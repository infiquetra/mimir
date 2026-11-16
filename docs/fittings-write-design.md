# Fittings write slice — locked design

Branch: `feat/rust-fittings-write`. Base: `develop` at
`2ffb045` (merge of pull request #572, player-structure
names). This document locks the design for Mimir's first
writes to ESI (EVE Swagger Interface, the EVE Online API):
saving a fitting to a character's in-game fitting list with
`POST /characters/{character_id}/fittings/`, and deleting a
saved fitting with
`DELETE /characters/{character_id}/fittings/{fitting_id}/`.
It closes the loop opened by the read-only saved-fittings
library (#569, `docs/fittings-library-design.md`) and the
local EFT import (#571, `docs/fittings-import-design.md`),
and extends — never contradicts — both. Where this document
and an earlier document disagree about a write behavior,
this document wins for writes only; every read behavior
stays exactly as shipped.

## 0. Grounded evidence (inspected bodies)

Every request shape, flag string, limit, and scope string
below traces to one of these inspected sources. Nothing is
invented; where sources disagree, the choice and its reason
are recorded in section 16.

1. **Live ESI OpenAPI specification**, fetched 2026-11-16
   from `https://esi.evetech.net/meta/openapi.json`
   (document title "EVE SKINR Ingenuity (ESI) -
   tranquility", version "2020-01-01"). The two fittings
   paths, verbatim facts used below:
   - `POST /characters/{character_id}/fittings`,
     operation `PostCharactersCharacterIdFittings`,
     security OAuth2 scope `esi-fittings.write_fittings.v1`.
     Request body schema: `name` (string, minimum length 1,
     maximum length 50), `description` (string, maximum
     length 500), `ship_type_id` (int64), `items` (array,
     minimum 1 item, maximum 512 items); all four are
     `required`. Each item requires `type_id` (int64),
     `flag` (string enum), and `quantity` (int64). The flag
     enum is exactly: `Cargo`, `DroneBay`, `FighterBay`,
     `HiSlot0`–`HiSlot7`, `Invalid`, `LoSlot0`–`LoSlot7`,
     `MedSlot0`–`MedSlot7`, `RigSlot0`–`RigSlot2`,
     `ServiceSlot0`–`ServiceSlot7`,
     `SubSystemSlot0`–`SubSystemSlot3`. The enum's own
     description says entries placed in `Invalid` "will be
     discarded. If this leaves the fitting with nothing, it
     will cause an error." Success response is **201
     Created** with schema `CharactersCharacterIdFittingsPost`:
     one required field, `fitting_id` (int64).
   - `DELETE /characters/{character_id}/fittings/{fitting_id}`,
     operation `DeleteCharactersCharacterIdFittingsFittingId`,
     same OAuth2 scope `esi-fittings.write_fittings.v1`.
     Success response is **204** ("Fitting deleted") with
     no response body schema.
   - `GET /characters/{character_id}/fittings` carries
     `x-cache-age: 300` and `x-server-cache-ttl: 300`: a
     list refresh immediately after a write may legitimately
     not yet show the write for up to five minutes
     (sections 7.3, 16).
   - Both write operations share rate-limit group `fitting`
     (150 tokens / 15 minutes). No design rule depends on
     this beyond the existing error-limit machinery.
2. **Retired Flutter app at `ed698d3`** (read via `git show`
   by discovery child W1; line citations are W1's):
   `EsiFittingExporter`
   (`lib/features/fitting/domain/esi_fitting_export.dart`),
   `EsiClient.saveFittingToEve`
   (`lib/core/network/esi_client.dart:458-485`),
   `saveCurrentToEve`
   (`lib/features/fitting/presentation/fitting_providers.dart:182-219`),
   the save confirm flow
   (`lib/features/fitting/presentation/fitting_screen.dart:34-79`),
   scope group (`lib/core/config/eve_config.dart:143-146`),
   and the two test files
   (`esi_fitting_export_test.dart`, `save_to_eve_test.dart`).
   W1 also proved the negative: Flutter has **no** ESI
   DELETE of any kind — its only `deleteFitting` is a local
   Drift database delete. DELETE below is therefore
   grounded in source 1 alone.
3. **Current Rust at base `2ffb045`** (read directly):
   scope groups and their tests (`src/config.rs`), the ESI
   client (`src/esi/client.rs`, especially `send`
   lines 241–288, `check_error_limit` lines 155–166,
   `auth_post` lines 363–378), the typed error vocabulary
   (`src/error.rs:7-35` and `from_status` lines 41–57),
   the fittings read endpoint and `needs_reauthorize`
   (`src/esi/endpoints.rs:619-639, 776-782`), the read
   models (`src/esi/models.rs:698-725`), the EFT import
   synthesis (`src/fitting/eft.rs:201-271`), the Fittings
   view (`src/ui/fittings.rs`), application state
   (`src/app/state.rs`), the shell's step-up, drain,
   refresh, and landing machinery (`src/app/shell.rs`),
   the one existing confirmation pattern
   (`src/ui/characters.rs:155-199`), and the Settings log
   tags (`src/ui/settings.rs:7-22`).

## 1. Value ranking (LOCKED)

When two choices conflict, the higher rank wins. Rules
below cite the rank that decided them where an inspected
body did not force the choice.

| Rank | Value | What it decides |
|---|---|---|
| 1 | No accidental or duplicate writes | Every write is behind an explicit two-step confirmation; one write in flight app-wide; a write whose outcome is unknown is never retried automatically; step-up completion never resumes a pending write (consent must be fresh) |
| 2 | Honest outcome reporting | Success is claimed only from the ESI success response for that exact request; unknown outcome is said in those words; the list after a write comes from the existing read path, never from local edits; anything left out of a save body is disclosed before the user confirms |
| 3 | Least-privilege authorization | The write scope is its own step-up group; first sign-in and the read group are untouched; the browser opens only from a button click; scope absence is detected before any HTTP when token metadata proves it |
| 4 | Character isolation for late results | Every write request, flight record, and result carries the character it belongs to; a result landing after a switch or removal is dropped whole and claims nothing |
| 5 | Reuse of shipped machinery | Existing `auth_post`/`send`, step-up flow, refresh path, selection-merge rule, two-step inline confirm shape, one-shot mock servers, and `[FITTING]`/`[ESI]` log tags; new machinery only where a seam is provably absent (`auth_delete`) |
| 6 | Feature breadth | Two save sources (imported fitting, copy of a saved fitting) through one mapping; no editor, no rename field, no statistics |

## 2. Hard scope and explicit exclusions (LOCKED)

In scope: one new step-up scope group; the POST and DELETE
endpoint functions with their request/response types; one
shared save-body mapping with pre-confirm disclosure; the
missing authenticated DELETE client seam; save and delete
entry points in the Fittings view with inline confirmation;
a write-scope step-up panel in the Fittings view; the
single-flight state machine and identity-keyed landing;
post-write refresh through the existing read path; demo
refusal; tests at every seam in section 13; the integrator
wiring in section 12.

Explicitly out of scope (each is a future slice if ever):

- No widening of `FIRST_AUTH_SCOPES` (`src/config.rs:33-39`)
  and no change to `FITTINGS_SCOPES`
  (`src/config.rs:101`) semantics. The read group keeps
  meaning exactly "may read fittings".
- No other ESI writes: no market orders, no planetary
  writes, no waypoints (Flutter's scope group also carried
  `esi-ui.write_waypoint.v1`; it is not ported), no mail.
- No fitting editor and no rename field. A save takes its
  name from its source (imported header name, or the saved
  fitting's name for a copy), normalized by section 4.3
  and shown in full in the confirmation before anything is
  sent.
- No fitting simulator statistics.
- No local persistence of anything write-related: no
  pending-write table, no outbox, no retry queue. A write
  exists only in memory between confirmation and landing.
- No automatic retry of any write, ever (section 6.3).
- No local mutation of `state.fittings` to reflect a
  write. The server list is the only list.
- No new log tag. Writes log under the existing
  `[FITTING]` and `[ESI]` tags (section 11).

## 3. Write scope group and step-up surfaces (LOCKED)

### 3.1 The group

One new constant in `src/config.rs`, immediately after
`STRUCTURE_SCOPES` (line 107), in the same one-scope
step-up shape:

```rust
/// Saved-fittings write step-up scope: save a fitting to a
/// character's in-game list or delete one from it. Granted
/// after first sign-in via step-up, never at first auth.
/// Separate from FITTINGS_SCOPES: reading fittings must
/// never imply permission to change them.
pub const FITTINGS_WRITE_SCOPES: &[&str] =
    &["esi-fittings.write_fittings.v1"];
```

The exact string is triple-grounded: live OpenAPI security
requirements for both write operations (section 0 source
1), Flutter `phase6WriteScopes`
(`eve_config.dart:143-146`), and the
`saveFittingToEve` doc comment (`esi_client.dart:460-462`).

The stale half of the `FITTINGS_SCOPES` doc comment
(`src/config.rs:99-100`, "The write scope is never
requested") and the read endpoint's matching comment
(`src/esi/endpoints.rs:625-627`) are corrected in the same
commits that outdate them (Builder A, section 14). The
read constant itself, its value, and every call site keep
their meaning.

One new config test,
`fittings_write_scopes_is_the_single_stepup_scope`,
mirroring `fittings_scopes_is_the_single_stepup_scope`
(`src/config.rs:249-261`): equality with
`["esi-fittings.write_fittings.v1"]`, disjoint from
`FIRST_AUTH_SCOPES`, and — beyond the existing template —
disjoint from `FITTINGS_SCOPES`, so the read and write
groups can never quietly merge (rank 3).

### 3.2 Where the write scope is offered

Exactly one new panel, `fittings_write_reauthorize_panel`,
in the Fittings view, modeled line-for-line on
`fittings_reauthorize_panel` (`src/ui/fittings.rs:420-453`)
but rendering `EveConfig::FITTINGS_WRITE_SCOPES.join(" ")`
and setting `stepup_requested` with `FITTINGS_WRITE_SCOPES`.
Locked wording:

- Heading: `Saving fittings needs one more EVE permission.`
- Body: `Mimir cannot save or delete fittings for this
  character until this EVE SSO scope is granted:
  esi-fittings.write_fittings.v1. Reading fittings and
  other views are unaffected.` (the scope string is
  rendered from the constant, not typed twice).
- The sign-in-as-the-right-character sentence is copied
  from the read panel with the character name substituted.
- Button: `Re-authorize with EVE SSO`, enabled exactly as
  the read panel's: `!demo && !auth.is_busy() &&
  active_character_id.is_some()`; spinner plus
  `auth.label()` while busy.

The panel is driven by one new state flag,
`pub fittings_write_needs_reauthorize: bool` on `AppState`,
parallel to `assets_needs_reauthorize` /
`structures_needs_reauthorize`. It renders when
`!state.demo && state.active_character_id.is_some() &&
state.fittings_write_needs_reauthorize`, immediately
after the import panel and before the `LoadState` match in
`show` (`src/ui/fittings.rs:784-786`). That placement is
locked (rank 6 within a correctness constraint): saving an
imported fitting needs no read scope, so the write panel
must stay reachable while the read section shows its own
step-up or an error — the same reasoning that already
puts the import panel before the match.

The flag is **set** only by the shell: by the pre-flight
refusal (section 3.3) and by a 401/403 write landing
(sections 8–9). It is **cleared** by: a successful write
landing for the active character; `BackendMsg::StepUpLoggedIn`
landing for the active character; and every character
switch/removal reset that clears fittings state today
(`src/app/state.rs:826-839, 895-903, 930-935` — Builder B
adds the flag and all section 6 fields to those same reset
sites). It is never set proactively at startup: a user who
never tries to write is never nagged for a write scope
(rank 3).

### 3.3 Scope-absent pre-check, before any HTTP

The shell's write starter (section 7.2) reads stored
token metadata with the exact call the step-up flow
already uses — `repositories::get_token_meta` then
`oauth::split_scopes` (`src/app/shell.rs:2225-2260`
pattern) — for the stamped character, before spawning:

- Scope absent (including no metadata row, or a metadata
  read error — absence of evidence is treated as absent,
  matching the step-up flow's treatment): **no task is
  spawned and no HTTP request is made.** The shell sets
  `fittings_write_needs_reauthorize = true` and the status
  message `Saving and deleting fittings needs one more EVE
  permission. Re-authorize in the Fittings view.` (section
  9), logs one `[FITTING]` info line with the character
  id and action kind, and returns. This is a not-sent
  outcome by construction (section 9.1).
- Scope present in metadata: spawn. Stored metadata can
  still be stale (revoked grant); section 3.4 covers that.

### 3.4 Observed-403 arm (the #572 lesson)

A new pure function beside `structures_stepup_observed`
(`src/app/shell.rs:207-212`):

```rust
fn fittings_write_stepup_observed(
    request_scopes: &[String],
    state: &AppState,
) -> bool {
    request_scopes
        .iter()
        .any(|scope| EveConfig::FITTINGS_WRITE_SCOPES.contains(&scope.as_str()))
        && state.fittings_write_needs_reauthorize
}
```

It is OR-ed into the `observed_reauthorize` computation in
`start_stepup_login` (`src/app/shell.rs:2266-2284`). A
write that observed a live 401/403 has already set the
state flag at landing, so metadata claiming the grant
cannot shortcut the write panel's own Re-authorize button
into a no-browser loop. A test mirrors
`fittings_observed_reauthorize_blocks_shortcut_only_on_scope_refusal`
(`src/app/shell.rs:2863+`): observed only when the request
contains the write scope **and** the flag is set; false
for the read scope alone; false when the flag is clear.

Note the deliberate asymmetry with the read arm: the read
flag lives inside `FittingsData::needs_fittings_stepup()`
because reads are section errors; the write flag is a
sibling `AppState` boolean because a write refusal is not
a list state. `FittingsData` gains no field (demo seeding
constructs it literally; `src/app/state.rs` bundle
comments forbid casual additions).

## 4. POST contract — save a fitting (LOCKED)

### 4.1 Endpoint function and wire shape

New endpoint function beside `get_character_fittings`
(`src/esi/endpoints.rs:619-639`):

```rust
pub async fn save_character_fitting(
    client: &EsiClient,
    character_id: i64,
    request: &SaveFittingRequest,
) -> AppResult<SaveFittingResponse>
```

It calls the existing, unchanged
`EsiClient::auth_post` (`src/esi/client.rs:363-378`) with
path `format!("/characters/{character_id}/fittings/")` —
the trailing-slash form the shipped read path and the
Flutter POST both use (`endpoints.rs:635`;
`esi_client.dart:476`). The OpenAPI path template omits
the trailing slash; the running-code form wins and the
discrepancy is recorded in section 16. Token loading,
refresh, JWT verification, the 30-second timeout, the
error limiter, and status-to-typed-error mapping are all
inherited from `valid_access_token` + `send` unchanged.

Request and response types, in `src/esi/models.rs` beside
`CharacterFitting` (field order is part of the contract —
serde serializes in declaration order and the
request-capture test asserts exact bytes):

```rust
#[derive(Debug, Clone, Serialize)]
pub struct SaveFittingRequest {
    pub name: String,
    pub description: String,
    pub ship_type_id: i64,
    pub items: Vec<FittingItem>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SaveFittingResponse {
    pub fitting_id: i64,
}
```

`FittingItem` (`flag`, `quantity`, `type_id` — already the
exact required triple) is reused as the item type; its
existing `Deserialize` is joined by the `Serialize` derive.
Body field names are exactly the OpenAPI property names,
which are also exactly the Flutter keys
(`esi_client.dart:478-483`): no extra keys, none omitted.
`SaveFittingResponse.fitting_id` deliberately has **no**
`#[serde(default)]`: a 201 whose body lacks `fitting_id`
is a decode failure — an unknown outcome (section 9.1),
not a fabricated id. (Every read model defaults its fields
because a short read row is still displayable; a write
receipt with no id proves nothing, rank 2.)

### 4.2 The save-body mapping (one mapper, both sources)

Both save sources funnel through one pure function in a
new module `src/fitting/write_map.rs` (declared in
`src/fitting/mod.rs`; every function logs `[FITTING]` at
debug with counts only):

```rust
pub fn build_save_request(
    source: &CharacterFitting,
) -> SaveMapping;

pub struct SaveMapping {
    pub request: SaveFittingRequest,
    /// True when the name was empty/whitespace and the
    /// fallback was used.
    pub name_was_fallback: bool,
    /// `Some(original_char_count)` when over 50 chars.
    pub name_truncated_from: Option<usize>,
    /// True when the source description exceeded 500 chars.
    pub description_truncated: bool,
    pub dropped: Vec<DroppedFittingItem>,
}

pub struct DroppedFittingItem {
    pub type_id: i64,
    pub flag: String,
    pub reason: DropReason,
}

pub enum DropReason {
    /// Slot index beyond the ESI flag enum (or a flag
    /// string not in the enum at all, `Invalid` included).
    NoEsiFlag,
    /// Stacked-category item with quantity <= 0, or an item
    /// with a non-positive type id.
    NotSaveable,
    /// Second or later item claiming the same slot flag.
    DuplicateSlot,
}
```

- **Imported source:** the view passes
  `imported.to_character_fitting()`
  (`src/fitting/eft.rs:223-271`), unchanged. That
  synthesis already assigns sequential
  `LoSlot{n}`/`MedSlot{n}`/`HiSlot{n}`/`RigSlot{n}`/
  `SubSystemSlot{n}` flags with no upper bound, maps
  drones/fighters/cargo to the literal bay flags, and
  excludes loaded charges. The mapper is where the
  enum bounds are enforced — the role Flutter's
  `droppedModules` played, extended (below) to the
  categories Flutter silently omitted.
- **Copy source:** the selected `CharacterFitting` from
  the loaded list, as-is. Its `fitting_id` is never
  copied into the request (the request type has no such
  field); a copy is a new server fitting.

Item rules, applied in source order (output `items`
preserves source order of the kept items):

1. Slot flags for `HiSlot`/`MedSlot`/`LoSlot` with index
   0–7, `RigSlot` 0–2, `SubSystemSlot` 0–3,
   `ServiceSlot` 0–7: kept with `quantity: 1` regardless
   of the source quantity (Flutter exporter always emitted
   1, `esi_fitting_export.dart:52-56`; a slot holds one
   module). A second kept item with the identical slot
   flag is dropped as `DuplicateSlot`.
2. Stacked flags `DroneBay`, `FighterBay`, `Cargo`: kept
   with the source `quantity` when it is at least 1;
   `quantity <= 0` is dropped as `NotSaveable` (Flutter's
   fighter rule, `esi_fitting_export.dart:60`, generalized
   to the two categories Flutter never sent — the live
   enum proves ESI accepts `DroneBay` and `Cargo`, so
   sending them is fidelity, and dropping a non-positive
   stack is the only honest reading of it).
3. Any other flag string — out-of-range slot index
   (`LoSlot8`, `RigSlot3`, `SubSystemSlot4`,
   `ServiceSlot8`), the literal `Invalid`, lowercase or
   empty or otherwise not exactly one enum member — is
   dropped as `NoEsiFlag`. `Invalid` is never sent:
   the specification says the server discards it, so
   sending it would hide a loss the user was not shown
   (rank 2; Flutter likewise never emitted it).
4. `type_id <= 0`: dropped as `NotSaveable` (checked
   before flag rules; the read models default a missing
   id to 0 and 0 is not an item).
5. Module state, charges-as-items, and any other source
   field: not represented in `FittingItem`, so nothing to
   map. Loaded charges of an imported fitting live only
   on `ImportedItem.charge` and are already excluded by
   synthesis; they are disclosed by count in the
   confirmation (section 6), never silently (Flutter's
   silent charge/drone/cargo omission is explicitly not
   repeated for drones and cargo, and is disclosed for
   charges).

Whole-fitting guards (evaluated from the finished
mapping; the confirmation UI, section 6, keys off them):

- `ship_type_id <= 0`, or kept `items` empty (specification
  minimum 1): the fitting **cannot be saved** — the arm
  button is disabled and the locked explanation of
  section 6.1 shows instead of a confirmation.
- Kept `items` longer than 512 (specification maximum):
  likewise cannot be saved. Truncating a fitting to fit
  would silently change what the user confirmed; refusing
  is the honest outcome (rank 2 over rank 6).

### 4.3 Name rule (where enforced, exact behavior)

Locked, from Flutter `saveCurrentToEve`
(`fitting_providers.dart:201-207`) plus the specification
limits (minimum length 1, maximum length 50):

0. Sanitize with the private `sanitize_for_save` in
   `write_map.rs`: the same transformation as the view's
   `sanitize_single_line` (`src/ui/fittings.rs:99-106` —
   control characters become spaces, whitespace runs
   collapse to one space). One seven-line twin, pinned by
   its own tests, because the fitting layer must not
   import the UI layer. This also makes the name the
   confirmation renders byte-identical to the name sent.
   The view's digit-only display fallback
   (`fitting_display_name` → "Unnamed fitting") is
   display-only and is **not** applied here: a user name
   of digits is user text, is valid for ESI, and is shown
   verbatim in the confirmation so what is confirmed is
   what is sent.
1. (Sanitizing already trims; no separate trim step.)
2. Empty after sanitizing → the exact fallback name
   `Unnamed fit`.
3. Longer than **50 characters** → keep the first 50
   **characters** (`.chars().take(50)`), never bytes. The
   specification's `maxLength` counts string characters;
   Flutter's `substring(0, 50)` counted UTF-16 code units
   — for names containing characters outside the basic
   multilingual plane the two differ, and the
   specification's reading is the one ESI validates.
   Recorded in section 16.

Enforcement point: `build_save_request` only. The view
never pre-trims and the endpoint never re-checks; the
confirmation renders `mapping.request.name` — the exact
string that will be sent — plus a note when
`name_was_fallback` or `name_truncated_from` is set
(section 6). A mutation-sensitive test with 51 copies of
a multibyte character proves 50 characters survive
(section 13).

### 4.4 Description rule

`description` is required by the specification (maximum
length 500, no minimum), and Flutter always sent the
literal `Saved from Mimir`
(`fitting_providers.dart:214`), ignoring any source
description. Locked choice, honoring copy fidelity where
a source description exists:

- Source `description` is `Some`, non-empty after
  `sanitize_for_save` (the 4.3 step-0 twin of the
  sanitize the detail view already renders descriptions
  through, `src/ui/fittings.rs:865-870`): send it,
  truncated to 500 characters (`.chars().take(500)`),
  with `description_truncated` set when longer.
  Sanitizing before sending means what was displayed is
  what is saved — no control characters or embedded
  newlines ride along invisibly (rank 2).
- Otherwise (`None`, or empty after sanitize — always the
  case for an imported fitting, whose synthesis sets
  `description: None`): send exactly `Saved from Mimir`,
  the grounded Flutter literal.

### 4.5 What success means

Success for save is, and is only: `auth_post` returned
`Ok` (i.e. `send` observed a 2xx status) **and** the body
deserialized as `SaveFittingResponse` with a
`fitting_id`. The endpoint returns that response; the
returned id is carried into the landing (section 8) and
is the pending-selection candidate — it is never rendered
as a number, never sent to name resolution (the existing
`fitting_id` contract, `src/esi/models.rs:689-695`), and
never invented locally. Flutter discarded this body
(`Future<void>`); Rust deliberately does not, because the
id is the only per-request receipt ESI gives (rank 2).

## 5. DELETE contract (LOCKED)

Grounded in the live OpenAPI operation alone (Flutter has
no ESI delete; W1). Path:
`/characters/{character_id}/fittings/{fitting_id}/` —
trailing slash to match the app's shipped convention for
this resource family, recorded as a live-verification
risk in section 16. Success is specification 204 with
**no body**.

### 5.1 The missing client seam

`send<T: DeserializeOwned>` (`src/esi/client.rs:241-288`)
always JSON-decodes the body, so a 204 empty body would
surface as `EsiError::Decode` — success misreported as
failure. One new private sibling, in `src/esi/client.rs`:

```rust
async fn send_unit(
    &self,
    request: reqwest::RequestBuilder,
    path: &str,
) -> AppResult<()>;
```

It performs the same steps as `send` — `check_error_limit`
first (so a pre-send refusal stays provably not-sent),
URL-stripped transport errors, error-limit headers
honored, body read as text, non-success →
`EsiError::from_status` with that body — and on any 2xx
returns `Ok(())` without decoding (the specification
defines no success body to decode; accepting the whole
2xx class matches `status.is_success()` as `send` already
defines it). Public seam, mirroring `auth_post`:

```rust
pub async fn auth_delete(
    &self,
    path: &str,
    character_id: i64,
) -> AppResult<()>
```

(`valid_access_token` → `self.http.delete(self.build_url(path))`
→ `bearer_auth` → `send_unit`; logs `[ESI] DELETE {path}
character_id={id}` at debug.) `send` itself is not
modified: no read path changes behavior (rank 5).

### 5.2 Endpoint function and preconditions

```rust
pub async fn delete_character_fitting(
    client: &EsiClient,
    character_id: i64,
    fitting_id: i64,
) -> AppResult<()>
```

beside the save function. Preconditions, all enforced
before spawn (section 7.2): the `fitting_id` is the
currently selected fitting of the active character, taken
from `fittings_selected_fitting_id` and re-resolved
against the loaded list at confirmation time (so the
confirmation names a fitting that still exists in what
the user sees); `fitting_id > 0` (the imported synthesis
id `-1` and the parse default `0` can therefore never be
delete targets — an imported fitting has nothing on the
server to delete and is offered no delete control,
section 6). Selection clearing after
delete: never local. The post-delete refresh's existing
merge rule (`fittings_selection_is_stale`,
`src/app/shell.rs:180-185`) clears the selection when the
fresh `Ok` list no longer carries the id, and preserves
it when the refresh fails — including when the refresh
still shows the fitting because of the 300-second list
cache. Until a refresh proves otherwise, the deleted
fitting's detail remains displayed and the status line
carries the outcome (section 9). No exception is carved
out (rank 2).

## 6. Confirmation UX (LOCKED)

The app has exactly one confirmation pattern — the
two-step inline confirm of `src/ui/characters.rs:155-199`
("two-step inline confirm, no modal traps") — and writes
follow it. No modal dialog is introduced (egui immediate
mode; the Flutter `AlertDialog` shape is not ported). One
new armed-confirmation value on `AppState` (section 7 for
its lifecycle):

```rust
pub enum FittingWriteConfirm {
    SaveImported { character_id: i64 },
    SaveCopy { character_id: i64, fitting_id: i64 },
    Delete { character_id: i64, fitting_id: i64 },
}
pub fittings_write_confirm: Option<FittingWriteConfirm>,
```

Rendering rules common to all three:

- The arm button and the armed block never coexist for the
  same target: arming swaps the button for the block, as
  `Delete character...` swaps to `Confirm delete` +
  `Cancel`. At most one confirmation is armed app-wide;
  arming one replaces any other.
- The armed block is recomputed **every frame** from the
  current source (current imported fitting; current list
  entry for the stamped `fitting_id`). If the stamped
  character is not the active character, or a stamped
  `fitting_id` is no longer in the loaded list, or (for
  `SaveImported`) the imported fitting is gone or its
  owner no longer matches the render guard
  (`src/ui/fittings.rs:687-691`), the block does not
  render and the value is cleared — a confirmation can
  never outlive the thing it confirms.
- `Confirm …` and the arm buttons are
  `add_enabled(write_enabled)` where
  `write_enabled = !state.demo && !state.auth.is_busy() &&
  state.fittings_write_in_flight.is_none() &&
  state.active_character_id.is_some()`.
  `Cancel` is always enabled. The auth-busy gate carries
  the characters.rs rationale: a write must not race an
  in-flight browser sign-in's token save.
- Clicking Confirm is the single snapshot point: in that
  same frame the view builds the final
  `SaveFittingRequest` via `build_save_request` (or, for
  delete, takes the stamped ids), sets
  `state.fittings_write_requested` (section 7), clears
  the confirmation, and logs one `[FITTING]` info line
  with counts only. What the block displayed that frame
  is bit-for-bit what is sent — there is no earlier
  snapshot to go stale and no later edit point.
- All names shown are resolved names: fitting names are
  `mapping.request.name` itself (already sanitized by
  the mapper, 4.3 — the confirmation must show the exact
  string to be sent, so `fitting_display_name`'s
  display fallbacks do not apply here), ship and item
  names come from the app resolver / imported local
  resolver. A dropped item whose name has not resolved is
  shown in the count-only fallback line below, never as a
  number.

### 6.1 Save the imported fitting

Arm button `Save imported fitting to EVE...` in the
import panel, directly after the existing
`Copy imported fitting as EFT` button
(`src/ui/fittings.rs:745-766`), rendered only when the
imported detail renders (same `owner_ok` guard). Armed
block, in order:

1. `Save "{name}" to EVE?` where `{name}` is
   `mapping.request.name` (post-normalization).
2. `"{name}" ({ship}, {n} items) will be added to this
   character's in-game fitting list.` — `{ship}` is the
   imported catalogue ship name, `{n}` the kept-item
   count. (The sentence shape follows Flutter's confirm
   message, `fitting_screen.dart:44-55`, with the ship
   added because two save sources now exist.)
3. If `name_was_fallback`: `The fitting name was empty,
   so it will be saved as "Unnamed fit".`
4. If `name_truncated_from = Some(c)`: `EVE fitting names
   are limited to 50 characters. This name ({c}
   characters) will be saved in the shortened form shown
   above.`
5. If `description_truncated`: `The fitting notes are too
   long for EVE and will be shortened.` (copy source
   only in practice; the rule is shared).
6. If the imported report has `charges_noted > 0`:
   `{k} loaded charge(s) are shown above but are not part
   of a saved fitting and will not be sent to EVE.`
7. Dropped-item lines (section 6.4).
8. `Confirm save to EVE` / `Cancel`.

If the mapping is un-saveable (section 4.2 guards), the
arm button is disabled and this label renders in its
place: `This fitting cannot be saved to EVE: nothing in
it fits an EVE fitting slot.` For the over-512 case:
`This fitting cannot be saved to EVE: it has more items
than EVE allows in one fitting (512).`

### 6.2 Save a copy of a saved fitting

Arm button `Save a copy to EVE...` in the selected
fitting's detail block, beside `Copy as EFT`
(`src/ui/fittings.rs:877`). Same armed block as 6.1,
sourced from the selected `CharacterFitting`, except line
2 reads: `A copy of "{name}" ({ship}, {n} items) will be
added to this character's in-game fitting list. The
original stays as it is.` (`{ship}` via the app resolver;
the same un-saveable labels apply — in practice a
server-returned fitting maps cleanly, but the guard is
not assumed away).

### 6.3 Delete a saved fitting

Arm button `Delete fitting from EVE...` in the same
detail block. Armed block:

1. `Delete "{name}" from EVE?`
2. `"{name}" ({ship}, {n} items) will be deleted from this
   character's in-game fitting list. This cannot be
   undone.`
3. `Confirm delete` / `Cancel`.

The irreversibility sentence is verbatim-locked; no
softer variant ships.

### 6.4 Dropped-item disclosure lines

Dropped items are grouped for display: named lines first,
at most 8, then one overflow line. Per reason (Flutter's
warning sentence is the template for `NoEsiFlag`,
`fitting_screen.dart:44-55`):

- `NoEsiFlag`: `{item name} has no EVE fitting slot and
  will be left out.`
- `DuplicateSlot`: `{item name} shares a fitting slot
  with another item and will be left out.`
- `NotSaveable` with `type_id` resolvable: `{item name}
  cannot be saved and will be left out.`
- Any dropped item without a resolved name, and any
  dropped items beyond the 8 named lines, collapse into
  one final line: `{k} more item(s) will be left out.`

Pure formatting functions in `src/ui/fittings.rs`
(templates above, section 13 tests assert them verbatim);
the `(s)` pluralization in templates is written out as
given — no plural logic, matching the shipped
`charges_note` style.

### 6.5 In-flight presentation

While `fittings_write_in_flight` is set, both detail and
import blocks render, in place of the write buttons: a
spinner plus `Saving to EVE...` or `Deleting from EVE...`
according to the stamped kind. All write arm/confirm
buttons are disabled app-wide by the `write_enabled` gate
above. Nothing about the list changes visually until a
refresh lands (section 8 is the state rule; this is its
face).

## 7. Single-flight and state machine (LOCKED)

### 7.1 Request and flight records

Two more `AppState` values, beside the request flags
(`src/app/state.rs:660+`):

```rust
pub enum FittingWriteRequest {
    Save { character_id: i64, request: SaveFittingRequest },
    Delete { character_id: i64, fitting_id: i64 },
}
pub fittings_write_requested: Option<FittingWriteRequest>,

pub struct FittingWriteInFlight {
    pub character_id: i64,
    pub kind: FittingWriteKind, // Save | Delete, Copy etc. not distinguished
    pub fitting_id: Option<i64>, // Some for Delete, None for Save
}
pub fittings_write_in_flight: Option<FittingWriteInFlight>,
```

Single-flight is **global**: at most one write in flight
in the whole app, not one per character (rank 1; it also
means the landing's flight-record match is
unambiguous). Double-click impossibility is
three-layered: (1) Confirm clears the armed confirmation
and the request in the same frame it is clicked, so the
button ceases to exist; (2) the shell drains the request
with `.take()` (the shipped drain pattern,
`src/app/shell.rs:1337-1339`) and spawns at most once per
value; (3) from spawn to landing every write control is
disabled (section 6). There is no queue: a request that
somehow arrives while a flight is active is refused by
the shell (7.2), never held.

### 7.2 Drain and pre-spawn guards

The integrator drain adds, after the step-up drain:

```rust
if let Some(request) = self.state.fittings_write_requested.take() {
    self.start_fitting_write(request);
}
```

`start_fitting_write` refuses — synchronously, with a
`[FITTING]` warn line carrying ids/kind only, and the
named status message — when any of these hold. Refusal
never sets `fittings_write_in_flight` and never spawns:

| Condition | Status message |
|---|---|
| `state.demo` | `Demo mode uses sample data. Saving or deleting fittings in EVE is disabled.` |
| `state.auth.is_busy()` | `Finish sign-in in your browser before changing fittings in EVE.` |
| a flight is already active | `A fitting change is already in progress. Wait for it to finish.` |
| stamped character is not in `state.characters` | `That character is no longer in Mimir. Nothing was sent to EVE.` |
| stamped character is not the active character | `The active character changed. Nothing was sent to EVE.` |
| backends or runtime not wired | `Fitting changes are unavailable: live backends not wired.` |
| token metadata lacks the write scope (3.3) | sets the write flag; message in 3.3 |

Otherwise it stamps `fittings_write_in_flight`, logs
`[FITTING] write started` with `character_id`, kind, and
(for save) the kept-item count — never the name — and
spawns one tokio task that calls exactly one endpoint
function and sends exactly one `BackendMsg::FittingWriteDone`
(section 8) on **every** path, mapping the `Err` arm with
the classifier of section 9 at the spawn site. The
client's existing 30-second timeout
(`EveConfig::DEFAULT_TIMEOUT_MS`) bounds the flight;
there is no additional write timer.

### 7.3 No automatic retry; the manual-retry rule

No code path in this slice re-issues a POST or a DELETE —
not on timeout, not on 5xx, not on refresh, not after
step-up completion (rank 1). The one and only retry is a
fresh user journey: arm → read the (recomputed)
confirmation → Confirm. For DELETE this is safe as well
as honest: a deliberate re-delete of an already-deleted
fitting returns 404, which the taxonomy reports as
already-gone (section 9), and the confirmation can only
be armed while the fitting still appears in the list
the user sees (section 6). Design therefore "allows" a
delete retry only in that manual sense, identical to a
save retry; there is no retry button distinct from the
normal arm buttons.

### 7.4 Timeout is an outcome, and the outcome is "unknown"

A reqwest timeout (or any transport failure mid-request)
surfaces as `EsiError::Http` (`src/esi/client.rs:250-253`).
For a write it proves nothing in either direction: the
server may have committed and the response may have been
lost. Section 9 classifies it **Unknown**; the locked
wording (section 9.2) says the change "may or may not
have reached EVE", never claims success, never claims
failure, and tells the user to check the refreshed list
before trying again — because trying again after a
secretly-successful save is exactly how a duplicate
fitting is born (rank 1). The landing additionally queues
a refresh (section 8) so the list the user is told to
check is already on its way.

## 8. Landing rules (LOCKED)

One new `BackendMsg` variant (`src/app/shell.rs:46-94`
enum), following the identity discipline of every shipped
variant:

```rust
FittingWriteDone {
    character_id: i64,
    kind: FittingWriteKind,
    outcome: FittingWriteOutcome,
},
pub enum FittingWriteOutcome {
    Saved { fitting_id: i64 },
    Deleted { fitting_id: i64 },
    Failed { class: WriteFailureClass, needs_reauthorize: bool },
}
```

(`FittingWriteKind` is Builder B's type in
`src/app/state.rs`; `WriteFailureClass` is Builder A's,
 beside the classifier of section 9.1, and the spawn
classifies with that classifier.) The handler runs in
this exact order:

1. **End the flight.** Clear `fittings_write_in_flight`
   unconditionally. The flight is over whatever the ids
   say; the match that matters is the next step, and a
   mismatched landing must still unblock the UI. (One
   pure helper carries steps 1–2's decision so it is
   directly testable, section 13.)
2. **Drop-whole-message on identity mismatch.** If
   `character_id != state.active_character_id` — the user
   switched character or removed the writer mid-flight —
   log one `[FITTING]` info line (`stale write result
   dropped character_id={id} kind={kind}`) and return:
   no status message, no state change, no refresh queued
   (a refresh would fetch for the *new* active character
   and dress the old write in new clothes). This is the
   `StructuresResolved` drop-whole precedent
   (`src/app/shell.rs:1104-1123`). The write itself may
   well have succeeded in EVE for the original character;
   Mimir simply makes no claim about it on another
   character's screen (rank 4) — switching back and
   refreshing shows the server truth.
3. **On match, by outcome:**
   - `Saved { fitting_id }`: status `Saved the fitting to
     EVE. Refreshing your fitting list...` (name-free like
     every write status, 9.2 — the request traveled with
     the spawn, so no name is at hand at landing to
     misattribute). Clear
     `fittings_write_needs_reauthorize`; record
     `fittings_pending_selection =
     Some((character_id, fitting_id))` (8.1); set
     `refresh_requested = true` (the existing drain →
     `start_refresh` → `BackendMsg::Refreshed` path,
     unchanged). The imported fitting is **not** cleared
     (the user may still copy it as EFT; section 10
     rewords its labels so they no longer claim it is
     unsaveable).
   - `Deleted { .. }`: status `Deleted the fitting from
     EVE. Refreshing your fitting list...`; clear the
     write flag; queue the same refresh. Selection is
     left untouched for the merge rule to judge (5.2).
   - `Failed { needs_reauthorize: true, .. }`: set
     `fittings_write_needs_reauthorize`; status from
     section 9.2; no refresh.
   - `Failed { class: Unknown, .. }`: status from 9.2;
     **queue the refresh** — it is the reconciliation the
     wording points at. For an unknown *delete*, the
     refreshed list settles it observably: fitting gone,
     or still there and deletable again manually. For an
     unknown *save*, the list may show a new fitting the
     user did not expect; nothing selects it automatically
     (no receipt id exists).
   - `Failed { class: AlreadyGone, .. }` (delete 404):
     status from 9.2; queue the refresh so the list and
     selection resynchronize through the normal merge.
   - Any other `Failed`: status from 9.2; no refresh
     (the server state provably did not change for
     NotSent/Definitive, section 9.1).

No other `BackendMsg` handler learns about writes. In
particular `StepUpLoggedIn` gains only the flag clear
named in 3.2 — it never starts, resumes, or replays a
write (rank 1: consent is re-given by hand).

### 8.1 Selection after save

One new state value,
`pub fittings_pending_selection: Option<(i64, i64)>`
(`(character_id, fitting_id)`), applied by a pure helper
called from the existing fittings merge in
`BackendMsg::Refreshed` (`src/app/shell.rs:1052-1071`)
immediately beside `fittings_selection_is_stale`:

```rust
fn apply_pending_fitting_selection(
    pending: Option<(i64, i64)>,
    applied_character_id: i64,
    fittings_list: &SectionResult<Vec<CharacterFitting>>,
) -> (/* keep pending */ Option<(i64, i64)>, /* select */ Option<i64>)
```

Rules: only a refresh landing for the stamped character
with an `Ok` fittings list judges the pending value —
contain the id → select it (`fittings_selected_fitting_id
= Some(fitting_id)`) and consume the pending value; not
contain it → consume the pending value and select nothing
(the 300-second list cache can outlast one refresh;
leaving a stale pending selection armed across an
arbitrary later refresh would yank the user's selection
minutes later — first judged refresh only, rank 2).
An `Err` list proves nothing: the pending value survives
it unjudged (the shipped Err-preserves-selection rule)
until an `Ok` list for that character judges it, a
character switch/removal reset clears it (section 3.2's
reset sites), or the user selects a row by hand (next
paragraph). The helper is also fed `None` after any manual
row selection: the view's selection click
(`src/ui/fittings.rs:849`) clears
`fittings_pending_selection` — an explicit user choice
always beats a pending machine one.

Selection after delete needs no new machinery: the
shipped stale rule judges it (5.2).

## 9. Error taxonomy → fixed UI wording (LOCKED)

### 9.1 The classifier (exhaustive — the #572 lesson)

One pure function in `src/esi/endpoints.rs` beside
`needs_reauthorize` (line 776), Builder A's:

```rust
pub enum WriteFailureClass {
    NotSent, Definitive, AlreadyGone, RateLimited { reset_secs: u32 }, Unknown,
}
pub fn classify_write_error(
    error: &AppError,
    is_delete: bool,
) -> (WriteFailureClass, bool /* needs_reauthorize */)
```

It matches **every** `EsiError` variant of
`src/error.rs:7-35` by name — no wildcard arm — so a
future variant is a compile error here, not a silent
miscategorization. The three write-relevant classes mean:

- **NotSent** — the request provably never left this
  process (error-limiter refusal inside `send` before the
  request is sent, `src/esi/client.rs:155-166, 246`; or
  token loading/refresh failure in `valid_access_token`,
  which precedes any send). Retrying by hand cannot
  duplicate anything.
- **Definitive** — ESI answered with a 4xx refusal.
  Nothing was created or deleted.
- **Unknown** — no usable answer: transport failure, a
  5xx (a server can fail after committing; for a first
  write the conservative reading wins, rank 1), or a
  success-status body that does not decode as the
  receipt.

Exhaustive mapping (`AppError` wraps `EsiError`; non-ESI
`AppError` arms follow the ESI rows):

| Typed error | Class | Reauthorize? |
|---|---|---|
| `EsiError::Unauthorized` (401) | Definitive | yes |
| `EsiError::Reauthorize` (403 — scope **or any other** 403; see below) | Definitive | yes |
| `EsiError::NotFound` (404) on DELETE | AlreadyGone | no |
| `EsiError::NotFound` (404) on POST | Definitive | no |
| `EsiError::RateLimited { reset_secs }` (420/429) | RateLimited { reset_secs } | no |
| `EsiError::Status(code)` / `StatusMessage(code, _)` with `400 <= code < 500` | Definitive | no |
| `EsiError::Status(code)` / `StatusMessage(code, _)` with any other code (5xx in practice) | Unknown | no |
| `EsiError::ErrorLimitExhausted { reset_secs }` | RateLimited { reset_secs } (provably unsent — refused inside `send`/`send_unit` before the request — so the "Nothing was saved/deleted" wording of that family holds exactly) | no |
| `EsiError::NoTokens` | NotSent | yes — a deliberate extension beyond the read path's `needs_reauthorize` (which matches only 401/403, `src/esi/endpoints.rs:776-782`): with no stored tokens the honest remedy is signing in again, and the write panel is this view's route to it |
| `EsiError::Http` (timeout/transport) | Unknown | no |
| `EsiError::Decode` | Unknown | no |
| `EsiError::NotWired` (unreachable on this path; classified so the match stays total) | NotSent | no |
| `EsiError::Message` (token-store/refresh plumbing, pre-send by construction on this path) | NotSent | no |
| `AppError::Auth(_)` (refresh/JWT failure inside `valid_access_token`) | NotSent | yes when it is `AuthError::RefreshRejected`, else no |
| `AppError::Db` / `AppError::Io` / `AppError::Json` / `AppError::Url` / `AppError::Message` | NotSent | no |

**403 scope versus 403 other:** `EsiError::from_status`
maps every 403 to `Reauthorize` (`src/error.rs:44`) —
the typed vocabulary cannot distinguish a missing scope
from any other 403 (for example an ACL-style refusal),
and this slice does not invent a body-sniffing
discriminator. Every write 403 therefore takes the
re-authorize route. That can only over-offer a step-up
the user may decline; it can never silently swallow a
scope refusal. The server's own `{"error": ...}` text
still reaches the `[FITTING]` warn log (through the typed
error's `Display`) for diagnosis — never the screen.
This is the same discrimination the shipped read path
makes (`needs_reauthorize` on 401/403); changing it is a
different slice, recorded in section 16.

The existing `needs_reauthorize` continues to serve reads
unchanged; the classifier's reauthorize boolean is
computed inside the classifier (it may call
`needs_reauthorize` for the 401/403 core) so the
shell has exactly one function to ask.

### 9.2 Locked status-message wording

Fixed strings, set as `state.status_message` at landing
(or at synchronous refusal, 7.2/3.3). `{s}` is the
rate-limit `reset_secs` — a duration, the only number a
write message ever shows. Save and delete differ only
where listed:

| Situation | Save | Delete |
|---|---|---|
| Success | `Saved the fitting to EVE. Refreshing your fitting list...` | `Deleted the fitting from EVE. Refreshing your fitting list...` |
| Not sent (local plumbing, not reauthorize, not rate-limited) | `Nothing was sent to EVE. Check the connection and try again.` | same |
| Needs reauthorize (401/403/NoTokens/refresh-rejected) | `EVE refused the save: this character has not granted fitting changes. Re-authorize in the Fittings view.` | `EVE refused the delete: this character has not granted fitting changes. Re-authorize in the Fittings view.` |
| Definitive 4xx (not 401/403/404-delete) | `EVE refused the save and nothing was saved. See the log for details.` | `EVE refused the delete and nothing was deleted. See the log for details.` |
| AlreadyGone (delete 404) | — | `That fitting is already gone from EVE. Refreshing your fitting list...` |
| RateLimited / ErrorLimitExhausted | `EVE is rate-limiting requests. Nothing was saved; wait {s} seconds and try again.` | `EVE is rate-limiting requests. Nothing was deleted; wait {s} seconds and try again.` |
| Unknown | `The save may or may not have reached EVE. Check the refreshed fitting list before saving again, so you do not create a duplicate.` | `The delete may or may not have reached EVE. Check the refreshed fitting list; if the fitting is still there, you can delete it again.` |

Example rendering with `reset_secs = 42`:
`EVE is rate-limiting requests. Nothing was saved; wait
42 seconds and try again.`

No status message contains a fitting name (user text
stays out of synthesized sentences it could break), a
numeric id, or any part of a server error body. Detail —
the typed error including any ESI message text, capped
by the existing 300-character extraction
(`src/error.rs:84-90`) — goes to one `[FITTING]` warn
line at the spawn site with `character_id` and kind
(section 11).

## 10. Demo behavior (LOCKED)

Demo performs no writes, offers no write, and says so:

- In demo, **no write arm button renders** anywhere. In
  their places: the imported-detail block and the
  selected-fitting detail block each render the one
  locked label `Demo mode uses sample data. Saving or
  deleting fittings in EVE is disabled.` (the same
  sentence the shell backstop uses, 7.2 — one wording
  everywhere, matching the shipped
  `Demo mode uses sample data; EVE sign-in is disabled.`
  family).
- The write step-up panel never renders in demo (its
  render gate includes `!state.demo`, 3.2), and the
  shell refuses any drained write request in demo
  regardless of how it was set (7.2) — demo data is
  byte-for-byte the shipped fixture: no fake save, no
  fake delete, no local list mutation of any kind. Use
  Sample EFT / import / copy-as-EFT keep working exactly
  as shipped.
- Two shipped sentences become false once saving exists
  and are reworded by Builder B in the same commit as the
  buttons: the import panel intro
  (`src/ui/fittings.rs:610`) becomes `Paste an EFT block
  (the [Ship, Fitting name] text format). The imported
  fitting stays in Mimir on this device unless you save
  it to EVE below, and it is gone when you switch
  characters or close Mimir.`; the imported-detail
  heading (`src/ui/fittings.rs:696`) becomes
  `Imported fitting`. In demo the demo label above is
  what qualifies the intro's "unless".

## 11. Logging (LOCKED)

Every new or modified function logs with the repo's
bracketed tags (`[FITTING]` for write flow decisions,
`[ESI]` inside client/endpoint transport lines —
`send_unit` mirrors `send`'s existing warn/debug lines).
Locked content rule, the slice-wide one: logs carry
`character_id`, action kind, `fitting_id` where it
already exists server-side, item **counts** (kept,
dropped, per-reason if useful), and the typed error —
**never** a fitting name, a description, pasted EFT text,
a request/response body, a token, an authorization code,
or an authorize URL. This deliberately departs from
Flutter, which logged the fit name verbatim
(`esi_client.dart:470-474`). It also departs, for write
lines only, from the shipped selection/copy log lines
that do carry names (`src/ui/fittings.rs:845-848, 904-910`):
those existing lines are out of this slice's blast radius
and stay untouched, but no new write line repeats the
pattern (rank 2; names are user text).

## 12. Integrator wiring (LOCKED)

After Builders A and B land (section 14), the integrator
— in the same final change set, never as a follow-up —
does exactly this:

1. **README fittings bullet** (`README.md:22`): reword so
   it stops claiming writes are impossible. Locked
   substance (integrator fits the prose to the bullet's
   existing shape): the view remains a saved-fittings
   library with search, EFT copy-out, and local EFT
   import; an imported fitting or a copy of a saved
   fitting can now be **saved to EVE**, and a saved
   fitting can be **deleted from EVE**, each behind an
   explicit in-view confirmation; saving and deleting
   need the EVE SSO scope
   `esi-fittings.write_fittings.v1`, which first sign-in
   deliberately does not request, offered through the
   same step-up flow when a character lacks it; items EVE
   cannot represent are named in the confirmation and
   left out, never silently; after a save or delete the
   list refreshes from EVE (the list is cached by EVE for
   up to five minutes, so a change can take that long to
   appear); nothing fitting-related is stored locally and
   there are still no fitting statistics; **this write
   path has not been live-verified against a real EVE
   account yet** (the bullet's existing caveat stays,
   now covering writes explicitly).
2. **README roadmap** (`README.md:31`): the Fitting
   roadmap line loses "fitting creation/editing/deletion
   in EVE" as wholly unimplemented; locked replacement
   substance: the fitting simulator with statistics,
   fitting **editing** in EVE, and Pyfa import remain not
   implemented; the parenthetical gains "and saving an
   imported fitting or a copy to EVE, plus deleting a
   saved fitting, are in the Fittings view above".
3. **README Status paragraph** (`README.md` "## Status"):
   "The read-only saved-fittings library and local
   in-memory EFT import above are the only fitting
   features" is corrected to include save/copy/delete;
   the simulator sentence stands. The integrator greps
   `README.md`, `CLAUDE.md`, and `docs/*.md` for the
   now-false claims (`never saved to EVE`, `no fitting
   saved in EVE can be created`, `read-only
   saved-fittings`, `write scope is never requested`,
   `no fitting write`) and fixes or records each hit —
   historical design documents keep their text (they
   describe their own slice's scope) but are listed in
   the integrator commit message as intentionally
   historical.
4. **Engineering journal** (`docs/engineering-journal/`):
   one `LEARNINGS.md` entry titled "First ESI writes: an
   unanswered write is an unknown outcome" with Evidence
   (this document sections 7.4/9.1 and the implementing
   commits), Mechanism (reads can be repeated harmlessly;
   a POST whose response was lost may have committed, so
   transport/5xx/decode on a write form a third class
   beside success and refusal — never retried
   automatically, reconciled by refreshing server state),
   and the generalizable rule; plus one `DECISIONS.md`
   entry recording the write-scope-as-separate-step-up
   decision with its rejected alternative (folding write
   into the read group) and a "revisit when" condition.
5. **Settings log tags**: verify only. `LOG_TAGS`
   (`src/ui/settings.rs:7-22`) already contains `[ESI]`
   and `[FITTING]`; the integrator confirms no new tag
   slipped in (section 2) and makes no change.
6. **Gates**: the configured ones (`.github/workflows/ci.yml`):
   `cargo fmt --check`,
   `cargo clippy --all-targets -- -D warnings`,
   `cargo test`, `cargo build`. Every builder runs them
   at each of its commits; every failure is the slice's
   until proven pre-existing on the clean base.

## 13. Test plan (LOCKED)

Mock pattern throughout: the shipped one-shot servers —
`src/esi/client.rs:395+` `mock_server` and
`src/esi/endpoints.rs:894-916` `one_shot_server` with
`client_with_fresh_tokens` (`endpoints.rs:828-843`) —
which capture the raw request. No new test framework, no
network in tests.

**Builder A — request capture (method/path/headers/body):**

1. `fitting_save_posts_exact_body_and_parses_id`: token
   store seeded with a known access token; mock replies
   `201 {"fitting_id": 4242}`. Assert the captured request
   begins `POST /characters/7/fittings/?datasource=tranquility`,
   carries `authorization: Bearer <seeded token>` and a
   JSON content type (reqwest `.json()`), and its body is
   byte-for-byte (after the header terminator):
   `{"name":"My Rifter","description":"Saved from Mimir","ship_type_id":587,"items":[{"flag":"LoSlot0","quantity":1,"type_id":2048},{"flag":"DroneBay","quantity":5,"type_id":2456}]}`.
   Assert the returned `fitting_id == 4242`.
2. `fitting_delete_sends_delete_and_accepts_204_empty`:
   mock replies `204` with an empty body. Assert request
   begins `DELETE /characters/7/fittings/4242/?datasource=tranquility`,
   carries the bearer header, has no body, and the result
   is `Ok(())` — this is the `send_unit` regression test
   (it fails against plain `send`).
3. `fitting_save_scope_failure_needs_reauthorize` and the
   delete twin: mock `403 {"error":"..."}` →
   `classify_write_error` yields `(Definitive, true)`.
   Plus save `401` → same; save `500` → `(Unknown, false)`;
   delete `404` → `(AlreadyGone, false)`; save `404` →
   `(Definitive, false)`; `420` with the mock's
   error-limit headers → `RateLimited`; malformed `201`
   body (`{}` and `not json`) → `Err` classifying `Unknown`;
   no-tokens character → `(NotSent, true)` and the error
   text contains no numeric character id (the shipped
   fittings precedent, `endpoints.rs:1688+`).
4. Classifier unit tests cover every row of the 9.1
   table, including `Status(400)` vs `Status(503)`
   branching on the code and `ErrorLimitExhausted`.
   Mutation-sensitive: flipping `< 500` to `<= 500`, or
   mapping `Http` to Definitive, must each fail a test.

**Builder A — mapper (`src/fitting/write_map.rs`):**
Flutter oracles ported exactly (W1): high-0 → `HiSlot0`,
med-3 → `MedSlot3`, low-7 → `LoSlot7`, rig-2 → `RigSlot2`,
subsystem-3 → `SubSystemSlot3`, each `quantity: 1`,
nothing dropped; rig slot 3 → `items` empty, one dropped
with that type id; a slot item with source quantity 9 →
kept with quantity forced to 1 (mutation: passing the
quantity through must fail). New boundary cases, each
paired in-range/out-of-range: `LoSlot7` kept/`LoSlot8`
dropped, `RigSlot2`/`RigSlot3`, `SubSystemSlot3`/
`SubSystemSlot4`, `ServiceSlot7` kept/`ServiceSlot8`
dropped, `Invalid` dropped, `loslot0` (lowercase)
dropped, empty flag dropped, duplicate `HiSlot0` (first
kept, second `DuplicateSlot`), `DroneBay` quantity 5
kept verbatim / quantity 0 and −3 dropped, `Cargo`
quantity kept verbatim, `type_id: 0` dropped even with a
valid flag, order preservation across a mixed list.
Name cases: normal name untouched; whitespace-only and
empty → `Unnamed fit` with flag set; exactly 50 chars
untouched with `name_truncated_from == None`; 51 chars →
first 50 and `Some(51)`; 51 × `é` → 50 `é` characters
(byte-length 100 — a byte-based truncation must fail
this); leading/trailing spaces trimmed before counting.
Description cases: `None` and `Some("")` →
`Saved from Mimir`; a real description passes through
sanitized; 501 chars → 500 with the flag set.
`sanitize_for_save` cases: embedded newline/tab/control
character collapse to single spaces exactly as the UI
twin does (a drift between the twins must fail here). Guards:
empty source items → un-saveable signal; 512 kept items
saveable / 513 not; `ship_type_id: 0` not saveable.

**Builder B — state, landing, UI text (pure helpers):**
state defaults (all new fields `None`/`false` for both
demo and live); switch/removal resets clear confirm,
request, pending selection, and the write flag (and
removal of a *non*-active character clears none of the
active character's, mirroring the shipped import tests
`src/app/state.rs:1683-1777`); the landing helper:
mismatched character → drop (no status mutation signal,
no refresh signal) yet flight cleared; matched Saved →
refresh + pending recorded; matched Unknown → refresh,
no pending; matched Definitive → neither;
`apply_pending_fitting_selection`: Ok-contains selects
and consumes, Ok-missing consumes without selecting,
Err keeps, wrong character ignored;
`fittings_write_stepup_observed` truth table (3.4);
wording functions: every 9.2 row rendered exactly for
save and delete (including `{s}` substitution with 42),
the 6.1–6.4 confirmation lines (fallback-name line,
50-char line with the count, charges line, each dropped
reason line, and the overflow line: 10 dropped with
resolved names produce 8 named lines plus `2 more
item(s) will be left out.`),
and the two un-saveable labels.

**Integrator:** full-suite run; a grep gate that no new
log line in the diff formats a fitting `name`/`description`
(section 11) and that `retry` appears in no new write-path
identifier; manual demo pass confirming the demo labels
and zero write buttons.

## 14. Ownership split and commit plan (LOCKED)

Cross-builder contracts (neither builder changes these
signatures unilaterally): `SaveFittingRequest` /
`SaveFittingResponse` field order (4.1);
`build_save_request` / `SaveMapping` / `DropReason`
(4.2); `save_character_fitting` /
`delete_character_fitting` / `classify_write_error` /
`WriteFailureClass` (4.1, 5.2, 9.1);
`FITTINGS_WRITE_SCOPES` (3.1); `FittingWriteConfirm` /
`FittingWriteRequest` / `FittingWriteInFlight` /
`FittingWriteKind` / `FittingWriteOutcome` and the three
new `AppState` fields plus flag and pending selection
(6, 7.1, 8) — `WriteFailureClass` lives with Builder A's
classifier in `src/esi/endpoints.rs` and Builder B's
`FittingWriteOutcome` references it; the two save sources
both end at `FittingWriteRequest::Save` carrying a
finished `SaveFittingRequest`, so the shell never touches
mapping logic.

| Owner | Files | Commits (each gated by its tests) |
|---|---|---|
| Builder A | `src/config.rs`, `src/esi/models.rs`, `src/esi/client.rs`, `src/esi/endpoints.rs`, `src/fitting/write_map.rs`, `src/fitting/mod.rs` | `feat(fittings): add write step-up scope group` · `feat(esi): add authenticated delete seam` · `feat(fittings): map a fitting to its ESI save body` · `feat(esi): save and delete character fittings` (endpoint fns + classifier) |
| Builder B | `src/app/state.rs`, `src/app/shell.rs`, `src/ui/fittings.rs` | `feat(fittings): add write state and landing rules` (fields, resets, drain, `start_fitting_write` incl. 3.3 pre-check, handler, pending selection, observed arm) · `feat(fittings): confirm and run fitting writes in the view` (arm/confirm blocks, write panel, in-flight, demo labels, 10 rewordings) |
| Integrator | `README.md`, `docs/engineering-journal/`, the 12.3 sweep | `docs(fittings): disclose fitting writes and record the unknown-outcome lesson` |

Builder order: A first (B compiles against A's endpoint
and classifier signatures), B second, integrator last.
Commit format `type(scope): description`, small and
atomic, no attribution lines. Nobody pushes or merges;
the parent does.

## 15. Rejected alternatives (LOCKED)

- **Folding the write scope into `FITTINGS_SCOPES`** —
  rejected (rank 3): every existing user would silently
  gain write permission the first time the read step-up
  re-asked, and "has the read group" would stop being
  evidence about writes. The `STRUCTURE_SCOPES` precedent
  is a separate group per permission.
- **Flutter fidelity for drones/cargo (silently omit)** —
  rejected: the live enum proves both flags are accepted
  on POST, so omission loses user data for no reason;
  and Flutter's silent part is the flaw this slice's
  disclosure rules exist to remove.
- **Retrying a timed-out POST once** — rejected (rank 1):
  there is no idempotency key in this API; a blind retry
  is precisely a duplicate-fitting generator.
- **Optimistic list updates** (insert/remove locally on
  success, correct on refresh) — rejected (rank 2): the
  UI would present server state it has not observed; the
  300-second cache makes even the honest refresh laggy,
  which the wording discloses instead of papering over.
- **A modal confirmation dialog** — rejected (rank 5):
  the app has one confirmation idiom and egui modal
  traps are the thing it avoids by name.
- **Giving `send<T>` a 204 special case** — rejected
  (rank 5 blast radius): every read path depends on
  `send`'s exact decode discipline; a sibling
  `send_unit` changes no shipped behavior.
- **Auto-replaying a write after its step-up completes**
  — rejected (ranks 1–2): consent would outlive the
  context it was given in (possibly across a character
  switch and a browser round trip).

## 16. Discrepancies and open risks (recorded honestly)

1. **Trailing slash.** The OpenAPI templates are
   `/characters/{character_id}/fittings` and
   `…/fittings/{fitting_id}` (no trailing slash); the
   shipped Rust read path, the Flutter POST, and every
   other endpoint in this app use the trailing-slash
   form against the same base URL, and ESI accepts it for
   the read. Design follows running code for POST and,
   by family consistency, DELETE. DELETE has no
   running-code witness anywhere — if live verification
   shows the slashed DELETE 404s where the unslashed
   succeeds, the fix is one format string; the taxonomy
   already reports such a 404 truthfully (AlreadyGone
   would be a misreport in that world — flagged here so
   live verification checks this first).
2. **Not live-verified.** No request in this slice has
   been sent to a real EVE account. The README caveat
   (12.1) stays until someone saves and deletes a real
   fitting and watches the list settle.
3. **POST success is trusted from the receipt, selection
   from the list.** A 201 + `fitting_id` is claimed as
   saved even though the cached GET may not show the
   fitting for up to 300 seconds (specification
   `x-server-cache-ttl`). Section 8.1's first-refresh-only
   pending selection may therefore legitimately not
   select a genuinely saved fitting; the status text
   says "Refreshing…" and the integrator README discloses
   the five-minute window rather than claiming the
   fitting will appear.
4. **Name length unit.** Flutter truncated by UTF-16
   code unit; design truncates by Unicode scalar
   (character), matching JSON Schema `maxLength`
   semantics as ESI publishes them. Astral-plane
   characters in names are the only observable
   difference; no inspected body arbitrates further.
5. **Duplicate names.** Nothing in the specification
   says fitting names are unique, and a copy (6.2) sends
   the same normalized name as its original. Design
   neither appends "copy" nor claims EVE will hold two
   same-named fittings — if ESI refuses, the refusal is
   Definitive and reported as such.
6. **Every 403 is routed to re-authorize** (9.1): if ESI
   returns 403 for a non-scope reason on these endpoints,
   the user is offered a step-up that will not fix it.
   Bounded harm (one declinable panel), recorded rather
   than engineered around with an ungrounded
   discriminator.
7. **`ServiceSlot0–7` pass-through on copy** is grounded
   only in the specification enum (Flutter never emitted
   one; the Rust renderer groups them into its Cargo
   catch-all, `src/ui/fittings.rs:42-55`). Structure
   fittings are thus copyable in principle; their
   in-game result is unverified like everything in
   item 2.
8. **`classify_write_error` maps 5xx to Unknown.** Some
   5xx responses certainly mean "not committed"; without
   a discriminator the safe class wins (rank 1). The
   user cost is a refresh-and-look instead of a flat
   failure message.
