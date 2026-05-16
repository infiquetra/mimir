/// Window type definitions for multi-window architecture.
///
/// Each navigation destination maps to a specific window type that can
/// be opened independently.
library;

/// Represents the different window types in the application.
///
/// Each window type corresponds to a major feature area that can be
/// displayed in its own window.
enum WindowType {
  /// Main controller window (typically hidden, manages other windows).
  main,

  /// Dashboard showing character overview.
  dashboard,

  /// Skills screen showing skill queue and training progress.
  skills,

  /// Wallet screen showing ISK balance and transaction history.
  wallet,

  /// Characters screen showing all configured characters.
  characters,

  /// Settings screen for app configuration.
  settings,

  /// Onboarding wizard for first-time users.
  onboarding,

  /// Assets screen for browsing item inventory.
  assets,

  /// Planetary Industry screen for managing colonies.
  planetary,

  /// Industry & Manufacturing screen for blueprints and jobs.
  industry,

  /// Market Tools screen for active orders and price checking.
  market,

  /// Ship Fitting tool for browsing ships and simulating fits.
  fitting,
}

/// Extension methods for [WindowType].
extension WindowTypeExtension on WindowType {
  /// Returns the window title displayed in the title bar.
  String get title {
    switch (this) {
      case WindowType.main:
        return 'Mimir';
      case WindowType.dashboard:
        return 'Dashboard - Mimir';
      case WindowType.skills:
        return 'Skills - Mimir';
      case WindowType.wallet:
        return 'Wallet - Mimir';
      case WindowType.characters:
        return 'Characters - Mimir';
      case WindowType.settings:
        return 'Settings - Mimir';
      case WindowType.onboarding:
        return 'Welcome to Mimir';
      case WindowType.assets:
        return 'Assets - Mimir';
      case WindowType.planetary:
        return 'Planetary Industry - Mimir';
      case WindowType.industry:
        return 'Industry & Manufacturing - Mimir';
      case WindowType.market:
        return 'Market Tools - Mimir';
      case WindowType.fitting:
        return 'Ship Fitting - Mimir';
    }
  }

  /// Returns the unique identifier for this window type.
  ///
  /// Used by desktop_multi_window to track open windows.
  int get windowId {
    switch (this) {
      case WindowType.main:
        return 0;
      case WindowType.dashboard:
        return 1;
      case WindowType.skills:
        return 2;
      case WindowType.wallet:
        return 3;
      case WindowType.characters:
        return 4;
      case WindowType.settings:
        return 5;
      case WindowType.onboarding:
        return 6;
      case WindowType.assets:
        return 7;
      case WindowType.planetary:
        return 8;
      case WindowType.industry:
        return 9;
      case WindowType.market:
        return 10;
      case WindowType.fitting:
        return 11;
    }
  }

  /// Creates a [WindowType] from its window ID.
  static WindowType fromId(int id) {
    switch (id) {
      case 0:
        return WindowType.main;
      case 1:
        return WindowType.dashboard;
      case 2:
        return WindowType.skills;
      case 3:
        return WindowType.wallet;
      case 4:
        return WindowType.characters;
      case 5:
        return WindowType.settings;
      case 6:
        return WindowType.onboarding;
      case 7:
        return WindowType.assets;
      case 8:
        return WindowType.planetary;
      case 9:
        return WindowType.industry;
      case 10:
        return WindowType.market;
      case 11:
        return WindowType.fitting;
      default:
        return WindowType.dashboard;
    }
  }

  /// Returns the default window size for this window type.
  ({double width, double height}) get defaultSize {
    switch (this) {
      case WindowType.main:
        return (width: 100, height: 400); // Narrow, just nav rail
      case WindowType.dashboard:
        return (width: 1100, height: 850);
      case WindowType.skills:
        return (width: 1200.0, height: 900.0);
      case WindowType.wallet:
        return (width: 800.0, height: 700.0);
      case WindowType.characters:
        return (width: 1200.0, height: 800.0);
      case WindowType.settings:
        return (width: 500, height: 450);
      case WindowType.onboarding:
        return (width: 800, height: 600);
      case WindowType.assets:
        return (width: 1000, height: 800);
      case WindowType.planetary:
        return (width: 1200, height: 900);
      case WindowType.industry:
        return (width: 1200, height: 900);
      case WindowType.market:
        return (width: 1200, height: 900);
      case WindowType.fitting:
        return (width: 1300, height: 950);
    }
  }

  /// Path to the PNG icon asset for this window type.
  ///
  /// Icons are sourced from EVE University Wiki:
  /// https://wiki.eveuniversity.org/UniWiki:Icons
  String get iconAsset {
    switch (this) {
      case WindowType.main:
        return 'assets/icons/eve/app_icon.png';
      case WindowType.dashboard:
        return 'assets/icons/eve/dashboard.png';
      case WindowType.skills:
        return 'assets/icons/eve/skills.png';
      case WindowType.wallet:
        return 'assets/icons/eve/wallet.png';
      case WindowType.characters:
        return 'assets/icons/eve/characters.png';
      case WindowType.settings:
        return 'assets/icons/eve/settings.png';
      case WindowType.onboarding:
        return 'assets/icons/eve/app_icon.png';
      case WindowType.assets:
        return 'assets/icons/eve/assets.png';
      case WindowType.planetary:
        return 'assets/icons/eve/planetary.png';
      case WindowType.industry:
        return 'assets/icons/eve/industry.png';
      case WindowType.market:
        return 'assets/icons/eve/market.png';
      case WindowType.fitting:
        return 'assets/icons/eve/fitting.png';
    }
  }
}
