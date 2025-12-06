# Peer Review Report: Mimir
**Date:** 2025-12-06
**Reviewer:** AI System (Senior Flutter/Dart Architect)
**Target:** Entire Codebase (Architecture, Features, Quality, UX)

## 1. Executive Summary
The *Mimir* application demonstrates a sophisticated "Tray-First" multi-window architecture, leveraging modern Flutter ecosystem tools (Riverpod, Drift, Dio). It successfully implements the "Database as Source of Truth" pattern to manage state across separate window isolates.

However, significant risks exist regarding **ESI Rate Limiting synchronization** across windows and **Performance inefficiencies** in data fetching logic. Furthermore, the **Testing Strategy** has a critical gap: complex business logic in `wallet` and `skills` is currently untested.

## 2. Architecture & Configuration
### 2.1 Multi-Window Strategy
*   **Observation:** The app uses `desktop_multi_window` to spawn separate isolates for feature windows.
*   **Strength:** `lib/main.dart` correctly handles argument passing (`dbPath`) to ensure all windows connect to the same SQLite database. This effectively solves data persistence synchronization.
*   **Risk (Critical):** Separate isolates mean separate memory heaps. Singletons like `EsiClient` (and its rate-limit counters) are **not shared**.
    *   *Impact:* Window A and Window B maintain separate ESI error counts. If both windows spam requests, the application may inadvertently exceed the global ESI rate limit, leading to temporary bans.
    *   *Recommendation:* Move rate-limit tracking to the SQLite database or use an IPC (Inter-Process Communication) mechanism to synchronize the `_errorLimitRemain` state.

### 2.2 Configuration
*   **Linting:** The project uses `package:flutter_lints` with no overrides.
    *   *Recommendation:* Upgrade to `very_good_analysis` or manually enable stricter rules (e.g., `unawaited_futures`, `prefer_final_locals`) to catch subtle bugs early.
*   **Logging:** `lib/main.dart` uses `debugPrint` directly.
    *   *Recommendation:* Standardize on the `Logger` class used elsewhere to ensure consistent formatting and log levels.

## 3. Feature Analysis: Wallet & Skills
### 3.1 Data Access Layer (Repositories)
*   **Wallet Summary Performance:** `WalletRepository.get30DaySummary` fetches up to **10,000** journal entries and filters them in Dart memory.
    *   *Impact:* High memory usage and slow performance on mobile/low-end devices.
    *   *Recommendation:* Push the date filtering to the SQL layer using Drift's `where` clause.
    *   *Snippet:* `..where((tbl) => tbl.date.isBiggerThanValue(thirtyDaysAgo))`
*   **N+1 Query Issue:** `SkillRepository.getAllCharacterQueues` iterates through characters and awaits a DB query for each inside a loop.
    *   *Recommendation:* Refactor to a single `join` query or a batch fetch.

### 3.2 ESI Integration
*   **Implementation:** `EsiClient` is robust, handling token refreshing and error wrapping well.
*   **Code Structure:** `esi_client.dart` is over 500 lines and contains numerous DTO classes (`CharacterPublicInfo`, `SkillQueueItem`, etc.).
    *   *Recommendation:* Extract DTOs into a dedicated `lib/core/network/models/` directory to adhere to the Single Responsibility Principle.

## 4. Quality Assurance
### 4.1 Testing
*   **Critical Gap:** The `test/features/` directory contains tests for `characters` and `dashboard`, but **no tests** for `wallet` or `skills`.
*   *Action Required:* Immediate priority to add unit tests for `WalletRepository` and `SkillRepository`, specifically covering:
    *   Token refresh failure scenarios.
    *   Data parsing edge cases.
    *   Cache invalidation logic.

### 4.2 Error Handling
*   **Repository Pattern:** Repositories generally `try/catch`, log, and `rethrow`. This is acceptable, but ensure the UI layer catches these rethrown exceptions to show user-friendly error messages instead of crashing.

## 5. UX/UI & Theming
### 5.1 Visual Design
*   **Theme:** `EveColors` provides a semantic and cohesive palette (High/Low/Null sec colors, ISK profit/loss).
*   **Widgets:** `WalletScreen` uses a custom `SpaceBackground` and clear tabbed navigation.

### 5.2 Interaction Issues
*   **Loading State:** `WalletScreen` checks `ref.watch(activeCharacterProvider).value`. If the provider is in a `loading` state (AsyncLoading), `.value` is null, causing the UI to render the "No Character Selected" empty state.
    *   *Fix:* Switch on the `AsyncValue` itself (`.when(data: ..., loading: ..., error: ...)`) to show a `CircularProgressIndicator` during the initial load.

## 6. Action Plan
1.  **High Priority:** Add Unit Tests for Wallet and Skills features.
2.  **High Priority:** Fix "No Character" loading state bug in `WalletScreen`.
3.  **Medium Priority:** Optimize `get30DaySummary` SQL query.
4.  **Medium Priority:** Extract DTOs from `esi_client.dart`.
5.  **Long Term:** Implement multi-window rate-limit synchronization.

---
*End of Report*
