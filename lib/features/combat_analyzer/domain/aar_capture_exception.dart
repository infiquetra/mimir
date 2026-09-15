/// Persisted when a current-ship snapshot maps to a hull with no fitted modules.
const kAarEmptyModulesLimitation =
    'No fitted modules were returned for the current ship.';

enum AarCaptureFailureCode {
  unmatchedCharacter,
  noCurrentShip,
  authFailure,
  assetLoadFailure,
  persistenceFailure,
}

/// Typed capture failure. Extends [FormatException] so existing direct-service
/// character/ship assertions keep matching `isA<FormatException>()`.
final class AarCaptureException extends FormatException {
  const AarCaptureException(super.message, {required this.code, this.cause});

  final AarCaptureFailureCode code;
  final Object? cause;
}
