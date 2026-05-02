import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/logging/logger.dart';
import 'core/tray/tray_service.dart';
import 'core/window/sub_window_app.dart';

/// Application entry point.
///
/// Handles both main window and sub-window initialization:
/// - Main window: Initializes window manager, tray icon, and runs MimirApp
/// - Sub-window: Parses arguments and runs SubWindowApp for the specific feature
///
/// Multi-window detection is done via the `multi_window` argument.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure google_fonts to work in multi-window environment
  // Sub-windows can't access path_provider, so disable font caching
  GoogleFonts.config.allowRuntimeFetching = false;

  // Check if this is a sub-window launch
  // desktop_multi_window passes: ['multi_window', 'windowId', 'arguments']
  // NOTE: No double-hyphen prefix (it's 'multi_window', not '--multi_window')
  if (args.firstOrNull == 'multi_window') {
    // This is a sub-window - parse the window ID and arguments
    // Note: desktop_multi_window 0.3.0 uses UUID strings, not integers
    final windowId = args[1]; // String UUID (e.g., '7906EAC4-B83A-43C7-B965-FFB3185ECF2F')
    final windowArgs = args[2];

    Log.d('WINDOW', 'SubWindow[$windowId]: Starting with args=$windowArgs');

    // CRITICAL: Set database path BEFORE creating ProviderScope.
    // Sub-windows can't use path_provider (plugin not registered), so the
    // main window passes the resolved path. We must set it before any
    // Riverpod providers are created, as they may access the database.
    try {
      final decoded = jsonDecode(windowArgs) as Map<String, dynamic>;
      final dbPath = decoded['dbPath'] as String?;
      if (dbPath != null) {
        setDatabasePath(dbPath);
        Log.i('WINDOW', 'SubWindow[$windowId]: Database path set to $dbPath');
      } else {
        Log.e('WINDOW', 'SubWindow[$windowId]: ERROR - No dbPath in args!');
      }
    } catch (e) {
      Log.e('WINDOW', 'SubWindow[$windowId]: ERROR parsing args: $e');
    }

    // Note: Sub-windows run in separate Flutter engines created by desktop_multi_window.
    // Window resizing is handled via custom WindowResizePlugin (see SubWindowApp._resizeWindow())

    runApp(
      ProviderScope(
        child: SubWindowApp(windowArgs: windowArgs),
      ),
    );
    return;
  }

  // Main window initialization
  await _initializeMainWindow();

  runApp(
    const ProviderScope(
      child: MimirApp(),
    ),
  );
}

/// Initializes the main window as a headless tray app.
///
/// Sets up:
/// - Window manager (but keeps window hidden)
/// - System tray icon for macOS menu bar
///
/// The main window never shows - all UI is through sub-windows
/// launched from the system tray menu.
Future<void> _initializeMainWindow() async {
  // Only initialize on desktop platforms
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return;
  }

  await windowManager.ensureInitialized();

  // Configure main window as minimal/hidden - it just hosts the tray
  const windowOptions = WindowOptions(
    size: Size(1, 1), // Minimal size since it's never shown
    minimumSize: Size(1, 1),
    backgroundColor: Color(0x00000000), // Transparent
    skipTaskbar: true, // Don't show in dock/taskbar
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Mimir',
  );

  // Immediately hide the window before showing to prevent blip
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  });

  // Initialize system tray (menu bar icon) - this is the main UI entry point
  await TrayService.instance.initialize();

  Log.i('WINDOW', 'Main window initialized (hidden, tray-only mode)');
}
