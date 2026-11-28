# Planetary Industry colony summary — design

Status: locked for the `feat/rust-pi-colony-summary` slice.
Base: `develop` at `773cb5a` (997 tests stated at slice start;
this design commit re-runs the section 13 gates).
Slice branch: `feat/rust-pi-colony-summary`.

Discovery: two read-only reports — one on the retired Flutter
Planetary Industry (PI) derivations, one on the Rust planets
detail view, its clock pattern, and the shipped demo pins.
During design the decisive bodies were re-read directly
(`git show ed698d3:` for
`lib/features/pi/presentation/widgets/colony_card.dart` lines
40–126 and `lib/core/utils/formatters.dart` lines 48–59; the
Rust bodies `src/ui/planets.rs` in full including its tests,
`src/ui/widgets.rs` lines 133–203 and 281–396,
`src/esi/models.rs` lines 595–690, `src/ui/industry.rs` lines
400–432, and `assets/demo/planets.json` in full). No EVE
behaviour here is recalled from outside those bodies.

**Grounded verdict up front:**

- **The colony summary ships in this slice.** At the top of
  the selected-colony detail, above "Pin types", the reader
  sees whether any extractor is running (`Extracting` /
  `Idle`), the reported pin count, the time until the next
  extractor completes when one is running, and the extractor
  count — all derived from the already-loaded pins of the one
  selected colony by one new pure function,
  `colony_summary` (sections 3–7).
- **The derivation is Flutter's, exactly.** A pin is an
  extractor when it carries a product, an extractor is
  active only when its expiry is strictly in the future, and
  the next completion is the earliest future expiry among
  extractor pins (section 2). Two Rust-side guards are named
  where they narrow Flutter: a non-positive product ID does
  not count (so the summary count agrees with the shipped
  Extractors section below it), and the duration is formatted
  with the Rust app's existing countdown formatter, not
  Flutter's (sections 4, 6).
- **Nothing is fetched and nothing is written.** The summary
  reads only `detail.pins` and the matching colony's reported
  pin count, both already loaded; Planetary Industry
  management — colony edits, extractor restarts, routing, any
  write of any kind — ships nothing in this slice
  (section 11).

## 1. Goal and value ranking

The Rust detail view lists what a colony contains (pin types,
extractor products, stored items) but never says whether the
colony is doing anything right now or when its next extractor
finishes — the two facts the retired Flutter colony card led
with. This slice adds that four-line summary.

Value ranking (locked, in order):

1. **Never a fabricated time.** No parseable future expiry
   means the verbatim placeholder `N/A`, never a guessed,
   clamped, or "paused" duration; an expiry string that fails
   to parse is ignored, never repaired (sections 4, 5, 7).
2. **Flutter's semantics, not a reinvention.** Extractor
   membership, the strict-future active test, and the
   earliest-future choice are copied line for line
   (section 2); every deviation is named in place.
3. **Honest states are distinguishable.** Flutter collapsed
   no-extractors, no-expiry-data, and all-expired into one
   `Idle`; Rust keeps Flutter's status word and `N/A` but
   names which of the three happened, in one sentence
   (section 7).
4. **Reuse.** One pure helper beside its three siblings in
   `src/ui/planets.rs`, the existing `parse_esi_date` /
   `format_countdown` in `src/ui/widgets.rs`, and the
   per-render `Utc::now()` sampling pattern from
   `src/ui/industry.rs`. No clock abstraction, no new module.

## 2. The Flutter semantics (quoted)

From `colony_card.dart` at `ed698d3`, re-read during design:

```dart
final extractorPins = pins.where((p) => p.productTypeId != null).toList();
final hasActiveExtractors = extractorPins.any(
  (p) => p.expiryTime != null && p.expiryTime!.isAfter(DateTime.now()),
);
final statusText = hasActiveExtractors ? 'Extracting' : 'Idle';
DateTime? nextCompletion;
if (hasActiveExtractors) {
  for (final pin in extractorPins) {
    if (pin.expiryTime != null && pin.expiryTime!.isAfter(DateTime.now())) {
      if (nextCompletion == null || pin.expiryTime!.isBefore(nextCompletion)) {
        nextCompletion = pin.expiryTime;
      }
    }
  }
}
```

Consequences locked from that body:

- **Extractor counting:** a pin counts iff its nullable
  `productTypeId` is non-null — pin type, schematic, and
  expiry are irrelevant. The `Extractors` row shows the
  total extractor count, expired and expiry-less pins
  included, never an active-only count.
- **Active predicate:** among extractor pins only, at least
  one expiry strictly after the moment of evaluation
  (`isAfter` is strict; expiry exactly equal to now is
  inactive). A non-extractor pin with a future expiry can
  never make a colony active; it is filtered out first.
- **Next completion:** the earliest future expiry among
  extractor pins, computed only when active; when inactive
  it stays null and the row shows `N/A` verbatim. It is
  never seeded from an expired or null expiry.
- **"Active Pins" is not an active count.** The row so
  labelled shows the stored colony `numPins` field (ESI's
  `num_pins`), not a computed count and not the length of
  the pins list. If the stored value disagrees with the
  loaded pins, the stored value wins. Section 4 keeps this
  meaning; section 12 records the trap.
- **Verbatim card strings:** `Extracting`, `Idle`,
  `Active Pins`, `Next Completion`, `Extractors`, `N/A`,
  in row order Upgrade Level, Active Pins, Next Completion,
  Extractors (the status word sat in a pill above the rows).
  `formatDuration` renders e.g. `2d 4h 32m` with no seconds
  part and `0m` for zero; section 6 does not port it.

## 3. The pure function (locked API)

One new public helper in `src/ui/planets.rs`, placed with the
other pure helpers after `storage_content_rows`, with one new
import line `use chrono::{DateTime, Utc};` (Builder A adds it;
Builder B's renderer uses the same line):

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ColonySummaryState {
    NoPins,
    NoExtractors,
    NoExpiryData,
    AllExpired,
    Extracting,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ColonySummary {
    pub state: ColonySummaryState,
    pub status_label: &'static str,
    pub extractor_count: usize,
    pub active_extractor_count: usize,
    pub next_completion: Option<DateTime<Utc>>,
    pub next_completion_label: String,
    pub active_pins_label: String,
    pub state_note: Option<&'static str>,
}

pub fn colony_summary(
    pins: &[PlanetPin],
    reported_pins: Option<i64>,
    now: DateTime<Utc>,
) -> ColonySummary
```

Like its siblings (`colony_rows`, `pin_type_counts`,
`extractor_product_rows`, `storage_content_rows`) the
function is pure, total (no panic path on any wire value),
and returns display-ready fields so the renderer only prints.
All wording therefore lives in this function and is testable
without any widget test (section 10).

The two non-pin inputs:

- `reported_pins` is the matching colony's stored `num_pins`
  (section 2's "Active Pins" value), passed as `Option`
  because the colonies section can have failed while the
  detail section succeeded. Deriving the value from
  `pins.len()` instead was considered and rejected: Flutter
  renders the stored count even when it disagrees with the
  loaded pins, and the colonies list directly above already
  renders the same stored count as `Pins: {n}`; two
  different numbers for one concept on one screen would be
  a Rust-invented contradiction.
- `now` is an input, never sampled inside (section 5).

## 4. Semantics, step by step

One pass over `pins`, in input order (counts and a minimum
are order-independent; no sort is applied or needed):

1. **Extractor test (per pin):**
   `pin.extractor_details.as_ref().and_then(|d|
   d.product_type_id).filter(|id| *id > 0).is_some()` — the
   identical filter chain `extractor_product_rows` already
   uses at `src/ui/planets.rs:118-119`. Named deviation from
   Flutter's `productTypeId != null`: `Some(0)` and negative
   product IDs do not count. Reason: they are malformed wire
   values that can never resolve to a name, and with this
   guard the summary's `extractor_count` always equals the
   number of rows the Extractors section below derives from
   the same pins — an invariant section 10 pins. Every
   other pin (no `extractor_details`, or
   `product_type_id: None`) is a non-extractor and is
   invisible to every later step, expiry included.
2. **Expiry parse (extractor pins only):**
   `pin.expiry_time.as_deref().and_then(widgets::parse_esi_date)`.
   `None` expiry, an empty string, and any string
   `parse_esi_date` rejects (`widgets.rs:152-156`, RFC 3339
   or `None`) all yield "no expiry instant" for that pin:
   the value is ignored, never trimmed, repaired, or
   guessed, and never rendered verbatim (a pseudo-date
   string can be a raw ID). Each ignored present-but-
   unparseable string increments the log-only
   `unparseable_expiry` count (section 8); a `None` expiry
   does not (absent is not malformed).
3. **Active test (per pin):** an extractor pin with a parsed
   expiry `t` where `t > now` (strict; `t == now` is
   inactive, Flutter's `isAfter`). `active_extractor_count`
   counts these; the colony is extracting iff the count is
   above zero (Flutter's `any`, with the count kept for the
   log line and tests).
4. **Next completion:** `next_completion` is the minimum `t`
   over active pins, `None` when none are active. Equal
   instants need no tie-break (only the instant is kept).
5. **State, in precedence order:** `NoPins` when
   `pins.is_empty()`; else `NoExtractors` when
   `extractor_count == 0`; else `Extracting` when
   `active_extractor_count > 0`; else `NoExpiryData` when no
   extractor pin produced a parsed expiry at all; else
   `AllExpired`. A mix of unparseable and past expiries is
   `AllExpired` (a parsed expiry exists and none is future;
   the unparseable ones are ignored per step 2).
6. **Derived fields:**
   - `status_label`: `"Extracting"` iff state is
     `Extracting`, else `"Idle"` (including `NoPins`, whose
     label the renderer suppresses, section 7).
   - `next_completion_label`: for `Some(t)`,
     `format!("in {}", widgets::format_countdown((t - now).num_seconds()))`;
     for `None`, `"N/A"`. `num_seconds()` truncates toward
     zero and `t > now`, so the value is never negative; a
     sub-second gap yields `0` and therefore `"in 0m"`,
     because production `now` carries sub-second precision
     while ESI strings are second-precise. Section 10 pins
     both that edge and the sub-minute `"in 30s"` arm of
     `format_countdown` (`widgets.rs:133-149`).
   - `active_pins_label`: `Some(n)` → `n.max(0)` rendered as
     a decimal (the clamp copies `colony_rows` at
     `planets.rs:45-46`); `None` → `"N/A"`.
   - `state_note`: `None` for `Extracting` and `NoPins`;
     otherwise the exact sentences locked in section 7.

No other pin field is read: `install_time`,
`last_cycle_start`, `schematic_id`, `qty_per_cycle`,
`cycle_time`, contents, latitude, and longitude play no part
(Flutter persisted several of these and derived from none).

## 5. How "now" enters

There is no application clock to reuse: the app samples the
wall clock once per render and passes the value down —
`industry.rs:403` (`let now = Utc::now();` before its row
loop), `skills.rs:351`, and `dashboard.rs:54` all do this,
and every pure date helper in `widgets.rs` (lines 159, 165,
190) takes `now: DateTime<Utc>` as a parameter. This slice
copies that pattern exactly:

- `colony_summary` takes `now` as an input and contains no
  `Utc::now()` call. One sampled `now` decides every pin in
  a call (Flutter re-sampled per pin; nothing observable
  could depend on the difference, and one sample makes the
  strict boundary in section 10 testable).
- Builder B's renderer samples `let now = Utc::now();` once,
  inside the detail section's `Ok(detail)` arm, immediately
  before calling `colony_summary`. No state field, timer, or
  repaint scheduling is added; the label refreshes whenever
  the view already repaints, exactly like the industry
  countdowns.
- Tests never use the wall clock as an oracle. They pin
  `now` by fixed strings with the shipped test idiom copied
  from `widgets.rs:281-283` and `wallet.rs:330-332`:
  `parse_esi_date("2026-11-15T12:00:00Z")`. This is also why
  the demo colonies of section 9 stay "extracting" in tests
  forever while live demo at a later real date honestly
  shows `Idle`.

## 6. Labels and formatting (verbatim register)

New strings are confined to `colony_summary` and one heading;
the renderer composes only the established
`"{Label}: {value}"` single-label shape of its siblings
(`"Upgrade level: {}"`, `planets.rs:263`;
`"Status: {}"`, `industry.rs`).

| String | Source |
|---|---|
| `Extracting`, `Idle` | Flutter `statusText`, verbatim, title case as stored. Rust does not apply Flutter's render-time uppercasing, and the dashboard card's `IDLE` is deferred with that card (section 11). |
| `Active Pins`, `Next Completion`, `Extractors` as row labels | Flutter `_InfoRow` labels verbatim, in Flutter's order (status, Active Pins, Next Completion, Extractors). |
| `N/A` | Flutter verbatim, for both no-next and no-reported-count. |
| `in 5d 20h 0m` shape | Rust `countdown_label`'s own wording (`"in {format_countdown}"`, `widgets.rs:169`), so planetary and industry countdowns read alike. Named deviation: Flutter's `formatDuration` omits zero hours next to days and has no seconds arm; `format_countdown` keeps `0h 0m` and renders `Xs` under a minute. The instant chosen is Flutter's; only its rendering is the Rust app's. |
| `Colony summary` (heading), `Status: …` (row prefix) | New Rust strings in the view's sentence-case heading style (`Pin types`, `Stored items`); `Status:` copies the industry row prefix. |
| The three state sentences | New Rust strings, section 7. Flutter had none. |
| `paused` | Explicitly **not** used. `countdown_label(None, _)` returns it (`widgets.rs:167`) and it is wrong for "no expiry reported"; the summary never calls `countdown_label`. |

`Upgrade Level` / `Level {n}` is not repeated in the summary:
the colonies list directly above already renders
`Upgrade level: {n}` for the selected colony
(`planets.rs:263`). No absolute completion date is shown —
Flutter shows the duration only, and the industry
`Ends: {date} ({countdown})` shape is not imported here.
No raw numeric ID can appear: every value is a count, one of
the words above, or a duration built from a parsed date.

## 7. Renderer placement and honest states

Builder B changes `show_detail_section` only, inside the
existing identity-gated `Ok(detail)` arm, immediately after
`let pins = &detail.pins;` (`planets.rs:299`) and before
`ui.heading("Pin types")` (line 300). At that point it:

1. samples `now` once (section 5);
2. finds the reported pin count for the selected planet in
   the already-loaded colonies section —
   `bundle.colonies` `Ok` list, first entry whose
   `planet_id == selected_planet`, mapped to `num_pins`;
   `None` on a colonies error or no match;
3. calls `colony_summary(pins, reported_pins, now)`;
4. renders `ui.heading("Colony summary")` and, by state:

| State | Exactly what renders |
|---|---|
| `NoPins` (no pins loaded) | One line, the existing shipped wording reused verbatim: `No pins were reported for this colony.` No status, count, or time row — an `Idle`/`0` block here would claim knowledge the empty pin list does not carry. (The Pin types section below prints the same sentence; the repetition matches how each existing section already states its own emptiness.) |
| `NoExtractors` (pins loaded, none is an extractor — "none active" because none exist) | The four rows below, then `state_note`: `No extractor pins were reported, so nothing is extracting.` |
| `NoExpiryData` (extractors exist, none reported a parseable expiry) | The four rows, then: `No extractor reported an expiry time, so no completion can be shown.` |
| `AllExpired` (parseable expiries exist, all at or before `now`) | The four rows, then: `All extractor expiry times are in the past.` |
| `Extracting` | The four rows and no note. |

The four rows, exact format strings in order:
`Status: {status_label}`, `Active Pins: {active_pins_label}`,
`Next Completion: {next_completion_label}`,
`Extractors: {extractor_count}`. In every inactive state
they therefore read `Idle` and `N/A` — Flutter's collapse —
and the one state sentence says which honest reason applies.
No render cap is needed (the block is at most six lines).

Placement inside the gated arm gives the block the section's
existing behaviour for free and Builder B adds no other
branch: no selection → the shipped select-a-colony line; a
selection whose detail has not landed → `Loading colony
detail...`; a detail section error → the shipped
`section_error_label`. The block can only ever describe the
stamped `(character, planet)` selection, the only colony
whose pins are loaded. The Colonies list, the step-up panel,
and the three existing subsections render byte-for-byte as
before.

## 8. Logging

`[PI]` is the tag (the module doc's feature; siblings at
`planets.rs:58, 94-98, 137, 177-181`).

- **Builder A (pure helper) logs one debug line per call**,
  like each sibling, carrying counts only:
  `tracing::debug!("[PI] colony summary pins={} extractors={} active={} state={:?} unparseable_expiry={}", …)`
  with the pin total, extractor count, active count,
  resulting state, and section 4's ignored-malformed count.
  No planet, pin, or product ID and no expiry string is
  logged (IDs are invisible tie-breaks in this module, and a
  rejected date string can be one).
- **Builder B (renderer) adds no logging at all**, matching
  the three sibling render blocks; the existing `[PI]` retry
  and step-up lines are untouched.
- No `info!`/`warn!` anywhere in the slice: an expired or
  expiry-less colony is normal data, not an event.

## 9. Demo pins (shipped fixtures, unchanged)

`assets/demo/planets.json` already carries every shape the
summary must survive, so this slice changes no demo data:

- Planet `700000001` (character `90000001`, the demo-selected
  colony, `num_pins: 4`): pins `700000011` (product 34,
  expiry `2026-11-21T08:00:00Z`) and `700000012` (product 36,
  same expiry) are extractors; `700000013` has no
  `extractor_details` and no expiry keys; `700000014` has
  explicit `"expiry_time": null` and no extractor details.
  At the pinned test `now` of `2026-11-15T12:00:00Z`:
  extractor count 2, active 2, next `2026-11-21T08:00:00Z`,
  label `in 5d 20h 0m` (Nov 15 12:00 → Nov 21 12:00 is 6
  days, minus 4 hours). Section 10 rebuilds these four pins
  as in-code literals, following the file's existing test
  style rather than loading the fixture.
- Planet `700000002`: extractor pin `700000021`, expiry
  `2026-11-19T08:00:00Z` (`in 3d 20h 0m` at test `now`);
  planet `700000101`: extractor pin `700000111`, expiry
  `2026-11-20T08:00:00Z` (`in 4d 20h 0m`). These two are
  demo-check material for the integrator (section 12), not
  unit literals.

## 10. Test literals

All tests are Builder A's, in the existing
`src/ui/planets.rs` test module, with two local helpers
locked: `now()` returning
`widgets::parse_esi_date("2026-11-15T12:00:00Z")` (fallible
setup uses `.expect("fixed test date parses")`, copying
`widgets.rs:282`), and `extractor_pin(pin_id, product_id,
expiry)` building a `PlanetPin` with `type_id: 20001` (the
module's existing demo extractor type) and
`..Default::default()` elsewhere. Every assertion compares
full fields or whole structs (`ColonySummary: PartialEq`),
never a substring. Expected values, each with its arithmetic:

1. **Empty pins** (`reported_pins: Some(4)`): state `NoPins`,
   both counts 0, `next_completion: None`, labels
   `"Idle"` / `"N/A"` / `"4"`, `state_note: None`.
2. **Non-extractors cannot activate**: one pin with no
   `extractor_details`, one with `product_type_id: None`,
   both expiry `2026-11-20T12:00:00Z` (now + 5 days) → state
   `NoExtractors`, counts 0/0, next `None`, note
   `"No extractor pins were reported, so nothing is extracting."`
3. **Non-positive products do not count**: extractor details
   with `Some(0)` and `Some(-3)`, future expiries → same
   result as case 2; and on a mixed set (those two plus one
   `Some(34)` expired pin), `extractor_count` equals
   `extractor_product_rows(&pins, &resolver()).len()` — the
   section 4 invariant, 1 in this fixture.
4. **No expiry data**: three `Some(34)` extractor pins with
   expiry `None`, `Some("")`, `Some("not-a-date")` →
   `extractor_count: 3`, active 0, state `NoExpiryData`,
   next `None` / `"N/A"`, note `"No extractor reported an expiry time, so no completion can be shown."`
5. **All expired, strict boundary**: expiries
   `2026-11-15T12:00:00Z` (exactly `now` — inactive by
   strictness) and `2026-11-14T12:00:00Z` (now − 1 day) →
   state `AllExpired`, active 0, next `None`, note
   `"All extractor expiry times are in the past."` A sibling
   unparseable expiry added to the same set changes nothing.
6. **Earliest future wins**: extractor expiries
   `2026-11-21T08:00:00Z` (5d 20h out), `2026-11-17T12:00:00Z`
   (2 × 86,400 = 172,800 seconds out), `2026-11-10T12:00:00Z`
   (past), `Some("700000001")` (unparseable pseudo-date) →
   `extractor_count: 4`, `active_extractor_count: 2`, state
   `Extracting`, status `"Extracting"`, next exactly
   `2026-11-17T12:00:00Z`, label `"in 2d 0h 0m"`. The same
   pins in reversed order produce an equal summary.
7. **Duration edges**: expiry `2026-11-15T12:00:30Z` (30
   seconds) → `"in 30s"`; `2026-11-15T12:01:00Z` (60 seconds)
   → `"in 1m"`; a `now` built as `2026-11-15T12:00:00.500Z`
   against expiry `2026-11-15T12:00:01Z` (half a second of
   future, `num_seconds() == 0`) → still `Extracting` with
   label `"in 0m"`, never a negative or empty string.
8. **Demo colony** (section 9's four pins,
   `reported_pins: Some(4)`): state `Extracting`, counts
   2/2, next `2026-11-21T08:00:00Z`, labels `"Extracting"` /
   `"in 5d 20h 0m"` (6 days minus 4 hours = 504,000 seconds)
   / `"4"`, note `None`.
9. **Reported-count arms** on the case 6 set:
   `Some(-2)` → `"0"` (clamped, like `colony_rows`);
   `None` → `"N/A"`; the pins-derived fields identical in
   all three arms, and in particular the value is *not*
   `pins.len()` (4) when `Some(40)` is reported → `"40"`.

Builder B adds no tests: every rendered string is a field
assertion above, and the renderer's remaining moves (block
placement, colony lookup) are covered by compile, review,
and the integrator's demo check, as with sibling blocks.

## 11. Deferred — Flutter PI beyond this summary

Named so nothing reads as silently dropped; none blocks
this slice:

- **Dashboard PI summary card** (grouped colonies across
  characters, `"{n} Colonies across {m} characters"`, the
  countdown rendered in place of the status word, `IDLE`
  uppercase). Deferred: the Rust app loads PI for the
  active character only and has no dashboard PI card; the
  aggregation would need multi-character pin loads the
  state model deliberately does not do.
- **All Characters overview toggle and colony grid.**
  Deferred for the same reason; the Rust view is
  active-character by design.
- **Per-pin expiry display** (an expiry/countdown on each
  Extractors row). Beyond a colony-level summary; the
  shipped extractor rows carry no expiry field and growing
  them is its own slice if wanted.
- **Animated planet, pin dots, glow/status colours.**
  Presentational Flutter machinery with no egui precedent in
  this codebase; the view renders text rows throughout.
- **Any derivation from `qty_per_cycle` / `cycle_time` /
  schematics** (rates, yields, production chains). Flutter
  persisted these fields and never derived from them, so
  there is no oracle to port; inventing PI production maths
  is out of scope.
- **Pull-to-refresh semantics and the "coming soon" detail
  tap.** Not applicable: Rust has a real loaded detail and
  the app-level refresh.
- **Planetary Industry management ships nothing.** Colony
  creation or edits, extractor restart, head placement,
  links/routes editing — no write call, no button, no state
  flag, no new scope. The planets module stays read-only
  exactly as its module doc states; this slice is a readout
  over pins already in memory.

## 12. Integrator list

- **README** (Planets bullet): replace "selecting one colony
  shows its summary — pin counts by resolved pin type,
  extractor products, and stored items aggregated from pin
  contents." with "selecting one colony shows its summary —
  whether an extractor is running and, when one is, how long
  until the next extractor completes (an expired or
  expiry-less colony shows no time rather than a guess) —
  plus pin counts by resolved pin type, extractor products,
  and stored items aggregated from pin contents." The
  bullet's "no colony can be edited or created, no
  extractor can be restarted" stays true and unchanged.
- **Engineering journal**
  (`docs/engineering-journal/LEARNINGS.md`, integrator's
  commit): one entry with Evidence / Mechanism /
  generalizable rule — a source UI's label is not its
  semantics: Flutter's "Active Pins" renders the stored
  `num_pins`, never an activity count, while activity and
  next completion derive only from extractor pins with a
  strictly-future expiry, so a port that trusted the label
  would have shipped a plausible number meaning the wrong
  thing; read the derivation, keep the stored-field meaning,
  and let the states the source collapsed be named by the
  port rather than merged.
- Nothing else: no demo-data, ESI, scope, storage, or
  asset change. Demo check: character `90000001` selected
  colony `700000001` shows `Extracting` while the demo
  expiry (`2026-11-21`) is in the future at check time and
  honestly flips to `Idle` + `All extractor expiry times
  are in the past.` after it, with `Extractors: 2` and
  `Active Pins: 4` in both eras; colony `700000002` shows
  the same shape with `Extractors: 1`. If build discovery
  contradicts any literal in section 10, the slice stops
  rather than growing scope.

## 13. Ownership, commit split, and gates

- **Design (this commit):** `docs/pi-colony-summary-design.md`
  only. Commit: `docs(planets): design colony summary`.
- **Builder A — pure derivation:** the section 3 enum,
  struct, and `colony_summary`, the `chrono` import, the
  section 8 log line, and the section 10 tests — all in
  `src/ui/planets.rs`, no renderer change (an unused-field
  warning cannot arise: the helper is `pub` in a `pub`
  module path like its siblings; if `dead_code` complains
  about the not-yet-read fields, Builder A stops and the
  split is revisited rather than papering with `allow`).
  Commit: `feat(planets): add colony summary derivation`.
- **Builder B — render:** the section 7 block in
  `show_detail_section` (now sampling, colonies lookup,
  heading, state rows) in the same file, after Builder A:
  the overlap is one file by file-ownership, so the two
  builders are sequential, not parallel. No logging, no
  tests, no other file. Commit:
  `feat(planets): show colony summary in colony detail`.
- **Integrator:** README and journal per section 12, full
  gates, and the demo check. Commit:
  `docs(planets): document colony summary`.

Gates for every commit in the slice, in this order:
`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`, `cargo build`. This design commit runs them on
the unchanged base code and records the observed test count
in its report; Builders A and B re-run them and Builder A's
new tests must pass without Builder B's renderer present.

