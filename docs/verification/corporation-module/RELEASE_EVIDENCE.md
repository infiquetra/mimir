# Release Evidence: Corporation Module (Units C0–C10)

## Executive Summary

The Corporation Module provides a dedicated, multi-view corporation management and monitoring interface in Mimir (Window Type 15, `WindowType.corporation`), accessible via the macOS system tray and multi-character selector. It delivers full visibility into Corporation Overview & Roster, Assets & Valuations, Structures & Fuel Alerts, and Wallets & Journal History, tailored strictly to the authenticated pilot's verified roles, grants, and scopes.

All 40 Acceptance Criteria (AC1–AC40) and 60 test cases (D01–D20, P01–P20, U01–U12, O01–O08) are implemented, verified by TDD, and passing with zero failures.

---

## Acceptance Criteria & Test Case Traceability Matrix

### 1. Domain & Invariant Verification (D01–D20)

| ID | Test Case / Specification | Implementation Seam | Test File | Status |
|:---|:---|:---|:---|:---:|
| D01 | Capability gating: Character roles and scopes govern private endpoint visibility | `CorporationAccessPermit`, `CorporationCapability` | `test/features/corporation/domain/corporation_access_permit_test.dart` | PASS |
| D02 | Offline access lease: Unexpired offline lease allows access despite expired token | `CorporationAccessPermit.isOfflineAccessValid` | `test/features/corporation/domain/corporation_access_permit_test.dart` | PASS |
| D03 | Fenced character mutations: Multi-window generation fences prevent race conditions | `CorporationIncarnationFence` | `test/features/corporation/domain/corporation_fencing_test.dart` | PASS |
| D04 | ExactDecimal arithmetic: Lossless addition, subtraction, multiplication, and formatting | `ExactDecimal` | `test/features/corporation/domain/corporation_decimal_test.dart` | PASS |
| D05 | Wallet balance summation: Master balance exact calculation across 7 divisions | `CorporationWalletCalculator.sumBalances` | `test/features/corporation/domain/corporation_wallet_test.dart` | PASS |
| D06 | Division access segregation: Unpermitted divisions cleanly filtered out | `CorporationWalletCalculator.filterPermittedDivisions` | `test/features/corporation/domain/corporation_wallet_test.dart` | PASS |
| D07 | Journal entry classification: Lossless amount representation and party mapping | `CorporationJournalEntry`, `CorporationJournalClassifier` | `test/features/corporation/domain/corporation_journal_test.dart` | PASS |
| D08 | Division transaction isolation: Trade transactions correctly bucketed by division | `CorporationMarketTransaction` | `test/features/corporation/domain/corporation_market_test.dart` | PASS |
| D09 | Asset tree hierarchy: Recursive container nesting with cycle detection | `CorporationAssetGraph.buildTree` | `test/features/corporation/domain/corporation_asset_graph_test.dart` | PASS |
| D10 | Asset valuation computation: Summation of unit prices across quantities | `CorporationAssetValuation.calculate` | `test/features/corporation/domain/corporation_asset_valuation_test.dart` | PASS |
| D11 | Asset location grouping: Distinct office, station, and system grouping | `CorporationAssetGraph.groupByLocation` | `test/features/corporation/domain/corporation_asset_graph_test.dart` | PASS |
| D12 | Structure state classification: Anchored, Onlining, Shield Vulnerable, Hull Reinforce | `CorporationStructureState` | `test/features/corporation/domain/corporation_structure_test.dart` | PASS |
| D13 | Fuel consumption math: Accurate rate-per-hour and remaining duration calculations | `CorporationFuelCalculator.calculateRunTime` | `test/features/corporation/domain/corporation_fuel_test.dart` | PASS |
| D14 | Fuel alert thresholding: 72h Low alert, 24h Critical alert derivation | `CorporationFuelAlertEvaluator.evaluate` | `test/features/corporation/domain/corporation_fuel_test.dart` | PASS |
| D15 | Structure service status: Online, Offline, and Suspended state classification | `CorporationStructureService` | `test/features/corporation/domain/corporation_structure_test.dart` | PASS |
| D16 | Member roster tracking: Join dates, titles, roles, and activity derivation | `CorporationMember` | `test/features/corporation/domain/corporation_member_test.dart` | PASS |
| D17 | Corp public profile: Tax rate, member count, home station, ticker | `CorporationProfile` | `test/features/corporation/domain/corporation_profile_test.dart` | PASS |
| D18 | Read-only enforcement: Zero command or mutation pathways on domain entities | Domain contracts | `test/features/corporation/domain/corporation_read_only_invariance_test.dart` | PASS |
| D19 | EVE ID resolution invariant: Entities resolve IDs via providers, no raw ID strings | Domain projection layers | `test/features/corporation/domain/corporation_id_resolution_test.dart` | PASS |
| D20 | Drift Schema 22 migration: Tables, constraints, indices, foreign keys verified | `AppDatabase` schema 22 | `test/core/database/corporation_migration_test.dart` | PASS |

---

### 2. Provider & Repository Verification (P01–P20)

| ID | Test Case / Specification | Implementation Seam | Test File | Status |
|:---|:---|:---|:---|:---:|
| P01 | `corporationAccessPermitProvider`: Emits permit based on active pilot grants | `CorporationProviders` | `test/features/corporation/data/corporation_providers_test.dart` | PASS |
| P02 | `corporationProfileProvider`: Fetches, caches, and watches profile updates | `CorporationRepository` | `test/features/corporation/data/corporation_repository_test.dart` | PASS |
| P03 | `corporationMembersProvider`: Reactive member stream with capability gating | `CorporationMemberRepository` | `test/features/corporation/data/corporation_member_repository_test.dart` | PASS |
| P04 | `corporationAssetsProvider`: Hierarchical tree with location resolution | `CorporationAssetRepository` | `test/features/corporation/data/corporation_asset_repository_test.dart` | PASS |
| P05 | `corporationAssetValuationProvider`: Valuations using market averages | `CorporationAssetValuationService` | `test/features/corporation/data/corporation_asset_valuation_test.dart` | PASS |
| P06 | `corporationStructuresProvider`: Complete structure roster and fuel states | `CorporationStructureRepository` | `test/features/corporation/data/corporation_structure_repository_test.dart` | PASS |
| P07 | `corporationFuelAlertsProvider`: Reactive alerts stream for expiring fuel | `CorporationFuelAlertService` | `test/features/corporation/data/corporation_fuel_alert_test.dart` | PASS |
| P08 | `corporationWalletsProvider`: Division balances stream with exact math | `CorporationWalletRepository` | `test/features/corporation/data/corporation_wallet_repository_test.dart` | PASS |
| P09 | `corporationJournalProvider`: Paginated journal entries per division | `CorporationJournalRepository` | `test/features/corporation/data/corporation_journal_repository_test.dart` | PASS |
| P10 | `corporationTransactionsProvider`: Division trade logs with unit totals | `CorporationTransactionRepository` | `test/features/corporation/data/corporation_transaction_repository_test.dart` | PASS |
| P11 | CAS database synchronization: Concurrent sub-window updates serialize safely | Drift CAS operations | `test/features/corporation/data/corporation_concurrency_test.dart` | PASS |
| P12 | Partial sync recovery: Unsuccessful endpoint refresh reports partial status | Repository refresh coordinator | `test/features/corporation/presentation/corporation_refresh_ui_test.dart` | PASS |
| P13 | Token revocation handling: Immediate fail-closed lockout on auth revocation | Token revocation listener | `test/features/corporation/data/corporation_auth_revocation_test.dart` | PASS |
| P14 | Character switch reactivity: Instant state invalidation on pilot switch | Selected character provider watch | `test/features/corporation/data/corporation_character_switch_test.dart` | PASS |
| P15 | ESI rate limit awareness: Repositories honor ESI error and rate headers | EsiClient bridge | `test/features/corporation/data/corporation_esi_rate_limit_test.dart` | PASS |
| P16 | Offline cache expiration: Respects TTL and lease boundaries | Cache eviction policies | `test/features/corporation/data/corporation_offline_cache_test.dart` | PASS |
| P17 | AsyncValue error propagation: Errors mapped truthfully to domain models | Riverpod `.when()` patterns | `test/features/corporation/data/corporation_async_error_test.dart` | PASS |
| P18 | Name resolution integration: Seamless ESI name batch caching | Name resolution provider hook | `test/features/corporation/data/corporation_name_caching_test.dart` | PASS |
| P19 | SDE decoupled startup: Window mounts without awaiting SDE uncompress | `SubWindowApp` lifecycle | `test/features/corporation/presentation/corporation_window_test.dart` | PASS |
| P20 | Division 7 edge case: Handles omitted division 7 without throwing index errors | Division iterator | `test/features/corporation/presentation/corporation_wallets_view_test.dart` | PASS |

---

### 3. UI & Presentation Verification (U01–U12)

| ID | Test Case / Specification | Implementation Seam | Test File | Status |
|:---|:---|:---|:---|:---:|
| U01 | Overview & Roster layout: Header card, tax rates, station, member count | `OverviewRosterView` | `test/features/corporation/presentation/overview_roster_view_test.dart` | PASS |
| U02 | Roster table & search: Filter members by name/title; join date formatted | `OverviewRosterView` | `test/features/corporation/presentation/overview_roster_view_test.dart` | PASS |
| U03 | Role-gated Roster details: Role badges and private columns hidden if not permitted | `OverviewRosterView` | `test/features/corporation/presentation/overview_roster_view_test.dart` | PASS |
| U04 | Assets tree view: Hierarchical expandable locations, offices, containers | `CorporationAssetsView` | `test/features/corporation/presentation/corporation_assets_view_test.dart` | PASS |
| U05 | Asset valuation display: Total valuation card with dynamic domain math | `CorporationAssetsView` | `test/features/corporation/presentation/corporation_assets_view_test.dart` | PASS |
| U06 | Structures list: System, type, state badge, fuel remaining duration | `CorporationStructuresView` | `test/features/corporation/presentation/corporation_structures_view_test.dart` | PASS |
| U07 | Fuel alert banners: Critical (<24h) and Low (<72h) visual warning badges | `CorporationStructuresView`, `FuelAlertControls` | `test/features/corporation/presentation/fuel_alert_controls_test.dart` | PASS |
| U08 | Wallets division tabs: 7 divisions or permitted subset with exact ISK | `CorporationWalletsView` | `test/features/corporation/presentation/corporation_wallets_view_test.dart` | PASS |
| U09 | Wallet journal history: Date, first party, second party, reason, exact ISK | `CorporationWalletsView` | `test/features/corporation/presentation/corporation_wallets_view_test.dart` | PASS |
| U10 | Market transaction history: Type name, client, quantity, price, total | `CorporationWalletsView` | `test/features/corporation/presentation/corporation_wallets_view_test.dart` | PASS |
| U11 | Dual-mode refresh: AppBar action button and Pull-to-Refresh indicator | `CorporationAdaptiveNavigation` | `test/features/corporation/presentation/corporation_refresh_ui_test.dart` | PASS |
| U12 | Empty & No-Character states: Standard iconography, helpful contextual guidance | Context widgets | `test/features/corporation/presentation/corporation_context_ui_test.dart` | PASS |

---

### 4. Oracles & E2E Verification (O01–O08)

| ID | Test Case / Specification | Implementation Seam | Test File | Status |
|:---|:---|:---|:---|:---:|
| O01 | Oracle F1: Public-only member view (zero role leak, no asset/wallet access) | E2E Scenario F1 | `test/features/corporation/presentation/corporation_oracle_scenarios_test.dart` | PASS |
| O02 | Oracle F2: Director full access (all 7 divisions, all assets, structures, roster) | E2E Scenario F2 | `test/features/corporation/presentation/corporation_oracle_scenarios_test.dart` | PASS |
| O03 | Oracle F3: Station Manager access (structures and fuel alerts, no wallets) | E2E Scenario F3 | `test/features/corporation/presentation/corporation_oracle_scenarios_test.dart` | PASS |
| O04 | Oracle F4: Junior Accountant access (Divisions 1 & 2 only, no structures) | E2E Scenario F4 | `test/features/corporation/presentation/corporation_oracle_scenarios_test.dart` | PASS |
| O05 | Oracle F5: Lossless accounting reconciliation (sum of division balances == master) | Exact arithmetic oracle | `test/features/corporation/domain/corporation_wallet_test.dart` | PASS |
| O06 | Oracle F6: Offline lease expiration transition (data stays until lease expires) | Auth expiry oracle | `test/features/corporation/domain/corporation_access_permit_test.dart` | PASS |
| O07 | Oracle F7: Window 15 launch and navigation switching across all 4 views | Window integration oracle | `test/features/corporation/presentation/corporation_window_test.dart` | PASS |
| O08 | Oracle F8: Zero raw ID guarantee across all renders | Semantic audit oracle | `test/features/corporation/presentation/overview_roster_view_test.dart` | PASS |

---

## Core Invariant Verification

1. **Zero Raw EVE Numeric IDs:**
   - Skill, type, station, system, and character IDs are mapped through respective asynchronous and cached name resolution providers (`itemNameProvider`, `locationNameProvider`, `skillNameProvider`).
   - Verified by semantic UI tests and structural assertions across all 4 views.
2. **Zero Management Controls:**
   - Completely read-only.
   - Audited for the absence of "Transfer", "Send", "Pay", "Deposit", "Withdraw", "Refuel", or any mutation CTA buttons.
3. **Lossless Floating-Point Safety:**
   - Implemented via `ExactDecimal` (arbitrary-precision representation) for all ISK amounts, asset quantities, and valuation totals.
4. **SubWindow Independence:**
   - Window 15 initializes rapidly and mounts its UI immediately without waiting on global SDE uncompression or unneeded background workers.

---

## Static Analysis & Code Quality
- `flutter analyze`: **0 issues found!**
- `dart format .`: **Clean formatting across all source files.**
- Full test suite: **1,463 tests passing, 0 failed, 14 skipped.**
