# M3 Test Specifications: F5 & F7

## Overview
This document contains the detailed test case specifications for M3, covering Feature F5 (Encounter list UI and multi-pane analysis view) and Feature F7 (Local parsing metrics). The Implementation Track will use these specifications to write the actual Flutter tests (`integration_test/screens/combat_analyzer/` and `test/features/combat_analyzer/`).

---

## Feature F5: Encounter list UI and multi-pane analysis view

### Tier 1 (Feature Coverage)
1. **Empty State**: Verify that the encounter list renders an appropriate empty state (icon and message) when no encounters are present.
2. **List Rendering**: Verify that the encounter list renders a list of cards correctly showing summary data (date/time, total damage, primary participants).
3. **Navigation**: Verify that tapping an encounter card navigates to or opens the multi-pane analysis view for that specific encounter.
4. **Multi-pane - Dealt**: Verify that the multi-pane view correctly renders the "Damage Dealt" section (e.g., list or chart).
5. **Multi-pane - Received**: Verify that the multi-pane view correctly renders the "Damage Received" section (e.g., list or chart).

### Tier 2 (Boundary & Corner Cases)
1. **Layout Overflow**: Verify that encounters with extremely long names or a massive number of participants do not cause pixel overflow in the UI.
2. **Zero Damage**: Verify that an encounter with 0 damage (e.g., only evades or movement) renders correctly without division-by-zero errors in charts.
3. **Rapid Switching**: Verify that rapidly tapping different encounters (or fast navigation) does not cause state bleeding between analysis panes.
4. **Responsive Layout**: Verify that the multi-pane layout adapts to narrow viewports (stacked vertically) and wide viewports (side-by-side).
5. **Fallback Resolution**: Verify that if an entity ID cannot be resolved, the UI falls back gracefully using `itemNameProvider` without crashing.

---

## Feature F7: Local parsing metrics (damage dealt/received over time)

### Tier 1 (Feature Coverage)
1. **Total Damage Dealt**: Verify that the parser accurately calculates the total damage dealt from a standard combat log fixture.
2. **Total Damage Received**: Verify that the parser accurately calculates total damage received and correctly attributes the source.
3. **Grouping**: Verify that damage is correctly grouped by weapon type or entity.
4. **Timeline Generation**: Verify that the parser generates a correct timeline array (e.g., damage per interval) for graphing purposes.
5. **Noise Rejection**: Verify that the parser ignores non-combat log lines (chat, motd, system messages) without throwing errors.

### Tier 2 (Boundary & Corner Cases)
1. **Performance/Size**: Verify that the parser can handle an extremely large log file efficiently without hanging the main isolate.
2. **Malformed Lines**: Verify that a log file containing corrupted or malformed lines recovers gracefully, skipping only the bad lines.
3. **Timestamp Edge Cases**: Verify that logs bridging midnight or containing leap-second/timezone edge cases parse into sequential timelines correctly.
4. **Encounter Boundaries**: Verify that back-to-back encounters or logs with long pauses correctly segment into distinct encounters.
5. **Integer Overflow**: Verify that extremely large damage values (e.g., structure bashes) do not cause overflow and are parsed correctly.

---

## Tier 3 (Cross-Feature Pairwise)
1. **Real-time Updates (F5xF7)**: Verify that if F7 continues parsing in the background, the F5 UI updates reactively to reflect the new metrics.
2. **Summary Accuracy (F5xF7)**: Verify that the top-level encounter list (F5) accurately displays the aggregated totals from the F7 parsing without needing to load the full detail view.
3. **Timeline Bounds (F5xF7)**: Verify that the F5 timeline UI scrubber exactly matches the first and last timestamp parsed by F7.
