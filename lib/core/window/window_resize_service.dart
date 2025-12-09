import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for resizing windows via native macOS method channel.
///
/// This service works around limitations in desktop_multi_window which
/// hardcodes window sizes to 800x600 in its native Swift code.
///
/// The service finds the current window and resizes it via NSWindow.setFrame().
class WindowResizeService {
  static const _channel = MethodChannel('com.infiquetra.mimir/window_resize');

  /// Sets the size of the current window.
  ///
  /// The window will be resized and centered on screen.
  static Future<void> setSize(double width, double height) async {
    try {
      await _channel.invokeMethod('setSize', {
        'width': width,
        'height': height,
      });
      debugPrint('WindowResizeService: Resized to ${width}x$height');
    } catch (e) {
      debugPrint('WindowResizeService: Failed to resize: $e');
    }
  }
}
