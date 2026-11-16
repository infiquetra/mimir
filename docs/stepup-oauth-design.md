# Step-Up OAuth — Design

Status: design only. No code is created by this document.
Repo: `/home/jefcox/workspace/infiquetra/mimir`, branch `feat/stepup-oauth`
off `develop` at ff7886e (Assets slice merged). Every `file:line`
reference below was read in full at that commit.

## 1. What this solves, in plain terms

First sign-in deliberately requests only the least-privilege scope set
(`EveConfig::FIRST_AUTH_SCOPES`, `src/config.rs:25-32`). The Assets view
needs one more EVE permission, `esi-assets.read_assets.v1`, which first
sign-in never requests. Today that character gets HTTP 403 on the assets
fetch, and the view shows honest guidance with no working button
(assets-port design decision D4, `docs/assets-port-design.md:137`;
`reauthorize_panel`, `src/ui/assets.rs:158-171`).

Step-up sign-in is the fix: an already signed-in character re-runs the EVE
SSO browser flow once, asking EVE for the scopes it already granted
**plus** the new one, and Mimir replaces the stored tokens with the new
wider-grant tokens — but only when the person who approved in the browser
is the same character the button was clicked for. This is the progressive
step-up mechanism the rewrite design already committed to
(`docs/rust-rewrite-design.md:24`, decision row "First-auth scopes":
extra scopes "become progressive step-up requests when those views are
first opened").

### Inspected current state (the pieces this design reuses)

- Scoped authorize primitive exists and is unused by the shell:
  `create_authorization_request_with_scopes(scopes: &str)`
  (`src/auth/oauth.rs:220-232`) builds PKCE + state + authorize URL for
  any space-separated scope string. `create_authorization_request()`
  (`:215-218`) is the same call with `first_auth_scopes_string()`.
- Granted scopes are already persisted per character, without any token
  value: `TokenMetaRow { character_id, scopes: String, expires_at }`
  (`src/storage/repositories.rs:94-101`), written at login from
  `claims.scp.join(" ")` (`src/app/shell.rs:782-791`), read back with
  `get_token_meta` (`src/storage/repositories.rs:1020-1040`), upserted
  with `set_token_meta` (`:1003-1018`). The `token_meta` table already
  stores scopes + expiry, so no schema change is needed or allowed.
- JWT claims already expose what validation needs:
  `JwtClaims::character_id()` parses `CHARACTER:EVE:<id>` from `sub`
  (`src/auth/oauth.rs:82-90`), `scp` deserializes from either EVE shape
  (space-separated string or array, `:42-60`, `:74-75`), and `name`/`exp`
  are fields (`:64-80`). Parsing is `parse_jwt_claims` (`:261-274`),
  without signature verification — a pre-existing named gap this design
  does not change (Section 9).
- Callback validation is one reusable call:
  `CallbackParams::into_result(expected_state)`
  (`src/auth/callback_server.rs:48-64`) maps SSO `error` to
  `AuthError::Denied`, state mismatch to `AuthError::StateMismatch`, and
  an empty code to `AuthError::MissingCode`. `start_login` uses it at
  `src/app/shell.rs:774`; step-up reuses it unchanged.
- First sign-in flow, the shape step-up mirrors: `start_login`
  (`src/app/shell.rs:747-816`) creates the request, opens the browser
  with `open::that` (URL never logged, `:761-762`), sets
  `AuthState::AwaitingCallback`, then spawns callback wait → state check
  → `oauth::exchange_code` → claims → `StoredTokens::from_token_response`
  → `TokenStore::save` → `set_token_meta`, and reports
  `BackendMsg::LoggedIn` / `LoginFailed`. `LoggedIn` is handled at
  `:489-499` (auth success, push-if-new, set active, post-login refresh);
  `LoginFailed` at `:500-504`.
- "Refresh instead of browser" already has a mechanism:
  `EsiClient::valid_access_token` (`src/esi/client.rs:172-201`) loads
  stored tokens and refreshes + persists them whenever the access token
  is expired or inside the 60-second buffer. A refresh-token grant keeps
  the scopes EVE originally granted, so if the assets scope is already
  granted, a normal data refresh is sufficient — no browser round-trip.
- Views never do work; they set request flags the shell drains each
  frame (`src/app/state.rs:1-7`, flag block `:241-248`;
  `drain_requests`, `src/app/shell.rs:396-535`). The closest flag
  precedents are `login_requested: bool` (set by
  `src/ui/characters.rs:27`, drained at `src/app/shell.rs:525-528`) and
  `logout_requested_id: Option<i64>` (drained with `.take()` at `:529`).
- The Assets scope-failure surface already exists end to end:
  `endpoints::needs_reauthorize` (`src/esi/endpoints.rs:402-407`)
  classifies 403/401, the refresh carries `assets_needs_reauthorize`
  (`src/app/state.rs:217-219`), and `show` branches to
  `reauthorize_panel` on that flag (`src/ui/assets.rs:180-184`). This
  design gives that panel a real button; it adds no new surface.
- Guard test that must keep passing untouched:
  `first_auth_scopes_match_least_privilege_set`
  (`src/config.rs:120-126`) asserts the first-auth string contains the
  skills/wallet scopes and does **not** contain `esi-assets`.

## 2. Decisions locked by this design

A builder who disagrees stops and raises it; none of these is re-decided
silently in code.

| # | Decision | Reason |
|---|---|---|
| S1 | One new request flag, `stepup_requested: Option<StepUpRequest>`, carrying `character_id` + requested scopes. Views only set it; the shell drains it with `.take()` | Exactly follows the `logout_requested_id` precedent and the "views set flags only" rule. Carrying the character id in the request (not "whoever is active later") is what makes the mismatch check in S5 meaningful. |
| S2 | The authorize request asks for granted ∪ requested scopes, never for the new scope alone | An EVE SSO token carries the scopes requested at authorize time. Asking only for `esi-assets.read_assets.v1` would mint a replacement token without the skills/wallet scopes and break every other view. The union preserves the existing grant. |
| S3 | Pre-check granted scopes from `token_meta`; if nothing is missing, skip the browser and just request a data refresh | `valid_access_token` already refreshes the access token from the stored refresh token, and the refreshed token keeps the granted scopes. Opening a browser to re-grant what is already granted is pure friction. The typed 403 from the real fetch remains the truth for showing the panel (assets-port D3); the pre-check only avoids a redundant browser trip. |
| S4 | `start_login` is not refactored. Step-up is a new shell function, `start_stepup_login`, mirroring its callback/exchange tail | First-authorization behaviour must stay byte-for-byte in scope content. Leaving `start_login` literally untouched makes that provable by `git diff`. The duplicated tail is small and the reuse is at the primitive level (`into_result`, `exchange_code`, `parse_jwt_claims`, `TokenStore::save`, `set_token_meta`). Revisit if a third scoped flow appears. |
| S5 | After exchange, returned claims are validated against the expected character **before** anything is saved. Mismatch aborts without saving tokens or token metadata, and without revoking anything | The browser user can approve as any EVE account. Saving another character's tokens under this flow would silently replace the clicked character's working tokens. Aborting before `StoredTokens` construction leaves the old tokens and `token_meta` row untouched, so skills/wallet keep working. The mismatched tokens are simply dropped (never logged, never persisted); revoking them would be an action against a grant this flow does not own. |
| S6 | If the returned claims still lack any requested scope, abort without saving (same failure message path) | Guards against a downgrade: a replacement token that did not gain the requested scope must not displace the existing refresh token. The existing login already trusts `claims.scp` (it persists it as `token_meta.scopes`), so checking it here is consistent. |
| S7 | A distinct `BackendMsg::StepUpLoggedIn { character_id }` instead of reusing `LoggedIn` | `LoggedIn` pushes a character row and forces it active (`src/app/shell.rs:489-499`). Step-up is for an existing character; if the user switched characters while the browser was open, step-up must not steal the active character back. The new arm only marks auth success and refreshes when the stepped-up character is still active. |
| S8 | One additive config constant, `EveConfig::ASSETS_SCOPES = &["esi-assets.read_assets.v1"]`. `WALLET_SCOPES` is not reused | `WALLET_SCOPES` (`src/config.rs:48-53`) also carries wallet + loyalty scopes; the asset endpoints need only the single scope (assets-port D2). The consent screen should ask for the minimum. `FIRST_AUTH_SCOPES` contents are not touched. |
| S9 | One additive error variant, `AuthError::CharacterMismatch`, with no payload | A typed variant is directly testable and lets the shell log both character ids (allowed; ids are not secrets) at the warn site. No token material can enter it. Reusing `AuthError::Message` was rejected: stringly-typed and untestable by variant match. |
| S10 | Demo mode can never open a browser from step-up: the shell checks `state.demo` first in `start_stepup_login`, the Assets button is disabled in demo, and the panel is normally unreachable in demo (demo seeding sets `assets_needs_reauthorize = false`, `src/demo/data.rs:527`) | Three layers, with the shell check as the authoritative one because flags can be set by any future view. Demo is sample data with no network; an SSO browser trip from demo is always wrong. |

## 3. State shape (Builder A, `src/app/state.rs`)

New type near `AuthState` (`src/app/state.rs:98-122`), and one new field
in the request-flag block (`:241-248`):

```rust
/// Step-up sign-in request: re-run EVE SSO for an existing character to
/// grant `scopes` in addition to what it already granted. Set by views;
/// drained by the shell. Scopes are not secrets; no token material here.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StepUpRequest {
    pub character_id: i64,
    pub scopes: Vec<String>,
}

impl StepUpRequest {
    pub fn new(character_id: i64, scopes: &[&str]) -> Self {
        Self {
            character_id,
            scopes: scopes.iter().map(|s| s.to_string()).collect(),
        }
    }
}
```

```rust
// inside AppState, in the request-flag block:
pub stepup_requested: Option<StepUpRequest>,
```

Rules:

- Default is `None` via the existing `#[derive(Debug, Default)]` on
  `AppState` (`:204-205`); nothing is added to `AppState::new`.
- The module doc comment (`:1-7`) gains `stepup_requested` in its flag
  list. The "no token material is ever stored in this struct" guarantee
  is unchanged: scopes and a character id are not secrets.
- `remove_character` (`:328-352`) clears a pending request for the
  removed character, beside the existing
  `self.assets_needs_reauthorize = false;` (`:344`):
  `if self.stepup_requested.as_ref().map(|r| r.character_id) == Some(character_id) { self.stepup_requested = None; }`.
  A pending request for a *different* character is kept.
- `set_active_character` does not touch the flag. The request names its
  own character, and the shell validates against that id regardless of
  who is active when the browser returns (Section 5, step 11).
- No new `AuthState` variant. Step-up reuses `AwaitingCallback`
  (label "Waiting for EVE SSO in your browser...", `is_busy() == true`),
  so the Characters view spinner and `needs_tick` repaint work unchanged.
- Re-export: `AppState`, `AuthState`, and `StepUpRequest` are consumed by
  the shell via `super::state::{...}` (existing import at
  `src/app/shell.rs:8-10`); Builder B adds `StepUpRequest` to that list.
  `src/lib.rs` is not edited.

## 4. Pure scope/claims logic (Builder A, `src/auth/oauth.rs`)

Four new public functions plus two small helpers. All are pure: no I/O,
no clock, no randomness, fully unit-testable in the existing
`#[cfg(test)] mod tests` (`src/auth/oauth.rs:453-551`). Scope names and
character ids may be logged; these functions receive no token values
(`validate_expected_character` receives already-parsed `JwtClaims`).

```rust
/// Split a space-separated EVE scope string (the `token_meta.scopes`
/// shape) into individual scopes. Empty input yields an empty vec.
pub fn split_scopes(scopes: &str) -> Vec<String>;

/// Join scopes into the space-separated form EVE SSO expects.
pub fn join_scopes(scopes: &[String]) -> String;

/// Granted ∪ requested, first occurrence wins: granted order first,
/// then requested scopes not already present, in requested order.
/// Exact string equality; empty strings are skipped. Duplicates inside
/// either input collapse to their first occurrence.
pub fn union_scopes(granted: &[String], requested: &[String]) -> Vec<String>;

/// Requested scopes not present in granted, in requested order,
/// duplicates collapsed, empty strings skipped. Empty result means
/// "already granted" (including when `requested` is empty).
pub fn missing_scopes(granted: &[String], requested: &[String]) -> Vec<String>;

/// Validate that exchanged token claims belong to the character the
/// step-up was started for. Ok carries the validated character id.
/// Unparsable `sub` -> AuthError::MalformedToken (same as the
/// first-login tail); a different character -> the new
/// AuthError::CharacterMismatch. Logs expected/actual ids at warn on
/// mismatch under [AUTH]; never receives or logs token values.
pub fn validate_expected_character(
    claims: &JwtClaims,
    expected_character_id: i64,
) -> Result<i64, AuthError>;
```

Notes for the builder:

- The existing private `ssplit_scopes` (`:58-60`, used only by
  `deserialize_scp`) stays untouched. `split_scopes` is a new public
  function with the same `split_whitespace` body; do not rename or
  rewire the deserializer.
- Shell call sites use full paths (`crate::auth::oauth::union_scopes`,
  the style `start_login` already uses at
  `src/app/shell.rs:753,775,776`). `src/auth/mod.rs` re-exports are not
  edited (it does not re-export `create_authorization_request_with_scopes`
  either).
- `AuthError::CharacterMismatch` is added in `src/error.rs` after
  `StateMismatch` (current `:94-95`), display text:
  `[AUTH] step-up sign-in returned a different character than expected`.
  Builder A owns this one additive variant; Builder B does not touch
  `src/error.rs`.
- New additive constant in `src/config.rs`, placed after `WALLET_SCOPES`
  (`:48-53`):

```rust
/// Assets step-up scopes: granted after first sign-in via the
/// step-up OAuth flow, never at first authorization.
pub const ASSETS_SCOPES: &[&str] = &["esi-assets.read_assets.v1"];
```

  `FIRST_AUTH_SCOPES` (`:25-32`), `first_auth_scopes_string` (`:90-92`),
  and the existing guard test (`:120-126`) are not modified. A *new*
  test asserts `ASSETS_SCOPES` is exactly that one scope and that
  `FIRST_AUTH_SCOPES` does not contain it.

## 5. Shell flow (Builder B, `src/app/shell.rs`)

### 5.1 Drain point

In `drain_requests`, immediately after the `login_requested` block
(`:525-528`) and before the logout/delete drains (`:529-534`):

```rust
if let Some(request) = self.state.stepup_requested.take() {
    self.start_stepup_login(request);
}
```

`.take()` consumes the flag on every path, including early returns, so a
rejected request can never loop frame after frame.

### 5.2 `start_stepup_login(&mut self, request: StepUpRequest)`

Placed directly after `start_login` (`:747-816`), which it mirrors.
Exact ordered steps; every log line uses `tracing` with a bracketed tag.

1. **Demo guard, first, before anything else.** If `self.state.demo`:
   `tracing::warn!("[AUTH] step-up ignored in demo mode character_id={}", request.character_id)`,
   set `status_message` to
   `"Demo mode uses sample data; EVE sign-in is disabled."`, return.
   No authorize request is created, `open::that` is not called, no
   callback listener is bound, `auth` is not touched (Section 6).
2. **Busy guard.** If `self.state.auth.is_busy()`: warn `[AUTH]` that a
   sign-in is already in progress (with character id), set
   `status_message` to
   `"Sign-in already in progress; finish it in your browser first."`,
   return. This prevents a second `CallbackServer` racing the first for
   the fixed bind `127.0.0.1:54321` (`EveConfig::CALLBACK_BIND`,
   `src/config.rs:20`).
3. **Backends guard.** Mirror `start_login` `:748-752`: if backends or
   runtime are missing, set
   `"Step-up sign-in unavailable: live backends not wired."` and return
   (auth state untouched, same as first login there).
4. **Known-character guard.** If no row in `self.state.characters` has
   `character_id == request.character_id`: warn `[AUTH]`, set
   `status_message` to
   `"Step-up sign-in skipped: that character is no longer in Mimir."`,
   return. Covers a character deleted between click and drain.
5. **Granted-scope pre-check.** Lock `backends.db` and call
   `repositories::get_token_meta(&conn, request.character_id)`:
   - `Ok(Some(meta))` → `granted = oauth::split_scopes(&meta.scopes)`.
   - `Ok(None)` → `granted = vec![]`, debug `[AUTH]` "no token_meta row;
     treating granted scopes as empty".
   - `Err(e)` → `granted = vec![]`, warn `[AUTH]` with the error.
     Failure falls toward the browser flow, which re-validates
     everything; it never falls toward skipping consent.
   Then `missing = oauth::missing_scopes(&granted, &request.scopes)` and
   one info line logging character id, granted count, the requested
   scope names (scopes may be logged), and missing count.
6. **Already-granted path (no browser).** If `missing.is_empty()`:
   info `[AUTH]` "step-up skipped; scopes already granted", set
   `status_message` to `"That permission is already granted. Refreshing..."`,
   call `self.state.request_refresh("stepup-already-granted")`, return.
   Do not clear `assets_needs_reauthorize` here and do not touch `auth`:
   the refresh outcome is the truth (`Refreshed` Ok clears the flag at
   `:438`; a repeated scope refusal re-sets it at `:440-445`). The
   refresh reaches ESI through `valid_access_token`
   (`src/esi/client.rs:172-201`), which performs the token refresh from
   the stored refresh token when needed — the shell makes no direct
   `oauth::refresh_*` call. An empty `request.scopes` also lands here
   (a harmless no-op refresh); the browser is never opened with an
   empty scope string.
7. **Scoped authorize request.** `union = oauth::union_scopes(&granted, &request.scopes)`,
   `scopes_string = oauth::join_scopes(&union)`, debug `[AUTH]` with
   the union scope names + count. Then
   `oauth::create_authorization_request_with_scopes(&scopes_string)`;
   on `Err(e)` mirror `:755-759`: `auth = AuthState::Error`,
   `status_message = format!("Step-up sign-in failed: {e}")`, return.
8. **Open browser.** Mirror `:761-767` exactly: info
   `"[AUTH] opening browser for EVE SSO step-up (url not logged with state)"`,
   `open::that(request.authorize_url.as_str())`; on error, `Error` auth +
   `"Could not open browser: {e}"`, return. The full authorize URL is
   never logged or put in a status message (it embeds the CSRF state).
   Then `self.state.auth = AuthState::AwaitingCallback`.
9. **Spawned tail.** Clone `token_store`, `db`, `tx` as at `:768-770`;
   move an owned `expected_character_id = request.character_id` and an
   owned `requested_scopes = request.scopes` into the task. The async
   outcome, step by step:
   1. `let params = CallbackServer::new().wait_for_callback().await?;`
      (unchanged, `:773`).
   2. `let code = params.into_result(&request.state)?;` — the existing
      CSRF state check, reused unchanged (`:774`). Denied, mismatched
      state, and missing code all fail here before any exchange.
   3. `let tokens = oauth::exchange_code(&code, &request.pkce.verifier).await?;`
      (unchanged, `:775`).
   4. `let claims = oauth::parse_jwt_claims(&tokens.access_token)?;`
      (unchanged, `:776`).
   5. `let character_id = oauth::validate_expected_character(&claims, expected_character_id)?;`
      — **before** any save. On mismatch or malformed `sub` the `?`
      returns the error, `tokens` is dropped unsaved, and neither
      `TokenStore::save` nor `set_token_meta` runs. The previously
      stored tokens and metadata for the expected character remain
      exactly as they were.
   6. Scope-gain check (decision S6):
      `let still_missing = oauth::missing_scopes(&claims.scp, &requested_scopes);`
      If non-empty: warn `[AUTH]` with character id and the still-missing
      scope names, and return
      `AuthError::Message("EVE did not grant the requested scope(s); nothing was saved")`
      as the outcome error (tokens dropped unsaved, as in step 9.5).
   7. `let stored = StoredTokens::from_token_response(character_id, &tokens); token_store.save(&stored)?;`
      (mirror `:780-781`).
   8. `set_token_meta` with `TokenMetaRow { character_id, scopes: claims.scp.join(" "), expires_at: claims.exp }`
      (mirror `:782-791`, including the best-effort `if let Ok(conn)` /
      `let _ =` shape). Writing the *returned* `claims.scp` (not the
      requested union) keeps `token_meta` an honest record of the grant.
   9. Outcome `Ok(character_id)`.
   Send `BackendMsg::StepUpLoggedIn { character_id }` on success and the
   existing `BackendMsg::LoginFailed { message: e.to_string() }` on any
   error (mirror `:805-814`), so denial/timeout/mismatch all surface
   through the existing `LoginFailed` arm (`:500-504`: auth error +
   `"Sign-in failed: {message}"` status). Error displays contain no
   codes or token values by construction (`src/error.rs:1`).
10. **New `BackendMsg` variant.** Add `StepUpLoggedIn { character_id: i64 }`
    to the enum (`:34-55`), after `LoggedIn`.
11. **`StepUpLoggedIn` arm** in the `drain_requests` match, after the
    `LoggedIn` arm (`:489-499`), which stays untouched:
    - info `[AUTH] step-up complete character_id={}`;
    - `self.state.auth = AuthState::Success;`
    - `status_message = "Permission granted. Refreshing..."`;
    - if `self.state.active_character_id == Some(character_id)`: set
      `assets_needs_reauthorize = false` and
      `self.state.request_refresh("post-stepup")` (the refresh re-fetches
      assets with the new token; a fresh refusal would re-set the flag);
    - else: warn `[AUTH]` that step-up finished for a non-active
      character and do nothing else — no push, no `set_active_character`,
      no refresh hijack. The next switch to that character refreshes via
      the existing character-switch path (`:508-519`).

### 5.3 What the shell does not change

- `start_login` (`:747-816`), `create_authorization_request()` usage,
  `LoggedIn`/`LoginFailed` arms, `logout`, `delete_character`,
  `start_refresh`: untouched.
- No direct shell call to `oauth::refresh_access_token` / `refresh_with`;
  token refresh stays inside `EsiClient::valid_access_token`.
- No `CallbackServer` change; the fixed `127.0.0.1:54321` listener and
  its 300-second timeout (`EveConfig::CALLBACK_TIMEOUT_SECS`) are shared
  with first login, serialized by the busy guard in step 2.

## 6. Demo guard

Contract: in demo mode, step-up can never open a browser, bind the
callback listener, exchange a code, or save a token.

1. Authoritative layer — shell: the `state.demo` check is step 1 of
   `start_stepup_login` (Section 5.2), before any request creation. It
   returns after a warn log + status message. Because the flag is
   consumed with `.take()` at the drain point, a demo click cannot spin.
2. Source layer — view: the Assets Re-authorize button is disabled when
   `state.demo` (Section 7), so the flag is not set in the first place.
3. Reachability layer: demo seeding clears `assets_needs_reauthorize`
   (`src/demo/data.rs:527`) and demo refresh swaps bundled data without
   network (`start_refresh` demo branch, `src/app/shell.rs:538-545`),
   so the panel with the button is not rendered in demo at all.

Named pre-existing gap, explicitly out of this slice: `start_login`
(first/Add-character sign-in) has no `demo` check today. Changing it is
not required for step-up and `start_login` must stay untouched (decision
S4); hardening it is a separate follow-up decision, not silent scope
growth here.

## 7. Assets panel: real Re-authorize button (Builder B, `src/ui/assets.rs`)

The `show` flag branch (`:180-184`) is unchanged in shape: when
`state.assets_needs_reauthorize` is true, render the panel and return.
Only `reauthorize_panel` changes.

- **Signature:** `fn reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState)`
  (was `fn reauthorize_panel(ui: &mut egui::Ui)`, `:158`). `show` passes
  `state` through. The call site's debug log stays.
- **Copy.** Keep heading `"Assets need one more EVE permission."` and
  the first paragraph (names `esi-assets.read_assets.v1`, says no data
  loaded, other views unaffected). Delete the "not in this build yet /
  Demo mode shows…" paragraph (`:165-170`). Replace with, using the
  active character's resolved `name` from `state.active_character()`
  (a name, never a raw id):

  > Choose Re-authorize and Mimir opens EVE SSO in your browser for
  > {name}, asking for the permissions already granted plus this one.
  > Sign in as {name}: approving as a different character is rejected
  > and nothing is saved.

- **Button.** Label exactly `Re-authorize with EVE SSO`. Rendered with
  `ui.add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))`
  (the pattern at `src/ui/characters.rs:21-24`), where
  `enabled = !state.demo && !state.auth.is_busy() && state.active_character_id.is_some()`.
  While `state.auth.is_busy()`, also render `ui.spinner()` and the
  label `"Waiting for EVE SSO in your browser..."` (from
  `state.auth.label()`), mirroring `src/ui/characters.rs:16-19`.
- **On click, exactly these view-layer actions** (views set flags only —
  no OAuth, browser, database, or token call in `src/ui/`):
  1. `tracing::info!("[AUTH] step-up re-authorize requested from Assets view character_id={} scopes={}", active_id, EveConfig::ASSETS_SCOPES.join(" "))`
     (character id and scope names may be logged).
  2. `state.stepup_requested = Some(StepUpRequest::new(active_id, EveConfig::ASSETS_SCOPES));`
     where `active_id` is `state.active_character_id` captured before
     the click block (the panel is only reachable after the
     no-character guard at `:176-179`, but the code still binds via
     `if let Some(active_id)` rather than unwrapping).
  3. `state.status_message = "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();`
     (same string as Add character, `src/ui/characters.rs:28-29`).
- **Not on click:** do not clear `assets_needs_reauthorize`, do not set
  `login_requested` (that is first-auth scopes and would loop back to
  the same 403), do not touch `state.assets`. The panel stays until a
  refresh proves the grant.
- **Imports added by Builder B:** `StepUpRequest` into the existing
  `crate::app::state::{...}` import (`:8`) and
  `use crate::config::EveConfig;`. The scope requested by the button
  comes only from `EveConfig::ASSETS_SCOPES`; the prose scope literal
  in paragraph one is tied to it by Builder A's exact-content test.
- The existing `group_assets` / `filter_groups` / `display_name` code
  and tests (`:239-377`) are untouched, as are the `LoadState` arms,
  including `error_panel_with_retry` for non-scope failures (`:230-235`).
  No Retry button is added to the panel: retry without the grant loops
  into the same 403 (assets-port Section 9 rule, still in force).

## 8. Security and logging rules (both builders)

- Never log or display: access-token values, refresh-token values,
  authorization codes, CSRF state values, PKCE verifiers, or full
  authorize URLs (a URL embeds the state). The existing redacted
  `Debug` impls (`AuthorizationRequest`, `PkcePair`, `TokenResponse`,
  `CallbackParams`, token newtypes) stay the safety net; new code adds
  no `{:?}` of those types and no new field that could carry them.
- May be logged: scope names, scope counts, character ids, character
  counts, expected/actual ids on mismatch, HTTP statuses (already the
  rule at `src/storage/repositories.rs:1004` and `src/auth/oauth.rs:198-201`).
- Every new log line goes through `tracing` with a bracketed tag:
  `[AUTH]` in oauth/state/shell step-up code and the Assets click site;
  no `println!`, no `log` crate, matching the codebase convention
  (for example `src/app/shell.rs:761`, `src/ui/assets.rs:181`).
- UI shows resolved EVE names only: the panel uses the character row's
  `name`; no raw numeric id is rendered anywhere new. Scope strings are
  protocol names, not ids, and are shown as today (`src/ui/assets.rs:161`).
- Tokens still persist only through `TokenStore` (keyring primary,
  `0600` file fallback, `src/auth/token_store.rs:171-201`); the database
  still receives only scopes + expiry via `token_meta`. No token value
  enters `AppState`, `StepUpRequest`, `BackendMsg`, or any status string.
- On mismatch/scope-gain failure the exchanged `TokenResponse` is
  dropped in the spawned task. Nothing is written for either character:
  the expected character keeps its prior grant, and the character who
  actually approved is not added, saved, or revoked by this flow (they
  can still use Add character, which is untouched).

## 9. Explicit non-goals

- **Widening first authorization.** `FIRST_AUTH_SCOPES` contents,
  `first_auth_scopes_string()`, `create_authorization_request()`, and
  `start_login` stay byte-for-byte in scope content; existing tests
  cover them and must pass unmodified.
- **Database schema migration.** No new table or column; `token_meta`
  already stores scopes + expiry. `src/storage/` is not edited:
  `get_token_meta` / `set_token_meta` are reused exactly as they are.
- **New feature modules.** No new file under `src/`, no new view, no new
  endpoint. The only new file in the whole slice is this design doc.
- **JWT signature verification.** Claims stay parsed without JWKS
  verification, as today (`src/auth/oauth.rs:62-63`, matched to
  Flutter). That named hardening gap is unchanged, not silently
  "solved" or widened; the mismatch check validates *which character*
  the claims name, not token authenticity.
- **General scope management UI.** No per-character scope list, no
  step-up entry points beyond the Assets panel, no Fleet/Character/
  Wallet step-up wiring. The state/pure/shell shapes generalize, but
  each future caller is its own follow-up.
- **Updating `token_meta` on ordinary token refresh.**
  `valid_access_token` persists rotated tokens but not metadata today
  (`src/esi/client.rs:197-199`); that behaviour is unchanged. Step-up
  writes metadata itself at grant time, mirroring first login.
- **Pushing or merging.** This branch work ends at local commits; push
  and merge are separate, separately authorized steps.

## 10. File ownership and sequencing

Work is strictly sequential in the shared tree on `feat/stepup-oauth`:
Builder A finishes and commits, then Builder B, then the integrator.
Nobody edits the other builder's files; an insufficient shape is
reported back, not patched across the boundary.

| Owner | Files (complete list) | Contents |
|---|---|---|
| Design (this commit) | `docs/stepup-oauth-design.md` only | This document. Commit: `docs: design the step-up OAuth flow` |
| Builder A | `src/config.rs`, `src/error.rs`, `src/auth/oauth.rs`, `src/app/state.rs` | `ASSETS_SCOPES` additive constant + new exact-content test (existing guard test untouched); `AuthError::CharacterMismatch` single variant; `split_scopes`/`join_scopes`/`union_scopes`/`missing_scopes`/`validate_expected_character` + unit tests; `StepUpRequest` + `stepup_requested` + `remove_character` clearing + module-comment update + unit tests. Suggested commit: `feat(auth): add step-up scope logic and request state` |
| Builder B | `src/app/shell.rs`, `src/ui/assets.rs` | Drain block, `start_stepup_login`, `BackendMsg::StepUpLoggedIn` + arm, demo/busy/backends/known-character guards; real Re-authorize button + copy. Suggested commit: `feat(auth): wire step-up sign-in into shell and Assets view` |
| Integrator | `README.md`, `docs/engineering-journal/DECISIONS.md` | README line 18 caveat ("until step-up sign-in lands…") updated to describe the working button; engineering-journal decision entry recording the union + validate-before-save choices; final gates (Section 11), diff audit that `FIRST_AUTH_SCOPES`/`start_login` are untouched, live manual matrix. Suggested commit: `docs: record step-up sign-in availability` |

Hard overlaps to respect: Builder B adds `StepUpRequest` to existing
imports in `src/app/shell.rs:8-10` and `src/ui/assets.rs:8` — import
lines are Builder B's files, so no cross-edit. Builder A does not touch
`src/auth/mod.rs`, `src/lib.rs`, `src/storage/*`, `src/esi/*`,
`src/auth/callback_server.rs`, or `src/auth/token_store.rs`. Nobody
adds a dependency (`Cargo.toml` untouched; `open`, `tracing` already
present). No attribution lines in any commit message or file.

## 11. Test plan

Repository gates (`.github/workflows/ci.yml:33-53`), run by each builder
before committing and by the integrator at the end:
`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`. Expected result: all green.

### Builder A — new unit tests (must fail before, pass after, where noted)

In `src/auth/oauth.rs` tests, reusing the existing `fake_jwt` helper
(`:479-483`) where claims are needed:

1. `union_scopes` is order-preserving and dedups: granted-first order,
   requested overlap, duplicates inside each input, empty+empty →
   empty, empty granted → requested deduped, empty strings skipped.
2. `missing_scopes`: full subset → empty; partial → only the missing
   ones in requested order; duplicate requested entries appear once;
   empty requested → empty (the already-granted decision input).
3. `split_scopes`/`join_scopes` roundtrip: multiple spaces collapse,
   `""` → empty vec, join of split is the normalized single-spaced
   string.
4. `validate_expected_character`: match returns `Ok(id)`; different
   `sub` id → `Err(AuthError::CharacterMismatch)`; malformed `sub`
   (missing/wrong `CHARACTER:EVE:` prefix) →
   `Err(AuthError::MalformedToken)`.
5. Scoped authorize URL: `build_authorize_url_with_scopes` with a
   two-scope string, asserting by **parsed query pairs** (not substring)
   that `scope` decodes to exactly those scopes (URL-encoding of the
   space must not make the test brittle). Asserts the union string is
   what EVE receives, without printing any real URL/state.
6. Regression, unmodified and passing: all existing oauth tests
   (`pkce_challenge_matches_rfc7636_vector`,
   `authorize_url_carries_pkce_and_state`,
   `jwt_claims_parse_character_and_scopes`, `malformed_jwt_is_rejected`,
   `refresh_buffer_math`, `callback_url_validation`,
   `token_response_debug_redacts`) and the callback-server tests.

In `src/config.rs` tests: new `assets_scopes_is_the_single_stepup_scope`
asserting `ASSETS_SCOPES == ["esi-assets.read_assets.v1"]` and
`!FIRST_AUTH_SCOPES.contains(&"esi-assets.read_assets.v1")`.
`first_auth_scopes_match_least_privilege_set` is not edited.

In `src/app/state.rs` tests: default `stepup_requested` is `None`;
`StepUpRequest::new` copies id + scopes in order; `remove_character`
clears a pending request for the removed id and keeps one for a
different id. Existing state tests pass unmodified.

### Builder B — automated surface

`src/app/shell.rs` has no `#[cfg(test)]` module today and the repo has
no egui widget-test harness (`Cargo.toml` dev-dependencies are
`tempfile` only). This design does not invent one for a single button.
Automated proof for B is therefore: full `cargo test` green (including
Builder A's new tests and every pre-existing test), clippy/fmt gates,
plus the pure-function coverage of every branch decision the shell
makes (missing/union/validate). The browser/callback/exchange plumbing
reuses code already covered by the callback-server roundtrip and OAuth
tests. Interactive behaviour is proven by the integrator's manual
matrix below, and that limitation is stated, not hidden.

### Integrator — final gates and live manual matrix

1. `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
   `cargo test` — record the exact outputs (tests passed count).
2. Diff audit: `git diff develop...HEAD -- src/config.rs src/app/shell.rs`
   shows no change inside `FIRST_AUTH_SCOPES` or the `start_login`
   function body; `git diff --stat` touches only the Section 10 files.
3. Secret audit: `grep` the diff for logging of `authorize_url`,
   `access_token`, `refresh`, `code`, and `state` values — only the
   existing redacted/`as_str()`-to-`open::that` uses may appear.
4. Manual, live character without the assets scope: Assets shows the
   panel + enabled button → click → browser opens on EVE SSO → approve
   as the same character → status "Permission granted. Refreshing..." →
   assets render with resolved names; Skills and Wallet still refresh
   (union preserved); `token_meta.scopes` for that character (query the
   scopes column only, never token files) now contains
   `esi-assets.read_assets.v1` alongside the first-auth scopes.
5. Manual, mismatch: repeat but approve as a different character →
   "Sign-in failed: [AUTH] step-up sign-in returned a different
   character than expected" status, Assets panel still shown, original
   character's Skills/Wallet still refresh, `token_meta` row unchanged.
6. Manual, denial: cancel on the EVE page → auth error status, panel
   still shown, no crash, button usable again.
7. Manual, already-granted: after case 4, the panel is gone (the click
   path is unreachable in the UI); that the pre-check would skip the
   browser is proven by Builder A's `missing_scopes` empty test, not by
   a forced UI state. Record it as unit-covered.
8. Manual, demo: run with `--demo` → Assets shows sample data, no
   Re-authorize panel/button, and no browser ever opens from Assets.
   Record that the shell demo guard itself is code-reviewed (Section 6,
   step 1) since the UI cannot set the flag in demo.
9. Manual, first-login regression: Add character still completes with
   first-auth scopes only (new character's Assets view shows the panel,
   proving first-auth was not widened).

## 12. Known limits, stated honestly

- **Stale `token_meta` can suppress the browser once.** The pre-check
  trusts `token_meta.scopes`, which is written at (step-up) login from
  returned claims and not refreshed on ordinary token refresh. In the
  normal flow it cannot be stale in the "claims a grant the token lacks"
  direction, because only a successful grant writes it (assets-port D3
  made the same observation for the fetch path). If the row were edited
  externally or a grant revoked server-side, one click would take the
  already-granted refresh path, the assets fetch would 403 again, and
  the panel would return — visible, not silent; recovery then needs
  the metadata to be corrected by a fresh grant. The typed 403 remains
  the authority for what the view shows.
- **Claims are not signature-verified** (Section 9). The mismatch check
  ensures the tokens name the expected character; it does not upgrade
  token-authenticity guarantees beyond the existing HTTPS token-endpoint
  exchange the whole app already relies on.
- **One sign-in at a time.** First login and step-up share the single
  `127.0.0.1:54321` callback listener; the busy guard serializes them
  by ignoring (with a status message) a step-up requested mid-login.
- **Step-up only from Assets.** Characters whose refresh token is dead
  (`AuthError::RefreshRejected` → `EsiError::Reauthorize`) also land on
  this panel via `needs_reauthorize`; step-up fixes them too, because a
  full re-authorize replaces both tokens. A general "re-authorize this
  character" affordance outside Assets remains future work.
