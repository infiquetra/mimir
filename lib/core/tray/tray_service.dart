import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../window/window_service.dart';
import '../window/window_types.dart';

/// Service for managing the system tray (menu bar) icon.
///
/// Provides a macOS menu bar icon with a dropdown menu for:
/// - Opening specific feature windows (Dashboard, Skills, Wallet, Settings)
/// - Quitting the application
///
/// The app stays running in the menu bar even when all windows are closed,
/// similar to apps like Slack or Discord.
class TrayService with TrayListener {
  TrayService._();

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
      // Note: We need a PNG icon for the system tray
      await trayManager.setIcon(
        'assets/icons/eve/app_icon.png',
        isTemplate: true, // Use template mode for macOS dark/light menu bar
      );

      // Build the menu
      await _updateMenu();

      // Listen for menu item clicks
      trayManager.addListener(this);

      _isInitialized = true;
      debugPrint('TrayService: Initialized successfully');
    } catch (e) {
      debugPrint('TrayService: Failed to initialize: $e');
    }
  }

  /// Updates the tray menu with current state.
  ///
  /// Called after initialization and when window state changes.
  Future<void> _updateMenu() async {
    final windowService = WindowService.instance;

    // Note: tray_manager doesn't support icons in menu items
    // Using circle indicators: ◆ = open, ○ = closed
    final menuItems = <MenuItem>[
      MenuItem(
        key: 'dashboard',
        label: windowService.isWindowOpen(WindowType.dashboard)
            ? '◆ Dashboard'
            : '○ Dashboard',
      ),
      MenuItem(
        key: 'skills',
        label: windowService.isWindowOpen(WindowType.skills)
            ? '◆ Skills'
            : '○ Skills',
      ),
      MenuItem(
        key: 'wallet',
        label: windowService.isWindowOpen(WindowType.wallet)
            ? '◆ Wallet'
            : '○ Wallet',
      ),
      MenuItem(
        key: 'characters',
        label: windowService.isWindowOpen(WindowType.characters)
            ? '◆ Characters'
            : '○ Characters',
      ),
      MenuItem(
        key: 'settings',
        label: windowService.isWindowOpen(WindowType.settings)
            ? '◆ Settings'
            : '○ Settings',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: 'Quit Mimir',
      ),
    ];

    await trayManager.setContextMenu(Menu(items: menuItems));
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

  // TrayListener implementation

  @override
  void onTrayIconMouseDown() {
    // Show menu on click (macOS default behavior)
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Also show menu on right-click
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    final windowService = WindowService.instance;

    switch (menuItem.key) {
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
      case 'quit':
        await windowService.quitApp();
        break;
    }
  }

  @override
  void onTrayIconMouseUp() {
    // Not used
  }

  @override
  void onTrayIconRightMouseUp() {
    // Not used
  }
}
