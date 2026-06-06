# Handoff Report: Combat Log Analysis & Parsing Strategy

## 1. Observation
- The example log at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt` contains a header with `Listener: Test Character` and `Session Started: YYYY.MM.DD HH:mm:ss`.
- Combat lines start with a timestamp: `[ 2026.05.20 18:32:10 ] (combat)`.
- Miss events are plain text: `[ ... ] (combat) State Protector Merlin misses you completely - Light Electron Blaster I`.
- Damage events are heavily bloated with HTML tags: `[ ... ] (combat) <color=0xff00ffff><b>42</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>State Protector Merlin</color></b><font size=10><color=0x77ffffff> - Light Electron Blaster I - Grazes</color></font>`.
- The damage amount is wrapped in `<b>...</b>` right after the first color tag.
- The direction is `from` or `to` wrapped in `<font...>` tags.
- The source/target is wrapped in nested `<b><color...>` tags.
- The weapon and hit quality (e.g., "Grazes", "Penetrates") are trailing in the string.
- Non-damage actions (e.g., `Warp drive active`) are plain text without HTML.

## 2. Logic Chain
1. **Log Identity (Listener):** The log parser must identify the character by looking for `^Listener:\s+(.+)$` in the header. This directly maps the log to a character in Mimir.
2. **Metric Extraction via Regex:** To satisfy the requirement of extracting total damage dealt/received, we must parse the damage lines specifically.
   - Regex pattern: `<b>(\d+)<\/b>.*?>(from|to)<.*?<color[^>]*>([^<]+)<\/color><\/b>.*?-\s*(.+?)\s*-\s*([^<]+)<\/color>`
   - This reliably captures: Amount (`$1`), Direction (`$2`), Entity (`$3`), Weapon (`$4`), and Hit Quality (`$5`).
   - Summing amounts where direction is `to` yields `totalDamageDealt`.
   - Summing amounts where direction is `from` yields `totalDamageReceived`.
3. **Token Optimization:**
   - **HTML Stripping:** The raw HTML adds ~150-200 unnecessary characters per line. Applying a global HTML stripper (`replaceAll(RegExp(r'<[^>]*>'), '')`) reduces a line to plain text: `42 from State Protector Merlin - Light Electron Blaster I - Grazes`.
   - **Event Compression:** Repeating identical events (like drone misses or rapid-fire small weapons) can be summarized. A simple Run-Length Encoding (RLE) buffer can squash identical events within a 10-second window into: `[18:32:10 - 18:32:25] 2x State Protector Merlin misses you completely - Light Electron Blaster I`.
4. **Data Modeling (`CombatEncounter`):**
   - The parsed result should be a `CombatEncounter` struct holding `characterName`, `startTime`, `endTime`, `totalDamageDealt`, `totalDamageReceived`, and the `rawFilteredLog` (the plain-text, token-optimized string for the LLM).
   - An encounter boundary can be defined by a significant gap in time (e.g., > 2 minutes without combat logs) since a single local log file can span an entire day.

## 3. Caveats
- The analysis was performed on a sample showing damage and misses. EWAR actions (Stasis Webifiers, Warp Scramblers, Energy Neutralizers) have different text formats. The parser needs a fallback rule: if a line does not match the damage or miss regex, it should just strip HTML tags and include the plain text in the LLM payload.
- We assume EVE logs use UTC time (`YYYY.MM.DD HH:mm:ss`), which must be parsed accurately into Dart `DateTime` objects.

## 4. Conclusion
The combat log parser should be implemented as a two-stage pipeline:
1. **Extraction:** A line-by-line Regex parser that pulls metrics (damage sums) and timestamps to build `CombatEncounter` metadata.
2. **Optimization:** A formatting pass that strips HTML tags from all lines and buffers consecutive identical events (ignoring timestamps/damage numbers, matching on entity, weapon, and event type) to output a highly compressed `rawFilteredLog` payload suitable for LLM ingestion.

## 5. Verification Method
- Implement the parsing logic in `lib/features/combat_analyzer/data/log_parser.dart`.
- Create a test `test/features/combat_analyzer/log_parser_test.dart` using the `merlin_combat_log.txt` fixture.
- Assert that:
  - `Listener` resolves to "Test Character".
  - `totalDamageDealt` exactly equals 525.
  - `totalDamageReceived` exactly equals 457.
  - `rawFilteredLog` contains zero HTML brackets (`<` or `>`) and is significantly smaller in character count than the original raw text.
