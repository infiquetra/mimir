# Tier 1 E2E Test Specifications: Feature Coverage

This document outlines the Tier 1 test cases for the AI-Driven Battle Analyzer feature in Mimir. These are happy-path, single-feature focus tests designed to verify that each feature functions correctly in isolation using equivalence class representatives.

## Feature 1: Automatic discovery/scanning of combat log directory
Source: ORIGINAL_REQUEST R2 & AC

- [ ] **T1.F1.01**: Verify scanner successfully finds valid `.txt` log files in a populated default directory.
- [ ] **T1.F1.02**: Verify scanner handles a missing or non-existent log directory gracefully without crashing, displaying appropriate empty state.
- [ ] **T1.F1.03**: Verify scanner handles an existing but empty log directory gracefully, displaying appropriate empty state.
- [ ] **T1.F1.04**: Verify scanner correctly identifies and ignores non-log files (e.g., `.png`, `.zip`, `.pdf`) present in the directory.
- [ ] **T1.F1.05**: Verify scanner operates correctly across simulated different OS paths (e.g., Windows vs. macOS default paths).

## Feature 2: Parse `Listener: [Name]` for character association
Source: ORIGINAL_REQUEST R2

- [ ] **T1.F2.01**: Verify parser correctly extracts standard alphanumeric character names from the `Listener:` header.
- [ ] **T1.F2.02**: Verify parser correctly extracts character names containing spaces and special characters (e.g., apostrophes or hyphens).
- [ ] **T1.F2.03**: Verify parser gracefully handles logs where the `Listener:` header is missing or malformed, associating them with a default/unknown character or rejecting them safely.
- [ ] **T1.F2.04**: Verify parser correctly matches the extracted listener name to the currently active Mimir character.
- [ ] **T1.F2.05**: Verify parser handles logs with unexpected whitespace around the `Listener:` header.

## Feature 3: Local token optimization (filtering/summarizing logs)
Source: ORIGINAL_REQUEST R2

- [ ] **T1.F3.01**: Verify token optimizer successfully groups and summarizes consecutive identical combat events (e.g., multiple drone misses).
- [ ] **T1.F3.02**: Verify token optimizer filters out known non-combat spam or irrelevant system messages before preparing the payload.
- [ ] **T1.F3.03**: Verify token optimizer leaves short, dense combat logs largely intact without over-summarizing.
- [ ] **T1.F3.04**: Verify token optimizer enforces a maximum token/character limit, truncating safely if the summarized log is still too large.
- [ ] **T1.F3.05**: Verify the optimization process maintains the chronological integrity of the remaining log events.

## Feature 4: LLM API key input and secure storage
Source: ORIGINAL_REQUEST R3 & AC

- [ ] **T1.F4.01**: Verify user can input a valid API key and save it, resulting in a success confirmation in the UI.
- [ ] **T1.F4.02**: Verify submitting an empty API key displays a clear validation error and prevents saving.
- [ ] **T1.F4.03**: Verify the API key input field obscures the text (password style) to prevent shoulder surfing.
- [ ] **T1.F4.04**: Verify a saved API key is successfully retrieved from secure storage upon application restart.
- [ ] **T1.F4.05**: Verify user can successfully clear/delete an existing saved API key.

## Feature 5: Encounter list UI and multi-pane analysis view
Source: ORIGINAL_REQUEST R4 & AC

- [ ] **T1.F5.01**: Verify the encounter list correctly renders multiple encounters with basic summary info (date, opponent, outcome).
- [ ] **T1.F5.02**: Verify selecting an encounter in the list correctly navigates to the detailed multi-pane analysis view.
- [ ] **T1.F5.03**: Verify the detailed analysis view correctly renders the 4 required panes ("What went wrong", "How to improve", "Fit improvements", "Metrics").
- [ ] **T1.F5.04**: Verify user can seamlessly switch between the 4 panes, and the content updates to reflect the active pane without UI overflow.
- [ ] **T1.F5.05**: Verify the encounter list displays a helpful empty state when no combat logs are found for the active character.

## Feature 6: Local caching (Drift) of LLM responses
Source: ORIGINAL_REQUEST R4 & AC

- [ ] **T1.F6.01**: Verify a newly received LLM analysis response is successfully inserted into the local Drift database.
- [ ] **T1.F6.02**: Verify viewing an already-analyzed encounter retrieves the analysis from the Drift database instead of making a new API call.
- [ ] **T1.F6.03**: Verify cached LLM responses persist correctly across application restarts.
- [ ] **T1.F6.04**: Verify the caching mechanism gracefully handles and recovers from corrupted or incompatible JSON data in the database.
- [ ] **T1.F6.05**: Verify the UI clearly indicates (e.g., via a loading spinner) when an analysis is being fetched from the network vs loaded instantly from cache.

## Feature 7: Local parsing metrics (damage dealt/received over time)
Source: ORIGINAL_REQUEST R5 & AC

- [ ] **T1.F7.01**: Verify local parser accurately calculates total damage dealt from a standard combat log.
- [ ] **T1.F7.02**: Verify local parser accurately calculates total damage received from a standard combat log.
- [ ] **T1.F7.03**: Verify local parser can correctly bucket damage events into time intervals (e.g., per minute or per 10 seconds) for graphing.
- [ ] **T1.F7.04**: Verify the Metrics pane renders a placeholder or empty state gracefully when a log contains zero damage events.
- [ ] **T1.F7.05**: Verify local parser correctly distinguishes between damage to shields, armor, and hull.

## Feature 8: LLM log processing (mocked) and result structure
Source: ORIGINAL_REQUEST R3, R5, AC

- [ ] **T1.F8.01**: Verify the app correctly sends a processed log to a mocked LLM endpoint and successfully parses a well-formed JSON response.
- [ ] **T1.F8.02**: Verify the app displays a user-friendly error message when the LLM endpoint returns a 500 Internal Server Error.
- [ ] **T1.F8.03**: Verify the app displays a user-friendly timeout message if the LLM endpoint takes too long to respond.
- [ ] **T1.F8.04**: Verify the app gracefully handles and displays fallback UI when the LLM returns malformed or non-JSON text.
- [ ] **T1.F8.05**: Verify the structured response maps perfectly to the UI panes, confirming "tactical mistakes" appear in "What went wrong" and "advice" appears in "How to improve".
