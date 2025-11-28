import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/oauth_service.dart';
import '../auth/token_manager.dart';
import '../config/eve_config.dart';

/// ESI API client for making requests to the EVE Online API.
///
/// Handles:
/// - Automatic token injection for authenticated requests
/// - Token refresh when access tokens expire
/// - ESI-specific error handling
/// - Rate limiting awareness
class EsiClient {
  final Dio _dio;
  final TokenManager _tokenManager;
  final OAuthService _oauthService;

  EsiClient({
    required TokenManager tokenManager,
    required OAuthService oauthService,
    Dio? dio,
  })  : _tokenManager = tokenManager,
        _oauthService = oauthService,
        _dio = dio ?? Dio() {
    _configureDio();
  }

  void _configureDio() {
    _dio.options.baseUrl = EveConfig.esiBaseUrl;
    _dio.options.connectTimeout =
        const Duration(milliseconds: EveConfig.defaultTimeout);
    _dio.options.receiveTimeout =
        const Duration(milliseconds: EveConfig.defaultTimeout);

    // Add default query parameter for datasource.
    _dio.options.queryParameters = {
      'datasource': EveConfig.datasource,
    };
  }

  /// Makes an authenticated GET request to ESI.
  ///
  /// [path] - The API path (without base URL).
  /// [characterId] - The character ID for token lookup.
  /// [queryParameters] - Additional query parameters.
  Future<Response<T>> authenticatedGet<T>(
    String path, {
    required int characterId,
    Map<String, dynamic>? queryParameters,
  }) async {
    final accessToken = await _getValidAccessToken(characterId);

    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );
  }

  /// Makes a public (unauthenticated) GET request to ESI.
  ///
  /// [path] - The API path (without base URL).
  /// [queryParameters] - Additional query parameters.
  Future<Response<T>> publicGet<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
    );
  }

  /// Gets a valid access token for a character, refreshing if needed.
  Future<String> _getValidAccessToken(int characterId) async {
    final tokens = await _tokenManager.getTokens(characterId);
    if (tokens == null) {
      throw EsiException(
        'No tokens found for character $characterId',
        statusCode: 401,
      );
    }

    // Check if access token needs refresh.
    if (tokens.isAccessTokenExpired || tokens.accessToken == null) {
      // Refresh the token.
      final newTokens = await _oauthService.refreshAccessToken(
        tokens.refreshToken,
      );

      // Store the new tokens.
      await _tokenManager.updateAccessToken(
        characterId: characterId,
        tokenResponse: newTokens,
      );

      return newTokens.accessToken;
    }

    return tokens.accessToken!;
  }

  // ============================================================================
  // Character API
  // ============================================================================

  /// Gets public character information.
  ///
  /// This is a public endpoint - no authentication required.
  Future<CharacterPublicInfo> getCharacterPublicInfo(int characterId) async {
    final response = await publicGet<Map<String, dynamic>>(
      '/characters/$characterId/',
    );

    return CharacterPublicInfo.fromJson(response.data!);
  }

  /// Gets the character's portrait URLs.
  String getCharacterPortraitUrl(int characterId, {int size = 128}) {
    return '${EveConfig.imageServerUrl}/characters/$characterId/portrait?size=$size';
  }

  // ============================================================================
  // Skills API
  // ============================================================================

  /// Gets the character's skill queue.
  Future<List<SkillQueueItem>> getSkillQueue(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>(
      '/characters/$characterId/skillqueue/',
      characterId: characterId,
    );

    return (response.data ?? [])
        .map((item) => SkillQueueItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ============================================================================
  // Wallet API
  // ============================================================================

  /// Gets the character's wallet balance.
  Future<double> getWalletBalance(int characterId) async {
    final response = await authenticatedGet<double>(
      '/characters/$characterId/wallet/',
      characterId: characterId,
    );

    return response.data ?? 0.0;
  }

  /// Gets the character's wallet journal.
  Future<List<WalletJournalItem>> getWalletJournal(
    int characterId, {
    int page = 1,
  }) async {
    final response = await authenticatedGet<List<dynamic>>(
      '/characters/$characterId/wallet/journal/',
      characterId: characterId,
      queryParameters: {'page': page},
    );

    return (response.data ?? [])
        .map((item) => WalletJournalItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================================
// Response Models
// ============================================================================

/// Public character information from ESI.
class CharacterPublicInfo {
  final int corporationId;
  final DateTime birthday;
  final String name;
  final int? allianceId;

  const CharacterPublicInfo({
    required this.corporationId,
    required this.birthday,
    required this.name,
    this.allianceId,
  });

  factory CharacterPublicInfo.fromJson(Map<String, dynamic> json) {
    return CharacterPublicInfo(
      corporationId: json['corporation_id'] as int,
      birthday: DateTime.parse(json['birthday'] as String),
      name: json['name'] as String,
      allianceId: json['alliance_id'] as int?,
    );
  }
}

/// Skill queue item from ESI.
class SkillQueueItem {
  final int queuePosition;
  final int skillId;
  final int finishedLevel;
  final DateTime? startDate;
  final DateTime? finishDate;
  final int? trainingStartSp;
  final int? levelEndSp;
  final int? levelStartSp;

  const SkillQueueItem({
    required this.queuePosition,
    required this.skillId,
    required this.finishedLevel,
    this.startDate,
    this.finishDate,
    this.trainingStartSp,
    this.levelEndSp,
    this.levelStartSp,
  });

  factory SkillQueueItem.fromJson(Map<String, dynamic> json) {
    return SkillQueueItem(
      queuePosition: json['queue_position'] as int,
      skillId: json['skill_id'] as int,
      finishedLevel: json['finished_level'] as int,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      finishDate: json['finish_date'] != null
          ? DateTime.parse(json['finish_date'] as String)
          : null,
      trainingStartSp: json['training_start_sp'] as int?,
      levelEndSp: json['level_end_sp'] as int?,
      levelStartSp: json['level_start_sp'] as int?,
    );
  }
}

/// Wallet journal item from ESI.
class WalletJournalItem {
  final int id;
  final double amount;
  final double balance;
  final String refType;
  final int? firstPartyId;
  final int? secondPartyId;
  final String? description;
  final DateTime date;

  const WalletJournalItem({
    required this.id,
    required this.amount,
    required this.balance,
    required this.refType,
    this.firstPartyId,
    this.secondPartyId,
    this.description,
    required this.date,
  });

  factory WalletJournalItem.fromJson(Map<String, dynamic> json) {
    return WalletJournalItem(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
      refType: json['ref_type'] as String,
      firstPartyId: json['first_party_id'] as int?,
      secondPartyId: json['second_party_id'] as int?,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

/// Exception for ESI API errors.
class EsiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const EsiException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() => 'EsiException: $message (status: $statusCode)';

  /// Whether this error indicates the token is invalid/expired.
  bool get isAuthError => statusCode == 401;

  /// Whether this error indicates missing scopes.
  bool get isScopeError => statusCode == 403;

  /// Whether this error indicates rate limiting.
  bool get isRateLimited => statusCode == 420;
}

/// Provider for the ESI client.
final esiClientProvider = Provider<EsiClient>((ref) {
  return EsiClient(
    tokenManager: ref.watch(tokenManagerProvider),
    oauthService: ref.watch(oauthServiceProvider),
  );
});
