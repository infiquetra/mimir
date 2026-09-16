import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:window_manager/window_manager.dart';

import '../database/app_database.dart';
import '../logging/logger.dart';
import '../platform/app_paths.dart';
import 'window_types.dart';

/// Native window operations, injected so tests can run without a host.
abstract class WindowPlatformAdapter {
  Future<List<String>> activeWindowIds();

  Future<WindowController> create(String arguments);

  Future<void> show(WindowController controller);

  Future<void> hide(WindowController controller);
}

/// Production adapter over [desktop_multi_window].
class DesktopMultiWindowAdapter implements WindowPlatformAdapter {
  const DesktopMultiWindowAdapter();

  @override
  Future<List<String>> activeWindowIds() async {
    final windows = await WindowController.getAll();
    return windows.map((w) => w.windowId).toList();
  }

  @override
  Future<WindowController> create(String arguments) {
    return WindowController.create(WindowConfiguration(arguments: arguments));
  }

  @override
  Future<void> show(WindowController controller) => controller.show();

  @override
  Future<void> hide(WindowController controller) => controller.hide();
}

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
  final Set<WindowType> _debugOpen = {};
  final Map<WindowType, Future<void>> _openInFlight = {};
  WindowPlatformAdapter _platform = const DesktopMultiWindowAdapter();

  /// Test seam: when set, [openWindow] skips native window creation.
  @visibleForTesting
  Future<void> Function(WindowType type)? debugCreateHook;

  @visibleForTesting
  int debugCreateCalls = 0;

  @visibleForTesting
  int debugShowCalls = 0;

  /// Inject a platform adapter (tests and production-host override).
  @visibleForTesting
  set platformAdapter(WindowPlatformAdapter adapter) => _platform = adapter;

  @visibleForTesting
  WindowPlatformAdapter get platformAdapter => _platform;

  @visibleForTesting
  void debugReset() {
    _windows.clear();
    _debugOpen.clear();
    _openInFlight.clear();
    debugCreateHook = null;
    debugCreateCalls = 0;
    debugShowCalls = 0;
    _platform = const DesktopMultiWindowAdapter();
  }

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
  /// Concurrent calls for the same type join one in-flight create. If the
  /// window is already open (including hidden), it is shown/focused instead
  /// of recreated.
  Future<void> openWindow(WindowType type) {
    final inFlight = _openInFlight[type];
    if (inFlight != null) {
      _log(type, 'join in-flight open');
      return inFlight;
    }
    final future = _openWindow(type);
    _openInFlight[type] = future;
    return future.whenComplete(() {
      if (identical(_openInFlight[type], future)) {
        _openInFlight.remove(type);
      }
    });
  }

  Future<void> _openWindow(WindowType type) async {
    if (type == WindowType.main) {
      await windowManager.show();
      await windowManager.focus();
      return;
    }

    if (debugCreateHook != null) {
      if (_debugOpen.contains(type)) {
        debugShowCalls += 1;
        _log(type, 'reopen show without recreate');
        return;
      }
      debugCreateCalls += 1;
      await debugCreateHook!(type);
      _debugOpen.add(type);
      _log(type, 'created via debug hook');
      return;
    }

    if (_windows.containsKey(type)) {
      final controller = _windows[type]!;
      final activeWindowIds = await _platform.activeWindowIds();
      if (activeWindowIds.contains(controller.windowId)) {
        try {
          await _platform.show(controller);
          _log(type, 'focused existing window');
          return;
        } catch (e) {
          debugPrint('WindowService: Error showing ${type.name} window: $e');
        }
      }

      _windows.remove(type);
      _log(type, 'removed stale window reference');
    }

    try {
      final dbPath = await getDatabasePath();
      final supportPath = await getMimirApplicationSupportPath();
      final size = type.defaultSize;
      final args = jsonEncode({
        'windowType': type.windowId,
        'dbPath': dbPath,
        'supportPath': supportPath,
        'width': size.width,
        'height': size.height,
      });

      final controller = await _platform.create(args);
      await _platform.show(controller);
      _windows[type] = controller;
      _log(type, 'created new window');
    } catch (e) {
      debugPrint('WindowService: Failed to create ${type.name} window: $e');
      rethrow;
    }
  }

  /// Hides a window without destroying its controller.
  ///
  /// Reopen shows/focuses the retained controller. The controller is removed
  /// only when the native window is actually destroyed.
  Future<void> hideWindow(WindowType type) async {
    if (type == WindowType.main) {
      await windowManager.hide();
      return;
    }

    _log(type, 'hide retaining controller');
    final controller = _windows[type];
    if (controller != null) {
      try {
        await _platform.hide(controller);
      } catch (e) {
        debugPrint('WindowService: Error hiding ${type.name} window: $e');
      }
    }
  }

  void _log(WindowType type, String message) {
    if (type == WindowType.exploration) {
      Log.d('EXPLORATION.WINDOW', '$message type=${type.name}');
    } else if (type == WindowType.corporation) {
      Log.d('CORPORATION.WINDOW', '$message type=${type.name}');
    } else {
      debugPrint('WindowService: $message ${type.name}');
    }
  }

  /// Closes a window of the specified type.
  Future<void> closeWindow(WindowType type) async {
    if (type == WindowType.main) {
      await windowManager.hide();
      return;
    }

    _debugOpen.remove(type);
    final controller = _windows.remove(type);
    if (controller != null) {
      try {
        await _platform.hide(controller);
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
    return _windows.containsKey(type) || _debugOpen.contains(type);
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
    _debugOpen.remove(type);
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
