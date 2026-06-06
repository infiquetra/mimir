# Tier 2: Boundary & Corner Cases (E2E Testing)

## F1. Auto discovery of log dir
- [ ] Directory does not exist on the system
- [ ] Directory exists but is completely empty
- [ ] Directory has insufficient read permissions
- [ ] Multiple valid log directories exist (e.g., multiple accounts/installations)
- [ ] Directory contains a massive number of files (e.g., 10,000+ files) causing potential timeouts during scan

## F2. Parse Listener
- [ ] Log file contains no listener information
- [ ] Listener name contains special/unicode characters (e.g., emojis, Cyrillic, CJK)
- [ ] Listener name is extremely long (e.g., 255+ characters)
- [ ] Listener tag is malformed or incomplete in the log file
- [ ] Multiple listener entries appear conflicting in the same log

## F3. Local token optimization
- [ ] Log file size exceeds the local processing memory limit (e.g., 500MB+)
- [ ] Log file contains only repetitive, identical lines (already optimized or loop)
- [ ] Log file has no combat events, only fluff/chat, resulting in zero tokens post-optimization
- [ ] Log file contains null bytes or corrupted encoding
- [ ] Log file is completely empty (0 bytes)

## F4. API key storage
- [ ] API key field is submitted completely empty
- [ ] API key format is invalid (e.g., spaces, wrong length, special characters)
- [ ] Extremely long string is pasted into the API key field
- [ ] Keyboard shortcuts (Ctrl+V, Cmd+V) paste multi-line strings into the API key field
- [ ] Secure storage (e.g., Keychain/Keystore) is unavailable or locked

## F5. UI analysis view
- [ ] Analysis text is exceptionally long, requiring extensive scrolling
- [ ] Screen size is unusually small (e.g., minimum window resize on desktop or very small mobile screen)
- [ ] Text contains complex markdown formatting (e.g., nested tables, deep lists) that may break the renderer
- [ ] Rapid toggling of dark/light themes while analysis view is rendering
- [ ] Very wide unbroken strings (e.g., URLs or hashes) that could cause horizontal layout overflow

## F6. Caching
- [ ] Cache file exists but is corrupted (e.g., half-written JSON)
- [ ] Storage is completely full when attempting to write to the cache
- [ ] Cache TTL (Time-To-Live) expires exactly during a read operation
- [ ] Concurrent read/write requests to the same cache entry
- [ ] Cache index file is missing while data files remain

## F7. Local metrics
- [ ] Total damage dealt/received is exactly 0
- [ ] Total damage exceeds typical integer limits (e.g., massive values causing integer overflow)
- [ ] Combat events occur with exactly the same timestamp
- [ ] Negative values appear in metrics (e.g., healing registered as negative damage in edge cases)
- [ ] Extremely high frequency of events (e.g., 1000 events per second) during metrics calculation

## F8. LLM processing
- [ ] Network request to the LLM API times out after the maximum allowed duration
- [ ] LLM API returns malformed JSON or plain text instead of the expected structured response
- [ ] Rate limit error (HTTP 429) is returned by the LLM API
- [ ] Response stream is abruptly cut off mid-transmission
- [ ] LLM returns an empty response body with a 200 OK status
