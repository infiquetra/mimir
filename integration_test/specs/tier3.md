# Tier 3: Cross-Feature Combination E2E Tests

This document outlines the end-to-end test cases that verify the interaction between different feature pairs of the AI-Driven Battle Analyzer.

## Features Reference
- **F1**: Auto discovery of log dir
- **F2**: Parse Listener
- **F3**: Local token optimization
- **F4**: API key storage
- **F5**: UI analysis view
- **F6**: Caching
- **F7**: Local metrics
- **F8**: LLM processing

---

## Test Cases

### F1 + F2: Auto Discovery & Parse Listener
- [ ] **Test Case 3.1: Automatic listener attachment**
  - **Setup**: Start app with a mock default Eve Online log directory containing sample logs.
  - **Action**: App completes startup sequence.
  - **Expected**: F1 automatically discovers the log directory and F2 successfully attaches the Parse Listener to it, processing existing sample logs without manual user intervention.

### F2 + F5: Parse Listener & UI Analysis View
- [ ] **Test Case 3.2: Real-time UI updates on new log events**
  - **Setup**: App is running with F5 UI analysis view open. F2 Parse listener is active.
  - **Action**: Inject a new mock combat log file into the watched directory.
  - **Expected**: F2 detects and parses the new log, and F5 immediately reflects the new combat event in the UI without a manual refresh.

### F3 + F8: Local Token Optimization & LLM Processing
- [ ] **Test Case 3.3: Optimized LLM API requests**
  - **Setup**: Load a large battle log (e.g., 500+ lines). API key is configured.
  - **Action**: Request AI analysis for the large log.
  - **Expected**: F3 compresses/optimizes the log data into a smaller token footprint. F8 sends this optimized payload to the LLM. Verify the network inspector shows a reduced payload size compared to the raw text.

### F4 + F8: API Key Storage & LLM Processing
- [ ] **Test Case 3.4: Secure key usage during AI analysis**
  - **Setup**: Store a valid API key in the F4 secure storage. Clear any mock LLM responses.
  - **Action**: Trigger an AI analysis for a battle log.
  - **Expected**: F8 retrieves the key from F4's secure storage, successfully authenticates with the LLM API, and returns an analysis without exposing the key in plain text logs.

### F6 + F8: Caching & LLM Processing
- [ ] **Test Case 3.5: Caching prevents redundant LLM calls**
  - **Setup**: Analyze a specific battle log to generate a cached response via F8.
  - **Action**: Request AI analysis for the *exact same* battle log again.
  - **Expected**: F6 intercepts the request. F8 does *not* make an external API call, and the cached analysis is returned immediately.

### F2 + F7: Parse Listener & Local Metrics
- [ ] **Test Case 3.6: Local metrics generated from parsed streams**
  - **Setup**: Clear F7 local metrics. Start the F2 Parse Listener.
  - **Action**: Stream several combat logs (e.g., dealing damage, taking damage) into the directory over time.
  - **Expected**: F2 parses the logs as they arrive, and F7 correctly aggregates these into accurate local DPS and tanking metrics in real time.

### F5 + F7: UI Analysis View & Local Metrics
- [ ] **Test Case 3.7: UI rendering of local metrics**
  - **Setup**: Pre-load the database with F7 local combat metrics.
  - **Action**: Open the F5 UI Analysis View and navigate to the metrics dashboard.
  - **Expected**: F5 accurately queries F7 and renders the correct DPS graphs, incoming damage charts, and relevant statistics.

### F1 + F5: Auto Discovery & UI Analysis View
- [ ] **Test Case 3.8: UI reflects discovered directory**
  - **Setup**: Set a specific custom mock path as the default Eve directory.
  - **Action**: Launch the app and open the settings/analysis UI (F5).
  - **Expected**: F1 discovers the custom path, and F5 displays this path correctly in the settings, showing it as "Active and Discovered".

### F3 + F6: Local Token Optimization & Caching
- [ ] **Test Case 3.9: Cache keys based on optimized tokens**
  - **Setup**: Prepare two raw logs that are identical in combat actions but differ in irrelevant white space or timestamp formats.
  - **Action**: Analyze the first log. Then analyze the second log.
  - **Expected**: F3 strips the irrelevant data resulting in identical optimized token strings for both logs. F6 uses this optimized string as the cache key, returning a cache hit for the second log.

### F4 + F5: API Key Storage & UI Analysis View
- [ ] **Test Case 3.10: UI prompts for missing API key**
  - **Setup**: Ensure F4 secure storage is empty (no API key).
  - **Action**: Open F5 UI analysis view and click "Analyze Battle".
  - **Expected**: The UI prevents the analysis and gracefully displays a prompt/modal asking the user to enter their API key, utilizing F4's save mechanism.

### F6 + F5: Caching & UI Analysis View
- [ ] **Test Case 3.11: Instant UI load from cache**
  - **Setup**: Analyze a battle to ensure it is stored in the F6 cache.
  - **Action**: Navigate away from the F5 analysis view, then navigate back to the same battle's analysis.
  - **Expected**: F5 loads the cached data from F6 instantly, bypassing any "Loading AI Response..." spinners or loading states.
