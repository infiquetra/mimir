# Testing Strategy: Milestone 3.1 - F5 (Encounter List UI & Multi-pane Analysis View)

## 1. Observation
- `TEST_INFRA.md` specifies an opaque-box, requirement-driven testing approach using Flutter integration tests. Feature F5 covers the "Encounter list UI and multi-pane analysis view".
- `GEMINI.md` dictates specific patterns for UI components:
  - Integration tests use Patrol.
  - Proper handling of AsyncValue states (`.when(data, loading, error)`).
  - Empty data state patterns (specific Icon, Heading, Description).
  - Responsive layouts (side-by-side on desktop, master-detail/stacked on mobile).
- The current codebase has minimal existing code for the combat analyzer feature (`combat_providers.dart` and `combat_stats_card.dart`), confirming this is a new feature implementation to be tested via black-box integration tests.

## 2. Logic Chain
Based on the requirements and constraints:
- Tier 1 tests must cover the core functional aspects of displaying a list of encounters and rendering details in multiple panes.
- Tier 2 tests must address edge cases like missing data, UI overflows, and extreme limits, ensuring the UI adheres to the `GEMINI.md` failure and empty state standards.
- Tests should be written for the Patrol framework to simulate user interactions on both desktop and mobile layouts.

## 3. Test Cases for F5

### Tier 1: Feature Coverage (Core Functionality)
1. **T1.1 Encounter List Population**
   - **Action**: Load the application with mock combat log fixtures containing multiple encounters.
   - **Expected**: The encounter list renders the correct number of items. Selecting an item highlights it in the list.
2. **T1.2 Multi-pane Content Synchronization**
   - **Action**: Select different encounters sequentially from the list.
   - **Expected**: The multi-pane analysis view updates its content (e.g., timestamp, target name, total damage) to match the currently selected encounter.
3. **T1.3 Pane Navigation within Analysis View**
   - **Action**: Select an encounter, then navigate between its sub-panes (e.g., "Summary", "Timeline", "LLM Insights" tabs).
   - **Expected**: The content switches appropriately without losing the context of the selected encounter.
4. **T1.4 Encounter Sorting and Filtering**
   - **Action**: Apply a sort operation (e.g., newest first) and a filter (e.g., specific ship type) on the encounter list.
   - **Expected**: The list re-orders and filters out non-matching encounters correctly.
5. **T1.5 Adaptive Responsive Layout**
   - **Action**: Render the view in both Desktop (wide screen) and Mobile (narrow viewport) configurations.
   - **Expected**: On desktop, a side-by-side master-detail view is shown. On mobile, the list takes the full screen, and selecting an item pushes the analysis view onto the navigation stack.

### Tier 2: Boundary & Corner Cases (Edge Cases)
1. **T2.1 Empty Encounter State**
   - **Action**: Load the UI with zero parsed encounters.
   - **Expected**: The list displays the standard "Empty Data State" as defined in `GEMINI.md` (Icon, Heading, Description, no refresh button unless via AppBar).
2. **T2.2 Layout Overflow Prevention**
   - **Action**: Load an encounter with an extremely long target name, pilot name, or excessive metadata.
   - **Expected**: No UI overflow exceptions occur. Text should gracefully wrap or truncate (e.g., using `TextOverflow.ellipsis`).
3. **T2.3 Partial/Malformed Encounter Data**
   - **Action**: Select an encounter where specific metrics (e.g., damage timeline) failed to parse or are missing.
   - **Expected**: The multi-pane view does not crash. Missing sections display a fallback UI or standard error state (`.when(error: ...)`).
4. **T2.4 Rapid Selection Switching Race Condition**
   - **Action**: Rapidly tap/click multiple encounters in the list before the multi-pane view finishes rendering or loading async data.
   - **Expected**: The UI remains stable. The final displayed pane data correctly corresponds to the very last encounter selected.
5. **T2.5 High Volume List Performance**
   - **Action**: Load an encounter list with an excessive number of records (e.g., 500+).
   - **Expected**: The `ListView` / `CustomScrollView` renders without significant frame drops, and scrolling remains smooth (verifying proper use of lazy loading/ListView.builder).

## 4. Caveats
- The specific tabs or panes within the multi-pane view (e.g., "Summary", "Timeline") are assumptions based on standard battle analyzer patterns; actual tab names may vary during implementation.
- Real LLM data parsing speeds are mocked for UI testing, so T2.4 assumes an artificial delay to test async loading.

## 5. Conclusion & Verification Method
- **Conclusion**: We have designed 10 comprehensive tests (5 Tier 1, 5 Tier 2) that fulfill the F5 requirements and align with the UI/testing standards set in `GEMINI.md`.
- **Verification Method**: These test cases should be implemented as Patrol tests in `integration_test/screens/combat_analyzer/encounter_list_test.dart`. Run `flutter test integration_test/screens/combat_analyzer/` to verify execution once the feature and tests are implemented.
