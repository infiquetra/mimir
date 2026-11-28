# Industry calculators — design

Status: locked for the `feat/rust-industry-calculators` slice.
Base: `develop` at `a4fb681` (917 tests stated at slice
start; this design commit re-runs the section 8 gates).
Slice branch: `feat/rust-industry-calculators`.

Discovery: two read-only reports — the retired Flutter
industry calculators at `ed698d3` and the Rust Industry view
seams with the trade-calculator precedent. During design the
Flutter bodies were re-read directly (`git show ed698d3:` for
`lib/features/industry/domain/invention_calculator.dart`,
29 lines, `reaction_calculator.dart`, 40 lines, and
`production_chain_builder.dart`, 116 lines; the panels
`invention_calculator_panel.dart`, 271 lines,
`reaction_calculator_panel.dart`, 272 lines, and
`production_chain_visualizer.dart`, 255 lines; and the three
test files `invention_calculator_test.dart`, 63 lines,
`reaction_calculator_test.dart`, 52 lines, and
`production_chain_builder_test.dart`, 35 lines), and the
Rust seams were read directly (`src/trade_calculator.rs`,
436 lines, `src/ui/industry.rs`, `src/ui/market.rs`
calculator block, `src/app/state.rs` trade-draft and
industry fields, `src/lib.rs`, `assets/demo/industry.json`,
and the key counts of `assets/sde/industry.json`). No EVE
probability, multiplier, bonus, or formula here is recalled
from outside those bodies.

**Grounded verdict up front, one line per calculator:**

- **Invention ships in this slice.** Flutter's
  `InventionCalculator.calculateProbability` is a pure
  function of five user-entered scalars — a base
  probability, three skill levels, and a decryptor
  multiplier — with only hard-coded constants. It reads no
  SDE (Static Data Export, EVE's published static game
  data), no blueprint, and no character. Sections 2–8 lock
  its port exactly.
- **Reaction ships nothing in this slice (deferred).** The
  domain arithmetic is pure over two quantity maps, but no
  user can supply those maps honestly: Flutter's own panel
  hard-codes dummy maps marked `// Dummy base inputs and
  outputs for testing` and renders raw `Item #<id>` rows,
  and the real per-run maps live in SDE tables
  (`industryActivityMaterials` / `industryActivityProducts`,
  activity 11) that the Rust tree bundles on disk in
  `assets/sde/industry.json` but never loads. Section 9
  names the exact missing data. Not even the pure functions
  ship: dead arithmetic with no honest caller would invite
  the dummy-map port this design forbids.
- **Production chain ships nothing in this slice
  (deferred).** `ProductionChainBuilder.buildChain` is a
  recursive query over the SDE industry materials graph,
  not a formula, and its own visualizer renders an invented
  dummy tree (`// Dummy tree for testing the UI`) beside a
  placeholder canvas. Rust loads none of that graph today.
  Section 9 names the exact missing data.

Anything beyond the one shipped calculator that would need
data Rust does not load — a per-blueprint base probability
auto-fill, skill levels read from the character, a reaction
picker, a production-chain tree, or a manufacturing
material calculation of any kind — **ships nothing**
(sections 3, 9). The starting values in the invention
fields are the Flutter panel's own starting values (base
probability 0.30, each skill level 4, decryptor multiplier
1.0), labelled as values to replace — never presented as
the signed-in character's levels or any blueprint's
probability.

## 1. Goal and value ranking

Add an Invention Calculator block to the Industry view: the
reader types a base probability as a fraction (0.30 means
30%), their own encryption and two datacore skill levels,
and a decryptor multiplier, and sees the invention chance
as a percentage, computed with the retired Flutter app's
formula at the values the reader entered.

Value ranking (locked, in order):

1. **Never a plausible-looking number from an absent or
   invented input.** An empty or invalid field renders no
   chance at all (never a computed-looking `0.0%`), no
   input is ever read from a loaded job, blueprint, or
   skill, and the two deferred calculators render nothing
   rather than Flutter's dummy data (sections 3, 4, 9).
2. **Grounded math only.** The one formula is Flutter's,
   quoted in section 2 and pinned by its four test oracles
   (section 8); anything Flutter did not compute from real
   inputs (expected runs, costs, a reaction table, a chain
   tree) ships nothing.
3. **Reuse.** The shipped trade-calculator shape end to
   end: a pure module in the `src/trade_calculator.rs`
   style, session-only `String` drafts in `AppState` seeded
   from the pure module's constants, a pure line-building
   helper in the view so every rendered string is testable
   without an egui (the immediate-mode GUI library) frame,
   and verbatim wording held in named constants.

## 2. Invention math (locked — replicate Flutter)

Flutter `invention_calculator.dart` at `ed698d3` (read in
full during design). The doc comment (lines 5–9) states
the input meanings: "The base probability of the invention
(e.g., 0.30 for ships)", the three levels each "(1-5)", and
"The multiplier provided by the decryptor (e.g., 1.2 for
+20%, 1.0 for none)". The body (lines 17–27), verbatim:

```dart
// Standard EVE Online Invention Formula
final skillFactor =
    1.0 +
    (encryptionSkillLevel / 40.0) +
    (datacoreSkill1Level / 40.0) +
    (datacoreSkill2Level / 40.0);

final finalChance = baseProbability * skillFactor * decryptorMultiplier;

// Cap at 1.0 (100%)
return finalChance > 1.0 ? 1.0 : finalChance;
```

Locked port, in `f64` throughout, with operand order kept
exactly as written above so floating-point association
matches the oracle:

```text
skill_factor = 1.0
             + (encryption_skill_level / 40.0)
             + (datacore_skill1_level / 40.0)
             + (datacore_skill2_level / 40.0)
raw_chance   = base_probability * skill_factor * decryptor_multiplier
chance       = min(raw_chance, 1.0)
```

Decisions locked:

- The divisor `40.0` is applied per skill three times, as
  written; it is never folded into `(sum / 40.0)` at the
  API level, because section 8's literals pin Flutter's
  association. Whether `40.0` and the `1.0` cap still
  match EVE Live is unverified — the only source is the
  body's `Standard EVE Online Invention Formula` comment
  — and the disclosure (section 7) says the figures can
  differ from EVE rather than claiming live accuracy.
- The cap is Flutter's own `> 1.0 ? 1.0 : …`: a raw chance
  of exactly 1.0 and any raw chance above 1.0 both produce
  exactly 1.0. There is no lower clamp reachable in the
  port, because section 4 requires every input positive
  and every level at least 1, so `skill_factor` lies
  between 1.075 and 1.375 and `raw_chance` is positive and
  finite for every constructed result.
- Flutter's domain function validates nothing: a `NaN`
  input returns `NaN` (its `> 1.0` test is false) and the
  panel would render it, and an infinite product returns
  1.0 through the cap test (infinity is above 1.0). The
  port returns `None` for both corners instead (section 4),
  the same replacement the trade calculator made for
  Flutter's rendered "Infinity ISK": no `NaN%`, no infinite
  figure, and never a capped-looking `100.0%` manufactured
  from an overflowed product.
- The one output is the chance itself. Flutter's panel
  renders no skill-factor, expected-attempts, or cost
  figure, so the port computes and displays none
  (section 9): the pure function returns the chance as a
  plain `f64` inside an `Option`, with no result struct,
  because there is no second figure for a struct to carry.

## 3. Inputs (locked — every input is user-entered)

Exactly five inputs, all typed by the reader. Nothing is
taken from loaded industry jobs or blueprints and nothing
from the character's skills.

| Input | Meaning | Starting text | Valid range (section 4) |
|---|---|---|---|
| Base probability | The invention's base probability as a fraction: 0.30 means 30% | `0.30` | finite, above 0, at most 1 |
| Encryption skill level | Reader's level in the one encryption skill the invention uses | `4` | whole number, 1 to 5 |
| Datacore skill 1 level | Reader's level in the first datacore skill | `4` | whole number, 1 to 5 |
| Datacore skill 2 level | Reader's level in the second datacore skill | `4` | whole number, 1 to 5 |
| Decryptor multiplier | Multiplier from the decryptor used, if any (1.0 for none) | `1.0` | finite, above 0 |

- The starting values are the Flutter panel's state
  (`invention_calculator_panel.dart:22–26`:
  `_baseProbability = 0.30`, three skills at 4,
  `_decryptorMultiplier = 1.0`), whose own comment
  (lines 19–21) says they are "Hardcoded for now" and
  would in a full implementation auto-populate from the
  SDE by blueprint and from the active character's trained
  skills. That full implementation never shipped in
  Flutter either, so the port keeps the same honest
  contract: the fields start at Flutter's values, the
  disclosure names them as starting values to replace
  (section 7), and nothing reads a blueprint or a
  character. With the starting texts the result is already
  computable (section 8: `0.30 × 1.3 × 1.0 = 0.39`), so —
  unlike the trade calculator, whose prices start empty —
  the block shows a result on first open, exactly as the
  Flutter panel did. That is a starting-value result
  clearly covered by the disclosure, not an absent input
  rendering as a figure: every field holds visible text
  the reader can see and edit.
- **Why no base probability from a blueprint:** the bundled
  `assets/sde/industry.json` does carry a `probabilities`
  table (1,341 rows, verified during design by loading its
  JSON and counting keys), and a demo blueprint type's
  invention probability is in it. But no Rust code loads
  that file: `src/names/sde.rs:81–84` loads only
  `assets/sde/skills.json`, and the only Rust reference to
  an industry JSON is the demo fixture
  (`src/demo/data.rs:35`, `assets/demo/industry.json`, jobs
  and owned blueprints, not SDE probabilities). Loading a
  5-megabyte SDE table, deciding which owned blueprint a
  selection means, and matching its activity-8 probability
  row is a data slice of its own; this slice adds no
  loader, no blueprint picker, and no prefill (section 9).
- **Why no skill levels from the character:** the app does
  load character skills (`SkillsData`, `src/app/state.rs`),
  so trained levels are readable in principle. But no
  inspected Flutter or Rust body says *which* skill types
  count as the encryption skill and the two datacore
  skills for a given invention — the Dart panel names only
  the slider labels and never a skill type — and the
  per-blueprint skill requirements live in the same
  unloaded SDE table (`skills`, 22,257 rows, verified the
  same way). A level box labelled generically could be
  prefilled with the wrong skill's level and still look
  authoritative, so this slice reads no skill data at all
  (section 9). The three level fields are labelled
  "(1 to 5, entered by you)" (section 7).
- **Why no probability from a loaded job:** a delivered
  invention job carries an optional `probability` field
  (ESI, the EVE Swagger Interface, `IndustryJob` in
  `src/esi/models.rs`), and the demo data has one at 0.4
  (demo job 710000203, verified in
  `assets/demo/industry.json`). The Rust model doc states
  that field is parsed and carried but "never rendered and
  never enter[s] any computation", and nothing inspected
  equates a past job's recorded probability with the base
  probability a new calculation should start from. The
  port neither displays nor copies it (sections 8, 9).
- **Decryptor is a typed multiplier, not a picker of owned
  items.** Flutter's dropdown (panel lines 194–215) lists
  five hard-coded choices — `None (x1.0)`, `Symmetry
  Decryptor (x1.1)`, `Process Decryptor (x1.2)`, `Parity
  Decryptor (x1.8)`, `Optimized Decryptor (x0.6)` — as a
  closed set of multipliers, none loaded from the
  character's assets. The Rust tree has no dropdown or
  slider precedent (no `ComboBox`, `Slider`, or
  `DragValue` anywhere in `src/ui/` or `src/app/`,
  verified during design), and the shipped trade
  calculator replaced Flutter sliders with text fields on
  exactly that ground. The port does the same: one text
  field for the multiplier, and the disclosure lists
  Flutter's five named choices with their multipliers
  (section 7) so the reader knows what to type. This
  widens what can be typed beyond the five values; it
  changes no formula, and no decryptor the character owns
  is read or claimed.
- **Skill levels and the base probability are text fields,
  not sliders,** for the same reason (Flutter's skill
  sliders ran 1–5 and its base slider 0.1–0.9; panel lines
  157–159 and 249–251 — widget choices, not EVE rules).
  The level range 1–5 is kept because the domain doc
  comment states "(1-5)" for all three levels
  (`invention_calculator.dart:6–8`); level 0 shows guidance
  rather than a chance, because no inspected body defines
  what an untrained level should produce. The base range
  widens from the slider's 0.1–0.9 to the full probability
  range above 0 and at most 1 (section 4): the domain
  tests themselves use 0.90 at the slider's edge, and the
  cap at 1.0 shows probabilities live on the 0–1 scale.
  The field is a *fraction* everywhere (section 5), as in
  Flutter's domain, its doc ("0.30 for ships"), and its
  tests — the label says "(0 to 1, entered by you)" and
  the guidance spells out "0.30 for 30%", so `30` or `30%`
  parse as nothing rather than being silently read as a
  percent (section 4).

Draft state (Builder A, section 11): five new `String`
fields on `AppState` beside the existing view-local
industry fields (`industry_search`,
`industry_blueprint_kind`):

```rust
pub industry_invention_base_probability: String,
pub industry_invention_encryption_skill: String,
pub industry_invention_datacore_skill1: String,
pub industry_invention_datacore_skill2: String,
pub industry_invention_decryptor_multiplier: String,
```

`AppState::new` sets all five explicitly from the pure
module's starting-value constants (section 5), next to the
existing trade-calculator seeding — the derived `Default`
would leave them empty, and an empty field must mean
"reader cleared it", not the app's starting state. Drafts
are session-only: nothing is stored, and character
switching, blueprint filtering, and industry refreshes
never touch them (the same survival the existing tests pin
for `industry_search` and the trade drafts).

## 4. Validation and invalid-input behaviour (locked)

Flutter's sliders and dropdown could only produce
in-range values, so the domain validated nothing; the text
fields need the rules sliders used to enforce, following
the trade module's parser shape. Three pure parsers
(section 5):

- `parse_base_probability(text)`: trim whitespace, parse
  as `f64`, accept only a finite value above 0 and at most
  1. No comma stripping and no `%` suffix rule: on a 0–1
  fraction field a comma is a mistyped decimal separator,
  not a thousands separator, and accepting `30%` would
  require inventing the percent reading section 3 forbids.
  This rejects empty text, `0`, values above 1 (including
  `30`), negatives, and — because Rust's `f64` parser
  accepts them — `inf`, `-inf`, and `NaN` in any case.
- `parse_skill_level(text)`: trim whitespace, parse as
  `i64`, accept only 1 to 5. This rejects `0`, `6`,
  negatives, empty text, and fractional text such as
  `4.0` (the `i64` parser rejects it; a level is a whole
  number, as Flutter's `int` parameters were).
- `parse_decryptor_multiplier(text)`: trim whitespace,
  parse as `f64`, accept only a finite value above 0. No
  upper bound at parse time (Flutter's domain has none);
  the calculation's finiteness check below is what rejects
  a typed multiplier so large the product overflows. This
  rejects `x1.0` (no `x` prefix rule is invented), `0`,
  negatives, empty text, and non-finite spellings.

Scientific notation that Rust parses to an in-range finite
value is accepted as typed in the two `f64` parsers; no
extra notation rules are invented (section 8 pins one such
case through the overflow path).

`calculate_probability` then returns `None` when any of
these holds — the full list, no others:

- base probability is non-finite, at or below 0, or above 1;
- any of the three skill levels is outside 1 to 5;
- decryptor multiplier is non-finite or at or below 0;
- the computed `raw_chance` is non-finite (overflow from a
  huge finite multiplier) — checked *before* the cap, so
  the Flutter corner where an infinite product caps to a
  plausible 1.0 can never produce a `100.0%` (section 2).

Consequences, locked:

- No `NaN`, infinity, negative, or above-100% figure can
  be produced: every `Some` chance is finite, at least 0,
  and at most 1 (a present input whose product underflows
  to exactly 0.0 at subnormal magnitudes is still a
  computed result, never an absent one), so the rendered
  percent lies in `0.0%`–`100.0%` display rounding of a
  value in [0, 1].
- An absent input never renders as a computed zero. When
  no result exists the block shows one guidance line and
  no percentage of any kind (section 7); presence is
  decided by the `Option`, never by comparing a figure to
  zero. In particular a cleared field can never show
  `0.0%`, and a typed base probability of exactly `0`
  shows guidance, not a `0.0%` chance, because section 3's
  range requires a value above 0.
- A computed boundary is still shown when it is genuinely
  computed: a raw chance at or above 1 renders `100.0%`
  (Flutter's cap case, section 8), and a tiny typed base
  probability renders its rounded display value even when
  that displays as `0.0%` at one decimal — the result
  exists, so the line renders; only its display rounds.

## 5. Pure API (locked)

New top-level module `src/invention_calculator.rs`,
registered in `src/lib.rs` in alphabetical position
(`pub mod invention_calculator;` between `fitting` and
`names`). It mirrors `src/trade_calculator.rs`: no egui,
no `AppState`, no network, no database, and it logs
nothing — it runs at render cadence (every frame while the
Industry view is open). Its module doc cites this design,
the Flutter oracle at `ed698d3`, the user-entered-inputs
lock, and the reaction/production-chain deferral, so no
reader mistakes the single shipped module for the whole
Flutter calculator set. It does not live inside
`src/ui/industry.rs`: that file's helpers are view-shaped
rows, while this API is the domain calculation the view
consumes, and a separate file keeps Builder A and
Builder B on disjoint files (section 11). The module is
named for the one calculator it ships, not
`industry_calculators`: a plural module would promise the
two deferred calculators it must not contain (section 9).

```rust
pub const DEFAULT_BASE_PROBABILITY: f64 = 0.30;
pub const DEFAULT_SKILL_LEVEL: i64 = 4;
pub const DEFAULT_DECRYPTOR_MULTIPLIER: f64 = 1.0;

pub fn parse_base_probability(text: &str) -> Option<f64>;
pub fn parse_skill_level(text: &str) -> Option<i64>;
pub fn parse_decryptor_multiplier(text: &str) -> Option<f64>;

pub fn calculate_probability(
    base_probability: f64,
    encryption_skill_level: i64,
    datacore_skill1_level: i64,
    datacore_skill2_level: i64,
    decryptor_multiplier: f64,
) -> Option<f64>;

pub fn invention_calculator_result(
    base_probability_text: &str,
    encryption_skill_text: &str,
    datacore_skill1_text: &str,
    datacore_skill2_text: &str,
    decryptor_multiplier_text: &str,
) -> Option<f64>;
```

Decisions locked:

- The three constants are the Flutter panel's starting
  values (section 3), named with the trade module's
  `DEFAULT_` prefix and each documented as the `AppState`
  draft seed, never a derived figure. One shared
  `DEFAULT_SKILL_LEVEL` covers all three level drafts
  because Flutter starts all three at the same value (4);
  there are no per-skill defaults to drift apart.
  `AppState::new` formats the seeds from the constants —
  `format!("{:.2}", DEFAULT_BASE_PROBABILITY)` giving
  `"0.30"`, `DEFAULT_SKILL_LEVEL.to_string()` giving
  `"4"`, `format!("{:.1}", DEFAULT_DECRYPTOR_MULTIPLIER)`
  giving `"1.0"` — so constants and drafts cannot drift.
- Probabilities and multipliers travel as plain `f64`
  fractions/multipliers at every boundary (`0.30` means
  30%, `1.1` means ×1.1), never as percents — Flutter's
  domain convention, and the reason no `/ 100` or
  `%`-stripping exists anywhere in the module (contrast
  the trade module, whose Flutter source took percents).
  The renderer multiplies by 100 only when formatting the
  result line (section 6).
- Skill levels are `i64` end to end (Flutter's `int`
  parameters; the tree's other EVE quantities are `i64`),
  converted with `as f64` inside the formula exactly where
  Dart's `int / double` promoted them.
- `calculate_probability` returns `Option<f64>`, not a
  struct (section 2): exactly one figure exists. It takes
  all five values explicitly — Rust has no counterpart to
  Dart's `decryptorMultiplier = 1.0` default argument
  (`invention_calculator.dart:15`), so nothing silently
  substitutes 1.0 for a cleared field; Flutter's default
  survives only as the seeded starting text.
- `invention_calculator_result` is the renderer's one
  call: it parses all five texts and returns `Some` only
  when all five parse and `calculate_probability`
  succeeds. The functions are total: no panics, no
  indexing, no unwrap on hostile text or hostile floats.

## 6. Rounding (locked — display only, as in Flutter)

No arithmetic step rounds. Flutter keeps raw `double`
precision end to end (no `round`/`ceil`/`floor` in the
invention files) and rounds only when formatting; the port
keeps that rule exactly. This is deliberately not a claim
about how EVE itself rounds an invention roll in game —
no inspected body states an in-game rounding rule or even
whether the chance is rolled per attempt as shown — so
none is applied or claimed, and the disclosure says the
figures can differ from EVE (section 7).

Display formatting, locked:

- The chance line: `format!("{:.1}%", chance * 100.0)` —
  Flutter's `'${(chance * 100).toStringAsFixed(1)}%'`
  (`invention_calculator_panel.dart:55`), one decimal, no
  thousands grouping (a percent at most 100.0 needs none).
- The input fields show the reader's typed text unchanged;
  the app never reformats a draft while it is being
  edited.

Test literals avoid exact half-way display boundaries, so
Dart-versus-Rust tie rounding is never what a test proves:
Flutter's own oracle values 41.25% and 45.375% sit on
one-decimal boundaries (a Rust probe during design
rendered the raw `f64` results as `41.2%` and `45.4%`, but
those directions are binary-representation accidents, not
Flutter-pinned strings), so they are asserted as raw `f64`
with a `1e-9` absolute tolerance in the pure tests and are
**not** locked as rendered strings. The rendered-string
tests use only off-boundary cases (39.0%, 31.2%, 100.0%,
section 8), each cross-checked by a Rust probe against
the section 2 formula and the `{:.1}` format during
design.

## 7. UI placement and verbatim wording (locked)

New `show_invention_calculator(ui, state)` in
`src/ui/industry.rs`, called from `show()` immediately
after `widgets::mode_notice` (`src/ui/industry.rs:456`)
and **before** the no-character early return (lines
457–460). Placement rationale: the calculator needs no
character, no job, and no blueprint — Flutter's panel is
hard-coded for the same reason — so, like the Market
view's trade calculator before its no-selection return, it
is available in every Industry state: no character,
loading, empty, error, ready, offline, and demo, rather
than only inside the `Ready` arm (lines 473–485) where it
would vanish for every reader the step-up scopes still
block. It sets no request flag, fetches nothing, and
touches neither section, keeping the view's read-only
contract (module doc, lines 1–6). Consequences locked:
the no-character state gains the calculator block above
the no-character panel, and Builder B updates no existing
test expectation, because today's industry tests assert
pure row/filter helpers, never `show()` output.

Layout follows the trade calculator's shipped block
(`src/ui/market.rs` `show_trade_calculator`): a heading,
then for each of the five drafts a label and a
`ui.text_edit_singleline` on its own row, with
`state.text_input_focused |= response.has_focus()` for
every field so the blueprint search shortcut stays gated
while typing, and `changed()` accumulated across the five
fields. No focus is ever requested for these fields. The
heading and the five input labels below are named
constants in `src/ui/industry.rs`
(`INVENTION_CALCULATOR_HEADING` and
`INVENTION_CALCULATOR_INPUT_LABELS: [&str; 5]`, in field
order) so Builder B can assert them byte-exactly without
an egui frame. There is **no Calculate button**: Flutter
recomputes from live widget state on every build and egui
recomputes every frame, so a button would be a no-op
control. No sliders, dropdown, colour coding
(Flutter coloured the chance by a `> 0.5` test at panel
line 57; no colour is locked — the Industry view's plain
labels carry the wording), or graphics of any kind.

Heading and input labels, verbatim and in order:

```text
Invention Calculator
Base Probability (0 to 1, entered by you)
Encryption Skill Level (1 to 5, entered by you)
Datacore Skill 1 Level (1 to 5, entered by you)
Datacore Skill 2 Level (1 to 5, entered by you)
Decryptor Multiplier (entered by you)
```

The names are Flutter's (`'Base Probability:'`,
`'Encryption Skill'`, `'Datacore Skill 1'`,
`'Datacore Skill 2'`, `'Decryptor:'`; panel lines 100,
105, 110, 150, 179), each extended with the valid range
and the honest source — the reader, not the character or
a blueprint — exactly as the trade calculator extended
Flutter's fee labels, because the range and source are
the slice rules a typed field must state (sections 3, 4).

Result lines, verbatim templates in order, each rendered
as one `ui.label`:

```text
Invention Chance: {chance:.1}%
With entered skills and decryptor
```

The first line follows the view's `Label: value` shape
(`show_jobs_section`, lines 342–372); the name is
Flutter's `'INVENTION CHANCE'` heading (panel line 47) in
the view's sentence case. The second line adapts
Flutter's `'With selected skills and decryptor'` (panel
line 63) by one word — "entered" for "selected" — because
in Flutter the values were selected on sliders and a
dropdown while here they are typed, and "selected skills"
could be misread as the character's skills having been
looked up; the adaptation is recorded here so it is a
decision, not drift. No other result line exists: the
Flutter panel shows no skill factor, base, or multiplier
echo (the fields themselves show what was typed).

When `invention_calculator_result` returns `None`, no
result line renders — instead exactly one guidance line,
chosen in this order (new constants in
`src/ui/industry.rs`, `INVENTION_CALCULATOR_INPUT_GUIDANCE`
and `INVENTION_CALCULATOR_NO_RESULT_GUIDANCE`):

1. If any of the five drafts fails its section 4 parser:

   ```text
   Enter a base probability above 0 and at most 1 (for example 0.30 for 30%), skill levels from 1 to 5, and a decryptor multiplier above 0, to see the result.
   ```

2. Else (all five parse but the calculation rejects them
   — with section 4's parsers the only such case is a
   multiplier so large the product is not finite):

   ```text
   No result: the entered values are too large to calculate with.
   ```

The renderer makes this choice by calling the three pure
parsers again only in the `None` arm; it does not
duplicate the calculation. Neither guidance line contains
a computed figure or any value taken from the drafts: the
only numbers in them are the fixed bounds and the worked
example in their own wording.

**Disclosure**, rendered verbatim under the fields in both
the result and guidance states (new constant
`INVENTION_CALCULATOR_DISCLOSURE` in
`src/ui/industry.rs`):

> Estimate using only the base probability, skill levels,
> and decryptor multiplier you entered. The starting
> values (base probability 0.30, each skill level 4,
> decryptor multiplier 1.0) are starting values to
> replace with your own: Mimir does not read the base
> probability from any blueprint, the skill levels from
> your character, or the multiplier from any decryptor
> you own. The decryptor choices in the retired app were
> None x1.0, Symmetry x1.1, Process x1.2, Parity x1.8, and
> Optimized x0.6; type the multiplier for the decryptor
> you mean. The chance is capped at 100%. There are no
> reaction or production-chain calculators. Figures are
> rounded only for display, so these numbers can differ
> from EVE.

Every clause carries one locked decision: user-entered
inputs only with Flutter's starting values named and every
un-read source named (section 3), Flutter's five decryptor
choices with their multipliers rendered as typed
references rather than an owned-item picker (section 3),
Flutter's cap (section 2), the two deferred calculators
named as absent in the product itself (section 9), and
display-only rounding (section 6).

Logging: the pure module logs nothing (render cadence,
section 5). The renderer emits one
`tracing::debug!("[INDUSTRY] invention calculator input changed")`
when any field's response reports `changed()` — the
`[INDUSTRY]` tag the view already uses — and logs no draft
contents and no computed figure.

## 8. Demo pins and test plan (locked literals)

**Flutter test oracles exist and govern.** Discovery and
design re-reads verified all four cases in
`invention_calculator_test.dart` at `ed698d3` (lines 6–61).
Every pure-module literal below is one of those oracles,
or derived during design from the section 2 formula with
its arithmetic in a comment (the panel-starting and
minimum-skill cases, which Flutter has no test for), and
each was cross-checked by a Rust probe during design.
`f64` assertions use one absolute tolerance of `1e-9` (the
trade module's precedent; Flutter's `closeTo` used 0.0001);
`assert_eq!` is reserved for `None` outcomes, the cap's
exact `1.0`, parser results, and rendered strings.

**Demo mode:** no demo data changes. The block renders in
demo mode exactly as live (starting texts `0.30` / `4` /
`4` / `4` / `1.0`, result `39.0%`) because no input comes
from loaded data (section 3). Nothing copies the demo
invention job's 0.4 probability (`assets/demo/industry.json`,
job 710000203 for character 90000002) or anything from the
demo blueprints (types 681, 682, 683 for character
90000001) into the drafts, and a renderer test proves a
ready demo industry bundle leaves all five drafts untouched
(below), following the market test's demo-independence
shape (`seed_demo_state` leaves drafts untouched).

**Builder A — pure module and state tests**
(`src/invention_calculator.rs`, `src/app/state.rs`):

Flutter oracle 1 (test lines 6–17; decryptor passed
explicitly as 1.0 per section 5):

```text
// skill factor = 1.0 + 5/40 + 5/40 + 5/40 = 1.375
// 0.30 * 1.375 = 0.4125
calculate_probability(0.30, 5, 5, 5, 1.0) = 0.4125
```

Flutter oracle 2 (lines 19–33, Symmetry):

```text
// 0.4125 * 1.1 = 0.45375
calculate_probability(0.30, 5, 5, 5, 1.1) = 0.45375
```

Flutter oracle 3 (lines 35–48, Optimized):

```text
// skill factor = 1.0 + 4/40 + 4/40 + 4/40 = 1.3
// 0.40 * 1.3 = 0.52; 0.52 * 0.6 = 0.312
calculate_probability(0.40, 4, 4, 4, 0.6) = 0.312
```

Flutter oracle 4 (lines 50–61, cap), asserted exactly:

```text
// 0.9 * 1.375 * 1.8 = 2.2275 -> capped at 1.0
calculate_probability(0.90, 5, 5, 5, 1.8) = 1.0 exactly
```

Panel-starting case (design-derived from section 3's
starting values; no Flutter test):

```text
// skill factor = 1.0 + 4/40 + 4/40 + 4/40 = 1.3
// 0.30 * 1.3 * 1.0 = 0.39
calculate_probability(0.30, 4, 4, 4, 1.0) = 0.39
```

Minimum-skill case (design-derived; pins the lower end of
the 1–5 range):

```text
// skill factor = 1.0 + 1/40 + 1/40 + 1/40 = 1.075
// 0.30 * 1.075 * 1.0 = 0.3225
calculate_probability(0.30, 1, 1, 1, 1.0) = 0.3225
```

Validation matrix, one assertion per rule in section 4:
base `0.0`, `-0.1`, `1.1`, `NaN`, `INFINITY`,
`NEG_INFINITY` give `None` (each with otherwise-valid
inputs); each skill position at `0` and at `6` and at `-1`
gives `None` (one bad position at a time, all three
positions covered for `0`, and `6`/`-1` covered in at
least one position each); decryptor `0.0`, `-1.0`, `NaN`,
`INFINITY` give `None`; overflow (`1.0, 5, 5, 5, 1.5e308`,
whose raw product `1.0 * 1.375 * 1.5e308` exceeds the
largest finite double — verified non-finite by the design
probe) gives `None`, pinning that overflow never caps to
1.0. Valid corners that must stay `Some`: base exactly
`1.0` (parses and calculates; with levels 4 and multiplier
1.0 the raw chance `1.3` caps to `1.0`).

Parser cases: `parse_base_probability`: `"0.30"` → `0.3`,
`" 0.5 "` → `0.5`, `"1"` → `1.0`; `""`, `"abc"`, `"NaN"`,
`"inf"`, `"-inf"`, `"0"`, `"-0.1"`, `"1.1"`, `"30"`,
`"30%"` → `None` (the last two pin the fraction-only lock,
section 3). `parse_skill_level`: `"4"` → `4`, `" 5 "` →
`5`, `"1"` → `1`; `"0"`, `"6"`, `"-1"`, `"4.0"`, `""`,
`"abc"` → `None`. `parse_decryptor_multiplier`: `"1.0"` →
`1.0`, `"0.6"` → `0.6`, `"1.8"` → `1.8` (Flutter's
dropdown values); `"0"`, `"-1"`, `""`, `"NaN"`, `"x1.0"` →
`None`.

`invention_calculator_result` cases: the five starting
texts (`"0.30"`, `"4"`, `"4"`, `"4"`, `"1.0"`) give `Some`
at `0.39`; any one text invalid gives `None` (one case per
field, five cases); the overflow texts (`"1"`, `"5"`,
`"5"`, `"5"`, `"1.5e308"`) all parse but give `None`.
Defaults case: `DEFAULT_BASE_PROBABILITY = 0.30`,
`DEFAULT_SKILL_LEVEL = 4`, `DEFAULT_DECRYPTOR_MULTIPLIER =
1.0`. State cases: `AppState::new(false)` has drafts
`"0.30"`, `"4"`, `"4"`, `"4"`, `"1.0"` (formatted from the
constants), and `set_active_character` leaves all five
drafts unchanged across a switch (the
`industry_search`-survival test shape).

**Builder B — renderer tests** (`src/ui/industry.rs`), in
the file's existing test style. Line-building is factored
so the strings are testable without an egui frame,
following the market block: Builder B adds a pure
`invention_calculator_lines(state: &AppState) -> Vec<String>`
helper that returns every line after the heading and input
rows (result lines plus disclosure, or guidance plus
disclosure), and `show_invention_calculator` renders
exactly those strings. Tests assert:

- Verbatim heading, the five input labels, both guidance
  constants, and the disclosure constant (byte-exact
  against section 7).
- The full starting-value result: drafts `0.30` / `4` /
  `4` / `4` / `1.0` give exactly `Invention Chance: 39.0%`,
  `With entered skills and decryptor`, then the disclosure
  (`0.30 × 1.3 × 1.0 = 0.39`, off-boundary per section 6).
- Flutter oracle 3 typed as drafts (`0.40` / `4` / `4` /
  `4` / `0.6`) gives `Invention Chance: 31.2%` (raw 0.312).
- Flutter oracle 4 typed as drafts (`0.90` / `5` / `5` /
  `5` / `1.8`) gives `Invention Chance: 100.0%` (raw 2.2275,
  capped) — a genuinely computed boundary shown, never
  the overflow corner.
- Guidance selection: any one draft emptied or invalid
  (one case per field, including base `0` and skill `0`)
  gives exactly the input-guidance line followed by the
  disclosure; the overflow drafts (`1` / `5` / `5` / `5` /
  `1.5e308`) give exactly the no-result-guidance line
  followed by the disclosure. No result line and no
  percentage appears in either state (asserted by
  whole-vector equality, so no stray `0.0%` line can hide
  between them).
- Demo independence: a state whose industry bundle is
  `Ready` from demo seeding leaves the five drafts exactly
  as constructed (no prefill from the demo invention job's
  0.4 probability or any demo blueprint, section 3), and
  the seeded starting drafts render the `39.0%` block in
  that state.
- Regression: every existing industry test passes
  unmodified — this slice inserts one block before the
  no-character return and rewords no existing line.

**Gates (every commit):** `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, `cargo test`,
`cargo build`.

## 9. Deferrals and exclusions (locked — ship-nothing lines are explicit)

- **Reaction calculator: deferred, ships nothing.** Exact
  missing data, all required before any reaction UI is
  honest: (a) a Rust loader for the SDE activity-11 tables
  already on disk in `assets/sde/industry.json` —
  `materials` (36,193 rows, `{typeId, activityId,
  materialTypeId, quantity}`) giving per-run base inputs
  keyed by reaction blueprint type, and `products` (6,266
  rows, `{typeId, activityId, productTypeId, quantity}`)
  giving per-run outputs — with its own struct, bundled
  load, and `[INDUSTRY]`-tagged logging in the shape of the
  three existing SDE loaders; (b) a way for the reader to
  choose a reaction blueprint by resolved name (the loaded
  blueprint library carries `type_id`s but nothing in Rust
  today can say which owned blueprint is a reaction
  formula, and the Industry view never renders a raw
  numeric ID, `src/ui/industry.rs:1–6`). Name resolution
  itself is *not* missing (`NameResolver::name` + the
  shell's scheduling pattern could resolve material/product
  names once ids come from a loader). What Flutter shipped
  proves the deferral: its panel feeds the domain two
  hard-coded dummy maps (`{16641: 100, 16642: 100, 16643:
  100}` → `{16654: 10}`, `reaction_calculator_panel.dart:
  22–30`, commented `// Dummy base inputs and outputs for
  testing`) and renders each row as `Item #<id>`
  (lines 198, 251). Porting that panel would ship invented
  quantities against raw IDs; porting only the domain
  functions would ship dead code whose only possible
  caller is that panel. Recorded here for the future
  slice, not ported: Flutter's verified arithmetic
  (`round(runs × baseQty × (1 − facilityBonus))` on the
  multiplied total, then a floor of 1, `reaction_calculator.dart:
  21–27`; outputs are exact `qty × runs`), its test oracles
  (`100 → 95` at a 0.048 bonus for 1 run, `→ 952` for 10
  runs, outputs `10 × 5 = 50`; `reaction_calculator_test.dart:
  18, 32–33, 49`), and its hard-coded facility-bonus choices
  (`0 / 0.02 / 0.024 / 0.028 / 0.04 / 0.048 / 0.056` labelled
  with Athanor/Tatara rig names, panel lines 115–143 — code
  comments are their only source; Live accuracy remains
  unverified for the future slice to establish). Note also
  for that slice: Flutter's panel never lets the reader
  edit the material lists, so any future typed-quantity
  editing is new product behaviour to design there, and
  Dart's `double.round()` tie behaviour versus Rust's must
  be decided from the oracles, not assumed.
- **Production chain: deferred, ships nothing.** Exact
  missing data: (a) the same `industry.json` loader, here
  for `materials` rows at activities 1 (manufacturing) and
  11 (reaction) traversed recursively
  (`materials[typeId][activityId] → [{materialTypeId,
  quantity}]`), since `ProductionChainBuilder` is that
  traversal (`production_chain_builder.dart:48–91`:
  `matQty = mat.quantity × quantity`, probe activity 1
  before 11, recurse); (b) a decided name source per node —
  Dart used skill-name then ship-type-name fallbacks
  (lines 43–45) with no Rust equivalent ordering, while
  Rust's `NameResolver` is ESI/database-backed and needs
  its scheduling extended before arbitrary chain ids
  resolve honestly; (c) a cycle/depth decision — Flutter
  recurses unbounded with no guard, which a Rust port must
  not copy blindly and must not silently invent either.
  Recorded, not ported: Flutter's single test oracle (a
  mocked empty-materials item, type 34 "Tritanium", quantity
  1, raw material; `production_chain_builder_test.dart:
  18–32`) and its visualizer's invented Paladin tree
  (`production_chain_visualizer.dart:21–68`, including
  12,000,000 Tritanium) — the latter is dummy UI data and
  is never an oracle for anything. The Tree/`2D Canvas`
  toggle and its `'Drag and drop functionality coming in
  next iteration.'` placeholder (visualizer lines 95–111,
  217–224) ship nothing and are not recreated even as a
  disabled control.
- **No SDE industry loader in this slice at all.** This
  slice adds no `include_str!` of `assets/sde/industry.json`,
  no loader struct, and no startup wiring — not even for
  the probabilities table (see next item). The file stays
  bundled-but-unloaded; the future data slice owns its
  whole loading and logging decision.
- **No auto-fill of any invention input.** No base
  probability from a blueprint's (unloaded) activity-8
  probability row, no skill level from the character's
  loaded skills, no multiplier from an owned decryptor
  asset, no probability from a loaded job's carried
  probability field (section 3 each). No blueprint,
  decryptor, or job picker exists in this slice, and the
  blueprint search/kind-filter state is untouched.
- **No manufacturing calculator.** Flutter has none: the
  industry domain directory at `ed698d3` contains exactly
  the three files above (verified by `git ls-tree`). The
  blueprint library already loads material and time
  efficiency values (`BlueprintRow`, `src/ui/industry.rs:
  163–175`), but no inspected body applies an ME value to
  a material list, so no "materials for N runs" figure is
  computed from an owned blueprint in this slice; the
  reaction rounding rule is never generalized to
  manufacturing.
- **No derived invention figures.** No expected attempts
  or success-over-runs probability (e.g. no `1/chance` or
  at-least-one-success figure), no chance breakdown or
  skill-factor line, no datacore/decryptor costing, no ISK
  figure of any kind, no history or comparison across
  blueprints — Flutter computed none of them.
- **No persistence and no writes.** The five drafts live
  only for the session; no job can be started, cancelled,
  or delivered; the view sets no new request flag and
  needs no new EVE SSO scope, no character, and no
  network for the calculator block.
- No change to `IndustryData` (its field set is a
  cross-builder contract, `src/app/state.rs:429–437`),
  `industry_job_rows`, `blueprint_rows`, the blueprint
  filter, the step-up panel, ESI endpoints or models (the
  carried-but-unrendered job probability stays exactly
  that), the shell's industry name scheduling, or demo JSON.

## 10. Integrator list

- **README** (Industry bullet, line 20): replace "Nothing
  industry-related is stored, no job can be started,
  cancelled, or delivered, and there is no production,
  cost, or profit calculator." with "The view also carries
  an invention calculator: you type a base probability as
  a fraction (0.30 means 30%), your encryption and two
  datacore skill levels, and a decryptor multiplier
  (starting values 0.30, each skill level 4, and 1.0,
  never read from a blueprint, your character's skills, a
  decryptor you own, or a past job), and it shows the
  invention chance, capped at 100%, rounded only for
  display; an empty or invalid field shows guidance
  instead of any figure. There are no reaction or
  production-chain calculators, and no production, cost,
  or profit calculator. Nothing industry-related is
  stored, and no job can be started, cancelled, or
  delivered." No Roadmap-bullet change: the roadmap list
  (lines 28–32) has no industry-calculator bullet to amend
  (verified during design).
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): one entry with Evidence/Mechanism/rule — data
  the app *has* is not data a calculator may *use*: a
  bundled-but-unloaded SDE table, a readable skill level,
  and a job's carried probability are each one loader,
  mapping, or meaning short of the figure they resemble,
  so two of the three Flutter "calculators" turned out to
  be dummy data over an unloaded graph and only the closed
  scalar formula could ship (sections 3, 9) — and Flutter's
  cap test turning an infinite product into a plausible
  1.0 is the porting corner where the finiteness check must
  run *before* the cap (sections 2, 4).
- Nothing else: no HANDOFF change beyond what the parent
  directs, no demo-data, ESI, scope, storage, or SDE-asset
  change. If build discovery contradicts any literal in
  section 8, the slice stops rather than growing scope.

## 11. Ownership and commit split

- **Design (this commit):** `docs/industry-calculators-design.md`
  only. Commit: `docs(industry): design industry calculators`.
- **Builder A — pure calculation and draft state:** new
  `src/invention_calculator.rs`, `src/lib.rs` module
  registration, the five `AppState` draft fields and their
  `AppState::new` seeding in `src/app/state.rs`, and the
  section 8 Builder-A tests. Commits:
  `feat(industry): add pure invention calculator`,
  `feat(industry): add invention calculator draft state`.
- **Builder B — render:** `src/ui/industry.rs` only (block,
  line helper, constants, section 8 Builder-B tests).
  Commit: `feat(industry): show invention calculator in industry view`.
- **Integrator:** README and journal per section 10, full
  gates, and a demo-mode check that the block shows the
  starting-value `39.0%` result with the demo bundle loaded
  (drafts untouched by seeding) and the input guidance when
  a field is cleared. Commit:
  `docs(industry): document invention calculator`.

Builder B touches no `src/invention_calculator.rs`,
`src/lib.rs`, or `src/app/state.rs` file and codes against
sections 5 and 7's locked API and wording; Builder A
touches no `src/ui/` file. Small atomic commits,
`type(scope): description`, no attribution lines. Nobody
pushes or merges; the parent does that.
