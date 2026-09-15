import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/features/combat_analyzer/data/combat_damage_profile_resolver.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/incoming_damage_allocation.dart';

import '../fixtures/attacker_matchup_fixtures.dart';

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

  group('P06/P10 resolveIncomingAllocation', () {
    late _CountingSdeDatabase database;
    late CombatDamageProfileResolver resolver;

    setUp(() {
      database = _CountingSdeDatabase();
      resolver = CombatDamageProfileResolver(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> seedWeapon({
      required int typeId,
      required String name,
      required Map<int, double> damage,
    }) async {
      await database
          .into(database.sdeTypes)
          .insert(
            SdeTypesCompanion.insert(
              typeId: Value(typeId),
              typeName: name,
              groupId: 387,
            ),
          );
      for (final entry in damage.entries) {
        await database
            .into(database.sdeTypeAttributes)
            .insert(
              SdeTypeAttributesCompanion.insert(
                typeId: typeId,
                attributeId: entry.key,
                value: entry.value,
              ),
            );
      }
    }

    test('P10 one lookup per distinct normalized weapon per snapshot', () async {
      await seedWeapon(
        typeId: 266,
        name: 'Scourge Rocket',
        damage: {CombatDamageProfileResolver.kineticDamageAttribute: 20},
      );
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 from Alpha - Scourge Rocket - Hits',
        '[ 2026.05.20 20:00:01 ] (combat) 50 from Bravo - Scourge Rocket - Hits',
      ]).single;
      database.searches = 0;
      final result = await resolver.resolveIncomingAllocation(
        encounter,
        sdeContentKey: matchupSdeContentKey,
      );
      expect(result, isA<IncomingAllocationReady>());
      expect(database.searches, 1);
    });

    test('P06 per-weapon lookup failure leaves siblings typed', () async {
      await seedWeapon(
        typeId: 266,
        name: 'Scourge Rocket',
        damage: {CombatDamageProfileResolver.kineticDamageAttribute: 20},
      );
      await seedWeapon(
        typeId: 999,
        name: 'Broken Gun',
        damage: {CombatDamageProfileResolver.emDamageAttribute: 10},
      );
      database.failingTypeId = 999;
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 from Alpha - Scourge Rocket - Hits',
        '[ 2026.05.20 20:00:01 ] (combat) 40 from Alpha - Broken Gun - Hits',
      ]).single;
      final result = await resolver.resolveIncomingAllocation(
        encounter,
        sdeContentKey: matchupSdeContentKey,
      );
      expect(result, isA<IncomingAllocationReady>());
      final allocation = (result as IncomingAllocationReady).allocation;
      expect(allocation.resolvedDamage, 100);
      expect(allocation.untypedDamage, 40);
      expect(
        allocation.sources.single.weapons.any(
          (w) => w.resolution.status == WeaponResolutionStatus.lookupFailed,
        ),
        isTrue,
      );
    });

    test('P06 global SDE failure is a separate unavailable result', () async {
      database.failAllSearches = true;
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 from Alpha - Scourge Rocket - Hits',
      ]).single;
      expect(
        () => resolver.resolveIncomingAllocation(
          encounter,
          sdeContentKey: matchupSdeContentKey,
        ),
        throwsA(anything),
      );
    });

    test('unique exact-match lookup; duplicate names are ambiguous', () async {
      await seedWeapon(
        typeId: 1,
        name: 'Scourge Rocket',
        damage: {CombatDamageProfileResolver.kineticDamageAttribute: 20},
      );
      await seedWeapon(
        typeId: 2,
        name: 'Scourge Rocket',
        damage: {CombatDamageProfileResolver.emDamageAttribute: 20},
      );
      final encounter = CombatLogParser.parseLines([
        'Listener: Pilot',
        '[ 2026.05.20 20:00:00 ] (combat) 100 from Alpha - Scourge Rocket - Hits',
      ]).single;
      final result = await resolver.resolveIncomingAllocation(
        encounter,
        sdeContentKey: matchupSdeContentKey,
      );
      final allocation = (result as IncomingAllocationReady).allocation;
      expect(
        allocation.sources.single.weapons.single.resolution.status,
        WeaponResolutionStatus.ambiguousType,
      );
    });
  });
}

class _CountingSdeDatabase extends SdeDatabase {
  _CountingSdeDatabase() : super.forTesting(NativeDatabase.memory());

  int searches = 0;
  int? failingTypeId;
  bool failAllSearches = false;

  @override
  Future<List<SdeType>> searchTypesByName(String query, {int limit = 50}) {
    if (failAllSearches) {
      throw StateError('sde unavailable');
    }
    searches++;
    return super.searchTypesByName(query, limit: limit);
  }

  @override
  Future<Map<int, double>> getTypeAttributes(int typeId) {
    if (failingTypeId == typeId) {
      throw StateError('attribute lookup failed');
    }
    return super.getTypeAttributes(typeId);
  }
}
