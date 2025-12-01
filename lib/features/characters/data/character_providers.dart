import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import 'character_repository.dart';

/// Provider that streams all characters from the database.
final allCharactersProvider = StreamProvider<List<Character>>((ref) {
  Log.d('CHAR', 'allCharactersProvider - setting up stream');
  final repository = ref.watch(characterRepositoryProvider);
  return repository.watchAllCharacters();
});

/// Provider that streams the active character.
final activeCharacterProvider = StreamProvider<Character?>((ref) {
  Log.d('CHAR', 'activeCharacterProvider - setting up stream');
  final repository = ref.watch(characterRepositoryProvider);
  return repository.watchActiveCharacter();
});

/// Provider for switching the active character.
final switchActiveCharacterProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  Log.i('CHAR', 'switchActiveCharacterProvider - invoked for character $characterId');
  final repository = ref.read(characterRepositoryProvider);
  await repository.setActiveCharacter(characterId);
});

/// Provider for refreshing a character's data from ESI.
final refreshCharacterProvider =
    FutureProvider.family<void, int>((ref, characterId) async {
  Log.i('CHAR', 'refreshCharacterProvider - invoked for character $characterId');
  final repository = ref.read(characterRepositoryProvider);
  await repository.refreshCharacter(characterId);
});

/// Provider that indicates if there are any authenticated characters.
final hasCharactersProvider = Provider<AsyncValue<bool>>((ref) {
  final characters = ref.watch(allCharactersProvider);
  return characters.whenData((list) => list.isNotEmpty);
});

/// Provider for getting a character's total skill points.
final characterTotalSpProvider =
    FutureProvider.family<int, int>((ref, characterId) async {
  Log.d('CHAR', 'characterTotalSpProvider($characterId) - START');
  final esiClient = ref.watch(esiClientProvider);
  final skills = await esiClient.getCharacterSkills(characterId);
  Log.i('CHAR', 'characterTotalSpProvider($characterId) - Total SP: ${skills.totalSp}');
  return skills.totalSp;
});
