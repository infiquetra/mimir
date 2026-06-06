import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/combat_analyzer/data/parsed_encounter_cache.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';

void main() {
  group('ParsedEncounterCache', () {
    late Directory tempDir;
    late AppDatabase database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mimir_parse_cache_');
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loads cached parsed encounters for unchanged files', () async {
      final file = File('${tempDir.path}/20260520_120000.txt');
      await file.writeAsString(_combatLogContent(damage: 100));
      final cache = ParsedEncounterCache(database);
      final encounters = await CombatLogParser.parseFile(file);

      await cache.saveForFile(file, encounters);

      final cached = await cache.loadValidForFile(file);

      expect(cached, isNotNull);
      expect(cached, hasLength(1));
      expect(cached!.single.totalDamageDealt, 100);
      expect(cached.single.id, encounters.single.id);
    });

    test(
      'invalidates cached parsed encounters when file fingerprint changes',
      () async {
        final file = File('${tempDir.path}/20260520_120000.txt');
        await file.writeAsString(_combatLogContent(damage: 100));
        final cache = ParsedEncounterCache(database);
        final encounters = await CombatLogParser.parseFile(file);
        await cache.saveForFile(file, encounters);

        await file.writeAsString(_combatLogContent(damage: 1000));

        final cached = await cache.loadValidForFile(file);

        expect(cached, isNull);
      },
    );
  });
}

String _combatLogContent({required int damage}) =>
    '''
Listener: Pilot
[ 2026.05.20 12:00:00 ] (combat) $damage to Enemy - Railgun - Hits
''';
