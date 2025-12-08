import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/app_database.dart';
import '../sde/sde_database.dart';
import '../sde/sde_service.dart';

/// Provider for the application database.
///
/// This is a singleton that persists for the lifetime of the app.
/// Drift handles connection pooling and thread safety.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the SDE database.
///
/// This is a singleton for EVE static data lookups.
final sdeDatabaseProvider = Provider<SdeDatabase>((ref) {
  final db = SdeDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the SDE service.
///
/// Handles loading and caching EVE static data (skills, items, etc).
final sdeServiceProvider = Provider<SdeService>((ref) {
  final database = ref.watch(sdeDatabaseProvider);
  return SdeService(database: database);
});

/// Provider for tracking the current theme mode.
///
/// Defaults to system theme, but can be overridden by user preference.
final themeModeProvider = StateProvider<ThemeModeOption>((ref) {
  return ThemeModeOption.system;
});

/// Theme mode options.
enum ThemeModeOption {
  light,
  dark,
  system,
}
