import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

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
/// Uses the system_tray package which supports:
/// - Menu item icons (EVE-themed PNG images)
/// - Menu title/header with divider
/// - Separators between menu sections
class TrayService {
  TrayService._();

  static final TrayService instance = TrayService._();

  final SystemTray _systemTray = SystemTray();
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
      await _systemTray.initSystemTray(
        title: 'Mimir',
        iconPath: 'assets/icons/eve/app_icon.png',
        toolTip: 'Mimir - EVE Online Companion',
      );

      // Build the menu with icons and title
      await _updateMenu();

      // Listen for tray icon clicks
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;
      debugPrint('TrayService: Initialized successfully with system_tray');
    } catch (e) {
      debugPrint('TrayService: Failed to initialize: $e');
    }
  }

  /// Updates the tray menu with current state.
  ///
  /// Called after initialization and when window state changes.
  Future<void> _updateMenu() async {
    final windowService = WindowService.instance;

    final menu = Menu();
    await menu.buildFrom([
      // App title header (disabled, acts as label)
      MenuItemLabel(
        label: 'Mimir',
        enabled: false, // Non-clickable title
      ),
      MenuSeparator(),

      // Main feature windows
      MenuItemLabel(
        label: windowService.isWindowOpen(WindowType.dashboard)
            ? '◆ Dashboard'
            : 'Dashboard',
        image: 'assets/icons/tray/dashboard.png',
        onClicked: (menuItem) => _handleMenuClick('dashboard'),
      ),
      MenuItemLabel(
        label: windowService.isWindowOpen(WindowType.skills)
            ? '◆ Skills'
            : 'Skills',
        image: 'assets/icons/tray/skills.png',
        onClicked: (menuItem) => _handleMenuClick('skills'),
      ),
      MenuItemLabel(
        label: windowService.isWindowOpen(WindowType.wallet)
            ? '◆ Wallet'
            : 'Wallet',
        image: 'assets/icons/tray/wallet.png',
        onClicked: (menuItem) => _handleMenuClick('wallet'),
      ),
      MenuItemLabel(
        label: windowService.isWindowOpen(WindowType.characters)
            ? '◆ Characters'
            : 'Characters',
        image: 'assets/icons/tray/characters.png',
        onClicked: (menuItem) => _handleMenuClick('characters'),
      ),
      MenuItemLabel(
        label: windowService.isWindowOpen(WindowType.settings)
            ? '◆ Settings'
            : 'Settings',
        image: 'assets/icons/tray/settings.png',
        onClicked: (menuItem) => _handleMenuClick('settings'),
      ),

      MenuSeparator(),

      MenuItemLabel(
        label: 'Show Tutorial',
        image: 'assets/icons/tray/tutorial.png',
        onClicked: (menuItem) => _handleMenuClick('onboarding'),
      ),

      MenuSeparator(),

      MenuItemLabel(
        label: 'Quit Mimir',
        onClicked: (menuItem) => _handleMenuClick('quit'),
      ),
    ]);

    await _systemTray.setContextMenu(menu);
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

    await _systemTray.destroy();
    _isInitialized = false;

    debugPrint('TrayService: Disposed');
  }
}
