import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../database/app_database.dart';
import 'oauth_service.dart';

/// File-based storage for pending OAuth authorization requests.
///
/// This allows sharing the PKCE code_verifier between windows:
/// - Sub-window creates auth request → saves to file → launches browser
/// - Main window receives callback → loads from file → exchanges tokens
///
/// Uses the app's Documents directory which is shared between all windows.
class PendingAuthStore {
  static const _fileName = 'pending_auth.json';

  /// Get the path to the pending auth file.
  static Future<File> _getFile() async {
    final dbPath = await getDatabasePath();
    final dir = Directory(path.dirname(dbPath));
    return File(path.join(dir.path, _fileName));
  }

  /// Save pending auth request to shared storage.
  ///
  /// Should be called before launching browser in OAuth flow.
  static Future<void> save(AuthorizationRequest request) async {
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode({
        'codeVerifier': request.codeVerifier,
        'state': request.state,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      debugPrint('[PENDINGAUTH] Saved pending request to ${file.path}');
    } catch (e) {
      debugPrint('[PENDINGAUTH] ERROR saving pending request: $e');
      rethrow;
    }
  }

  /// Load and clear pending auth request from shared storage.
  ///
  /// Returns null if no request exists or if request is expired (> 5 minutes).
  /// Automatically deletes the file after reading for security.
  static Future<AuthorizationRequest?> loadAndClear() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        debugPrint('[PENDINGAUTH] No pending auth file found');
        return null;
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;

      // Delete immediately after reading (security + cleanup)
      await file.delete();
      debugPrint('[PENDINGAUTH] Loaded and cleared pending request from ${file.path}');

      // Check if request is too old (5 minutes max)
      final timestamp = DateTime.parse(json['timestamp'] as String);
      final age = DateTime.now().difference(timestamp);

      if (age > const Duration(minutes: 5)) {
        debugPrint('[PENDINGAUTH] Request expired (age: ${age.inMinutes} minutes)');
        return null;
      }

      return AuthorizationRequest(
        authorizationUrl: Uri(), // Not needed for callback handling
        codeVerifier: json['codeVerifier'] as String,
        state: json['state'] as String,
      );
    } catch (e) {
      debugPrint('[PENDINGAUTH] ERROR loading pending request: $e');
      // Try to clean up the file if it exists
      try {
        final file = await _getFile();
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
      return null;
    }
  }

  /// Clear any pending auth request.
  ///
  /// Useful for cleanup on auth cancellation or error.
  static Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
        debugPrint('[PENDINGAUTH] Cleared pending auth file');
      }
    } catch (e) {
      debugPrint('[PENDINGAUTH] ERROR clearing pending request: $e');
    }
  }
}
