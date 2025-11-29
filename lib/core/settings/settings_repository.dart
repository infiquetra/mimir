/// Repository for app settings persistence.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'app_settings.dart';

/// Repository for managing app-wide settings.
///
/// Provides conversion between database model and domain model.
class SettingsRepository {
  final AppDatabase _db;

  /// Create settings repository.
  SettingsRepository(this._db);

  /// Get current app settings.
  Future<AppSettings> getSettings() async {
    final dbSettings = await _db.getAppSettings();
    return _fromDb(dbSettings);
  }

  /// Watch app settings for reactive updates.
  Stream<AppSettings> watchSettings() {
    return _db.watchAppSettings().map(_fromDb);
  }

  /// Set startup behavior preference.
  Future<void> setStartupBehavior(StartupBehavior behavior) {
    return _db.updateAppSettings(
      AppSettingsTableCompanion(
        startupBehavior: Value(behavior.value),
      ),
    );
  }

  /// Mark onboarding as complete.
  Future<void> completeOnboarding() {
    return _db.updateAppSettings(
      const AppSettingsTableCompanion(
        onboardingComplete: Value(true),
      ),
    );
  }

  /// Convert database model to domain model.
  AppSettings _fromDb(AppSettingsTableData data) {
    return AppSettings(
      startupBehavior: StartupBehavior.fromValue(data.startupBehavior),
      onboardingComplete: data.onboardingComplete,
    );
  }
}
