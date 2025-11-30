import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../di/providers.dart';
import '../window/cross_window_events.dart';
import '../../features/characters/data/character_repository.dart';
import 'oauth_service.dart';
import 'pending_auth_store.dart';
import 'token_manager.dart';

/// Provider for the OAuth service.
final oauthServiceProvider = Provider<OAuthService>((ref) {
  return OAuthService();
});

/// Provider for the token manager.
final tokenManagerProvider = Provider<TokenManager>((ref) {
  final database = ref.watch(databaseProvider);
  return TokenManager(database: database);
});

/// Current authentication flow state.
enum AuthFlowState {
  /// No authentication in progress.
  idle,

  /// Waiting for user to authenticate in browser.
  awaitingCallback,

  /// Processing the callback and exchanging tokens.
  exchangingTokens,

  /// Authentication completed successfully.
  success,

  /// Authentication failed.
  error,
}

/// State for the authentication flow.
class AuthState {
  final AuthFlowState flowState;
  final String? errorMessage;

  /// The pending authorization request (code verifier needed for callback).
  final AuthorizationRequest? pendingRequest;

  const AuthState({
    this.flowState = AuthFlowState.idle,
    this.errorMessage,
    this.pendingRequest,
  });

  AuthState copyWith({
    AuthFlowState? flowState,
    String? errorMessage,
    AuthorizationRequest? pendingRequest,
    bool clearPending = false,
    bool clearError = false,
  }) {
    return AuthState(
      flowState: flowState ?? this.flowState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingRequest:
          clearPending ? null : (pendingRequest ?? this.pendingRequest),
    );
  }
}

/// Controller for managing the OAuth authentication flow.
///
/// This controller coordinates:
/// - Initiating the OAuth flow and launching the browser
/// - Handling the callback from deep links
/// - Exchanging authorization codes for tokens
/// - Storing tokens and creating character records
class AuthController extends StateNotifier<AuthState> {
  final OAuthService _oauthService;
  final TokenManager _tokenManager;
  final AppDatabase _database;
  final CharacterRepository _characterRepository;

  AuthController({
    required OAuthService oauthService,
    required TokenManager tokenManager,
    required AppDatabase database,
    required CharacterRepository characterRepository,
  })  : _oauthService = oauthService,
        _tokenManager = tokenManager,
        _database = database,
        _characterRepository = characterRepository,
        super(const AuthState());

  /// Starts the OAuth authentication flow.
  ///
  /// Returns true if the browser was launched successfully.
  Future<bool> startAuthFlow() async {
    try {
      debugPrint('[AUTH] startAuthFlow: Creating authorization request');
      // Create the authorization request with PKCE.
      final request = _oauthService.createAuthorizationRequest();

      // Save to shared storage before launching browser.
      // This allows the main window to access the code_verifier when
      // the OAuth callback arrives, even though it was created in a sub-window.
      await PendingAuthStore.save(request);
      debugPrint('[AUTH] startAuthFlow: Saved pending request to shared storage');

      // Update state to track the pending request.
      state = state.copyWith(
        flowState: AuthFlowState.awaitingCallback,
        pendingRequest: request,
        clearError: true,
      );

      debugPrint('[AUTH] startAuthFlow: Launching browser with macOS open command');
      // Use Process.run to bypass url_launcher plugin issues in sub-windows.
      // macOS 'open' command opens URLs in default browser.
      final result = await Process.run(
        'open',
        [request.authorizationUrl.toString()],
      );

      if (result.exitCode != 0) {
        debugPrint('[AUTH] startAuthFlow: Failed to launch browser: ${result.stderr}');
        state = state.copyWith(
          flowState: AuthFlowState.error,
          errorMessage: 'Failed to launch browser: ${result.stderr}',
          clearPending: true,
        );
        return false;
      }

      debugPrint('[AUTH] startAuthFlow: Browser launched successfully, awaiting callback');
      return true;
    } catch (e) {
      debugPrint('[AUTH] startAuthFlow: Exception: $e');
      state = state.copyWith(
        flowState: AuthFlowState.error,
        errorMessage: 'Failed to start authentication: $e',
        clearPending: true,
      );
      return false;
    }
  }

  /// Handles the OAuth callback from a deep link.
  ///
  /// [callbackUri] - The full callback URI including query parameters.
  Future<int?> handleCallback(Uri callbackUri) async {
    debugPrint('[AUTH] handleCallback: Received callback');

    // First try local state, then shared storage.
    // This handles both same-window auth (pendingRequest exists) and
    // cross-window auth (pendingRequest null, load from shared file).
    var pendingRequest = state.pendingRequest;

    if (pendingRequest == null) {
      debugPrint('[AUTH] handleCallback: No local pending request, checking shared storage');
      pendingRequest = await PendingAuthStore.loadAndClear();
    }

    if (pendingRequest == null) {
      debugPrint('[AUTH] handleCallback: ERROR - No pending authentication request');
      state = state.copyWith(
        flowState: AuthFlowState.error,
        errorMessage: 'No pending authentication request',
      );
      return null;
    }

    try {
      debugPrint('[AUTH] handleCallback: Exchanging authorization code for tokens');
      state = state.copyWith(flowState: AuthFlowState.exchangingTokens);

      // Parse the callback to get the authorization code.
      final code = _oauthService.parseCallbackUrl(
        callbackUri,
        pendingRequest.state,
      );

      if (code == null) {
        debugPrint('[AUTH] handleCallback: Authentication was cancelled by user');
        state = state.copyWith(
          flowState: AuthFlowState.error,
          errorMessage: 'Authentication was cancelled',
          clearPending: true,
        );
        return null;
      }

      // Exchange the code for tokens.
      final tokenResponse = await _oauthService.exchangeCodeForTokens(
        code: code,
        codeVerifier: pendingRequest.codeVerifier,
      );
      debugPrint('[AUTH] handleCallback: Token exchange successful');

      // Parse the JWT to get character info.
      final characterInfo =
          _oauthService.parseAccessToken(tokenResponse.accessToken);
      debugPrint('[AUTH] handleCallback: Character ${characterInfo.characterId} (${characterInfo.characterName})');

      // Create or update the character in the database (includes tokens).
      await _createOrUpdateCharacter(characterInfo, tokenResponse);
      debugPrint('[AUTH] handleCallback: Character and tokens saved to database');

      // Fetch full character data from ESI (corporation, alliance).
      // This runs in background - don't block OAuth completion on it.
      _refreshCharacterData(characterInfo.characterId);

      state = state.copyWith(
        flowState: AuthFlowState.success,
        clearPending: true,
      );
      debugPrint('[AUTH] handleCallback: Authentication flow completed successfully');

      return characterInfo.characterId;
    } on OAuthException catch (e, stack) {
      debugPrint('OAuth error: ${e.message}');
      debugPrint('Stack trace: $stack');
      state = state.copyWith(
        flowState: AuthFlowState.error,
        errorMessage: e.message,
        clearPending: true,
      );
      return null;
    } catch (e, stack) {
      debugPrint('Authentication error: $e');
      debugPrint('Stack trace: $stack');
      state = state.copyWith(
        flowState: AuthFlowState.error,
        errorMessage: 'Authentication failed: $e',
        clearPending: true,
      );
      return null;
    }
  }

  /// Cancels any pending authentication flow.
  void cancelAuth() {
    state = const AuthState();
  }

  /// Resets the auth state to idle.
  void reset() {
    state = const AuthState();
  }

  /// Notifies that authentication completed successfully (for cross-window IPC).
  ///
  /// Called by sub-windows when they receive auth_complete message from main window.
  void notifyAuthComplete(int characterId) {
    debugPrint('[AUTH] notifyAuthComplete: Character $characterId authenticated via IPC');
    state = state.copyWith(
      flowState: AuthFlowState.success,
      clearPending: true,
    );
  }

  /// Logs out a character (revokes tokens and removes from database).
  Future<void> logout(int characterId) async {
    try {
      // Get the stored tokens.
      final tokens = await _tokenManager.getTokens(characterId);
      if (tokens != null) {
        // Revoke the refresh token.
        try {
          await _oauthService.revokeToken(tokens.refreshToken);
        } catch (_) {
          // Revocation failures are non-critical.
        }
      }

      // Delete tokens from secure storage.
      await _tokenManager.deleteTokens(characterId);

      // Check if we're deleting the active character.
      final activeCharacter = await _database.getActiveCharacter();
      final isActiveCharacter = activeCharacter?.characterId == characterId;

      // Delete character from database.
      await _database.deleteCharacter(characterId);

      // If we deleted the active character, set another one as active.
      if (isActiveCharacter) {
        final remainingCharacters = await _database.getAllCharacters();
        if (remainingCharacters.isNotEmpty) {
          await _database
              .setActiveCharacter(remainingCharacters.first.characterId);
        }
      }

      // Broadcast deletion to all windows
      await CrossWindowEventService.broadcast(CrossWindowEvent(
        type: CrossWindowEventType.characterDeleted,
        data: {'characterId': characterId},
      ));
      debugPrint('[AUTH] Broadcast character_deleted event for character $characterId');
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Log but don't throw - we want to clean up as much as possible.
    }
  }

  /// Creates or updates a character record after successful authentication.
  Future<void> _createOrUpdateCharacter(
    JwtCharacterInfo characterInfo,
    TokenResponse tokenResponse,
  ) async {
    // Create character record with all fields including tokens.
    // Corporation info will be fetched via ESI in a later step.
    final companion = CharactersCompanion.insert(
      characterId: Value(characterInfo.characterId),
      name: characterInfo.characterName,
      corporationId: 0, // Will be fetched from ESI.
      corporationName: 'Loading...', // Will be fetched from ESI.
      portraitUrl:
          'https://images.evetech.net/characters/${characterInfo.characterId}/portrait',
      tokenExpiry: characterInfo.expiresAt,
      lastUpdated: DateTime.now(),
      refreshToken: Value(tokenResponse.refreshToken),
      accessToken: Value(tokenResponse.accessToken),
    );

    await _database.upsertCharacter(companion);

    // Always set the newly added character as active.
    // The user explicitly added this character, so they want to use it.
    await _database.setActiveCharacter(characterInfo.characterId);
  }

  /// Refreshes character data from ESI in the background.
  ///
  /// This fetches corporation/alliance names and updates the database.
  /// Errors are logged but don't interrupt the auth flow.
  void _refreshCharacterData(int characterId) {
    _characterRepository.refreshCharacter(characterId).then((_) {
      debugPrint('Character $characterId data refreshed from ESI');
    }).catchError((error) {
      debugPrint('Failed to refresh character $characterId: $error');
    });
  }
}

/// Provider for the auth controller.
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    oauthService: ref.watch(oauthServiceProvider),
    tokenManager: ref.watch(tokenManagerProvider),
    database: ref.watch(databaseProvider),
    characterRepository: ref.watch(characterRepositoryProvider),
  );
});

/// Provider that exposes whether any characters are authenticated.
final hasAuthenticatedCharactersProvider = FutureProvider<bool>((ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final characterIds = await tokenManager.getAuthenticatedCharacterIds();
  return characterIds.isNotEmpty;
});
