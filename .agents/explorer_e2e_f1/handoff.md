# Handoff Report: E2E Testing Track (F1)

## 1. Observation
- The goal is to design E2E/Unit tests for **F1: Automatic discovery/scanning of combat log directory** according to `TEST_INFRA.md` (5 Tier 1, 5 Tier 2 tests).
- `ORIGINAL_REQUEST.md` states: "The tool must automatically locate and scan the standard EVE local combat log directory" and "Parse the `Listener: [Name]` header".
- An existing example combat log resides at `test/features/combat_analyzer/fixtures/merlin_combat_log.txt`.
- The instructions require defining exactly what to write in `integration_test/test_utils/fixtures/combat_log_fixtures.dart` and the test files.

## 2. Logic Chain
- To achieve robust Test-Driven Development, we must define the `CombatLogFixtures` containing static strings of different log permutations (valid, missing listener, invalid). This avoids cross-environment file-loading issues in `integration_test`.
- The `CombatLogScanner` (to be implemented) should handle scanning a given `Directory`.
- **Tier 1 (Happy Path)** tests need to prove the scanner can find a single file, multiple files, ignore non-`.txt` files, extract the `Listener` correctly, and read the content.
- **Tier 2 (Error Path)** tests need to prove the scanner handles non-existent directories, empty directories, directories with only wrong file types, logs without a `Listener` header, and completely empty/invalid text files gracefully without throwing unhandled exceptions.

## 3. Caveats
- Since this is TDD, the implementation (`CombatLogScanner` and `CombatLogFile`) does not exist yet. The test file provides a mock interface that the Implementer must build to make the tests pass.
- Flutter's `dart:io` `Directory.systemTemp` is used to mock the file system temporarily, ensuring tests run isolated and fast.

## 4. Conclusion
The Worker should execute the following exact steps:

### Step 1: Create `integration_test/test_utils/fixtures/combat_log_fixtures.dart`
Create the file with the following content:

```dart
class CombatLogFixtures {
  static const String merlinLog = '''
---------------------------------------------------------------
  Combat Log - 2026.05.20 18:30:00
---------------------------------------------------------------
Listener: Test Character
Session Started: 2026.05.20 18:30:00
---------------------------------------------------------------

[ 2026.05.20 18:32:10 ] (combat) State Protector Merlin misses you completely - Light Electron Blaster I
[ 2026.05.20 18:32:12 ] (combat) <color=0xff00ffff><b>42</b> <color=0x77ffffff><font size=10>from</font> <b><color=0xffffffff>State Protector Merlin</color></b><font size=10><color=0x77ffffff> - Light Electron Blaster I - Grazes</color></font>
''';

  static const String altLog = '''
---------------------------------------------------------------
  Combat Log - 2026.05.21 19:00:00
---------------------------------------------------------------
Listener: Alt Character
Session Started: 2026.05.21 19:00:00
---------------------------------------------------------------

[ 2026.05.21 19:02:10 ] (combat) Warrior II misses you completely
''';

  static const String noListenerLog = '''
---------------------------------------------------------------
  Combat Log - 2026.05.20 18:30:00
---------------------------------------------------------------
Session Started: 2026.05.20 18:30:00
---------------------------------------------------------------
[ 2026.05.20 18:32:10 ] (combat) State Protector Merlin misses you completely
''';

  static const String invalidFormatLog = '''
This is just a random text file.
It is not a combat log.
''';

  static const String emptyLog = '';
}
```

### Step 2: Create Test File `test/features/combat_analyzer/data/combat_log_scanner_test.dart`
Write the following test definitions, anticipating the `CombatLogScanner` and `CombatLogFile` models.

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
// Note: Implementer must create these models/classes in lib/features/combat_analyzer/data/
import 'package:mimir/features/combat_analyzer/data/combat_log_scanner.dart';
import '../../../../integration_test/test_utils/fixtures/combat_log_fixtures.dart';

void main() {
  late Directory tempDir;
  late CombatLogScanner scanner;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mimir_combat_log_tests_');
    scanner = CombatLogScanner(directoryPath: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('F1 Tier 1: Happy Path / Equivalence Class', () {
    test('1. Discovers a single valid combat log file', () async {
      final file = File('${tempDir.path}/20260520_183000.txt');
      await file.writeAsString(CombatLogFixtures.merlinLog);

      final logs = await scanner.scanDirectory();

      expect(logs.length, 1);
      expect(logs.first.characterName, 'Test Character');
      expect(logs.first.filePath, file.path);
    });

    test('2. Discovers multiple valid combat log files', () async {
      await File('${tempDir.path}/log1.txt').writeAsString(CombatLogFixtures.merlinLog);
      await File('${tempDir.path}/log2.txt').writeAsString(CombatLogFixtures.altLog);

      final logs = await scanner.scanDirectory();

      expect(logs.length, 2);
      final names = logs.map((l) => l.characterName).toSet();
      expect(names, containsAll(['Test Character', 'Alt Character']));
    });

    test('3. Ignores files that do not end with .txt', () async {
      await File('${tempDir.path}/log1.txt').writeAsString(CombatLogFixtures.merlinLog);
      await File('${tempDir.path}/log2.log').writeAsString(CombatLogFixtures.merlinLog);
      await File('${tempDir.path}/image.png').writeAsString('fake image');

      final logs = await scanner.scanDirectory();

      expect(logs.length, 1);
      expect(logs.first.filePath, endsWith('.txt'));
    });

    test('4. Correctly extracts the Listener header from the log', () async {
      await File('${tempDir.path}/log1.txt').writeAsString(CombatLogFixtures.merlinLog);

      final logs = await scanner.scanDirectory();

      expect(logs.first.characterName, 'Test Character');
    });

    test('5. Correctly reads the entire file content into the object', () async {
      await File('${tempDir.path}/log1.txt').writeAsString(CombatLogFixtures.merlinLog);

      final logs = await scanner.scanDirectory();

      expect(logs.first.content, CombatLogFixtures.merlinLog);
    });
  });

  group('F1 Tier 2: Error / Boundary Value', () {
    test('1. Handles non-existent directory gracefully (returns empty list)', () async {
      final missingDirScanner = CombatLogScanner(directoryPath: '${tempDir.path}/does_not_exist');
      
      final logs = await missingDirScanner.scanDirectory();

      expect(logs, isEmpty);
    });

    test('2. Handles an empty directory gracefully (returns empty list)', () async {
      final logs = await scanner.scanDirectory();

      expect(logs, isEmpty);
    });

    test('3. Handles a directory with only invalid file extensions', () async {
      await File('${tempDir.path}/log1.log').writeAsString(CombatLogFixtures.merlinLog);
      await File('${tempDir.path}/data.csv').writeAsString('a,b,c');

      final logs = await scanner.scanDirectory();

      expect(logs, isEmpty);
    });

    test('4. Skips log files that are missing the Listener header', () async {
      await File('${tempDir.path}/no_listener.txt').writeAsString(CombatLogFixtures.noListenerLog);

      final logs = await scanner.scanDirectory();

      expect(logs, isEmpty);
    });

    test('5. Skips files that are completely empty or unformatted', () async {
      await File('${tempDir.path}/empty.txt').writeAsString(CombatLogFixtures.emptyLog);
      await File('${tempDir.path}/invalid.txt').writeAsString(CombatLogFixtures.invalidFormatLog);

      final logs = await scanner.scanDirectory();

      expect(logs, isEmpty);
    });
  });
}
```

## 5. Verification Method
- After implementing `CombatLogScanner` to satisfy the API, verify by running:
  `flutter test test/features/combat_analyzer/data/combat_log_scanner_test.dart`
- Tests should all pass (10/10).
