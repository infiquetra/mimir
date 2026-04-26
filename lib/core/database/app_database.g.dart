// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _corporationIdMeta =
      const VerificationMeta('corporationId');
  @override
  late final GeneratedColumn<int> corporationId = GeneratedColumn<int>(
      'corporation_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _corporationNameMeta =
      const VerificationMeta('corporationName');
  @override
  late final GeneratedColumn<String> corporationName = GeneratedColumn<String>(
      'corporation_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _allianceIdMeta =
      const VerificationMeta('allianceId');
  @override
  late final GeneratedColumn<int> allianceId = GeneratedColumn<int>(
      'alliance_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _allianceNameMeta =
      const VerificationMeta('allianceName');
  @override
  late final GeneratedColumn<String> allianceName = GeneratedColumn<String>(
      'alliance_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _factionIdMeta =
      const VerificationMeta('factionId');
  @override
  late final GeneratedColumn<int> factionId = GeneratedColumn<int>(
      'faction_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _securityStatusMeta =
      const VerificationMeta('securityStatus');
  @override
  late final GeneratedColumn<double> securityStatus = GeneratedColumn<double>(
      'security_status', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _portraitUrlMeta =
      const VerificationMeta('portraitUrl');
  @override
  late final GeneratedColumn<String> portraitUrl = GeneratedColumn<String>(
      'portrait_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _refreshTokenMeta =
      const VerificationMeta('refreshToken');
  @override
  late final GeneratedColumn<String> refreshToken = GeneratedColumn<String>(
      'refresh_token', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accessTokenMeta =
      const VerificationMeta('accessToken');
  @override
  late final GeneratedColumn<String> accessToken = GeneratedColumn<String>(
      'access_token', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tokenExpiryMeta =
      const VerificationMeta('tokenExpiry');
  @override
  late final GeneratedColumn<DateTime> tokenExpiry = GeneratedColumn<DateTime>(
      'token_expiry', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        characterId,
        name,
        corporationId,
        corporationName,
        allianceId,
        allianceName,
        factionId,
        securityStatus,
        portraitUrl,
        refreshToken,
        accessToken,
        tokenExpiry,
        lastUpdated,
        isActive
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(Insertable<Character> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('corporation_id')) {
      context.handle(
          _corporationIdMeta,
          corporationId.isAcceptableOrUnknown(
              data['corporation_id']!, _corporationIdMeta));
    } else if (isInserting) {
      context.missing(_corporationIdMeta);
    }
    if (data.containsKey('corporation_name')) {
      context.handle(
          _corporationNameMeta,
          corporationName.isAcceptableOrUnknown(
              data['corporation_name']!, _corporationNameMeta));
    } else if (isInserting) {
      context.missing(_corporationNameMeta);
    }
    if (data.containsKey('alliance_id')) {
      context.handle(
          _allianceIdMeta,
          allianceId.isAcceptableOrUnknown(
              data['alliance_id']!, _allianceIdMeta));
    }
    if (data.containsKey('alliance_name')) {
      context.handle(
          _allianceNameMeta,
          allianceName.isAcceptableOrUnknown(
              data['alliance_name']!, _allianceNameMeta));
    }
    if (data.containsKey('faction_id')) {
      context.handle(_factionIdMeta,
          factionId.isAcceptableOrUnknown(data['faction_id']!, _factionIdMeta));
    }
    if (data.containsKey('security_status')) {
      context.handle(
          _securityStatusMeta,
          securityStatus.isAcceptableOrUnknown(
              data['security_status']!, _securityStatusMeta));
    }
    if (data.containsKey('portrait_url')) {
      context.handle(
          _portraitUrlMeta,
          portraitUrl.isAcceptableOrUnknown(
              data['portrait_url']!, _portraitUrlMeta));
    } else if (isInserting) {
      context.missing(_portraitUrlMeta);
    }
    if (data.containsKey('refresh_token')) {
      context.handle(
          _refreshTokenMeta,
          refreshToken.isAcceptableOrUnknown(
              data['refresh_token']!, _refreshTokenMeta));
    }
    if (data.containsKey('access_token')) {
      context.handle(
          _accessTokenMeta,
          accessToken.isAcceptableOrUnknown(
              data['access_token']!, _accessTokenMeta));
    }
    if (data.containsKey('token_expiry')) {
      context.handle(
          _tokenExpiryMeta,
          tokenExpiry.isAcceptableOrUnknown(
              data['token_expiry']!, _tokenExpiryMeta));
    } else if (isInserting) {
      context.missing(_tokenExpiryMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {characterId};
  @override
  Character map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Character(
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      corporationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}corporation_id'])!,
      corporationName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}corporation_name'])!,
      allianceId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}alliance_id']),
      allianceName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alliance_name']),
      factionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}faction_id']),
      securityStatus: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}security_status'])!,
      portraitUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}portrait_url'])!,
      refreshToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}refresh_token']),
      accessToken: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}access_token']),
      tokenExpiry: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}token_expiry'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  /// EVE character ID (primary key).
  final int characterId;

  /// Character name.
  final String name;

  /// Corporation ID the character belongs to.
  final int corporationId;

  /// Corporation name (cached for display).
  final String corporationName;

  /// Alliance ID (null if not in an alliance).
  final int? allianceId;

  /// Alliance name (null if not in an alliance).
  final String? allianceName;

  /// Faction ID (null if not in a faction warfare corp).
  final int? factionId;

  /// Character security status (-10 to +10).
  final double securityStatus;

  /// URL to character portrait image.
  final String portraitUrl;

  /// OAuth refresh token for this character.
  final String? refreshToken;

  /// Current OAuth access token (cached).
  final String? accessToken;

  /// When the OAuth token expires.
  final DateTime tokenExpiry;

  /// Last time character data was refreshed from ESI.
  final DateTime lastUpdated;

  /// Whether this is the currently active character.
  final bool isActive;
  const Character(
      {required this.characterId,
      required this.name,
      required this.corporationId,
      required this.corporationName,
      this.allianceId,
      this.allianceName,
      this.factionId,
      required this.securityStatus,
      required this.portraitUrl,
      this.refreshToken,
      this.accessToken,
      required this.tokenExpiry,
      required this.lastUpdated,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['character_id'] = Variable<int>(characterId);
    map['name'] = Variable<String>(name);
    map['corporation_id'] = Variable<int>(corporationId);
    map['corporation_name'] = Variable<String>(corporationName);
    if (!nullToAbsent || allianceId != null) {
      map['alliance_id'] = Variable<int>(allianceId);
    }
    if (!nullToAbsent || allianceName != null) {
      map['alliance_name'] = Variable<String>(allianceName);
    }
    if (!nullToAbsent || factionId != null) {
      map['faction_id'] = Variable<int>(factionId);
    }
    map['security_status'] = Variable<double>(securityStatus);
    map['portrait_url'] = Variable<String>(portraitUrl);
    if (!nullToAbsent || refreshToken != null) {
      map['refresh_token'] = Variable<String>(refreshToken);
    }
    if (!nullToAbsent || accessToken != null) {
      map['access_token'] = Variable<String>(accessToken);
    }
    map['token_expiry'] = Variable<DateTime>(tokenExpiry);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      characterId: Value(characterId),
      name: Value(name),
      corporationId: Value(corporationId),
      corporationName: Value(corporationName),
      allianceId: allianceId == null && nullToAbsent
          ? const Value.absent()
          : Value(allianceId),
      allianceName: allianceName == null && nullToAbsent
          ? const Value.absent()
          : Value(allianceName),
      factionId: factionId == null && nullToAbsent
          ? const Value.absent()
          : Value(factionId),
      securityStatus: Value(securityStatus),
      portraitUrl: Value(portraitUrl),
      refreshToken: refreshToken == null && nullToAbsent
          ? const Value.absent()
          : Value(refreshToken),
      accessToken: accessToken == null && nullToAbsent
          ? const Value.absent()
          : Value(accessToken),
      tokenExpiry: Value(tokenExpiry),
      lastUpdated: Value(lastUpdated),
      isActive: Value(isActive),
    );
  }

  factory Character.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      characterId: serializer.fromJson<int>(json['characterId']),
      name: serializer.fromJson<String>(json['name']),
      corporationId: serializer.fromJson<int>(json['corporationId']),
      corporationName: serializer.fromJson<String>(json['corporationName']),
      allianceId: serializer.fromJson<int?>(json['allianceId']),
      allianceName: serializer.fromJson<String?>(json['allianceName']),
      factionId: serializer.fromJson<int?>(json['factionId']),
      securityStatus: serializer.fromJson<double>(json['securityStatus']),
      portraitUrl: serializer.fromJson<String>(json['portraitUrl']),
      refreshToken: serializer.fromJson<String?>(json['refreshToken']),
      accessToken: serializer.fromJson<String?>(json['accessToken']),
      tokenExpiry: serializer.fromJson<DateTime>(json['tokenExpiry']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'characterId': serializer.toJson<int>(characterId),
      'name': serializer.toJson<String>(name),
      'corporationId': serializer.toJson<int>(corporationId),
      'corporationName': serializer.toJson<String>(corporationName),
      'allianceId': serializer.toJson<int?>(allianceId),
      'allianceName': serializer.toJson<String?>(allianceName),
      'factionId': serializer.toJson<int?>(factionId),
      'securityStatus': serializer.toJson<double>(securityStatus),
      'portraitUrl': serializer.toJson<String>(portraitUrl),
      'refreshToken': serializer.toJson<String?>(refreshToken),
      'accessToken': serializer.toJson<String?>(accessToken),
      'tokenExpiry': serializer.toJson<DateTime>(tokenExpiry),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Character copyWith(
          {int? characterId,
          String? name,
          int? corporationId,
          String? corporationName,
          Value<int?> allianceId = const Value.absent(),
          Value<String?> allianceName = const Value.absent(),
          Value<int?> factionId = const Value.absent(),
          double? securityStatus,
          String? portraitUrl,
          Value<String?> refreshToken = const Value.absent(),
          Value<String?> accessToken = const Value.absent(),
          DateTime? tokenExpiry,
          DateTime? lastUpdated,
          bool? isActive}) =>
      Character(
        characterId: characterId ?? this.characterId,
        name: name ?? this.name,
        corporationId: corporationId ?? this.corporationId,
        corporationName: corporationName ?? this.corporationName,
        allianceId: allianceId.present ? allianceId.value : this.allianceId,
        allianceName:
            allianceName.present ? allianceName.value : this.allianceName,
        factionId: factionId.present ? factionId.value : this.factionId,
        securityStatus: securityStatus ?? this.securityStatus,
        portraitUrl: portraitUrl ?? this.portraitUrl,
        refreshToken:
            refreshToken.present ? refreshToken.value : this.refreshToken,
        accessToken: accessToken.present ? accessToken.value : this.accessToken,
        tokenExpiry: tokenExpiry ?? this.tokenExpiry,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        isActive: isActive ?? this.isActive,
      );
  Character copyWithCompanion(CharactersCompanion data) {
    return Character(
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      name: data.name.present ? data.name.value : this.name,
      corporationId: data.corporationId.present
          ? data.corporationId.value
          : this.corporationId,
      corporationName: data.corporationName.present
          ? data.corporationName.value
          : this.corporationName,
      allianceId:
          data.allianceId.present ? data.allianceId.value : this.allianceId,
      allianceName: data.allianceName.present
          ? data.allianceName.value
          : this.allianceName,
      factionId: data.factionId.present ? data.factionId.value : this.factionId,
      securityStatus: data.securityStatus.present
          ? data.securityStatus.value
          : this.securityStatus,
      portraitUrl:
          data.portraitUrl.present ? data.portraitUrl.value : this.portraitUrl,
      refreshToken: data.refreshToken.present
          ? data.refreshToken.value
          : this.refreshToken,
      accessToken:
          data.accessToken.present ? data.accessToken.value : this.accessToken,
      tokenExpiry:
          data.tokenExpiry.present ? data.tokenExpiry.value : this.tokenExpiry,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Character(')
          ..write('characterId: $characterId, ')
          ..write('name: $name, ')
          ..write('corporationId: $corporationId, ')
          ..write('corporationName: $corporationName, ')
          ..write('allianceId: $allianceId, ')
          ..write('allianceName: $allianceName, ')
          ..write('factionId: $factionId, ')
          ..write('securityStatus: $securityStatus, ')
          ..write('portraitUrl: $portraitUrl, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('accessToken: $accessToken, ')
          ..write('tokenExpiry: $tokenExpiry, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      characterId,
      name,
      corporationId,
      corporationName,
      allianceId,
      allianceName,
      factionId,
      securityStatus,
      portraitUrl,
      refreshToken,
      accessToken,
      tokenExpiry,
      lastUpdated,
      isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Character &&
          other.characterId == this.characterId &&
          other.name == this.name &&
          other.corporationId == this.corporationId &&
          other.corporationName == this.corporationName &&
          other.allianceId == this.allianceId &&
          other.allianceName == this.allianceName &&
          other.factionId == this.factionId &&
          other.securityStatus == this.securityStatus &&
          other.portraitUrl == this.portraitUrl &&
          other.refreshToken == this.refreshToken &&
          other.accessToken == this.accessToken &&
          other.tokenExpiry == this.tokenExpiry &&
          other.lastUpdated == this.lastUpdated &&
          other.isActive == this.isActive);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<int> characterId;
  final Value<String> name;
  final Value<int> corporationId;
  final Value<String> corporationName;
  final Value<int?> allianceId;
  final Value<String?> allianceName;
  final Value<int?> factionId;
  final Value<double> securityStatus;
  final Value<String> portraitUrl;
  final Value<String?> refreshToken;
  final Value<String?> accessToken;
  final Value<DateTime> tokenExpiry;
  final Value<DateTime> lastUpdated;
  final Value<bool> isActive;
  const CharactersCompanion({
    this.characterId = const Value.absent(),
    this.name = const Value.absent(),
    this.corporationId = const Value.absent(),
    this.corporationName = const Value.absent(),
    this.allianceId = const Value.absent(),
    this.allianceName = const Value.absent(),
    this.factionId = const Value.absent(),
    this.securityStatus = const Value.absent(),
    this.portraitUrl = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.tokenExpiry = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  CharactersCompanion.insert({
    this.characterId = const Value.absent(),
    required String name,
    required int corporationId,
    required String corporationName,
    this.allianceId = const Value.absent(),
    this.allianceName = const Value.absent(),
    this.factionId = const Value.absent(),
    this.securityStatus = const Value.absent(),
    required String portraitUrl,
    this.refreshToken = const Value.absent(),
    this.accessToken = const Value.absent(),
    required DateTime tokenExpiry,
    required DateTime lastUpdated,
    this.isActive = const Value.absent(),
  })  : name = Value(name),
        corporationId = Value(corporationId),
        corporationName = Value(corporationName),
        portraitUrl = Value(portraitUrl),
        tokenExpiry = Value(tokenExpiry),
        lastUpdated = Value(lastUpdated);
  static Insertable<Character> custom({
    Expression<int>? characterId,
    Expression<String>? name,
    Expression<int>? corporationId,
    Expression<String>? corporationName,
    Expression<int>? allianceId,
    Expression<String>? allianceName,
    Expression<int>? factionId,
    Expression<double>? securityStatus,
    Expression<String>? portraitUrl,
    Expression<String>? refreshToken,
    Expression<String>? accessToken,
    Expression<DateTime>? tokenExpiry,
    Expression<DateTime>? lastUpdated,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (characterId != null) 'character_id': characterId,
      if (name != null) 'name': name,
      if (corporationId != null) 'corporation_id': corporationId,
      if (corporationName != null) 'corporation_name': corporationName,
      if (allianceId != null) 'alliance_id': allianceId,
      if (allianceName != null) 'alliance_name': allianceName,
      if (factionId != null) 'faction_id': factionId,
      if (securityStatus != null) 'security_status': securityStatus,
      if (portraitUrl != null) 'portrait_url': portraitUrl,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (accessToken != null) 'access_token': accessToken,
      if (tokenExpiry != null) 'token_expiry': tokenExpiry,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (isActive != null) 'is_active': isActive,
    });
  }

  CharactersCompanion copyWith(
      {Value<int>? characterId,
      Value<String>? name,
      Value<int>? corporationId,
      Value<String>? corporationName,
      Value<int?>? allianceId,
      Value<String?>? allianceName,
      Value<int?>? factionId,
      Value<double>? securityStatus,
      Value<String>? portraitUrl,
      Value<String?>? refreshToken,
      Value<String?>? accessToken,
      Value<DateTime>? tokenExpiry,
      Value<DateTime>? lastUpdated,
      Value<bool>? isActive}) {
    return CharactersCompanion(
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      corporationId: corporationId ?? this.corporationId,
      corporationName: corporationName ?? this.corporationName,
      allianceId: allianceId ?? this.allianceId,
      allianceName: allianceName ?? this.allianceName,
      factionId: factionId ?? this.factionId,
      securityStatus: securityStatus ?? this.securityStatus,
      portraitUrl: portraitUrl ?? this.portraitUrl,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: accessToken ?? this.accessToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (corporationId.present) {
      map['corporation_id'] = Variable<int>(corporationId.value);
    }
    if (corporationName.present) {
      map['corporation_name'] = Variable<String>(corporationName.value);
    }
    if (allianceId.present) {
      map['alliance_id'] = Variable<int>(allianceId.value);
    }
    if (allianceName.present) {
      map['alliance_name'] = Variable<String>(allianceName.value);
    }
    if (factionId.present) {
      map['faction_id'] = Variable<int>(factionId.value);
    }
    if (securityStatus.present) {
      map['security_status'] = Variable<double>(securityStatus.value);
    }
    if (portraitUrl.present) {
      map['portrait_url'] = Variable<String>(portraitUrl.value);
    }
    if (refreshToken.present) {
      map['refresh_token'] = Variable<String>(refreshToken.value);
    }
    if (accessToken.present) {
      map['access_token'] = Variable<String>(accessToken.value);
    }
    if (tokenExpiry.present) {
      map['token_expiry'] = Variable<DateTime>(tokenExpiry.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersCompanion(')
          ..write('characterId: $characterId, ')
          ..write('name: $name, ')
          ..write('corporationId: $corporationId, ')
          ..write('corporationName: $corporationName, ')
          ..write('allianceId: $allianceId, ')
          ..write('allianceName: $allianceName, ')
          ..write('factionId: $factionId, ')
          ..write('securityStatus: $securityStatus, ')
          ..write('portraitUrl: $portraitUrl, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('accessToken: $accessToken, ')
          ..write('tokenExpiry: $tokenExpiry, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $SkillQueueEntriesTable extends SkillQueueEntries
    with TableInfo<$SkillQueueEntriesTable, SkillQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _queuePositionMeta =
      const VerificationMeta('queuePosition');
  @override
  late final GeneratedColumn<int> queuePosition = GeneratedColumn<int>(
      'queue_position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<int> skillId = GeneratedColumn<int>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _finishedLevelMeta =
      const VerificationMeta('finishedLevel');
  @override
  late final GeneratedColumn<int> finishedLevel = GeneratedColumn<int>(
      'finished_level', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _finishDateMeta =
      const VerificationMeta('finishDate');
  @override
  late final GeneratedColumn<DateTime> finishDate = GeneratedColumn<DateTime>(
      'finish_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _trainingStartSpMeta =
      const VerificationMeta('trainingStartSp');
  @override
  late final GeneratedColumn<int> trainingStartSp = GeneratedColumn<int>(
      'training_start_sp', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _levelEndSpMeta =
      const VerificationMeta('levelEndSp');
  @override
  late final GeneratedColumn<int> levelEndSp = GeneratedColumn<int>(
      'level_end_sp', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _levelStartSpMeta =
      const VerificationMeta('levelStartSp');
  @override
  late final GeneratedColumn<int> levelStartSp = GeneratedColumn<int>(
      'level_start_sp', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        characterId,
        queuePosition,
        skillId,
        finishedLevel,
        startDate,
        finishDate,
        trainingStartSp,
        levelEndSp,
        levelStartSp
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skill_queue_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SkillQueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('queue_position')) {
      context.handle(
          _queuePositionMeta,
          queuePosition.isAcceptableOrUnknown(
              data['queue_position']!, _queuePositionMeta));
    } else if (isInserting) {
      context.missing(_queuePositionMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('finished_level')) {
      context.handle(
          _finishedLevelMeta,
          finishedLevel.isAcceptableOrUnknown(
              data['finished_level']!, _finishedLevelMeta));
    } else if (isInserting) {
      context.missing(_finishedLevelMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    }
    if (data.containsKey('finish_date')) {
      context.handle(
          _finishDateMeta,
          finishDate.isAcceptableOrUnknown(
              data['finish_date']!, _finishDateMeta));
    }
    if (data.containsKey('training_start_sp')) {
      context.handle(
          _trainingStartSpMeta,
          trainingStartSp.isAcceptableOrUnknown(
              data['training_start_sp']!, _trainingStartSpMeta));
    }
    if (data.containsKey('level_end_sp')) {
      context.handle(
          _levelEndSpMeta,
          levelEndSp.isAcceptableOrUnknown(
              data['level_end_sp']!, _levelEndSpMeta));
    }
    if (data.containsKey('level_start_sp')) {
      context.handle(
          _levelStartSpMeta,
          levelStartSp.isAcceptableOrUnknown(
              data['level_start_sp']!, _levelStartSpMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SkillQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SkillQueueEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      queuePosition: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}queue_position'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}skill_id'])!,
      finishedLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}finished_level'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date']),
      finishDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}finish_date']),
      trainingStartSp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}training_start_sp']),
      levelEndSp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level_end_sp']),
      levelStartSp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level_start_sp']),
    );
  }

  @override
  $SkillQueueEntriesTable createAlias(String alias) {
    return $SkillQueueEntriesTable(attachedDatabase, alias);
  }
}

class SkillQueueEntry extends DataClass implements Insertable<SkillQueueEntry> {
  /// Auto-incrementing ID for this queue entry.
  final int id;

  /// Character ID this queue entry belongs to.
  final int characterId;

  /// Position in the training queue (0 = currently training).
  final int queuePosition;

  /// Skill type ID from EVE SDE.
  final int skillId;

  /// Target level being trained (1-5).
  final int finishedLevel;

  /// When training started for this skill.
  final DateTime? startDate;

  /// When training will complete.
  final DateTime? finishDate;

  /// Training start skill points.
  final int? trainingStartSp;

  /// Skill points at completion.
  final int? levelEndSp;

  /// Skill points when this level started.
  final int? levelStartSp;
  const SkillQueueEntry(
      {required this.id,
      required this.characterId,
      required this.queuePosition,
      required this.skillId,
      required this.finishedLevel,
      this.startDate,
      this.finishDate,
      this.trainingStartSp,
      this.levelEndSp,
      this.levelStartSp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['queue_position'] = Variable<int>(queuePosition);
    map['skill_id'] = Variable<int>(skillId);
    map['finished_level'] = Variable<int>(finishedLevel);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || finishDate != null) {
      map['finish_date'] = Variable<DateTime>(finishDate);
    }
    if (!nullToAbsent || trainingStartSp != null) {
      map['training_start_sp'] = Variable<int>(trainingStartSp);
    }
    if (!nullToAbsent || levelEndSp != null) {
      map['level_end_sp'] = Variable<int>(levelEndSp);
    }
    if (!nullToAbsent || levelStartSp != null) {
      map['level_start_sp'] = Variable<int>(levelStartSp);
    }
    return map;
  }

  SkillQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return SkillQueueEntriesCompanion(
      id: Value(id),
      characterId: Value(characterId),
      queuePosition: Value(queuePosition),
      skillId: Value(skillId),
      finishedLevel: Value(finishedLevel),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      finishDate: finishDate == null && nullToAbsent
          ? const Value.absent()
          : Value(finishDate),
      trainingStartSp: trainingStartSp == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingStartSp),
      levelEndSp: levelEndSp == null && nullToAbsent
          ? const Value.absent()
          : Value(levelEndSp),
      levelStartSp: levelStartSp == null && nullToAbsent
          ? const Value.absent()
          : Value(levelStartSp),
    );
  }

  factory SkillQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SkillQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      queuePosition: serializer.fromJson<int>(json['queuePosition']),
      skillId: serializer.fromJson<int>(json['skillId']),
      finishedLevel: serializer.fromJson<int>(json['finishedLevel']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      finishDate: serializer.fromJson<DateTime?>(json['finishDate']),
      trainingStartSp: serializer.fromJson<int?>(json['trainingStartSp']),
      levelEndSp: serializer.fromJson<int?>(json['levelEndSp']),
      levelStartSp: serializer.fromJson<int?>(json['levelStartSp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'queuePosition': serializer.toJson<int>(queuePosition),
      'skillId': serializer.toJson<int>(skillId),
      'finishedLevel': serializer.toJson<int>(finishedLevel),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'finishDate': serializer.toJson<DateTime?>(finishDate),
      'trainingStartSp': serializer.toJson<int?>(trainingStartSp),
      'levelEndSp': serializer.toJson<int?>(levelEndSp),
      'levelStartSp': serializer.toJson<int?>(levelStartSp),
    };
  }

  SkillQueueEntry copyWith(
          {int? id,
          int? characterId,
          int? queuePosition,
          int? skillId,
          int? finishedLevel,
          Value<DateTime?> startDate = const Value.absent(),
          Value<DateTime?> finishDate = const Value.absent(),
          Value<int?> trainingStartSp = const Value.absent(),
          Value<int?> levelEndSp = const Value.absent(),
          Value<int?> levelStartSp = const Value.absent()}) =>
      SkillQueueEntry(
        id: id ?? this.id,
        characterId: characterId ?? this.characterId,
        queuePosition: queuePosition ?? this.queuePosition,
        skillId: skillId ?? this.skillId,
        finishedLevel: finishedLevel ?? this.finishedLevel,
        startDate: startDate.present ? startDate.value : this.startDate,
        finishDate: finishDate.present ? finishDate.value : this.finishDate,
        trainingStartSp: trainingStartSp.present
            ? trainingStartSp.value
            : this.trainingStartSp,
        levelEndSp: levelEndSp.present ? levelEndSp.value : this.levelEndSp,
        levelStartSp:
            levelStartSp.present ? levelStartSp.value : this.levelStartSp,
      );
  SkillQueueEntry copyWithCompanion(SkillQueueEntriesCompanion data) {
    return SkillQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      queuePosition: data.queuePosition.present
          ? data.queuePosition.value
          : this.queuePosition,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      finishedLevel: data.finishedLevel.present
          ? data.finishedLevel.value
          : this.finishedLevel,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      finishDate:
          data.finishDate.present ? data.finishDate.value : this.finishDate,
      trainingStartSp: data.trainingStartSp.present
          ? data.trainingStartSp.value
          : this.trainingStartSp,
      levelEndSp:
          data.levelEndSp.present ? data.levelEndSp.value : this.levelEndSp,
      levelStartSp: data.levelStartSp.present
          ? data.levelStartSp.value
          : this.levelStartSp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SkillQueueEntry(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('queuePosition: $queuePosition, ')
          ..write('skillId: $skillId, ')
          ..write('finishedLevel: $finishedLevel, ')
          ..write('startDate: $startDate, ')
          ..write('finishDate: $finishDate, ')
          ..write('trainingStartSp: $trainingStartSp, ')
          ..write('levelEndSp: $levelEndSp, ')
          ..write('levelStartSp: $levelStartSp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      characterId,
      queuePosition,
      skillId,
      finishedLevel,
      startDate,
      finishDate,
      trainingStartSp,
      levelEndSp,
      levelStartSp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillQueueEntry &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.queuePosition == this.queuePosition &&
          other.skillId == this.skillId &&
          other.finishedLevel == this.finishedLevel &&
          other.startDate == this.startDate &&
          other.finishDate == this.finishDate &&
          other.trainingStartSp == this.trainingStartSp &&
          other.levelEndSp == this.levelEndSp &&
          other.levelStartSp == this.levelStartSp);
}

class SkillQueueEntriesCompanion extends UpdateCompanion<SkillQueueEntry> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<int> queuePosition;
  final Value<int> skillId;
  final Value<int> finishedLevel;
  final Value<DateTime?> startDate;
  final Value<DateTime?> finishDate;
  final Value<int?> trainingStartSp;
  final Value<int?> levelEndSp;
  final Value<int?> levelStartSp;
  const SkillQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.queuePosition = const Value.absent(),
    this.skillId = const Value.absent(),
    this.finishedLevel = const Value.absent(),
    this.startDate = const Value.absent(),
    this.finishDate = const Value.absent(),
    this.trainingStartSp = const Value.absent(),
    this.levelEndSp = const Value.absent(),
    this.levelStartSp = const Value.absent(),
  });
  SkillQueueEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required int queuePosition,
    required int skillId,
    required int finishedLevel,
    this.startDate = const Value.absent(),
    this.finishDate = const Value.absent(),
    this.trainingStartSp = const Value.absent(),
    this.levelEndSp = const Value.absent(),
    this.levelStartSp = const Value.absent(),
  })  : characterId = Value(characterId),
        queuePosition = Value(queuePosition),
        skillId = Value(skillId),
        finishedLevel = Value(finishedLevel);
  static Insertable<SkillQueueEntry> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<int>? queuePosition,
    Expression<int>? skillId,
    Expression<int>? finishedLevel,
    Expression<DateTime>? startDate,
    Expression<DateTime>? finishDate,
    Expression<int>? trainingStartSp,
    Expression<int>? levelEndSp,
    Expression<int>? levelStartSp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (queuePosition != null) 'queue_position': queuePosition,
      if (skillId != null) 'skill_id': skillId,
      if (finishedLevel != null) 'finished_level': finishedLevel,
      if (startDate != null) 'start_date': startDate,
      if (finishDate != null) 'finish_date': finishDate,
      if (trainingStartSp != null) 'training_start_sp': trainingStartSp,
      if (levelEndSp != null) 'level_end_sp': levelEndSp,
      if (levelStartSp != null) 'level_start_sp': levelStartSp,
    });
  }

  SkillQueueEntriesCompanion copyWith(
      {Value<int>? id,
      Value<int>? characterId,
      Value<int>? queuePosition,
      Value<int>? skillId,
      Value<int>? finishedLevel,
      Value<DateTime?>? startDate,
      Value<DateTime?>? finishDate,
      Value<int?>? trainingStartSp,
      Value<int?>? levelEndSp,
      Value<int?>? levelStartSp}) {
    return SkillQueueEntriesCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      queuePosition: queuePosition ?? this.queuePosition,
      skillId: skillId ?? this.skillId,
      finishedLevel: finishedLevel ?? this.finishedLevel,
      startDate: startDate ?? this.startDate,
      finishDate: finishDate ?? this.finishDate,
      trainingStartSp: trainingStartSp ?? this.trainingStartSp,
      levelEndSp: levelEndSp ?? this.levelEndSp,
      levelStartSp: levelStartSp ?? this.levelStartSp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (queuePosition.present) {
      map['queue_position'] = Variable<int>(queuePosition.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<int>(skillId.value);
    }
    if (finishedLevel.present) {
      map['finished_level'] = Variable<int>(finishedLevel.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (finishDate.present) {
      map['finish_date'] = Variable<DateTime>(finishDate.value);
    }
    if (trainingStartSp.present) {
      map['training_start_sp'] = Variable<int>(trainingStartSp.value);
    }
    if (levelEndSp.present) {
      map['level_end_sp'] = Variable<int>(levelEndSp.value);
    }
    if (levelStartSp.present) {
      map['level_start_sp'] = Variable<int>(levelStartSp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('queuePosition: $queuePosition, ')
          ..write('skillId: $skillId, ')
          ..write('finishedLevel: $finishedLevel, ')
          ..write('startDate: $startDate, ')
          ..write('finishDate: $finishDate, ')
          ..write('trainingStartSp: $trainingStartSp, ')
          ..write('levelEndSp: $levelEndSp, ')
          ..write('levelStartSp: $levelStartSp')
          ..write(')'))
        .toString();
  }
}

class $WalletJournalEntriesTable extends WalletJournalEntries
    with TableInfo<$WalletJournalEntriesTable, WalletJournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletJournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _refTypeMeta =
      const VerificationMeta('refType');
  @override
  late final GeneratedColumn<String> refType = GeneratedColumn<String>(
      'ref_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _firstPartyIdMeta =
      const VerificationMeta('firstPartyId');
  @override
  late final GeneratedColumn<int> firstPartyId = GeneratedColumn<int>(
      'first_party_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _secondPartyIdMeta =
      const VerificationMeta('secondPartyId');
  @override
  late final GeneratedColumn<int> secondPartyId = GeneratedColumn<int>(
      'second_party_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        characterId,
        amount,
        balance,
        refType,
        firstPartyId,
        secondPartyId,
        description,
        date
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_journal_entries';
  @override
  VerificationContext validateIntegrity(Insertable<WalletJournalEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    } else if (isInserting) {
      context.missing(_balanceMeta);
    }
    if (data.containsKey('ref_type')) {
      context.handle(_refTypeMeta,
          refType.isAcceptableOrUnknown(data['ref_type']!, _refTypeMeta));
    } else if (isInserting) {
      context.missing(_refTypeMeta);
    }
    if (data.containsKey('first_party_id')) {
      context.handle(
          _firstPartyIdMeta,
          firstPartyId.isAcceptableOrUnknown(
              data['first_party_id']!, _firstPartyIdMeta));
    }
    if (data.containsKey('second_party_id')) {
      context.handle(
          _secondPartyIdMeta,
          secondPartyId.isAcceptableOrUnknown(
              data['second_party_id']!, _secondPartyIdMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletJournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletJournalEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      refType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ref_type'])!,
      firstPartyId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}first_party_id']),
      secondPartyId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}second_party_id']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
    );
  }

  @override
  $WalletJournalEntriesTable createAlias(String alias) {
    return $WalletJournalEntriesTable(attachedDatabase, alias);
  }
}

class WalletJournalEntry extends DataClass
    implements Insertable<WalletJournalEntry> {
  /// Transaction ID (primary key).
  final int id;

  /// Character ID this entry belongs to.
  final int characterId;

  /// ISK amount (positive = income, negative = expense).
  final double amount;

  /// Running balance after this transaction.
  final double balance;

  /// Transaction type (e.g., 'market_transaction', 'player_donation').
  final String refType;

  /// First party ID (source or self).
  final int? firstPartyId;

  /// Second party ID (destination or counterparty).
  final int? secondPartyId;

  /// Transaction description/reason.
  final String? description;

  /// When the transaction occurred.
  final DateTime date;
  const WalletJournalEntry(
      {required this.id,
      required this.characterId,
      required this.amount,
      required this.balance,
      required this.refType,
      this.firstPartyId,
      this.secondPartyId,
      this.description,
      required this.date});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['amount'] = Variable<double>(amount);
    map['balance'] = Variable<double>(balance);
    map['ref_type'] = Variable<String>(refType);
    if (!nullToAbsent || firstPartyId != null) {
      map['first_party_id'] = Variable<int>(firstPartyId);
    }
    if (!nullToAbsent || secondPartyId != null) {
      map['second_party_id'] = Variable<int>(secondPartyId);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  WalletJournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return WalletJournalEntriesCompanion(
      id: Value(id),
      characterId: Value(characterId),
      amount: Value(amount),
      balance: Value(balance),
      refType: Value(refType),
      firstPartyId: firstPartyId == null && nullToAbsent
          ? const Value.absent()
          : Value(firstPartyId),
      secondPartyId: secondPartyId == null && nullToAbsent
          ? const Value.absent()
          : Value(secondPartyId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      date: Value(date),
    );
  }

  factory WalletJournalEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletJournalEntry(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      amount: serializer.fromJson<double>(json['amount']),
      balance: serializer.fromJson<double>(json['balance']),
      refType: serializer.fromJson<String>(json['refType']),
      firstPartyId: serializer.fromJson<int?>(json['firstPartyId']),
      secondPartyId: serializer.fromJson<int?>(json['secondPartyId']),
      description: serializer.fromJson<String?>(json['description']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'amount': serializer.toJson<double>(amount),
      'balance': serializer.toJson<double>(balance),
      'refType': serializer.toJson<String>(refType),
      'firstPartyId': serializer.toJson<int?>(firstPartyId),
      'secondPartyId': serializer.toJson<int?>(secondPartyId),
      'description': serializer.toJson<String?>(description),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  WalletJournalEntry copyWith(
          {int? id,
          int? characterId,
          double? amount,
          double? balance,
          String? refType,
          Value<int?> firstPartyId = const Value.absent(),
          Value<int?> secondPartyId = const Value.absent(),
          Value<String?> description = const Value.absent(),
          DateTime? date}) =>
      WalletJournalEntry(
        id: id ?? this.id,
        characterId: characterId ?? this.characterId,
        amount: amount ?? this.amount,
        balance: balance ?? this.balance,
        refType: refType ?? this.refType,
        firstPartyId:
            firstPartyId.present ? firstPartyId.value : this.firstPartyId,
        secondPartyId:
            secondPartyId.present ? secondPartyId.value : this.secondPartyId,
        description: description.present ? description.value : this.description,
        date: date ?? this.date,
      );
  WalletJournalEntry copyWithCompanion(WalletJournalEntriesCompanion data) {
    return WalletJournalEntry(
      id: data.id.present ? data.id.value : this.id,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      amount: data.amount.present ? data.amount.value : this.amount,
      balance: data.balance.present ? data.balance.value : this.balance,
      refType: data.refType.present ? data.refType.value : this.refType,
      firstPartyId: data.firstPartyId.present
          ? data.firstPartyId.value
          : this.firstPartyId,
      secondPartyId: data.secondPartyId.present
          ? data.secondPartyId.value
          : this.secondPartyId,
      description:
          data.description.present ? data.description.value : this.description,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletJournalEntry(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('amount: $amount, ')
          ..write('balance: $balance, ')
          ..write('refType: $refType, ')
          ..write('firstPartyId: $firstPartyId, ')
          ..write('secondPartyId: $secondPartyId, ')
          ..write('description: $description, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, characterId, amount, balance, refType,
      firstPartyId, secondPartyId, description, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletJournalEntry &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.amount == this.amount &&
          other.balance == this.balance &&
          other.refType == this.refType &&
          other.firstPartyId == this.firstPartyId &&
          other.secondPartyId == this.secondPartyId &&
          other.description == this.description &&
          other.date == this.date);
}

class WalletJournalEntriesCompanion
    extends UpdateCompanion<WalletJournalEntry> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<double> amount;
  final Value<double> balance;
  final Value<String> refType;
  final Value<int?> firstPartyId;
  final Value<int?> secondPartyId;
  final Value<String?> description;
  final Value<DateTime> date;
  const WalletJournalEntriesCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.amount = const Value.absent(),
    this.balance = const Value.absent(),
    this.refType = const Value.absent(),
    this.firstPartyId = const Value.absent(),
    this.secondPartyId = const Value.absent(),
    this.description = const Value.absent(),
    this.date = const Value.absent(),
  });
  WalletJournalEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required double amount,
    required double balance,
    required String refType,
    this.firstPartyId = const Value.absent(),
    this.secondPartyId = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime date,
  })  : characterId = Value(characterId),
        amount = Value(amount),
        balance = Value(balance),
        refType = Value(refType),
        date = Value(date);
  static Insertable<WalletJournalEntry> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<double>? amount,
    Expression<double>? balance,
    Expression<String>? refType,
    Expression<int>? firstPartyId,
    Expression<int>? secondPartyId,
    Expression<String>? description,
    Expression<DateTime>? date,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (amount != null) 'amount': amount,
      if (balance != null) 'balance': balance,
      if (refType != null) 'ref_type': refType,
      if (firstPartyId != null) 'first_party_id': firstPartyId,
      if (secondPartyId != null) 'second_party_id': secondPartyId,
      if (description != null) 'description': description,
      if (date != null) 'date': date,
    });
  }

  WalletJournalEntriesCompanion copyWith(
      {Value<int>? id,
      Value<int>? characterId,
      Value<double>? amount,
      Value<double>? balance,
      Value<String>? refType,
      Value<int?>? firstPartyId,
      Value<int?>? secondPartyId,
      Value<String?>? description,
      Value<DateTime>? date}) {
    return WalletJournalEntriesCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      amount: amount ?? this.amount,
      balance: balance ?? this.balance,
      refType: refType ?? this.refType,
      firstPartyId: firstPartyId ?? this.firstPartyId,
      secondPartyId: secondPartyId ?? this.secondPartyId,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (refType.present) {
      map['ref_type'] = Variable<String>(refType.value);
    }
    if (firstPartyId.present) {
      map['first_party_id'] = Variable<int>(firstPartyId.value);
    }
    if (secondPartyId.present) {
      map['second_party_id'] = Variable<int>(secondPartyId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletJournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('amount: $amount, ')
          ..write('balance: $balance, ')
          ..write('refType: $refType, ')
          ..write('firstPartyId: $firstPartyId, ')
          ..write('secondPartyId: $secondPartyId, ')
          ..write('description: $description, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }
}

class $WalletBalancesTable extends WalletBalances
    with TableInfo<$WalletBalancesTable, WalletBalance> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletBalancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _recordedAtMeta =
      const VerificationMeta('recordedAt');
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
      'recorded_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, characterId, balance, recordedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_balances';
  @override
  VerificationContext validateIntegrity(Insertable<WalletBalance> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    } else if (isInserting) {
      context.missing(_balanceMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
          _recordedAtMeta,
          recordedAt.isAcceptableOrUnknown(
              data['recorded_at']!, _recordedAtMeta));
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletBalance map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletBalance(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      recordedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}recorded_at'])!,
    );
  }

  @override
  $WalletBalancesTable createAlias(String alias) {
    return $WalletBalancesTable(attachedDatabase, alias);
  }
}

class WalletBalance extends DataClass implements Insertable<WalletBalance> {
  /// Auto-incrementing ID.
  final int id;

  /// Character ID.
  final int characterId;

  /// Balance in ISK.
  final double balance;

  /// When this balance was recorded.
  final DateTime recordedAt;
  const WalletBalance(
      {required this.id,
      required this.characterId,
      required this.balance,
      required this.recordedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['balance'] = Variable<double>(balance);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  WalletBalancesCompanion toCompanion(bool nullToAbsent) {
    return WalletBalancesCompanion(
      id: Value(id),
      characterId: Value(characterId),
      balance: Value(balance),
      recordedAt: Value(recordedAt),
    );
  }

  factory WalletBalance.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletBalance(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      balance: serializer.fromJson<double>(json['balance']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'balance': serializer.toJson<double>(balance),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  WalletBalance copyWith(
          {int? id, int? characterId, double? balance, DateTime? recordedAt}) =>
      WalletBalance(
        id: id ?? this.id,
        characterId: characterId ?? this.characterId,
        balance: balance ?? this.balance,
        recordedAt: recordedAt ?? this.recordedAt,
      );
  WalletBalance copyWithCompanion(WalletBalancesCompanion data) {
    return WalletBalance(
      id: data.id.present ? data.id.value : this.id,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      balance: data.balance.present ? data.balance.value : this.balance,
      recordedAt:
          data.recordedAt.present ? data.recordedAt.value : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletBalance(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('balance: $balance, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, characterId, balance, recordedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletBalance &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.balance == this.balance &&
          other.recordedAt == this.recordedAt);
}

class WalletBalancesCompanion extends UpdateCompanion<WalletBalance> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<double> balance;
  final Value<DateTime> recordedAt;
  const WalletBalancesCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.balance = const Value.absent(),
    this.recordedAt = const Value.absent(),
  });
  WalletBalancesCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required double balance,
    required DateTime recordedAt,
  })  : characterId = Value(characterId),
        balance = Value(balance),
        recordedAt = Value(recordedAt);
  static Insertable<WalletBalance> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<double>? balance,
    Expression<DateTime>? recordedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (balance != null) 'balance': balance,
      if (recordedAt != null) 'recorded_at': recordedAt,
    });
  }

  WalletBalancesCompanion copyWith(
      {Value<int>? id,
      Value<int>? characterId,
      Value<double>? balance,
      Value<DateTime>? recordedAt}) {
    return WalletBalancesCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      balance: balance ?? this.balance,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletBalancesCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('balance: $balance, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }
}

class $WalletTransactionsTable extends WalletTransactions
    with TableInfo<$WalletTransactionsTable, WalletTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
      'transaction_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
      'type_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
      'location_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceMeta =
      const VerificationMeta('unitPrice');
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
      'unit_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isBuyMeta = const VerificationMeta('isBuy');
  @override
  late final GeneratedColumn<bool> isBuy = GeneratedColumn<bool>(
      'is_buy', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_buy" IN (0, 1))'));
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<int> clientId = GeneratedColumn<int>(
      'client_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _journalRefIdMeta =
      const VerificationMeta('journalRefId');
  @override
  late final GeneratedColumn<int> journalRefId = GeneratedColumn<int>(
      'journal_ref_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        transactionId,
        characterId,
        typeId,
        locationId,
        unitPrice,
        quantity,
        isBuy,
        clientId,
        date,
        journalRefId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_transactions';
  @override
  VerificationContext validateIntegrity(Insertable<WalletTransaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta,
          typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(_unitPriceMeta,
          unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta));
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('is_buy')) {
      context.handle(
          _isBuyMeta, isBuy.isAcceptableOrUnknown(data['is_buy']!, _isBuyMeta));
    } else if (isInserting) {
      context.missing(_isBuyMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('journal_ref_id')) {
      context.handle(
          _journalRefIdMeta,
          journalRefId.isAcceptableOrUnknown(
              data['journal_ref_id']!, _journalRefIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transactionId};
  @override
  WalletTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletTransaction(
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transaction_id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      typeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type_id'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location_id'])!,
      unitPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}unit_price'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      isBuy: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_buy'])!,
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}client_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      journalRefId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}journal_ref_id']),
    );
  }

  @override
  $WalletTransactionsTable createAlias(String alias) {
    return $WalletTransactionsTable(attachedDatabase, alias);
  }
}

class WalletTransaction extends DataClass
    implements Insertable<WalletTransaction> {
  /// Transaction ID (primary key).
  final int transactionId;

  /// Character ID this transaction belongs to.
  final int characterId;

  /// Item type ID from EVE SDE.
  final int typeId;

  /// Location ID (station or structure).
  final int locationId;

  /// Price per unit in ISK.
  final double unitPrice;

  /// Quantity of items.
  final int quantity;

  /// Whether this is a buy (true) or sell (false) transaction.
  final bool isBuy;

  /// Client ID (counterparty character/corporation).
  final int clientId;

  /// When the transaction occurred.
  final DateTime date;

  /// Reference to journal entry ID (if applicable).
  final int? journalRefId;
  const WalletTransaction(
      {required this.transactionId,
      required this.characterId,
      required this.typeId,
      required this.locationId,
      required this.unitPrice,
      required this.quantity,
      required this.isBuy,
      required this.clientId,
      required this.date,
      this.journalRefId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transaction_id'] = Variable<int>(transactionId);
    map['character_id'] = Variable<int>(characterId);
    map['type_id'] = Variable<int>(typeId);
    map['location_id'] = Variable<int>(locationId);
    map['unit_price'] = Variable<double>(unitPrice);
    map['quantity'] = Variable<int>(quantity);
    map['is_buy'] = Variable<bool>(isBuy);
    map['client_id'] = Variable<int>(clientId);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || journalRefId != null) {
      map['journal_ref_id'] = Variable<int>(journalRefId);
    }
    return map;
  }

  WalletTransactionsCompanion toCompanion(bool nullToAbsent) {
    return WalletTransactionsCompanion(
      transactionId: Value(transactionId),
      characterId: Value(characterId),
      typeId: Value(typeId),
      locationId: Value(locationId),
      unitPrice: Value(unitPrice),
      quantity: Value(quantity),
      isBuy: Value(isBuy),
      clientId: Value(clientId),
      date: Value(date),
      journalRefId: journalRefId == null && nullToAbsent
          ? const Value.absent()
          : Value(journalRefId),
    );
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletTransaction(
      transactionId: serializer.fromJson<int>(json['transactionId']),
      characterId: serializer.fromJson<int>(json['characterId']),
      typeId: serializer.fromJson<int>(json['typeId']),
      locationId: serializer.fromJson<int>(json['locationId']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      quantity: serializer.fromJson<int>(json['quantity']),
      isBuy: serializer.fromJson<bool>(json['isBuy']),
      clientId: serializer.fromJson<int>(json['clientId']),
      date: serializer.fromJson<DateTime>(json['date']),
      journalRefId: serializer.fromJson<int?>(json['journalRefId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transactionId': serializer.toJson<int>(transactionId),
      'characterId': serializer.toJson<int>(characterId),
      'typeId': serializer.toJson<int>(typeId),
      'locationId': serializer.toJson<int>(locationId),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'quantity': serializer.toJson<int>(quantity),
      'isBuy': serializer.toJson<bool>(isBuy),
      'clientId': serializer.toJson<int>(clientId),
      'date': serializer.toJson<DateTime>(date),
      'journalRefId': serializer.toJson<int?>(journalRefId),
    };
  }

  WalletTransaction copyWith(
          {int? transactionId,
          int? characterId,
          int? typeId,
          int? locationId,
          double? unitPrice,
          int? quantity,
          bool? isBuy,
          int? clientId,
          DateTime? date,
          Value<int?> journalRefId = const Value.absent()}) =>
      WalletTransaction(
        transactionId: transactionId ?? this.transactionId,
        characterId: characterId ?? this.characterId,
        typeId: typeId ?? this.typeId,
        locationId: locationId ?? this.locationId,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        isBuy: isBuy ?? this.isBuy,
        clientId: clientId ?? this.clientId,
        date: date ?? this.date,
        journalRefId:
            journalRefId.present ? journalRefId.value : this.journalRefId,
      );
  WalletTransaction copyWithCompanion(WalletTransactionsCompanion data) {
    return WalletTransaction(
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      isBuy: data.isBuy.present ? data.isBuy.value : this.isBuy,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      date: data.date.present ? data.date.value : this.date,
      journalRefId: data.journalRefId.present
          ? data.journalRefId.value
          : this.journalRefId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletTransaction(')
          ..write('transactionId: $transactionId, ')
          ..write('characterId: $characterId, ')
          ..write('typeId: $typeId, ')
          ..write('locationId: $locationId, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('isBuy: $isBuy, ')
          ..write('clientId: $clientId, ')
          ..write('date: $date, ')
          ..write('journalRefId: $journalRefId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transactionId, characterId, typeId,
      locationId, unitPrice, quantity, isBuy, clientId, date, journalRefId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletTransaction &&
          other.transactionId == this.transactionId &&
          other.characterId == this.characterId &&
          other.typeId == this.typeId &&
          other.locationId == this.locationId &&
          other.unitPrice == this.unitPrice &&
          other.quantity == this.quantity &&
          other.isBuy == this.isBuy &&
          other.clientId == this.clientId &&
          other.date == this.date &&
          other.journalRefId == this.journalRefId);
}

class WalletTransactionsCompanion extends UpdateCompanion<WalletTransaction> {
  final Value<int> transactionId;
  final Value<int> characterId;
  final Value<int> typeId;
  final Value<int> locationId;
  final Value<double> unitPrice;
  final Value<int> quantity;
  final Value<bool> isBuy;
  final Value<int> clientId;
  final Value<DateTime> date;
  final Value<int?> journalRefId;
  const WalletTransactionsCompanion({
    this.transactionId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.typeId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.isBuy = const Value.absent(),
    this.clientId = const Value.absent(),
    this.date = const Value.absent(),
    this.journalRefId = const Value.absent(),
  });
  WalletTransactionsCompanion.insert({
    this.transactionId = const Value.absent(),
    required int characterId,
    required int typeId,
    required int locationId,
    required double unitPrice,
    required int quantity,
    required bool isBuy,
    required int clientId,
    required DateTime date,
    this.journalRefId = const Value.absent(),
  })  : characterId = Value(characterId),
        typeId = Value(typeId),
        locationId = Value(locationId),
        unitPrice = Value(unitPrice),
        quantity = Value(quantity),
        isBuy = Value(isBuy),
        clientId = Value(clientId),
        date = Value(date);
  static Insertable<WalletTransaction> custom({
    Expression<int>? transactionId,
    Expression<int>? characterId,
    Expression<int>? typeId,
    Expression<int>? locationId,
    Expression<double>? unitPrice,
    Expression<int>? quantity,
    Expression<bool>? isBuy,
    Expression<int>? clientId,
    Expression<DateTime>? date,
    Expression<int>? journalRefId,
  }) {
    return RawValuesInsertable({
      if (transactionId != null) 'transaction_id': transactionId,
      if (characterId != null) 'character_id': characterId,
      if (typeId != null) 'type_id': typeId,
      if (locationId != null) 'location_id': locationId,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (quantity != null) 'quantity': quantity,
      if (isBuy != null) 'is_buy': isBuy,
      if (clientId != null) 'client_id': clientId,
      if (date != null) 'date': date,
      if (journalRefId != null) 'journal_ref_id': journalRefId,
    });
  }

  WalletTransactionsCompanion copyWith(
      {Value<int>? transactionId,
      Value<int>? characterId,
      Value<int>? typeId,
      Value<int>? locationId,
      Value<double>? unitPrice,
      Value<int>? quantity,
      Value<bool>? isBuy,
      Value<int>? clientId,
      Value<DateTime>? date,
      Value<int?>? journalRefId}) {
    return WalletTransactionsCompanion(
      transactionId: transactionId ?? this.transactionId,
      characterId: characterId ?? this.characterId,
      typeId: typeId ?? this.typeId,
      locationId: locationId ?? this.locationId,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      isBuy: isBuy ?? this.isBuy,
      clientId: clientId ?? this.clientId,
      date: date ?? this.date,
      journalRefId: journalRefId ?? this.journalRefId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<int>(locationId.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (isBuy.present) {
      map['is_buy'] = Variable<bool>(isBuy.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<int>(clientId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (journalRefId.present) {
      map['journal_ref_id'] = Variable<int>(journalRefId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletTransactionsCompanion(')
          ..write('transactionId: $transactionId, ')
          ..write('characterId: $characterId, ')
          ..write('typeId: $typeId, ')
          ..write('locationId: $locationId, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('isBuy: $isBuy, ')
          ..write('clientId: $clientId, ')
          ..write('date: $date, ')
          ..write('journalRefId: $journalRefId')
          ..write(')'))
        .toString();
  }
}

class $LoyaltyPointsTable extends LoyaltyPoints
    with TableInfo<$LoyaltyPointsTable, LoyaltyPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoyaltyPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _corporationIdMeta =
      const VerificationMeta('corporationId');
  @override
  late final GeneratedColumn<int> corporationId = GeneratedColumn<int>(
      'corporation_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _loyaltyPointsMeta =
      const VerificationMeta('loyaltyPoints');
  @override
  late final GeneratedColumn<int> loyaltyPoints = GeneratedColumn<int>(
      'loyalty_points', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, characterId, corporationId, loyaltyPoints, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loyalty_points';
  @override
  VerificationContext validateIntegrity(Insertable<LoyaltyPoint> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('corporation_id')) {
      context.handle(
          _corporationIdMeta,
          corporationId.isAcceptableOrUnknown(
              data['corporation_id']!, _corporationIdMeta));
    } else if (isInserting) {
      context.missing(_corporationIdMeta);
    }
    if (data.containsKey('loyalty_points')) {
      context.handle(
          _loyaltyPointsMeta,
          loyaltyPoints.isAcceptableOrUnknown(
              data['loyalty_points']!, _loyaltyPointsMeta));
    } else if (isInserting) {
      context.missing(_loyaltyPointsMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LoyaltyPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoyaltyPoint(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      corporationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}corporation_id'])!,
      loyaltyPoints: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}loyalty_points'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $LoyaltyPointsTable createAlias(String alias) {
    return $LoyaltyPointsTable(attachedDatabase, alias);
  }
}

class LoyaltyPoint extends DataClass implements Insertable<LoyaltyPoint> {
  /// Auto-incrementing ID.
  final int id;

  /// Character ID.
  final int characterId;

  /// Corporation ID offering these loyalty points.
  final int corporationId;

  /// Amount of loyalty points.
  final int loyaltyPoints;

  /// When this data was last updated.
  final DateTime lastUpdated;
  const LoyaltyPoint(
      {required this.id,
      required this.characterId,
      required this.corporationId,
      required this.loyaltyPoints,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['corporation_id'] = Variable<int>(corporationId);
    map['loyalty_points'] = Variable<int>(loyaltyPoints);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  LoyaltyPointsCompanion toCompanion(bool nullToAbsent) {
    return LoyaltyPointsCompanion(
      id: Value(id),
      characterId: Value(characterId),
      corporationId: Value(corporationId),
      loyaltyPoints: Value(loyaltyPoints),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory LoyaltyPoint.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoyaltyPoint(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      corporationId: serializer.fromJson<int>(json['corporationId']),
      loyaltyPoints: serializer.fromJson<int>(json['loyaltyPoints']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'corporationId': serializer.toJson<int>(corporationId),
      'loyaltyPoints': serializer.toJson<int>(loyaltyPoints),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  LoyaltyPoint copyWith(
          {int? id,
          int? characterId,
          int? corporationId,
          int? loyaltyPoints,
          DateTime? lastUpdated}) =>
      LoyaltyPoint(
        id: id ?? this.id,
        characterId: characterId ?? this.characterId,
        corporationId: corporationId ?? this.corporationId,
        loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  LoyaltyPoint copyWithCompanion(LoyaltyPointsCompanion data) {
    return LoyaltyPoint(
      id: data.id.present ? data.id.value : this.id,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      corporationId: data.corporationId.present
          ? data.corporationId.value
          : this.corporationId,
      loyaltyPoints: data.loyaltyPoints.present
          ? data.loyaltyPoints.value
          : this.loyaltyPoints,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoyaltyPoint(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('corporationId: $corporationId, ')
          ..write('loyaltyPoints: $loyaltyPoints, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, characterId, corporationId, loyaltyPoints, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoyaltyPoint &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.corporationId == this.corporationId &&
          other.loyaltyPoints == this.loyaltyPoints &&
          other.lastUpdated == this.lastUpdated);
}

class LoyaltyPointsCompanion extends UpdateCompanion<LoyaltyPoint> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<int> corporationId;
  final Value<int> loyaltyPoints;
  final Value<DateTime> lastUpdated;
  const LoyaltyPointsCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.corporationId = const Value.absent(),
    this.loyaltyPoints = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  LoyaltyPointsCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required int corporationId,
    required int loyaltyPoints,
    required DateTime lastUpdated,
  })  : characterId = Value(characterId),
        corporationId = Value(corporationId),
        loyaltyPoints = Value(loyaltyPoints),
        lastUpdated = Value(lastUpdated);
  static Insertable<LoyaltyPoint> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<int>? corporationId,
    Expression<int>? loyaltyPoints,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (corporationId != null) 'corporation_id': corporationId,
      if (loyaltyPoints != null) 'loyalty_points': loyaltyPoints,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  LoyaltyPointsCompanion copyWith(
      {Value<int>? id,
      Value<int>? characterId,
      Value<int>? corporationId,
      Value<int>? loyaltyPoints,
      Value<DateTime>? lastUpdated}) {
    return LoyaltyPointsCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      corporationId: corporationId ?? this.corporationId,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (corporationId.present) {
      map['corporation_id'] = Variable<int>(corporationId.value);
    }
    if (loyaltyPoints.present) {
      map['loyalty_points'] = Variable<int>(loyaltyPoints.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoyaltyPointsCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('corporationId: $corporationId, ')
          ..write('loyaltyPoints: $loyaltyPoints, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $AssetCacheTable extends AssetCache
    with TableInfo<$AssetCacheTable, AssetCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
      'item_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<int> typeId = GeneratedColumn<int>(
      'type_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
      'location_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [itemId, characterId, typeId, quantity, locationId, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_cache';
  @override
  VerificationContext validateIntegrity(Insertable<AssetCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta,
          typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  AssetCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetCacheData(
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      typeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location_id'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $AssetCacheTable createAlias(String alias) {
    return $AssetCacheTable(attachedDatabase, alias);
  }
}

class AssetCacheData extends DataClass implements Insertable<AssetCacheData> {
  /// Item ID (unique asset instance, primary key).
  final int itemId;

  /// Character ID this asset belongs to.
  final int characterId;

  /// Item type ID from EVE SDE.
  final int typeId;

  /// Quantity of this item.
  final int quantity;

  /// Location ID where the asset is stored.
  final int locationId;

  /// When this cache was last updated.
  final DateTime lastUpdated;
  const AssetCacheData(
      {required this.itemId,
      required this.characterId,
      required this.typeId,
      required this.quantity,
      required this.locationId,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<int>(itemId);
    map['character_id'] = Variable<int>(characterId);
    map['type_id'] = Variable<int>(typeId);
    map['quantity'] = Variable<int>(quantity);
    map['location_id'] = Variable<int>(locationId);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  AssetCacheCompanion toCompanion(bool nullToAbsent) {
    return AssetCacheCompanion(
      itemId: Value(itemId),
      characterId: Value(characterId),
      typeId: Value(typeId),
      quantity: Value(quantity),
      locationId: Value(locationId),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory AssetCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetCacheData(
      itemId: serializer.fromJson<int>(json['itemId']),
      characterId: serializer.fromJson<int>(json['characterId']),
      typeId: serializer.fromJson<int>(json['typeId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      locationId: serializer.fromJson<int>(json['locationId']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<int>(itemId),
      'characterId': serializer.toJson<int>(characterId),
      'typeId': serializer.toJson<int>(typeId),
      'quantity': serializer.toJson<int>(quantity),
      'locationId': serializer.toJson<int>(locationId),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  AssetCacheData copyWith(
          {int? itemId,
          int? characterId,
          int? typeId,
          int? quantity,
          int? locationId,
          DateTime? lastUpdated}) =>
      AssetCacheData(
        itemId: itemId ?? this.itemId,
        characterId: characterId ?? this.characterId,
        typeId: typeId ?? this.typeId,
        quantity: quantity ?? this.quantity,
        locationId: locationId ?? this.locationId,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  AssetCacheData copyWithCompanion(AssetCacheCompanion data) {
    return AssetCacheData(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetCacheData(')
          ..write('itemId: $itemId, ')
          ..write('characterId: $characterId, ')
          ..write('typeId: $typeId, ')
          ..write('quantity: $quantity, ')
          ..write('locationId: $locationId, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      itemId, characterId, typeId, quantity, locationId, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetCacheData &&
          other.itemId == this.itemId &&
          other.characterId == this.characterId &&
          other.typeId == this.typeId &&
          other.quantity == this.quantity &&
          other.locationId == this.locationId &&
          other.lastUpdated == this.lastUpdated);
}

class AssetCacheCompanion extends UpdateCompanion<AssetCacheData> {
  final Value<int> itemId;
  final Value<int> characterId;
  final Value<int> typeId;
  final Value<int> quantity;
  final Value<int> locationId;
  final Value<DateTime> lastUpdated;
  const AssetCacheCompanion({
    this.itemId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.typeId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.locationId = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  AssetCacheCompanion.insert({
    this.itemId = const Value.absent(),
    required int characterId,
    required int typeId,
    required int quantity,
    required int locationId,
    required DateTime lastUpdated,
  })  : characterId = Value(characterId),
        typeId = Value(typeId),
        quantity = Value(quantity),
        locationId = Value(locationId),
        lastUpdated = Value(lastUpdated);
  static Insertable<AssetCacheData> custom({
    Expression<int>? itemId,
    Expression<int>? characterId,
    Expression<int>? typeId,
    Expression<int>? quantity,
    Expression<int>? locationId,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (characterId != null) 'character_id': characterId,
      if (typeId != null) 'type_id': typeId,
      if (quantity != null) 'quantity': quantity,
      if (locationId != null) 'location_id': locationId,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  AssetCacheCompanion copyWith(
      {Value<int>? itemId,
      Value<int>? characterId,
      Value<int>? typeId,
      Value<int>? quantity,
      Value<int>? locationId,
      Value<DateTime>? lastUpdated}) {
    return AssetCacheCompanion(
      itemId: itemId ?? this.itemId,
      characterId: characterId ?? this.characterId,
      typeId: typeId ?? this.typeId,
      quantity: quantity ?? this.quantity,
      locationId: locationId ?? this.locationId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<int>(typeId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<int>(locationId.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetCacheCompanion(')
          ..write('itemId: $itemId, ')
          ..write('characterId: $characterId, ')
          ..write('typeId: $typeId, ')
          ..write('quantity: $quantity, ')
          ..write('locationId: $locationId, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, AppSettingsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _startupBehaviorMeta =
      const VerificationMeta('startupBehavior');
  @override
  late final GeneratedColumn<String> startupBehavior = GeneratedColumn<String>(
      'startup_behavior', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('dashboard'));
  static const VerificationMeta _onboardingCompleteMeta =
      const VerificationMeta('onboardingComplete');
  @override
  late final GeneratedColumn<bool> onboardingComplete = GeneratedColumn<bool>(
      'onboarding_complete', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("onboarding_complete" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _esiErrorLimitRemainMeta =
      const VerificationMeta('esiErrorLimitRemain');
  @override
  late final GeneratedColumn<int> esiErrorLimitRemain = GeneratedColumn<int>(
      'esi_error_limit_remain', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(100));
  static const VerificationMeta _esiErrorLimitResetMeta =
      const VerificationMeta('esiErrorLimitReset');
  @override
  late final GeneratedColumn<DateTime> esiErrorLimitReset =
      GeneratedColumn<DateTime>('esi_error_limit_reset', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        startupBehavior,
        onboardingComplete,
        esiErrorLimitRemain,
        esiErrorLimitReset
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<AppSettingsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('startup_behavior')) {
      context.handle(
          _startupBehaviorMeta,
          startupBehavior.isAcceptableOrUnknown(
              data['startup_behavior']!, _startupBehaviorMeta));
    }
    if (data.containsKey('onboarding_complete')) {
      context.handle(
          _onboardingCompleteMeta,
          onboardingComplete.isAcceptableOrUnknown(
              data['onboarding_complete']!, _onboardingCompleteMeta));
    }
    if (data.containsKey('esi_error_limit_remain')) {
      context.handle(
          _esiErrorLimitRemainMeta,
          esiErrorLimitRemain.isAcceptableOrUnknown(
              data['esi_error_limit_remain']!, _esiErrorLimitRemainMeta));
    }
    if (data.containsKey('esi_error_limit_reset')) {
      context.handle(
          _esiErrorLimitResetMeta,
          esiErrorLimitReset.isAcceptableOrUnknown(
              data['esi_error_limit_reset']!, _esiErrorLimitResetMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      startupBehavior: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}startup_behavior'])!,
      onboardingComplete: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}onboarding_complete'])!,
      esiErrorLimitRemain: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}esi_error_limit_remain'])!,
      esiErrorLimitReset: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}esi_error_limit_reset']),
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }
}

class AppSettingsTableData extends DataClass
    implements Insertable<AppSettingsTableData> {
  /// Primary key (always 1 for singleton).
  final int id;

  /// Startup behavior ('dashboard' or 'tray_only').
  final String startupBehavior;

  /// Whether the user has completed onboarding.
  final bool onboardingComplete;

  /// ESI Error limit remaining
  final int esiErrorLimitRemain;

  /// ESI Error limit reset timestamp
  final DateTime? esiErrorLimitReset;
  const AppSettingsTableData(
      {required this.id,
      required this.startupBehavior,
      required this.onboardingComplete,
      required this.esiErrorLimitRemain,
      this.esiErrorLimitReset});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['startup_behavior'] = Variable<String>(startupBehavior);
    map['onboarding_complete'] = Variable<bool>(onboardingComplete);
    map['esi_error_limit_remain'] = Variable<int>(esiErrorLimitRemain);
    if (!nullToAbsent || esiErrorLimitReset != null) {
      map['esi_error_limit_reset'] = Variable<DateTime>(esiErrorLimitReset);
    }
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      id: Value(id),
      startupBehavior: Value(startupBehavior),
      onboardingComplete: Value(onboardingComplete),
      esiErrorLimitRemain: Value(esiErrorLimitRemain),
      esiErrorLimitReset: esiErrorLimitReset == null && nullToAbsent
          ? const Value.absent()
          : Value(esiErrorLimitReset),
    );
  }

  factory AppSettingsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsTableData(
      id: serializer.fromJson<int>(json['id']),
      startupBehavior: serializer.fromJson<String>(json['startupBehavior']),
      onboardingComplete: serializer.fromJson<bool>(json['onboardingComplete']),
      esiErrorLimitRemain:
          serializer.fromJson<int>(json['esiErrorLimitRemain']),
      esiErrorLimitReset:
          serializer.fromJson<DateTime?>(json['esiErrorLimitReset']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startupBehavior': serializer.toJson<String>(startupBehavior),
      'onboardingComplete': serializer.toJson<bool>(onboardingComplete),
      'esiErrorLimitRemain': serializer.toJson<int>(esiErrorLimitRemain),
      'esiErrorLimitReset': serializer.toJson<DateTime?>(esiErrorLimitReset),
    };
  }

  AppSettingsTableData copyWith(
          {int? id,
          String? startupBehavior,
          bool? onboardingComplete,
          int? esiErrorLimitRemain,
          Value<DateTime?> esiErrorLimitReset = const Value.absent()}) =>
      AppSettingsTableData(
        id: id ?? this.id,
        startupBehavior: startupBehavior ?? this.startupBehavior,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        esiErrorLimitRemain: esiErrorLimitRemain ?? this.esiErrorLimitRemain,
        esiErrorLimitReset: esiErrorLimitReset.present
            ? esiErrorLimitReset.value
            : this.esiErrorLimitReset,
      );
  AppSettingsTableData copyWithCompanion(AppSettingsTableCompanion data) {
    return AppSettingsTableData(
      id: data.id.present ? data.id.value : this.id,
      startupBehavior: data.startupBehavior.present
          ? data.startupBehavior.value
          : this.startupBehavior,
      onboardingComplete: data.onboardingComplete.present
          ? data.onboardingComplete.value
          : this.onboardingComplete,
      esiErrorLimitRemain: data.esiErrorLimitRemain.present
          ? data.esiErrorLimitRemain.value
          : this.esiErrorLimitRemain,
      esiErrorLimitReset: data.esiErrorLimitReset.present
          ? data.esiErrorLimitReset.value
          : this.esiErrorLimitReset,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableData(')
          ..write('id: $id, ')
          ..write('startupBehavior: $startupBehavior, ')
          ..write('onboardingComplete: $onboardingComplete, ')
          ..write('esiErrorLimitRemain: $esiErrorLimitRemain, ')
          ..write('esiErrorLimitReset: $esiErrorLimitReset')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startupBehavior, onboardingComplete,
      esiErrorLimitRemain, esiErrorLimitReset);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsTableData &&
          other.id == this.id &&
          other.startupBehavior == this.startupBehavior &&
          other.onboardingComplete == this.onboardingComplete &&
          other.esiErrorLimitRemain == this.esiErrorLimitRemain &&
          other.esiErrorLimitReset == this.esiErrorLimitReset);
}

class AppSettingsTableCompanion extends UpdateCompanion<AppSettingsTableData> {
  final Value<int> id;
  final Value<String> startupBehavior;
  final Value<bool> onboardingComplete;
  final Value<int> esiErrorLimitRemain;
  final Value<DateTime?> esiErrorLimitReset;
  const AppSettingsTableCompanion({
    this.id = const Value.absent(),
    this.startupBehavior = const Value.absent(),
    this.onboardingComplete = const Value.absent(),
    this.esiErrorLimitRemain = const Value.absent(),
    this.esiErrorLimitReset = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    this.id = const Value.absent(),
    this.startupBehavior = const Value.absent(),
    this.onboardingComplete = const Value.absent(),
    this.esiErrorLimitRemain = const Value.absent(),
    this.esiErrorLimitReset = const Value.absent(),
  });
  static Insertable<AppSettingsTableData> custom({
    Expression<int>? id,
    Expression<String>? startupBehavior,
    Expression<bool>? onboardingComplete,
    Expression<int>? esiErrorLimitRemain,
    Expression<DateTime>? esiErrorLimitReset,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startupBehavior != null) 'startup_behavior': startupBehavior,
      if (onboardingComplete != null) 'onboarding_complete': onboardingComplete,
      if (esiErrorLimitRemain != null)
        'esi_error_limit_remain': esiErrorLimitRemain,
      if (esiErrorLimitReset != null)
        'esi_error_limit_reset': esiErrorLimitReset,
    });
  }

  AppSettingsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? startupBehavior,
      Value<bool>? onboardingComplete,
      Value<int>? esiErrorLimitRemain,
      Value<DateTime?>? esiErrorLimitReset}) {
    return AppSettingsTableCompanion(
      id: id ?? this.id,
      startupBehavior: startupBehavior ?? this.startupBehavior,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      esiErrorLimitRemain: esiErrorLimitRemain ?? this.esiErrorLimitRemain,
      esiErrorLimitReset: esiErrorLimitReset ?? this.esiErrorLimitReset,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startupBehavior.present) {
      map['startup_behavior'] = Variable<String>(startupBehavior.value);
    }
    if (onboardingComplete.present) {
      map['onboarding_complete'] = Variable<bool>(onboardingComplete.value);
    }
    if (esiErrorLimitRemain.present) {
      map['esi_error_limit_remain'] = Variable<int>(esiErrorLimitRemain.value);
    }
    if (esiErrorLimitReset.present) {
      map['esi_error_limit_reset'] =
          Variable<DateTime>(esiErrorLimitReset.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('startupBehavior: $startupBehavior, ')
          ..write('onboardingComplete: $onboardingComplete, ')
          ..write('esiErrorLimitRemain: $esiErrorLimitRemain, ')
          ..write('esiErrorLimitReset: $esiErrorLimitReset')
          ..write(')'))
        .toString();
  }
}

class $CombatStatsTable extends CombatStats
    with TableInfo<$CombatStatsTable, CombatStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CombatStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _killsMeta = const VerificationMeta('kills');
  @override
  late final GeneratedColumn<int> kills = GeneratedColumn<int>(
      'kills', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deathsMeta = const VerificationMeta('deaths');
  @override
  late final GeneratedColumn<int> deaths = GeneratedColumn<int>(
      'deaths', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _iskDestroyedMeta =
      const VerificationMeta('iskDestroyed');
  @override
  late final GeneratedColumn<double> iskDestroyed = GeneratedColumn<double>(
      'isk_destroyed', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _iskLostMeta =
      const VerificationMeta('iskLost');
  @override
  late final GeneratedColumn<double> iskLost = GeneratedColumn<double>(
      'isk_lost', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [characterId, kills, deaths, iskDestroyed, iskLost, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'combat_stats';
  @override
  VerificationContext validateIntegrity(Insertable<CombatStat> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    }
    if (data.containsKey('kills')) {
      context.handle(
          _killsMeta, kills.isAcceptableOrUnknown(data['kills']!, _killsMeta));
    }
    if (data.containsKey('deaths')) {
      context.handle(_deathsMeta,
          deaths.isAcceptableOrUnknown(data['deaths']!, _deathsMeta));
    }
    if (data.containsKey('isk_destroyed')) {
      context.handle(
          _iskDestroyedMeta,
          iskDestroyed.isAcceptableOrUnknown(
              data['isk_destroyed']!, _iskDestroyedMeta));
    }
    if (data.containsKey('isk_lost')) {
      context.handle(_iskLostMeta,
          iskLost.isAcceptableOrUnknown(data['isk_lost']!, _iskLostMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {characterId};
  @override
  CombatStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CombatStat(
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      kills: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}kills'])!,
      deaths: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deaths'])!,
      iskDestroyed: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}isk_destroyed'])!,
      iskLost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}isk_lost'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $CombatStatsTable createAlias(String alias) {
    return $CombatStatsTable(attachedDatabase, alias);
  }
}

class CombatStat extends DataClass implements Insertable<CombatStat> {
  /// Character ID (primary key).
  final int characterId;

  /// Total kills (ships destroyed).
  final int kills;

  /// Total deaths (ships lost).
  final int deaths;

  /// ISK destroyed (from killing other ships).
  final double iskDestroyed;

  /// ISK lost (from own ships destroyed).
  final double iskLost;

  /// When this data was last fetched from zkillboard.
  final DateTime lastUpdated;
  const CombatStat(
      {required this.characterId,
      required this.kills,
      required this.deaths,
      required this.iskDestroyed,
      required this.iskLost,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['character_id'] = Variable<int>(characterId);
    map['kills'] = Variable<int>(kills);
    map['deaths'] = Variable<int>(deaths);
    map['isk_destroyed'] = Variable<double>(iskDestroyed);
    map['isk_lost'] = Variable<double>(iskLost);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  CombatStatsCompanion toCompanion(bool nullToAbsent) {
    return CombatStatsCompanion(
      characterId: Value(characterId),
      kills: Value(kills),
      deaths: Value(deaths),
      iskDestroyed: Value(iskDestroyed),
      iskLost: Value(iskLost),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory CombatStat.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CombatStat(
      characterId: serializer.fromJson<int>(json['characterId']),
      kills: serializer.fromJson<int>(json['kills']),
      deaths: serializer.fromJson<int>(json['deaths']),
      iskDestroyed: serializer.fromJson<double>(json['iskDestroyed']),
      iskLost: serializer.fromJson<double>(json['iskLost']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'characterId': serializer.toJson<int>(characterId),
      'kills': serializer.toJson<int>(kills),
      'deaths': serializer.toJson<int>(deaths),
      'iskDestroyed': serializer.toJson<double>(iskDestroyed),
      'iskLost': serializer.toJson<double>(iskLost),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  CombatStat copyWith(
          {int? characterId,
          int? kills,
          int? deaths,
          double? iskDestroyed,
          double? iskLost,
          DateTime? lastUpdated}) =>
      CombatStat(
        characterId: characterId ?? this.characterId,
        kills: kills ?? this.kills,
        deaths: deaths ?? this.deaths,
        iskDestroyed: iskDestroyed ?? this.iskDestroyed,
        iskLost: iskLost ?? this.iskLost,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  CombatStat copyWithCompanion(CombatStatsCompanion data) {
    return CombatStat(
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      kills: data.kills.present ? data.kills.value : this.kills,
      deaths: data.deaths.present ? data.deaths.value : this.deaths,
      iskDestroyed: data.iskDestroyed.present
          ? data.iskDestroyed.value
          : this.iskDestroyed,
      iskLost: data.iskLost.present ? data.iskLost.value : this.iskLost,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CombatStat(')
          ..write('characterId: $characterId, ')
          ..write('kills: $kills, ')
          ..write('deaths: $deaths, ')
          ..write('iskDestroyed: $iskDestroyed, ')
          ..write('iskLost: $iskLost, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      characterId, kills, deaths, iskDestroyed, iskLost, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CombatStat &&
          other.characterId == this.characterId &&
          other.kills == this.kills &&
          other.deaths == this.deaths &&
          other.iskDestroyed == this.iskDestroyed &&
          other.iskLost == this.iskLost &&
          other.lastUpdated == this.lastUpdated);
}

class CombatStatsCompanion extends UpdateCompanion<CombatStat> {
  final Value<int> characterId;
  final Value<int> kills;
  final Value<int> deaths;
  final Value<double> iskDestroyed;
  final Value<double> iskLost;
  final Value<DateTime> lastUpdated;
  const CombatStatsCompanion({
    this.characterId = const Value.absent(),
    this.kills = const Value.absent(),
    this.deaths = const Value.absent(),
    this.iskDestroyed = const Value.absent(),
    this.iskLost = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  CombatStatsCompanion.insert({
    this.characterId = const Value.absent(),
    this.kills = const Value.absent(),
    this.deaths = const Value.absent(),
    this.iskDestroyed = const Value.absent(),
    this.iskLost = const Value.absent(),
    required DateTime lastUpdated,
  }) : lastUpdated = Value(lastUpdated);
  static Insertable<CombatStat> custom({
    Expression<int>? characterId,
    Expression<int>? kills,
    Expression<int>? deaths,
    Expression<double>? iskDestroyed,
    Expression<double>? iskLost,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (characterId != null) 'character_id': characterId,
      if (kills != null) 'kills': kills,
      if (deaths != null) 'deaths': deaths,
      if (iskDestroyed != null) 'isk_destroyed': iskDestroyed,
      if (iskLost != null) 'isk_lost': iskLost,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  CombatStatsCompanion copyWith(
      {Value<int>? characterId,
      Value<int>? kills,
      Value<int>? deaths,
      Value<double>? iskDestroyed,
      Value<double>? iskLost,
      Value<DateTime>? lastUpdated}) {
    return CombatStatsCompanion(
      characterId: characterId ?? this.characterId,
      kills: kills ?? this.kills,
      deaths: deaths ?? this.deaths,
      iskDestroyed: iskDestroyed ?? this.iskDestroyed,
      iskLost: iskLost ?? this.iskLost,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (kills.present) {
      map['kills'] = Variable<int>(kills.value);
    }
    if (deaths.present) {
      map['deaths'] = Variable<int>(deaths.value);
    }
    if (iskDestroyed.present) {
      map['isk_destroyed'] = Variable<double>(iskDestroyed.value);
    }
    if (iskLost.present) {
      map['isk_lost'] = Variable<double>(iskLost.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CombatStatsCompanion(')
          ..write('characterId: $characterId, ')
          ..write('kills: $kills, ')
          ..write('deaths: $deaths, ')
          ..write('iskDestroyed: $iskDestroyed, ')
          ..write('iskLost: $iskLost, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $CharacterStatusesTable extends CharacterStatuses
    with TableInfo<$CharacterStatusesTable, CharacterStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharacterStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _solarSystemIdMeta =
      const VerificationMeta('solarSystemId');
  @override
  late final GeneratedColumn<int> solarSystemId = GeneratedColumn<int>(
      'solar_system_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _solarSystemNameMeta =
      const VerificationMeta('solarSystemName');
  @override
  late final GeneratedColumn<String> solarSystemName = GeneratedColumn<String>(
      'solar_system_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _securityStatusMeta =
      const VerificationMeta('securityStatus');
  @override
  late final GeneratedColumn<double> securityStatus = GeneratedColumn<double>(
      'security_status', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _shipTypeIdMeta =
      const VerificationMeta('shipTypeId');
  @override
  late final GeneratedColumn<int> shipTypeId = GeneratedColumn<int>(
      'ship_type_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _shipTypeNameMeta =
      const VerificationMeta('shipTypeName');
  @override
  late final GeneratedColumn<String> shipTypeName = GeneratedColumn<String>(
      'ship_type_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isOnlineMeta =
      const VerificationMeta('isOnline');
  @override
  late final GeneratedColumn<bool> isOnline = GeneratedColumn<bool>(
      'is_online', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_online" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastLoginMeta =
      const VerificationMeta('lastLogin');
  @override
  late final GeneratedColumn<DateTime> lastLogin = GeneratedColumn<DateTime>(
      'last_login', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastLogoutMeta =
      const VerificationMeta('lastLogout');
  @override
  late final GeneratedColumn<DateTime> lastLogout = GeneratedColumn<DateTime>(
      'last_logout', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        characterId,
        solarSystemId,
        solarSystemName,
        securityStatus,
        shipTypeId,
        shipTypeName,
        isOnline,
        lastLogin,
        lastLogout,
        lastUpdated
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'character_statuses';
  @override
  VerificationContext validateIntegrity(Insertable<CharacterStatuse> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    }
    if (data.containsKey('solar_system_id')) {
      context.handle(
          _solarSystemIdMeta,
          solarSystemId.isAcceptableOrUnknown(
              data['solar_system_id']!, _solarSystemIdMeta));
    }
    if (data.containsKey('solar_system_name')) {
      context.handle(
          _solarSystemNameMeta,
          solarSystemName.isAcceptableOrUnknown(
              data['solar_system_name']!, _solarSystemNameMeta));
    }
    if (data.containsKey('security_status')) {
      context.handle(
          _securityStatusMeta,
          securityStatus.isAcceptableOrUnknown(
              data['security_status']!, _securityStatusMeta));
    }
    if (data.containsKey('ship_type_id')) {
      context.handle(
          _shipTypeIdMeta,
          shipTypeId.isAcceptableOrUnknown(
              data['ship_type_id']!, _shipTypeIdMeta));
    }
    if (data.containsKey('ship_type_name')) {
      context.handle(
          _shipTypeNameMeta,
          shipTypeName.isAcceptableOrUnknown(
              data['ship_type_name']!, _shipTypeNameMeta));
    }
    if (data.containsKey('is_online')) {
      context.handle(_isOnlineMeta,
          isOnline.isAcceptableOrUnknown(data['is_online']!, _isOnlineMeta));
    }
    if (data.containsKey('last_login')) {
      context.handle(_lastLoginMeta,
          lastLogin.isAcceptableOrUnknown(data['last_login']!, _lastLoginMeta));
    }
    if (data.containsKey('last_logout')) {
      context.handle(
          _lastLogoutMeta,
          lastLogout.isAcceptableOrUnknown(
              data['last_logout']!, _lastLogoutMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {characterId};
  @override
  CharacterStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterStatuse(
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      solarSystemId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}solar_system_id']),
      solarSystemName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}solar_system_name']),
      securityStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}security_status']),
      shipTypeId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ship_type_id']),
      shipTypeName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ship_type_name']),
      isOnline: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_online'])!,
      lastLogin: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_login']),
      lastLogout: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_logout']),
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $CharacterStatusesTable createAlias(String alias) {
    return $CharacterStatusesTable(attachedDatabase, alias);
  }
}

class CharacterStatuse extends DataClass
    implements Insertable<CharacterStatuse> {
  /// Character ID (primary key).
  final int characterId;

  /// Solar system ID where the character is located.
  final int? solarSystemId;

  /// Solar system name (cached from SDE).
  final String? solarSystemName;

  /// Security status of the solar system (0.0 to 1.0).
  final double? securityStatus;

  /// Ship type ID the character is currently flying.
  final int? shipTypeId;

  /// Ship type name (cached from SDE).
  final String? shipTypeName;

  /// Whether the character is currently online.
  final bool isOnline;

  /// When the character last logged in.
  final DateTime? lastLogin;

  /// When the character last logged out.
  final DateTime? lastLogout;

  /// When this data was last refreshed from ESI.
  final DateTime lastUpdated;
  const CharacterStatuse(
      {required this.characterId,
      this.solarSystemId,
      this.solarSystemName,
      this.securityStatus,
      this.shipTypeId,
      this.shipTypeName,
      required this.isOnline,
      this.lastLogin,
      this.lastLogout,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['character_id'] = Variable<int>(characterId);
    if (!nullToAbsent || solarSystemId != null) {
      map['solar_system_id'] = Variable<int>(solarSystemId);
    }
    if (!nullToAbsent || solarSystemName != null) {
      map['solar_system_name'] = Variable<String>(solarSystemName);
    }
    if (!nullToAbsent || securityStatus != null) {
      map['security_status'] = Variable<double>(securityStatus);
    }
    if (!nullToAbsent || shipTypeId != null) {
      map['ship_type_id'] = Variable<int>(shipTypeId);
    }
    if (!nullToAbsent || shipTypeName != null) {
      map['ship_type_name'] = Variable<String>(shipTypeName);
    }
    map['is_online'] = Variable<bool>(isOnline);
    if (!nullToAbsent || lastLogin != null) {
      map['last_login'] = Variable<DateTime>(lastLogin);
    }
    if (!nullToAbsent || lastLogout != null) {
      map['last_logout'] = Variable<DateTime>(lastLogout);
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  CharacterStatusesCompanion toCompanion(bool nullToAbsent) {
    return CharacterStatusesCompanion(
      characterId: Value(characterId),
      solarSystemId: solarSystemId == null && nullToAbsent
          ? const Value.absent()
          : Value(solarSystemId),
      solarSystemName: solarSystemName == null && nullToAbsent
          ? const Value.absent()
          : Value(solarSystemName),
      securityStatus: securityStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(securityStatus),
      shipTypeId: shipTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(shipTypeId),
      shipTypeName: shipTypeName == null && nullToAbsent
          ? const Value.absent()
          : Value(shipTypeName),
      isOnline: Value(isOnline),
      lastLogin: lastLogin == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLogin),
      lastLogout: lastLogout == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLogout),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory CharacterStatuse.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterStatuse(
      characterId: serializer.fromJson<int>(json['characterId']),
      solarSystemId: serializer.fromJson<int?>(json['solarSystemId']),
      solarSystemName: serializer.fromJson<String?>(json['solarSystemName']),
      securityStatus: serializer.fromJson<double?>(json['securityStatus']),
      shipTypeId: serializer.fromJson<int?>(json['shipTypeId']),
      shipTypeName: serializer.fromJson<String?>(json['shipTypeName']),
      isOnline: serializer.fromJson<bool>(json['isOnline']),
      lastLogin: serializer.fromJson<DateTime?>(json['lastLogin']),
      lastLogout: serializer.fromJson<DateTime?>(json['lastLogout']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'characterId': serializer.toJson<int>(characterId),
      'solarSystemId': serializer.toJson<int?>(solarSystemId),
      'solarSystemName': serializer.toJson<String?>(solarSystemName),
      'securityStatus': serializer.toJson<double?>(securityStatus),
      'shipTypeId': serializer.toJson<int?>(shipTypeId),
      'shipTypeName': serializer.toJson<String?>(shipTypeName),
      'isOnline': serializer.toJson<bool>(isOnline),
      'lastLogin': serializer.toJson<DateTime?>(lastLogin),
      'lastLogout': serializer.toJson<DateTime?>(lastLogout),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  CharacterStatuse copyWith(
          {int? characterId,
          Value<int?> solarSystemId = const Value.absent(),
          Value<String?> solarSystemName = const Value.absent(),
          Value<double?> securityStatus = const Value.absent(),
          Value<int?> shipTypeId = const Value.absent(),
          Value<String?> shipTypeName = const Value.absent(),
          bool? isOnline,
          Value<DateTime?> lastLogin = const Value.absent(),
          Value<DateTime?> lastLogout = const Value.absent(),
          DateTime? lastUpdated}) =>
      CharacterStatuse(
        characterId: characterId ?? this.characterId,
        solarSystemId:
            solarSystemId.present ? solarSystemId.value : this.solarSystemId,
        solarSystemName: solarSystemName.present
            ? solarSystemName.value
            : this.solarSystemName,
        securityStatus:
            securityStatus.present ? securityStatus.value : this.securityStatus,
        shipTypeId: shipTypeId.present ? shipTypeId.value : this.shipTypeId,
        shipTypeName:
            shipTypeName.present ? shipTypeName.value : this.shipTypeName,
        isOnline: isOnline ?? this.isOnline,
        lastLogin: lastLogin.present ? lastLogin.value : this.lastLogin,
        lastLogout: lastLogout.present ? lastLogout.value : this.lastLogout,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  CharacterStatuse copyWithCompanion(CharacterStatusesCompanion data) {
    return CharacterStatuse(
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      solarSystemId: data.solarSystemId.present
          ? data.solarSystemId.value
          : this.solarSystemId,
      solarSystemName: data.solarSystemName.present
          ? data.solarSystemName.value
          : this.solarSystemName,
      securityStatus: data.securityStatus.present
          ? data.securityStatus.value
          : this.securityStatus,
      shipTypeId:
          data.shipTypeId.present ? data.shipTypeId.value : this.shipTypeId,
      shipTypeName: data.shipTypeName.present
          ? data.shipTypeName.value
          : this.shipTypeName,
      isOnline: data.isOnline.present ? data.isOnline.value : this.isOnline,
      lastLogin: data.lastLogin.present ? data.lastLogin.value : this.lastLogin,
      lastLogout:
          data.lastLogout.present ? data.lastLogout.value : this.lastLogout,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterStatuse(')
          ..write('characterId: $characterId, ')
          ..write('solarSystemId: $solarSystemId, ')
          ..write('solarSystemName: $solarSystemName, ')
          ..write('securityStatus: $securityStatus, ')
          ..write('shipTypeId: $shipTypeId, ')
          ..write('shipTypeName: $shipTypeName, ')
          ..write('isOnline: $isOnline, ')
          ..write('lastLogin: $lastLogin, ')
          ..write('lastLogout: $lastLogout, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      characterId,
      solarSystemId,
      solarSystemName,
      securityStatus,
      shipTypeId,
      shipTypeName,
      isOnline,
      lastLogin,
      lastLogout,
      lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterStatuse &&
          other.characterId == this.characterId &&
          other.solarSystemId == this.solarSystemId &&
          other.solarSystemName == this.solarSystemName &&
          other.securityStatus == this.securityStatus &&
          other.shipTypeId == this.shipTypeId &&
          other.shipTypeName == this.shipTypeName &&
          other.isOnline == this.isOnline &&
          other.lastLogin == this.lastLogin &&
          other.lastLogout == this.lastLogout &&
          other.lastUpdated == this.lastUpdated);
}

class CharacterStatusesCompanion extends UpdateCompanion<CharacterStatuse> {
  final Value<int> characterId;
  final Value<int?> solarSystemId;
  final Value<String?> solarSystemName;
  final Value<double?> securityStatus;
  final Value<int?> shipTypeId;
  final Value<String?> shipTypeName;
  final Value<bool> isOnline;
  final Value<DateTime?> lastLogin;
  final Value<DateTime?> lastLogout;
  final Value<DateTime> lastUpdated;
  const CharacterStatusesCompanion({
    this.characterId = const Value.absent(),
    this.solarSystemId = const Value.absent(),
    this.solarSystemName = const Value.absent(),
    this.securityStatus = const Value.absent(),
    this.shipTypeId = const Value.absent(),
    this.shipTypeName = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.lastLogin = const Value.absent(),
    this.lastLogout = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  CharacterStatusesCompanion.insert({
    this.characterId = const Value.absent(),
    this.solarSystemId = const Value.absent(),
    this.solarSystemName = const Value.absent(),
    this.securityStatus = const Value.absent(),
    this.shipTypeId = const Value.absent(),
    this.shipTypeName = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.lastLogin = const Value.absent(),
    this.lastLogout = const Value.absent(),
    required DateTime lastUpdated,
  }) : lastUpdated = Value(lastUpdated);
  static Insertable<CharacterStatuse> custom({
    Expression<int>? characterId,
    Expression<int>? solarSystemId,
    Expression<String>? solarSystemName,
    Expression<double>? securityStatus,
    Expression<int>? shipTypeId,
    Expression<String>? shipTypeName,
    Expression<bool>? isOnline,
    Expression<DateTime>? lastLogin,
    Expression<DateTime>? lastLogout,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (characterId != null) 'character_id': characterId,
      if (solarSystemId != null) 'solar_system_id': solarSystemId,
      if (solarSystemName != null) 'solar_system_name': solarSystemName,
      if (securityStatus != null) 'security_status': securityStatus,
      if (shipTypeId != null) 'ship_type_id': shipTypeId,
      if (shipTypeName != null) 'ship_type_name': shipTypeName,
      if (isOnline != null) 'is_online': isOnline,
      if (lastLogin != null) 'last_login': lastLogin,
      if (lastLogout != null) 'last_logout': lastLogout,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  CharacterStatusesCompanion copyWith(
      {Value<int>? characterId,
      Value<int?>? solarSystemId,
      Value<String?>? solarSystemName,
      Value<double?>? securityStatus,
      Value<int?>? shipTypeId,
      Value<String?>? shipTypeName,
      Value<bool>? isOnline,
      Value<DateTime?>? lastLogin,
      Value<DateTime?>? lastLogout,
      Value<DateTime>? lastUpdated}) {
    return CharacterStatusesCompanion(
      characterId: characterId ?? this.characterId,
      solarSystemId: solarSystemId ?? this.solarSystemId,
      solarSystemName: solarSystemName ?? this.solarSystemName,
      securityStatus: securityStatus ?? this.securityStatus,
      shipTypeId: shipTypeId ?? this.shipTypeId,
      shipTypeName: shipTypeName ?? this.shipTypeName,
      isOnline: isOnline ?? this.isOnline,
      lastLogin: lastLogin ?? this.lastLogin,
      lastLogout: lastLogout ?? this.lastLogout,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (solarSystemId.present) {
      map['solar_system_id'] = Variable<int>(solarSystemId.value);
    }
    if (solarSystemName.present) {
      map['solar_system_name'] = Variable<String>(solarSystemName.value);
    }
    if (securityStatus.present) {
      map['security_status'] = Variable<double>(securityStatus.value);
    }
    if (shipTypeId.present) {
      map['ship_type_id'] = Variable<int>(shipTypeId.value);
    }
    if (shipTypeName.present) {
      map['ship_type_name'] = Variable<String>(shipTypeName.value);
    }
    if (isOnline.present) {
      map['is_online'] = Variable<bool>(isOnline.value);
    }
    if (lastLogin.present) {
      map['last_login'] = Variable<DateTime>(lastLogin.value);
    }
    if (lastLogout.present) {
      map['last_logout'] = Variable<DateTime>(lastLogout.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharacterStatusesCompanion(')
          ..write('characterId: $characterId, ')
          ..write('solarSystemId: $solarSystemId, ')
          ..write('solarSystemName: $solarSystemName, ')
          ..write('securityStatus: $securityStatus, ')
          ..write('shipTypeId: $shipTypeId, ')
          ..write('shipTypeName: $shipTypeName, ')
          ..write('isOnline: $isOnline, ')
          ..write('lastLogin: $lastLogin, ')
          ..write('lastLogout: $lastLogout, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $UniverseNamesTable extends UniverseNames
    with TableInfo<$UniverseNamesTable, UniverseName> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UniverseNamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<int> lastUpdated = GeneratedColumn<int>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, category, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'universe_names';
  @override
  VerificationContext validateIntegrity(Insertable<UniverseName> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UniverseName map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UniverseName(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $UniverseNamesTable createAlias(String alias) {
    return $UniverseNamesTable(attachedDatabase, alias);
  }
}

class UniverseName extends DataClass implements Insertable<UniverseName> {
  /// EVE ID (primary key).
  final int id;

  /// Resolved name.
  final String name;

  /// Entity category ('character', 'corporation', 'alliance', 'faction',
  /// 'inventory_type', 'solar_system', 'station', etc.).
  final String category;

  /// When this name was last fetched from ESI (Unix timestamp).
  final int lastUpdated;
  const UniverseName(
      {required this.id,
      required this.name,
      required this.category,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['last_updated'] = Variable<int>(lastUpdated);
    return map;
  }

  UniverseNamesCompanion toCompanion(bool nullToAbsent) {
    return UniverseNamesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory UniverseName.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UniverseName(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      lastUpdated: serializer.fromJson<int>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'lastUpdated': serializer.toJson<int>(lastUpdated),
    };
  }

  UniverseName copyWith(
          {int? id, String? name, String? category, int? lastUpdated}) =>
      UniverseName(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  UniverseName copyWithCompanion(UniverseNamesCompanion data) {
    return UniverseName(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UniverseName(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, category, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UniverseName &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.lastUpdated == this.lastUpdated);
}

class UniverseNamesCompanion extends UpdateCompanion<UniverseName> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> category;
  final Value<int> lastUpdated;
  const UniverseNamesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  UniverseNamesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String category,
    required int lastUpdated,
  })  : name = Value(name),
        category = Value(category),
        lastUpdated = Value(lastUpdated);
  static Insertable<UniverseName> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<int>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  UniverseNamesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? category,
      Value<int>? lastUpdated}) {
    return UniverseNamesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<int>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UniverseNamesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $CharacterSkillsTable extends CharacterSkills
    with TableInfo<$CharacterSkillsTable, CharacterSkill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharacterSkillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<int> skillId = GeneratedColumn<int>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _trainedSkillLevelMeta =
      const VerificationMeta('trainedSkillLevel');
  @override
  late final GeneratedColumn<int> trainedSkillLevel = GeneratedColumn<int>(
      'trained_skill_level', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _activeSkillLevelMeta =
      const VerificationMeta('activeSkillLevel');
  @override
  late final GeneratedColumn<int> activeSkillLevel = GeneratedColumn<int>(
      'active_skill_level', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _skillpointsInSkillMeta =
      const VerificationMeta('skillpointsInSkill');
  @override
  late final GeneratedColumn<int> skillpointsInSkill = GeneratedColumn<int>(
      'skillpoints_in_skill', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        characterId,
        skillId,
        trainedSkillLevel,
        activeSkillLevel,
        skillpointsInSkill,
        lastUpdated
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'character_skills';
  @override
  VerificationContext validateIntegrity(Insertable<CharacterSkill> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('trained_skill_level')) {
      context.handle(
          _trainedSkillLevelMeta,
          trainedSkillLevel.isAcceptableOrUnknown(
              data['trained_skill_level']!, _trainedSkillLevelMeta));
    } else if (isInserting) {
      context.missing(_trainedSkillLevelMeta);
    }
    if (data.containsKey('active_skill_level')) {
      context.handle(
          _activeSkillLevelMeta,
          activeSkillLevel.isAcceptableOrUnknown(
              data['active_skill_level']!, _activeSkillLevelMeta));
    } else if (isInserting) {
      context.missing(_activeSkillLevelMeta);
    }
    if (data.containsKey('skillpoints_in_skill')) {
      context.handle(
          _skillpointsInSkillMeta,
          skillpointsInSkill.isAcceptableOrUnknown(
              data['skillpoints_in_skill']!, _skillpointsInSkillMeta));
    } else if (isInserting) {
      context.missing(_skillpointsInSkillMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CharacterSkill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterSkill(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}skill_id'])!,
      trainedSkillLevel: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}trained_skill_level'])!,
      activeSkillLevel: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}active_skill_level'])!,
      skillpointsInSkill: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}skillpoints_in_skill'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $CharacterSkillsTable createAlias(String alias) {
    return $CharacterSkillsTable(attachedDatabase, alias);
  }
}

class CharacterSkill extends DataClass implements Insertable<CharacterSkill> {
  /// Auto-incrementing ID.
  final int id;

  /// Character ID this skill belongs to.
  final int characterId;

  /// Skill type ID from EVE SDE.
  final int skillId;

  /// Trained skill level (0-5).
  final int trainedSkillLevel;

  /// Active skill level (same as trained unless in skillqueue).
  final int activeSkillLevel;

  /// Skill points in this skill.
  final int skillpointsInSkill;

  /// When this data was last fetched from ESI.
  final DateTime lastUpdated;
  const CharacterSkill(
      {required this.id,
      required this.characterId,
      required this.skillId,
      required this.trainedSkillLevel,
      required this.activeSkillLevel,
      required this.skillpointsInSkill,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['skill_id'] = Variable<int>(skillId);
    map['trained_skill_level'] = Variable<int>(trainedSkillLevel);
    map['active_skill_level'] = Variable<int>(activeSkillLevel);
    map['skillpoints_in_skill'] = Variable<int>(skillpointsInSkill);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  CharacterSkillsCompanion toCompanion(bool nullToAbsent) {
    return CharacterSkillsCompanion(
      id: Value(id),
      characterId: Value(characterId),
      skillId: Value(skillId),
      trainedSkillLevel: Value(trainedSkillLevel),
      activeSkillLevel: Value(activeSkillLevel),
      skillpointsInSkill: Value(skillpointsInSkill),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory CharacterSkill.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterSkill(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      skillId: serializer.fromJson<int>(json['skillId']),
      trainedSkillLevel: serializer.fromJson<int>(json['trainedSkillLevel']),
      activeSkillLevel: serializer.fromJson<int>(json['activeSkillLevel']),
      skillpointsInSkill: serializer.fromJson<int>(json['skillpointsInSkill']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'skillId': serializer.toJson<int>(skillId),
      'trainedSkillLevel': serializer.toJson<int>(trainedSkillLevel),
      'activeSkillLevel': serializer.toJson<int>(activeSkillLevel),
      'skillpointsInSkill': serializer.toJson<int>(skillpointsInSkill),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  CharacterSkill copyWith(
          {int? id,
          int? characterId,
          int? skillId,
          int? trainedSkillLevel,
          int? activeSkillLevel,
          int? skillpointsInSkill,
          DateTime? lastUpdated}) =>
      CharacterSkill(
        id: id ?? this.id,
        characterId: characterId ?? this.characterId,
        skillId: skillId ?? this.skillId,
        trainedSkillLevel: trainedSkillLevel ?? this.trainedSkillLevel,
        activeSkillLevel: activeSkillLevel ?? this.activeSkillLevel,
        skillpointsInSkill: skillpointsInSkill ?? this.skillpointsInSkill,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  CharacterSkill copyWithCompanion(CharacterSkillsCompanion data) {
    return CharacterSkill(
      id: data.id.present ? data.id.value : this.id,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      trainedSkillLevel: data.trainedSkillLevel.present
          ? data.trainedSkillLevel.value
          : this.trainedSkillLevel,
      activeSkillLevel: data.activeSkillLevel.present
          ? data.activeSkillLevel.value
          : this.activeSkillLevel,
      skillpointsInSkill: data.skillpointsInSkill.present
          ? data.skillpointsInSkill.value
          : this.skillpointsInSkill,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterSkill(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('skillId: $skillId, ')
          ..write('trainedSkillLevel: $trainedSkillLevel, ')
          ..write('activeSkillLevel: $activeSkillLevel, ')
          ..write('skillpointsInSkill: $skillpointsInSkill, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, characterId, skillId, trainedSkillLevel,
      activeSkillLevel, skillpointsInSkill, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterSkill &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.skillId == this.skillId &&
          other.trainedSkillLevel == this.trainedSkillLevel &&
          other.activeSkillLevel == this.activeSkillLevel &&
          other.skillpointsInSkill == this.skillpointsInSkill &&
          other.lastUpdated == this.lastUpdated);
}

class CharacterSkillsCompanion extends UpdateCompanion<CharacterSkill> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<int> skillId;
  final Value<int> trainedSkillLevel;
  final Value<int> activeSkillLevel;
  final Value<int> skillpointsInSkill;
  final Value<DateTime> lastUpdated;
  const CharacterSkillsCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.trainedSkillLevel = const Value.absent(),
    this.activeSkillLevel = const Value.absent(),
    this.skillpointsInSkill = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  CharacterSkillsCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required int skillId,
    required int trainedSkillLevel,
    required int activeSkillLevel,
    required int skillpointsInSkill,
    required DateTime lastUpdated,
  })  : characterId = Value(characterId),
        skillId = Value(skillId),
        trainedSkillLevel = Value(trainedSkillLevel),
        activeSkillLevel = Value(activeSkillLevel),
        skillpointsInSkill = Value(skillpointsInSkill),
        lastUpdated = Value(lastUpdated);
  static Insertable<CharacterSkill> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<int>? skillId,
    Expression<int>? trainedSkillLevel,
    Expression<int>? activeSkillLevel,
    Expression<int>? skillpointsInSkill,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (skillId != null) 'skill_id': skillId,
      if (trainedSkillLevel != null) 'trained_skill_level': trainedSkillLevel,
      if (activeSkillLevel != null) 'active_skill_level': activeSkillLevel,
      if (skillpointsInSkill != null)
        'skillpoints_in_skill': skillpointsInSkill,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  CharacterSkillsCompanion copyWith(
      {Value<int>? id,
      Value<int>? characterId,
      Value<int>? skillId,
      Value<int>? trainedSkillLevel,
      Value<int>? activeSkillLevel,
      Value<int>? skillpointsInSkill,
      Value<DateTime>? lastUpdated}) {
    return CharacterSkillsCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      skillId: skillId ?? this.skillId,
      trainedSkillLevel: trainedSkillLevel ?? this.trainedSkillLevel,
      activeSkillLevel: activeSkillLevel ?? this.activeSkillLevel,
      skillpointsInSkill: skillpointsInSkill ?? this.skillpointsInSkill,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<int>(skillId.value);
    }
    if (trainedSkillLevel.present) {
      map['trained_skill_level'] = Variable<int>(trainedSkillLevel.value);
    }
    if (activeSkillLevel.present) {
      map['active_skill_level'] = Variable<int>(activeSkillLevel.value);
    }
    if (skillpointsInSkill.present) {
      map['skillpoints_in_skill'] = Variable<int>(skillpointsInSkill.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharacterSkillsCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('skillId: $skillId, ')
          ..write('trainedSkillLevel: $trainedSkillLevel, ')
          ..write('activeSkillLevel: $activeSkillLevel, ')
          ..write('skillpointsInSkill: $skillpointsInSkill, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $SkillPlansTable extends SkillPlans
    with TableInfo<$SkillPlansTable, SkillPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _characterIdMeta =
      const VerificationMeta('characterId');
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
      'character_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES characters (character_id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, characterId, name, description, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skill_plans';
  @override
  VerificationContext validateIntegrity(Insertable<SkillPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('character_id')) {
      context.handle(
          _characterIdMeta,
          characterId.isAcceptableOrUnknown(
              data['character_id']!, _characterIdMeta));
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SkillPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SkillPlan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      characterId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}character_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SkillPlansTable createAlias(String alias) {
    return $SkillPlansTable(attachedDatabase, alias);
  }
}

class SkillPlan extends DataClass implements Insertable<SkillPlan> {
  /// Auto-incrementing ID (primary key).
  final int id;

  /// Character ID this plan belongs to.
  final int characterId;

  /// Plan name (e.g., "PvP Frigate", "Mining Barge").
  final String name;

  /// Optional description of plan purpose.
  final String? description;

  /// When this plan was created.
  final DateTime createdAt;

  /// When this plan was last modified.
  final DateTime updatedAt;
  const SkillPlan(
      {required this.id,
      required this.characterId,
      required this.name,
      this.description,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['character_id'] = Variable<int>(characterId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SkillPlansCompanion toCompanion(bool nullToAbsent) {
    return SkillPlansCompanion(
      id: Value(id),
      characterId: Value(characterId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SkillPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SkillPlan(
      id: serializer.fromJson<int>(json['id']),
      characterId: serializer.fromJson<int>(json['characterId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'characterId': serializer.toJson<int>(characterId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SkillPlan copyWith(
          {int? id,
          int? characterId,
          String? name,
          Value<String?> description = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      SkillPlan(
        id: id ?? this.id,
        characterId: characterId ?? this.characterId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SkillPlan copyWithCompanion(SkillPlansCompanion data) {
    return SkillPlan(
      id: data.id.present ? data.id.value : this.id,
      characterId:
          data.characterId.present ? data.characterId.value : this.characterId,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SkillPlan(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, characterId, name, description, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillPlan &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SkillPlansCompanion extends UpdateCompanion<SkillPlan> {
  final Value<int> id;
  final Value<int> characterId;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SkillPlansCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SkillPlansCompanion.insert({
    this.id = const Value.absent(),
    required int characterId,
    required String name,
    this.description = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : characterId = Value(characterId),
        name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SkillPlan> custom({
    Expression<int>? id,
    Expression<int>? characterId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SkillPlansCompanion copyWith(
      {Value<int>? id,
      Value<int>? characterId,
      Value<String>? name,
      Value<String?>? description,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return SkillPlansCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillPlansCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SkillPlanEntriesTable extends SkillPlanEntries
    with TableInfo<$SkillPlanEntriesTable, SkillPlanEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillPlanEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES skill_plans (id)'));
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<int> skillId = GeneratedColumn<int>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _targetLevelMeta =
      const VerificationMeta('targetLevel');
  @override
  late final GeneratedColumn<int> targetLevel = GeneratedColumn<int>(
      'target_level', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, planId, skillId, targetLevel, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skill_plan_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SkillPlanEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('target_level')) {
      context.handle(
          _targetLevelMeta,
          targetLevel.isAcceptableOrUnknown(
              data['target_level']!, _targetLevelMeta));
    } else if (isInserting) {
      context.missing(_targetLevelMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SkillPlanEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SkillPlanEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plan_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}skill_id'])!,
      targetLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_level'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $SkillPlanEntriesTable createAlias(String alias) {
    return $SkillPlanEntriesTable(attachedDatabase, alias);
  }
}

class SkillPlanEntry extends DataClass implements Insertable<SkillPlanEntry> {
  /// Auto-incrementing ID.
  final int id;

  /// Skill plan ID this entry belongs to.
  final int planId;

  /// Skill type ID from EVE SDE.
  final int skillId;

  /// Target level for this skill (1-5).
  final int targetLevel;

  /// Sort order within the plan (0 = first).
  final int sortOrder;
  const SkillPlanEntry(
      {required this.id,
      required this.planId,
      required this.skillId,
      required this.targetLevel,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<int>(planId);
    map['skill_id'] = Variable<int>(skillId);
    map['target_level'] = Variable<int>(targetLevel);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SkillPlanEntriesCompanion toCompanion(bool nullToAbsent) {
    return SkillPlanEntriesCompanion(
      id: Value(id),
      planId: Value(planId),
      skillId: Value(skillId),
      targetLevel: Value(targetLevel),
      sortOrder: Value(sortOrder),
    );
  }

  factory SkillPlanEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SkillPlanEntry(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<int>(json['planId']),
      skillId: serializer.fromJson<int>(json['skillId']),
      targetLevel: serializer.fromJson<int>(json['targetLevel']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<int>(planId),
      'skillId': serializer.toJson<int>(skillId),
      'targetLevel': serializer.toJson<int>(targetLevel),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SkillPlanEntry copyWith(
          {int? id,
          int? planId,
          int? skillId,
          int? targetLevel,
          int? sortOrder}) =>
      SkillPlanEntry(
        id: id ?? this.id,
        planId: planId ?? this.planId,
        skillId: skillId ?? this.skillId,
        targetLevel: targetLevel ?? this.targetLevel,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  SkillPlanEntry copyWithCompanion(SkillPlanEntriesCompanion data) {
    return SkillPlanEntry(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      targetLevel:
          data.targetLevel.present ? data.targetLevel.value : this.targetLevel,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SkillPlanEntry(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('skillId: $skillId, ')
          ..write('targetLevel: $targetLevel, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, planId, skillId, targetLevel, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillPlanEntry &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.skillId == this.skillId &&
          other.targetLevel == this.targetLevel &&
          other.sortOrder == this.sortOrder);
}

class SkillPlanEntriesCompanion extends UpdateCompanion<SkillPlanEntry> {
  final Value<int> id;
  final Value<int> planId;
  final Value<int> skillId;
  final Value<int> targetLevel;
  final Value<int> sortOrder;
  const SkillPlanEntriesCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.targetLevel = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  SkillPlanEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int planId,
    required int skillId,
    required int targetLevel,
    required int sortOrder,
  })  : planId = Value(planId),
        skillId = Value(skillId),
        targetLevel = Value(targetLevel),
        sortOrder = Value(sortOrder);
  static Insertable<SkillPlanEntry> custom({
    Expression<int>? id,
    Expression<int>? planId,
    Expression<int>? skillId,
    Expression<int>? targetLevel,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (skillId != null) 'skill_id': skillId,
      if (targetLevel != null) 'target_level': targetLevel,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  SkillPlanEntriesCompanion copyWith(
      {Value<int>? id,
      Value<int>? planId,
      Value<int>? skillId,
      Value<int>? targetLevel,
      Value<int>? sortOrder}) {
    return SkillPlanEntriesCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      skillId: skillId ?? this.skillId,
      targetLevel: targetLevel ?? this.targetLevel,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<int>(skillId.value);
    }
    if (targetLevel.present) {
      map['target_level'] = Variable<int>(targetLevel.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillPlanEntriesCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('skillId: $skillId, ')
          ..write('targetLevel: $targetLevel, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $SkillQueueEntriesTable skillQueueEntries =
      $SkillQueueEntriesTable(this);
  late final $WalletJournalEntriesTable walletJournalEntries =
      $WalletJournalEntriesTable(this);
  late final $WalletBalancesTable walletBalances = $WalletBalancesTable(this);
  late final $WalletTransactionsTable walletTransactions =
      $WalletTransactionsTable(this);
  late final $LoyaltyPointsTable loyaltyPoints = $LoyaltyPointsTable(this);
  late final $AssetCacheTable assetCache = $AssetCacheTable(this);
  late final $AppSettingsTableTable appSettingsTable =
      $AppSettingsTableTable(this);
  late final $CombatStatsTable combatStats = $CombatStatsTable(this);
  late final $CharacterStatusesTable characterStatuses =
      $CharacterStatusesTable(this);
  late final $UniverseNamesTable universeNames = $UniverseNamesTable(this);
  late final $CharacterSkillsTable characterSkills =
      $CharacterSkillsTable(this);
  late final $SkillPlansTable skillPlans = $SkillPlansTable(this);
  late final $SkillPlanEntriesTable skillPlanEntries =
      $SkillPlanEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        characters,
        skillQueueEntries,
        walletJournalEntries,
        walletBalances,
        walletTransactions,
        loyaltyPoints,
        assetCache,
        appSettingsTable,
        combatStats,
        characterStatuses,
        universeNames,
        characterSkills,
        skillPlans,
        skillPlanEntries
      ];
}

typedef $$CharactersTableCreateCompanionBuilder = CharactersCompanion Function({
  Value<int> characterId,
  required String name,
  required int corporationId,
  required String corporationName,
  Value<int?> allianceId,
  Value<String?> allianceName,
  Value<int?> factionId,
  Value<double> securityStatus,
  required String portraitUrl,
  Value<String?> refreshToken,
  Value<String?> accessToken,
  required DateTime tokenExpiry,
  required DateTime lastUpdated,
  Value<bool> isActive,
});
typedef $$CharactersTableUpdateCompanionBuilder = CharactersCompanion Function({
  Value<int> characterId,
  Value<String> name,
  Value<int> corporationId,
  Value<String> corporationName,
  Value<int?> allianceId,
  Value<String?> allianceName,
  Value<int?> factionId,
  Value<double> securityStatus,
  Value<String> portraitUrl,
  Value<String?> refreshToken,
  Value<String?> accessToken,
  Value<DateTime> tokenExpiry,
  Value<DateTime> lastUpdated,
  Value<bool> isActive,
});

final class $$CharactersTableReferences
    extends BaseReferences<_$AppDatabase, $CharactersTable, Character> {
  $$CharactersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SkillQueueEntriesTable, List<SkillQueueEntry>>
      _skillQueueEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.skillQueueEntries,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.skillQueueEntries.characterId));

  $$SkillQueueEntriesTableProcessedTableManager get skillQueueEntriesRefs {
    final manager =
        $$SkillQueueEntriesTableTableManager($_db, $_db.skillQueueEntries)
            .filter((f) => f.characterId.characterId
                .sqlEquals($_itemColumn<int>('character_id')!));

    final cache =
        $_typedResult.readTableOrNull(_skillQueueEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WalletJournalEntriesTable,
      List<WalletJournalEntry>> _walletJournalEntriesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.walletJournalEntries,
          aliasName: $_aliasNameGenerator(
              db.characters.characterId, db.walletJournalEntries.characterId));

  $$WalletJournalEntriesTableProcessedTableManager
      get walletJournalEntriesRefs {
    final manager =
        $$WalletJournalEntriesTableTableManager($_db, $_db.walletJournalEntries)
            .filter((f) => f.characterId.characterId
                .sqlEquals($_itemColumn<int>('character_id')!));

    final cache =
        $_typedResult.readTableOrNull(_walletJournalEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WalletBalancesTable, List<WalletBalance>>
      _walletBalancesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.walletBalances,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.walletBalances.characterId));

  $$WalletBalancesTableProcessedTableManager get walletBalancesRefs {
    final manager = $$WalletBalancesTableTableManager($_db, $_db.walletBalances)
        .filter((f) => f.characterId.characterId
            .sqlEquals($_itemColumn<int>('character_id')!));

    final cache = $_typedResult.readTableOrNull(_walletBalancesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WalletTransactionsTable, List<WalletTransaction>>
      _walletTransactionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.walletTransactions,
              aliasName: $_aliasNameGenerator(db.characters.characterId,
                  db.walletTransactions.characterId));

  $$WalletTransactionsTableProcessedTableManager get walletTransactionsRefs {
    final manager =
        $$WalletTransactionsTableTableManager($_db, $_db.walletTransactions)
            .filter((f) => f.characterId.characterId
                .sqlEquals($_itemColumn<int>('character_id')!));

    final cache =
        $_typedResult.readTableOrNull(_walletTransactionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$LoyaltyPointsTable, List<LoyaltyPoint>>
      _loyaltyPointsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.loyaltyPoints,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.loyaltyPoints.characterId));

  $$LoyaltyPointsTableProcessedTableManager get loyaltyPointsRefs {
    final manager = $$LoyaltyPointsTableTableManager($_db, $_db.loyaltyPoints)
        .filter((f) => f.characterId.characterId
            .sqlEquals($_itemColumn<int>('character_id')!));

    final cache = $_typedResult.readTableOrNull(_loyaltyPointsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AssetCacheTable, List<AssetCacheData>>
      _assetCacheRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.assetCache,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.assetCache.characterId));

  $$AssetCacheTableProcessedTableManager get assetCacheRefs {
    final manager = $$AssetCacheTableTableManager($_db, $_db.assetCache).filter(
        (f) => f.characterId.characterId
            .sqlEquals($_itemColumn<int>('character_id')!));

    final cache = $_typedResult.readTableOrNull(_assetCacheRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CombatStatsTable, List<CombatStat>>
      _combatStatsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.combatStats,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.combatStats.characterId));

  $$CombatStatsTableProcessedTableManager get combatStatsRefs {
    final manager = $$CombatStatsTableTableManager($_db, $_db.combatStats)
        .filter((f) => f.characterId.characterId
            .sqlEquals($_itemColumn<int>('character_id')!));

    final cache = $_typedResult.readTableOrNull(_combatStatsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CharacterStatusesTable, List<CharacterStatuse>>
      _characterStatusesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.characterStatuses,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.characterStatuses.characterId));

  $$CharacterStatusesTableProcessedTableManager get characterStatusesRefs {
    final manager =
        $$CharacterStatusesTableTableManager($_db, $_db.characterStatuses)
            .filter((f) => f.characterId.characterId
                .sqlEquals($_itemColumn<int>('character_id')!));

    final cache =
        $_typedResult.readTableOrNull(_characterStatusesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CharacterSkillsTable, List<CharacterSkill>>
      _characterSkillsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.characterSkills,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.characterSkills.characterId));

  $$CharacterSkillsTableProcessedTableManager get characterSkillsRefs {
    final manager =
        $$CharacterSkillsTableTableManager($_db, $_db.characterSkills).filter(
            (f) => f.characterId.characterId
                .sqlEquals($_itemColumn<int>('character_id')!));

    final cache =
        $_typedResult.readTableOrNull(_characterSkillsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SkillPlansTable, List<SkillPlan>>
      _skillPlansRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.skillPlans,
              aliasName: $_aliasNameGenerator(
                  db.characters.characterId, db.skillPlans.characterId));

  $$SkillPlansTableProcessedTableManager get skillPlansRefs {
    final manager = $$SkillPlansTableTableManager($_db, $_db.skillPlans).filter(
        (f) => f.characterId.characterId
            .sqlEquals($_itemColumn<int>('character_id')!));

    final cache = $_typedResult.readTableOrNull(_skillPlansRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get characterId => $composableBuilder(
      column: $table.characterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get corporationId => $composableBuilder(
      column: $table.corporationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get corporationName => $composableBuilder(
      column: $table.corporationName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get allianceId => $composableBuilder(
      column: $table.allianceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get allianceName => $composableBuilder(
      column: $table.allianceName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get factionId => $composableBuilder(
      column: $table.factionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get securityStatus => $composableBuilder(
      column: $table.securityStatus,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get portraitUrl => $composableBuilder(
      column: $table.portraitUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get tokenExpiry => $composableBuilder(
      column: $table.tokenExpiry, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  Expression<bool> skillQueueEntriesRefs(
      Expression<bool> Function($$SkillQueueEntriesTableFilterComposer f) f) {
    final $$SkillQueueEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.skillQueueEntries,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillQueueEntriesTableFilterComposer(
              $db: $db,
              $table: $db.skillQueueEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> walletJournalEntriesRefs(
      Expression<bool> Function($$WalletJournalEntriesTableFilterComposer f)
          f) {
    final $$WalletJournalEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.walletJournalEntries,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletJournalEntriesTableFilterComposer(
              $db: $db,
              $table: $db.walletJournalEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> walletBalancesRefs(
      Expression<bool> Function($$WalletBalancesTableFilterComposer f) f) {
    final $$WalletBalancesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.walletBalances,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletBalancesTableFilterComposer(
              $db: $db,
              $table: $db.walletBalances,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> walletTransactionsRefs(
      Expression<bool> Function($$WalletTransactionsTableFilterComposer f) f) {
    final $$WalletTransactionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.walletTransactions,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletTransactionsTableFilterComposer(
              $db: $db,
              $table: $db.walletTransactions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> loyaltyPointsRefs(
      Expression<bool> Function($$LoyaltyPointsTableFilterComposer f) f) {
    final $$LoyaltyPointsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.loyaltyPoints,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LoyaltyPointsTableFilterComposer(
              $db: $db,
              $table: $db.loyaltyPoints,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> assetCacheRefs(
      Expression<bool> Function($$AssetCacheTableFilterComposer f) f) {
    final $$AssetCacheTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.assetCache,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetCacheTableFilterComposer(
              $db: $db,
              $table: $db.assetCache,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> combatStatsRefs(
      Expression<bool> Function($$CombatStatsTableFilterComposer f) f) {
    final $$CombatStatsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.combatStats,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CombatStatsTableFilterComposer(
              $db: $db,
              $table: $db.combatStats,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> characterStatusesRefs(
      Expression<bool> Function($$CharacterStatusesTableFilterComposer f) f) {
    final $$CharacterStatusesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characterStatuses,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharacterStatusesTableFilterComposer(
              $db: $db,
              $table: $db.characterStatuses,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> characterSkillsRefs(
      Expression<bool> Function($$CharacterSkillsTableFilterComposer f) f) {
    final $$CharacterSkillsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characterSkills,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharacterSkillsTableFilterComposer(
              $db: $db,
              $table: $db.characterSkills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> skillPlansRefs(
      Expression<bool> Function($$SkillPlansTableFilterComposer f) f) {
    final $$SkillPlansTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.skillPlans,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlansTableFilterComposer(
              $db: $db,
              $table: $db.skillPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get characterId => $composableBuilder(
      column: $table.characterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get corporationId => $composableBuilder(
      column: $table.corporationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get corporationName => $composableBuilder(
      column: $table.corporationName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get allianceId => $composableBuilder(
      column: $table.allianceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get allianceName => $composableBuilder(
      column: $table.allianceName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get factionId => $composableBuilder(
      column: $table.factionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get securityStatus => $composableBuilder(
      column: $table.securityStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get portraitUrl => $composableBuilder(
      column: $table.portraitUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get tokenExpiry => $composableBuilder(
      column: $table.tokenExpiry, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get characterId => $composableBuilder(
      column: $table.characterId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get corporationId => $composableBuilder(
      column: $table.corporationId, builder: (column) => column);

  GeneratedColumn<String> get corporationName => $composableBuilder(
      column: $table.corporationName, builder: (column) => column);

  GeneratedColumn<int> get allianceId => $composableBuilder(
      column: $table.allianceId, builder: (column) => column);

  GeneratedColumn<String> get allianceName => $composableBuilder(
      column: $table.allianceName, builder: (column) => column);

  GeneratedColumn<int> get factionId =>
      $composableBuilder(column: $table.factionId, builder: (column) => column);

  GeneratedColumn<double> get securityStatus => $composableBuilder(
      column: $table.securityStatus, builder: (column) => column);

  GeneratedColumn<String> get portraitUrl => $composableBuilder(
      column: $table.portraitUrl, builder: (column) => column);

  GeneratedColumn<String> get refreshToken => $composableBuilder(
      column: $table.refreshToken, builder: (column) => column);

  GeneratedColumn<String> get accessToken => $composableBuilder(
      column: $table.accessToken, builder: (column) => column);

  GeneratedColumn<DateTime> get tokenExpiry => $composableBuilder(
      column: $table.tokenExpiry, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> skillQueueEntriesRefs<T extends Object>(
      Expression<T> Function($$SkillQueueEntriesTableAnnotationComposer a) f) {
    final $$SkillQueueEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.characterId,
            referencedTable: $db.skillQueueEntries,
            getReferencedColumn: (t) => t.characterId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$SkillQueueEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.skillQueueEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> walletJournalEntriesRefs<T extends Object>(
      Expression<T> Function($$WalletJournalEntriesTableAnnotationComposer a)
          f) {
    final $$WalletJournalEntriesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.characterId,
            referencedTable: $db.walletJournalEntries,
            getReferencedColumn: (t) => t.characterId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$WalletJournalEntriesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.walletJournalEntries,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> walletBalancesRefs<T extends Object>(
      Expression<T> Function($$WalletBalancesTableAnnotationComposer a) f) {
    final $$WalletBalancesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.walletBalances,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WalletBalancesTableAnnotationComposer(
              $db: $db,
              $table: $db.walletBalances,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> walletTransactionsRefs<T extends Object>(
      Expression<T> Function($$WalletTransactionsTableAnnotationComposer a) f) {
    final $$WalletTransactionsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.characterId,
            referencedTable: $db.walletTransactions,
            getReferencedColumn: (t) => t.characterId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$WalletTransactionsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.walletTransactions,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> loyaltyPointsRefs<T extends Object>(
      Expression<T> Function($$LoyaltyPointsTableAnnotationComposer a) f) {
    final $$LoyaltyPointsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.loyaltyPoints,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LoyaltyPointsTableAnnotationComposer(
              $db: $db,
              $table: $db.loyaltyPoints,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> assetCacheRefs<T extends Object>(
      Expression<T> Function($$AssetCacheTableAnnotationComposer a) f) {
    final $$AssetCacheTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.assetCache,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssetCacheTableAnnotationComposer(
              $db: $db,
              $table: $db.assetCache,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> combatStatsRefs<T extends Object>(
      Expression<T> Function($$CombatStatsTableAnnotationComposer a) f) {
    final $$CombatStatsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.combatStats,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CombatStatsTableAnnotationComposer(
              $db: $db,
              $table: $db.combatStats,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> characterStatusesRefs<T extends Object>(
      Expression<T> Function($$CharacterStatusesTableAnnotationComposer a) f) {
    final $$CharacterStatusesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.characterId,
            referencedTable: $db.characterStatuses,
            getReferencedColumn: (t) => t.characterId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$CharacterStatusesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.characterStatuses,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> characterSkillsRefs<T extends Object>(
      Expression<T> Function($$CharacterSkillsTableAnnotationComposer a) f) {
    final $$CharacterSkillsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characterSkills,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharacterSkillsTableAnnotationComposer(
              $db: $db,
              $table: $db.characterSkills,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> skillPlansRefs<T extends Object>(
      Expression<T> Function($$SkillPlansTableAnnotationComposer a) f) {
    final $$SkillPlansTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.skillPlans,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlansTableAnnotationComposer(
              $db: $db,
              $table: $db.skillPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CharactersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CharactersTable,
    Character,
    $$CharactersTableFilterComposer,
    $$CharactersTableOrderingComposer,
    $$CharactersTableAnnotationComposer,
    $$CharactersTableCreateCompanionBuilder,
    $$CharactersTableUpdateCompanionBuilder,
    (Character, $$CharactersTableReferences),
    Character,
    PrefetchHooks Function(
        {bool skillQueueEntriesRefs,
        bool walletJournalEntriesRefs,
        bool walletBalancesRefs,
        bool walletTransactionsRefs,
        bool loyaltyPointsRefs,
        bool assetCacheRefs,
        bool combatStatsRefs,
        bool characterStatusesRefs,
        bool characterSkillsRefs,
        bool skillPlansRefs})> {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> characterId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> corporationId = const Value.absent(),
            Value<String> corporationName = const Value.absent(),
            Value<int?> allianceId = const Value.absent(),
            Value<String?> allianceName = const Value.absent(),
            Value<int?> factionId = const Value.absent(),
            Value<double> securityStatus = const Value.absent(),
            Value<String> portraitUrl = const Value.absent(),
            Value<String?> refreshToken = const Value.absent(),
            Value<String?> accessToken = const Value.absent(),
            Value<DateTime> tokenExpiry = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              CharactersCompanion(
            characterId: characterId,
            name: name,
            corporationId: corporationId,
            corporationName: corporationName,
            allianceId: allianceId,
            allianceName: allianceName,
            factionId: factionId,
            securityStatus: securityStatus,
            portraitUrl: portraitUrl,
            refreshToken: refreshToken,
            accessToken: accessToken,
            tokenExpiry: tokenExpiry,
            lastUpdated: lastUpdated,
            isActive: isActive,
          ),
          createCompanionCallback: ({
            Value<int> characterId = const Value.absent(),
            required String name,
            required int corporationId,
            required String corporationName,
            Value<int?> allianceId = const Value.absent(),
            Value<String?> allianceName = const Value.absent(),
            Value<int?> factionId = const Value.absent(),
            Value<double> securityStatus = const Value.absent(),
            required String portraitUrl,
            Value<String?> refreshToken = const Value.absent(),
            Value<String?> accessToken = const Value.absent(),
            required DateTime tokenExpiry,
            required DateTime lastUpdated,
            Value<bool> isActive = const Value.absent(),
          }) =>
              CharactersCompanion.insert(
            characterId: characterId,
            name: name,
            corporationId: corporationId,
            corporationName: corporationName,
            allianceId: allianceId,
            allianceName: allianceName,
            factionId: factionId,
            securityStatus: securityStatus,
            portraitUrl: portraitUrl,
            refreshToken: refreshToken,
            accessToken: accessToken,
            tokenExpiry: tokenExpiry,
            lastUpdated: lastUpdated,
            isActive: isActive,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CharactersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {skillQueueEntriesRefs = false,
              walletJournalEntriesRefs = false,
              walletBalancesRefs = false,
              walletTransactionsRefs = false,
              loyaltyPointsRefs = false,
              assetCacheRefs = false,
              combatStatsRefs = false,
              characterStatusesRefs = false,
              characterSkillsRefs = false,
              skillPlansRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (skillQueueEntriesRefs) db.skillQueueEntries,
                if (walletJournalEntriesRefs) db.walletJournalEntries,
                if (walletBalancesRefs) db.walletBalances,
                if (walletTransactionsRefs) db.walletTransactions,
                if (loyaltyPointsRefs) db.loyaltyPoints,
                if (assetCacheRefs) db.assetCache,
                if (combatStatsRefs) db.combatStats,
                if (characterStatusesRefs) db.characterStatuses,
                if (characterSkillsRefs) db.characterSkills,
                if (skillPlansRefs) db.skillPlans
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (skillQueueEntriesRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            SkillQueueEntry>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._skillQueueEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .skillQueueEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (walletJournalEntriesRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            WalletJournalEntry>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._walletJournalEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .walletJournalEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (walletBalancesRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            WalletBalance>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._walletBalancesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .walletBalancesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (walletTransactionsRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            WalletTransaction>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._walletTransactionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .walletTransactionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (loyaltyPointsRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            LoyaltyPoint>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._loyaltyPointsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .loyaltyPointsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (assetCacheRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            AssetCacheData>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._assetCacheRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .assetCacheRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (combatStatsRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            CombatStat>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._combatStatsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .combatStatsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (characterStatusesRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            CharacterStatuse>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._characterStatusesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .characterStatusesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (characterSkillsRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            CharacterSkill>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._characterSkillsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .characterSkillsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items),
                  if (skillPlansRefs)
                    await $_getPrefetchedData<Character, $CharactersTable,
                            SkillPlan>(
                        currentTable: table,
                        referencedTable: $$CharactersTableReferences
                            ._skillPlansRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CharactersTableReferences(db, table, p0)
                                .skillPlansRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems.where(
                                (e) => e.characterId == item.characterId),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CharactersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CharactersTable,
    Character,
    $$CharactersTableFilterComposer,
    $$CharactersTableOrderingComposer,
    $$CharactersTableAnnotationComposer,
    $$CharactersTableCreateCompanionBuilder,
    $$CharactersTableUpdateCompanionBuilder,
    (Character, $$CharactersTableReferences),
    Character,
    PrefetchHooks Function(
        {bool skillQueueEntriesRefs,
        bool walletJournalEntriesRefs,
        bool walletBalancesRefs,
        bool walletTransactionsRefs,
        bool loyaltyPointsRefs,
        bool assetCacheRefs,
        bool combatStatsRefs,
        bool characterStatusesRefs,
        bool characterSkillsRefs,
        bool skillPlansRefs})>;
typedef $$SkillQueueEntriesTableCreateCompanionBuilder
    = SkillQueueEntriesCompanion Function({
  Value<int> id,
  required int characterId,
  required int queuePosition,
  required int skillId,
  required int finishedLevel,
  Value<DateTime?> startDate,
  Value<DateTime?> finishDate,
  Value<int?> trainingStartSp,
  Value<int?> levelEndSp,
  Value<int?> levelStartSp,
});
typedef $$SkillQueueEntriesTableUpdateCompanionBuilder
    = SkillQueueEntriesCompanion Function({
  Value<int> id,
  Value<int> characterId,
  Value<int> queuePosition,
  Value<int> skillId,
  Value<int> finishedLevel,
  Value<DateTime?> startDate,
  Value<DateTime?> finishDate,
  Value<int?> trainingStartSp,
  Value<int?> levelEndSp,
  Value<int?> levelStartSp,
});

final class $$SkillQueueEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $SkillQueueEntriesTable, SkillQueueEntry> {
  $$SkillQueueEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.skillQueueEntries.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SkillQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SkillQueueEntriesTable> {
  $$SkillQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get queuePosition => $composableBuilder(
      column: $table.queuePosition, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get finishedLevel => $composableBuilder(
      column: $table.finishedLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get finishDate => $composableBuilder(
      column: $table.finishDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainingStartSp => $composableBuilder(
      column: $table.trainingStartSp,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get levelEndSp => $composableBuilder(
      column: $table.levelEndSp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get levelStartSp => $composableBuilder(
      column: $table.levelStartSp, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SkillQueueEntriesTable> {
  $$SkillQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get queuePosition => $composableBuilder(
      column: $table.queuePosition,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get finishedLevel => $composableBuilder(
      column: $table.finishedLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get finishDate => $composableBuilder(
      column: $table.finishDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainingStartSp => $composableBuilder(
      column: $table.trainingStartSp,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get levelEndSp => $composableBuilder(
      column: $table.levelEndSp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get levelStartSp => $composableBuilder(
      column: $table.levelStartSp,
      builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SkillQueueEntriesTable> {
  $$SkillQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get queuePosition => $composableBuilder(
      column: $table.queuePosition, builder: (column) => column);

  GeneratedColumn<int> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get finishedLevel => $composableBuilder(
      column: $table.finishedLevel, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get finishDate => $composableBuilder(
      column: $table.finishDate, builder: (column) => column);

  GeneratedColumn<int> get trainingStartSp => $composableBuilder(
      column: $table.trainingStartSp, builder: (column) => column);

  GeneratedColumn<int> get levelEndSp => $composableBuilder(
      column: $table.levelEndSp, builder: (column) => column);

  GeneratedColumn<int> get levelStartSp => $composableBuilder(
      column: $table.levelStartSp, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillQueueEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SkillQueueEntriesTable,
    SkillQueueEntry,
    $$SkillQueueEntriesTableFilterComposer,
    $$SkillQueueEntriesTableOrderingComposer,
    $$SkillQueueEntriesTableAnnotationComposer,
    $$SkillQueueEntriesTableCreateCompanionBuilder,
    $$SkillQueueEntriesTableUpdateCompanionBuilder,
    (SkillQueueEntry, $$SkillQueueEntriesTableReferences),
    SkillQueueEntry,
    PrefetchHooks Function({bool characterId})> {
  $$SkillQueueEntriesTableTableManager(
      _$AppDatabase db, $SkillQueueEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillQueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillQueueEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<int> queuePosition = const Value.absent(),
            Value<int> skillId = const Value.absent(),
            Value<int> finishedLevel = const Value.absent(),
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> finishDate = const Value.absent(),
            Value<int?> trainingStartSp = const Value.absent(),
            Value<int?> levelEndSp = const Value.absent(),
            Value<int?> levelStartSp = const Value.absent(),
          }) =>
              SkillQueueEntriesCompanion(
            id: id,
            characterId: characterId,
            queuePosition: queuePosition,
            skillId: skillId,
            finishedLevel: finishedLevel,
            startDate: startDate,
            finishDate: finishDate,
            trainingStartSp: trainingStartSp,
            levelEndSp: levelEndSp,
            levelStartSp: levelStartSp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int characterId,
            required int queuePosition,
            required int skillId,
            required int finishedLevel,
            Value<DateTime?> startDate = const Value.absent(),
            Value<DateTime?> finishDate = const Value.absent(),
            Value<int?> trainingStartSp = const Value.absent(),
            Value<int?> levelEndSp = const Value.absent(),
            Value<int?> levelStartSp = const Value.absent(),
          }) =>
              SkillQueueEntriesCompanion.insert(
            id: id,
            characterId: characterId,
            queuePosition: queuePosition,
            skillId: skillId,
            finishedLevel: finishedLevel,
            startDate: startDate,
            finishDate: finishDate,
            trainingStartSp: trainingStartSp,
            levelEndSp: levelEndSp,
            levelStartSp: levelStartSp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SkillQueueEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable: $$SkillQueueEntriesTableReferences
                        ._characterIdTable(db),
                    referencedColumn: $$SkillQueueEntriesTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SkillQueueEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SkillQueueEntriesTable,
    SkillQueueEntry,
    $$SkillQueueEntriesTableFilterComposer,
    $$SkillQueueEntriesTableOrderingComposer,
    $$SkillQueueEntriesTableAnnotationComposer,
    $$SkillQueueEntriesTableCreateCompanionBuilder,
    $$SkillQueueEntriesTableUpdateCompanionBuilder,
    (SkillQueueEntry, $$SkillQueueEntriesTableReferences),
    SkillQueueEntry,
    PrefetchHooks Function({bool characterId})>;
typedef $$WalletJournalEntriesTableCreateCompanionBuilder
    = WalletJournalEntriesCompanion Function({
  Value<int> id,
  required int characterId,
  required double amount,
  required double balance,
  required String refType,
  Value<int?> firstPartyId,
  Value<int?> secondPartyId,
  Value<String?> description,
  required DateTime date,
});
typedef $$WalletJournalEntriesTableUpdateCompanionBuilder
    = WalletJournalEntriesCompanion Function({
  Value<int> id,
  Value<int> characterId,
  Value<double> amount,
  Value<double> balance,
  Value<String> refType,
  Value<int?> firstPartyId,
  Value<int?> secondPartyId,
  Value<String?> description,
  Value<DateTime> date,
});

final class $$WalletJournalEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $WalletJournalEntriesTable, WalletJournalEntry> {
  $$WalletJournalEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.walletJournalEntries.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WalletJournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WalletJournalEntriesTable> {
  $$WalletJournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get refType => $composableBuilder(
      column: $table.refType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get firstPartyId => $composableBuilder(
      column: $table.firstPartyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get secondPartyId => $composableBuilder(
      column: $table.secondPartyId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletJournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletJournalEntriesTable> {
  $$WalletJournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get refType => $composableBuilder(
      column: $table.refType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get firstPartyId => $composableBuilder(
      column: $table.firstPartyId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get secondPartyId => $composableBuilder(
      column: $table.secondPartyId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletJournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletJournalEntriesTable> {
  $$WalletJournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<String> get refType =>
      $composableBuilder(column: $table.refType, builder: (column) => column);

  GeneratedColumn<int> get firstPartyId => $composableBuilder(
      column: $table.firstPartyId, builder: (column) => column);

  GeneratedColumn<int> get secondPartyId => $composableBuilder(
      column: $table.secondPartyId, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletJournalEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WalletJournalEntriesTable,
    WalletJournalEntry,
    $$WalletJournalEntriesTableFilterComposer,
    $$WalletJournalEntriesTableOrderingComposer,
    $$WalletJournalEntriesTableAnnotationComposer,
    $$WalletJournalEntriesTableCreateCompanionBuilder,
    $$WalletJournalEntriesTableUpdateCompanionBuilder,
    (WalletJournalEntry, $$WalletJournalEntriesTableReferences),
    WalletJournalEntry,
    PrefetchHooks Function({bool characterId})> {
  $$WalletJournalEntriesTableTableManager(
      _$AppDatabase db, $WalletJournalEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletJournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletJournalEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletJournalEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<String> refType = const Value.absent(),
            Value<int?> firstPartyId = const Value.absent(),
            Value<int?> secondPartyId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
          }) =>
              WalletJournalEntriesCompanion(
            id: id,
            characterId: characterId,
            amount: amount,
            balance: balance,
            refType: refType,
            firstPartyId: firstPartyId,
            secondPartyId: secondPartyId,
            description: description,
            date: date,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int characterId,
            required double amount,
            required double balance,
            required String refType,
            Value<int?> firstPartyId = const Value.absent(),
            Value<int?> secondPartyId = const Value.absent(),
            Value<String?> description = const Value.absent(),
            required DateTime date,
          }) =>
              WalletJournalEntriesCompanion.insert(
            id: id,
            characterId: characterId,
            amount: amount,
            balance: balance,
            refType: refType,
            firstPartyId: firstPartyId,
            secondPartyId: secondPartyId,
            description: description,
            date: date,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WalletJournalEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable: $$WalletJournalEntriesTableReferences
                        ._characterIdTable(db),
                    referencedColumn: $$WalletJournalEntriesTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WalletJournalEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $WalletJournalEntriesTable,
        WalletJournalEntry,
        $$WalletJournalEntriesTableFilterComposer,
        $$WalletJournalEntriesTableOrderingComposer,
        $$WalletJournalEntriesTableAnnotationComposer,
        $$WalletJournalEntriesTableCreateCompanionBuilder,
        $$WalletJournalEntriesTableUpdateCompanionBuilder,
        (WalletJournalEntry, $$WalletJournalEntriesTableReferences),
        WalletJournalEntry,
        PrefetchHooks Function({bool characterId})>;
typedef $$WalletBalancesTableCreateCompanionBuilder = WalletBalancesCompanion
    Function({
  Value<int> id,
  required int characterId,
  required double balance,
  required DateTime recordedAt,
});
typedef $$WalletBalancesTableUpdateCompanionBuilder = WalletBalancesCompanion
    Function({
  Value<int> id,
  Value<int> characterId,
  Value<double> balance,
  Value<DateTime> recordedAt,
});

final class $$WalletBalancesTableReferences
    extends BaseReferences<_$AppDatabase, $WalletBalancesTable, WalletBalance> {
  $$WalletBalancesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.walletBalances.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WalletBalancesTableFilterComposer
    extends Composer<_$AppDatabase, $WalletBalancesTable> {
  $$WalletBalancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletBalancesTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletBalancesTable> {
  $$WalletBalancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletBalancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletBalancesTable> {
  $$WalletBalancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
      column: $table.recordedAt, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletBalancesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WalletBalancesTable,
    WalletBalance,
    $$WalletBalancesTableFilterComposer,
    $$WalletBalancesTableOrderingComposer,
    $$WalletBalancesTableAnnotationComposer,
    $$WalletBalancesTableCreateCompanionBuilder,
    $$WalletBalancesTableUpdateCompanionBuilder,
    (WalletBalance, $$WalletBalancesTableReferences),
    WalletBalance,
    PrefetchHooks Function({bool characterId})> {
  $$WalletBalancesTableTableManager(
      _$AppDatabase db, $WalletBalancesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletBalancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletBalancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletBalancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<DateTime> recordedAt = const Value.absent(),
          }) =>
              WalletBalancesCompanion(
            id: id,
            characterId: characterId,
            balance: balance,
            recordedAt: recordedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int characterId,
            required double balance,
            required DateTime recordedAt,
          }) =>
              WalletBalancesCompanion.insert(
            id: id,
            characterId: characterId,
            balance: balance,
            recordedAt: recordedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WalletBalancesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable:
                        $$WalletBalancesTableReferences._characterIdTable(db),
                    referencedColumn: $$WalletBalancesTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WalletBalancesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WalletBalancesTable,
    WalletBalance,
    $$WalletBalancesTableFilterComposer,
    $$WalletBalancesTableOrderingComposer,
    $$WalletBalancesTableAnnotationComposer,
    $$WalletBalancesTableCreateCompanionBuilder,
    $$WalletBalancesTableUpdateCompanionBuilder,
    (WalletBalance, $$WalletBalancesTableReferences),
    WalletBalance,
    PrefetchHooks Function({bool characterId})>;
typedef $$WalletTransactionsTableCreateCompanionBuilder
    = WalletTransactionsCompanion Function({
  Value<int> transactionId,
  required int characterId,
  required int typeId,
  required int locationId,
  required double unitPrice,
  required int quantity,
  required bool isBuy,
  required int clientId,
  required DateTime date,
  Value<int?> journalRefId,
});
typedef $$WalletTransactionsTableUpdateCompanionBuilder
    = WalletTransactionsCompanion Function({
  Value<int> transactionId,
  Value<int> characterId,
  Value<int> typeId,
  Value<int> locationId,
  Value<double> unitPrice,
  Value<int> quantity,
  Value<bool> isBuy,
  Value<int> clientId,
  Value<DateTime> date,
  Value<int?> journalRefId,
});

final class $$WalletTransactionsTableReferences extends BaseReferences<
    _$AppDatabase, $WalletTransactionsTable, WalletTransaction> {
  $$WalletTransactionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.walletTransactions.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WalletTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletTransactionsTable> {
  $$WalletTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isBuy => $composableBuilder(
      column: $table.isBuy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get journalRefId => $composableBuilder(
      column: $table.journalRefId, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletTransactionsTable> {
  $$WalletTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isBuy => $composableBuilder(
      column: $table.isBuy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get journalRefId => $composableBuilder(
      column: $table.journalRefId,
      builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletTransactionsTable> {
  $$WalletTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<bool> get isBuy =>
      $composableBuilder(column: $table.isBuy, builder: (column) => column);

  GeneratedColumn<int> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get journalRefId => $composableBuilder(
      column: $table.journalRefId, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WalletTransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WalletTransactionsTable,
    WalletTransaction,
    $$WalletTransactionsTableFilterComposer,
    $$WalletTransactionsTableOrderingComposer,
    $$WalletTransactionsTableAnnotationComposer,
    $$WalletTransactionsTableCreateCompanionBuilder,
    $$WalletTransactionsTableUpdateCompanionBuilder,
    (WalletTransaction, $$WalletTransactionsTableReferences),
    WalletTransaction,
    PrefetchHooks Function({bool characterId})> {
  $$WalletTransactionsTableTableManager(
      _$AppDatabase db, $WalletTransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletTransactionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> transactionId = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<int> typeId = const Value.absent(),
            Value<int> locationId = const Value.absent(),
            Value<double> unitPrice = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<bool> isBuy = const Value.absent(),
            Value<int> clientId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int?> journalRefId = const Value.absent(),
          }) =>
              WalletTransactionsCompanion(
            transactionId: transactionId,
            characterId: characterId,
            typeId: typeId,
            locationId: locationId,
            unitPrice: unitPrice,
            quantity: quantity,
            isBuy: isBuy,
            clientId: clientId,
            date: date,
            journalRefId: journalRefId,
          ),
          createCompanionCallback: ({
            Value<int> transactionId = const Value.absent(),
            required int characterId,
            required int typeId,
            required int locationId,
            required double unitPrice,
            required int quantity,
            required bool isBuy,
            required int clientId,
            required DateTime date,
            Value<int?> journalRefId = const Value.absent(),
          }) =>
              WalletTransactionsCompanion.insert(
            transactionId: transactionId,
            characterId: characterId,
            typeId: typeId,
            locationId: locationId,
            unitPrice: unitPrice,
            quantity: quantity,
            isBuy: isBuy,
            clientId: clientId,
            date: date,
            journalRefId: journalRefId,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WalletTransactionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable: $$WalletTransactionsTableReferences
                        ._characterIdTable(db),
                    referencedColumn: $$WalletTransactionsTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WalletTransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WalletTransactionsTable,
    WalletTransaction,
    $$WalletTransactionsTableFilterComposer,
    $$WalletTransactionsTableOrderingComposer,
    $$WalletTransactionsTableAnnotationComposer,
    $$WalletTransactionsTableCreateCompanionBuilder,
    $$WalletTransactionsTableUpdateCompanionBuilder,
    (WalletTransaction, $$WalletTransactionsTableReferences),
    WalletTransaction,
    PrefetchHooks Function({bool characterId})>;
typedef $$LoyaltyPointsTableCreateCompanionBuilder = LoyaltyPointsCompanion
    Function({
  Value<int> id,
  required int characterId,
  required int corporationId,
  required int loyaltyPoints,
  required DateTime lastUpdated,
});
typedef $$LoyaltyPointsTableUpdateCompanionBuilder = LoyaltyPointsCompanion
    Function({
  Value<int> id,
  Value<int> characterId,
  Value<int> corporationId,
  Value<int> loyaltyPoints,
  Value<DateTime> lastUpdated,
});

final class $$LoyaltyPointsTableReferences
    extends BaseReferences<_$AppDatabase, $LoyaltyPointsTable, LoyaltyPoint> {
  $$LoyaltyPointsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.loyaltyPoints.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LoyaltyPointsTableFilterComposer
    extends Composer<_$AppDatabase, $LoyaltyPointsTable> {
  $$LoyaltyPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get corporationId => $composableBuilder(
      column: $table.corporationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get loyaltyPoints => $composableBuilder(
      column: $table.loyaltyPoints, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LoyaltyPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $LoyaltyPointsTable> {
  $$LoyaltyPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get corporationId => $composableBuilder(
      column: $table.corporationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get loyaltyPoints => $composableBuilder(
      column: $table.loyaltyPoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LoyaltyPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LoyaltyPointsTable> {
  $$LoyaltyPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get corporationId => $composableBuilder(
      column: $table.corporationId, builder: (column) => column);

  GeneratedColumn<int> get loyaltyPoints => $composableBuilder(
      column: $table.loyaltyPoints, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LoyaltyPointsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LoyaltyPointsTable,
    LoyaltyPoint,
    $$LoyaltyPointsTableFilterComposer,
    $$LoyaltyPointsTableOrderingComposer,
    $$LoyaltyPointsTableAnnotationComposer,
    $$LoyaltyPointsTableCreateCompanionBuilder,
    $$LoyaltyPointsTableUpdateCompanionBuilder,
    (LoyaltyPoint, $$LoyaltyPointsTableReferences),
    LoyaltyPoint,
    PrefetchHooks Function({bool characterId})> {
  $$LoyaltyPointsTableTableManager(_$AppDatabase db, $LoyaltyPointsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoyaltyPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoyaltyPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LoyaltyPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<int> corporationId = const Value.absent(),
            Value<int> loyaltyPoints = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              LoyaltyPointsCompanion(
            id: id,
            characterId: characterId,
            corporationId: corporationId,
            loyaltyPoints: loyaltyPoints,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int characterId,
            required int corporationId,
            required int loyaltyPoints,
            required DateTime lastUpdated,
          }) =>
              LoyaltyPointsCompanion.insert(
            id: id,
            characterId: characterId,
            corporationId: corporationId,
            loyaltyPoints: loyaltyPoints,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LoyaltyPointsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable:
                        $$LoyaltyPointsTableReferences._characterIdTable(db),
                    referencedColumn: $$LoyaltyPointsTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LoyaltyPointsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LoyaltyPointsTable,
    LoyaltyPoint,
    $$LoyaltyPointsTableFilterComposer,
    $$LoyaltyPointsTableOrderingComposer,
    $$LoyaltyPointsTableAnnotationComposer,
    $$LoyaltyPointsTableCreateCompanionBuilder,
    $$LoyaltyPointsTableUpdateCompanionBuilder,
    (LoyaltyPoint, $$LoyaltyPointsTableReferences),
    LoyaltyPoint,
    PrefetchHooks Function({bool characterId})>;
typedef $$AssetCacheTableCreateCompanionBuilder = AssetCacheCompanion Function({
  Value<int> itemId,
  required int characterId,
  required int typeId,
  required int quantity,
  required int locationId,
  required DateTime lastUpdated,
});
typedef $$AssetCacheTableUpdateCompanionBuilder = AssetCacheCompanion Function({
  Value<int> itemId,
  Value<int> characterId,
  Value<int> typeId,
  Value<int> quantity,
  Value<int> locationId,
  Value<DateTime> lastUpdated,
});

final class $$AssetCacheTableReferences
    extends BaseReferences<_$AppDatabase, $AssetCacheTable, AssetCacheData> {
  $$AssetCacheTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.assetCache.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AssetCacheTableFilterComposer
    extends Composer<_$AppDatabase, $AssetCacheTable> {
  $$AssetCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssetCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $AssetCacheTable> {
  $$AssetCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssetCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssetCacheTable> {
  $$AssetCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssetCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssetCacheTable,
    AssetCacheData,
    $$AssetCacheTableFilterComposer,
    $$AssetCacheTableOrderingComposer,
    $$AssetCacheTableAnnotationComposer,
    $$AssetCacheTableCreateCompanionBuilder,
    $$AssetCacheTableUpdateCompanionBuilder,
    (AssetCacheData, $$AssetCacheTableReferences),
    AssetCacheData,
    PrefetchHooks Function({bool characterId})> {
  $$AssetCacheTableTableManager(_$AppDatabase db, $AssetCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> itemId = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<int> typeId = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<int> locationId = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              AssetCacheCompanion(
            itemId: itemId,
            characterId: characterId,
            typeId: typeId,
            quantity: quantity,
            locationId: locationId,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> itemId = const Value.absent(),
            required int characterId,
            required int typeId,
            required int quantity,
            required int locationId,
            required DateTime lastUpdated,
          }) =>
              AssetCacheCompanion.insert(
            itemId: itemId,
            characterId: characterId,
            typeId: typeId,
            quantity: quantity,
            locationId: locationId,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AssetCacheTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable:
                        $$AssetCacheTableReferences._characterIdTable(db),
                    referencedColumn: $$AssetCacheTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AssetCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssetCacheTable,
    AssetCacheData,
    $$AssetCacheTableFilterComposer,
    $$AssetCacheTableOrderingComposer,
    $$AssetCacheTableAnnotationComposer,
    $$AssetCacheTableCreateCompanionBuilder,
    $$AssetCacheTableUpdateCompanionBuilder,
    (AssetCacheData, $$AssetCacheTableReferences),
    AssetCacheData,
    PrefetchHooks Function({bool characterId})>;
typedef $$AppSettingsTableTableCreateCompanionBuilder
    = AppSettingsTableCompanion Function({
  Value<int> id,
  Value<String> startupBehavior,
  Value<bool> onboardingComplete,
  Value<int> esiErrorLimitRemain,
  Value<DateTime?> esiErrorLimitReset,
});
typedef $$AppSettingsTableTableUpdateCompanionBuilder
    = AppSettingsTableCompanion Function({
  Value<int> id,
  Value<String> startupBehavior,
  Value<bool> onboardingComplete,
  Value<int> esiErrorLimitRemain,
  Value<DateTime?> esiErrorLimitReset,
});

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startupBehavior => $composableBuilder(
      column: $table.startupBehavior,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get onboardingComplete => $composableBuilder(
      column: $table.onboardingComplete,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get esiErrorLimitRemain => $composableBuilder(
      column: $table.esiErrorLimitRemain,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get esiErrorLimitReset => $composableBuilder(
      column: $table.esiErrorLimitReset,
      builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startupBehavior => $composableBuilder(
      column: $table.startupBehavior,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get onboardingComplete => $composableBuilder(
      column: $table.onboardingComplete,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get esiErrorLimitRemain => $composableBuilder(
      column: $table.esiErrorLimitRemain,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get esiErrorLimitReset => $composableBuilder(
      column: $table.esiErrorLimitReset,
      builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get startupBehavior => $composableBuilder(
      column: $table.startupBehavior, builder: (column) => column);

  GeneratedColumn<bool> get onboardingComplete => $composableBuilder(
      column: $table.onboardingComplete, builder: (column) => column);

  GeneratedColumn<int> get esiErrorLimitRemain => $composableBuilder(
      column: $table.esiErrorLimitRemain, builder: (column) => column);

  GeneratedColumn<DateTime> get esiErrorLimitReset => $composableBuilder(
      column: $table.esiErrorLimitReset, builder: (column) => column);
}

class $$AppSettingsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTableTable,
    AppSettingsTableData,
    $$AppSettingsTableTableFilterComposer,
    $$AppSettingsTableTableOrderingComposer,
    $$AppSettingsTableTableAnnotationComposer,
    $$AppSettingsTableTableCreateCompanionBuilder,
    $$AppSettingsTableTableUpdateCompanionBuilder,
    (
      AppSettingsTableData,
      BaseReferences<_$AppDatabase, $AppSettingsTableTable,
          AppSettingsTableData>
    ),
    AppSettingsTableData,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableTableManager(
      _$AppDatabase db, $AppSettingsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> startupBehavior = const Value.absent(),
            Value<bool> onboardingComplete = const Value.absent(),
            Value<int> esiErrorLimitRemain = const Value.absent(),
            Value<DateTime?> esiErrorLimitReset = const Value.absent(),
          }) =>
              AppSettingsTableCompanion(
            id: id,
            startupBehavior: startupBehavior,
            onboardingComplete: onboardingComplete,
            esiErrorLimitRemain: esiErrorLimitRemain,
            esiErrorLimitReset: esiErrorLimitReset,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> startupBehavior = const Value.absent(),
            Value<bool> onboardingComplete = const Value.absent(),
            Value<int> esiErrorLimitRemain = const Value.absent(),
            Value<DateTime?> esiErrorLimitReset = const Value.absent(),
          }) =>
              AppSettingsTableCompanion.insert(
            id: id,
            startupBehavior: startupBehavior,
            onboardingComplete: onboardingComplete,
            esiErrorLimitRemain: esiErrorLimitRemain,
            esiErrorLimitReset: esiErrorLimitReset,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTableTable,
    AppSettingsTableData,
    $$AppSettingsTableTableFilterComposer,
    $$AppSettingsTableTableOrderingComposer,
    $$AppSettingsTableTableAnnotationComposer,
    $$AppSettingsTableTableCreateCompanionBuilder,
    $$AppSettingsTableTableUpdateCompanionBuilder,
    (
      AppSettingsTableData,
      BaseReferences<_$AppDatabase, $AppSettingsTableTable,
          AppSettingsTableData>
    ),
    AppSettingsTableData,
    PrefetchHooks Function()>;
typedef $$CombatStatsTableCreateCompanionBuilder = CombatStatsCompanion
    Function({
  Value<int> characterId,
  Value<int> kills,
  Value<int> deaths,
  Value<double> iskDestroyed,
  Value<double> iskLost,
  required DateTime lastUpdated,
});
typedef $$CombatStatsTableUpdateCompanionBuilder = CombatStatsCompanion
    Function({
  Value<int> characterId,
  Value<int> kills,
  Value<int> deaths,
  Value<double> iskDestroyed,
  Value<double> iskLost,
  Value<DateTime> lastUpdated,
});

final class $$CombatStatsTableReferences
    extends BaseReferences<_$AppDatabase, $CombatStatsTable, CombatStat> {
  $$CombatStatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.combatStats.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CombatStatsTableFilterComposer
    extends Composer<_$AppDatabase, $CombatStatsTable> {
  $$CombatStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get kills => $composableBuilder(
      column: $table.kills, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deaths => $composableBuilder(
      column: $table.deaths, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get iskDestroyed => $composableBuilder(
      column: $table.iskDestroyed, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get iskLost => $composableBuilder(
      column: $table.iskLost, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CombatStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $CombatStatsTable> {
  $$CombatStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get kills => $composableBuilder(
      column: $table.kills, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deaths => $composableBuilder(
      column: $table.deaths, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get iskDestroyed => $composableBuilder(
      column: $table.iskDestroyed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get iskLost => $composableBuilder(
      column: $table.iskLost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CombatStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CombatStatsTable> {
  $$CombatStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get kills =>
      $composableBuilder(column: $table.kills, builder: (column) => column);

  GeneratedColumn<int> get deaths =>
      $composableBuilder(column: $table.deaths, builder: (column) => column);

  GeneratedColumn<double> get iskDestroyed => $composableBuilder(
      column: $table.iskDestroyed, builder: (column) => column);

  GeneratedColumn<double> get iskLost =>
      $composableBuilder(column: $table.iskLost, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CombatStatsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CombatStatsTable,
    CombatStat,
    $$CombatStatsTableFilterComposer,
    $$CombatStatsTableOrderingComposer,
    $$CombatStatsTableAnnotationComposer,
    $$CombatStatsTableCreateCompanionBuilder,
    $$CombatStatsTableUpdateCompanionBuilder,
    (CombatStat, $$CombatStatsTableReferences),
    CombatStat,
    PrefetchHooks Function({bool characterId})> {
  $$CombatStatsTableTableManager(_$AppDatabase db, $CombatStatsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CombatStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CombatStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CombatStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> characterId = const Value.absent(),
            Value<int> kills = const Value.absent(),
            Value<int> deaths = const Value.absent(),
            Value<double> iskDestroyed = const Value.absent(),
            Value<double> iskLost = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              CombatStatsCompanion(
            characterId: characterId,
            kills: kills,
            deaths: deaths,
            iskDestroyed: iskDestroyed,
            iskLost: iskLost,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> characterId = const Value.absent(),
            Value<int> kills = const Value.absent(),
            Value<int> deaths = const Value.absent(),
            Value<double> iskDestroyed = const Value.absent(),
            Value<double> iskLost = const Value.absent(),
            required DateTime lastUpdated,
          }) =>
              CombatStatsCompanion.insert(
            characterId: characterId,
            kills: kills,
            deaths: deaths,
            iskDestroyed: iskDestroyed,
            iskLost: iskLost,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CombatStatsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable:
                        $$CombatStatsTableReferences._characterIdTable(db),
                    referencedColumn: $$CombatStatsTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CombatStatsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CombatStatsTable,
    CombatStat,
    $$CombatStatsTableFilterComposer,
    $$CombatStatsTableOrderingComposer,
    $$CombatStatsTableAnnotationComposer,
    $$CombatStatsTableCreateCompanionBuilder,
    $$CombatStatsTableUpdateCompanionBuilder,
    (CombatStat, $$CombatStatsTableReferences),
    CombatStat,
    PrefetchHooks Function({bool characterId})>;
typedef $$CharacterStatusesTableCreateCompanionBuilder
    = CharacterStatusesCompanion Function({
  Value<int> characterId,
  Value<int?> solarSystemId,
  Value<String?> solarSystemName,
  Value<double?> securityStatus,
  Value<int?> shipTypeId,
  Value<String?> shipTypeName,
  Value<bool> isOnline,
  Value<DateTime?> lastLogin,
  Value<DateTime?> lastLogout,
  required DateTime lastUpdated,
});
typedef $$CharacterStatusesTableUpdateCompanionBuilder
    = CharacterStatusesCompanion Function({
  Value<int> characterId,
  Value<int?> solarSystemId,
  Value<String?> solarSystemName,
  Value<double?> securityStatus,
  Value<int?> shipTypeId,
  Value<String?> shipTypeName,
  Value<bool> isOnline,
  Value<DateTime?> lastLogin,
  Value<DateTime?> lastLogout,
  Value<DateTime> lastUpdated,
});

final class $$CharacterStatusesTableReferences extends BaseReferences<
    _$AppDatabase, $CharacterStatusesTable, CharacterStatuse> {
  $$CharacterStatusesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.characterStatuses.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CharacterStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $CharacterStatusesTable> {
  $$CharacterStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get solarSystemId => $composableBuilder(
      column: $table.solarSystemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get solarSystemName => $composableBuilder(
      column: $table.solarSystemName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get securityStatus => $composableBuilder(
      column: $table.securityStatus,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shipTypeId => $composableBuilder(
      column: $table.shipTypeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shipTypeName => $composableBuilder(
      column: $table.shipTypeName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isOnline => $composableBuilder(
      column: $table.isOnline, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastLogin => $composableBuilder(
      column: $table.lastLogin, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastLogout => $composableBuilder(
      column: $table.lastLogout, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharacterStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $CharacterStatusesTable> {
  $$CharacterStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get solarSystemId => $composableBuilder(
      column: $table.solarSystemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get solarSystemName => $composableBuilder(
      column: $table.solarSystemName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get securityStatus => $composableBuilder(
      column: $table.securityStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shipTypeId => $composableBuilder(
      column: $table.shipTypeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shipTypeName => $composableBuilder(
      column: $table.shipTypeName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isOnline => $composableBuilder(
      column: $table.isOnline, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastLogin => $composableBuilder(
      column: $table.lastLogin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastLogout => $composableBuilder(
      column: $table.lastLogout, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharacterStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharacterStatusesTable> {
  $$CharacterStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get solarSystemId => $composableBuilder(
      column: $table.solarSystemId, builder: (column) => column);

  GeneratedColumn<String> get solarSystemName => $composableBuilder(
      column: $table.solarSystemName, builder: (column) => column);

  GeneratedColumn<double> get securityStatus => $composableBuilder(
      column: $table.securityStatus, builder: (column) => column);

  GeneratedColumn<int> get shipTypeId => $composableBuilder(
      column: $table.shipTypeId, builder: (column) => column);

  GeneratedColumn<String> get shipTypeName => $composableBuilder(
      column: $table.shipTypeName, builder: (column) => column);

  GeneratedColumn<bool> get isOnline =>
      $composableBuilder(column: $table.isOnline, builder: (column) => column);

  GeneratedColumn<DateTime> get lastLogin =>
      $composableBuilder(column: $table.lastLogin, builder: (column) => column);

  GeneratedColumn<DateTime> get lastLogout => $composableBuilder(
      column: $table.lastLogout, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharacterStatusesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CharacterStatusesTable,
    CharacterStatuse,
    $$CharacterStatusesTableFilterComposer,
    $$CharacterStatusesTableOrderingComposer,
    $$CharacterStatusesTableAnnotationComposer,
    $$CharacterStatusesTableCreateCompanionBuilder,
    $$CharacterStatusesTableUpdateCompanionBuilder,
    (CharacterStatuse, $$CharacterStatusesTableReferences),
    CharacterStatuse,
    PrefetchHooks Function({bool characterId})> {
  $$CharacterStatusesTableTableManager(
      _$AppDatabase db, $CharacterStatusesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharacterStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharacterStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharacterStatusesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> characterId = const Value.absent(),
            Value<int?> solarSystemId = const Value.absent(),
            Value<String?> solarSystemName = const Value.absent(),
            Value<double?> securityStatus = const Value.absent(),
            Value<int?> shipTypeId = const Value.absent(),
            Value<String?> shipTypeName = const Value.absent(),
            Value<bool> isOnline = const Value.absent(),
            Value<DateTime?> lastLogin = const Value.absent(),
            Value<DateTime?> lastLogout = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              CharacterStatusesCompanion(
            characterId: characterId,
            solarSystemId: solarSystemId,
            solarSystemName: solarSystemName,
            securityStatus: securityStatus,
            shipTypeId: shipTypeId,
            shipTypeName: shipTypeName,
            isOnline: isOnline,
            lastLogin: lastLogin,
            lastLogout: lastLogout,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> characterId = const Value.absent(),
            Value<int?> solarSystemId = const Value.absent(),
            Value<String?> solarSystemName = const Value.absent(),
            Value<double?> securityStatus = const Value.absent(),
            Value<int?> shipTypeId = const Value.absent(),
            Value<String?> shipTypeName = const Value.absent(),
            Value<bool> isOnline = const Value.absent(),
            Value<DateTime?> lastLogin = const Value.absent(),
            Value<DateTime?> lastLogout = const Value.absent(),
            required DateTime lastUpdated,
          }) =>
              CharacterStatusesCompanion.insert(
            characterId: characterId,
            solarSystemId: solarSystemId,
            solarSystemName: solarSystemName,
            securityStatus: securityStatus,
            shipTypeId: shipTypeId,
            shipTypeName: shipTypeName,
            isOnline: isOnline,
            lastLogin: lastLogin,
            lastLogout: lastLogout,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CharacterStatusesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable: $$CharacterStatusesTableReferences
                        ._characterIdTable(db),
                    referencedColumn: $$CharacterStatusesTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CharacterStatusesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CharacterStatusesTable,
    CharacterStatuse,
    $$CharacterStatusesTableFilterComposer,
    $$CharacterStatusesTableOrderingComposer,
    $$CharacterStatusesTableAnnotationComposer,
    $$CharacterStatusesTableCreateCompanionBuilder,
    $$CharacterStatusesTableUpdateCompanionBuilder,
    (CharacterStatuse, $$CharacterStatusesTableReferences),
    CharacterStatuse,
    PrefetchHooks Function({bool characterId})>;
typedef $$UniverseNamesTableCreateCompanionBuilder = UniverseNamesCompanion
    Function({
  Value<int> id,
  required String name,
  required String category,
  required int lastUpdated,
});
typedef $$UniverseNamesTableUpdateCompanionBuilder = UniverseNamesCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String> category,
  Value<int> lastUpdated,
});

class $$UniverseNamesTableFilterComposer
    extends Composer<_$AppDatabase, $UniverseNamesTable> {
  $$UniverseNamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));
}

class $$UniverseNamesTableOrderingComposer
    extends Composer<_$AppDatabase, $UniverseNamesTable> {
  $$UniverseNamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));
}

class $$UniverseNamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UniverseNamesTable> {
  $$UniverseNamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);
}

class $$UniverseNamesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UniverseNamesTable,
    UniverseName,
    $$UniverseNamesTableFilterComposer,
    $$UniverseNamesTableOrderingComposer,
    $$UniverseNamesTableAnnotationComposer,
    $$UniverseNamesTableCreateCompanionBuilder,
    $$UniverseNamesTableUpdateCompanionBuilder,
    (
      UniverseName,
      BaseReferences<_$AppDatabase, $UniverseNamesTable, UniverseName>
    ),
    UniverseName,
    PrefetchHooks Function()> {
  $$UniverseNamesTableTableManager(_$AppDatabase db, $UniverseNamesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UniverseNamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UniverseNamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UniverseNamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<int> lastUpdated = const Value.absent(),
          }) =>
              UniverseNamesCompanion(
            id: id,
            name: name,
            category: category,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String category,
            required int lastUpdated,
          }) =>
              UniverseNamesCompanion.insert(
            id: id,
            name: name,
            category: category,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UniverseNamesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UniverseNamesTable,
    UniverseName,
    $$UniverseNamesTableFilterComposer,
    $$UniverseNamesTableOrderingComposer,
    $$UniverseNamesTableAnnotationComposer,
    $$UniverseNamesTableCreateCompanionBuilder,
    $$UniverseNamesTableUpdateCompanionBuilder,
    (
      UniverseName,
      BaseReferences<_$AppDatabase, $UniverseNamesTable, UniverseName>
    ),
    UniverseName,
    PrefetchHooks Function()>;
typedef $$CharacterSkillsTableCreateCompanionBuilder = CharacterSkillsCompanion
    Function({
  Value<int> id,
  required int characterId,
  required int skillId,
  required int trainedSkillLevel,
  required int activeSkillLevel,
  required int skillpointsInSkill,
  required DateTime lastUpdated,
});
typedef $$CharacterSkillsTableUpdateCompanionBuilder = CharacterSkillsCompanion
    Function({
  Value<int> id,
  Value<int> characterId,
  Value<int> skillId,
  Value<int> trainedSkillLevel,
  Value<int> activeSkillLevel,
  Value<int> skillpointsInSkill,
  Value<DateTime> lastUpdated,
});

final class $$CharacterSkillsTableReferences extends BaseReferences<
    _$AppDatabase, $CharacterSkillsTable, CharacterSkill> {
  $$CharacterSkillsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.characterSkills.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CharacterSkillsTableFilterComposer
    extends Composer<_$AppDatabase, $CharacterSkillsTable> {
  $$CharacterSkillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainedSkillLevel => $composableBuilder(
      column: $table.trainedSkillLevel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get activeSkillLevel => $composableBuilder(
      column: $table.activeSkillLevel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get skillpointsInSkill => $composableBuilder(
      column: $table.skillpointsInSkill,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharacterSkillsTableOrderingComposer
    extends Composer<_$AppDatabase, $CharacterSkillsTable> {
  $$CharacterSkillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainedSkillLevel => $composableBuilder(
      column: $table.trainedSkillLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get activeSkillLevel => $composableBuilder(
      column: $table.activeSkillLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get skillpointsInSkill => $composableBuilder(
      column: $table.skillpointsInSkill,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharacterSkillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharacterSkillsTable> {
  $$CharacterSkillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get trainedSkillLevel => $composableBuilder(
      column: $table.trainedSkillLevel, builder: (column) => column);

  GeneratedColumn<int> get activeSkillLevel => $composableBuilder(
      column: $table.activeSkillLevel, builder: (column) => column);

  GeneratedColumn<int> get skillpointsInSkill => $composableBuilder(
      column: $table.skillpointsInSkill, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharacterSkillsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CharacterSkillsTable,
    CharacterSkill,
    $$CharacterSkillsTableFilterComposer,
    $$CharacterSkillsTableOrderingComposer,
    $$CharacterSkillsTableAnnotationComposer,
    $$CharacterSkillsTableCreateCompanionBuilder,
    $$CharacterSkillsTableUpdateCompanionBuilder,
    (CharacterSkill, $$CharacterSkillsTableReferences),
    CharacterSkill,
    PrefetchHooks Function({bool characterId})> {
  $$CharacterSkillsTableTableManager(
      _$AppDatabase db, $CharacterSkillsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharacterSkillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharacterSkillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharacterSkillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<int> skillId = const Value.absent(),
            Value<int> trainedSkillLevel = const Value.absent(),
            Value<int> activeSkillLevel = const Value.absent(),
            Value<int> skillpointsInSkill = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              CharacterSkillsCompanion(
            id: id,
            characterId: characterId,
            skillId: skillId,
            trainedSkillLevel: trainedSkillLevel,
            activeSkillLevel: activeSkillLevel,
            skillpointsInSkill: skillpointsInSkill,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int characterId,
            required int skillId,
            required int trainedSkillLevel,
            required int activeSkillLevel,
            required int skillpointsInSkill,
            required DateTime lastUpdated,
          }) =>
              CharacterSkillsCompanion.insert(
            id: id,
            characterId: characterId,
            skillId: skillId,
            trainedSkillLevel: trainedSkillLevel,
            activeSkillLevel: activeSkillLevel,
            skillpointsInSkill: skillpointsInSkill,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CharacterSkillsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({characterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable:
                        $$CharacterSkillsTableReferences._characterIdTable(db),
                    referencedColumn: $$CharacterSkillsTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CharacterSkillsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CharacterSkillsTable,
    CharacterSkill,
    $$CharacterSkillsTableFilterComposer,
    $$CharacterSkillsTableOrderingComposer,
    $$CharacterSkillsTableAnnotationComposer,
    $$CharacterSkillsTableCreateCompanionBuilder,
    $$CharacterSkillsTableUpdateCompanionBuilder,
    (CharacterSkill, $$CharacterSkillsTableReferences),
    CharacterSkill,
    PrefetchHooks Function({bool characterId})>;
typedef $$SkillPlansTableCreateCompanionBuilder = SkillPlansCompanion Function({
  Value<int> id,
  required int characterId,
  required String name,
  Value<String?> description,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$SkillPlansTableUpdateCompanionBuilder = SkillPlansCompanion Function({
  Value<int> id,
  Value<int> characterId,
  Value<String> name,
  Value<String?> description,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$SkillPlansTableReferences
    extends BaseReferences<_$AppDatabase, $SkillPlansTable, SkillPlan> {
  $$SkillPlansTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias($_aliasNameGenerator(
          db.skillPlans.characterId, db.characters.characterId));

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<int>('character_id')!;

    final manager = $$CharactersTableTableManager($_db, $_db.characters)
        .filter((f) => f.characterId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$SkillPlanEntriesTable, List<SkillPlanEntry>>
      _skillPlanEntriesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.skillPlanEntries,
              aliasName: $_aliasNameGenerator(
                  db.skillPlans.id, db.skillPlanEntries.planId));

  $$SkillPlanEntriesTableProcessedTableManager get skillPlanEntriesRefs {
    final manager =
        $$SkillPlanEntriesTableTableManager($_db, $_db.skillPlanEntries)
            .filter((f) => f.planId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_skillPlanEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SkillPlansTableFilterComposer
    extends Composer<_$AppDatabase, $SkillPlansTable> {
  $$SkillPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableFilterComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> skillPlanEntriesRefs(
      Expression<bool> Function($$SkillPlanEntriesTableFilterComposer f) f) {
    final $$SkillPlanEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.skillPlanEntries,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlanEntriesTableFilterComposer(
              $db: $db,
              $table: $db.skillPlanEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SkillPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $SkillPlansTable> {
  $$SkillPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableOrderingComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $SkillPlansTable> {
  $$SkillPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.characterId,
        referencedTable: $db.characters,
        getReferencedColumn: (t) => t.characterId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableAnnotationComposer(
              $db: $db,
              $table: $db.characters,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> skillPlanEntriesRefs<T extends Object>(
      Expression<T> Function($$SkillPlanEntriesTableAnnotationComposer a) f) {
    final $$SkillPlanEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.skillPlanEntries,
        getReferencedColumn: (t) => t.planId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlanEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.skillPlanEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SkillPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SkillPlansTable,
    SkillPlan,
    $$SkillPlansTableFilterComposer,
    $$SkillPlansTableOrderingComposer,
    $$SkillPlansTableAnnotationComposer,
    $$SkillPlansTableCreateCompanionBuilder,
    $$SkillPlansTableUpdateCompanionBuilder,
    (SkillPlan, $$SkillPlansTableReferences),
    SkillPlan,
    PrefetchHooks Function({bool characterId, bool skillPlanEntriesRefs})> {
  $$SkillPlansTableTableManager(_$AppDatabase db, $SkillPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> characterId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              SkillPlansCompanion(
            id: id,
            characterId: characterId,
            name: name,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int characterId,
            required String name,
            Value<String?> description = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
          }) =>
              SkillPlansCompanion.insert(
            id: id,
            characterId: characterId,
            name: name,
            description: description,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SkillPlansTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {characterId = false, skillPlanEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (skillPlanEntriesRefs) db.skillPlanEntries
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (characterId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.characterId,
                    referencedTable:
                        $$SkillPlansTableReferences._characterIdTable(db),
                    referencedColumn: $$SkillPlansTableReferences
                        ._characterIdTable(db)
                        .characterId,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (skillPlanEntriesRefs)
                    await $_getPrefetchedData<SkillPlan, $SkillPlansTable,
                            SkillPlanEntry>(
                        currentTable: table,
                        referencedTable: $$SkillPlansTableReferences
                            ._skillPlanEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SkillPlansTableReferences(db, table, p0)
                                .skillPlanEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.planId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SkillPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SkillPlansTable,
    SkillPlan,
    $$SkillPlansTableFilterComposer,
    $$SkillPlansTableOrderingComposer,
    $$SkillPlansTableAnnotationComposer,
    $$SkillPlansTableCreateCompanionBuilder,
    $$SkillPlansTableUpdateCompanionBuilder,
    (SkillPlan, $$SkillPlansTableReferences),
    SkillPlan,
    PrefetchHooks Function({bool characterId, bool skillPlanEntriesRefs})>;
typedef $$SkillPlanEntriesTableCreateCompanionBuilder
    = SkillPlanEntriesCompanion Function({
  Value<int> id,
  required int planId,
  required int skillId,
  required int targetLevel,
  required int sortOrder,
});
typedef $$SkillPlanEntriesTableUpdateCompanionBuilder
    = SkillPlanEntriesCompanion Function({
  Value<int> id,
  Value<int> planId,
  Value<int> skillId,
  Value<int> targetLevel,
  Value<int> sortOrder,
});

final class $$SkillPlanEntriesTableReferences extends BaseReferences<
    _$AppDatabase, $SkillPlanEntriesTable, SkillPlanEntry> {
  $$SkillPlanEntriesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SkillPlansTable _planIdTable(_$AppDatabase db) =>
      db.skillPlans.createAlias(
          $_aliasNameGenerator(db.skillPlanEntries.planId, db.skillPlans.id));

  $$SkillPlansTableProcessedTableManager get planId {
    final $_column = $_itemColumn<int>('plan_id')!;

    final manager = $$SkillPlansTableTableManager($_db, $_db.skillPlans)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SkillPlanEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SkillPlanEntriesTable> {
  $$SkillPlanEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetLevel => $composableBuilder(
      column: $table.targetLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$SkillPlansTableFilterComposer get planId {
    final $$SkillPlansTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.skillPlans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlansTableFilterComposer(
              $db: $db,
              $table: $db.skillPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillPlanEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SkillPlanEntriesTable> {
  $$SkillPlanEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetLevel => $composableBuilder(
      column: $table.targetLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$SkillPlansTableOrderingComposer get planId {
    final $$SkillPlansTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.skillPlans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlansTableOrderingComposer(
              $db: $db,
              $table: $db.skillPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillPlanEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SkillPlanEntriesTable> {
  $$SkillPlanEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get targetLevel => $composableBuilder(
      column: $table.targetLevel, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$SkillPlansTableAnnotationComposer get planId {
    final $$SkillPlansTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.planId,
        referencedTable: $db.skillPlans,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SkillPlansTableAnnotationComposer(
              $db: $db,
              $table: $db.skillPlans,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SkillPlanEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SkillPlanEntriesTable,
    SkillPlanEntry,
    $$SkillPlanEntriesTableFilterComposer,
    $$SkillPlanEntriesTableOrderingComposer,
    $$SkillPlanEntriesTableAnnotationComposer,
    $$SkillPlanEntriesTableCreateCompanionBuilder,
    $$SkillPlanEntriesTableUpdateCompanionBuilder,
    (SkillPlanEntry, $$SkillPlanEntriesTableReferences),
    SkillPlanEntry,
    PrefetchHooks Function({bool planId})> {
  $$SkillPlanEntriesTableTableManager(
      _$AppDatabase db, $SkillPlanEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillPlanEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillPlanEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillPlanEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> planId = const Value.absent(),
            Value<int> skillId = const Value.absent(),
            Value<int> targetLevel = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
          }) =>
              SkillPlanEntriesCompanion(
            id: id,
            planId: planId,
            skillId: skillId,
            targetLevel: targetLevel,
            sortOrder: sortOrder,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int planId,
            required int skillId,
            required int targetLevel,
            required int sortOrder,
          }) =>
              SkillPlanEntriesCompanion.insert(
            id: id,
            planId: planId,
            skillId: skillId,
            targetLevel: targetLevel,
            sortOrder: sortOrder,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SkillPlanEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (planId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.planId,
                    referencedTable:
                        $$SkillPlanEntriesTableReferences._planIdTable(db),
                    referencedColumn:
                        $$SkillPlanEntriesTableReferences._planIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SkillPlanEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SkillPlanEntriesTable,
    SkillPlanEntry,
    $$SkillPlanEntriesTableFilterComposer,
    $$SkillPlanEntriesTableOrderingComposer,
    $$SkillPlanEntriesTableAnnotationComposer,
    $$SkillPlanEntriesTableCreateCompanionBuilder,
    $$SkillPlanEntriesTableUpdateCompanionBuilder,
    (SkillPlanEntry, $$SkillPlanEntriesTableReferences),
    SkillPlanEntry,
    PrefetchHooks Function({bool planId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$SkillQueueEntriesTableTableManager get skillQueueEntries =>
      $$SkillQueueEntriesTableTableManager(_db, _db.skillQueueEntries);
  $$WalletJournalEntriesTableTableManager get walletJournalEntries =>
      $$WalletJournalEntriesTableTableManager(_db, _db.walletJournalEntries);
  $$WalletBalancesTableTableManager get walletBalances =>
      $$WalletBalancesTableTableManager(_db, _db.walletBalances);
  $$WalletTransactionsTableTableManager get walletTransactions =>
      $$WalletTransactionsTableTableManager(_db, _db.walletTransactions);
  $$LoyaltyPointsTableTableManager get loyaltyPoints =>
      $$LoyaltyPointsTableTableManager(_db, _db.loyaltyPoints);
  $$AssetCacheTableTableManager get assetCache =>
      $$AssetCacheTableTableManager(_db, _db.assetCache);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
  $$CombatStatsTableTableManager get combatStats =>
      $$CombatStatsTableTableManager(_db, _db.combatStats);
  $$CharacterStatusesTableTableManager get characterStatuses =>
      $$CharacterStatusesTableTableManager(_db, _db.characterStatuses);
  $$UniverseNamesTableTableManager get universeNames =>
      $$UniverseNamesTableTableManager(_db, _db.universeNames);
  $$CharacterSkillsTableTableManager get characterSkills =>
      $$CharacterSkillsTableTableManager(_db, _db.characterSkills);
  $$SkillPlansTableTableManager get skillPlans =>
      $$SkillPlansTableTableManager(_db, _db.skillPlans);
  $$SkillPlanEntriesTableTableManager get skillPlanEntries =>
      $$SkillPlanEntriesTableTableManager(_db, _db.skillPlanEntries);
}
