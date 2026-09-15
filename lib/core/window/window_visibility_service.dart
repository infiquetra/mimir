import 'dart:async';

enum WindowVisibilityEvent { visible, hidden, closed, resume }

/// Naive X7 visibility: resume maps to visible; hide/dispose leave polling on.
class WindowVisibilityService {
  WindowVisibilityService({this.windowKey = 'exploration'});

  final String windowKey;
  final StreamController<WindowVisibilityEvent> _events =
      StreamController<WindowVisibilityEvent>.broadcast();
  var _hidden = false;

  Stream<WindowVisibilityEvent> get events => _events.stream;

  bool get isPolling => true;

  bool get isHidden => _hidden;

  void emitVisible() {
    _hidden = false;
    _events.add(WindowVisibilityEvent.visible);
  }

  void emitHidden() {
    _hidden = true;
    _events.add(WindowVisibilityEvent.hidden);
  }

  void emitClosed() {
    _events.add(WindowVisibilityEvent.closed);
  }

  void emitResume() {
    emitVisible();
  }

  void dispose() {
    _hidden = true;
  }
}
