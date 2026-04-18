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
  int get planetId;
  String get planetName;
  String get planetType;
  int get ownerId;
  DateTime get lastUpdate;
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
            (identical(other.planetId, planetId) ||
                other.planetId == planetId) &&
            (identical(other.planetName, planetName) ||
                other.planetName == planetName) &&
            (identical(other.planetType, planetType) ||
                other.planetType == planetType) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.lastUpdate, lastUpdate) ||
                other.lastUpdate == lastUpdate) &&
            (identical(other.upgradeLevel, upgradeLevel) ||
                other.upgradeLevel == upgradeLevel) &&
            (identical(other.numPins, numPins) || other.numPins == numPins) &&
            const DeepCollectionEquality().equals(other.pins, pins));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      planetId,
      planetName,
      planetType,
      ownerId,
      lastUpdate,
      upgradeLevel,
      numPins,
      const DeepCollectionEquality().hash(pins));

  @override
  String toString() {
    return 'Colony(planetId: $planetId, planetName: $planetName, planetType: $planetType, ownerId: $ownerId, lastUpdate: $lastUpdate, upgradeLevel: $upgradeLevel, numPins: $numPins, pins: $pins)';
  }
}

/// @nodoc
abstract mixin class $ColonyCopyWith<$Res> {
  factory $ColonyCopyWith(Colony value, $Res Function(Colony) _then) =
      _$ColonyCopyWithImpl;
  @useResult
  $Res call(
      {int planetId,
      String planetName,
      String planetType,
      int ownerId,
      DateTime lastUpdate,
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
    Object? planetId = null,
    Object? planetName = null,
    Object? planetType = null,
    Object? ownerId = null,
    Object? lastUpdate = null,
    Object? upgradeLevel = null,
    Object? numPins = null,
    Object? pins = null,
  }) {
    return _then(_self.copyWith(
      planetId: null == planetId
          ? _self.planetId
          : planetId // ignore: cast_nullable_to_non_nullable
              as int,
      planetName: null == planetName
          ? _self.planetName
          : planetName // ignore: cast_nullable_to_non_nullable
              as String,
      planetType: null == planetType
          ? _self.planetType
          : planetType // ignore: cast_nullable_to_non_nullable
              as String,
      ownerId: null == ownerId
          ? _self.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdate: null == lastUpdate
          ? _self.lastUpdate
          : lastUpdate // ignore: cast_nullable_to_non_nullable
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
            int planetId,
            String planetName,
            String planetType,
            int ownerId,
            DateTime lastUpdate,
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
            _that.planetId,
            _that.planetName,
            _that.planetType,
            _that.ownerId,
            _that.lastUpdate,
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
            int planetId,
            String planetName,
            String planetType,
            int ownerId,
            DateTime lastUpdate,
            int upgradeLevel,
            int numPins,
            List<Pin> pins)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Colony():
        return $default(
            _that.planetId,
            _that.planetName,
            _that.planetType,
            _that.ownerId,
            _that.lastUpdate,
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
            int planetId,
            String planetName,
            String planetType,
            int ownerId,
            DateTime lastUpdate,
            int upgradeLevel,
            int numPins,
            List<Pin> pins)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Colony() when $default != null:
        return $default(
            _that.planetId,
            _that.planetName,
            _that.planetType,
            _that.ownerId,
            _that.lastUpdate,
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
class _Colony implements Colony {
  const _Colony(
      {required this.planetId,
      required this.planetName,
      required this.planetType,
      required this.ownerId,
      required this.lastUpdate,
      required this.upgradeLevel,
      required this.numPins,
      final List<Pin> pins = const []})
      : _pins = pins;
  factory _Colony.fromJson(Map<String, dynamic> json) => _$ColonyFromJson(json);

  @override
  final int planetId;
  @override
  final String planetName;
  @override
  final String planetType;
  @override
  final int ownerId;
  @override
  final DateTime lastUpdate;
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
            (identical(other.planetId, planetId) ||
                other.planetId == planetId) &&
            (identical(other.planetName, planetName) ||
                other.planetName == planetName) &&
            (identical(other.planetType, planetType) ||
                other.planetType == planetType) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId) &&
            (identical(other.lastUpdate, lastUpdate) ||
                other.lastUpdate == lastUpdate) &&
            (identical(other.upgradeLevel, upgradeLevel) ||
                other.upgradeLevel == upgradeLevel) &&
            (identical(other.numPins, numPins) || other.numPins == numPins) &&
            const DeepCollectionEquality().equals(other._pins, _pins));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      planetId,
      planetName,
      planetType,
      ownerId,
      lastUpdate,
      upgradeLevel,
      numPins,
      const DeepCollectionEquality().hash(_pins));

  @override
  String toString() {
    return 'Colony(planetId: $planetId, planetName: $planetName, planetType: $planetType, ownerId: $ownerId, lastUpdate: $lastUpdate, upgradeLevel: $upgradeLevel, numPins: $numPins, pins: $pins)';
  }
}

/// @nodoc
abstract mixin class _$ColonyCopyWith<$Res> implements $ColonyCopyWith<$Res> {
  factory _$ColonyCopyWith(_Colony value, $Res Function(_Colony) _then) =
      __$ColonyCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int planetId,
      String planetName,
      String planetType,
      int ownerId,
      DateTime lastUpdate,
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
    Object? planetId = null,
    Object? planetName = null,
    Object? planetType = null,
    Object? ownerId = null,
    Object? lastUpdate = null,
    Object? upgradeLevel = null,
    Object? numPins = null,
    Object? pins = null,
  }) {
    return _then(_Colony(
      planetId: null == planetId
          ? _self.planetId
          : planetId // ignore: cast_nullable_to_non_nullable
              as int,
      planetName: null == planetName
          ? _self.planetName
          : planetName // ignore: cast_nullable_to_non_nullable
              as String,
      planetType: null == planetType
          ? _self.planetType
          : planetType // ignore: cast_nullable_to_non_nullable
              as String,
      ownerId: null == ownerId
          ? _self.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdate: null == lastUpdate
          ? _self.lastUpdate
          : lastUpdate // ignore: cast_nullable_to_non_nullable
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

/// @nodoc
mixin _$Pin {
  int get pinId;
  int get typeId;
  String? get typeName;
  double get latitude;
  double get longitude;
  DateTime get installDate;
  DateTime? get lastCycleStart;
  int? get lastCycleDuration;
  Extractor? get extractorDetails;

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
                other.longitude == longitude) &&
            (identical(other.installDate, installDate) ||
                other.installDate == installDate) &&
            (identical(other.lastCycleStart, lastCycleStart) ||
                other.lastCycleStart == lastCycleStart) &&
            (identical(other.lastCycleDuration, lastCycleDuration) ||
                other.lastCycleDuration == lastCycleDuration) &&
            (identical(other.extractorDetails, extractorDetails) ||
                other.extractorDetails == extractorDetails));
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
      installDate,
      lastCycleStart,
      lastCycleDuration,
      extractorDetails);

  @override
  String toString() {
    return 'Pin(pinId: $pinId, typeId: $typeId, typeName: $typeName, latitude: $latitude, longitude: $longitude, installDate: $installDate, lastCycleStart: $lastCycleStart, lastCycleDuration: $lastCycleDuration, extractorDetails: $extractorDetails)';
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
      double longitude,
      DateTime installDate,
      DateTime? lastCycleStart,
      int? lastCycleDuration,
      Extractor? extractorDetails});

  $ExtractorCopyWith<$Res>? get extractorDetails;
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
    Object? installDate = null,
    Object? lastCycleStart = freezed,
    Object? lastCycleDuration = freezed,
    Object? extractorDetails = freezed,
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
      installDate: null == installDate
          ? _self.installDate
          : installDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastCycleStart: freezed == lastCycleStart
          ? _self.lastCycleStart
          : lastCycleStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastCycleDuration: freezed == lastCycleDuration
          ? _self.lastCycleDuration
          : lastCycleDuration // ignore: cast_nullable_to_non_nullable
              as int?,
      extractorDetails: freezed == extractorDetails
          ? _self.extractorDetails
          : extractorDetails // ignore: cast_nullable_to_non_nullable
              as Extractor?,
    ));
  }

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExtractorCopyWith<$Res>? get extractorDetails {
    if (_self.extractorDetails == null) {
      return null;
    }

    return $ExtractorCopyWith<$Res>(_self.extractorDetails!, (value) {
      return _then(_self.copyWith(extractorDetails: value));
    });
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Pin value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Pin() when $default != null:
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
    TResult Function(_Pin value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Pin():
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
    TResult? Function(_Pin value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Pin() when $default != null:
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
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            DateTime installDate,
            DateTime? lastCycleStart,
            int? lastCycleDuration,
            Extractor? extractorDetails)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Pin() when $default != null:
        return $default(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.installDate,
            _that.lastCycleStart,
            _that.lastCycleDuration,
            _that.extractorDetails);
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
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            DateTime installDate,
            DateTime? lastCycleStart,
            int? lastCycleDuration,
            Extractor? extractorDetails)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Pin():
        return $default(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.installDate,
            _that.lastCycleStart,
            _that.lastCycleDuration,
            _that.extractorDetails);
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
            int pinId,
            int typeId,
            String? typeName,
            double latitude,
            double longitude,
            DateTime installDate,
            DateTime? lastCycleStart,
            int? lastCycleDuration,
            Extractor? extractorDetails)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Pin() when $default != null:
        return $default(
            _that.pinId,
            _that.typeId,
            _that.typeName,
            _that.latitude,
            _that.longitude,
            _that.installDate,
            _that.lastCycleStart,
            _that.lastCycleDuration,
            _that.extractorDetails);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Pin implements Pin {
  const _Pin(
      {required this.pinId,
      required this.typeId,
      this.typeName,
      required this.latitude,
      required this.longitude,
      required this.installDate,
      this.lastCycleStart,
      this.lastCycleDuration,
      this.extractorDetails});
  factory _Pin.fromJson(Map<String, dynamic> json) => _$PinFromJson(json);

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
  @override
  final DateTime installDate;
  @override
  final DateTime? lastCycleStart;
  @override
  final int? lastCycleDuration;
  @override
  final Extractor? extractorDetails;

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PinCopyWith<_Pin> get copyWith =>
      __$PinCopyWithImpl<_Pin>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PinToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Pin &&
            (identical(other.pinId, pinId) || other.pinId == pinId) &&
            (identical(other.typeId, typeId) || other.typeId == typeId) &&
            (identical(other.typeName, typeName) ||
                other.typeName == typeName) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.installDate, installDate) ||
                other.installDate == installDate) &&
            (identical(other.lastCycleStart, lastCycleStart) ||
                other.lastCycleStart == lastCycleStart) &&
            (identical(other.lastCycleDuration, lastCycleDuration) ||
                other.lastCycleDuration == lastCycleDuration) &&
            (identical(other.extractorDetails, extractorDetails) ||
                other.extractorDetails == extractorDetails));
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
      installDate,
      lastCycleStart,
      lastCycleDuration,
      extractorDetails);

  @override
  String toString() {
    return 'Pin(pinId: $pinId, typeId: $typeId, typeName: $typeName, latitude: $latitude, longitude: $longitude, installDate: $installDate, lastCycleStart: $lastCycleStart, lastCycleDuration: $lastCycleDuration, extractorDetails: $extractorDetails)';
  }
}

/// @nodoc
abstract mixin class _$PinCopyWith<$Res> implements $PinCopyWith<$Res> {
  factory _$PinCopyWith(_Pin value, $Res Function(_Pin) _then) =
      __$PinCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int pinId,
      int typeId,
      String? typeName,
      double latitude,
      double longitude,
      DateTime installDate,
      DateTime? lastCycleStart,
      int? lastCycleDuration,
      Extractor? extractorDetails});

  @override
  $ExtractorCopyWith<$Res>? get extractorDetails;
}

/// @nodoc
class __$PinCopyWithImpl<$Res> implements _$PinCopyWith<$Res> {
  __$PinCopyWithImpl(this._self, this._then);

  final _Pin _self;
  final $Res Function(_Pin) _then;

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
    Object? installDate = null,
    Object? lastCycleStart = freezed,
    Object? lastCycleDuration = freezed,
    Object? extractorDetails = freezed,
  }) {
    return _then(_Pin(
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
      installDate: null == installDate
          ? _self.installDate
          : installDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastCycleStart: freezed == lastCycleStart
          ? _self.lastCycleStart
          : lastCycleStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastCycleDuration: freezed == lastCycleDuration
          ? _self.lastCycleDuration
          : lastCycleDuration // ignore: cast_nullable_to_non_nullable
              as int?,
      extractorDetails: freezed == extractorDetails
          ? _self.extractorDetails
          : extractorDetails // ignore: cast_nullable_to_non_nullable
              as Extractor?,
    ));
  }

  /// Create a copy of Pin
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ExtractorCopyWith<$Res>? get extractorDetails {
    if (_self.extractorDetails == null) {
      return null;
    }

    return $ExtractorCopyWith<$Res>(_self.extractorDetails!, (value) {
      return _then(_self.copyWith(extractorDetails: value));
    });
  }
}

/// @nodoc
mixin _$Extractor {
  int? get productId;
  String? get productName;
  int? get quantityPerCycle;
  int? get cycleTime;
  int? get headCount;

  /// Create a copy of Extractor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ExtractorCopyWith<Extractor> get copyWith =>
      _$ExtractorCopyWithImpl<Extractor>(this as Extractor, _$identity);

  /// Serializes this Extractor to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Extractor &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.quantityPerCycle, quantityPerCycle) ||
                other.quantityPerCycle == quantityPerCycle) &&
            (identical(other.cycleTime, cycleTime) ||
                other.cycleTime == cycleTime) &&
            (identical(other.headCount, headCount) ||
                other.headCount == headCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, productId, productName,
      quantityPerCycle, cycleTime, headCount);

  @override
  String toString() {
    return 'Extractor(productId: $productId, productName: $productName, quantityPerCycle: $quantityPerCycle, cycleTime: $cycleTime, headCount: $headCount)';
  }
}

/// @nodoc
abstract mixin class $ExtractorCopyWith<$Res> {
  factory $ExtractorCopyWith(Extractor value, $Res Function(Extractor) _then) =
      _$ExtractorCopyWithImpl;
  @useResult
  $Res call(
      {int? productId,
      String? productName,
      int? quantityPerCycle,
      int? cycleTime,
      int? headCount});
}

/// @nodoc
class _$ExtractorCopyWithImpl<$Res> implements $ExtractorCopyWith<$Res> {
  _$ExtractorCopyWithImpl(this._self, this._then);

  final Extractor _self;
  final $Res Function(Extractor) _then;

  /// Create a copy of Extractor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = freezed,
    Object? productName = freezed,
    Object? quantityPerCycle = freezed,
    Object? cycleTime = freezed,
    Object? headCount = freezed,
  }) {
    return _then(_self.copyWith(
      productId: freezed == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as int?,
      productName: freezed == productName
          ? _self.productName
          : productName // ignore: cast_nullable_to_non_nullable
              as String?,
      quantityPerCycle: freezed == quantityPerCycle
          ? _self.quantityPerCycle
          : quantityPerCycle // ignore: cast_nullable_to_non_nullable
              as int?,
      cycleTime: freezed == cycleTime
          ? _self.cycleTime
          : cycleTime // ignore: cast_nullable_to_non_nullable
              as int?,
      headCount: freezed == headCount
          ? _self.headCount
          : headCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [Extractor].
extension ExtractorPatterns on Extractor {
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
    TResult Function(_Extractor value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Extractor() when $default != null:
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
    TResult Function(_Extractor value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Extractor():
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
    TResult? Function(_Extractor value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Extractor() when $default != null:
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
    TResult Function(int? productId, String? productName, int? quantityPerCycle,
            int? cycleTime, int? headCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Extractor() when $default != null:
        return $default(_that.productId, _that.productName,
            _that.quantityPerCycle, _that.cycleTime, _that.headCount);
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
    TResult Function(int? productId, String? productName, int? quantityPerCycle,
            int? cycleTime, int? headCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Extractor():
        return $default(_that.productId, _that.productName,
            _that.quantityPerCycle, _that.cycleTime, _that.headCount);
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
    TResult? Function(int? productId, String? productName,
            int? quantityPerCycle, int? cycleTime, int? headCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Extractor() when $default != null:
        return $default(_that.productId, _that.productName,
            _that.quantityPerCycle, _that.cycleTime, _that.headCount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Extractor implements Extractor {
  const _Extractor(
      {this.productId,
      this.productName,
      this.quantityPerCycle,
      this.cycleTime,
      this.headCount});
  factory _Extractor.fromJson(Map<String, dynamic> json) =>
      _$ExtractorFromJson(json);

  @override
  final int? productId;
  @override
  final String? productName;
  @override
  final int? quantityPerCycle;
  @override
  final int? cycleTime;
  @override
  final int? headCount;

  /// Create a copy of Extractor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ExtractorCopyWith<_Extractor> get copyWith =>
      __$ExtractorCopyWithImpl<_Extractor>(this, _$identity);

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
            other is _Extractor &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.quantityPerCycle, quantityPerCycle) ||
                other.quantityPerCycle == quantityPerCycle) &&
            (identical(other.cycleTime, cycleTime) ||
                other.cycleTime == cycleTime) &&
            (identical(other.headCount, headCount) ||
                other.headCount == headCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, productId, productName,
      quantityPerCycle, cycleTime, headCount);

  @override
  String toString() {
    return 'Extractor(productId: $productId, productName: $productName, quantityPerCycle: $quantityPerCycle, cycleTime: $cycleTime, headCount: $headCount)';
  }
}

/// @nodoc
abstract mixin class _$ExtractorCopyWith<$Res>
    implements $ExtractorCopyWith<$Res> {
  factory _$ExtractorCopyWith(
          _Extractor value, $Res Function(_Extractor) _then) =
      __$ExtractorCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int? productId,
      String? productName,
      int? quantityPerCycle,
      int? cycleTime,
      int? headCount});
}

/// @nodoc
class __$ExtractorCopyWithImpl<$Res> implements _$ExtractorCopyWith<$Res> {
  __$ExtractorCopyWithImpl(this._self, this._then);

  final _Extractor _self;
  final $Res Function(_Extractor) _then;

  /// Create a copy of Extractor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? productId = freezed,
    Object? productName = freezed,
    Object? quantityPerCycle = freezed,
    Object? cycleTime = freezed,
    Object? headCount = freezed,
  }) {
    return _then(_Extractor(
      productId: freezed == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as int?,
      productName: freezed == productName
          ? _self.productName
          : productName // ignore: cast_nullable_to_non_nullable
              as String?,
      quantityPerCycle: freezed == quantityPerCycle
          ? _self.quantityPerCycle
          : quantityPerCycle // ignore: cast_nullable_to_non_nullable
              as int?,
      cycleTime: freezed == cycleTime
          ? _self.cycleTime
          : cycleTime // ignore: cast_nullable_to_non_nullable
              as int?,
      headCount: freezed == headCount
          ? _self.headCount
          : headCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

// dart format on
