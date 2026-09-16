// C1 RED contracts for scoped corporation deletion and selection revision.
// Naive deleteCorporationPrivateOwner is a no-op; context generation is not
// bumped on selectCharacterWithRevision.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/corporation/data/corporation_tables.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';
import 'corporation_schema_support.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await createNaiveCorporationSchema(database);
    await seedSentinelCharacter(database, characterId: kAdaId, name: 'Ada');
    await seedSentinelCharacter(database, characterId: kCyraId, name: 'Cyra');
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertPrivateOwner({
    required int characterId,
    required String snapshotId,
  }) async {
    await database.customStatement(
      '''
      INSERT INTO character_authorization_states (
        tenant, character_id, incarnation, grant_epoch
      ) VALUES ('tranquility', ?, ?, 1)
      ''',
      [characterId, 'inc-$characterId'],
    );
    await database.customStatement(
      '''
      INSERT INTO corporation_wallet_balances (
        snapshot_id, division, owner_character_id, balance
      ) VALUES (?, 1, ?, 1000.10)
      ''',
      [snapshotId, characterId],
    );
    await database.customStatement(
      '''
      INSERT INTO corporation_capabilities (
        owner_key, owner_character_id, capability, endpoint_until_ms
      ) VALUES (?, ?, 'wallets', ?)
      ''',
      [
        'owner-$characterId',
        characterId,
        kCorporationT0.millisecondsSinceEpoch,
      ],
    );
  }

  group('P06/P19 scoped deletion', () {
    test(
      'deleteCorporationPrivateOwner removes that character and keeps others',
      () async {
        await insertPrivateOwner(characterId: kAdaId, snapshotId: 'snap-ada');
        await insertPrivateOwner(characterId: kCyraId, snapshotId: 'snap-cyra');
        await database.customStatement(
          '''
          INSERT INTO corporation_profiles (tenant, corporation_id, name)
          VALUES ('tranquility', ?, 'Helios Research')
          ''',
          [kHeliosId],
        );
        await database.customStatement('''
          INSERT INTO exact_market_prices (tenant, type_id, average_price)
          VALUES ('tranquility', 101, 2.50)
          ''');

        await database.deleteCorporationPrivateOwner(
          tenant: 'tranquility',
          characterId: kAdaId,
        );

        final adaAuth = await database
            .customSelect(
              'SELECT character_id FROM character_authorization_states WHERE character_id = ?',
              variables: [Variable.withInt(kAdaId)],
            )
            .get();
        final adaBalances = await database
            .customSelect(
              'SELECT snapshot_id FROM corporation_wallet_balances WHERE owner_character_id = ?',
              variables: [Variable.withInt(kAdaId)],
            )
            .get();
        final adaCaps = await database
            .customSelect(
              'SELECT owner_key FROM corporation_capabilities WHERE owner_character_id = ?',
              variables: [Variable.withInt(kAdaId)],
            )
            .get();
        final cyraAuth = await database
            .customSelect(
              'SELECT character_id FROM character_authorization_states WHERE character_id = ?',
              variables: [Variable.withInt(kCyraId)],
            )
            .get();
        final profiles = await database
            .customSelect(
              'SELECT name FROM corporation_profiles WHERE corporation_id = ?',
              variables: [Variable.withInt(kHeliosId)],
            )
            .get();
        final prices = await database
            .customSelect('SELECT type_id FROM exact_market_prices')
            .get();

        expect(adaAuth, isEmpty);
        expect(adaBalances, isEmpty);
        expect(adaCaps, isEmpty);
        expect(cyraAuth, hasLength(1));
        expect(profiles, hasLength(1));
        expect(prices, hasLength(1));
        expect(await database.getCharacter(kAdaId), isNotNull);
        expect(await database.getCharacter(kCyraId), isNotNull);
      },
    );

    test('selectCharacterWithRevision bumps context generation', () async {
      await database.customStatement(
        '''
        INSERT INTO corporation_context_states (
          tenant, selected_character_id, context_generation, selection_revision
        ) VALUES ('tranquility', ?, 1, 1)
        ''',
        [kAdaId],
      );
      await database.selectCharacterWithRevision(kCyraId);
      final row = await database
          .customSelect(
            'SELECT selected_character_id, context_generation, selection_revision FROM corporation_context_states WHERE tenant = ?',
            variables: [Variable.withString('tranquility')],
          )
          .getSingle();
      expect(row.read<int>('selected_character_id'), kCyraId);
      expect(row.read<int>('context_generation'), 2);
      expect(row.read<int>('selection_revision'), 2);
    });
  });

  group('table presence for deletion contracts', () {
    test('private and public corporation tables exist', () async {
      expect(
        await corporationTableExists(
          database,
          CorporationTableNames.characterAuthorizationStates,
        ),
        isTrue,
      );
      expect(
        await corporationTableExists(
          database,
          CorporationTableNames.corporationProfiles,
        ),
        isTrue,
      );
      expect(
        await corporationTableExists(
          database,
          CorporationTableNames.exactMarketPrices,
        ),
        isTrue,
      );
    });
  });
}
