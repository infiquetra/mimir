import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';

void main() {
  group('CombatDamageProfileResolver incoming', () {
    late SdeDatabase database;

    setUp(() {
      database = SdeDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'T4.6-incoming Scourge Rocket is 100% Kinetic; Mystery Gun unknown; outgoing empty',
      () async {
        await database
            .into(database.sdeTypes)
            .insert(
              SdeTypesCompanion.insert(
                typeId: const Value(266),
                typeName: 'Scourge Rocket',
                groupId: 387,
              ),
            );
        await database
            .into(database.sdeTypeAttributes)
            .insert(
              SdeTypeAttributesCompanion.insert(
                typeId: 266,
                attributeId: CombatDamageProfileResolver.kineticDamageAttribute,
                value: 20,
              ),
            );

        final encounter = CombatLogParser.parseLines([
          'Listener: Pilot',
          '[ 2026.05.20 20:00:00 ] (combat) 100 from Enemy - Scourge Rocket - Hits',
          '[ 2026.05.20 20:00:01 ] (combat) 50 from Enemy - Mystery Gun - Hits',
        ]).single;

        final resolver = CombatDamageProfileResolver(database: database);
        final incoming = await resolver.resolveIncomingProfile(encounter);
        expect(incoming.entries, hasLength(1));
        expect(incoming.entries.single.type, 'Kinetic');
        expect(incoming.entries.single.percent, 1.0);
        expect(incoming.unknownWeapons, ['Mystery Gun']);

        final outgoing = await resolver.resolveOutgoingProfile(encounter);
        expect(outgoing.entries, isEmpty);
        expect(outgoing.unknownWeapons, isEmpty);
      },
    );
  });
}
