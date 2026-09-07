import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/database/app_database.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/core/network/esi_client.dart' as esi;
import 'package:mimir/features/intel/data/intel_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockEsiClient extends Mock implements esi.EsiClient {}

void main() {
  late AppDatabase database;
  late MockEsiClient mockEsiClient;
  late ProviderContainer container;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockEsiClient = MockEsiClient();

    await database.into(database.universeNames).insert(
      UniverseNamesCompanion.insert(
        id: const drift.Value(30000142),
        name: 'Jita',
        category: 'solar_system',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        esi.esiClientProvider.overrideWithValue(mockEsiClient),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('solarSystemByNameProvider', () {
    test('serves the cached universe name without touching ESI', () async {
      final resolved = await container.read(
        solarSystemByNameProvider('jita').future,
      );

      expect(resolved?.id, 30000142);
      expect(resolved?.name, 'Jita');
      verifyNever(() => mockEsiClient.resolveSolarSystemByName(any()));
    });

    test('falls back to ESI when the name is not cached', () async {
      when(() => mockEsiClient.resolveSolarSystemByName('Amarr')).thenAnswer(
        (_) async => esi.EsiUniverseName(
          id: 30002187,
          name: 'Amarr',
          category: 'solar_system',
        ),
      );

      final resolved = await container.read(
        solarSystemByNameProvider('Amarr').future,
      );

      expect(resolved?.id, 30002187);
      verify(() => mockEsiClient.resolveSolarSystemByName('Amarr')).called(1);
    });

    test('returns null when neither the cache nor ESI knows the name', () async {
      when(
        () => mockEsiClient.resolveSolarSystemByName(any()),
      ).thenAnswer((_) async => null);

      final resolved = await container.read(
        solarSystemByNameProvider('Not A System').future,
      );

      expect(resolved, isNull);
    });
  });
}
