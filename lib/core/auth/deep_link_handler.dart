import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/eve_config.dart';
import 'auth_providers.dart';

/// Service that handles deep links for OAuth callbacks.
///
/// Uses the `app_links` package to listen for incoming URLs and routes
/// OAuth callbacks to the auth controller.
class DeepLinkHandler {
  final AppLinks _appLinks;
  final Ref _ref;
  StreamSubscription<Uri>? _subscription;

  DeepLinkHandler({
    required Ref ref,
    AppLinks? appLinks,
  })  : _ref = ref,
        _appLinks = appLinks ?? AppLinks();

  /// Initializes the deep link handler.
  ///
  /// Call this once at app startup to begin listening for deep links.
  Future<void> initialize() async {
    // Handle the initial link if the app was launched from a deep link.
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (_) {
      // No initial link or error getting it - this is fine.
    }

    // Listen for subsequent deep links while the app is running.
    _subscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  /// Handles an incoming deep link URI.
  void _handleDeepLink(Uri uri) {
    // Check if this is an OAuth callback.
    if (_isOAuthCallback(uri)) {
      _handleOAuthCallback(uri);
    }
  }

  /// Checks if the URI is an OAuth callback.
  bool _isOAuthCallback(Uri uri) {
    // Check if the scheme matches our registered scheme.
    return uri.scheme == EveConfig.urlScheme;
  }

  /// Handles an OAuth callback by passing it to the auth controller.
  void _handleOAuthCallback(Uri uri) {
    final authController = _ref.read(authControllerProvider.notifier);
    authController.handleCallback(uri);
  }

  /// Disposes of the deep link handler.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Provider for the deep link handler.
///
/// This should be initialized at app startup.
final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  final handler = DeepLinkHandler(ref: ref);

  // Initialize immediately.
  handler.initialize();

  // Dispose when the provider is disposed.
  ref.onDispose(() => handler.dispose());

  return handler;
});
