import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../characters/data/character_providers.dart';
import 'industry_repository.dart';
import 'industry_sync_service.dart';

// --- Sync Providers ---

/// Provider to trigger a manual sync of all industry data.
final syncIndustryProvider = FutureProvider.autoDispose<void>((ref) async {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) return;

  final syncService = ref.read(industrySyncServiceProvider);
  
  // Run both syncs in parallel
  await Future.wait([
    syncService.syncBlueprints(activeCharacter.characterId),
    syncService.syncIndustryJobs(activeCharacter.characterId, includeCompleted: true),
  ]);
});

// --- Blueprints ---

/// Stream of all blueprints for the active character.
final characterBlueprintsProvider = StreamProvider<List<Blueprint>>((ref) async* {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) {
    yield [];
    return;
  }

  final repository = ref.watch(industryRepositoryProvider);
  yield* repository.watchBlueprints(activeCharacter.characterId);
});

// --- Industry Jobs ---

/// Stream of all industry jobs for the active character.
final characterIndustryJobsProvider = StreamProvider<List<IndustryJob>>((ref) async* {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) {
    yield [];
    return;
  }

  final repository = ref.watch(industryRepositoryProvider);
  yield* repository.watchIndustryJobs(activeCharacter.characterId, includeCompleted: true);
});

/// Stream of only active industry jobs for the active character.
final activeIndustryJobsProvider = StreamProvider<List<IndustryJob>>((ref) async* {
  final activeCharacter = await ref.watch(activeCharacterProvider.future);
  if (activeCharacter == null) {
    yield [];
    return;
  }

  final repository = ref.watch(industryRepositoryProvider);
  yield* repository.watchIndustryJobs(activeCharacter.characterId, includeCompleted: false);
});
