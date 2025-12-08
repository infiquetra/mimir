import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/app_database.dart';

/// Provider for the application database.
///
/// This is a singleton that persists for the lifetime of the app.
/// Drift handles connection pooling and thread safety.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
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
