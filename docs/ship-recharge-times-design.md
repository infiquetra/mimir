# Ship recharge times — design

Status: locked for the `feat/rust-ship-recharge-times` slice (built inline
by the parent session, proportional to #575). Base: `develop` at `55bee6f`.

## 1. Goal and value ranking

Show the hull's base shield recharge time and capacitor recharge time in the
existing "Ship (base values)" block (#578), after Max speed. Ranking: never
a base time mistaken for a fitted recharge > correctness > reuse.

## 2. Attributes and units (grounded)

- 479 `shieldRechargeRate` ("Shield recharge time") and 55 `rechargeRate`
  ("Capacitor Recharge time"), read directly from `dogmaAttributes.jsonl`
  in `scripts/sde/eve-online-static-data-3503375-jsonl.zip`; both unit 101
  ("Milliseconds", display `s` in `dogmaUnits.jsonl`). Values are whole
  recharge durations in milliseconds (Rifter 587: 625000 / 125000 in
  `dgmTypeAttributes.csv.bz2`; Punisher 597: 625000 / 160000).
- Flutter at `ed698d3`: `dogma_attributes.dart` line 6
  `capacitorRechargeTime = 55`, line 13 `shieldRechargeTime = 479`;
  `stats_panel.dart` renders capacitor recharge as `(value / 1000)` with
  one decimal + ` s`. Conversion is therefore `ms / 1000` seconds, never
  recalled.
- Coverage audit (cache × committed catalogue, run during design): all 404
  category-6 ships carry both attributes (479: 260000–20000000 ms;
  55: 62500–7500000 ms). Emission is category-6 only, like the other base
  stats.

## 3. Catalogue extension

`BASE_STAT_ATTR_IDS` gains {479, 55} with constants
`SHIELD_RECHARGE_ATTR` / `CAPACITOR_RECHARGE_ATTR`; emission appends
SDE-verbatim keys `shieldRechargeRate` then `rechargeRate` after
`maxVelocity` in the category-6 block (values stay raw milliseconds,
never pre-converted — the #579 raw-storage rule). Existing loud-failure
rules apply unchanged (duplicate/unparseable/non-finite/negative). New
oracle pins in `SHIP_STAT_ORACLES` (587: 625000/125000, 597: 625000/160000)
and the None-key list grows both keys. The catalogue-wide invariant grows
to all seven base-stat keys. Determinism proofs as before: generator run
twice identical; stripped-new-keys output byte-identical to the pre-slice
catalogue.

## 4. Pure API and availability

`ShipBaseStats` gains `shield_recharge_secs` and `capacitor_recharge_secs`
(`Option<f64>`, seconds — conversion inside the pure function so every
consumer shares it). Usable = present, finite, non-negative (the #578
`usable` predicate). A present `0.0` ms renders as a real `0.0 s`; an
absent stat omits its line. `Available` now means at least one of the
seven stats is usable; #578 five-stat behavior is otherwise unchanged.

## 5. UI

Two lines appended to the existing block after Max speed, via the shared
`ship_base_stat_lines` helper and `format_fitting_amount(v, "s")`:
`Shield recharge: 625.0 s`, `Capacitor recharge: 125.0 s`. Labels come
from the SDE display names shortened like the sibling lines ("Capacitor
capacity" precedent). The block disclosure already covers these lines
("Base values from Mimir's bundled item data… are not applied"); wording
is unchanged. `render_ship_base_stats`, resources, resistances, and EHP
blocks are untouched.

## 6. Exclusions

No recharge *rates* (HP/s or GJ/s curves — EVE recharge is non-linear and
no grounded curve body was inspected), no capacitor stability, no
modifiers of any kind, no new ESI/scope/storage changes.

## 7. Tests

Generator oracles above; loader invariants (all seven Some on ships,
none outside category 6, spot pins); pure conversion pins (Rifter
625.0/125.0 s, Punisher 625.0/160.0 s); renderer lines present after Max
speed in demo pins (existing demo-stat test lines grow by two entries —
the one deliberate expectation change, recorded here); regeneration
byte-identity.
