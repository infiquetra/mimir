# Industry Window with BOM Calculator Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Add a new Industry feature area with a BOM Calculator tab, supporting item search, graph visualization, and shopping list management.

**Architecture:** 
- Add `industry` to `WindowType` for multi-window support.
- Implement `IndustryScreen` as a tabbed layout.
- Implement `BomCalculatorScreen` using Riverpod for search and calculation state.
- Use `fl_chart` for tree/graph visualization of the bill of materials.

**Tech Stack:** Flutter, Riverpod, fl_chart, drift.

---

### Task 1: Update WindowType Enum
**Objective:** Register Industry as a first-class window type.
**Files:**
- Modify: `lib/core/window/window_types.dart`
**Instructions:**
- Add `industry` to `WindowType` enum.
- Update `WindowTypeExtension`:
  - `title`: 'Industry - Mimir'
  - `windowId`: 7
  - `defaultSize`: (width: 1200, height: 900)
  - `iconAsset`: 'assets/icons/eve/industry.png' (Ensure asset exists or use placeholder)
- Update `fromId` static method to handle 7.

### Task 2: Create Industry Screen Base
**Objective:** Create the main Industrial hub with tabs.
**Files:**
- Create: `lib/features/industry/presentation/industry_screen.dart`
**Instructions:**
- Use `ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`.
- Implement `TabBar` with titles: 'Jobs', 'Blueprints', 'BOM Calculator'.
- The initial tab should be 'BOM Calculator' (index 2).
- Log screen entry.

### Task 3: Create BOM Calculator Screen Shell
**Objective:** Implement the layout for the BOM Calculator.
**Files:**
- Create: `lib/features/industry/presentation/bom_calculator_screen.dart`
**Instructions:**
- Add a search bar at the top for items.
- A main area for the BOM tree/graph.
- A right sidebar for the "Shopping List".
- A "Copy to Clipboard" button in the shopping list.

### Task 4: Implement Item Search Logic
**Objective:** Allow users to search for items to calculate.
**Files:**
- Create: `lib/features/industry/data/industry_providers.dart`
**Instructions:**
- Create a `bomSearchProvider` that uses `esiClient` or `database` to search for types.
- Integrate with an `Autocomplete` widget in `bom_calculator_screen.dart`.

### Task 5: Implement BOM Calculation State
**Objective:** Manage the tree structure of materials.
**Files:**
- Modify: `lib/features/industry/data/industry_providers.dart`
**Instructions:**
- Create a `bomCalculatorProvider` (StateNotifier or equivalent) that takes a `typeId` and recursively fetches blueprint materials.
- This might require access to an SDE (Static Data Export) table for blueprints.

### Task 6: Add Visualizations
**Objective:** Integrate `fl_chart` or simple tree view for BOM visualization.
**Files:**
- Modify: `lib/features/industry/presentation/bom_calculator_screen.dart`
**Instructions:**
- Display materials in a hierarchical list or simple bar chart showing relative ISK costs.

### Task 7: Shopping List and Clipboard
**Objective:** Consolidate materials and allow copying.
**Files:**
- Modify: `lib/features/industry/presentation/bom_calculator_screen.dart`
**Instructions:**
- Sum identical materials across the whole tree.
- Format for EVE Online's multifit/buy list format: `<Item Name> <Quantity>`.
- Use `Clipboard.setData`.
