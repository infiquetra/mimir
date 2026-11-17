# Market trade calculator — design

Status: locked for the `feat/rust-market-trade-calc` slice.
Base: `develop` at `0ed6d17` (898 tests stated at slice
start; this design commit re-runs the section 8 gates).
Slice branch: `feat/rust-market-trade-calc`.

Discovery: two read-only reports — the retired Flutter
calculator at `ed698d3` and the Rust Market view seams. During
design the Flutter bodies were re-read directly
(`git show ed698d3:lib/features/market/domain/trade_calculator.dart`,
72 lines, and
`git show ed698d3:lib/features/market/presentation/widgets/trade_calculator_panel.dart`,
403 lines, plus `lib/core/utils/formatters.dart`), and the
Rust seams were read directly (`src/ui/market.rs`,
`src/app/state.rs` market fields, `src/ui/widgets.rs`
`format_isk`, `assets/demo/market.json`,
`assets/sde/skills.json`). No EVE fee rate or formula here is
recalled from outside those bodies.

**Grounded verdict up front:** the Flutter calculator is a
pure function of four user-entered numbers — a buy price, a
sell price, a broker-fee percent, and a sales-tax percent —
with broker fee charged on both orders and sales tax on the
sell order only. It reads no market data, no character, and
no skill. This slice ports exactly that, per unit. The two
fee percents stay **user-entered inputs with honest labels**
(section 3): the app can read the active character's skill
levels, but no inspected body states how a skill level, a
standing, or a structure turns into an effective fee percent,
so deriving one would invent a rate. Skill-derived rates,
structure fees, standings, relist fees, and quantity totals
**ship nothing** (section 9). The starting values in the fee
fields are the Flutter app's own starting values (broker fee
1.0%, sales tax 2.0%), labelled as values to replace with the
reader's own rates — never presented as the signed-in
character's rates.

## 1. Goal and value ranking

Add a Trade Calculator block to the Market view: the reader
types a buy price and a sell price per unit (in ISK, the
in-game currency) plus their own broker-fee and sales-tax
percents, and sees the per-unit cost, net revenue, profit,
margin percent, total fees, and the break-even sell price,
computed with the retired Flutter app's formulas at the
values the reader entered.

Value ranking (locked, in order):

1. **Never a plausible-looking number from an absent or
   invented input.** An empty or invalid field renders no
   result at all (never a computed-looking zero), and no fee
   percent is ever derived from skills, standings, or a
   structure (sections 3, 6).
2. **Grounded math only.** Every formula is Flutter's,
   quoted in section 2; anything Flutter did not compute
   (relist fees, quantity totals, a return-on-investment
   figure distinct from margin) ships nothing.
3. **Reuse.** String-draft inputs in `AppState` like
   `market_search`, `text_edit_singleline` like the picker,
   `price_label` for every ISK figure, a pure module with
   no egui (the immediate-mode GUI library), state, network,
   or database access.

## 2. Trade math (locked — replicate Flutter)

Flutter `trade_calculator.dart` at `ed698d3` (read in full
during design). Header comment (lines 3–5): "All math
follows EVE Online's fee structure: Broker fee is paid on
both buy and sell orders. Sales tax is paid only on sell
orders."

`calculateMargin` (lines 14–31), verbatim:

```dart
final brokerFeeRate = brokerFeePercent / 100;
final salesTaxRate = salesTaxPercent / 100;
final buyTotal = buyPrice * (1 + brokerFeeRate);
final sellNet = sellPrice * (1 - brokerFeeRate - salesTaxRate);
final profit = sellNet - buyTotal;
final marginPercent = buyTotal > 0 ? (profit / buyTotal) * 100 : 0.0;
brokerFee: buyPrice * brokerFeeRate + sellPrice * brokerFeeRate,
salesTax: sellPrice * salesTaxRate,
```

`breakEvenSellPrice` (lines 40–45), verbatim:

```dart
final buyTotal = buyPrice * (1 + brokerFeePercent / 100);
// sellNet = sellPrice * (1 - brokerFee - salesTax) = buyTotal
// sellPrice = buyTotal / (1 - brokerFee - salesTax)
final denominator = 1 - brokerFeePercent / 100 - salesTaxPercent / 100;
if (denominator <= 0) return double.infinity;
return buyTotal / denominator;
```

`isProfitable => profit > 0` (line 71): strictly greater, so
a profit of exactly zero is a LOSS.

Locked port, per unit, in `f64` throughout:

```text
broker_rate   = broker_fee_percent / 100
tax_rate      = sales_tax_percent / 100
broker_buy    = buy_price * broker_rate
broker_sell   = sell_price * broker_rate
buy_total     = buy_price * (1 + broker_rate)        (= buy_price + broker_buy)
sell_net      = sell_price * (1 - broker_rate - tax_rate)
profit        = sell_net - buy_total
margin_percent = (profit / buy_total) * 100
broker_fee    = broker_buy + broker_sell
sales_tax     = sell_price * tax_rate
total_fees    = broker_fee + sales_tax
break_even    = buy_total / (1 - broker_rate - tax_rate)
```

Decisions locked:

- Margin divides by the fee-inclusive `buy_total`, as in the
  body — it is the only percentage output. There is no
  second "ROI" figure.
- Flutter's `buyTotal > 0 ? … : 0.0` guard has no reachable
  false branch once section 4's validation requires a
  positive buy price and a non-negative broker percent, so
  the Rust function returns `None` on invalid input instead
  of a `0.0` margin (section 4). No code path renders the
  guard's zero.
- Flutter returns `double.infinity` for break-even when the
  denominator is at or below zero, and its panel renders
  that as the literal text "Infinity ISK". The Rust port
  returns `Option<f64>` and renders nothing for `None`
  (sections 4, 6). "Infinity ISK" and any non-finite figure
  never appear.
- The panel's buy/sell broker-fee split rows recompute
  `buyPrice * _brokerFee / 100` and
  `sellPrice * _brokerFee / 100` in the widget (panel lines
  282, 293). The Rust struct carries both splits from the
  pure function (section 5) so the renderer does no fee
  arithmetic of its own beyond formatting.

## 3. Inputs (locked — every input is user-entered)

Exactly four inputs, all typed by the reader. Nothing is
taken from loaded market data and nothing from the
character's skills.

| Input | Meaning | Starting text | Valid range (section 4) |
|---|---|---|---|
| Buy price | Per-unit buy price in ISK | empty | finite, above 0 |
| Sell price | Per-unit sell price in ISK | empty | finite, above 0 |
| Broker fee percent | Reader's own broker-fee percent, charged on both orders | `1.0` | finite, 0 to 100 |
| Sales tax percent | Reader's own sales-tax percent, charged on the sell order only | `2.0` | finite, 0 to 100 |

- The starting percents are Flutter's: domain defaults
  `brokerFeePercent = 1.0` and `salesTaxPercent = 2.0`
  (`trade_calculator.dart:11–12, 37–38`) and panel state
  `_brokerFee = 1.0` / `_salesTax = 2.0` (panel lines
  19–20). They are starting text the reader edits, stated
  as such in the disclosure (section 7). They are not read
  from, and never described as, the active character's
  rates.
- **Why no skill-derived rate:** the app does load character
  skills (`SkillsData`, `src/app/state.rs:325`) and the
  bundled skill catalogue names Broker Relations (type
  3446), Advanced Broker Relations (type 16597), and
  Accounting (type 16622) in `assets/sde/skills.json`
  (verified during design). But no inspected Flutter or
  Rust body states a base broker-fee or sales-tax percent,
  a per-level reduction, a standing term, or a structure
  term — Flutter never looked a skill up (its panel is
  mounted as "pure client-side, no character needed"), and
  the Rust tree contains no fee formula. A level is
  therefore knowable while the percent it implies is not.
  Per the slice rule — never invent a fee rate — this slice
  reads no skill, shows no skill level, and ships no
  effective-rate derivation (section 9). A future slice may
  revisit only with an inspected formula body for the full
  rate (base, skills, standings, structure), not for one
  term of it.
- **Why no prefill from loaded market data:** Flutter
  consumed no market data (the calculator files import no
  repository). The Rust Market view already shows "Best
  sell" / "Best buy" lines the reader can type from. This
  slice adds no "use best buy/sell" button and never writes
  a loaded price into the drafts: an automatic copy would
  silently overwrite typed values on refresh or selection
  change, and would tie a per-unit what-if tool to a
  possibly truncated order book. Ships nothing (section 9).
- **No quantity input.** Flutter has none; every figure is
  per unit. No total-profit multiplication exists to port.
- Flutter's sliders (broker 0.0–5.0, sales tax 0.0–8.0, in
  0.1% steps; panel lines 107–108, 121–122, 222) are a
  widget choice, not an EVE rule, and the Rust tree has no
  slider precedent (discovery report 2, section 4: no
  `Slider` or `DragValue` anywhere in `src/`). The Rust
  percents are therefore text fields like the prices, valid
  over the full 0–100 range in section 4 rather than
  Flutter's slider caps. This widens what can be typed; it
  changes no formula.

Draft state (Builder A, section 11): four new `String`
fields on `AppState` beside the existing market view-local
fields (`src/app/state.rs:752–758`):

```rust
pub market_trade_buy_price: String,
pub market_trade_sell_price: String,
pub market_trade_broker_fee_percent: String,
pub market_trade_sales_tax_percent: String,
```

`AppState::new` sets the fee drafts explicitly from the pure
module's constants (section 5), next to the existing
explicit `market_region_id` assignment — the derived
`Default` would leave them empty, and an empty fee must mean
"reader cleared it", not the app's starting state. The price
drafts start empty. Drafts are session-only: nothing is
stored, and character switching, selection changes, and
market refreshes never touch them.

## 4. Validation and invalid-input behaviour (locked)

Parsing mirrors Flutter's `_calculate` (panel lines 30–36:
strip commas, parse, reject missing or non-positive) and
extends it to the cases Dart's parser and Rust's parser
treat differently. Two pure parsers (section 5):

- `parse_trade_price(text)`: trim whitespace, remove every
  `,` (thousands separators, as Flutter), parse as `f64`,
  and accept only a finite value above 0. This rejects
  empty text, non-numeric text, `0`, negatives, and —
  because Rust's `f64` parser accepts them — the texts
  `inf`, `-inf`, and `NaN` in any case. Scientific notation
  that Rust parses to a finite positive value is accepted
  as typed; no extra notation rules are invented.
- `parse_fee_percent(text)`: trim whitespace, remove one
  trailing `%` if present, remove every `,`, parse as
  `f64`, and accept only a finite value with
  `0.0 <= value <= 100.0`.

`calculate_margin` then returns `None` when any of these
holds — the full list, no others:

- buy or sell price is non-finite or at or below 0;
- either percent is non-finite or outside 0 to 100;
- the two percents sum to 100 or more (the fees would take
  the entire sale: `sell_net` would be zero or negative and
  break-even's denominator zero or negative — Flutter
  renders that corner as a negative net and "Infinity ISK";
  this port renders nothing, section 7);
- any computed output (`buy_total`, `sell_net`, `profit`,
  `margin_percent`, either broker split, `broker_fee`,
  `sales_tax`, or the `broker_fee + sales_tax` total the
  renderer shows) is non-finite, which covers overflow from
  huge finite prices.

`break_even_sell_price` returns `None` under the same price
and percent rules (sell price plays no part), including a
denominator at or below 0 and a non-finite result.

Consequences, locked:

- No `NaN`, infinity, or negative fee/cost/revenue figure
  can be produced: with the rules above, `buy_total`,
  `sell_net`, both broker splits, and `sales_tax` are all
  strictly positive or zero (zero only when a percent is
  exactly 0), and `margin_percent` is above -100. `profit`
  alone may be negative — that is the LOSS case Flutter
  shows, not a negative-money surprise.
- An absent input never renders as a computed zero. When no
  result exists the block shows one guidance line and no
  ISK figure of any kind (section 7). In particular the
  renderer never calls `widgets::format_isk` on an absent
  or non-finite amount: that formatter renders non-finite
  input as `0.00 ISK` (`src/ui/widgets.rs:20–24`), which is
  exactly the false quote `price_label`
  (`src/ui/market.rs:204–210`) exists to avoid. Every
  calculator ISK figure goes through `price_label`.
- A computed zero is still shown when it is genuinely
  computed (for example profit `0.00 ISK` with 0% fees and
  equal prices, section 8): presence is decided by the
  `Option`, never by comparing a figure to zero.

## 5. Pure API (locked)

New top-level module `src/trade_calculator.rs`, registered
in `src/lib.rs` in alphabetical position (`pub mod
trade_calculator;` between `storage` and `ui`). It mirrors
the shipped pure fitting modules (for example
`src/fitting/ship_cap_stability.rs`): no egui, no
`AppState`, no network, no database, and it logs nothing —
it runs at render cadence (every frame while the Market
view is open). Its module doc cites this design, the Flutter
oracle at `ed698d3`, and the user-entered-rates lock. It
does not live inside `src/ui/market.rs`: that file's pure
summaries are view-shaped, while this API is the domain
calculation the view consumes, and a separate file keeps
Builder A and Builder B on disjoint files (section 11).

```rust
pub const DEFAULT_BROKER_FEE_PERCENT: f64 = 1.0;
pub const DEFAULT_SALES_TAX_PERCENT: f64 = 2.0;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TradeMargin {
    pub buy_price: f64,
    pub sell_price: f64,
    pub broker_fee_buy: f64,
    pub broker_fee_sell: f64,
    pub broker_fee: f64,
    pub sales_tax: f64,
    pub buy_total: f64,
    pub sell_net: f64,
    pub profit: f64,
    pub margin_percent: f64,
}

impl TradeMargin {
    pub fn is_profitable(&self) -> bool; // profit > 0.0
    pub fn total_fees(&self) -> f64;     // broker_fee + sales_tax
}

pub fn parse_trade_price(text: &str) -> Option<f64>;
pub fn parse_fee_percent(text: &str) -> Option<f64>;

pub fn calculate_margin(
    buy_price: f64,
    sell_price: f64,
    broker_fee_percent: f64,
    sales_tax_percent: f64,
) -> Option<TradeMargin>;

pub fn break_even_sell_price(
    buy_price: f64,
    broker_fee_percent: f64,
    sales_tax_percent: f64,
) -> Option<f64>;

pub fn trade_calculator_result(
    buy_text: &str,
    sell_text: &str,
    broker_fee_text: &str,
    sales_tax_text: &str,
) -> Option<(TradeMargin, Option<f64>)>;
```

Decisions locked:

- Field names are Flutter's `TradeMargin` fields in Rust
  snake case, plus the two broker splits the Flutter panel
  recomputes (section 2). `total_fees` is a method, not a
  stored field, matching the panel's
  `result.brokerFee + result.salesTax` (panel line 310); it
  cannot go non-finite for a constructed `TradeMargin`
  because section 4 requires that exact sum to be finite
  before the struct is built — Builder A asserts this in
  the overflow test (section 8).
- Percents travel as percents (`1.0` means 1%), never as
  fractions, at every boundary — Flutter's convention
  (`brokerFeePercent / 100` happens inside the function).
- No default arguments exist in Rust, so the defaults are
  the two constants, used only to seed the `AppState` drafts
  (section 3). The functions themselves always take all
  four values explicitly; nothing silently substitutes a
  default for a cleared field.
- `trade_calculator_result` is the renderer's one call: it
  parses all four texts, and returns `Some((margin,
  break_even))` only when all four parse and
  `calculate_margin` succeeds. The inner break-even is
  still an `Option` so the renderer omits that one line if
  it is ever `None` (it can be `None` while the margin is
  `Some` when the break-even quotient overflows, so the
  renderer must not assume it is always present).
- The functions are total: no panics, no indexing, no
  unwrap on hostile text or hostile floats.

## 6. Rounding (locked — display only, as in Flutter)

No arithmetic step rounds. Flutter keeps raw `double`
precision end to end (no `round`/`ceil`/`floor` in either
calculator file) and rounds only when formatting; the port
keeps that rule exactly. This is deliberately not a claim
about how EVE itself rounds fees in game — no inspected body
states an in-game rounding rule, so none is applied or
claimed, and the disclosure says the figures can differ from
EVE (section 7).

Display formatting, locked:

- Every ISK figure: `price_label(value)` from
  `src/ui/market.rs:204–210`, which is
  `widgets::format_isk` for finite values — thousands-grouped
  with two decimals (`1,234,567.50 ISK`, `-150.00 ISK`) —
  matching Flutter's `NumberFormat('#,##0.00', 'en_US')`
  plus ` ISK` (`formatters.dart:9–12`). The pure module
  guarantees finite outputs, so the `not available` branch
  is defence in depth, not an expected rendering.
- Margin line: one decimal via `format!("{:.1}% margin",
  margin_percent)` — Flutter's
  `marginPercent.toStringAsFixed(1)` plus `% margin` (panel
  line 273). No thousands grouping, as in Flutter.
- The fee fields show the reader's typed text unchanged;
  the app never reformats a draft while it is being edited.

Test literals avoid exact half-way display boundaries, so
Dart-versus-Rust tie rounding is never what a test proves;
stored `f64` values are asserted with a `1e-9` absolute
tolerance (the existing `approx` precedent in
`src/ui/market.rs` tests) and rendered strings byte-exactly.

## 7. UI placement and verbatim wording (locked)

New `show_trade_calculator(ui, state)` in
`src/ui/market.rs`, called from `show()` immediately after
`show_picker(ui, state, resolver)` (`src/ui/market.rs:573`)
and **before** the no-selection early return (lines
575–581). Placement rationale: the Flutter panel needs no
item and no character ("pure client-side, no character
needed"), so the Rust block is available in every Market
state — no selection, loading, error, ready, offline, and
demo — and appears before the item sections rather than
inside the `Ready` arm (lines 624–628), where it would
vanish exactly when no fetch has happened. It sets no
request flag, fetches nothing, and never touches the
selection, keeping the view's read-only contract (module
doc, lines 1–6).

Layout follows the picker's shipped pattern (lines
277–341): a heading, then for each of the four drafts a
label and a `ui.text_edit_singleline` on its own row, with
`state.text_input_focused |= response.has_focus()` for every
field so keyboard shortcuts elsewhere stay gated while
typing (the precedent at line 290). No focus is ever
requested for these fields. The heading and the four input
labels below are named constants in `src/ui/market.rs`
(`TRADE_CALCULATOR_HEADING` and
`TRADE_CALCULATOR_INPUT_LABELS: [&str; 4]`, in field order)
so Builder B can assert them byte-exactly without an egui
frame. There is **no Calculate
button**: Flutter recalculates on every change (`onChanged`,
panel line 185, and both sliders), and egui recomputes every
frame, so the button would be a no-op control. No colour
coding is locked; the Market view's plain labels carry the
wording, and the PROFITABLE/LOSS word carries the verdict.

Heading and input labels, verbatim and in order:

```text
Trade Calculator
Buy Price (ISK)
Sell Price (ISK)
Broker Fee % (entered by you)
Sales Tax % (entered by you)
```

The price labels are Flutter's (panel lines 86, 94). The
fee labels extend Flutter's `Broker Fee` / `Sales Tax`
(panel lines 105, 119) with the honest source — the reader,
not the character — because that is the slice rule for a
rate the app cannot know (section 3).

Result lines, verbatim templates in order, each rendered as
one `ui.label` in the Market view's `Label: value` shape
(lines 364–382 precedent), every ISK value via
`price_label` (section 6). Labels are Flutter's result rows
(panel lines 279–311) in Flutter's order:

```text
{PROFITABLE or LOSS}
{profit}
{margin:.1}% margin
Buy Price: {buy_price}
+ Broker Fee (buy): {broker_fee_buy}
= Total Cost: {buy_total}
Sell Price: {sell_price}
- Broker Fee (sell): {broker_fee_sell}
- Sales Tax: {sales_tax}
= Net Revenue: {sell_net}
Profit / Unit: {profit}
Total Fees: {total_fees}
Break-Even Sell Price: {break_even}
```

The verdict word is `PROFITABLE` when
`is_profitable()` (profit strictly above 0, section 2) and
`LOSS` otherwise, including profit exactly 0. The first
profit figure is Flutter's headline (panel line 266); its
repetition as `Profit / Unit` is Flutter's own repetition
(panel lines 302–307) and is kept. The break-even line
renders only when the inner `Option` is `Some` (section 5);
otherwise that one line is omitted and the rest still show.

When `trade_calculator_result` returns `None`, no result
line renders — instead exactly one guidance line, chosen in
this order (new constants in `src/ui/market.rs`,
`TRADE_CALCULATOR_INPUT_GUIDANCE` and
`TRADE_CALCULATOR_NO_RESULT_GUIDANCE`):

1. If any of the four drafts fails its section 4 parser:

   ```text
   Enter a buy price and a sell price above 0 ISK, and fee percents from 0 to 100, to see the result.
   ```

2. Else (all four parse but the calculation rejects them —
   the percents summing to 100 or more, or a non-finite
   output from huge prices):

   ```text
   No result: the broker fee and sales tax together must be below 100%, and the prices must be small enough to calculate with.
   ```

The renderer makes this choice by calling the two pure
parsers again only in the `None` arm; it does not duplicate
the calculation. Neither guidance line contains a computed
figure or any value taken from the drafts: the only numbers
in them are the fixed bounds in their own wording.

**Disclosure**, rendered verbatim under the fields in both
the result and guidance states (new constant
`TRADE_CALCULATOR_DISCLOSURE` in `src/ui/market.rs`):

> Per-unit estimate using only the prices and percents you
> entered. The broker fee is charged on both the buy and
> sell orders; sales tax is charged on the sell order only.
> The starting percents (broker fee 1.0%, sales tax 2.0%)
> are starting values to replace with your own rates: Mimir
> does not read them from your character's skills,
> standings, or the station or structure, and they may not
> be the rates you actually pay. Relist fees and any
> quantity total are not included. Figures are rounded only
> for display, so these numbers can differ from EVE.

Every clause carries one locked decision: per-unit with no
quantity (section 3), broker on both orders and tax on sell
only (section 2), user-entered rates with Flutter's starting
values named as starting values and every un-read source
named (section 3), relist excluded (section 9), display-only
rounding (section 6).

Logging: the pure module logs nothing (render cadence,
section 5). The renderer emits one
`tracing::debug!("[MARKET] trade calculator input changed")`
when any field's response reports `changed()` — the
`[MARKET]` tag the view already uses — and logs no draft
contents and no computed figure.

## 8. Demo pins and test plan (locked literals)

**No Flutter test oracle exists.** Discovery verified that
`git grep -n "TradeMargin|calculateMargin|breakEven" ed698d3
-- test/` is empty and no market test file references the
calculator, so there are no Flutter test numbers to
reproduce. Every literal below is instead derived during
design directly from the quoted Flutter formulas
(section 2), with the arithmetic in a comment beside each
assertion, and cross-checked by script against those
formulas. `f64` assertions use one absolute tolerance of
`1e-9`; `assert_eq!` is reserved for `None` outcomes,
booleans, and rendered strings.

**Demo mode:** no demo data changes. The block renders in
demo mode exactly as live (empty price drafts, fee drafts
`1.0` / `2.0`, input guidance) because no input comes from
loaded data (section 3). The demo order-book prices are
used only as hand-typed test inputs tying the pure tests to
the committed `assets/demo/market.json` pins: Aria's
Tritanium best buy 5.50 / best sell 5.75 (character
90000001) and Marcus's Pyerite best buy 7.90 / best sell
8.20 (character 90000002). No code copies them into the
drafts, and a renderer test proves the drafts are untouched
by a ready demo bundle (below).

**Builder A — pure module and state tests**
(`src/trade_calculator.rs`, `src/app/state.rs`):

Profitable case at the starting percents (buy 100, sell 120,
broker 1.0, tax 2.0):

```text
// buy_total = 100 * 1.01 = 101; sell_net = 120 * 0.97 = 116.4
// profit = 116.4 - 101 = 15.4; margin = 15.4 / 101 * 100 = 15.2475…
// broker = 100*0.01 + 120*0.01 = 2.2; tax = 120*0.02 = 2.4; fees = 4.6
// break_even = 101 / 0.97 = 104.12371134020619
```

Loss case at equal prices (buy 100, sell 100, 1.0, 2.0):
`buy_total 101`, `sell_net 97`, `profit -4`,
`margin -3.960396…`, `is_profitable()` false, break-even
unchanged at `104.12371134020619` (buy-only input).

Zero-fee cases: buy 100, sell 110, 0.0, 0.0 gives
`profit 10`, `margin 10`, all fees 0, break-even 100;
buy 100, sell 100, 0.0, 0.0 gives `profit 0`, `margin 0`,
and `is_profitable()` **false** — the zero-profit-is-LOSS
rule (section 2).

Custom percents (buy 1000, sell 1500, broker 2.5, tax 4.0):

```text
// buy_total = 1000 * 1.025 = 1025; sell_net = 1500 * 0.935 = 1402.5
// profit = 377.5; margin = 377.5 / 1025 * 100 = 36.829268…
// broker = 25 + 37.5 = 62.5; tax = 60; fees = 122.5
// break_even = 1025 / 0.935 = 1096.2566844919786
```

Demo-price cases (typed inputs, starting percents):
Tritanium buy 5.50, sell 5.75 gives `buy_total 5.555`,
`sell_net 5.5775`, `profit 0.0225`, `margin 0.405040…`,
broker splits `0.055` / `0.0575`, tax `0.115`, fees
`0.2275`, break-even `5.72680412371134`. Pyerite buy 7.90,
sell 8.20 gives `buy_total 7.979`, `sell_net 7.954`,
`profit -0.025`, `margin -0.313322…`, break-even
`8.22577319587629` — a LOSS at the demo spread, asserted
as such (the demo prices are not edited to flatter the
tool).

Break-even inverse: feeding a returned break-even back as
the sell price yields profit within `1e-9` of 0 (asserted
for the 100 / 1.0 / 2.0 case), and
`break_even_sell_price(100, 1.0, 2.0)` is
`104.12371134020619` regardless of any sell price.

Validation matrix, one assertion per rule in section 4:
prices `0`, `-5`, `NaN`, `INFINITY`, `-INFINITY` give
`None`; percents `-0.1`, `100.1`, `NaN` give `None`;
percent exactly `100` parses but any pair summing to 100 or
more (60 + 40, 100 + 0, 60 + 50) gives `None` from both
functions; a huge finite price whose outputs overflow
(buy 1.78e308, sell 1.78e308, 1.0, 2.0, whose buy total
1.78e308 * 1.01 exceeds the largest finite double) gives
`None`, and
`total_fees()` is finite for every `Some` case above.

Parser cases: `"1,234.5"` parses to 1234.5, `" 5.75 "` to
5.75; `""`, `"abc"`, `"NaN"`, `"inf"`, `"0"`, `"-1"` give
`None` as prices; `"1.0"` and `"1.0%"` give 1.0 as percents,
`"0"` gives 0.0, `"100"` gives 100.0; `"-0.1"`, `"100.1"`,
`""`, `"NaN"` give `None` as percents.

`trade_calculator_result` cases: all four texts valid gives
`Some` with `Some` break-even; any one text invalid gives
`None` (one case per field). State case:
`AppState::new(false)` has empty price drafts and fee drafts
`"1.0"` / `"2.0"` (from the section 5 constants), and
`set_market_selection` / `set_market_region` leave all four
drafts unchanged.

**Builder B — renderer tests** (`src/ui/market.rs`), in the
file's existing test style. Line-building is factored so
the strings are testable without an egui frame, following
the file's pure-summary precedent: Builder B adds a pure
`trade_calculator_lines(state: &AppState) -> Vec<String>`
helper in `src/ui/market.rs` that returns every line after
the heading and input rows (result lines plus disclosure,
or guidance plus disclosure), and `show_trade_calculator`
renders exactly those strings. Tests assert:

- Verbatim heading, the four input labels, both guidance
  constants, and the disclosure constant (byte-exact
  against section 7).
- The full result block for buy `100`, sell `120`, fees
  `1.0` / `2.0`: `PROFITABLE`, `15.40 ISK`, `15.2% margin`,
  `Buy Price: 100.00 ISK`, `+ Broker Fee (buy): 1.00 ISK`,
  `= Total Cost: 101.00 ISK`, `Sell Price: 120.00 ISK`,
  `- Broker Fee (sell): 1.20 ISK`, `- Sales Tax: 2.40 ISK`,
  `= Net Revenue: 116.40 ISK`, `Profit / Unit: 15.40 ISK`,
  `Total Fees: 4.60 ISK`, `Break-Even Sell Price: 104.12 ISK`.
- LOSS wording: equal prices at the starting percents give
  `LOSS` and `-4.0% margin`; zero fees and equal prices give
  `LOSS`, `0.00 ISK` profit, `0.0% margin` (a computed zero
  shown, section 4).
- Guidance selection: empty or invalid drafts give exactly
  the input-guidance line followed by the disclosure; fees
  `60` / `40` with valid prices give exactly the
  no-result-guidance line followed by the disclosure. No
  result line and no computed figure appears in either
  state (asserted by whole-vector equality, so no stray
  `0.00 ISK` line can hide between them).
- Demo independence: a state whose market bundle is the
  demo Tritanium bundle leaves the four drafts exactly as
  constructed (no prefill, section 3), and typing the demo
  prices 5.50 / 5.75 renders `PROFITABLE` with
  `0.02 ISK` headline profit (0.0225 at display rounding)
  and `0.4% margin`.
- Regression: every existing market test passes unmodified
  — this slice inserts one block before the item sections
  and rewords none of theirs.

**Gates (every commit):** `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`.

## 9. Exclusions (locked — ship-nothing lines are explicit)

- **No skill-derived, standing-derived, or structure-derived
  fee percent.** The levels of Broker Relations (3446),
  Advanced Broker Relations (16597), and Accounting (16622)
  are readable from loaded skills, but no inspected body
  states the base percents or any reduction formula, so no
  effective rate is computed, prefilled, suggested, or
  displayed; this slice reads no skill data at all. Any
  future derivation needs an inspected formula body for the
  complete rate — base, skills, standings, and the
  station/structure term together (section 3). The demo
  skill fixtures containing none of these skills (discovery
  report 2, section 7) is therefore not a gap to seed
  around.
- **No NPC-station versus player-structure distinction** and
  no structure fee field: Flutter models neither, and no
  loaded Rust data carries a structure's fee percent.
- **No relist fee** (the fee for modifying an order's
  price): absent from the Flutter calculator entirely — no
  field, term, or constant — and no other inspected body
  states its formula. The disclosure names the exclusion;
  no input or line exists for it.
- **No quantity, volume, or total-profit figure:** per unit
  only, as in Flutter. No escrow, collateral, or
  wallet-balance check of any kind.
- **No prefill or copy button** from best buy/sell, spread,
  price history, or the character's own orders (section 3),
  and **no persistence** of the four drafts beyond the
  session.
- **No order placement, modification, or cancellation:**
  the Market view stays read-only; this block sets no
  request flag and needs no EVE SSO scope (the browser
  sign-in permission flow), no character, and no network.
- **No invented in-game rounding:** no whole-ISK fee
  rounding, price-tick rounding, or minimum-fee term is
  applied or claimed (section 6).
- **No second percentage:** no ROI, markup-on-sell-price, or
  margin-on-revenue figure beside Flutter's one margin
  (section 2), and no chart, history of past calculations,
  or comparison across items or regions.
- No change to `summarize_orders`, `summarize_history`,
  `character_order_rows`, the picker, ESI endpoints or
  models, demo JSON, or `MarketData` (whose field set is a
  cross-builder contract, `src/app/state.rs:405–414`).

## 10. Integrator list

- **README** (Market bullet, line 19): append one sentence
  in the same voice — "The view also carries a per-unit
  trade calculator: you type a buy price, a sell price, and
  your own broker-fee and sales-tax percents (starting
  values 1.0% and 2.0%, never read from your character's
  skills, standings, or the station or structure), and it
  shows total cost, net revenue, profit per unit, margin,
  total fees, and the break-even sell price, with the
  broker fee on both orders and sales tax on the sell order
  only; relist fees and quantity totals are not included,
  figures are rounded only for display, and an empty or
  invalid field shows guidance instead of any figure." —
  and in that bullet replace "Nothing market-related is
  stored, no order can be placed, and there is no profit or
  valuation feature." with "Nothing market-related is
  stored and no order can be placed; the only profit figure
  is the calculator's per-unit estimate from values you
  type, and there is no valuation feature." In the line-29
  not-implemented checklist, change "**Market Tools**:
  profit analysis (not implemented; …)" to "**Market
  Tools**: profit analysis beyond the Market view's
  per-unit trade calculator (not implemented; …)", leaving
  the parenthetical's remainder intact.
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): one entry with Evidence/Mechanism/rule — a skill
  level being readable does not make the fee percent it
  implies knowable: with no inspected base-rate or
  reduction formula, the rate stays a labelled user input
  rather than a derived figure (sections 3, 9), and
  Flutter's silently rendered "Infinity ISK" break-even is
  the porting corner where an `Option` plus guidance
  replaces a plausible-looking non-number (sections 2, 4).
- Nothing else: no HANDOFF change beyond what the parent
  directs, no demo-data, ESI, scope, or storage change. If
  build discovery contradicts any literal in section 8, the
  slice stops rather than growing scope.

## 11. Ownership and commit split

- **Design (this commit):** `docs/market-trade-calculator-design.md`
  only. Commit: `docs(market): design trade calculator`.
- **Builder A — pure calculation and draft state:** new
  `src/trade_calculator.rs`, `src/lib.rs` module
  registration, the four `AppState` draft fields and their
  `AppState::new` seeding in `src/app/state.rs`, and the
  section 8 Builder-A tests. Commits:
  `feat(market): add pure trade margin calculator`,
  `feat(market): add trade calculator draft state`.
- **Builder B — render:** `src/ui/market.rs` only (block,
  line helper, constants, section 8 Builder-B tests).
  Commit: `feat(market): show trade calculator in market view`.
- **Integrator:** README and journal per section 10, full
  gates, and a demo-mode check that the block shows the
  input guidance with the demo bundle loaded and computes
  the section 8 Tritanium case when its prices are typed.
  Commit: `docs(market): document trade calculator`.

Builder B touches no `src/trade_calculator.rs`,
`src/lib.rs`, or `src/app/state.rs` file and codes against
sections 5 and 7's locked API and wording; Builder A
touches no `src/ui/` file. Small atomic commits,
`type(scope): description`, no attribution lines. Nobody
pushes or merges; the parent does that.





