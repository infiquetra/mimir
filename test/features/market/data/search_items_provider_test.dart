import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart' as esi;
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_providers.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/market/data/market_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements esi.EsiClient {}

class MockSdeService extends Mock implements SdeService {}

void main() {
  late SdeDatabase sdeDatabase;
  late MockEsiClient mockEsiClient;
  late MockSdeService mockSdeService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() async {
    sdeDatabase = SdeDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();
    mockSdeService = MockSdeService();

    when(() => mockSdeService.database).thenReturn(sdeDatabase);
    when(() => mockSdeService.initialize()).thenAnswer((_) async {});

    await sdeDatabase.batch((batch) {
      batch.insertAll(sdeDatabase.sdeTypes, [
        SdeTypesCompanion.insert(
          typeId: const drift.Value(587),
          typeName: 'Rifter',
          groupId: 25,
        ),
        SdeTypesCompanion.insert(
          typeId: const drift.Value(603),
          typeName: 'Merlin',
          groupId: 25,
        ),
        SdeTypesCompanion.insert(
          typeId: const drift.Value(1150),
          typeName: 'Merlin Prime',
          groupId: 25,
        ),
      ]);
    });

    container = ProviderContainer(
      overrides: [
        sdeServiceProvider.overrideWithValue(mockSdeService),
        esi.esiClientProvider.overrideWithValue(mockEsiClient),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await sdeDatabase.close();
  });

  group('searchItemsProvider', () {
    test(
      'returns bundled SDE substring matches when ESI is unavailable',
      () async {
        when(
          () => mockEsiClient.resolveInventoryTypesByName(any()),
        ).thenThrow(Exception('offline'));

        final results = await container.read(searchItemsProvider('mer').future);

        expect(results.map((i) => i.name), ['Merlin', 'Merlin Prime']);
        expect(results.map((i) => i.typeId), [603, 1150]);
      },
    );

    test('merges an exact ESI hit the bundled SDE does not contain', () async {
      when(
        () => mockEsiClient.resolveInventoryTypesByName(['Tritanium']),
      ).thenAnswer(
        (_) async => [
          esi.EsiUniverseName(
            id: 34,
            name: 'Tritanium',
            category: 'inventory_type',
          ),
        ],
      );

      final results = await container.read(
        searchItemsProvider('Tritanium').future,
      );

      expect(results, hasLength(1));
      expect(results.single.typeId, 34);
      expect(results.single.name, 'Tritanium');
    });

    test('deduplicates when the SDE and ESI agree', () async {
      when(
        () => mockEsiClient.resolveInventoryTypesByName(['Merlin']),
      ).thenAnswer(
        (_) async => [
          esi.EsiUniverseName(
            id: 603,
            name: 'Merlin',
            category: 'inventory_type',
          ),
        ],
      );

      final results = await container.read(
        searchItemsProvider('Merlin').future,
      );

      // SDE substring match yields Merlin and Merlin Prime; the ESI exact hit
      // for 603 must not add a second copy of it.
      expect(results.map((i) => i.typeId), [603, 1150]);
    });

    test('does not search for queries shorter than three characters', () async {
      final results = await container.read(searchItemsProvider('me').future);

      expect(results, isEmpty);
      verifyNever(() => mockEsiClient.resolveInventoryTypesByName(any()));
    });
  });
}
