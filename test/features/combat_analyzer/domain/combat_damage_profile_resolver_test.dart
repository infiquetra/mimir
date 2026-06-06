import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';

void main() {
  group('CombatDamageProfileResolver', () {
    late SdeDatabase database;

    setUp(() {
      database = SdeDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('resolves exact SDE damage attributes by weapon name', () async {
      await database
          .into(database.sdeTypes)
          .insert(
            SdeTypesCompanion.insert(
              typeId: const Value(2456),
              typeName: 'Hobgoblin II',
              groupId: 100,
            ),
          );
      await database
          .into(database.sdeTypeAttributes)
          .insert(
            SdeTypeAttributesCompanion.insert(
              typeId: 2456,
              attributeId: CombatDamageProfileResolver.thermalDamageAttribute,
              value: 20,
            ),
          );
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Hobgoblin II - Hits',
        '[ 2026.05.20 20:00:01 ] (combat) 50 to Enemy - Unknown Blaster - Hits',
      ]).single;

      final resolver = CombatDamageProfileResolver(database: database);
      final profile = await resolver.resolveOutgoingProfile(encounter);

      expect(profile.entries, hasLength(1));
      expect(profile.entries.single.type, 'Thermal');
      expect(profile.entries.single.amount, 100);
      expect(profile.entries.single.percent, 1.0);
      expect(profile.unknownWeapons, ['Unknown Blaster']);
    });
  });
}
