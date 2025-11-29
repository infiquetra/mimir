import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/app_database.dart';
import '../di/providers.dart';
import '../../features/characters/data/character_repository.dart';
import 'oauth_service.dart';
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
      // Create the authorization request with PKCE.
      final request = _oauthService.createAuthorizationRequest();

      // Update state to track the pending request.
      state = state.copyWith(
        flowState: AuthFlowState.awaitingCallback,
        pendingRequest: request,
        clearError: true,
      );

      // Launch the browser for authentication.
      final launched = await launchUrl(
        request.authorizationUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        state = state.copyWith(
          flowState: AuthFlowState.error,
          errorMessage: 'Failed to launch browser for authentication',
          clearPending: true,
        );
        return false;
      }

      return true;
    } catch (e) {
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
    debugPrint('OAuth callback received: $callbackUri');
    final pendingRequest = state.pendingRequest;
    if (pendingRequest == null) {
      state = state.copyWith(
        flowState: AuthFlowState.error,
        errorMessage: 'No pending authentication request',
      );
      return null;
    }

    try {
      state = state.copyWith(flowState: AuthFlowState.exchangingTokens);

      // Parse the callback to get the authorization code.
      final code = _oauthService.parseCallbackUrl(
        callbackUri,
        pendingRequest.state,
      );

      if (code == null) {
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

      // Parse the JWT to get character info.
      final characterInfo =
          _oauthService.parseAccessToken(tokenResponse.accessToken);

      // Store the tokens securely.
      await _tokenManager.storeTokens(
        characterId: characterInfo.characterId,
        tokenResponse: tokenResponse,
      );

      // Create or update the character in the database.
      await _createOrUpdateCharacter(characterInfo, tokenResponse);

      // Fetch full character data from ESI (corporation, alliance).
      // This runs in background - don't block OAuth completion on it.
      _refreshCharacterData(characterInfo.characterId);

      state = state.copyWith(
        flowState: AuthFlowState.success,
        clearPending: true,
      );

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
    // For now, create a basic character record.
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
