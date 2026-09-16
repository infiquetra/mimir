import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/di/providers.dart';
import 'package:mimir/features/exploration/data/exploration_providers.dart'
    show eveScoutFeedRepositoryProvider, eveScoutTransportProvider;
import '../../../core/network/esi_client.dart';
import '../../characters/data/character_repository.dart';
import '../../exploration/domain/eve_scout_normalizer.dart';
import '../domain/killmail_models.dart';
import '../domain/thera_models.dart';
import 'eve_scout_client.dart';
import 'intel_repository.dart';
import 'zkillboard_client.dart';

export 'package:mimir/features/exploration/data/exploration_providers.dart'
    show eveScoutFeedRepositoryProvider, eveScoutTransportProvider;

final intelRepositoryProvider = Provider<IntelRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return IntelRepository(db);
});

final zkillboardClientProvider = Provider<ZKillboardClient>((ref) {
  final client = ZKillboardClient();
  ref.onDispose(() => client.dispose());
  return client;
});

// Stream of recent kills watched directly from the Drift database
final recentKillsProvider = StreamProvider.autoDispose<List<ZKillmail>>((ref) {
  final repo = ref.watch(intelRepositoryProvider);
  return repo.watchRecentKills(limit: 50);
});

// Provides the current watch list configuration from the database
final intelConfigProvider = StreamProvider.autoDispose<List<dynamic>>((ref) {
  final repo = ref.watch(intelRepositoryProvider);
  return repo.watchConfig();
});

final eveScoutClientProvider = Provider<EveScoutClient>((ref) {
  return EveScoutClient(
    transport: ref.watch(eveScoutTransportProvider),
    repository: ref.watch(eveScoutFeedRepositoryProvider),
  );
});

final theraConnectionsProvider =
    FutureProvider.autoDispose<List<TheraConnection>>((ref) async {
      final repository = ref.watch(eveScoutFeedRepositoryProvider);
      var snapshot = await repository.readAccepted();
      snapshot ??= await () async {
        await repository.refresh();
        return repository.readAccepted();
      }();
      if (snapshot == null) return const [];
      return [
        for (final connection in snapshot.records)
          if (connection.hub.systemId == EveScoutNormalizer.theraSystemId)
            TheraConnection(
              id: connection.providerKey,
              whType: connection.whType ?? '',
              maxShipSize: connection.shipSize.name,
              expiresAt:
                  connection.expiresAt ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
              remainingHours: 0,
              outSystemId: connection.hub.systemId,
              outSystemName: connection.hub.systemName,
              outSignature: connection.hub.signature ?? '',
              inSystemId: connection.far.systemId,
              inSystemClass: '',
              inSystemName: connection.far.systemName,
              inRegionId: 0,
              inRegionName: '',
              inSignature: connection.far.signature ?? '',
            ),
      ];
    });

/// Resolves a solar-system name to a watch-list target, offline-first: the
/// cached universe-name table, then ESI `POST /universe/ids/`.
///
/// The watch list used to accept only raw numeric system IDs and display them
/// verbatim — unusable, and against the project rule that EVE IDs are never
/// shown to users.
final solarSystemByNameProvider =
    FutureProvider.family<EsiUniverseName?, String>((ref, name) async {
      final db = ref.watch(databaseProvider);
      final cached =
          await (db.select(db.universeNames)
                ..where((u) => u.category.equals('solar_system'))
                ..where((u) => u.name.lower().equals(name.toLowerCase())))
              .get();
      if (cached.isNotEmpty) {
        return EsiUniverseName(
          id: cached.first.id,
          name: cached.first.name,
          category: 'solar_system',
        );
      }
      return ref.watch(esiClientProvider).resolveSolarSystemByName(name);
    });

/// Sets the running game client's autopilot destination.
///
/// Throws [EsiException]; statusCode 403 means the stored token predates
/// esi-ui.write_waypoint.v1 and the caller must ask the user to re-authorize.
final setDestinationProvider = FutureProvider.family<void, int>((
  ref,
  destinationId,
) async {
  final character = await ref
      .read(characterRepositoryProvider)
      .getActiveCharacter();
  if (character == null) {
    throw StateError('No active character');
  }
  await ref
      .read(esiClientProvider)
      .setAutopilotWaypoint(
        character.characterId,
        destinationId: destinationId,
      );
});
