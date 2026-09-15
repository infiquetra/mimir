import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/logger.dart';

/// Encounter-scoped attachment/analysis barrier.
///
/// Attachment is reserved synchronously before the first await. A second
/// attachment for the same encounter is rejected as busy. Explicit analysis
/// waits for a pending attachment, then releases before calling the AI.
class AarEvidenceOperationCoordinator extends ChangeNotifier {
  final Map<String, Completer<void>> _attachments = {};

  bool isBusy(String encounterId) => _attachments.containsKey(encounterId);

  Future<T> runAttachment<T>(String encounterId, Future<T> Function() action) {
    if (_attachments.containsKey(encounterId)) {
      Log.w('AAR', 'attachment busy encounter=$encounterId');
      throw StateError('Attachment is busy for this encounter.');
    }
    final done = Completer<void>();
    _attachments[encounterId] = done;
    notifyListeners();
    Log.d('AAR', 'attachment reserved encounter=$encounterId');
    return () async {
      try {
        return await action();
      } finally {
        _attachments.remove(encounterId);
        if (!done.isCompleted) {
          done.complete();
        }
        notifyListeners();
        Log.d('AAR', 'attachment settled encounter=$encounterId');
      }
    }();
  }

  Future<void> waitForAttachment(String encounterId) async {
    final pending = _attachments[encounterId];
    if (pending == null) return;
    Log.d('AAR', 'analysis waiting for attachment encounter=$encounterId');
    await pending.future;
  }
}
