import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/logger.dart';

enum WindowVisibilityEvent { visible, hidden, closed, resume }

/// Per-engine visibility tracking for Exploration (and other subwindows).
///
/// Native observations arrive through [WindowVisibilityPlugin] bound to that
/// engine's NSWindow. Polling is a fallback that runs only while visible and
/// is cancelled on hide, close, and dispose.
class WindowVisibilityService {
  WindowVisibilityService({
    this.windowKey = 'exploration',
    @visibleForTesting EventChannel? eventChannel,
  }) : _eventChannel =
           eventChannel ??
           const EventChannel('com.infiquetra.mimir/window_visibility_events');

  static const _pollInterval = Duration(seconds: 1);

  final String windowKey;
  final EventChannel _eventChannel;
  final StreamController<WindowVisibilityEvent> _events =
      StreamController<WindowVisibilityEvent>.broadcast();

  StreamSubscription<dynamic>? _platformSubscription;
  Timer? _pollTimer;
  var _hidden = true;
  var _disposed = false;

  Stream<WindowVisibilityEvent> get events => _events.stream;

  bool get isPolling => _pollTimer?.isActive ?? false;

  bool get isHidden => _hidden;

  void attach() {
    if (_disposed || _platformSubscription != null) {
      return;
    }
    Log.d('EXPLORATION.WINDOW', 'attach visibility windowKey=$windowKey');
    _platformSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onPlatformEvent,
      onError: (Object error, StackTrace stack) {
        Log.w('EXPLORATION.WINDOW', 'visibility channel error: $error');
      },
    );
  }

  void emitVisible() {
    _hidden = false;
    _startPolling();
    _add(WindowVisibilityEvent.visible);
  }

  void emitHidden() {
    _hidden = true;
    _stopPolling();
    _add(WindowVisibilityEvent.hidden);
  }

  void emitClosed() {
    _hidden = true;
    _stopPolling();
    _add(WindowVisibilityEvent.closed);
  }

  void emitResume() {
    _hidden = false;
    _startPolling();
    _add(WindowVisibilityEvent.resume);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    Log.d('EXPLORATION.WINDOW', 'detach visibility windowKey=$windowKey');
    _stopPolling();
    _platformSubscription?.cancel();
    _platformSubscription = null;
    _events.close();
  }

  void _onPlatformEvent(dynamic event) {
    final name = event is Map ? event['state']?.toString() : event?.toString();
    switch (name) {
      case 'visible':
        emitVisible();
      case 'hidden':
        emitHidden();
      case 'closed':
        emitClosed();
      case 'resume':
        emitResume();
      default:
        Log.w('EXPLORATION.WINDOW', 'unknown visibility event: $event');
    }
  }

  void _startPolling() {
    if (_disposed) {
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {});
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _add(WindowVisibilityEvent event) {
    if (_disposed || _events.isClosed) {
      return;
    }
    Log.d(
      'EXPLORATION.WINDOW',
      'visibility ${event.name} windowKey=$windowKey',
    );
    _events.add(event);
  }
}
