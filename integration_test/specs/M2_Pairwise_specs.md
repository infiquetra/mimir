# M2 Cross-Feature Combinations (Tier 3) Tests

This document defines Tier 3 integration test specifications for the cross-feature interactions of M2 features: F4, F6, and F8.

## Features
- **F4**: LLM API key input and secure storage
- **F6**: Local caching (Drift) of LLM responses
- **F8**: LLM log processing (mocked) and result structure

## Test Cases

### Test Case 1: F4 + F8 - API Key validation gates log processing
- **Scenario**: The system must verify the presence of a valid API key before initiating log processing.
- **Inputs**: 
  - API Key: None (cleared)
  - Log Input: Valid raw combat log snippet
- **Actions**:
  1. Navigate to Settings and ensure the LLM API Key is empty or cleared.
  2. Navigate to the Log Processing screen.
  3. Paste the valid raw combat log snippet into the input field.
  4. Tap the "Process" button.
- **Expected Outcomes**:
  - The system does not attempt to process the log.
  - An error message or dialog is displayed indicating that an API key is required.
  - No result structure is shown on the screen.

### Test Case 2: F6 + F8 - Log processing populates cache and subsequent identical requests use cache
- **Scenario**: Processing a log successfully should store the result in the local cache, and subsequent identical requests should retrieve the result from the cache instead of re-processing.
- **Inputs**:
  - API Key: "valid-test-key"
  - Log Input: "Combat log snippet A"
- **Actions**:
  1. Configure the valid API key in Settings.
  2. Navigate to the Log Processing screen.
  3. Paste "Combat log snippet A" and tap "Process".
  4. Observe the processing indicator and wait for the result structure to appear.
  5. Clear the result (or navigate away and back).
  6. Paste the exact same "Combat log snippet A" and tap "Process" again.
- **Expected Outcomes**:
  - The first request shows a processing state (simulating network/LLM delay) and eventually displays the parsed result structure.
  - The second request resolves almost instantly.
  - The result structure matches the first request perfectly.
  - A UI indicator or log message confirms the result was loaded from the local cache.

### Test Case 3: F4 + F6 - Cached results are accessible even if API key is removed
- **Scenario**: Once a log response is cached, retrieving it should not require an active/valid API key.
- **Inputs**:
  - API Key: "valid-test-key" (initially), then None.
  - Log Input: "Combat log snippet B"
- **Actions**:
  1. Configure the valid API key in Settings.
  2. Process "Combat log snippet B" to ensure its result is cached.
  3. Verify the result structure is displayed.
  4. Navigate to Settings and delete/clear the API key.
  5. Navigate back to the Log Processing screen.
  6. Paste the exact same "Combat log snippet B" and tap "Process".
- **Expected Outcomes**:
  - The system successfully loads and displays the result structure for "Combat log snippet B".
  - No API key error is thrown, demonstrating that cache retrieval bypasses the API key check.

### Test Case 4: F4 + F6 + F8 - Cache misses correctly fallback to processing and enforce API key requirements
- **Scenario**: Modifying a previously processed log creates a cache miss, which then triggers the full processing flow, thereby requiring a valid API key.
- **Inputs**:
  - API Key: "valid-test-key" (initially), then None.
  - Log Input 1: "Combat log snippet C"
  - Log Input 2: "Combat log snippet C - modified"
- **Actions**:
  1. Configure the valid API key in Settings.
  2. Process "Combat log snippet C" to cache its result.
  3. Navigate to Settings and delete/clear the API key.
  4. Navigate back to the Log Processing screen.
  5. Paste "Combat log snippet C - modified" (a slightly altered version of the original log).
  6. Tap "Process".
- **Expected Outcomes**:
  - The system detects a cache miss for the modified log.
  - The system attempts to initiate log processing (F8).
  - The system blocks the processing and displays an error indicating the API key is missing (F4).
  - No result structure is shown for the modified log.
