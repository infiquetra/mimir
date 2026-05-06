import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/logger.dart';
import 'planetary_repository.dart';
import 'planetary_sync_service.dart';

/// Provider for the list of colonies for a specific character.
final coloniesProvider = StreamProvider.family<List<PlanetaryColony>, int>((ref, characterId) {
  final repository = ref.watch(planetaryRepositoryProvider);
  return repository.watchColonies(characterId);
});

/// Provider for the list of all colonies across all characters.
final allColoniesProvider = StreamProvider<List<PlanetaryColony>>((ref) {
  final repository = ref.watch(planetaryRepositoryProvider);
  return repository.watchAllColonies();
});

/// Provider for the list of pins for a specific planet.
final planetPinsProvider = StreamProvider.family<List<PlanetaryPin>, PlanetPinsArgs>((ref, args) {
  final repository = ref.watch(planetaryRepositoryProvider);
  return repository.watchPins(args.characterId, args.planetId);
});

/// Arguments for the planetPinsProvider.
class PlanetPinsArgs {
  final int characterId;
  final int planetId;

  const PlanetPinsArgs({required this.characterId, required this.planetId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanetPinsArgs &&
          runtimeType == other.runtimeType &&
          characterId == other.characterId &&
          planetId == other.planetId;

  @override
  int get hashCode => characterId.hashCode ^ planetId.hashCode;
}

/// Provider for the PI sync state.
final piSyncProvider = AsyncNotifierProvider<PiSyncNotifier, void>(() {
  return PiSyncNotifier();
});

class PiSyncNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() => null;

  Future<void> sync(int characterId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final syncService = ref.read(planetarySyncServiceProvider);
      await syncService.syncColonies(characterId);
    });
  }
}
