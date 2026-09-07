import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/features/fitting/domain/models.dart';
import 'package:mimir/features/fitting/presentation/fitting_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../integration_test/test_utils/fixtures/character_fixtures.dart';

class MockEsiClient extends Mock implements EsiClient {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<Map<String, dynamic>>[]);
  });

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.characters)
        .insert(CharacterFixtures.testCharacter());
    mockEsiClient = MockEsiClient();
    when(
      () => mockEsiClient.saveFittingToEve(
        any(),
        name: any(named: 'name'),
        description: any(named: 'description'),
        shipTypeId: any(named: 'shipTypeId'),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        esiClientProvider.overrideWithValue(mockEsiClient),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('saveCurrentToEve', () {
    test('sends the mapped fitting to ESI for the active character', () async {
      container
          .read(activeFittingProvider.notifier)
          .loadFitting(
            Fitting(
              id: 'f',
              name: 'My Rifter',
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
            ),
          );

      final export = await container
          .read(activeFittingProvider.notifier)
          .saveCurrentToEve();

      expect(export.items, hasLength(1));
      verify(
        () => mockEsiClient.saveFittingToEve(
          CharacterFixtures.testCharacter().characterId.value,
          name: 'My Rifter',
          description: 'Saved from Mimir',
          shipTypeId: 587,
          items: any(named: 'items'),
        ),
      ).called(1);
    });

    test('truncates names to the 50 characters ESI accepts', () async {
      final longName = 'A' * 80;
      container
          .read(activeFittingProvider.notifier)
          .loadFitting(
            Fitting(
              id: 'f',
              name: longName,
              shipTypeId: 587,
              shipName: 'Rifter',
            ),
          );

      await container.read(activeFittingProvider.notifier).saveCurrentToEve();

      verify(
        () => mockEsiClient.saveFittingToEve(
          any(),
          name: 'A' * 50,
          description: any(named: 'description'),
          shipTypeId: 587,
          items: any(named: 'items'),
        ),
      ).called(1);
    });

    test('refuses to call ESI when there is no working fitting', () async {
      await expectLater(
        container.read(activeFittingProvider.notifier).saveCurrentToEve(),
        throwsA(isA<StateError>()),
      );
      verifyNever(
        () => mockEsiClient.saveFittingToEve(
          any(),
          name: any(named: 'name'),
          description: any(named: 'description'),
          shipTypeId: any(named: 'shipTypeId'),
          items: any(named: 'items'),
        ),
      );
    });
  });
}
