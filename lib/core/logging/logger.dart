import 'package:flutter/foundation.dart';

/// Centralized logging utility for consistent debug output.
///
/// All logging uses debugPrint() which only outputs in debug mode.
/// Use tagged prefixes for easy filtering in logs.
///
/// Usage:
/// ```dart
/// Log.d('TRAY', 'Menu initialized');
/// Log.i('AUTH', 'User logged in: $characterId');
/// Log.w('ESI', 'Rate limit approaching');
/// Log.e('DB', 'Failed to save', error, stackTrace);
/// ```
class Log {
  /// Debug: General diagnostic messages
  /// Use for method entry/exit, state changes
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  /// Info: Important operations
  /// Use for significant events (fetch, save, navigation)
  static void i(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ℹ️ $message');
    }
  }

  /// Warning: Unexpected but handled situations
  /// Use for non-critical issues
  static void w(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ⚠️ $message');
    }
  }

  /// Error: Caught exceptions
  /// Always include error and stack trace when available
  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (kDebugMode) {
      debugPrint('[$tag] ❌ $message');
      if (error != null) debugPrint('[$tag] Error: $error');
      if (stack != null) debugPrint('[$tag] Stack: $stack');
    }
  }
}
