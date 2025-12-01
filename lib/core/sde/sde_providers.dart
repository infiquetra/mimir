import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sde_database.dart';
import 'sde_service.dart';

/// Provider for the SDE database instance.
final sdeDatabaseProvider = Provider<SdeDatabase>((ref) {
  final database = SdeDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Provider for the SDE service.
final sdeServiceProvider = Provider<SdeService>((ref) {
  final database = ref.watch(sdeDatabaseProvider);
  return SdeService(database: database);
});

/// Provider to initialize the SDE service.
///
/// Watch this provider during app startup to ensure
/// SDE data is loaded before skill displays are shown.
final sdeInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(sdeServiceProvider);
  await service.initialize();
});

/// Provider to get a skill name by type ID.
///
/// Returns the skill name or "Skill #`<id>`" if not found.
final skillNameProvider = FutureProvider.family<String, int>((ref, typeId) async {
  final service = ref.watch(sdeServiceProvider);

  // Ensure SDE is initialized
  await ref.watch(sdeInitializerProvider.future);

  final name = await service.getSkillName(typeId);
  return name ?? 'Skill #$typeId';
});

/// Provider to get multiple skill names at once.
///
/// More efficient for lists of skills than calling skillNameProvider
/// multiple times.
final skillNamesProvider =
    FutureProvider.family<Map<int, String>, List<int>>((ref, typeIds) async {
  final service = ref.watch(sdeServiceProvider);

  // Ensure SDE is initialized
  await ref.watch(sdeInitializerProvider.future);

  final names = await service.getSkillNames(typeIds);

  // Fill in missing names with fallback
  final result = <int, String>{};
  for (final id in typeIds) {
    result[id] = names[id] ?? 'Skill #$id';
  }
  return result;
});

/// Provider to get all skill groups.
final skillGroupsProvider = FutureProvider<List<SdeGroup>>((ref) async {
  final service = ref.watch(sdeServiceProvider);

  // Ensure SDE is initialized
  await ref.watch(sdeInitializerProvider.future);

  return service.getSkillGroups();
});

/// Provider to get skills in a specific group.
final skillsByGroupProvider =
    FutureProvider.family<List<SdeType>, int>((ref, groupId) async {
  final service = ref.watch(sdeServiceProvider);

  // Ensure SDE is initialized
  await ref.watch(sdeInitializerProvider.future);

  return service.getSkillsByGroup(groupId);
});

/// Provider for SDE initialization status.
final sdeReadyProvider = Provider<bool>((ref) {
  final asyncValue = ref.watch(sdeInitializerProvider);
  return asyncValue.hasValue;
});
