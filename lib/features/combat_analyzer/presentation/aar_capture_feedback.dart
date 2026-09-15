import 'package:dio/dio.dart';

import '../../../core/network/esi_client.dart';
import '../domain/aar_capture_exception.dart';
import '../domain/combat_evidence_ledger.dart';

const kAarCaptureSuccessMessage =
    'Current fit confirmed for this AAR. Re-analyze to include it.';

const kAarCaptureEmptySuccessMessage =
    'Current fit confirmed for this AAR. No fitted modules were returned. Re-analyze to include it.';

const kAarCaptureReferenceMessage =
    'Current fit snapshot saved as reference evidence.';

const kAarCaptureNoCharacterUi =
    'Unable to capture fit: This log is not linked to an authenticated character.';

const kAarCaptureAuthUi =
    'Unable to capture fit: Reauthorize this character and try again.';

const kAarCaptureNoShipUi =
    'Unable to capture fit: ESI did not return a current ship. Try again or import a fit.';

const kAarCaptureAssetsUi =
    'Unable to capture fit: Character assets could not be loaded. Try again or import a fit.';

const kAarCaptureSaveUi =
    'Unable to capture fit: The snapshot could not be saved. Try again.';

String aarCaptureSuccessMessage({
  required bool confirmed,
  FitEvidence? evidence,
}) {
  final emptyModules =
      evidence != null &&
      (evidence.fitting.allModules.isEmpty ||
          evidence.limitations.contains(kAarEmptyModulesLimitation));
  if (confirmed && emptyModules) {
    return kAarCaptureEmptySuccessMessage;
  }
  if (confirmed) {
    return kAarCaptureSuccessMessage;
  }
  return kAarCaptureReferenceMessage;
}

/// Maps capture exceptions to Product copy. Never interpolates [error].
String aarCaptureFailureMessage(Object error) {
  if (error is AarCaptureException) {
    return switch (error.code) {
      AarCaptureFailureCode.unmatchedCharacter => kAarCaptureNoCharacterUi,
      AarCaptureFailureCode.noCurrentShip => kAarCaptureNoShipUi,
      AarCaptureFailureCode.authFailure => kAarCaptureAuthUi,
      AarCaptureFailureCode.assetLoadFailure => kAarCaptureAssetsUi,
      AarCaptureFailureCode.persistenceFailure => kAarCaptureSaveUi,
    };
  }
  if (_isAuthFailure(error)) {
    return kAarCaptureAuthUi;
  }
  if (error is FormatException) {
    final message = error.message;
    if (message.contains('authenticated character')) {
      return kAarCaptureNoCharacterUi;
    }
    if (message.contains('current ship')) {
      return kAarCaptureNoShipUi;
    }
  }
  if (error is DioException) {
    return kAarCaptureAssetsUi;
  }
  return kAarCaptureSaveUi;
}

bool _isAuthFailure(Object error) {
  if (error is EsiException) {
    return error.statusCode == 401 || error.statusCode == 403;
  }
  if (error is DioException) {
    final nested = error.error;
    if (nested is EsiException) {
      return nested.statusCode == 401 || nested.statusCode == 403;
    }
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }
  return false;
}
