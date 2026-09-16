// C1 RED contracts for millisecond columns, TEXT money, and uniqueness.
// Naive schema uses REAL balances and allows duplicate members.
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
  });

  tearDown(() async {
    await database.close();
  });

  Matcher isConstraintFailure() {
    return predicate((Object? error) {
      final text = error.toString().toLowerCase();
      return text.contains('unique') ||
          text.contains('constraint') ||
          text.contains('2067');
    }, 'a unique constraint failure');
  }

  group('millisecond columns', () {
    test('lease_until_ms and occurred_at_ms round-trip exact UTC ms', () async {
      expect(
        await corporationTableExists(
          database,
          CorporationTableNames.corporationWalletJournal,
        ),
        isTrue,
      );
      expect(
        await corporationTableExists(
          database,
          CorporationTableNames.corporationCapabilities,
        ),
        isTrue,
      );
      final instant = kCorporationT0.add(const Duration(milliseconds: 123));
      await database.customStatement(
        '''
        INSERT INTO corporation_wallet_journal (
          owner_key, journal_key, owner_character_id, amount, occurred_at_ms
        ) VALUES ('ada/2', '101', ?, 100.10, ?)
        ''',
        [kAdaId, instant.millisecondsSinceEpoch],
      );
      await database.customStatement(
        '''
        INSERT INTO corporation_capabilities (
          owner_key, owner_character_id, capability, endpoint_until_ms
        ) VALUES ('ada/wallets', ?, 'wallets', ?)
        ''',
        [kAdaId, instant.millisecondsSinceEpoch],
      );
      final journal = await database
          .customSelect(
            'SELECT occurred_at_ms FROM corporation_wallet_journal WHERE journal_key = ?',
            variables: [Variable.withString('101')],
          )
          .getSingle();
      final capability = await database
          .customSelect(
            'SELECT endpoint_until_ms FROM corporation_capabilities WHERE owner_key = ?',
            variables: [Variable.withString('ada/wallets')],
          )
          .getSingle();
      expect(
        journal.read<int>('occurred_at_ms'),
        instant.millisecondsSinceEpoch,
      );
      expect(
        capability.read<int>('endpoint_until_ms'),
        instant.millisecondsSinceEpoch,
      );
      final restored = DateTime.fromMillisecondsSinceEpoch(
        journal.read<int>('occurred_at_ms'),
        isUtc: true,
      );
      expect(restored.millisecond, 123);
      expect(restored, instant);
    });
  });

  group('money storage', () {
    test('balance and amount columns are TEXT, not REAL', () async {
      final balanceTypes = await columnTypes(
        database,
        CorporationTableNames.corporationWalletBalances,
      );
      final journalTypes = await columnTypes(
        database,
        CorporationTableNames.corporationWalletJournal,
      );
      final priceTypes = await columnTypes(
        database,
        CorporationTableNames.exactMarketPrices,
      );
      expect(balanceTypes['balance']?.toUpperCase(), 'TEXT');
      expect(journalTypes['amount']?.toUpperCase(), 'TEXT');
      expect(priceTypes['average_price']?.toUpperCase(), 'TEXT');
    });

    test('nullable amounts stay null, not zero', () async {
      await database.customStatement(
        '''
        INSERT INTO corporation_wallet_journal (
          owner_key, journal_key, owner_character_id, occurred_at_ms
        ) VALUES ('ada/2', '105', ?, ?)
        ''',
        [kAdaId, kCorporationT0.millisecondsSinceEpoch],
      );
      final row = await database
          .customSelect(
            'SELECT amount FROM corporation_wallet_journal WHERE journal_key = ?',
            variables: [Variable.withString('105')],
          )
          .getSingle();
      expect(row.data['amount'], isNull);
    });
  });

  group('primary keys and uniqueness', () {
    test('duplicate roster members in one snapshot are rejected', () async {
      expect(
        await corporationTableExists(
          database,
          CorporationTableNames.corporationMembers,
        ),
        isTrue,
      );
      await database.customStatement(
        'INSERT INTO corporation_members (snapshot_id, member_id) VALUES (?, ?)',
        ['snap-1', kAdaId],
      );
      await expectLater(
        database.customStatement(
          'INSERT INTO corporation_members (snapshot_id, member_id) VALUES (?, ?)',
          ['snap-1', kAdaId],
        ),
        throwsA(isConstraintFailure()),
      );
    });

    test('every §2.2 table is present', () async {
      for (final name in CorporationTableNames.all) {
        expect(
          await corporationTableExists(database, name),
          isTrue,
          reason: name,
        );
      }
    });
  });
}
