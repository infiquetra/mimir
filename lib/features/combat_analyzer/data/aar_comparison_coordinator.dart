import '../../../core/logging/logger.dart';

/// Slot-keyed busy lock for comparison capture/proposal writes.
///
/// Independent of [AarEvidenceOperationCoordinator]: comparison writes do not
/// become analysis evidence waits.
class AarComparisonCoordinator {
  final Set<String> _reserved = {};

  String _key(String encounterId, String slot) => '$encounterId:$slot';

  bool isBusy(String encounterId, {required String slot}) {
    return _reserved.contains(_key(encounterId, slot));
  }

  /// Synchronous reserve. Throws [StateError] containing `busy` on duplicate.
  void reserve(String encounterId, {required String slot}) {
    final key = _key(encounterId, slot);
    if (_reserved.contains(key)) {
      Log.w('AAR', 'comparison slot busy $key');
      throw StateError('Comparison slot is busy for $key');
    }
    _reserved.add(key);
    Log.d('AAR', 'comparison reserved $key');
  }

  void settle(String encounterId, {required String slot}) {
    final key = _key(encounterId, slot);
    _reserved.remove(key);
    Log.d('AAR', 'comparison settled $key');
  }
}
