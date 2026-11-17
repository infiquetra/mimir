# Character portraits — design

Slice goal: show the EVE portrait for each character on the surfaces
where Flutter showed them (the Characters switcher list and active
character detail, and the Dashboard all-characters grid), fetched from
the EVE image service, decoded and rendered as egui textures, with an
on-disk cache in the app cache directory, character-keyed async
landing, bounded size and concurrency, and honest placeholders.

Builder split: Builder A owns the fetch/cache/state layer plus tests
(`src/portraits.rs`, `src/app/state.rs`, `src/app/shell.rs`,
`src/lib.rs`, `src/main.rs` wiring). Builder B owns rendering
(`src/ui/characters.rs`, `src/ui/dashboard.rs` and its texture cache).

Note: this document is written by Builder A because the planned design
pass (prior result 1) failed with a generator error and no
`docs/portraits-design.md` or `feat/rust-portraits` branch existed.
Every contract below was derived from the slice goal text and the
codebase's own seams this session.

## 1. Fetch layer (`src/portraits.rs`)

- `PortraitClient`: unauthenticated `reqwest::Client::new()`-style
  client against `EveConfig::IMAGE_SERVER_URL`, with a
  `with_base_url(String)` test seam mirroring `EsiClient::with_base_url`.
  Portraits are public; no token is fetched or attached.
- Request shape: `GET {base}/characters/{id}/portrait?size={size}` via
  `EveConfig::portrait_url` (extended to take the client base, or a
  host-relative builder in this module mirroring that path exactly).
- One fixed size for the whole app: `PORTRAIT_SIZE: u32 = 256`
  (renders downscale it; nothing upscales past decode).
- Bounded body: streamed with a chunk loop, aborting above
  `MAX_IMAGE_BYTES` (1 MiB). A missing version of the bytes never
  reaches decode.
- Bounded decode: `decode_portrait(bytes)` rejects bodies above the
  byte cap and decoded images whose width or height exceeds
  `MAX_IMAGE_DIMENSION` (1024). Decode failures are errors, never
  placeholders.
- `PortraitError` (thiserror, `[PORTRAIT]` display prefix, no URLs,
  no tokens, no user text): `Http(reqwest::Error)`, `Status(u16)`,
  `TooLarge`, `Decode(String)`, `CacheIo(String)`.

## 2. On-disk cache

- Directory: `{app_cache_dir}/portraits/` via
  `crate::storage::db::app_cache_dir` (per-OS cache dir, never the
  database — see `src/storage/db.rs:21`).
- Naming: `{character_id}_{size}.jpg`, character-keyed so one
  character's bytes can never serve another's slot.
- `PortraitStore::read_cached` / `write_cached`. Writes go to a temp
  file in the same directory and rename, so a torn write never poisons
  the next read. A cached body that fails decode is a miss: the entry
  is dropped and refetched once.
- Lookup is cache-first: a hit makes zero network calls.

## 3. Async orchestration and concurrency

- `PortraitService { client, store, semaphore }` with
  `MAX_CONCURRENT_FETCHES = 4` (`tokio::sync::Semaphore` permits,
  `acquire_owned` inside the spawned task). The semaphore is the only
  concurrency limiter; the shell spawns one task per requested id and
  the semaphore queues the rest.
- `PortraitService::portrait(id, size)`
  (`async Result<Arc<DynamicImage>, PortraitError>`): cache hit →
  decode → return; miss → fetch → write cache → decode → return.
- Demo mode: the shell drain never spawns in `state.demo`, so demo
  mode makes zero network calls even if a view requests a portrait.
  Construction of the service itself performs no I/O.

## 4. State (`src/app/state.rs`)

- `pub enum PortraitState { NotRequested, Loading,
  Ready(Arc<image::DynamicImage>), Failed }` stored per character in
  `pub portraits: HashMap<i64, PortraitState>` on `AppState`. The
  decoded image (not raw bytes) is stored so decode happens once at
  landing, not per frame.
- `pub portrait_requests: Vec<i64>` — the request queue. Views call
  `AppState::request_portrait(id)`; the shell drains it with
  `take_portrait_requests()`. `request_portrait` ignores unknown ids,
  no-ops for `Ready`/`Loading` entries, dedups queued ids, and turns
  `NotRequested`/`Failed` onto `Loading` plus one queued id.
- Character switching never clears the map: entries are keyed by
  character id, so a late result for a switched-away character writes
  only its own slot and can never paint the new active character's
  portrait (the keyed-summary precedent). `remove_character` drops
  the removed id's entry and queued requests; emptying the character
  list clears both.
- `pub fn portrait_state(&self, id) -> &PortraitState` returns
  `NotRequested` for absent ids.

## 5. Shell landing (`src/app/shell.rs`)

- New `BackendMsg::PortraitFetched { character_id, image:
  Result<Arc<DynamicImage>, PortraitError> }`, sent by the spawned
  task when the service resolves (success or failure — failures land
  as `Err` and become `PortraitState::Failed`).
- Landing (`apply_portrait_landing`, a pure free function next to
  `decide_fitting_write_landing`): applies only when the character is
  still in `state.characters` (removed characters cannot be
  resurrected, the `Refreshed` summary precedent); the keyed insert
  is the whole correctness argument for switched-away characters.
- Start decision (`decide_portrait_start` + `PortraitStartRefusal`
  `{ Demo, BackendsMissing }`, mirroring the fitting-write refusal
  table): demo → never spawn (state stays `Loading`, which renders
  as the placeholder); backends/runtime missing → spawn nothing and
  mark `Failed` so the view shows the failure placeholder instead of
  spinning forever.
- Drain site: immediately after the `fittings_write_requested` take,
  inside `drain_requests`.
- `Backends` gains `portraits: Arc<PortraitService>`, constructed in
  `src/main.rs` with `db::app_cache_dir()`; the service's semaphore
  and cache directory are created once, app-wide.

## 6. Placeholders (Builder B contract; pure helper now)

- `initial_for_name(name) -> Option<char>` in `src/portraits.rs`:
  first alphabetic character, ASCII-uppercased; `None` when the name
  has none. Builder B renders initial or name text for
  `NotRequested`/`Loading`/`Failed` and demo mode.
- Never a fabricated or stock face, never another character's image:
  only `PortraitState::Ready` for that exact character id renders an
  image.

## 7. Logging

- `[PORTRAIT]` tag on every public function and state change (the
  `lib.rs` feature-tag rule). Character ids are logged as plain
  `character_id={}` integers, matching the existing `[CHAR]`/`[ESI]`
  convention. No URLs, no tokens, no character names, no error bodies.

## 8. Tests (Builder A, hand-derived literals)

- `src/portraits.rs`: cache naming literals, `initial_for_name` cases,
  decode dimension round-trip on a generated 4×3 PNG, byte-cap and
  dimension-cap rejections, store round-trip in a temp dir,
  one-shot mock-server fetch (path literal
  `/characters/90000001/portrait?size=256`, 8×8 decoded dims),
  404 → `Status(404)`, oversized body → `TooLarge`, cache-first
  second fetch with no server, semaphore permit count.
- `src/app/state.rs`: queue dedup, unknown-id ignore, Ready no-op,
  Failed re-request, drain, remove drops entry + queued id, empty
  list clears, default `NotRequested`.
- `src/app/shell.rs`: `decide_portrait_start` table (demo, missing
  backends, allowed), `apply_portrait_landing` for present,
  switched-away, and removed characters (active character's entry
  provably untouched).
