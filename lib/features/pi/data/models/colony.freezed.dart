// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'colony.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Colony {
  int get characterId;
  int get planetId;
  String get planetType;
  String get solarSystemName;
  int get solarSystemId;
  DateTime get lastUpdated;
  int get upgradeLevel;
  int get numPins;
  List<Pin> get pins;

  /// Create a copy of Colony
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ColonyCopyWith<Colony> get copyWith =>
      _$ColonyCopyWithImpl<Colony>(this as Colony, _$identity);

  /// Serializes this Colony to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Colony &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.planetId, planetId) ||
                other.planetId == planetId) &&
            (identical(other.planetType, planetType) ||
                other.planetType == planetType) &&
            (identical(other.solarSystemName, solarSystemName) ||
                other.solarSystemName == solarSystemName) &&
            (identical(other.solarSystemId, solarSystemId) ||
                other.solarSystemId == solarSystemId) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            (identical(other.upgradeLevel, upgradeLevel) ||
                other.upgradeLevel == upgradeLevel) &&
            (identical(other.numPins, numPins) || other.numPins == numPins) &&
            const DeepCollectionEquality().equals(other.pins, pins));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      characterId,
      planetId,
      planetType,
      solarSystemName,
      solarSystemId,
      lastUpdated,
      upgradeLevel,
      numPins,
      const DeepCollectionEquality().hash(pins));
}

/// @nodoc
abstract mixin class $ColonyCopyWith<$Res> {
  factory $ColonyCopyWith(Colony value, $Res Function(Colony) _then) =
      _$ColonyCopyWithImpl;
  @useResult
  $Res call(
      {int characterId,
      int planetId,
      String planetType,
      String solarSystemName,
      int solarSystemId,
      DateTime lastUpdated,
      int upgradeLevel,
      int numPins,
      List<Pin> pins});
}

/// @nodoc
class _$ColonyCopyWithImpl<$Res> implements $ColonyCopyWith<$Res> {
  _$ColonyCopyWithImpl(this._self, this._then);

  final Colony _self;
  final $Res Function(Colony) _then;

  /// Create a copy of Colony
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterId = null,
    Object? planetId = null,
    Object? planetType = null,
    Object? solarSystemName = null,
    Object? solarSystemId = null,
    Object? lastUpdated = null,
    Object? upgradeLevel = null,
    Object? numPins = null,
    Object? pins = null,
  }) {
    return _then(_self.copyWith(
      characterId: null == characterId
          ? _self.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as int,
      planetId: null == planetId
          ? _self.planetId
          : planetId // ignore: cast_nullable_to_non_nullable
              as int,
      planetType: null == planetType
          ? _self.planetType
          : planetType // ignore: cast_nullable_to_non_nullable
              as String,
      solarSystemName: null == solarSystemName
          ? _self.solarSystemName
          : solarSystemName // ignore: cast_nullable_to_non_nullable
              as String,
      solarSystemId: null == solarSystemId
          ? _self.solarSystemId
          : solarSystemId // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdated: null == lastUpdated
          ? _self.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime,
      upgradeLevel: null == upgradeLevel
          ? _self.upgradeLevel
          : upgradeLevel // ignore: cast_nullable_to_non_nullable
              as int,
      numPins: null == numPins
          ? _self.numPins
          : numPins // ignore: cast_nullable_to_non_nullable
              as int,
      pins: null == pins
          ? _self.pins
          : pins // ignore: cast_nullable_to_non_nullable
              as List<Pin>,
    ));
  }
}

/// Adds pattern-matching-related methods to [Colony].
extension ColonyPatterns on Colony {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Colony value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Colony() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_Colony value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Colony():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_Colony value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Colony() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            int characterId,
            int planetId,
            String planetType,
            String solarSystemName,
            int solarSystemId,
            DateTime lastUpdated,
            int upgradeLevel,
            int numPins,
            List<Pin> pins)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Colony() when $default != null:
        return $default(
            _that.characterId,
            _that.planetId,
            _that.planetType,
            _that.solarSystemName,
            _that.solarSystemId,
            _that.lastUpdated,
            _that.upgradeLevel,
            _that.numPins,
            _that.pins);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            int characterId,
            int planetId,
            String planetType,
            String solarSystemName,
            int solarSystemId,
            DateTime lastUpdated,
            int upgradeLevel,
            int numPins,
            List<Pin> pins)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Colony():
        return $default(
            _that.characterId,
            _that.planetId,
            _that.planetType,
            _that.solarSystemName,
            _that.solarSystemId,
            _that.lastUpdated,
            _that.upgradeLevel,
            _that.numPins,
            _that.pins);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            int characterId,
            int planetId,
            String planetType,
            String solarSystemName,
            int solarSystemId,
            DateTime lastUpdated,
            int upgradeLevel,
            int numPins,
            List<Pin> pins)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Colony() when $default != null:
        return $default(
            _that.characterId,
            _that.planetId,
            _that.planetType,
            _that.solarSystemName,
            _that.solarSystemId,
            _that.lastUpdated,
            _that.upgradeLevel,
            _that.numPins,
            _that.pins);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Colony extends Colony {
  const _Colony(
      {required this.characterId,
      required this.planetId,
      required this.planetType,
      required this.solarSystemName,
      required this.solarSystemId,
      required this.lastUpdated,
      required this.upgradeLevel,
      required this.numPins,
      final List<Pin> pins = const []})
      : _pins = pins,
        super._();
  factory _Colony.fromJson(Map<String, dynamic> json) => _$ColonyFromJson(json);

  @override
  final int characterId;
  @override
  final int planetId;
  @override
  final String planetType;
  @override
  final String solarSystemName;
  @override
  final int solarSystemId;
  @override
  final DateTime lastUpdated;
  @override
  final int upgradeLevel;
  @override
  final int numPins;
  final List<Pin> _pins;
  @override
  @JsonKey()
  List<Pin> get pins {
    if (_pins is EqualUnmodifiableListView) return _pins;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pins);
  }

  /// Create a copy of Colony
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ColonyCopyWith<_Colony> get copyWith =>
      __$ColonyCopyWithImpl<_Colony>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ColonyToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Colony &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.planetId, planetId) ||
                other.planetId == planetId) &&
            (identical(other.planetType, planetType) ||
                other.planetType == planetType) &&
            (identical(other.solarSystemName, solarSystemName) ||
                other.solarSystemName == solarSystemName) &&
            (identical(other.solarSystemId, solarSystemId) ||
                other.solarSystemId == solarSystemId) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            (identical(other.upgradeLevel, upgradeLevel) ||
                other.upgradeLevel == upgradeLevel) &&
            (identical(other.numPins, numPins) || other.numPins == numPins) &&
            const DeepCollectionEquality().equals(other._pins, _pins));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      characterId,
      planetId,
      planetType,
      solarSystemName,
      solarSystemId,
      lastUpdated,
      upgradeLevel,
      numPins,
      const DeepCollectionEquality().hash(_pins));
}

/// @nodoc
abstract mixin class _$ColonyCopyWith<$Res> implements $ColonyCopyWith<$Res> {
  factory _$ColonyCopyWith(_Colony value, $Res Function(_Colony) _then) =
      __$ColonyCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int characterId,
      int planetId,
      String planetType,
      String solarSystemName,
      int solarSystemId,
      DateTime lastUpdated,
      int upgradeLevel,
      int numPins,
      List<Pin> pins});
}

/// @nodoc
class __$ColonyCopyWithImpl<$Res> implements _$ColonyCopyWith<$Res> {
  __$ColonyCopyWithImpl(this._self, this._then);

  final _Colony _self;
  final $Res Function(_Colony) _then;

  /// Create a copy of Colony
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? characterId = null,
    Object? planetId = null,
    Object? planetType = null,
    Object? solarSystemName = null,
    Object? solarSystemId = null,
    Object? lastUpdated = null,
    Object? upgradeLevel = null,
    Object? numPins = null,
    Object? pins = null,
  }) {
    return _then(_Colony(
      characterId: null == characterId
          ? _self.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as int,
      planetId: null == planetId
          ? _self.planetId
          : planetId // ignore: cast_nullable_to_non_nullable
              as int,
      planetType: null == planetType
          ? _self.planetType
          : planetType // ignore: cast_nullable_to_non_nullable
              as String,
      solarSystemName: null == solarSystemName
          ? _self.solarSystemName
          : solarSystemName // ignore: cast_nullable_to_non_nullable
              as String,
      solarSystemId: null == solarSystemId
          ? _self.solarSystemId
          : solarSystemId // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdated: null == lastUpdated
          ? _self.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime,
      upgradeLevel: null == upgradeLevel
          ? _self.upgradeLevel
          : upgradeLevel // ignore: cast_nullable_to_non_nullable
              as int,
      numPins: null == numPins
          ? _self.numPins
          : numPins // ignore: cast_nullable_to_non_nullable
              as int,
      pins: null == pins
          ? _self._pins
          : pins // ignore: cast_nullable_to_non_nullable
              as List<Pin>,
    ));
  }
}

Pin _$PinFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'extractor':
      return Extractor.fromJson(json);
    case 'factory':
      return Factory.fromJson(json);
    case 'storage':
      return Storage.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'Pin',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$Pin {
  int get pinId;
  int get typeId;
  String? get typeName;
  double get latitude;
  double get longitude;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PinCopyWith<Pin> get copyWith =>
      _$PinCopyWithImpl<Pin>(this as Pin, _$identity);

  /// Serializes this Pin to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Pin &&
            (identical(other.pinId, pinId) || other.pinId == pinId) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeName, typeName) ||
                other.typeName == typeName) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, pinId, typeId, typeName, latitude, longitude);

  @override
  String toString() {
    return 'Pin(pinId: $pinId, typeId: $typeId, typeName: $typeName, latitude: $latitude, longitude: $longitude)';
  }
}

/// @nodoc
abstract mixin class $PinCopyWith<$Res> {
  factory $PinCopyWith(Pin value, $Res Function(Pin) _then) = _$PinCopyWithImpl;
  @useResult
  $Res call(
      {int pinId,
      int typeId,
      String? typeName,
      double latitude,
      double longitude});
}

/// @nodoc
class _$PinCopyWithImpl<$Res> implements $PinCopyWith<$Res> {
  _$PinCopyWithImpl(this._self, this._then);

  final Pin _self;
  final $Res Function(Pin) _then;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pinId = null,
    Object? typeId = null,
    Object? typeName = freezed,
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(_self.copyWith(
      pinId: null == pinId
          ? _self.pinId
          : pinId // ignore: cast_nullable_to_non_nullable
              as int,
      typeId: null == typeId
          ? _self.typeId
          : typeId // ignore: cast_nullable_to_non_nullable
              as int,
      typeName: freezed == typeName
          ? _self.typeName
          : typeName // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [Pin].
extension PinPatterns on Pin {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Extractor value)? extractor,
    TResult Function(Factory value)? factory,
    TResult Function(Storage value)? storage,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case Extractor() when extractor != null:
        return extractor(_that);
      case Factory() when factory != null:
        return factory(_that);
      case Storage() when storage != null:
        return storage(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Extractor value) extractor,
    required TResult Function(Factory value) factory,
    required TResult Function(Storage value) storage,
  }) {
    final _that = this;
    switch (_that) {
      case Extractor():
        return extractor(_that);
      case Factory():
        return factory(_that);
      case Storage():
        return storage(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(Extractor value)? extractor,
    TResult? Function(Factory value)? factory,
    TResult? Function(Storage value)? storage,
  }) {
    final _that = this;
    switch (_that) {
      case Extractor() when extractor != null:
        return extractor(_that);
      case Factory() when factory != null:
        return factory(_that);
      case Storage() when storage != null:
        return storage(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            int productTypeId,
            DateTime? lastCycleStart,
            Duration? lastCycleDuration,
            DateTime? expiryTime,
            int? qtyPerCycle)?
        extractor,
    TResult Function(int pinId, int typeId, String? typeName, double latitude,
            double longitude, int schematicId, String? schematicName)?
        factory,
    TResult Function(int pinId, int typeId, String? typeName, double latitude,
            double longitude, int capacity, double fillPercentage)?
        storage,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case Extractor() when extractor != null:
        return extractor(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.productTypeId,
            _that.lastCycleStart,
            _that.lastCycleDuration,
            _that.expiryTime,
            _that.qtyPerCycle);
      case Factory() when factory != null:
        return factory(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.schematicId,
            _that.schematicName);
      case Storage() when storage != null:
        return storage(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.capacity,
            _that.fillPercentage);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            int productTypeId,
            DateTime? lastCycleStart,
            Duration? lastCycleDuration,
            DateTime? expiryTime,
            int? qtyPerCycle)
        extractor,
    required TResult Function(
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            int schematicId,
            String? schematicName)
        factory,
    required TResult Function(
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            int capacity,
            double fillPercentage)
        storage,
  }) {
    final _that = this;
    switch (_that) {
      case Extractor():
        return extractor(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.productTypeId,
            _that.lastCycleStart,
            _that.lastCycleDuration,
            _that.expiryTime,
            _that.qtyPerCycle);
      case Factory():
        return factory(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.schematicId,
            _that.schematicName);
      case Storage():
        return storage(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.capacity,
            _that.fillPercentage);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            int productTypeId,
            DateTime? lastCycleStart,
            Duration? lastCycleDuration,
            DateTime? expiryTime,
            int? qtyPerCycle)?
        extractor,
    TResult? Function(int pinId, int typeId, String? typeName, double latitude,
            double longitude, int schematicId, String? schematicName)?
        factory,
    TResult? Function(int pinId, int typeId, String? typeName, double latitude,
            double longitude, int capacity, double fillPercentage)?
        storage,
  }) {
    final _that = this;
    switch (_that) {
      case Extractor() when extractor != null:
        return extractor(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.productTypeId,
            _that.lastCycleStart,
            _that.lastCycleDuration,
            _that.expiryTime,
            _that.qtyPerCycle);
      case Factory() when factory != null:
        return factory(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.schematicId,
            _that.schematicName);
      case Storage() when storage != null:
        return storage(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.capacity,
            _that.fillPercentage);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class Extractor implements Pin {
  const Extractor(
      {required this.pinId,
      required this.typeId,
      this.typeName,
      required this.latitude,
      required this.longitude,
      required this.productTypeId,
      this.lastCycleStart,
      this.lastCycleDuration,
      this.expiryTime,
      this.qtyPerCycle,
      final String? $type})
      : $type = $type ?? 'extractor';
  factory Extractor.fromJson(Map<String, dynamic> json) =>
      _$ExtractorFromJson(json);

  @override
  final int pinId;
  @override
  final int typeId;
  @override
  final String? typeName;
  @override
  final double latitude;
  @override
  final double longitude;
  final int productTypeId;
  final DateTime? lastCycleStart;
  final Duration? lastCycleDuration;
  final DateTime? expiryTime;
  final int? qtyPerCycle;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExtractorCopyWith<Extractor> get copyWith =>
      _$ExtractorCopyWithImpl<Extractor>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ExtractorToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Extractor &&
            (identical(other.pinId, pinId) || other.pinId == pinId) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeName, typeName) ||
                other.typeName == typeName) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.productTypeId, productTypeId) ||
                other.productTypeId == productTypeId) &&
            (identical(other.lastCycleStart, lastCycleStart) ||
                other.lastCycleStart == lastCycleStart) &&
            (identical(other.lastCycleDuration, lastCycleDuration) ||
                other.lastCycleDuration == lastCycleDuration) &&
            (identical(other.expiryTime, expiryTime) ||
                other.expiryTime == expiryTime) &&
            (identical(other.qtyPerCycle, qtyPerCycle) ||
                other.qtyPerCycle == qtyPerCycle));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      pinId,
      typeId,
      typeName,
      latitude,
      longitude,
      productTypeId,
      lastCycleStart,
      lastCycleDuration,
      expiryTime,
      qtyPerCycle);

  @override
  String toString() {
    return 'Pin.extractor(pinId: $pinId, typeId: $typeId, typeName: $typeName, latitude: $latitude, longitude: $longitude, productTypeId: $productTypeId, lastCycleStart: $lastCycleStart, lastCycleDuration: $lastCycleDuration, expiryTime: $expiryTime, qtyPerCycle: $qtyPerCycle)';
  }
}

/// @nodoc
abstract mixin class $ExtractorCopyWith<$Res> implements $PinCopyWith<$Res> {
  factory $ExtractorCopyWith(Extractor value, $Res Function(Extractor) _then) =
      _$ExtractorCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int pinId,
      int typeId,
      String? typeName,
      double latitude,
      double longitude,
      int productTypeId,
      DateTime? lastCycleStart,
      Duration? lastCycleDuration,
      DateTime? expiryTime,
      int? qtyPerCycle});
}

/// @nodoc
class _$ExtractorCopyWithImpl<$Res> implements $ExtractorCopyWith<$Res> {
  _$ExtractorCopyWithImpl(this._self, this._then);

  final Extractor _self;
  final $Res Function(Extractor) _then;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? pinId = null,
    Object? typeId = null,
    Object? typeName = freezed,
    Object? latitude = null,
    Object? longitude = null,
    Object? productTypeId = null,
    Object? lastCycleStart = freezed,
    Object? lastCycleDuration = freezed,
    Object? expiryTime = freezed,
    Object? qtyPerCycle = freezed,
  }) {
    return _then(Extractor(
      pinId: null == pinId
          ? _self.pinId
          : pinId // ignore: cast_nullable_to_non_nullable
              as int,
      typeId: null == typeId
          ? _self.typeId
          : typeId // ignore: cast_nullable_to_non_nullable
              as int,
      typeName: freezed == typeName
          ? _self.typeName
          : typeName // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      productTypeId: null == productTypeId
          ? _self.productTypeId
          : productTypeId // ignore: cast_nullable_to_non_nullable
              as int,
      lastCycleStart: freezed == lastCycleStart
          ? _self.lastCycleStart
          : lastCycleStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastCycleDuration: freezed == lastCycleDuration
          ? _self.lastCycleDuration
          : lastCycleDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      expiryTime: freezed == expiryTime
          ? _self.expiryTime
          : expiryTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      qtyPerCycle: freezed == qtyPerCycle
          ? _self.qtyPerCycle
          : qtyPerCycle // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class Factory implements Pin {
  const Factory(
      {required this.pinId,
      required this.typeId,
      this.typeName,
      required this.latitude,
      required this.longitude,
      required this.schematicId,
      this.schematicName,
      final String? $type})
      : $type = $type ?? 'factory';
  factory Factory.fromJson(Map<String, dynamic> json) =>
      _$FactoryFromJson(json);

  @override
  final int pinId;
  @override
  final int typeId;
  @override
  final String? typeName;
  @override
  final double latitude;
  @override
  final double longitude;
  final int schematicId;
  final String? schematicName;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FactoryCopyWith<Factory> get copyWith =>
      _$FactoryCopyWithImpl<Factory>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FactoryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Factory &&
            (identical(other.pinId, pinId) || other.pinId == pinId) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeName, typeName) ||
                other.typeName == typeName) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.schematicId, schematicId) ||
                other.schematicId == schematicId) &&
            (identical(other.schematicName, schematicName) ||
                other.schematicName == schematicName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, pinId, typeId, typeName,
      latitude, longitude, schematicId, schematicName);

  @override
  String toString() {
    return 'Pin.factory(pinId: $pinId, typeId: $typeId, typeName: $typeName, latitude: $latitude, longitude: $longitude, schematicId: $schematicId, schematicName: $schematicName)';
  }
}

/// @nodoc
abstract mixin class $FactoryCopyWith<$Res> implements $PinCopyWith<$Res> {
  factory $FactoryCopyWith(Factory value, $Res Function(Factory) _then) =
      _$FactoryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int pinId,
      int typeId,
      String? typeName,
      double latitude,
      double longitude,
      int schematicId,
      String? schematicName});
}

/// @nodoc
class _$FactoryCopyWithImpl<$Res> implements $FactoryCopyWith<$Res> {
  _$FactoryCopyWithImpl(this._self, this._then);

  final Factory _self;
  final $Res Function(Factory) _then;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? pinId = null,
    Object? typeId = null,
    Object? typeName = freezed,
    Object? latitude = null,
    Object? longitude = null,
    Object? schematicId = null,
    Object? schematicName = freezed,
  }) {
    return _then(Factory(
      pinId: null == pinId
          ? _self.pinId
          : pinId // ignore: cast_nullable_to_non_nullable
              as int,
      typeId: null == typeId
          ? _self.typeId
          : typeId // ignore: cast_nullable_to_non_nullable
              as int,
      typeName: freezed == typeName
          ? _self.typeName
          : typeName // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      schematicId: null == schematicId
          ? _self.schematicId
          : schematicId // ignore: cast_nullable_to_non_nullable
              as int,
      schematicName: freezed == schematicName
          ? _self.schematicName
          : schematicName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class Storage implements Pin {
  const Storage(
      {required this.pinId,
      required this.typeId,
      this.typeName,
      required this.latitude,
      required this.longitude,
      required this.capacity,
      required this.fillPercentage,
      final String? $type})
      : $type = $type ?? 'storage';
  factory Storage.fromJson(Map<String, dynamic> json) =>
      _$StorageFromJson(json);

  @override
  final int pinId;
  @override
  final int typeId;
  @override
  final String? typeName;
  @override
  final double latitude;
  @override
  final double longitude;
  final int capacity;
  final double fillPercentage;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StorageCopyWith<Storage> get copyWith =>
      _$StorageCopyWithImpl<Storage>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$StorageToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Storage &&
            (identical(other.pinId, pinId) || other.pinId == pinId) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeName, typeName) ||
                other.typeName == typeName) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.capacity, capacity) ||
                other.capacity == capacity) &&
            (identical(other.fillPercentage, fillPercentage) ||
                other.fillPercentage == fillPercentage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, pinId, typeId, typeName,
      latitude, longitude, capacity, fillPercentage);

  @override
  String toString() {
    return 'Pin.storage(pinId: $pinId, typeId: $typeId, typeName: $typeName, latitude: $latitude, longitude: $longitude, capacity: $capacity, fillPercentage: $fillPercentage)';
  }
}

/// @nodoc
abstract mixin class $StorageCopyWith<$Res> implements $PinCopyWith<$Res> {
  factory $StorageCopyWith(Storage value, $Res Function(Storage) _then) =
      _$StorageCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int pinId,
      int typeId,
      String? typeName,
      double latitude,
      double longitude,
      int capacity,
      double fillPercentage});
}

/// @nodoc
class _$StorageCopyWithImpl<$Res> implements $StorageCopyWith<$Res> {
  _$StorageCopyWithImpl(this._self, this._then);

  final Storage _self;
  final $Res Function(Storage) _then;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? pinId = null,
    Object? typeId = null,
    Object? typeName = freezed,
    Object? latitude = null,
    Object? longitude = null,
    Object? capacity = null,
    Object? fillPercentage = null,
  }) {
    return _then(Storage(
      pinId: null == pinId
          ? _self.pinId
          : pinId // ignore: cast_nullable_to_non_nullable
              as int,
      typeId: null == typeId
          ? _self.typeId
          : typeId // ignore: cast_nullable_to_non_nullable
              as int,
      typeName: freezed == typeName
          ? _self.typeName
          : typeName // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      capacity: null == capacity
          ? _self.capacity
          : capacity // ignore: cast_nullable_to_non_nullable
              as int,
      fillPercentage: null == fillPercentage
          ? _self.fillPercentage
          : fillPercentage // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
