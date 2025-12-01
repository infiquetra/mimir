import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:window_manager/window_manager.dart';

import '../database/app_database.dart';
import 'window_types.dart';

/// Service for managing multiple application windows.
///
/// Handles creating, tracking, and controlling windows for the multi-window
/// architecture. Each major feature (Dashboard, Skills, Wallet, Settings)
/// can be opened in its own window.
///
/// Uses [desktop_multi_window] for creating windows and [window_manager]
/// for controlling window properties.
class WindowService {
  WindowService._();

  static final WindowService instance = WindowService._();

  /// Map of window type to its controller (if open).
  final Map<WindowType, WindowController> _windows = {};

  /// Initializes the window manager for the main window.
  ///
  /// Should be called once during app startup in the main window.
  Future<void> initializeMainWindow() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(100, 400),
      minimumSize: Size(80, 300),
      center: false,
      backgroundColor: Color(0xFF0A0E17),
      skipTaskbar: true, // Hide from dock/taskbar since we use menu bar
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // Don't show main window by default - just run in menu bar
      await windowManager.hide();
    });

    debugPrint('WindowService: Main window initialized');
  }

  /// Opens a window of the specified type.
  ///
  /// If the window is already open, brings it to the front.
  /// Otherwise, creates a new window.
  Future<void> openWindow(WindowType type) async {
    if (type == WindowType.main) {
      // Show the main window if hidden
      await windowManager.show();
      await windowManager.focus();
      return;
    }

    // Check if window is already open
    if (_windows.containsKey(type)) {
      final controller = _windows[type]!;

      // Verify the window actually still exists by checking active sub-windows
      final activeWindows = await WindowController.getAll();
      final activeWindowIds = activeWindows.map((w) => w.windowId).toList();
      if (activeWindowIds.contains(controller.windowId)) {
        // Window is still alive, bring to front
        try {
          await controller.show();
          debugPrint('WindowService: Focused existing ${type.name} window');
          return;
        } catch (e) {
          debugPrint('WindowService: Error showing ${type.name} window: $e');
        }
      }

      // Window was closed externally, remove stale reference
      _windows.remove(type);
      debugPrint('WindowService: Removed stale ${type.name} window reference');
    }

    // Create new window
    try {
      // Get database path to pass to sub-window.
      // Sub-windows can't use path_provider, so we resolve the path here.
      final dbPath = await getDatabasePath();
      final args = jsonEncode({
        'windowType': type.windowId,
        'dbPath': dbPath,
      });

      final controller = await WindowController.create(
        WindowConfiguration(arguments: args),
      );

      // Note: setFrame and setTitle are not available in desktop_multi_window 0.3.0
      // Windows will use default size and title
      await controller.show();
      // Note: show() brings window to front; WindowController doesn't have focus()

      _windows[type] = controller;
      debugPrint('WindowService: Created new ${type.name} window');
    } catch (e) {
      debugPrint('WindowService: Failed to create ${type.name} window: $e');
      rethrow;
    }
  }

  /// Closes a window of the specified type.
  Future<void> closeWindow(WindowType type) async {
    if (type == WindowType.main) {
      await windowManager.hide();
      return;
    }

    final controller = _windows.remove(type);
    if (controller != null) {
      try {
        await controller.hide();
        debugPrint('WindowService: Closed ${type.name} window');
      } catch (e) {
        debugPrint('WindowService: Error closing ${type.name} window: $e');
      }
    }
  }

  /// Checks if a window of the specified type is currently open.
  bool isWindowOpen(WindowType type) {
    if (type == WindowType.main) {
      return true; // Main window is always "open" (running)
    }
    return _windows.containsKey(type);
  }

  /// Returns all currently open window types.
  List<WindowType> get openWindows => _windows.keys.toList();

  /// Closes all windows except the main controller.
  Future<void> closeAllWindows() async {
    for (final type in _windows.keys.toList()) {
      await closeWindow(type);
    }
  }

  /// Called when a sub-window is closed externally.
  ///
  /// This removes the window from tracking.
  void onWindowClosed(WindowType type) {
    _windows.remove(type);
    debugPrint('WindowService: ${type.name} window closed externally');
  }

  /// Quits the entire application.
  Future<void> quitApp() async {
    await closeAllWindows();
    exit(0);
  }
}

/// Provider for the window service singleton.
final windowServiceProvider = Provider<WindowService>((ref) {
  return WindowService.instance;
});

/// Provider that tracks which windows are currently open.
///
/// This is a simple state provider that UI can watch to update indicators.
final openWindowsProvider = StateProvider<Set<WindowType>>((ref) {
  return {};
});
