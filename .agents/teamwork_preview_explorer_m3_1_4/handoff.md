# Combat Analyzer E2E Test Design (M3.1)

## 1. Observation
- `original_prompt.md` details requirements for Combat Analyzer: F4 (Encounter List UI), F6 (Analysis Multi-Pane UI), and F7 (Raw Metrics Calculation).
- `TEST_INFRA.md` specifies that tests must be opaque-box Flutter integration tests, using Category-Partition and BVA methodologies, reaching at least 5 Tier-1 tests per feature.
- `GEMINI.md` mandates using the `TestApp` wrapper, properly handling `AsyncValue` (loading, error, data states), and ensuring responsive layouts that avoid overflow errors.

## 2. Logic Chain
- **F4 (Encounter List UI)**: Needs coverage for the complete data lifecycle: no character selected, character selected but no logs, loading data, successfully rendering logs, and navigating to a log.
- **F6 (Analysis Multi-Pane UI)**: Must verify the presence and navigation of the four required panes ("What went wrong", "How to improve", "Fit improvements", "Metrics"). Furthermore, it must ensure no `RenderFlex` overflow errors occur on mobile viewports.
- **F7 (Raw Metrics Calculation)**: Must verify that damage dealt/received numbers are accurate. Edge cases like zero damage must be handled without throwing NaN exceptions. Since metrics are calculated locally, they should be displayed independently of LLM API success or failure.
- To enable parallel development, minimal UI stubs are required in the presentation layer so the test compiler can resolve screen classes and widget keys.

## 3. Caveats
- The design assumes the use of standard Material widgets (e.g., `TabBar`, `ListTile`, `CircularProgressIndicator`). If custom widgets are implemented instead, test selectors (like `find.byType(TabBar)`) will need adjustment.
- It is assumed that data providers (e.g., `encounterListProvider`, `encounterDetailProvider`) will be mocked in `TestApp` via `overrides`.

## 4. Conclusion & Test Designs

### Feature F4: Encounter List UI
1. **Empty State - No Character**
   - **Inputs**: `TestApp` initialized with `initialCharacter: null`.
   - **Expected**: Finds `find.text('No Character Selected')` and `find.byIcon(Icons.person_off_outlined)`.
2. **Empty State - No Encounters**
   - **Inputs**: Valid character, but `encounterListProvider` returns an empty list.
   - **Expected**: Finds `find.text('No encounters found')` and `find.byType(ListView)` is empty.
3. **Loading State**
   - **Inputs**: `encounterListProvider` mocked with a delayed `Completer`.
   - **Expected**: Finds `find.byType(CircularProgressIndicator)`.
4. **Data State - List Rendering**
   - **Inputs**: `encounterListProvider` mocked with 2 valid encounters.
   - **Expected**: Finds 2 `ListTile` widgets containing the encounter titles (e.g., "Combat vs Merlin").
5. **Navigation to Details**
   - **Inputs**: Tap the first `ListTile`.
   - **Expected**: Application navigates; `find.byType(AnalysisMultiPaneScreen)` (or equivalent) is found.

### Feature F6: Analysis Multi-Pane UI
1. **Pane Presence & Initialization**
   - **Inputs**: Navigate to analysis view with a valid encounter.
   - **Expected**: Finds text labels for "What went wrong", "How to improve", "Fit improvements", and "Metrics".
2. **Tab Navigation (What went wrong -> Fit improvements)**
   - **Inputs**: Tap the "Fit improvements" tab/button.
   - **Expected**: The content for fit improvements becomes visible on screen; original pane content is hidden or replaced.
3. **Responsive Layout (Overflow Prevention)**
   - **Inputs**: Set viewport physical size to `400x800`. Navigate through all panes.
   - **Expected**: No `FlutterError` (specifically `RenderFlex` overflow) occurs.
4. **LLM Loading State**
   - **Inputs**: Analysis provider mocked with a delayed `Completer`.
   - **Expected**: Finds a `CircularProgressIndicator` within the active LLM pane.
5. **LLM Error State**
   - **Inputs**: Analysis provider mocked to throw an exception.
   - **Expected**: Finds an error icon and a "Retry" button in the LLM panes.

### Feature F7: Raw Metrics Calculation
1. **Accurate Damage Dealt Display**
   - **Inputs**: Encounter log parsed with 500 damage dealt.
   - **Expected**: Finds text containing "500" adjacent to "Damage Dealt" labels.
2. **Accurate Damage Received Display**
   - **Inputs**: Encounter log parsed with 300 damage received.
   - **Expected**: Finds text containing "300" adjacent to "Damage Received" labels.
3. **Zero Damage Handling**
   - **Inputs**: Encounter log parsed with 0 damage.
   - **Expected**: Finds "0" for damage dealt/received without encountering exceptions or displaying `NaN`.
4. **Metrics Over Time Rendering**
   - **Inputs**: Valid encounter log with duration.
   - **Expected**: Finds a chart widget (e.g., `find.byKey(Key('damage_timeline_chart'))`) or timeline text.
5. **Independence from LLM Failure**
   - **Inputs**: Valid log, but LLM analysis throws an error.
   - **Expected**: The Metrics pane still displays correct damage numbers and timeline, even though the LLM panes show an error state.

### Required UI Stubs (`lib/features/combat_analyzer/presentation/`)
To make these tests compile, the following minimal stubs must be created:
1. `encounter_list_screen.dart` - Containing `class EncounterListScreen extends ConsumerWidget`.
2. `analysis_multi_pane_screen.dart` - Containing `class AnalysisMultiPaneScreen extends ConsumerWidget`.
3. `widgets/encounter_list_tile.dart` - Containing `class EncounterListTile extends StatelessWidget`.
4. `widgets/llm_analysis_pane.dart` - Containing `class LlmAnalysisPane extends ConsumerWidget`.
5. `widgets/metrics_pane.dart` - Containing `class MetricsPane extends ConsumerWidget`.

## 5. Verification Method
- **Compiler Check**: Run `flutter analyze` after creating the test files and the UI stubs. It must pass without unresolved class errors.
- **Test Execution**: Run `flutter test integration_test/screens/combat_analyzer/`. The tests should compile and run (they will fail initially until the business logic is implemented).
