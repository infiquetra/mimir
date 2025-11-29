/// App-wide settings and preferences.
library;

/// Startup behavior options for the app.
enum StartupBehavior {
  /// Open the Dashboard window on app launch.
  openDashboard('dashboard'),

  /// Show only the tray icon on app launch.
  trayOnly('tray_only');

  const StartupBehavior(this.value);

  /// Database value for this enum.
  final String value;

  /// Create from database value.
  static StartupBehavior fromValue(String value) {
    return StartupBehavior.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StartupBehavior.openDashboard,
    );
  }
}

/// Application settings model.
class AppSettings {
  /// Behavior when app launches.
  final StartupBehavior startupBehavior;

  /// Whether the user has completed onboarding.
  final bool onboardingComplete;

  /// Create app settings.
  const AppSettings({
    this.startupBehavior = StartupBehavior.openDashboard,
    this.onboardingComplete = false,
  });

  /// Create copy with updated fields.
  AppSettings copyWith({
    StartupBehavior? startupBehavior,
    bool? onboardingComplete,
  }) {
    return AppSettings(
      startupBehavior: startupBehavior ?? this.startupBehavior,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}
