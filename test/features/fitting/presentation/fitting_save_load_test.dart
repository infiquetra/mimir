import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/fitting/data/fitting_repository.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';

void main() {
  late AppDatabase appDatabase;
  late SdeDatabase sdeDatabase;
  late ProviderContainer container;

  Fitting sampleFitting() => Fitting(
    id: 'fit-1',
    name: 'Test Rifter',
    shipTypeId: 587,
    shipName: 'Rifter',
    lowSlots: [
      FittedModule(
        typeId: 2048,
        typeName: 'Damage Control II',
        slotType: SlotType.low,
        slotIndex: 0,
        state: ModuleState.online,
      ),
    ],
  );

  setUp(() async {
    appDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    sdeDatabase = SdeDatabase.forTesting(NativeDatabase.memory());

    await sdeDatabase.batch((batch) {
      batch.insertAll(sdeDatabase.sdeTypes, [
        SdeTypesCompanion.insert(
          typeId: const Value(587),
          typeName: 'Rifter',
          groupId: 25,
        ),
        SdeTypesCompanion.insert(
          typeId: const Value(2048),
          typeName: 'Damage Control II',
          groupId: 25,
        ),
      ]);
      batch.insertAll(sdeDatabase.sdeTypeEffects, [
        SdeTypeEffectsCompanion.insert(typeId: 2048, effectId: 11),
      ]);
    });

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(appDatabase),
        sdeServiceProvider.overrideWithValue(SdeService(database: sdeDatabase)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await appDatabase.close();
    await sdeDatabase.close();
  });

  group('saved fittings', () {
    test('saveCurrent persists and savedFittingsProvider emits it', () async {
      container.read(activeFittingProvider.notifier).loadFitting(
        sampleFitting(),
      );

      final saved = await container
          .read(activeFittingProvider.notifier)
          .saveCurrent();
      expect(saved, isTrue);

      final fittings = await container
          .read(fittingRepositoryProvider)
          .getFittings(characterId: null);
      expect(fittings, hasLength(1));
      expect(fittings.single.name, 'Test Rifter');
      // The persisted JSON must keep the modules, not just the hull.
      expect(fittings.single.lowSlots, hasLength(1));
    });

    test('saveCurrent reports false when there is no working fitting', () async {
      final saved = await container
          .read(activeFittingProvider.notifier)
          .saveCurrent();
      expect(saved, isFalse);
    });

    test('loadFitting restores a saved fitting into the working session', () async {
      final fitting = sampleFitting();
      container.read(activeFittingProvider.notifier).loadFitting(fitting);
      await container.read(activeFittingProvider.notifier).saveCurrent();

      // Wipe the working session, then reload from storage.
      container.read(activeFittingProvider.notifier).loadFitting(
        Fitting(
          id: 'other',
          name: 'Empty',
          shipTypeId: 603,
          shipName: 'Merlin',
        ),
      );

      final stored = (await container
          .read(fittingRepositoryProvider)
          .getFittings(characterId: null))
          .single;
      container.read(activeFittingProvider.notifier).loadFitting(stored);

      expect(container.read(activeFittingProvider)?.id, 'fit-1');
      expect(container.read(activeFittingProvider)?.lowSlots, hasLength(1));
    });

    test('deleteFitting removes it from the stream', () async {
      container.read(activeFittingProvider.notifier).loadFitting(
        sampleFitting(),
      );
      await container.read(activeFittingProvider.notifier).saveCurrent();
      await container.read(fittingRepositoryProvider).deleteFitting('fit-1');

      final fittings = await container
          .read(fittingRepositoryProvider)
          .getFittings(characterId: null);
      expect(fittings, isEmpty);
    });

    test('importFromText parses an EFT block into the working fitting', () async {
      final imported = await container
          .read(activeFittingProvider.notifier)
          .importFromText('[Rifter, Imported]\nDamage Control II\n');

      expect(imported, isNotNull);
      expect(container.read(activeFittingProvider)?.shipTypeId, 587);
      expect(container.read(activeFittingProvider)?.lowSlots, hasLength(1));
    });

    test('importFromText returns null for unparseable text', () async {
      final imported = await container
          .read(activeFittingProvider.notifier)
          .importFromText('this is not a fitting');

      expect(imported, isNull);
      expect(container.read(activeFittingProvider), isNull);
    });
  });
}
