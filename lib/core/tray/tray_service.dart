import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

import '../logging/logger.dart';
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
    Log.d('TRAY', 'Constructor - adding tray listener');
    trayManager.addListener(this);
  }

  static final TrayService instance = TrayService._();

  bool _isInitialized = false;

  /// Initializes the system tray icon and menu.
  ///
  /// Should be called once during main window startup.
  Future<void> initialize() async {
    Log.d('TRAY', 'initialize() - START');

    if (_isInitialized) {
      Log.w('TRAY', 'initialize() - already initialized, skipping');
      return;
    }

    // Only initialize on macOS (could extend to Windows/Linux later)
    if (!Platform.isMacOS) {
      Log.w('TRAY', 'initialize() - not on macOS, skipping');
      return;
    }

    try {
      Log.d('TRAY', 'Setting tray icon: assets/icons/tray/dashboard.png');
      // Set up the tray icon (REQUIRED - creates the status item)
      await trayManager.setIcon(
        'assets/icons/tray/dashboard.png',
        isTemplate: true,
      );
      Log.i('TRAY', 'Tray icon set successfully');

      Log.d('TRAY', 'Setting tray title: Mimir');
      // Add title text next to icon
      await trayManager.setTitle('Mimir');
      Log.i('TRAY', 'Tray title set successfully');

      Log.d('TRAY', 'Setting tooltip: Mimir - EVE Online Companion');
      // Set tooltip
      await trayManager.setToolTip('Mimir - EVE Online Companion');
      Log.i('TRAY', 'Tray tooltip set successfully');

      // Build the menu with icons and title
      Log.d('TRAY', 'Building context menu...');
      await _updateMenu();

      _isInitialized = true;
      Log.i('TRAY', 'initialize() - SUCCESS');
    } catch (e, stack) {
      Log.e('TRAY', 'initialize() - FAILED', e, stack);
    }
  }

  /// Updates the tray menu with current state.
  ///
  /// Called after initialization and when window state changes.
  Future<void> _updateMenu() async {
    Log.d('TRAY', '_updateMenu() - START');
    final windowService = WindowService.instance;

    final menuItems = <MenuItem>[];

    // App title header (disabled, acts as label)
    menuItems.add(MenuItem(
      label: 'Mimir',
      disabled: true,
    ));
    Log.d('TRAY', 'Added menu item: Mimir (header, disabled)');

    menuItems.add(MenuItem.separator());
    Log.d('TRAY', 'Added separator');

    // Main feature windows
    final dashboardLabel = windowService.isWindowOpen(WindowType.dashboard)
        ? '◆ Dashboard'
        : 'Dashboard';
    menuItems.add(MenuItem(
      key: 'dashboard',
      label: dashboardLabel,
      icon: 'assets/icons/tray/dashboard.png',
    ));
    Log.d('TRAY', 'Added menu item: $dashboardLabel (key=dashboard)');

    final skillsLabel = windowService.isWindowOpen(WindowType.skills)
        ? '◆ Skills'
        : 'Skills';
    menuItems.add(MenuItem(
      key: 'skills',
      label: skillsLabel,
      icon: 'assets/icons/tray/skills.png',
    ));
    Log.d('TRAY', 'Added menu item: $skillsLabel (key=skills)');

    final walletLabel = windowService.isWindowOpen(WindowType.wallet)
        ? '◆ Wallet'
        : 'Wallet';
    menuItems.add(MenuItem(
      key: 'wallet',
      label: walletLabel,
      icon: 'assets/icons/tray/wallet.png',
    ));
    Log.d('TRAY', 'Added menu item: $walletLabel (key=wallet)');

    final charactersLabel = windowService.isWindowOpen(WindowType.characters)
        ? '◆ Characters'
        : 'Characters';
    menuItems.add(MenuItem(
      key: 'characters',
      label: charactersLabel,
      icon: 'assets/icons/tray/characters.png',
    ));
    Log.d('TRAY', 'Added menu item: $charactersLabel (key=characters)');

    final settingsLabel = windowService.isWindowOpen(WindowType.settings)
        ? '◆ Settings'
        : 'Settings';
    menuItems.add(MenuItem(
      key: 'settings',
      label: settingsLabel,
      icon: 'assets/icons/tray/settings.png',
    ));
    Log.d('TRAY', 'Added menu item: $settingsLabel (key=settings)');

    menuItems.add(MenuItem.separator());
    Log.d('TRAY', 'Added separator');

    menuItems.add(MenuItem(
      key: 'onboarding',
      label: 'Show Tutorial',
      icon: 'assets/icons/tray/tutorial.png',
    ));
    Log.d('TRAY', 'Added menu item: Show Tutorial (key=onboarding)');

    menuItems.add(MenuItem.separator());
    Log.d('TRAY', 'Added separator');

    menuItems.add(MenuItem(
      key: 'quit',
      label: 'Quit Mimir',
    ));
    Log.d('TRAY', 'Added menu item: Quit Mimir (key=quit)');

    final menu = Menu(items: menuItems);
    Log.i('TRAY', 'Created menu with ${menuItems.length} items');

    try {
      Log.d('TRAY', 'Setting context menu on trayManager...');
      await trayManager.setContextMenu(menu);
      Log.i('TRAY', '_updateMenu() - SUCCESS - context menu set');
    } catch (e, stack) {
      Log.e('TRAY', '_updateMenu() - setContextMenu FAILED', e, stack);
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    Log.i('TRAY', 'onTrayMenuItemClick - label="${menuItem.label}", key="${menuItem.key}"');
    final action = menuItem.key;
    if (action != null) {
      Log.d('TRAY', 'Handling menu click: $action');
      _handleMenuClick(action);
    } else {
      Log.w('TRAY', 'Menu item clicked but has no key: ${menuItem.label}');
    }
  }

  /// Handles menu item clicks.
  Future<void> _handleMenuClick(String action) async {
    Log.d('TRAY', '_handleMenuClick($action) - START');
    final windowService = WindowService.instance;

    try {
      switch (action) {
        case 'dashboard':
          Log.i('TRAY', 'Opening dashboard window');
          await windowService.openWindow(WindowType.dashboard);
          await refreshMenu();
          break;
        case 'skills':
          Log.i('TRAY', 'Opening skills window');
          await windowService.openWindow(WindowType.skills);
          await refreshMenu();
          break;
        case 'wallet':
          Log.i('TRAY', 'Opening wallet window');
          await windowService.openWindow(WindowType.wallet);
          await refreshMenu();
          break;
        case 'characters':
          Log.i('TRAY', 'Opening characters window');
          await windowService.openWindow(WindowType.characters);
          await refreshMenu();
          break;
        case 'settings':
          Log.i('TRAY', 'Opening settings window');
          await windowService.openWindow(WindowType.settings);
          await refreshMenu();
          break;
        case 'onboarding':
          Log.i('TRAY', 'Opening onboarding window');
          await windowService.openWindow(WindowType.onboarding);
          await refreshMenu();
          break;
        case 'quit':
          Log.i('TRAY', 'Quitting application');
          await windowService.quitApp();
          break;
        default:
          Log.w('TRAY', 'Unknown menu action: $action');
      }
      Log.d('TRAY', '_handleMenuClick($action) - SUCCESS');
    } catch (e, stack) {
      Log.e('TRAY', '_handleMenuClick($action) - FAILED', e, stack);
    }
  }

  /// Refreshes the menu to reflect current window state.
  Future<void> refreshMenu() async {
    Log.d('TRAY', 'refreshMenu() - START');
    if (!_isInitialized) {
      Log.w('TRAY', 'refreshMenu() - not initialized, skipping');
      return;
    }
    await _updateMenu();
    Log.d('TRAY', 'refreshMenu() - SUCCESS');
  }

  /// Disposes of the tray service.
  Future<void> dispose() async {
    Log.d('TRAY', 'dispose() - START');
    if (!_isInitialized) {
      Log.w('TRAY', 'dispose() - not initialized, skipping');
      return;
    }

    trayManager.removeListener(this);
    Log.d('TRAY', 'Removed tray listener');

    await trayManager.destroy();
    Log.d('TRAY', 'Destroyed tray manager');

    _isInitialized = false;

    Log.i('TRAY', 'dispose() - SUCCESS');
  }
}
