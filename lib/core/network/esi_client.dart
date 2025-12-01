import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// Tracks remaining error limit (ESI returns 429 if this hits 0).
  int _errorLimitRemain = 100;

  /// Timestamp when the error limit will reset.
  DateTime? _errorLimitReset;

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

    // Add interceptor for error handling and logging.
    _dio.interceptors.add(_EsiInterceptor(this));
  }

  /// Updates error limit tracking from response headers.
  void _updateErrorLimit(Response response) {
    final remainHeader = response.headers.value('X-ESI-Error-Limit-Remain');
    final resetHeader = response.headers.value('X-ESI-Error-Limit-Reset');

    if (remainHeader != null) {
      _errorLimitRemain = int.tryParse(remainHeader) ?? _errorLimitRemain;
    }
    if (resetHeader != null) {
      final resetSeconds = int.tryParse(resetHeader);
      if (resetSeconds != null) {
        _errorLimitReset = DateTime.now().add(Duration(seconds: resetSeconds));
      }
    }
  }

  /// Gets the current error limit remaining.
  int get errorLimitRemain => _errorLimitRemain;

  /// Gets when the error limit will reset (if known).
  DateTime? get errorLimitReset => _errorLimitReset;

  /// Whether we're at risk of being rate limited.
  bool get isNearRateLimit => _errorLimitRemain < 20;

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

  /// Gets the character's trained skills.
  ///
  /// Returns all skills the character has trained, with levels and SP.
  Future<CharacterSkills> getCharacterSkills(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>(
      '/characters/$characterId/skills/',
      characterId: characterId,
    );

    return CharacterSkills.fromJson(response.data!);
  }

  /// Gets the character's attributes.
  ///
  /// Returns intelligence, memory, perception, willpower, charisma.
  Future<CharacterAttributes> getCharacterAttributes(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>(
      '/characters/$characterId/attributes/',
      characterId: characterId,
    );

    return CharacterAttributes.fromJson(response.data!);
  }

  // ============================================================================
  // Corporation API
  // ============================================================================

  /// Gets public corporation information.
  Future<CorporationInfo> getCorporationInfo(int corporationId) async {
    final response = await publicGet<Map<String, dynamic>>(
      '/corporations/$corporationId/',
    );

    return CorporationInfo.fromJson(response.data!);
  }

  /// Gets the corporation's logo URL.
  String getCorporationLogoUrl(int corporationId, {int size = 128}) {
    return '${EveConfig.imageServerUrl}/corporations/$corporationId/logo?size=$size';
  }

  // ============================================================================
  // Alliance API
  // ============================================================================

  /// Gets public alliance information.
  Future<AllianceInfo> getAllianceInfo(int allianceId) async {
    final response = await publicGet<Map<String, dynamic>>(
      '/alliances/$allianceId/',
    );

    return AllianceInfo.fromJson(response.data!);
  }

  /// Gets the alliance's logo URL.
  String getAllianceLogoUrl(int allianceId, {int size = 128}) {
    return '${EveConfig.imageServerUrl}/alliances/$allianceId/logo?size=$size';
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

  // ============================================================================
  // Universe API
  // ============================================================================

  /// Gets information about a solar system.
  ///
  /// This is a public endpoint - no authentication required.
  Future<SolarSystemInfo> getSolarSystemInfo(int solarSystemId) async {
    final response = await publicGet<Map<String, dynamic>>(
      '/universe/systems/$solarSystemId/',
    );

    return SolarSystemInfo.fromJson(response.data!);
  }

  /// Gets information about a station.
  ///
  /// This is a public endpoint - no authentication required.
  Future<StationInfo> getStationInfo(int stationId) async {
    final response = await publicGet<Map<String, dynamic>>(
      '/universe/stations/$stationId/',
    );

    return StationInfo.fromJson(response.data!);
  }

  /// Resolves a list of IDs to names.
  ///
  /// This is a public endpoint - no authentication required.
  /// Accepts up to 1000 IDs at a time.
  /// Returns a list of entities with their IDs, names, and categories.
  Future<List<UniverseName>> getUniverseNames(List<int> ids) async {
    if (ids.isEmpty) return [];

    final response = await _dio.post<List<dynamic>>(
      '/universe/names/',
      data: ids,
    );

    return (response.data ?? [])
        .map((item) => UniverseName.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Gets information about a player-owned structure.
  ///
  /// Requires scope: `esi-universe.read_structures.v1`
  /// Returns null if the structure cannot be accessed (forbidden, not docked, etc.)
  /// Throws [EsiException] if authentication fails or other errors occur.
  Future<String?> getStructureName(int structureId, int characterId) async {
    try {
      final response = await authenticatedGet<Map<String, dynamic>>(
        '/universe/structures/$structureId/',
        characterId: characterId,
      );

      return response.data?['name'] as String?;
    } on DioException catch (e) {
      // 403 Forbidden - character lacks docking access to structure
      if (e.response?.statusCode == 403) {
        Log.w('ESI', 'Cannot access structure $structureId: no docking rights');
        return null;
      }
      // Rethrow other errors
      rethrow;
    }
  }

  // ============================================================================
  // Location API
  // ============================================================================

  /// Gets the character's current location.
  ///
  /// Returns null if the character is offline or location is inaccessible.
  /// Throws [EsiException] with 403 if missing required scopes.
  Future<CharacterLocation?> getCharacterLocation(int characterId) async {
    try {
      final response = await authenticatedGet<Map<String, dynamic>>(
        '/characters/$characterId/location/',
        characterId: characterId,
      );

      return CharacterLocation.fromJson(response.data!);
    } on DioException catch (e) {
      // 403 = missing scope (esi-location.read_location.v1)
      if (e.error is EsiException && (e.error as EsiException).isScopeError) {
        rethrow;
      }
      // Character offline or location inaccessible
      return null;
    }
  }

  /// Gets the character's current ship.
  ///
  /// Returns null if the character is offline or ship data is inaccessible.
  /// Throws [EsiException] with 403 if missing required scopes.
  Future<CharacterShip?> getCharacterShip(int characterId) async {
    try {
      final response = await authenticatedGet<Map<String, dynamic>>(
        '/characters/$characterId/ship/',
        characterId: characterId,
      );

      return CharacterShip.fromJson(response.data!);
    } on DioException catch (e) {
      // 403 = missing scope (esi-location.read_ship_type.v1)
      if (e.error is EsiException && (e.error as EsiException).isScopeError) {
        rethrow;
      }
      // Character offline or ship data inaccessible
      return null;
    }
  }

  /// Gets the character's online status.
  ///
  /// Throws [EsiException] with 403 if missing required scopes.
  Future<CharacterOnline> getCharacterOnline(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>(
      '/characters/$characterId/online/',
      characterId: characterId,
    );

    return CharacterOnline.fromJson(response.data!);
  }

  /// Gets the character's clones (jump clones and home location).
  ///
  /// Requires scope: `esi-clones.read_clones.v1`
  /// Throws [EsiException] with 403 if missing required scopes.
  Future<CharacterClones> getCharacterClones(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>(
      '/characters/$characterId/clones/',
      characterId: characterId,
    );

    return CharacterClones.fromJson(response.data!);
  }

  /// Gets the character's active implants.
  ///
  /// Returns a list of implant type IDs currently plugged into the character.
  /// Requires scope: `esi-clones.read_implants.v1`
  /// Throws [EsiException] with 403 if missing required scopes.
  Future<List<int>> getCharacterImplants(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>(
      '/characters/$characterId/implants/',
      characterId: characterId,
    );

    return (response.data ?? []).cast<int>();
  }

  /// Gets the character's standings with NPC factions and corporations.
  ///
  /// Requires scope: `esi-characters.read_standings.v1`
  /// Throws [EsiException] with 403 if missing required scopes.
  Future<List<Standing>> getCharacterStandings(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>(
      '/characters/$characterId/standings/',
      characterId: characterId,
    );

    return (response.data ?? [])
        .map((item) => Standing.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================================
// Dio Interceptor
// ============================================================================

/// Interceptor for ESI-specific error handling and logging.
class _EsiInterceptor extends Interceptor {
  final EsiClient _client;

  _EsiInterceptor(this._client);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Update error limit tracking from headers.
    _client._updateErrorLimit(response);

    // Log successful requests in debug mode.
    if (kDebugMode) {
      debugPrint('ESI ${response.requestOptions.method} ${response.requestOptions.path} '
          '-> ${response.statusCode}');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Convert Dio errors to ESI exceptions.
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    String message;
    String? errorCode;

    if (data is Map<String, dynamic>) {
      message = data['error'] as String? ?? err.message ?? 'Unknown error';
      errorCode = data['error_code'] as String?;
    } else {
      message = err.message ?? 'Unknown error';
    }

    // Log errors.
    debugPrint('ESI Error: $message (status: $statusCode, code: $errorCode)');

    // Update error limit if present in error response.
    if (err.response != null) {
      _client._updateErrorLimit(err.response!);
    }

    // Wrap in EsiException for consistent handling.
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: EsiException(
          message,
          statusCode: statusCode,
          errorCode: errorCode,
        ),
      ),
    );
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
  final String? description;
  final int? factionId;
  final String? title;

  const CharacterPublicInfo({
    required this.corporationId,
    required this.birthday,
    required this.name,
    this.allianceId,
    this.description,
    this.factionId,
    this.title,
  });

  factory CharacterPublicInfo.fromJson(Map<String, dynamic> json) {
    return CharacterPublicInfo(
      corporationId: json['corporation_id'] as int,
      birthday: DateTime.parse(json['birthday'] as String),
      name: json['name'] as String,
      allianceId: json['alliance_id'] as int?,
      description: json['description'] as String?,
      factionId: json['faction_id'] as int?,
      title: json['title'] as String?,
    );
  }
}

/// Character skills summary from ESI.
class CharacterSkills {
  final int totalSp;
  final int? unallocatedSp;
  final List<Skill> skills;

  const CharacterSkills({
    required this.totalSp,
    this.unallocatedSp,
    required this.skills,
  });

  factory CharacterSkills.fromJson(Map<String, dynamic> json) {
    return CharacterSkills(
      totalSp: json['total_sp'] as int,
      unallocatedSp: json['unallocated_sp'] as int?,
      skills: (json['skills'] as List<dynamic>)
          .map((s) => Skill.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single trained skill.
class Skill {
  final int skillId;
  final int trainedSkillLevel;
  final int skillpointsInSkill;
  final int activeSkillLevel;

  const Skill({
    required this.skillId,
    required this.trainedSkillLevel,
    required this.skillpointsInSkill,
    required this.activeSkillLevel,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      skillId: json['skill_id'] as int,
      trainedSkillLevel: json['trained_skill_level'] as int,
      skillpointsInSkill: json['skillpoints_in_skill'] as int,
      activeSkillLevel: json['active_skill_level'] as int,
    );
  }
}

/// Character attributes from ESI.
class CharacterAttributes {
  final int intelligence;
  final int memory;
  final int perception;
  final int willpower;
  final int charisma;
  final int? bonusRemaps;
  final DateTime? lastRemapDate;
  final DateTime? accruedRemapCooldownDate;

  const CharacterAttributes({
    required this.intelligence,
    required this.memory,
    required this.perception,
    required this.willpower,
    required this.charisma,
    this.bonusRemaps,
    this.lastRemapDate,
    this.accruedRemapCooldownDate,
  });

  factory CharacterAttributes.fromJson(Map<String, dynamic> json) {
    return CharacterAttributes(
      intelligence: json['intelligence'] as int,
      memory: json['memory'] as int,
      perception: json['perception'] as int,
      willpower: json['willpower'] as int,
      charisma: json['charisma'] as int,
      bonusRemaps: json['bonus_remaps'] as int?,
      lastRemapDate: json['last_remap_date'] != null
          ? DateTime.parse(json['last_remap_date'] as String)
          : null,
      accruedRemapCooldownDate: json['accrued_remap_cooldown_date'] != null
          ? DateTime.parse(json['accrued_remap_cooldown_date'] as String)
          : null,
    );
  }

  /// Calculates SP per hour for training a skill with given attributes.
  double spPerHour(int primaryAttribute, int secondaryAttribute) {
    final primary = _getAttributeValue(primaryAttribute);
    final secondary = _getAttributeValue(secondaryAttribute);
    return (primary + secondary / 2) * 60;
  }

  int _getAttributeValue(int attributeId) {
    switch (attributeId) {
      case 164: // Charisma
        return charisma;
      case 165: // Intelligence
        return intelligence;
      case 166: // Memory
        return memory;
      case 167: // Perception
        return perception;
      case 168: // Willpower
        return willpower;
      default:
        return 0;
    }
  }
}

/// Corporation information from ESI.
class CorporationInfo {
  final String name;
  final String ticker;
  final int memberCount;
  final int ceoId;
  final int? allianceId;
  final String? description;
  final DateTime? dateFounded;
  final int? homeStationId;
  final double? taxRate;
  final String? url;
  final bool? warEligible;

  const CorporationInfo({
    required this.name,
    required this.ticker,
    required this.memberCount,
    required this.ceoId,
    this.allianceId,
    this.description,
    this.dateFounded,
    this.homeStationId,
    this.taxRate,
    this.url,
    this.warEligible,
  });

  factory CorporationInfo.fromJson(Map<String, dynamic> json) {
    return CorporationInfo(
      name: json['name'] as String,
      ticker: json['ticker'] as String,
      memberCount: json['member_count'] as int,
      ceoId: json['ceo_id'] as int,
      allianceId: json['alliance_id'] as int?,
      description: json['description'] as String?,
      dateFounded: json['date_founded'] != null
          ? DateTime.parse(json['date_founded'] as String)
          : null,
      homeStationId: json['home_station_id'] as int?,
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
      url: json['url'] as String?,
      warEligible: json['war_eligible'] as bool?,
    );
  }
}

/// Alliance information from ESI.
class AllianceInfo {
  final String name;
  final String ticker;
  final int creatorCorporationId;
  final int creatorId;
  final DateTime dateFounded;
  final int? executorCorporationId;
  final int? factionId;

  const AllianceInfo({
    required this.name,
    required this.ticker,
    required this.creatorCorporationId,
    required this.creatorId,
    required this.dateFounded,
    this.executorCorporationId,
    this.factionId,
  });

  factory AllianceInfo.fromJson(Map<String, dynamic> json) {
    return AllianceInfo(
      name: json['name'] as String,
      ticker: json['ticker'] as String,
      creatorCorporationId: json['creator_corporation_id'] as int,
      creatorId: json['creator_id'] as int,
      dateFounded: DateTime.parse(json['date_founded'] as String),
      executorCorporationId: json['executor_corporation_id'] as int?,
      factionId: json['faction_id'] as int?,
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
  final String? reason;
  final int? contextId;
  final String? contextIdType;

  const WalletJournalItem({
    required this.id,
    required this.amount,
    required this.balance,
    required this.refType,
    this.firstPartyId,
    this.secondPartyId,
    this.description,
    required this.date,
    this.reason,
    this.contextId,
    this.contextIdType,
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
      reason: json['reason'] as String?,
      contextId: json['context_id'] as int?,
      contextIdType: json['context_id_type'] as String?,
    );
  }
}

/// Solar system information from ESI.
class SolarSystemInfo {
  final int systemId;
  final String name;
  final double securityStatus;
  final int? constellationId;
  final int? starId;

  const SolarSystemInfo({
    required this.systemId,
    required this.name,
    required this.securityStatus,
    this.constellationId,
    this.starId,
  });

  factory SolarSystemInfo.fromJson(Map<String, dynamic> json) {
    return SolarSystemInfo(
      systemId: json['system_id'] as int,
      name: json['name'] as String,
      securityStatus: (json['security_status'] as num).toDouble(),
      constellationId: json['constellation_id'] as int?,
      starId: json['star_id'] as int?,
    );
  }

  /// Returns true if this is high security space (≥0.5).
  bool get isHighSec => securityStatus >= 0.5;

  /// Returns true if this is low security space (0.0 to 0.5).
  bool get isLowSec => securityStatus > 0.0 && securityStatus < 0.5;

  /// Returns true if this is null security space (≤0.0).
  bool get isNullSec => securityStatus <= 0.0;
}

/// Character location from ESI.
class CharacterLocation {
  final int solarSystemId;
  final int? stationId;
  final int? structureId;

  const CharacterLocation({
    required this.solarSystemId,
    this.stationId,
    this.structureId,
  });

  factory CharacterLocation.fromJson(Map<String, dynamic> json) {
    return CharacterLocation(
      solarSystemId: json['solar_system_id'] as int,
      stationId: json['station_id'] as int?,
      structureId: json['structure_id'] as int?,
    );
  }
}

/// Character ship from ESI.
class CharacterShip {
  final int shipTypeId;
  final String? shipTypeName;
  final int shipItemId;

  const CharacterShip({
    required this.shipTypeId,
    this.shipTypeName,
    required this.shipItemId,
  });

  factory CharacterShip.fromJson(Map<String, dynamic> json) {
    return CharacterShip(
      shipTypeId: json['ship_type_id'] as int,
      // shipTypeName not in ESI response - must be looked up from SDE
      shipItemId: json['ship_item_id'] as int,
    );
  }
}

/// Character online status from ESI.
class CharacterOnline {
  final bool online;
  final DateTime? lastLogin;
  final DateTime? lastLogout;
  final int? logins;

  const CharacterOnline({
    required this.online,
    this.lastLogin,
    this.lastLogout,
    this.logins,
  });

  factory CharacterOnline.fromJson(Map<String, dynamic> json) {
    return CharacterOnline(
      online: json['online'] as bool,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
      lastLogout: json['last_logout'] != null
          ? DateTime.parse(json['last_logout'] as String)
          : null,
      logins: json['logins'] as int?,
    );
  }
}

/// Character clones from ESI.
class CharacterClones {
  final HomeLocation? homeLocation;
  final List<JumpClone> jumpClones;
  final DateTime? lastCloneJumpDate;
  final DateTime? lastStationChangeDate;

  const CharacterClones({
    this.homeLocation,
    required this.jumpClones,
    this.lastCloneJumpDate,
    this.lastStationChangeDate,
  });

  factory CharacterClones.fromJson(Map<String, dynamic> json) {
    return CharacterClones(
      homeLocation: json['home_location'] != null
          ? HomeLocation.fromJson(json['home_location'] as Map<String, dynamic>)
          : null,
      jumpClones: (json['jump_clones'] as List<dynamic>?)
              ?.map((item) => JumpClone.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      lastCloneJumpDate: json['last_clone_jump_date'] != null
          ? DateTime.parse(json['last_clone_jump_date'] as String)
          : null,
      lastStationChangeDate: json['last_station_change_date'] != null
          ? DateTime.parse(json['last_station_change_date'] as String)
          : null,
    );
  }
}

/// Home location information.
class HomeLocation {
  final int? locationId;
  final String locationType; // 'station' or 'structure'

  const HomeLocation({
    this.locationId,
    required this.locationType,
  });

  factory HomeLocation.fromJson(Map<String, dynamic> json) {
    return HomeLocation(
      locationId: json['location_id'] as int?,
      locationType: json['location_type'] as String,
    );
  }
}

/// Jump clone information.
class JumpClone {
  final int jumpCloneId;
  final int? locationId;
  final String locationType; // 'station' or 'structure'
  final List<int> implants;
  final String? name;

  const JumpClone({
    required this.jumpCloneId,
    this.locationId,
    required this.locationType,
    required this.implants,
    this.name,
  });

  factory JumpClone.fromJson(Map<String, dynamic> json) {
    return JumpClone(
      jumpCloneId: json['jump_clone_id'] as int,
      locationId: json['location_id'] as int?,
      locationType: json['location_type'] as String,
      implants: (json['implants'] as List<dynamic>?)?.cast<int>() ?? [],
      name: json['name'] as String?,
    );
  }
}

/// Standing with an NPC faction or corporation.
class Standing {
  final int fromId;
  final String fromType; // 'faction', 'npc_corp', or 'agent'
  final double standing;

  const Standing({
    required this.fromId,
    required this.fromType,
    required this.standing,
  });

  factory Standing.fromJson(Map<String, dynamic> json) {
    return Standing(
      fromId: json['from_id'] as int,
      fromType: json['from_type'] as String,
      standing: (json['standing'] as num).toDouble(),
    );
  }
}

/// Station information from ESI.
class StationInfo {
  final int stationId;
  final String name;
  final int systemId;
  final int? typeId;
  final int? ownerId;
  final double? maxDockableShipVolume;
  final int? officeRentalCost;
  final List<String>? services;
  final double? reprocessingEfficiency;
  final double? reprocessingStationsTake;

  const StationInfo({
    required this.stationId,
    required this.name,
    required this.systemId,
    this.typeId,
    this.ownerId,
    this.maxDockableShipVolume,
    this.officeRentalCost,
    this.services,
    this.reprocessingEfficiency,
    this.reprocessingStationsTake,
  });

  factory StationInfo.fromJson(Map<String, dynamic> json) {
    return StationInfo(
      stationId: json['station_id'] as int,
      name: json['name'] as String,
      systemId: json['system_id'] as int,
      typeId: json['type_id'] as int?,
      ownerId: json['owner'] as int?,
      maxDockableShipVolume:
          (json['max_dockable_ship_volume'] as num?)?.toDouble(),
      officeRentalCost: json['office_rental_cost'] as int?,
      services: (json['services'] as List<dynamic>?)?.cast<String>(),
      reprocessingEfficiency:
          (json['reprocessing_efficiency'] as num?)?.toDouble(),
      reprocessingStationsTake:
          (json['reprocessing_stations_take'] as num?)?.toDouble(),
    );
  }
}

/// Universe name resolution result.
class UniverseName {
  final int id;
  final String name;
  final String category; // 'character', 'corporation', 'alliance', 'faction', 'inventory_type', 'solar_system', 'station', etc.

  const UniverseName({
    required this.id,
    required this.name,
    required this.category,
  });

  factory UniverseName.fromJson(Map<String, dynamic> json) {
    return UniverseName(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
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

  /// Whether this error is a server error (5xx).
  bool get isServerError =>
      statusCode != null && statusCode! >= 500 && statusCode! < 600;

  /// Whether this error is a client error (4xx).
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;
}

/// Provider for the ESI client.
final esiClientProvider = Provider<EsiClient>((ref) {
  return EsiClient(
    tokenManager: ref.watch(tokenManagerProvider),
    oauthService: ref.watch(oauthServiceProvider),
  );
});
