# Handoff Report: EVE Combat Log Ingestion & Parsing

## 1. Observation
- The EVE log files begin with a header containing `Listener: <Character Name>` and `Session Started: <Date>`. (e.g., `Listener: Test Character`).
- Each combat event line has a timestamp prefix: `[ 2026.05.20 18:32:10 ] (combat) <content>`.
- The raw combat lines contain rich text HTML/UI tags, e.g., `<color=0xff00ffff><b>42</b> <color=0x77ffffff><font size=10>from</font> ...`.
- Combat events describe damage dealt (using the word "to"), damage received (using the word "from"), or misses ("misses you completely", "misses").
- Log lines also include environmental/state context, e.g., `Warp drive active`.
- Reference file: `/Users/jefcox/workspace/infiquetra/mimir/test/features/combat_analyzer/fixtures/merlin_combat_log.txt`

## 2. Logic Chain
1. **Header Parsing**: The ingestor must scan the first few lines to extract `Listener: ([^\n]+)`. This directly satisfies the requirement to associate logs with a specific Mimir character.
2. **HTML Stripping**: To perform metric extraction and save LLM tokens, all `<...>` tags must be stripped using a regular expression (e.g., `/<[^>]+>/g`). A cleaned line looks like: `[ 2026.05.20 18:32:15 ] (combat) 120 to State Protector Merlin - Light Neutron Blaster II - Penetrates`.
3. **Metric Extraction**: With clean text, we can use regex to extract the timestamp, damage amount, direction (`to` vs `from`), entity, and weapon. This satisfies the requirement to generate basic metric reports (damage dealt/received over time) locally without needing the LLM.
4. **Token Optimization (Filtering/Compression)**: The LLM does not need to see every individual hit if they are identical. A local buffer can compress repetitive actions within a short time window (e.g., 10 seconds). 
   - *Example*: Three consecutive misses can become `[18:32:10 - 18:32:25] State Protector Merlin misses you completely (x2) - Light Electron Blaster I`.
   - *Example*: Multiple hits can become `[18:32:15 - 18:32:23] 4x hits to State Protector Merlin - Light Neutron Blaster II (Total: 525 dmg)`.
5. **Context Preservation**: Lines that don't match the damage/miss regexes (like `Warp drive active`) should be passed through to the `rawFilteredLog` untouched, as they give the LLM tactical context.
6. **Data Model Strategy**:
   - Create `CombatEncounter` to store the aggregated data ready for the LLM and the UI.
   ```dart
   class CombatEncounter {
     final String id; // UUID
     final String characterName; // From Listener
     final DateTime startTime; // Timestamp of first combat entry
     final DateTime endTime; // Timestamp of last combat entry
     final String rawFilteredLog; // Stripped of HTML and compressed, ready for LLM
     final int totalDamageDealt;
     final int totalDamageReceived;
     final List<DamageDataPoint> damageDealtOverTime; 
     final List<DamageDataPoint> damageReceivedOverTime;
   }
   
   class DamageDataPoint {
     final DateTime timestamp;
     final int amount;
   }
   ```

## 3. Caveats
- The example log is simple (1v1). In large fleet fights, compression will be more complex because damage comes from many different entities simultaneously. Grouping must be keyed by `(Entity, Weapon, ActionType)`.
- We assume logs are partitioned into meaningful "encounters" based on time gaps (e.g., >2 minutes of silence = new encounter) or session breaks. This logic will need to be implemented in the `LogScanner`.
- EVE log timestamps are in EVE Time (UTC). The parser should treat them as UTC.

## 4. Conclusion
We must implement a `LogParser` that processes the log file line-by-line. It should:
1. Extract the `Listener`.
2. Strip HTML tags from all lines.
3. Parse lines to build a timeline of `DamageDataPoint` metrics.
4. Group and compress identical, consecutive actions (by entity/weapon) over small time windows to build a highly dense, token-optimized `rawFilteredLog` string.
5. Output a `CombatEncounter` object which serves as the payload for both the LLM integration and the Mimir UI Metrics pane.

## 5. Verification Method
- Examine `test/features/combat_analyzer/fixtures/merlin_combat_log.txt` to verify the tag structures.
- A future implementer will write `test/features/combat_analyzer/log_parser_test.dart`. This test must pass the fixture text through the parser and verify that:
  - `characterName` is `"Test Character"`.
  - HTML tags are completely removed from `rawFilteredLog`.
  - `totalDamageDealt` equals 525.
  - `totalDamageReceived` equals 457.
  - Repetitive lines (like the "misses you completely" at 18:32:10 and 18:32:25) are aggregated in the `rawFilteredLog` if a suitable time-window compression is used.
