# Mimir Repo Code Review Report

Scope: whole-repo quality, maintainability, and reliability review for `/Users/jefcox/workspace/infiquetra/mimir`.

Notes:
- No code changes were made; this is a review artifact only.
- No tests were run.

## Executive summary

This review found several correctness and production-readiness risks worth fixing. Some are hard defects that can impact startup/auth reliability, and some are feature-completeness debt that leaks into runtime behavior. The highest priority items are around startup argument safety, auth path robustness, and placeholder/mock data flows.

## Severity-ranked findings

1. [P1] Sub-window startup can throw on malformed CLI args
- Location: `lib/main.dart:33-39`
- Why it matters: The `multi_window` branch assumes `args[1]` and `args[2]` exist. If the launch args are malformed, app startup can crash with `RangeError` before initialization.
- Reasoning:
  - `if (args.firstOrNull == 'multi_window') { final windowId = args[1]; final windowArgs = args[2]; ... }`
- Recommended action:
  - Validate argument length before indexing. If malformed, log clear error and fallback to safe main-window startup.

2. [P1] Mapper Intel feature is mock/defaulted and not production-safe
- Location: `lib/features/intel/presentation/widgets/mapper_sync_card.dart:21`
- Location: `lib/features/intel/data/mapper_client.dart:16-27`
- Why it matters: `MapperSyncCard` always connects to `https://pathfinder.example.com` with `test-api-key` and the client emits fake timer-based updates.
- Reasoning:
  - `connect('https://pathfinder.example.com', 'test-api-key');`
  - `Timer.periodic` + hardcoded map payload instead of API integration.
- Recommended action:
  - Gate mock behavior behind explicit dev/test switch.
  - Move endpoint/key to injectable config.
  - Fail closed or hide UI when config unavailable.

3. [P2] `MapperSyncCard` starts a timer without lifecycle cleanup in dispose
- Location: `lib/features/intel/presentation/widgets/mapper_sync_card.dart:16-22`
- Location: `lib/features/intel/data/mapper_client.dart:12-43`
- Why it matters: Timer-based stream source is started in `initState` but widget lifecycle cleanup is not enforced from the view side, so repeated window mounts can accumulate background activity.
- Reasoning:
  - Start logic in `initState` only.
  - No visible `dispose()` to disconnect/cancel.
- Recommended action:
  - Ensure stream cleanup via widget `dispose` or provider auto-dispose semantics.

4. [P2] Deep-link OAuth callback errors can be lost
- Location: `lib/core/auth/deep_link_handler.dart:44-48`
- Why it matters: `_handleDeepLink` invokes async handler without awaiting and without error boundary, so failures in callback processing may be unobserved.
- Reasoning:
  - `_handleDeepLink` is synchronous and calls `_handleOAuthCallback(uri);` directly.
- Recommended action:
  - Make callback handling awaited/logged or use explicit async error capture.

5. [P2] OAuth launch flow is macOS-specific
- Location: `lib/core/auth/auth_providers.dart:153-156`
- Why it matters: flow hardcodes `open` command; this is macOS-specific and breaks on other desktop platforms.
- Reasoning:
  - `Process.run('open', [request.authorizationUrl.toString()]);`
- Recommended action:
  - Use cross-platform command dispatch or `url_launcher` fallback.
  - Return clear platform-specific error message when unsupported.

6. [P2] User-facing fallback displays raw IDs in failure path
- Location: `lib/features/intel/presentation/widgets/killmail_card.dart:65,85`
- Why it matters: If name resolution fails, UI prints raw IDs, exposing technical identifiers rather than user-friendly unknown names.
- Reasoning:
  - Error fallback text is `System ${killmail.solarSystemId}` and `Ship ${killmail.victim.shipTypeId}`.
- Recommended action:
  - Return canonical “Unknown” text and/or cached fallback label.

7. [P2] SDE update/version and solar-system metadata paths are incomplete
- Location: `lib/core/sde/sde_service.dart:629-631`
- Location: `lib/core/sde/sde_service.dart:920-932`
- Why it matters: update/version checking is placeholder and solar-system lookups can degrade UX with placeholder fallback values.
- Reasoning:
  - `checkForUpdates()` only logs and returns.
  - `getSolarSystemName` always returns `System #<id>` in missing-cache cases.
- Recommended action:
  - Implement versioned incremental update path and cache-backed solar-system lookup or centralize ESI fallback strategy.

8. [P2] Fitting engine still has known calculation gaps
- Location: `lib/features/fitting/domain/dogma_engine.dart:36`
- Location: `lib/features/fitting/domain/dogma_engine.dart:148`
- Location: `lib/features/fitting/domain/format_parser.dart:222`
- Why it matters: known TODOs around ship-base skill effects, full stat calculations, and slot mapping can produce inaccurate fitting output.
- Recommended action:
  - Complete TODO backlog before feature promotion.

9. [P3] Mixed logging and ignored errors reduce diagnosability
- Location: multiple files (examples below)
  - `lib/app.dart:79-110`
  - `lib/core/auth/deep_link_handler.dart:35-36`
  - `lib/core/auth/pending_auth_store.dart:85-96`
- Why it matters: many `debugPrint` and `catch (_)` calls reduce observability and may hide root cause in auth/storage edge paths.
- Recommended action:
  - Normalize on repo logger (`core/logging/logger.dart`) with context tags.
  - Replace broad/empty catch in high-surface flows with explicit handling + minimal escalation.

## What I recommend you focus on first

1. Fix startup/arg safety (`lib/main.dart`).
2. Resolve auth callback reliability (`deep_link_handler`, `auth_providers`, `oauth_callback_server`).
3. Remove production mock/placeholder dependencies in Intel mapper path.
4. Decide whether SDE placeholders are acceptable launch behavior or must be implemented before release.

## Quick evidence index

- `lib/main.dart`
- `lib/features/intel/presentation/widgets/mapper_sync_card.dart`
- `lib/features/intel/data/mapper_client.dart`
- `lib/core/auth/deep_link_handler.dart`
- `lib/core/auth/auth_providers.dart`
- `lib/features/intel/presentation/widgets/killmail_card.dart`
- `lib/core/sde/sde_service.dart`
- `lib/features/fitting/domain/dogma_engine.dart`
- `lib/features/fitting/domain/format_parser.dart`
- `lib/core/auth/pending_auth_store.dart`

## Residual risks not yet fixed in this review pass

- Some logging/developer-experience inconsistencies are widespread and may be best handled as a separate cleanup PR.
- A few TODOs remain in non-critical UX/feature paths.
