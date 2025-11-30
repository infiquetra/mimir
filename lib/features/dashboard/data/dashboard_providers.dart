import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../characters/data/character_providers.dart';
import '../../skills/data/skill_repository.dart';
import '../../wallet/data/wallet_repository.dart';

/// Aggregated data for next skill completion across all characters.
class NextSkillCompletion {
  final Character character;
  final SkillQueueEntry skillEntry;

  const NextSkillCompletion({
    required this.character,
    required this.skillEntry,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NextSkillCompletion &&
          runtimeType == other.runtimeType &&
          character.characterId == other.character.characterId &&
          skillEntry.id == other.skillEntry.id;

  @override
  int get hashCode => character.characterId.hashCode ^ skillEntry.id.hashCode;
}

/// Provider that returns wallet balances for all characters.
///
/// Returns a map of characterId → balance for all characters that
/// have a recorded balance. Characters without balances are excluded.
final allCharacterBalancesProvider =
    FutureProvider<Map<int, double>>((ref) async {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return walletRepository.getAllCharacterBalances();
});

/// Provider that returns skill queues for all characters.
///
/// Returns a map of characterId → skill queue entries for all characters.
/// Characters with empty queues are included with empty lists.
final allCharacterSkillQueuesProvider =
    FutureProvider<Map<int, List<SkillQueueEntry>>>((ref) async {
  final skillRepository = ref.watch(skillRepositoryProvider);
  return skillRepository.getAllCharacterQueues();
});

/// Provider that calculates the total wealth across all characters.
///
/// Sums all character wallet balances. Returns 0.0 if no characters
/// or no balances are available.
final combinedWealthProvider = Provider<AsyncValue<double>>((ref) {
  final balances = ref.watch(allCharacterBalancesProvider);
  return balances.whenData((balanceMap) {
    return balanceMap.values.fold(0.0, (sum, balance) => sum + balance);
  });
});

/// Provider that returns the next skills completing across all characters.
///
/// Returns a sorted list of (Character, SkillQueueEntry) pairs for skills
/// that are actively training (have a finish date). Sorted by finish time
/// (earliest first).
///
/// Skills without finish dates are excluded. Returns empty list if no
/// characters or no active training.
final nextSkillsCompletingProvider =
    FutureProvider<List<NextSkillCompletion>>((ref) async {
  final characters = await ref.watch(allCharactersProvider.future);
  final queues = await ref.watch(allCharacterSkillQueuesProvider.future);

  final completions = <NextSkillCompletion>[];

  for (final character in characters) {
    final queue = queues[character.characterId];
    if (queue == null || queue.isEmpty) continue;

    // Find skills with finish dates
    for (final skill in queue) {
      if (skill.finishDate != null) {
        completions.add(NextSkillCompletion(
          character: character,
          skillEntry: skill,
        ));
      }
    }
  }

  // Sort by finish date (earliest first)
  completions.sort((a, b) {
    final aDate = a.skillEntry.finishDate!;
    final bDate = b.skillEntry.finishDate!;
    return aDate.compareTo(bDate);
  });

  return completions;
});
