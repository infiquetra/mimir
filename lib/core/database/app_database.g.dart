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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $SkillQueueEntriesTable skillQueueEntries =
      $SkillQueueEntriesTable(this);
  late final $WalletJournalEntriesTable walletJournalEntries =
      $WalletJournalEntriesTable(this);
  late final $WalletBalancesTable walletBalances = $WalletBalancesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [characters, skillQueueEntries, walletJournalEntries, walletBalances];
}

typedef $$CharactersTableCreateCompanionBuilder = CharactersCompanion Function({
  Value<int> characterId,
  required String name,
  required int corporationId,
  required String corporationName,
  Value<int?> allianceId,
  Value<String?> allianceName,
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
        bool walletBalancesRefs})> {
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
              walletBalancesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (skillQueueEntriesRefs) db.skillQueueEntries,
                if (walletJournalEntriesRefs) db.walletJournalEntries,
                if (walletBalancesRefs) db.walletBalances
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
        bool walletBalancesRefs})>;
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
}
