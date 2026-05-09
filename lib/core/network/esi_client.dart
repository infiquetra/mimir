import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/oauth_service.dart';
import '../auth/token_manager.dart';
import '../config/eve_config.dart';
import '../database/app_database.dart';
import '../di/providers.dart';
import '../logging/logger.dart';

/// ESI API client for making requests to the EVE Online API.
class EsiClient {
  final Dio _dio;
  final TokenManager _tokenManager;
  final OAuthService _oauthService;
  final AppDatabase _database;

  int _errorLimitRemain = 100;
  DateTime? _errorLimitReset;
  StreamSubscription? _errorLimitSubscription;

  EsiClient({
    required TokenManager tokenManager,
    required OAuthService oauthService,
    required AppDatabase database,
    Dio? dio,
  })  : _tokenManager = tokenManager,
        _oauthService = oauthService,
        _database = database,
        _dio = dio ?? Dio() {
    _configureDio();
    _startWatchingErrorLimit();
  }

  void _startWatchingErrorLimit() {
    _errorLimitSubscription = _database.select(_database.appSettingsTable).watch().listen((settings) {
      if (settings.isNotEmpty) {
        _errorLimitRemain = settings.first.esiErrorLimitRemain;
        _errorLimitReset = settings.first.esiErrorLimitReset;
      }
    });
  }

  void dispose() {
    _errorLimitSubscription?.cancel();
  }

  void _configureDio() {
    _dio.options.baseUrl = EveConfig.esiBaseUrl;
    _dio.options.connectTimeout = const Duration(milliseconds: EveConfig.defaultTimeout);
    _dio.options.receiveTimeout = const Duration(milliseconds: EveConfig.defaultTimeout);
    _dio.options.queryParameters = {'datasource': EveConfig.datasource};
    _dio.interceptors.add(_EsiInterceptor(this));
  }

  Future<void> _updateErrorLimit(Response response) async {
    final remainHeader = response.headers.value('X-ESI-Error-Limit-Remain');
    final resetHeader = response.headers.value('X-ESI-Error-Limit-Reset');

    bool updated = false;
    if (remainHeader != null) {
      final parsed = int.tryParse(remainHeader);
      if (parsed != null && parsed != _errorLimitRemain) {
        _errorLimitRemain = parsed;
        updated = true;
      }
    }
    if (resetHeader != null) {
      final resetSeconds = int.tryParse(resetHeader);
      if (resetSeconds != null) {
        final newReset = DateTime.now().add(Duration(seconds: resetSeconds));
        if (_errorLimitReset == null || _errorLimitReset!.difference(newReset).inSeconds.abs() > 2) {
          _errorLimitReset = newReset;
          updated = true;
        }
      }
    }
    if (updated) {
      await _database.updateEsiErrorLimit(_errorLimitRemain, _errorLimitReset);
    }
  }

  int get errorLimitRemain => _errorLimitRemain;
  DateTime? get errorLimitReset => _errorLimitReset;
  bool get isNearRateLimit => _errorLimitRemain < 20;

  Future<Response<T>> authenticatedGet<T>(String path, {required int characterId, Map<String, dynamic>? queryParameters}) async {
    final accessToken = await _getValidAccessToken(characterId);
    return _dio.get<T>(path, queryParameters: queryParameters, options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
  }

  Future<Response<T>> authenticatedPost<T>(String path, {required int characterId, dynamic data}) async {
    final accessToken = await _getValidAccessToken(characterId);
    return _dio.post<T>(path, data: data, options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
  }

  Future<Response<T>> publicGet<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<String> _getValidAccessToken(int characterId) async {
    final tokens = await _tokenManager.getTokens(characterId);
    if (tokens == null) throw EsiException('No tokens found for character $characterId', statusCode: 401);
    if (tokens.isAccessTokenExpired || tokens.accessToken == null) {
      final newTokens = await _oauthService.refreshAccessToken(tokens.refreshToken);
      await _tokenManager.updateAccessToken(characterId: characterId, tokenResponse: newTokens);
      return newTokens.accessToken;
    }
    return tokens.accessToken!;
  }

  // Character API
  Future<CharacterPublicInfo> getCharacterPublicInfo(int characterId) async {
    final response = await publicGet<Map<String, dynamic>>('/characters/$characterId/');
    return CharacterPublicInfo.fromJson(response.data!);
  }

  String getCharacterPortraitUrl(int characterId, {int size = 128}) {
    return '${EveConfig.imageServerUrl}/characters/$characterId/portrait?size=$size';
  }

  // Skills API
  Future<CharacterSkills> getCharacterSkills(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/skills/', characterId: characterId);
    return CharacterSkills.fromJson(response.data!);
  }

  Future<CharacterSkills> getSkills(int characterId) async {
    return getCharacterSkills(characterId);
  }

  Future<List<SkillQueueItem>> getSkillQueue(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/skillqueue/', characterId: characterId);
    return (response.data ?? []).map((item) => SkillQueueItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<CharacterAttributes> getCharacterAttributes(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/attributes/', characterId: characterId);
    return CharacterAttributes.fromJson(response.data!);
  }

  // Wallet API
  Future<double> getWalletBalance(int characterId) async {
    final response = await authenticatedGet<double>('/characters/$characterId/wallet/', characterId: characterId);
    return response.data ?? 0.0;
  }

  Future<List<WalletJournalItem>> getWalletJournal(int characterId, {int page = 1}) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/wallet/journal/', characterId: characterId, queryParameters: {'page': page});
    return (response.data ?? []).map((item) => WalletJournalItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<WalletTransactionItem>> getWalletTransactions(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/wallet/transactions/', characterId: characterId);
    return (response.data ?? []).map((item) => WalletTransactionItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<LoyaltyPointItem>> getLoyaltyPoints(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/loyalty/points/', characterId: characterId);
    return (response.data ?? []).map((item) => LoyaltyPointItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<int> getPlexCount(int characterId) async {
    final response = await getCharacterAssets(characterId);
    final plexAsset = response.data.where((a) => a.typeId == 44992).firstOrNull;
    return plexAsset?.quantity ?? 0;
  }

  // Industry API
  Future<EsiResponse<List<BlueprintItem>>> getCharacterBlueprints(int characterId, {int page = 1}) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/blueprints/', characterId: characterId, queryParameters: {'page': page});
    final data = (response.data ?? []).map((item) => BlueprintItem.fromJson(item as Map<String, dynamic>)).toList();
    return EsiResponse(data: data, headers: response.headers.map, statusCode: response.statusCode);
  }

  Future<EsiResponse<List<IndustryJobData>>> getCharacterIndustryJobs(int characterId, {bool includeCompleted = false}) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/industry/jobs/', characterId: characterId, queryParameters: {'include_completed': includeCompleted});
    final data = (response.data ?? []).map((item) => IndustryJobData.fromJson(item as Map<String, dynamic>)).toList();
    return EsiResponse(data: data, headers: response.headers.map, statusCode: response.statusCode);
  }

  // Market API
  Future<EsiResponse<List<MarketPriceData>>> getMarketPrices() async {
    final response = await publicGet<List<dynamic>>('/markets/prices/');
    final data = (response.data ?? []).map((item) => MarketPriceData.fromJson(item as Map<String, dynamic>)).toList();
    return EsiResponse(data: data, headers: response.headers.map, statusCode: response.statusCode);
  }

  Future<EsiResponse<List<CharacterOrderData>>> getCharacterOrders(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/orders/', characterId: characterId);
    final data = (response.data ?? []).map((item) => CharacterOrderData.fromJson(item as Map<String, dynamic>)).toList();
    return EsiResponse(data: data, headers: response.headers.map, statusCode: response.statusCode);
  }

  // Assets API
  Future<EsiResponse<List<AssetItem>>> getCharacterAssets(int characterId, {int page = 1}) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/assets/', characterId: characterId, queryParameters: {'page': page});
    final data = (response.data ?? []).map((item) => AssetItem.fromJson(item as Map<String, dynamic>)).toList();
    return EsiResponse(data: data, headers: response.headers.map, statusCode: response.statusCode);
  }

  Future<List<EsiAssetName>> getCharacterAssetNames(int characterId, List<int> itemIds) async {
    if (itemIds.isEmpty) return [];
    final response = await authenticatedPost<List<dynamic>>('/characters/$characterId/assets/names/', characterId: characterId, data: itemIds);
    return (response.data ?? []).map((item) => EsiAssetName.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<EsiAssetLocation>> getCharacterAssetLocations(int characterId, List<int> itemIds) async {
    if (itemIds.isEmpty) return [];
    final response = await authenticatedPost<List<dynamic>>('/characters/$characterId/assets/locations/', characterId: characterId, data: itemIds);
    return (response.data ?? []).map((item) => EsiAssetLocation.fromJson(item as Map<String, dynamic>)).toList();
  }

  // PI API
  Future<List<EsiPlanetaryColony>> getCharacterPlanets(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/planets/', characterId: characterId);
    return (response.data ?? []).map((item) => EsiPlanetaryColony.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<EsiPlanetaryPin>> getCharacterPlanetPins(int characterId, int planetId) async {
    final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/planets/$planetId/', characterId: characterId);
    final pins = response.data?['pins'] as List<dynamic>?;
    return (pins ?? []).map((item) => EsiPlanetaryPin.fromJson(item as Map<String, dynamic>)).toList();
  }

  // Universe API
  Future<SolarSystemInfo> getSolarSystemInfo(int solarSystemId) async {
    final response = await publicGet<Map<String, dynamic>>('/universe/systems/$solarSystemId/');
    return SolarSystemInfo.fromJson(response.data!);
  }

  Future<StationInfo> getStationInfo(int stationId) async {
    final response = await publicGet<Map<String, dynamic>>('/universe/stations/$stationId/');
    return StationInfo.fromJson(response.data!);
  }

  Future<List<UniverseName>> getUniverseNames(List<int> ids) async {
    if (ids.isEmpty) return [];
    final response = await _dio.post<List<dynamic>>('/universe/names/', data: ids);
    return (response.data ?? []).map((item) => UniverseName.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<String?> getStructureName(int structureId, int characterId) async {
    try {
      final response = await authenticatedGet<Map<String, dynamic>>('/universe/structures/$structureId/', characterId: characterId);
      return response.data?['name'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return null;
      rethrow;
    }
  }

  // Corporation/Alliance API
  Future<CorporationInfo> getCorporationInfo(int corporationId) async {
    final response = await publicGet<Map<String, dynamic>>('/corporations/$corporationId/');
    return CorporationInfo.fromJson(response.data!);
  }

  String getCorporationLogoUrl(int corporationId, {int size = 128}) {
    return '${EveConfig.imageServerUrl}/corporations/$corporationId/logo?size=$size';
  }

  Future<AllianceInfo> getAllianceInfo(int allianceId) async {
    final response = await publicGet<Map<String, dynamic>>('/alliances/$allianceId/');
    return AllianceInfo.fromJson(response.data!);
  }

  String getAllianceLogoUrl(int allianceId, {int size = 128}) {
    return '${EveConfig.imageServerUrl}/alliances/$allianceId/logo?size=$size';
  }

  // Location/Status API
  Future<CharacterLocation?> getCharacterLocation(int characterId) async {
    try {
      final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/location/', characterId: characterId);
      return CharacterLocation.fromJson(response.data!);
    } on DioException { return null; }
  }

  Future<CharacterShip?> getCharacterShip(int characterId) async {
    try {
      final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/ship/', characterId: characterId);
      return CharacterShip.fromJson(response.data!);
    } on DioException { return null; }
  }

  Future<CharacterOnline> getCharacterOnline(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/online/', characterId: characterId);
    return CharacterOnline.fromJson(response.data!);
  }

  // Clones/Standings
  Future<CharacterClones> getCharacterClones(int characterId) async {
    final response = await authenticatedGet<Map<String, dynamic>>('/characters/$characterId/clones/', characterId: characterId);
    return CharacterClones.fromJson(response.data!);
  }

  Future<List<int>> getCharacterImplants(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/implants/', characterId: characterId);
    return (response.data ?? []).cast<int>();
  }

  Future<List<Standing>> getCharacterStandings(int characterId) async {
    final response = await authenticatedGet<List<dynamic>>('/characters/$characterId/standings/', characterId: characterId);
    return (response.data ?? []).map((item) => Standing.fromJson(item as Map<String, dynamic>)).toList();
  }
}

// Models
class CharacterPublicInfo {
  final String name;
  final int corporationId;
  final int? allianceId;
  final DateTime birthday;
  final double securityStatus;
  final String? description;
  final int? factionId;
  final String? title;

  CharacterPublicInfo({required this.name, required this.corporationId, this.allianceId, required this.birthday, required this.securityStatus, this.description, this.factionId, this.title});

  factory CharacterPublicInfo.fromJson(Map<String, dynamic> json) {
    return CharacterPublicInfo(
      name: json['name'] as String,
      corporationId: json['corporation_id'] as int,
      allianceId: json['alliance_id'] as int?,
      birthday: DateTime.parse(json['birthday'] as String),
      securityStatus: (json['security_status'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      factionId: json['faction_id'] as int?,
      title: json['title'] as String?,
    );
  }
}

class CharacterSkills {
  final List<SkillItem> skills;
  final int totalSp;
  final int? unallocatedSp;

  CharacterSkills({required this.skills, required this.totalSp, this.unallocatedSp});

  factory CharacterSkills.fromJson(Map<String, dynamic> json) {
    return CharacterSkills(
      skills: (json['skills'] as List<dynamic>? ?? []).map((s) => SkillItem.fromJson(s as Map<String, dynamic>)).toList(),
      totalSp: json['total_sp'] as int? ?? 0,
      unallocatedSp: json['unallocated_sp'] as int?,
    );
  }
}

class SkillItem {
  final int skillId;
  final int trainedSkillLevel;
  final int activeSkillLevel;
  final int skillpointsInSkill;

  SkillItem({required this.skillId, required this.trainedSkillLevel, required this.activeSkillLevel, required this.skillpointsInSkill});

  factory SkillItem.fromJson(Map<String, dynamic> json) {
    return SkillItem(
      skillId: json['skill_id'] as int,
      trainedSkillLevel: json['trained_skill_level'] as int,
      activeSkillLevel: json['active_skill_level'] as int,
      skillpointsInSkill: json['skillpoints_in_skill'] as int,
    );
  }
}

class Skill extends SkillItem {
  Skill({required super.skillId, required super.trainedSkillLevel, required super.activeSkillLevel, required super.skillpointsInSkill});
}

class SkillQueueItem {
  final int skillId;
  final int finishedLevel;
  final int queuePosition;
  final int? trainingStartSp;
  final int? levelStartSp;
  final int? levelEndSp;
  final DateTime? startDate;
  final DateTime? finishDate;

  SkillQueueItem({required this.skillId, required this.finishedLevel, required this.queuePosition, this.trainingStartSp, this.levelStartSp, this.levelEndSp, this.startDate, this.finishDate});

  factory SkillQueueItem.fromJson(Map<String, dynamic> json) {
    return SkillQueueItem(
      skillId: json['skill_id'] as int,
      finishedLevel: json['finished_level'] as int,
      queuePosition: json['queue_position'] as int,
      trainingStartSp: json['training_start_sp'] as int?,
      levelStartSp: json['level_start_sp'] as int?,
      levelEndSp: json['level_end_sp'] as int?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      finishDate: json['finish_date'] != null ? DateTime.parse(json['finish_date'] as String) : null,
    );
  }
}

class CharacterAttributes {
  final int intelligence;
  final int memory;
  final int perception;
  final int willpower;
  final int charisma;
  final int? bonusRemaps;
  final DateTime? lastRemapDate;
  final DateTime? accruedRemapCooldownDate;

  const CharacterAttributes({required this.intelligence, required this.memory, required this.perception, required this.willpower, required this.charisma, this.bonusRemaps, this.lastRemapDate, this.accruedRemapCooldownDate});

  factory CharacterAttributes.fromJson(Map<String, dynamic> json) {
    return CharacterAttributes(
      intelligence: json['intelligence'] as int,
      memory: json['memory'] as int,
      perception: json['perception'] as int,
      willpower: json['willpower'] as int,
      charisma: json['charisma'] as int,
      bonusRemaps: json['bonus_remaps'] as int?,
      lastRemapDate: json['last_remap_date'] != null ? DateTime.parse(json['last_remap_date'] as String) : null,
      accruedRemapCooldownDate: json['accrued_remap_cooldown_date'] != null ? DateTime.parse(json['accrued_remap_cooldown_date'] as String) : null,
    );
  }

  double spPerHour(int primaryAttrId, int secondaryAttrId) {
    final primary = _getAttributeValue(primaryAttrId);
    final secondary = _getAttributeValue(secondaryAttrId);
    return (primary + secondary / 2.0) * 60.0;
  }

  int _getAttributeValue(int attrId) {
    switch (attrId) {
      case 164: return charisma;
      case 165: return intelligence;
      case 166: return memory;
      case 167: return perception;
      case 168: return willpower;
      default: return 0;
    }
  }
}

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

  CorporationInfo({required this.name, required this.ticker, required this.memberCount, required this.ceoId, this.allianceId, this.description, this.dateFounded, this.homeStationId, this.taxRate, this.url, this.warEligible});

  factory CorporationInfo.fromJson(Map<String, dynamic> json) {
    return CorporationInfo(
      name: json['name'] as String,
      ticker: json['ticker'] as String,
      memberCount: json['member_count'] as int,
      ceoId: json['ceo_id'] as int,
      allianceId: json['alliance_id'] as int?,
      description: json['description'] as String?,
      dateFounded: json['date_founded'] != null ? DateTime.parse(json['date_founded'] as String) : null,
      homeStationId: json['home_station_id'] as int?,
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
      url: json['url'] as String?,
      warEligible: json['war_eligible'] as bool?,
    );
  }
}

class AllianceInfo {
  final String name;
  final String ticker;
  final int creatorCorporationId;
  final int creatorId;
  final DateTime dateFounded;
  final int executorCorporationId;
  final int? factionId;

  AllianceInfo({required this.name, required this.ticker, required this.creatorCorporationId, required this.creatorId, required this.dateFounded, required this.executorCorporationId, this.factionId});

  factory AllianceInfo.fromJson(Map<String, dynamic> json) {
    return AllianceInfo(
      name: json['name'] as String,
      ticker: json['ticker'] as String,
      creatorCorporationId: json['creator_corporation_id'] as int,
      creatorId: json['creator_id'] as int,
      dateFounded: DateTime.parse(json['date_founded'] as String),
      executorCorporationId: json['executor_corporation_id'] as int,
      factionId: json['faction_id'] as int?,
    );
  }
}

class WalletJournalItem {
  final int id;
  final String refType;
  final double amount;
  final double? balance;
  final DateTime date;
  final String description;
  final int? firstPartyId;
  final int? secondPartyId;
  final String? reason;
  final int? contextId;
  final String? contextIdType;

  WalletJournalItem({required this.id, required this.refType, required this.amount, this.balance, required this.date, required this.description, this.firstPartyId, this.secondPartyId, this.reason, this.contextId, this.contextIdType});

  factory WalletJournalItem.fromJson(Map<String, dynamic> json) {
    return WalletJournalItem(
      id: json['id'] as int,
      refType: json['ref_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      balance: (json['balance'] as num?)?.toDouble(),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String? ?? '',
      firstPartyId: json['first_party_id'] as int?,
      secondPartyId: json['second_party_id'] as int?,
      reason: json['reason'] as String?,
      contextId: json['context_id'] as int?,
      contextIdType: json['context_id_type'] as String?,
    );
  }
}

class WalletTransactionItem {
  final int transactionId;
  final int typeId;
  final int locationId;
  final int quantity;
  final double unitPrice;
  final bool isBuy;
  final DateTime date;
  final int clientId;
  final int? journalRefId;

  WalletTransactionItem({required this.transactionId, required this.typeId, required this.locationId, required this.quantity, required this.unitPrice, required this.isBuy, required this.date, required this.clientId, this.journalRefId});

  factory WalletTransactionItem.fromJson(Map<String, dynamic> json) {
    return WalletTransactionItem(
      transactionId: json['transaction_id'] as int,
      typeId: json['type_id'] as int,
      locationId: json['location_id'] as int,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      isBuy: json['is_buy'] as bool,
      date: DateTime.parse(json['date'] as String),
      clientId: json['client_id'] as int,
      journalRefId: json['journal_ref_id'] as int?,
    );
  }
}

class LoyaltyPointItem {
  final int corporationId;
  final int loyaltyPoints;

  LoyaltyPointItem({required this.corporationId, required this.loyaltyPoints});

  factory LoyaltyPointItem.fromJson(Map<String, dynamic> json) {
    return LoyaltyPointItem(
      corporationId: json['corporation_id'] as int,
      loyaltyPoints: json['loyalty_points'] as int,
    );
  }
}

class AssetItem {
  final int itemId;
  final int typeId;
  final int quantity;
  final int locationId;
  final String locationFlag;
  final bool isSingleton;

  const AssetItem({required this.itemId, required this.typeId, required this.quantity, required this.locationId, required this.locationFlag, required this.isSingleton});

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      itemId: json['item_id'] as int,
      typeId: json['type_id'] as int,
      quantity: json['quantity'] as int,
      locationId: json['location_id'] as int,
      locationFlag: json['location_flag'] as String,
      isSingleton: json['is_singleton'] as bool,
    );
  }
}

class EsiAssetName {
  final int itemId;
  final String name;
  const EsiAssetName({required this.itemId, required this.name});
  factory EsiAssetName.fromJson(Map<String, dynamic> json) {
    return EsiAssetName(itemId: json['item_id'] as int, name: json['name'] as String);
  }
}

class EsiAssetLocation {
  final int itemId;
  final double x;
  final double y;
  final double z;
  const EsiAssetLocation({required this.itemId, required this.x, required this.y, required this.z});
  factory EsiAssetLocation.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>;
    return EsiAssetLocation(itemId: json['item_id'] as int, x: (pos['x'] as num).toDouble(), y: (pos['y'] as num).toDouble(), z: (pos['z'] as num).toDouble());
  }
}

class EsiPlanetaryColony {
  final int planetId;
  final String planetType;
  final int solarSystemId;
  final DateTime lastUpdate;
  final int upgradeLevel;
  final int numPins;
  const EsiPlanetaryColony({required this.planetId, required this.planetType, required this.solarSystemId, required this.lastUpdate, required this.upgradeLevel, required this.numPins});
  factory EsiPlanetaryColony.fromJson(Map<String, dynamic> json) {
    return EsiPlanetaryColony(
      planetId: json['planet_id'] as int,
      planetType: json['planet_type'] as String,
      solarSystemId: json['solar_system_id'] as int,
      lastUpdate: DateTime.parse(json['last_update'] as String),
      upgradeLevel: json['upgrade_level'] as int,
      numPins: json['num_pins'] as int,
    );
  }
}

class EsiPlanetaryPin {
  final int pinId;
  final int typeId;
  final double latitude;
  final double longitude;
  final DateTime installTime;
  final DateTime? expiryTime;
  final int? productTypeId;
  final int? quantityPerCycle;
  final int? cycleTime;
  final int? schematicId;
  final DateTime? lastCycleStart;

  const EsiPlanetaryPin({required this.pinId, required this.typeId, required this.latitude, required this.longitude, required this.installTime, this.expiryTime, this.productTypeId, this.quantityPerCycle, this.cycleTime, this.schematicId, this.lastCycleStart});

  factory EsiPlanetaryPin.fromJson(Map<String, dynamic> json) {
    final extractorDetails = json['extractor_details'] as Map<String, dynamic>?;
    return EsiPlanetaryPin(
      pinId: json['pin_id'] as int,
      typeId: json['type_id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      installTime: DateTime.parse(json['install_time'] as String),
      expiryTime: json['expiry_time'] != null ? DateTime.parse(json['expiry_time'] as String) : null,
      productTypeId: extractorDetails?['product_type_id'] as int?,
      quantityPerCycle: extractorDetails?['qty_per_cycle'] as int?,
      cycleTime: extractorDetails?['cycle_time'] as int?,
      schematicId: json['schematic_id'] as int?,
      lastCycleStart: json['last_cycle_start'] != null ? DateTime.parse(json['last_cycle_start'] as String) : null,
    );
  }
}

class SolarSystemInfo {
  final int systemId;
  final String name;
  final double securityStatus;
  SolarSystemInfo({required this.systemId, required this.name, required this.securityStatus});
  factory SolarSystemInfo.fromJson(Map<String, dynamic> json) {
    return SolarSystemInfo(systemId: json['system_id'] as int, name: json['name'] as String, securityStatus: (json['security_status'] as num).toDouble());
  }
}

class StationInfo {
  final int stationId;
  final String name;
  final int systemId;
  StationInfo({required this.stationId, required this.name, required this.systemId});
  factory StationInfo.fromJson(Map<String, dynamic> json) {
    return StationInfo(stationId: json['station_id'] as int, name: json['name'] as String, systemId: json['system_id'] as int);
  }
}

class UniverseName {
  final int id;
  final String name;
  final String category;
  UniverseName({required this.id, required this.name, required this.category});
  factory UniverseName.fromJson(Map<String, dynamic> json) {
    return UniverseName(id: json['id'] as int, name: json['name'] as String, category: json['category'] as String);
  }
}

class CharacterLocation {
  final int solarSystemId;
  final int? stationId;
  final int? structureId;
  CharacterLocation({required this.solarSystemId, this.stationId, this.structureId});
  factory CharacterLocation.fromJson(Map<String, dynamic> json) {
    return CharacterLocation(solarSystemId: json['solar_system_id'] as int, stationId: json['station_id'] as int?, structureId: json['structure_id'] as int?);
  }
}

class CharacterShip {
  final int shipTypeId;
  final int shipItemId;
  final String? shipName;
  final String? shipTypeName;

  CharacterShip({required this.shipTypeId, required this.shipItemId, this.shipName, this.shipTypeName});

  factory CharacterShip.fromJson(Map<String, dynamic> json) {
    return CharacterShip(
      shipTypeId: json['ship_type_id'] as int,
      shipItemId: json['ship_item_id'] as int,
      shipName: json['ship_name'] as String?,
      shipTypeName: json['ship_type_name'] as String?,
    );
  }
}

class CharacterOnline {
  final bool online;
  final DateTime? lastLogin;
  final DateTime? lastLogout;
  final int? logins;
  CharacterOnline({required this.online, this.lastLogin, this.lastLogout, this.logins});
  factory CharacterOnline.fromJson(Map<String, dynamic> json) {
    return CharacterOnline(
      online: json['online'] as bool,
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login'] as String) : null,
      lastLogout: json['last_logout'] != null ? DateTime.parse(json['last_logout'] as String) : null,
      logins: json['logins'] as int?,
    );
  }
}

class CharacterClones {
  final List<JumpClone> jumpClones;
  final HomeLocation homeLocation;
  final DateTime? lastCloneJumpDate;
  final DateTime? lastStationChangeDate;

  CharacterClones({required this.jumpClones, required this.homeLocation, this.lastCloneJumpDate, this.lastStationChangeDate});

  factory CharacterClones.fromJson(Map<String, dynamic> json) {
    return CharacterClones(
      jumpClones: (json['jump_clones'] as List<dynamic>? ?? []).map((c) => JumpClone.fromJson(c as Map<String, dynamic>)).toList(),
      homeLocation: HomeLocation.fromJson(json['home_location'] as Map<String, dynamic>),
      lastCloneJumpDate: json['last_clone_jump_date'] != null ? DateTime.parse(json['last_clone_jump_date'] as String) : null,
      lastStationChangeDate: json['last_station_change_date'] != null ? DateTime.parse(json['last_station_change_date'] as String) : null,
    );
  }
}

class JumpClone {
  final int jumpCloneId;
  final int locationId;
  final String locationType;
  final List<int> implants;
  final String? name;
  JumpClone({required this.jumpCloneId, required this.locationId, required this.locationType, required this.implants, this.name});
  factory JumpClone.fromJson(Map<String, dynamic> json) {
    return JumpClone(
      jumpCloneId: json['jump_clone_id'] as int,
      locationId: json['location_id'] as int,
      locationType: json['location_type'] as String,
      implants: (json['implants'] as List<dynamic>? ?? []).cast<int>(),
      name: json['name'] as String?,
    );
  }
}

class HomeLocation {
  final int locationId;
  final String locationType;
  HomeLocation({required this.locationId, required this.locationType});
  factory HomeLocation.fromJson(Map<String, dynamic> json) {
    return HomeLocation(locationId: json['location_id'] as int, locationType: json['location_type'] as String);
  }
}

class Standing {
  final int fromId;
  final String fromType;
  final double standing;
  Standing({required this.fromId, required this.fromType, required this.standing});
  factory Standing.fromJson(Map<String, dynamic> json) {
    return Standing(fromId: json['from_id'] as int, fromType: json['from_type'] as String, standing: (json['standing'] as num).toDouble());
  }
}

class EsiResponse<T> {
  final T data;
  final Map<String, List<String>> headers;
  final int? statusCode;
  const EsiResponse({required this.data, required this.headers, this.statusCode});
}

class BlueprintItem {
  final int itemId;
  final int typeId;
  final int locationId;
  final String locationFlag;
  final int quantity;
  final int timeEfficiency;
  final int materialEfficiency;
  final int runs;
  final int? runsRemaining;

  BlueprintItem({
    required this.itemId,
    required this.typeId,
    required this.locationId,
    required this.locationFlag,
    required this.quantity,
    required this.timeEfficiency,
    required this.materialEfficiency,
    required this.runs,
    this.runsRemaining,
  });

  factory BlueprintItem.fromJson(Map<String, dynamic> json) {
    return BlueprintItem(
      itemId: json['item_id'] as int,
      typeId: json['type_id'] as int,
      locationId: json['location_id'] as int,
      locationFlag: json['location_flag'] as String,
      quantity: json['quantity'] as int,
      timeEfficiency: json['time_efficiency'] as int,
      materialEfficiency: json['material_efficiency'] as int,
      runs: json['runs'] as int,
      runsRemaining: json['runs_remaining'] as int?,
    );
  }
}

class IndustryJobData {
  final int jobId;
  final int installerId;
  final int facilityId;
  final int locationId;
  final int activityId;
  final int blueprintId;
  final int blueprintTypeId;
  final int outputLocationId;
  final int runs;
  final double? cost;
  final int? licensedProductionRuns;
  final double? probability;
  final int? productTypeId;
  final String status;
  final int duration;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? pauseDate;
  final DateTime? completedDate;
  final int? completedCharacterId;
  final int? successfulRuns;

  IndustryJobData({
    required this.jobId,
    required this.installerId,
    required this.facilityId,
    required this.locationId,
    required this.activityId,
    required this.blueprintId,
    required this.blueprintTypeId,
    required this.outputLocationId,
    required this.runs,
    this.cost,
    this.licensedProductionRuns,
    this.probability,
    this.productTypeId,
    required this.status,
    required this.duration,
    required this.startDate,
    required this.endDate,
    this.pauseDate,
    this.completedDate,
    this.completedCharacterId,
    this.successfulRuns,
  });

  factory IndustryJobData.fromJson(Map<String, dynamic> json) {
    return IndustryJobData(
      jobId: json['job_id'] as int,
      installerId: json['installer_id'] as int,
      facilityId: json['facility_id'] as int,
      locationId: json['location_id'] as int,
      activityId: json['activity_id'] as int,
      blueprintId: json['blueprint_id'] as int,
      blueprintTypeId: json['blueprint_type_id'] as int,
      outputLocationId: json['output_location_id'] as int,
      runs: json['runs'] as int,
      cost: (json['cost'] as num?)?.toDouble(),
      licensedProductionRuns: json['licensed_production_runs'] as int?,
      probability: (json['probability'] as num?)?.toDouble(),
      productTypeId: json['product_type_id'] as int?,
      status: json['status'] as String,
      duration: json['duration'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      pauseDate: json['pause_date'] != null ? DateTime.parse(json['pause_date'] as String) : null,
      completedDate: json['completed_date'] != null ? DateTime.parse(json['completed_date'] as String) : null,
      completedCharacterId: json['completed_character_id'] as int?,
      successfulRuns: json['successful_runs'] as int?,
    );
  }
}

class EsiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  const EsiException(this.message, {this.statusCode, this.errorCode});
  bool get isAuthError => statusCode == 401;
  bool get isScopeError => statusCode == 403;
  bool get isRateLimited => statusCode == 420 || statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500 && statusCode! < 600;
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
  @override
  String toString() => 'EsiException: $message (status: $statusCode)';
}

class MarketPriceData {
  final int typeId;
  final double? adjustedPrice;
  final double? averagePrice;

  MarketPriceData({
    required this.typeId,
    this.adjustedPrice,
    this.averagePrice,
  });

  factory MarketPriceData.fromJson(Map<String, dynamic> json) {
    return MarketPriceData(
      typeId: json['type_id'] as int,
      adjustedPrice: (json['adjusted_price'] as num?)?.toDouble(),
      averagePrice: (json['average_price'] as num?)?.toDouble(),
    );
  }
}

class CharacterOrderData {
  final int orderId;
  final int typeId;
  final int regionId;
  final int locationId;
  final double price;
  final int volumeRemain;
  final int volumeTotal;
  final int minVolume;
  final bool isBuyOrder;
  final DateTime issued;
  final int duration;
  final String range;
  final bool isCorporation;
  final double escrow;
  final String state;

  CharacterOrderData({
    required this.orderId,
    required this.typeId,
    required this.regionId,
    required this.locationId,
    required this.price,
    required this.volumeRemain,
    required this.volumeTotal,
    required this.minVolume,
    required this.isBuyOrder,
    required this.issued,
    required this.duration,
    required this.range,
    required this.isCorporation,
    required this.escrow,
    required this.state,
  });

  factory CharacterOrderData.fromJson(Map<String, dynamic> json) {
    return CharacterOrderData(
      orderId: json['order_id'] as int,
      typeId: json['type_id'] as int,
      regionId: json['region_id'] as int,
      locationId: json['location_id'] as int,
      price: (json['price'] as num).toDouble(),
      volumeRemain: json['volume_remain'] as int,
      volumeTotal: json['volume_total'] as int,
      minVolume: json['min_volume'] as int,
      isBuyOrder: json['is_buy_order'] as bool? ?? false,
      issued: DateTime.parse(json['issued'] as String),
      duration: json['duration'] as int,
      range: json['range'] as String,
      isCorporation: json['is_corporation'] as bool? ?? false,
      escrow: (json['escrow'] as num?)?.toDouble() ?? 0.0,
      state: json['state'] as String? ?? 'active',
    );
  }
}

class _EsiInterceptor extends Interceptor {
  final EsiClient _client;
  _EsiInterceptor(this._client);
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _client._updateErrorLimit(response);
    if (kDebugMode) debugPrint('ESI ${response.requestOptions.method} ${response.requestOptions.path} -> ${response.statusCode}');
    handler.next(response);
  }
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    String message;
    String? errorCode;
    if (data is Map<String, dynamic>) {
      message = data['error'] as String? ?? err.message ?? 'Unknown error';
      errorCode = data['error_code'] as String?;
    } else { message = err.message ?? 'Unknown error'; }
    debugPrint('ESI Error: $message (status: $statusCode, code: $errorCode)');
    if (err.response != null) _client._updateErrorLimit(err.response!);
    handler.reject(DioException(requestOptions: err.requestOptions, response: err.response, type: err.type, error: EsiException(message, statusCode: statusCode, errorCode: errorCode)));
  }
}

final esiClientProvider = Provider<EsiClient>((ref) {
  final client = EsiClient(tokenManager: ref.watch(tokenManagerProvider), oauthService: ref.watch(oauthServiceProvider), database: ref.watch(databaseProvider));
  ref.onDispose(() => client.dispose());
  return client;
});
