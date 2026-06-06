# Feature F4: LLM API Key Input and Secure Storage (Test Specs)

This document contains the opaque-box test cases for the LLM API key input and secure storage feature. 

## Tier 1: Feature Coverage (Happy-Path)

### [ ] 1. Initial API Key Entry and Save
- **Scenario:** A user navigates to the settings/API key page for the first time and enters a valid key.
- **Inputs:** A valid LLM API key (e.g., `sk-valid-api-key-12345`).
- **Actions:** 
  1. Open the API Key settings screen.
  2. Enter the valid API key into the input field.
  3. Tap the "Save" or "Submit" button.
- **Expected Outcomes:** 
  - A success confirmation message (e.g., "API Key saved successfully") is displayed.
  - The input field is either cleared and replaced by a masked key representation (e.g., `sk-...345`), or shows a success state indicating a key is stored.

### [ ] 2. API Key Persistence Across Sessions
- **Scenario:** An API key is saved, and the user restarts the application.
- **Inputs:** Previously saved valid API key.
- **Actions:** 
  1. Save a valid API key.
  2. Fully close and terminate the application.
  3. Re-open the application and navigate back to the API Key settings screen.
- **Expected Outcomes:** 
  - The application accurately reflects that the API key is already configured and stored securely.
  - The UI displays the masked key or "Key Configured" state without requiring re-entry.

### [ ] 3. Updating an Existing API Key
- **Scenario:** A user with a previously saved API key decides to replace it with a new one.
- **Inputs:** A new valid LLM API key (e.g., `sk-new-api-key-67890`).
- **Actions:** 
  1. Navigate to the API Key settings screen where an existing key is shown.
  2. Enter the new API key into the input field (or tap "Edit Key" if applicable).
  3. Tap the "Save" button.
- **Expected Outcomes:** 
  - A success confirmation message is displayed.
  - The UI updates to reflect the new key (e.g., showing the new masked suffix `...890`).

### [ ] 4. Removing/Deleting an API Key
- **Scenario:** A user wants to remove their securely stored API key from the app.
- **Inputs:** None.
- **Actions:** 
  1. Navigate to the API Key settings screen where a key is already stored.
  2. Tap the "Remove Key", "Clear", or "Delete" button.
  3. Confirm the deletion prompt if one appears.
- **Expected Outcomes:** 
  - The API key is removed from secure storage.
  - The UI resets to its default empty state, prompting the user to enter an API key.

### [ ] 5. Testing API Key Connection
- **Scenario:** A user wants to verify that the entered API key works.
- **Inputs:** A valid LLM API key.
- **Actions:** 
  1. Enter a valid API key.
  2. Tap a "Test Connection" or "Verify" button.
- **Expected Outcomes:** 
  - The application displays a loading indicator.
  - After a short delay, a success message indicating "Connection Successful" or "Key is valid" is shown.


## Tier 2: Boundary & Corner Cases (Edge Cases)

### [ ] 6. Empty API Key Submission
- **Scenario:** A user attempts to save without entering any text.
- **Inputs:** Empty string (`""`).
- **Actions:** 
  1. Navigate to the API Key settings screen.
  2. Leave the input field blank.
  3. Tap the "Save" button.
- **Expected Outcomes:** 
  - The app prevents saving.
  - A validation error message (e.g., "API key cannot be empty") is displayed next to or below the input field.

### [ ] 7. Whitespace-Only API Key Submission
- **Scenario:** A user accidentally enters only spaces or tabs into the input field.
- **Inputs:** Multiple space characters (`"    "`).
- **Actions:** 
  1. Enter spaces into the API key input field.
  2. Tap the "Save" button.
- **Expected Outcomes:** 
  - The app prevents saving.
  - A validation error message is displayed, treating the whitespace as an empty input.

### [ ] 8. Pasting Key with Leading/Trailing Whitespace
- **Scenario:** A user copies an API key but accidentally copies spaces before or after the key.
- **Inputs:** A valid API key padded with whitespace (e.g., `"   sk-valid-api-key-123   "`).
- **Actions:** 
  1. Paste the padded key into the input field.
  2. Tap the "Save" button.
- **Expected Outcomes:** 
  - The app automatically trims the surrounding whitespace.
  - The trimmed API key is successfully saved and correctly masked in the UI.

### [ ] 9. Invalid API Key Format (Test Connection Failure)
- **Scenario:** A user enters a string that is not a real API key.
- **Inputs:** Random characters or an invalid format (e.g., `invalid_key_string`).
- **Actions:** 
  1. Enter the invalid key.
  2. Tap "Save" and then "Test Connection".
- **Expected Outcomes:** 
  - The save action may succeed (if format validation is loose), but the "Test Connection" action fails.
  - The app handles the API error gracefully, displaying a user-friendly message like "Invalid API Key: Verification failed." and does not crash.

### [ ] 10. Extremely Long Input String
- **Scenario:** A user pastes an absurdly long string into the API key field to test UI and storage limits.
- **Inputs:** A string consisting of 10,000 random alphanumeric characters.
- **Actions:** 
  1. Paste the extremely long string into the input field.
  2. Tap the "Save" button.
- **Expected Outcomes:** 
  - The application does not crash.
  - Either the app successfully truncates/rejects the key with a clear error message (e.g., "Key is too long"), or saves it but correctly handles the subsequent verification failure gracefully.

### [ ] 11. Network Failure During Key Validation
- **Scenario:** A user attempts to test their API key while the device has no internet connection.
- **Inputs:** A valid API key.
- **Actions:** 
  1. Disable the device's internet connection (turn on airplane mode).
  2. Enter the valid API key and tap "Test Connection".
- **Expected Outcomes:** 
  - The application detects the lack of connectivity.
  - Displays a specific network error message (e.g., "Network error: Unable to verify key. Please check your connection.") rather than an "Invalid Key" message.
