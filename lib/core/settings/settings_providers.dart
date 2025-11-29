/// Riverpod providers for app settings.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../di/providers.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

part 'settings_providers.g.dart';

/// Settings repository provider.
@riverpod
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  final db = ref.watch(appDatabaseProvider);
  return SettingsRepository(db);
}

/// Current app settings provider (async).
@riverpod
Future<AppSettings> appSettings(AppSettingsRef ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getSettings();
}

/// Stream of app settings for reactive updates.
@riverpod
Stream<AppSettings> appSettingsStream(AppSettingsStreamRef ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.watchSettings();
}
