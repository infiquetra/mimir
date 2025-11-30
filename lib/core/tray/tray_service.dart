import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../window/window_service.dart';
import '../window/window_types.dart';

/// Service for managing the system tray (menu bar) icon.
///
/// Provides a macOS menu bar icon with a dropdown menu for:
/// - Opening specific feature windows (Dashboard, Skills, Wallet, Settings)
/// - Showing the tutorial/onboarding
/// - Quitting the application
///
/// The app stays running in the menu bar even when all windows are closed,
/// similar to apps like Slack or Discord.
///
/// Uses the tray_manager package which supports:
/// - Menu item icons (EVE-themed PNG images)
/// - Menu title/header with divider
/// - Separators between menu sections
class TrayService extends TrayListener {
  TrayService._() {
    trayManager.addListener(this);
  }

  static final TrayService instance = TrayService._();

  bool _isInitialized = false;

  /// Initializes the system tray icon and menu.
  ///
  /// Should be called once during main window startup.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Only initialize on macOS (could extend to Windows/Linux later)
    if (!Platform.isMacOS) {
      debugPrint('TrayService: Not on macOS, skipping tray initialization');
      return;
    }

    try {
      // Set up the tray icon
      await trayManager.setIcon(
        'assets/icons/eve/blank.png',
        isTemplate: true,
      );

      // Set tooltip
      await trayManager.setToolTip('Mimir - EVE Online Companion');

      // Build the menu with icons and title
      await _updateMenu();

      _isInitialized = true;
      debugPrint('TrayService: Initialized successfully with tray_manager');
    } catch (e) {
      debugPrint('TrayService: Failed to initialize: $e');
    }
  }

  /// Updates the tray menu with current state.
  ///
  /// Called after initialization and when window state changes.
  Future<void> _updateMenu() async {
    final windowService = WindowService.instance;

    final menu = Menu(
      items: [
        // App title header (disabled, acts as label)
        MenuItem(
          label: 'Mimir',
          disabled: true, // Non-clickable title
        ),
        MenuItem.separator(),

        // Main feature windows
        MenuItem(
          key: 'dashboard',
          label: windowService.isWindowOpen(WindowType.dashboard)
              ? '◆ Dashboard'
              : 'Dashboard',
          image: 'assets/icons/tray/dashboard.png',
        ),
        MenuItem(
          key: 'skills',
          label: windowService.isWindowOpen(WindowType.skills)
              ? '◆ Skills'
              : 'Skills',
          image: 'assets/icons/tray/skills.png',
        ),
        MenuItem(
          key: 'wallet',
          label: windowService.isWindowOpen(WindowType.wallet)
              ? '◆ Wallet'
              : 'Wallet',
          image: 'assets/icons/tray/wallet.png',
        ),
        MenuItem(
          key: 'characters',
          label: windowService.isWindowOpen(WindowType.characters)
              ? '◆ Characters'
              : 'Characters',
          image: 'assets/icons/tray/characters.png',
        ),
        MenuItem(
          key: 'settings',
          label: windowService.isWindowOpen(WindowType.settings)
              ? '◆ Settings'
              : 'Settings',
          image: 'assets/icons/tray/settings.png',
        ),

        MenuItem.separator(),

        MenuItem(
          key: 'onboarding',
          label: 'Show Tutorial',
          image: 'assets/icons/tray/tutorial.png',
        ),

        MenuItem.separator(),

        MenuItem(
          key: 'quit',
          label: 'Quit Mimir',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = menuItem.key;
    if (action != null) {
      _handleMenuClick(action);
    }
  }

  /// Handles menu item clicks.
  Future<void> _handleMenuClick(String action) async {
    final windowService = WindowService.instance;

    switch (action) {
      case 'dashboard':
        await windowService.openWindow(WindowType.dashboard);
        await refreshMenu();
        break;
      case 'skills':
        await windowService.openWindow(WindowType.skills);
        await refreshMenu();
        break;
      case 'wallet':
        await windowService.openWindow(WindowType.wallet);
        await refreshMenu();
        break;
      case 'characters':
        await windowService.openWindow(WindowType.characters);
        await refreshMenu();
        break;
      case 'settings':
        await windowService.openWindow(WindowType.settings);
        await refreshMenu();
        break;
      case 'onboarding':
        await windowService.openWindow(WindowType.onboarding);
        await refreshMenu();
        break;
      case 'quit':
        await windowService.quitApp();
        break;
    }
  }

  /// Refreshes the menu to reflect current window state.
  Future<void> refreshMenu() async {
    if (!_isInitialized) return;
    await _updateMenu();
  }

  /// Disposes of the tray service.
  Future<void> dispose() async {
    if (!_isInitialized) return;

    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;

    debugPrint('TrayService: Disposed');
  }
}
