# Combat Analyzer Recovery Plan

Date: 2026-05-20

## Goal

Get Mimir back to a working, testable state, then finish the combat analyzer as a native Flutter/Riverpod feature that scans EVE combat logs, caches parsed/analyzed encounters in Drift, and supports a defensible LLM authentication path.

## Current Findings

- Worktree is heavily modified: 267 tracked files changed plus new combat analyzer files and scratch scripts.
- `flutter analyze` currently fails on `integration_test/screens/intel/kill_feed_test.dart`, not on combat analyzer source.
- Targeted analyzer check is clean for `lib/features/combat_analyzer` and the new auth/path files.
- `flutter test test/features/combat_analyzer` now passes after replacing placeholder `log_scanner_test.dart` cases.
- `flutter test test/core/database/app_database_test.dart` passes.
- `flutter test integration_test/screens/combat_analyzer` is blocked by iOS CocoaPods sqlite version mismatch, not by combat analyzer assertions.
- Combat analyzer is wired into `WindowType`, `SubWindowApp`, and tray menu, but several UI widgets are placeholders or duplicates.
- The current device OAuth implementation uses the wrong OpenAI/Codex endpoint shape and saves an access token as `llmApiKey`; this is why a 400 is expected and it should not be treated as a normal OpenAI API key path.
- Hermes implements Codex auth as an app-owned auth store (`~/.hermes/auth.json`), not by mutating the Codex CLI store. It stores `providers.openai-codex.tokens`, refreshes tokens before expiry, and uses the ChatGPT Codex backend with Codex-specific headers.

## Recovery Phases

### Phase 1: Stabilize The Repo

1. Preserve user changes and avoid broad rewrites.
2. Remove or quarantine scratch files that are not meant to be analyzed as app code (`parse_test*.dart`, `test_opt.dart`, `test_regex.dart`, etc.) after confirming they are disposable.
3. Fix `integration_test/screens/intel/kill_feed_test.dart` so full `flutter analyze` no longer has hard errors.
4. Resolve the iOS/macOS CocoaPods sqlite lock mismatch after approval for dependency lockfile changes.

### Phase 2: App-Owned Codex Auth

Decision: mirror Hermes' working pattern with a Mimir-owned `auth.json`.

1. [done] Add a `CodexAuthStore` service that owns Mimir's auth file under the app support directory, for example `~/Library/Application Support/mimir/auth.json` on macOS.
2. [done] Use a Hermes-compatible JSON shape:
   - `version: 1`
   - `active_provider: "openai-codex"`
   - `providers.openai-codex.tokens.access_token`
   - `providers.openai-codex.tokens.refresh_token`
   - `providers.openai-codex.last_refresh`
   - `providers.openai-codex.auth_mode: "chatgpt"`
3. [done] Write the auth file atomically, restrict directory/file permissions to owner-only on macOS, and never log token values.
4. [done] Replace the current generic `DeviceAuthService` with a Codex-specific flow matching Hermes:
   - `POST https://auth.openai.com/api/accounts/deviceauth/usercode` with JSON `{ "client_id": "app_EMoamEEZ73f0CkXaXp7hrann" }`
   - show/open `https://auth.openai.com/codex/device` and display the returned `user_code`
   - poll `POST https://auth.openai.com/api/accounts/deviceauth/token` with JSON `{ "device_auth_id", "user_code" }`
   - exchange the returned `authorization_code` and `code_verifier` at `https://auth.openai.com/oauth/token` using form-encoded `grant_type=authorization_code`, `redirect_uri=https://auth.openai.com/deviceauth/callback`, `client_id`, and `code_verifier`
   - store the returned access and refresh tokens only in Mimir's auth store
5. [done] Implement refresh with `grant_type=refresh_token`, preserve rotated refresh tokens, and refresh about 120 seconds before JWT expiry.
6. [done] Optional migration only: offer to import valid non-expired Codex CLI tokens from `~/.codex/auth.json`, but keep fresh Mimir login as the recommended path to avoid refresh-token rotation conflicts.
7. [done] Keep direct OpenAI API key support optional and separate. Do not save Codex access tokens in `llmApiKey`.

### Phase 3: Complete Combat Analyzer Data Model

1. Replace `ParsedCombatEncounter` with fields needed by UI/cache: stable ID, source file path, start/end time, listener/character name, opponent names, raw excerpt, optimized prompt payload, damage events, totals, and parse warnings.
2. Update `CombatEncounters` table to store character identity, source log metadata, encounter hash, analysis status, provider/model, parsed metrics JSON, and LLM response JSON.
3. Add database helper methods for get-by-hash, insert parsed encounter, save analysis result, and watch encounters by active character.

### Phase 4: Make Log Scanning Real

1. Make `LogScanner` injectable/testable without relying on global `SharedPreferences`.
2. Support the standard EVE `Documents/EVE/logs/Gamelogs` path, manual directory selection, empty/missing dirs, recursive scan if required, and safe handling of unreadable files.
3. Filter by actual EVE log shape, not only filename regex.
4. Parse `Listener:` and associate encounters with existing Mimir characters.
5. Replace placeholder scanner tests with temp-directory unit tests.

### Phase 5: Finish Parsing And Token Optimization

1. Parse EVE HTML color tags robustly.
2. Segment encounters by idle gap and/or combat boundary events.
3. Track cumulative damage dealt/received over time for the metrics pane.
4. Summarize repeated events locally, especially repeated drone misses and repeated weapon messages.
5. Validate against the Merlin fixture.

### Phase 6: Build The Codex Analysis Client

1. [done] Add a `CodexAnalysisClient` that reads Mimir's auth store, refreshes if needed, and calls `https://chatgpt.com/backend-api/codex` with the Responses API request shape.
2. [done] Add Codex backend headers matching Hermes/codex-rs behavior: `Authorization: Bearer <token>`, `User-Agent: codex_cli_rs/0.0.0 (Mimir)`, `originator: codex_cli_rs`, and `ChatGPT-Account-ID` derived from the access token claim when available.
3. [done] Do not send `temperature` or `max_output_tokens` to the Codex backend; Hermes explicitly omits these to avoid 400s.
4. [done] Use a strict JSON response contract for the combat analysis result and parse defensively.
5. [done] Cache before calling Codex, and never resend an already analyzed encounter.
6. [done] Log request lifecycle and errors without logging secrets, auth file contents, raw tokens, or full combat logs.
7. [partial] Added unit tests with fake HTTP/auth store dependencies for device flow, refresh rotation, Responses payload, scanner behavior, and parser coverage. Cache-hit coverage remains tied to the broader Drift analyzer tests.

### Phase 7: Finish UI

1. Remove duplicate placeholder screens/widgets.
2. Build the encounter list with active-character filtering, empty/error states, refresh, manual directory selection, and settings.
3. Build the analysis view with Summary, What Went Wrong, How To Improve, Fit Improvements, and Metrics panes.
4. Use parsed damage chart data instead of generated mock chart data.
5. Keep the UI responsive and avoid nested card-heavy layouts.

### Phase 8: Verification

1. `flutter analyze`
2. `flutter test test/features/combat_analyzer`
3. `flutter test test/core/database/app_database_test.dart`
4. `flutter test test/features/dashboard/data/combat_providers_test.dart`
5. `flutter test integration_test/screens/combat_analyzer/` after CocoaPods lock mismatch is fixed
6. Manual macOS run: open Combat Analyzer from tray, scan logs, save API config, analyze Merlin fixture, confirm cached reload.

## Checkpoint 2026-05-20 Codex Auth Implementation

- Added app support path propagation from the main window to sub-windows.
- Added `CodexAuthStore`, `CodexAuthService`, and `CodexAnalysisClient`.
- Replaced the generic device auth dialog with Codex sign-in, sign-out, optional Codex CLI import, model setting, browser open, polling, and token storage in Mimir's `auth.json`.
- Updated combat analysis to use the Codex Responses backend and Mimir-owned OAuth credentials.
- Replaced placeholder scanner tests.
- Checks run:
  - `flutter analyze lib/core/platform/app_paths.dart lib/main.dart lib/core/window/window_service.dart lib/features/combat_analyzer test/features/combat_analyzer`
  - `flutter test test/features/combat_analyzer`
  - `flutter test test/core/window/window_service_test.dart`
  - `flutter test test/core/database/app_database_test.dart`

## Decided

"Codex OAuth" means a Mimir-owned Codex auth store and Codex-specific device authorization flow, following Hermes. Mimir should not write to `~/.codex/auth.json`, should not store Codex tokens in Drift settings, and should not call Codex through the normal `/v1/chat/completions` path.

## Checkpoint 2026-05-20 Post-Sign-In Crash Follow-Up

- Manual attached run showed the Codex device flow succeeded, wrote Mimir's `auth.json`, and loaded authenticated state on reopening settings.
- The only concrete post-success fault in the run logs was macOS sandbox denial when spawning `/bin/chmod`, which left `auth.json` at `0644`.
- Replaced subprocess `chmod` with in-process POSIX `chmod` through Dart FFI, repair permissions on auth-store reads, and added unit assertions for saved and pre-existing auth files being `0600` on Unix-like platforms.
- Combat log scanner currently looks in `~/Documents/EVE/logs/Gamelogs/` by default or a saved `combat_log_directory` preference. A local check found 1,419 gamelog `.txt` files there.
- Fixed scanner matching to include EVE's character-suffixed files (`YYYYMMDD_HHMMSS_characterId.txt`), not only legacy `YYYYMMDD_HHMMSS.txt` files, and added parser coverage for real HTML-colored EVE damage lines.
- Added a Combat Analyzer toolbar folder picker and macOS user-selected read entitlement so the sandboxed app can be pointed at the real `~/Documents/EVE/logs/Gamelogs` directory.
- Fixed `logScannerProvider` and `rawEncountersProvider` to await `SharedPreferences` instead of returning an empty encounter list or "scanner not ready" while preferences initialize.
- Removed `shared_preferences` from the combat scanner because sub-window Flutter engines cannot use that plugin channel reliably. The selected combat log directory is now stored in Mimir's app-support `combat_analyzer.json`.
- Capped the initial local log scan to the newest 100 gamelog files to avoid parsing the entire historical EVE log directory on startup.
- Opening a parsed encounter no longer automatically sends it to Codex. Cached analysis is displayed if present; otherwise the user must click "Analyze With Codex", and cached results can be explicitly re-analyzed.
- Fixed macOS sub-window native plugin registration: `desktop_multi_window` sub-windows now call `RegisterGeneratedPlugins`, so `file_selector_macos` can open the folder picker from Combat Analyzer.
- Reproduced the Codex analysis HTTP 400 with a minimal request and confirmed the backend requires streamed Responses calls (`stream: true`, `Accept: text/event-stream`). Updated `CodexAnalysisClient` to request SSE, read the streamed response body, and extract final `response.output_text` content before parsing the strict analysis JSON.
- Tightened combat log filtering so timestamped EVE gamelogs are only shown when their contents include actual combat damage lines. Parser output now ignores non-combat timestamped events and combat-tagged lines with no damage, which prevents skill-point redemption logs from being analyzed.
- Added a persisted combat-log classification cache in `combat_analyzer.json` keyed by file path, modified time, and size. Unchanged non-combat files are skipped on refresh without reopening them; changed files are rechecked.
- Verified the saved app config points at `/Users/jefcox/Documents/EVE/logs/Gamelogs`, with 1,419 gamelog files classified into 56 combat logs and 1,363 non-combat logs. A provider mirror parsed those 56 combat logs into 295 displayable encounters.
- Updated the folder picker completion path to invalidate scanner state, force a completed encounter refresh, and show the loaded encounter count in the snackbar so the UI does not leave a stale empty state after selecting a folder.
- Checks run after the fix:
  - `flutter analyze lib/core/platform/app_paths.dart lib/main.dart lib/core/window/window_service.dart lib/features/combat_analyzer test/features/combat_analyzer`
  - `flutter test test/features/combat_analyzer`
  - `flutter analyze lib/features/combat_analyzer test/features/combat_analyzer`
  - `flutter test test/features/combat_analyzer`
  - `flutter test .codex/tmp/inspect_combat_logs_test.dart --plain-name 'mirror rawEncountersProvider with saved config'` (temporary local diagnostic; removed)
  - `flutter build macos --debug`
