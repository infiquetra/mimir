import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../characters/data/character_providers.dart';
import 'models/colony.dart';
import 'pi_repository.dart';

/// Provider for the PI repository.
final piRepositoryProvider = Provider<PiRepository>((ref) {
  return PiRepository(
    ref.watch(esiClientProvider),
    ref.watch(databaseProvider),
  );
});

/// Provider that fetches colonies for all authenticated characters.
final allColoniesProvider = FutureProvider<List<Colony>>((ref) async {
  final characters = ref.watch(allCharactersProvider).value ?? [];
  final repository = ref.watch(piRepositoryProvider);

  final List<Colony> allColonies = [];
  for (final char in characters) {
    try {
      final colonies = await repository.getColonies(char.characterId);
      allColonies.addAll(colonies);
    } catch (e) {
      // Log error but continue with other characters
    }
  }
  return allColonies;
});

/// Selected character filter for PI overview (null = All).
final piCharacterFilterProvider = StateProvider<int?>((ref) => null);

/// Filtered list of colonies based on selected character.
final filteredColoniesProvider = Provider<AsyncValue<List<Colony>>>((ref) {
  final coloniesAsync = ref.watch(allColoniesProvider);
  final filterId = ref.watch(piCharacterFilterProvider);

  return coloniesAsync.whenData((list) {
    if (filterId == null) return list;
    return list.where((c) => c.characterId == filterId).toList();
  });
});
