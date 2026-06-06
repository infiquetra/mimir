import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/data/log_scanner.dart';

void main() {
  group('LogScanner', () {
    late Directory tempDir;
    late String configPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mimir_log_scanner_');
      configPath = '${tempDir.path}/combat_analyzer.json';
      await File(
        configPath,
      ).writeAsString(jsonEncode({'combat_log_directory': tempDir.path}));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('finds timestamped combat logs in a saved directory', () async {
      final logFile = File('${tempDir.path}/20260520_120000.txt');
      await logFile.writeAsString(_combatLogContent());
      final scanner = LogScanner(configFilePath: configPath);

      final logs = await scanner.getCombatLogs();

      expect(logs.map((file) => file.path), contains(logFile.path));
    });

    test('finds character-suffixed EVE gamelog files', () async {
      final logFile = File('${tempDir.path}/20260520_120000_92955167.txt');
      await logFile.writeAsString(_combatLogContent());
      final scanner = LogScanner(configFilePath: configPath);

      final logs = await scanner.getCombatLogs();

      expect(logs.map((file) => file.path), contains(logFile.path));
    });

    test('limits scan to newest gamelog files', () async {
      final olderLog = File('${tempDir.path}/20260519_120000.txt');
      final newerLog = File('${tempDir.path}/20260520_120000.txt');
      await olderLog.writeAsString(_combatLogContent());
      await newerLog.writeAsString(_combatLogContent());
      final scanner = LogScanner(configFilePath: configPath);

      final logs = await scanner.getCombatLogs(limit: 1);

      expect(logs.map((file) => file.path), [newerLog.path]);
    });

    test('returns empty list for an empty saved directory', () async {
      final scanner = LogScanner(configFilePath: configPath);

      final logs = await scanner.getCombatLogs();

      expect(logs, isEmpty);
    });

    test(
      'ignores files that do not match EVE gamelog timestamp format',
      () async {
        final validLog = File('${tempDir.path}/20260520_120000.txt');
        final invalidTxt = File('${tempDir.path}/notes.txt');
        final invalidExtension = File('${tempDir.path}/20260520_120000.log');
        final invalidSuffix = File('${tempDir.path}/20260520_120000_pilot.txt');
        await validLog.writeAsString(_combatLogContent());
        await invalidTxt.writeAsString('not a gamelog');
        await invalidExtension.writeAsString('not a txt gamelog');
        await invalidSuffix.writeAsString('not a numeric character id suffix');
        final scanner = LogScanner(configFilePath: configPath);

        final logs = await scanner.getCombatLogs();

        expect(logs.map((file) => file.path), [validLog.path]);
      },
    );

    test('filters timestamped gamelogs without combat damage', () async {
      final combatLog = File('${tempDir.path}/20260520_120000.txt');
      final nonCombatLog = File('${tempDir.path}/20260520_130000.txt');
      await combatLog.writeAsString(_combatLogContent());
      await nonCombatLog.writeAsString(_nonCombatLogContent());
      final scanner = LogScanner(configFilePath: configPath);

      final logs = await scanner.getCombatLogs();

      expect(logs.map((file) => file.path), [combatLog.path]);
      final config =
          jsonDecode(await File(configPath).readAsString())
              as Map<String, dynamic>;
      final cache = config['combat_log_cache'] as Map<String, dynamic>;
      expect(cache[combatLog.path]['is_combat'], isTrue);
      expect(cache[nonCombatLog.path]['is_combat'], isFalse);
    });

    test('rechecks cached gamelogs when file fingerprint changes', () async {
      final logFile = File('${tempDir.path}/20260520_120000.txt');
      await logFile.writeAsString(_nonCombatLogContent());
      final scanner = LogScanner(configFilePath: configPath);

      expect(await scanner.getCombatLogs(), isEmpty);

      await logFile.writeAsString(_combatLogContent());

      final logs = await scanner.getCombatLogs();

      expect(logs.map((file) => file.path), [logFile.path]);
    });
  });
}

String _combatLogContent() => '''
Listener: Pilot
[ 2026.05.20 12:00:00 ] (combat) 100 to Enemy - Railgun - Hits
''';

String _nonCombatLogContent() => '''
Listener: Pilot
[ 2026.05.20 12:00:00 ] redeeming and injecting 50000 Skill Points
''';
