# DNA fitting export (Copy as DNA) — design

Status: locked for the `feat/rust-fittings-dna-export` slice. Base: `develop`
at `f3771a6` (DNA import merged as #574). This is a small slice built inline
by the parent session, not a workflow; this document records the grounding
and the locked choices the implementation follows.

## 1. Goal and value ranking

Add "Copy as DNA" beside both existing "Copy as EFT" actions (selected saved
fitting, imported fitting), producing the single-line DNA link the EVE client
copies (`shipTypeId:typeId;count:...::`). Ranking: honesty (nothing dropped
without a disclosed count) > round-trip through our own DNA importer >
Flutter `generateDna` parity > convenience.

## 2. Grounding

- Flutter `generateDna` at `ed698d3`
  (`lib/features/fitting/domain/format_parser.dart:393-410`): writes
  `{shipTypeId}:`, counts each type id over `Fitting.allModules`
  (high, medium, low, rig, subsystem slots in that order,
  `models.dart:49-55`), writes `{typeId};{count}:` per type in
  first-appearance order, then one extra `:` — net `::` terminator. Zero
  modules yields `587::`. Drones, fighters, cargo, and loaded charges are
  not represented. The Flutter round-trip oracle (`587:2048;2::`) is ported.
- Our DNA importer (`src/fitting/dna.rs`, #574) is the acceptance contract:
  slot sections only (`UnsupportedDnaItem` for everything else), quantity
  expansion to per-slot rows, caps of 1,000 segments and 4,096 expanded
  items, quantity field at most 2,147,483,647.
- Our EFT exporter (`src/ui/fittings.rs` `fitting_to_eft`) is the disclosure
  precedent: unexportable rows are counted and named in the status line,
  never silently absent.

## 3. Mapping (locked)

`fitting_to_dna(fitting: &CharacterFitting) -> Option<DnaExport>` in
`src/ui/fittings.rs` beside `fitting_to_eft`. No name resolver is involved:
DNA carries type numbers, so an unloaded ship name never blocks a copy.
`None` only when `ship_type_id <= 0` (broken data, mirroring the EFT guard).

- Sections counted: Low, Medium, High, Rig, Subsystem (via the shipped
  `section_for_flag`), traversed in Flutter `allModules` order — High,
  Medium, Low, Rig, Subsystem — preserving stored order inside a section.
- Counts merge by type id in first-appearance order across that traversal
  (Flutter counts merge the same type across slots; with catalogue slot
  classification a type sits in exactly one section anyway).
- Quantities: each row contributes `quantity.max(0)`; rows with
  `type_id <= 0` or quantity `<= 0` count as `skipped_empty`.
- Drones, Fighters, and Cargo (including catch-all flags) cannot be
  represented: their clamped quantities sum into `skipped_unsupported`.
- Total emitted count is capped at 4,096 (the importer's expanded cap) so
  our own output always re-imports: counts truncate in first-appearance
  order and truncated units sum into `skipped_capped`.
- Output: `{ship}:` then `{type};{count}:` per type, then `:` — always
  ending `::`, hull-only fits emit `{ship}::`.

`DnaExport { text, skipped_unsupported, skipped_empty, skipped_capped }`
mirrors `EftExport` counting (units for unsupported/capped, rows for empty,
matching the EFT stacked/empty precedent).

## 4. UI and wording (locked)

- Saved fitting: `Copy as DNA` button immediately after `Copy as EFT`.
  Status: `Copied "{name}" as a DNA link`, or with left-out items
  `Copied "{name}" as a DNA link ({n} items left out: DNA links hold fitted modules only)`.
- Imported fitting: `Copy imported fitting as DNA` after the EFT button,
  status from a pure helper combining the left-out and loaded-charge
  disclosures (`DNA links do not store loaded charges`).
- Logs follow the existing copy patterns per surface (`[FITTING]`,
  counts; the saved-fitting copy log already carries the display name).
- Demo: copying is local clipboard only, enabled like Copy as EFT; no
  network, no writes, no new demo data.

## 5. Exclusions

No DNA import changes, no ESI calls or scopes, no persistence, no fitting
statistics, no Pyfa. Save-to-EVE is untouched (it maps from the fitting
model, not from DNA text).

## 6. Tests

Beside the EFT exporter tests in `src/ui/fittings.rs`: Flutter round-trip
oracle (two Damage Control rows → `587:2048;2::`, and that text re-imports
through `parse_dna` to the same modules), Flutter-order first-appearance
counting (high before low regardless of stored order), hull-only output,
unsupported/empty/capped accounting, a full saved-fitting round-trip
(DNA export → DNA import → same slot items), and the imported-status wording
pins. Existing EFT tests must pass unmodified.
