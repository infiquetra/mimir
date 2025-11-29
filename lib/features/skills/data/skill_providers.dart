import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../characters/data/character_providers.dart';
import 'skill_repository.dart';

/// Provider that streams the skill queue for the active character.
///
/// Automatically updates when the active character changes or
/// when the skill queue is refreshed.
final skillQueueProvider = StreamProvider<List<SkillQueueEntry>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).valueOrNull;
  if (activeCharacter == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(skillRepositoryProvider);
  return repository.watchSkillQueue(activeCharacter.characterId);
});

/// Provider for the currently training skill (position 0 in queue).
final currentTrainingProvider = Provider<SkillQueueEntry?>((ref) {
  final queue = ref.watch(skillQueueProvider).valueOrNull ?? [];
  if (queue.isEmpty) return null;

  // Find the skill at position 0 (currently training).
  return queue.firstWhere(
    (entry) => entry.queuePosition == 0,
    orElse: () => queue.first,
  );
});

/// Provider for the skill queue preview (first 3 skills for Dashboard).
final skillQueuePreviewProvider = Provider<List<SkillQueueEntry>>((ref) {
  final queue = ref.watch(skillQueueProvider).valueOrNull ?? [];
  return queue.take(3).toList();
});

/// Provider for refreshing the skill queue from ESI.
final refreshSkillQueueProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  final repository = ref.read(skillRepositoryProvider);
  await repository.refreshSkillQueue(characterId);
});

/// Provider that indicates if the skill queue is empty.
final isSkillQueueEmptyProvider = Provider<bool>((ref) {
  final queue = ref.watch(skillQueueProvider).valueOrNull ?? [];
  return queue.isEmpty;
});

/// Provider that indicates if skill queue is loading.
final isSkillQueueLoadingProvider = Provider<bool>((ref) {
  return ref.watch(skillQueueProvider).isLoading;
});
