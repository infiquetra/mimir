// C7 RED: real selector, generation bump, transient reset.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/features/corporation/presentation/corporation_character_selector.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';
import '../data/corporation_schema_support.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await seedSentinelCharacter(database, characterId: kAdaId, name: 'Ada');
    await seedSentinelCharacter(database, characterId: kCyraId, name: 'Cyra');
    await database.selectCharacterWithRevision(kAdaId);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'select delegates to selectCharacterWithRevision and bumps generation',
    () async {
      final controller = CorporationCharacterSelectorController(database)
        ..transientFilter = 'ammo';
      await controller.select(kCyraId);
      final row = await database
          .customSelect(
            '''
          SELECT selected_character_id, context_generation, selection_revision
          FROM corporation_context_states WHERE tenant = ?
          ''',
            variables: [Variable.withString('tranquility')],
          )
          .getSingle();
      expect(row.read<int>('selected_character_id'), kCyraId);
      expect(row.read<int>('context_generation'), 2);
      expect(row.read<int>('selection_revision'), 2);
      final active = await database
          .customSelect(
            'SELECT character_id FROM characters WHERE is_active = 1',
          )
          .getSingle();
      expect(active.read<int>('character_id'), kCyraId);
    },
  );

  test('selection resets view-local transient state', () async {
    final controller = CorporationCharacterSelectorController(database)
      ..transientFilter = 'ammo';
    await controller.select(kCyraId);
    expect(controller.transientFilter, isEmpty);
  });

  testWidgets('tapping Cyra invokes onSelected', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CorporationCharacterSelector(
            characters: const [
              CorporationCharacterOption(id: kAdaId, name: 'Ada'),
              CorporationCharacterOption(id: kCyraId, name: 'Cyra'),
            ],
            activeId: kAdaId,
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Cyra'), findsOneWidget);
    await tester.tap(find.text('Cyra'));
    await tester.pump();
    expect(selected, kCyraId);
    expect(find.text('Chars'), findsNothing);
  });
}
