import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'character_repository.dart';

/// Provider that streams all characters from the database.
final allCharactersProvider = StreamProvider<List<Character>>((ref) {
  final repository = ref.watch(characterRepositoryProvider);
  return repository.watchAllCharacters();
});

/// Provider that streams the active character.
final activeCharacterProvider = StreamProvider<Character?>((ref) {
  final repository = ref.watch(characterRepositoryProvider);
  return repository.watchActiveCharacter();
});

/// Provider for switching the active character.
final switchActiveCharacterProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  final repository = ref.read(characterRepositoryProvider);
  await repository.setActiveCharacter(characterId);
});

/// Provider for refreshing a character's data from ESI.
final refreshCharacterProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  final repository = ref.read(characterRepositoryProvider);
  await repository.refreshCharacter(characterId);
});

/// Provider that indicates if there are any authenticated characters.
final hasCharactersProvider = Provider<AsyncValue<bool>>((ref) {
  final characters = ref.watch(allCharactersProvider);
  return characters.whenData((list) => list.isNotEmpty);
});
