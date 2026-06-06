# M2 F6 Specs: Local Caching (Drift) of LLM Responses

## Tier 1: Feature Coverage (Happy Path)

- [ ] **Test Case 1: Cache New LLM Response**
  - **Scenario:** The user submits a prompt for the first time, and the response is cached.
  - **Inputs:** A valid, unique text prompt (e.g., "What are the rules of EVE Online?").
  - **Actions:** 
    1. User submits the prompt.
    2. Wait for the LLM to finish responding.
    3. User navigates away and then checks the history/cache view.
  - **Expected Outcomes:** 
    - The LLM response is displayed to the user.
    - The prompt and its corresponding response are visible in the cached history list.

- [ ] **Test Case 2: Retrieve Cached Response on Exact Match**
  - **Scenario:** The user submits a prompt that has already been asked and cached.
  - **Inputs:** A prompt identical to one already in the cache.
  - **Actions:**
    1. User submits the prompt.
    2. Observe the response time and network activity (or offline capability).
  - **Expected Outcomes:**
    - The response appears almost instantly.
    - The content matches the previously cached response exactly.
    - (Optional) A UI indicator shows the response was served from cache rather than a live network request.

- [ ] **Test Case 3: View Cache History List**
  - **Scenario:** The user wants to see their past LLM interactions.
  - **Inputs:** Multiple different previously asked prompts.
  - **Actions:**
    1. User submits 3 different prompts and waits for their responses.
    2. User navigates to the "History" or "Cached Responses" screen.
  - **Expected Outcomes:**
    - All 3 prompts and summaries/snippets of their responses are displayed.
    - The entries are sorted chronologically (e.g., newest first).

- [ ] **Test Case 4: Delete Single Cached Entry**
  - **Scenario:** The user removes a specific LLM response from their local cache.
  - **Inputs:** An existing cached entry.
  - **Actions:**
    1. User navigates to the History screen.
    2. User selects a specific entry and taps "Delete" or swipes to delete.
  - **Expected Outcomes:**
    - The selected entry is removed from the History screen immediately.
    - Other cached entries remain intact.

- [ ] **Test Case 5: Clear Entire Cache**
  - **Scenario:** The user wants to wipe all locally cached LLM responses.
  - **Inputs:** An existing cache with multiple entries.
  - **Actions:**
    1. User navigates to Settings or History screen.
    2. User taps "Clear All Cache" (or equivalent) and confirms the action.
  - **Expected Outcomes:**
    - All entries disappear from the History screen.
    - Submitting previously asked prompts results in new network requests instead of instant cache hits.

## Tier 2: Boundary & Corner Cases (Edge Cases)

- [ ] **Test Case 6: Caching Extremely Large Responses**
  - **Scenario:** The LLM generates an exceptionally long response.
  - **Inputs:** A prompt designed to generate a huge amount of text (e.g., "Write a 10,000 word story...").
  - **Actions:**
    1. User submits the prompt and waits for the full response to complete.
    2. User views the History screen and selects the entry to read it.
  - **Expected Outcomes:**
    - The app successfully displays and caches the response without freezing or crashing.
    - The retrieved cached response matches the original long text perfectly without truncation.

- [ ] **Test Case 7: Complex Formatting and Special Characters**
  - **Scenario:** The prompt and response contain diverse character sets and formatting.
  - **Inputs:** A prompt with emojis, multiple languages, and a request for markdown code blocks.
  - **Actions:**
    1. User submits the complex prompt.
    2. User views the cached entry from the History screen.
  - **Expected Outcomes:**
    - Emojis, multi-byte characters, and markdown (code blocks, bold, lists) are rendered correctly both in the initial response and when retrieved from the cache.

- [ ] **Test Case 8: Offline Retrieval of Cached Response**
  - **Scenario:** The user attempts to access a previously cached response without internet access.
  - **Inputs:** A previously cached prompt.
  - **Actions:**
    1. User disables the device's internet connection (Airplane mode).
    2. User submits the exact same prompt OR navigates to the History screen to view it.
  - **Expected Outcomes:**
    - The app instantly provides the cached response despite being offline.
    - No infinite loading spinners or network error crashes occur for the cached prompt.

- [ ] **Test Case 9: Interrupted Response Caching**
  - **Scenario:** The app is closed or network drops while the LLM is streaming its response.
  - **Inputs:** A prompt that takes a long time to generate.
  - **Actions:**
    1. User submits the prompt.
    2. While the response is partially generated/streaming, the user force-quits the app or disconnects the network.
    3. User reopens the app and checks History.
  - **Expected Outcomes:**
    - The cache gracefully handles the interruption: either the partial response is saved and clearly marked as incomplete, or the incomplete response is discarded. The app does not crash upon reading the database.

- [ ] **Test Case 10: Concurrent Identical Prompts**
  - **Scenario:** The user aggressively taps the submit button for the same prompt multiple times before the first response arrives.
  - **Inputs:** A single prompt string.
  - **Actions:**
    1. User rapidly submits the same prompt 5 times in quick succession.
  - **Expected Outcomes:**
    - The app handles the concurrency gracefully (e.g., debouncing the input, or only processing the first request).
    - Only a single entry for this prompt is created in the local cache.
