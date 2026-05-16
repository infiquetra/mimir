// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Fitting {

 String get id; String get name; String? get description; int get shipTypeId; String get shipName; List<FittedModule> get highSlots; List<FittedModule> get medSlots; List<FittedModule> get lowSlots; List<FittedModule> get rigSlots; List<FittedModule> get subsystems; List<DroneGroup> get drones; List<CargoItem> get cargo;
/// Create a copy of Fitting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FittingCopyWith<Fitting> get copyWith => _$FittingCopyWithImpl<Fitting>(this as Fitting, _$identity);

  /// Serializes this Fitting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Fitting&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.shipTypeId, shipTypeId) || other.shipTypeId == shipTypeId)&&(identical(other.shipName, shipName) || other.shipName == shipName)&&const DeepCollectionEquality().equals(other.highSlots, highSlots)&&const DeepCollectionEquality().equals(other.medSlots, medSlots)&&const DeepCollectionEquality().equals(other.lowSlots, lowSlots)&&const DeepCollectionEquality().equals(other.rigSlots, rigSlots)&&const DeepCollectionEquality().equals(other.subsystems, subsystems)&&const DeepCollectionEquality().equals(other.drones, drones)&&const DeepCollectionEquality().equals(other.cargo, cargo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,shipTypeId,shipName,const DeepCollectionEquality().hash(highSlots),const DeepCollectionEquality().hash(medSlots),const DeepCollectionEquality().hash(lowSlots),const DeepCollectionEquality().hash(rigSlots),const DeepCollectionEquality().hash(subsystems),const DeepCollectionEquality().hash(drones),const DeepCollectionEquality().hash(cargo));

@override
String toString() {
  return 'Fitting(id: $id, name: $name, description: $description, shipTypeId: $shipTypeId, shipName: $shipName, highSlots: $highSlots, medSlots: $medSlots, lowSlots: $lowSlots, rigSlots: $rigSlots, subsystems: $subsystems, drones: $drones, cargo: $cargo)';
}


}

/// @nodoc
abstract mixin class $FittingCopyWith<$Res>  {
  factory $FittingCopyWith(Fitting value, $Res Function(Fitting) _then) = _$FittingCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, int shipTypeId, String shipName, List<FittedModule> highSlots, List<FittedModule> medSlots, List<FittedModule> lowSlots, List<FittedModule> rigSlots, List<FittedModule> subsystems, List<DroneGroup> drones, List<CargoItem> cargo
});




}
/// @nodoc
class _$FittingCopyWithImpl<$Res>
    implements $FittingCopyWith<$Res> {
  _$FittingCopyWithImpl(this._self, this._then);

  final Fitting _self;
  final $Res Function(Fitting) _then;

/// Create a copy of Fitting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? shipTypeId = null,Object? shipName = null,Object? highSlots = null,Object? medSlots = null,Object? lowSlots = null,Object? rigSlots = null,Object? subsystems = null,Object? drones = null,Object? cargo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,shipTypeId: null == shipTypeId ? _self.shipTypeId : shipTypeId // ignore: cast_nullable_to_non_nullable
as int,shipName: null == shipName ? _self.shipName : shipName // ignore: cast_nullable_to_non_nullable
as String,highSlots: null == highSlots ? _self.highSlots : highSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,medSlots: null == medSlots ? _self.medSlots : medSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,lowSlots: null == lowSlots ? _self.lowSlots : lowSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,rigSlots: null == rigSlots ? _self.rigSlots : rigSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,subsystems: null == subsystems ? _self.subsystems : subsystems // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,drones: null == drones ? _self.drones : drones // ignore: cast_nullable_to_non_nullable
as List<DroneGroup>,cargo: null == cargo ? _self.cargo : cargo // ignore: cast_nullable_to_non_nullable
as List<CargoItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [Fitting].
extension FittingPatterns on Fitting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Fitting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Fitting() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Fitting value)  $default,){
final _that = this;
switch (_that) {
case _Fitting():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Fitting value)?  $default,){
final _that = this;
switch (_that) {
case _Fitting() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  int shipTypeId,  String shipName,  List<FittedModule> highSlots,  List<FittedModule> medSlots,  List<FittedModule> lowSlots,  List<FittedModule> rigSlots,  List<FittedModule> subsystems,  List<DroneGroup> drones,  List<CargoItem> cargo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Fitting() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.shipTypeId,_that.shipName,_that.highSlots,_that.medSlots,_that.lowSlots,_that.rigSlots,_that.subsystems,_that.drones,_that.cargo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  int shipTypeId,  String shipName,  List<FittedModule> highSlots,  List<FittedModule> medSlots,  List<FittedModule> lowSlots,  List<FittedModule> rigSlots,  List<FittedModule> subsystems,  List<DroneGroup> drones,  List<CargoItem> cargo)  $default,) {final _that = this;
switch (_that) {
case _Fitting():
return $default(_that.id,_that.name,_that.description,_that.shipTypeId,_that.shipName,_that.highSlots,_that.medSlots,_that.lowSlots,_that.rigSlots,_that.subsystems,_that.drones,_that.cargo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  int shipTypeId,  String shipName,  List<FittedModule> highSlots,  List<FittedModule> medSlots,  List<FittedModule> lowSlots,  List<FittedModule> rigSlots,  List<FittedModule> subsystems,  List<DroneGroup> drones,  List<CargoItem> cargo)?  $default,) {final _that = this;
switch (_that) {
case _Fitting() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.shipTypeId,_that.shipName,_that.highSlots,_that.medSlots,_that.lowSlots,_that.rigSlots,_that.subsystems,_that.drones,_that.cargo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Fitting extends Fitting {
  const _Fitting({required this.id, required this.name, this.description, required this.shipTypeId, required this.shipName, final  List<FittedModule> highSlots = const [], final  List<FittedModule> medSlots = const [], final  List<FittedModule> lowSlots = const [], final  List<FittedModule> rigSlots = const [], final  List<FittedModule> subsystems = const [], final  List<DroneGroup> drones = const [], final  List<CargoItem> cargo = const []}): _highSlots = highSlots,_medSlots = medSlots,_lowSlots = lowSlots,_rigSlots = rigSlots,_subsystems = subsystems,_drones = drones,_cargo = cargo,super._();
  factory _Fitting.fromJson(Map<String, dynamic> json) => _$FittingFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  int shipTypeId;
@override final  String shipName;
 final  List<FittedModule> _highSlots;
@override@JsonKey() List<FittedModule> get highSlots {
  if (_highSlots is EqualUnmodifiableListView) return _highSlots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_highSlots);
}

 final  List<FittedModule> _medSlots;
@override@JsonKey() List<FittedModule> get medSlots {
  if (_medSlots is EqualUnmodifiableListView) return _medSlots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_medSlots);
}

 final  List<FittedModule> _lowSlots;
@override@JsonKey() List<FittedModule> get lowSlots {
  if (_lowSlots is EqualUnmodifiableListView) return _lowSlots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lowSlots);
}

 final  List<FittedModule> _rigSlots;
@override@JsonKey() List<FittedModule> get rigSlots {
  if (_rigSlots is EqualUnmodifiableListView) return _rigSlots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rigSlots);
}

 final  List<FittedModule> _subsystems;
@override@JsonKey() List<FittedModule> get subsystems {
  if (_subsystems is EqualUnmodifiableListView) return _subsystems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subsystems);
}

 final  List<DroneGroup> _drones;
@override@JsonKey() List<DroneGroup> get drones {
  if (_drones is EqualUnmodifiableListView) return _drones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_drones);
}

 final  List<CargoItem> _cargo;
@override@JsonKey() List<CargoItem> get cargo {
  if (_cargo is EqualUnmodifiableListView) return _cargo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cargo);
}


/// Create a copy of Fitting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FittingCopyWith<_Fitting> get copyWith => __$FittingCopyWithImpl<_Fitting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FittingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Fitting&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.shipTypeId, shipTypeId) || other.shipTypeId == shipTypeId)&&(identical(other.shipName, shipName) || other.shipName == shipName)&&const DeepCollectionEquality().equals(other._highSlots, _highSlots)&&const DeepCollectionEquality().equals(other._medSlots, _medSlots)&&const DeepCollectionEquality().equals(other._lowSlots, _lowSlots)&&const DeepCollectionEquality().equals(other._rigSlots, _rigSlots)&&const DeepCollectionEquality().equals(other._subsystems, _subsystems)&&const DeepCollectionEquality().equals(other._drones, _drones)&&const DeepCollectionEquality().equals(other._cargo, _cargo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,shipTypeId,shipName,const DeepCollectionEquality().hash(_highSlots),const DeepCollectionEquality().hash(_medSlots),const DeepCollectionEquality().hash(_lowSlots),const DeepCollectionEquality().hash(_rigSlots),const DeepCollectionEquality().hash(_subsystems),const DeepCollectionEquality().hash(_drones),const DeepCollectionEquality().hash(_cargo));

@override
String toString() {
  return 'Fitting(id: $id, name: $name, description: $description, shipTypeId: $shipTypeId, shipName: $shipName, highSlots: $highSlots, medSlots: $medSlots, lowSlots: $lowSlots, rigSlots: $rigSlots, subsystems: $subsystems, drones: $drones, cargo: $cargo)';
}


}

/// @nodoc
abstract mixin class _$FittingCopyWith<$Res> implements $FittingCopyWith<$Res> {
  factory _$FittingCopyWith(_Fitting value, $Res Function(_Fitting) _then) = __$FittingCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, int shipTypeId, String shipName, List<FittedModule> highSlots, List<FittedModule> medSlots, List<FittedModule> lowSlots, List<FittedModule> rigSlots, List<FittedModule> subsystems, List<DroneGroup> drones, List<CargoItem> cargo
});




}
/// @nodoc
class __$FittingCopyWithImpl<$Res>
    implements _$FittingCopyWith<$Res> {
  __$FittingCopyWithImpl(this._self, this._then);

  final _Fitting _self;
  final $Res Function(_Fitting) _then;

/// Create a copy of Fitting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? shipTypeId = null,Object? shipName = null,Object? highSlots = null,Object? medSlots = null,Object? lowSlots = null,Object? rigSlots = null,Object? subsystems = null,Object? drones = null,Object? cargo = null,}) {
  return _then(_Fitting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,shipTypeId: null == shipTypeId ? _self.shipTypeId : shipTypeId // ignore: cast_nullable_to_non_nullable
as int,shipName: null == shipName ? _self.shipName : shipName // ignore: cast_nullable_to_non_nullable
as String,highSlots: null == highSlots ? _self._highSlots : highSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,medSlots: null == medSlots ? _self._medSlots : medSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,lowSlots: null == lowSlots ? _self._lowSlots : lowSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,rigSlots: null == rigSlots ? _self._rigSlots : rigSlots // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,subsystems: null == subsystems ? _self._subsystems : subsystems // ignore: cast_nullable_to_non_nullable
as List<FittedModule>,drones: null == drones ? _self._drones : drones // ignore: cast_nullable_to_non_nullable
as List<DroneGroup>,cargo: null == cargo ? _self._cargo : cargo // ignore: cast_nullable_to_non_nullable
as List<CargoItem>,
  ));
}


}


/// @nodoc
mixin _$FittedModule {

 int get typeId; String get typeName; SlotType get slotType; int get slotIndex; ModuleState get state; int? get chargeTypeId; String? get chargeName; Map<int, double> get attributes;
/// Create a copy of FittedModule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FittedModuleCopyWith<FittedModule> get copyWith => _$FittedModuleCopyWithImpl<FittedModule>(this as FittedModule, _$identity);

  /// Serializes this FittedModule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FittedModule&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName)&&(identical(other.slotType, slotType) || other.slotType == slotType)&&(identical(other.slotIndex, slotIndex) || other.slotIndex == slotIndex)&&(identical(other.state, state) || other.state == state)&&(identical(other.chargeTypeId, chargeTypeId) || other.chargeTypeId == chargeTypeId)&&(identical(other.chargeName, chargeName) || other.chargeName == chargeName)&&const DeepCollectionEquality().equals(other.attributes, attributes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,typeName,slotType,slotIndex,state,chargeTypeId,chargeName,const DeepCollectionEquality().hash(attributes));

@override
String toString() {
  return 'FittedModule(typeId: $typeId, typeName: $typeName, slotType: $slotType, slotIndex: $slotIndex, state: $state, chargeTypeId: $chargeTypeId, chargeName: $chargeName, attributes: $attributes)';
}


}

/// @nodoc
abstract mixin class $FittedModuleCopyWith<$Res>  {
  factory $FittedModuleCopyWith(FittedModule value, $Res Function(FittedModule) _then) = _$FittedModuleCopyWithImpl;
@useResult
$Res call({
 int typeId, String typeName, SlotType slotType, int slotIndex, ModuleState state, int? chargeTypeId, String? chargeName, Map<int, double> attributes
});




}
/// @nodoc
class _$FittedModuleCopyWithImpl<$Res>
    implements $FittedModuleCopyWith<$Res> {
  _$FittedModuleCopyWithImpl(this._self, this._then);

  final FittedModule _self;
  final $Res Function(FittedModule) _then;

/// Create a copy of FittedModule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? typeId = null,Object? typeName = null,Object? slotType = null,Object? slotIndex = null,Object? state = null,Object? chargeTypeId = freezed,Object? chargeName = freezed,Object? attributes = null,}) {
  return _then(_self.copyWith(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,typeName: null == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String,slotType: null == slotType ? _self.slotType : slotType // ignore: cast_nullable_to_non_nullable
as SlotType,slotIndex: null == slotIndex ? _self.slotIndex : slotIndex // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ModuleState,chargeTypeId: freezed == chargeTypeId ? _self.chargeTypeId : chargeTypeId // ignore: cast_nullable_to_non_nullable
as int?,chargeName: freezed == chargeName ? _self.chargeName : chargeName // ignore: cast_nullable_to_non_nullable
as String?,attributes: null == attributes ? _self.attributes : attributes // ignore: cast_nullable_to_non_nullable
as Map<int, double>,
  ));
}

}


/// Adds pattern-matching-related methods to [FittedModule].
extension FittedModulePatterns on FittedModule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FittedModule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FittedModule() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FittedModule value)  $default,){
final _that = this;
switch (_that) {
case _FittedModule():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FittedModule value)?  $default,){
final _that = this;
switch (_that) {
case _FittedModule() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int typeId,  String typeName,  SlotType slotType,  int slotIndex,  ModuleState state,  int? chargeTypeId,  String? chargeName,  Map<int, double> attributes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FittedModule() when $default != null:
return $default(_that.typeId,_that.typeName,_that.slotType,_that.slotIndex,_that.state,_that.chargeTypeId,_that.chargeName,_that.attributes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int typeId,  String typeName,  SlotType slotType,  int slotIndex,  ModuleState state,  int? chargeTypeId,  String? chargeName,  Map<int, double> attributes)  $default,) {final _that = this;
switch (_that) {
case _FittedModule():
return $default(_that.typeId,_that.typeName,_that.slotType,_that.slotIndex,_that.state,_that.chargeTypeId,_that.chargeName,_that.attributes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int typeId,  String typeName,  SlotType slotType,  int slotIndex,  ModuleState state,  int? chargeTypeId,  String? chargeName,  Map<int, double> attributes)?  $default,) {final _that = this;
switch (_that) {
case _FittedModule() when $default != null:
return $default(_that.typeId,_that.typeName,_that.slotType,_that.slotIndex,_that.state,_that.chargeTypeId,_that.chargeName,_that.attributes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FittedModule implements FittedModule {
  const _FittedModule({required this.typeId, required this.typeName, required this.slotType, required this.slotIndex, this.state = ModuleState.active, this.chargeTypeId, this.chargeName, final  Map<int, double> attributes = const {}}): _attributes = attributes;
  factory _FittedModule.fromJson(Map<String, dynamic> json) => _$FittedModuleFromJson(json);

@override final  int typeId;
@override final  String typeName;
@override final  SlotType slotType;
@override final  int slotIndex;
@override@JsonKey() final  ModuleState state;
@override final  int? chargeTypeId;
@override final  String? chargeName;
 final  Map<int, double> _attributes;
@override@JsonKey() Map<int, double> get attributes {
  if (_attributes is EqualUnmodifiableMapView) return _attributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_attributes);
}


/// Create a copy of FittedModule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FittedModuleCopyWith<_FittedModule> get copyWith => __$FittedModuleCopyWithImpl<_FittedModule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FittedModuleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FittedModule&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName)&&(identical(other.slotType, slotType) || other.slotType == slotType)&&(identical(other.slotIndex, slotIndex) || other.slotIndex == slotIndex)&&(identical(other.state, state) || other.state == state)&&(identical(other.chargeTypeId, chargeTypeId) || other.chargeTypeId == chargeTypeId)&&(identical(other.chargeName, chargeName) || other.chargeName == chargeName)&&const DeepCollectionEquality().equals(other._attributes, _attributes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,typeName,slotType,slotIndex,state,chargeTypeId,chargeName,const DeepCollectionEquality().hash(_attributes));

@override
String toString() {
  return 'FittedModule(typeId: $typeId, typeName: $typeName, slotType: $slotType, slotIndex: $slotIndex, state: $state, chargeTypeId: $chargeTypeId, chargeName: $chargeName, attributes: $attributes)';
}


}

/// @nodoc
abstract mixin class _$FittedModuleCopyWith<$Res> implements $FittedModuleCopyWith<$Res> {
  factory _$FittedModuleCopyWith(_FittedModule value, $Res Function(_FittedModule) _then) = __$FittedModuleCopyWithImpl;
@override @useResult
$Res call({
 int typeId, String typeName, SlotType slotType, int slotIndex, ModuleState state, int? chargeTypeId, String? chargeName, Map<int, double> attributes
});




}
/// @nodoc
class __$FittedModuleCopyWithImpl<$Res>
    implements _$FittedModuleCopyWith<$Res> {
  __$FittedModuleCopyWithImpl(this._self, this._then);

  final _FittedModule _self;
  final $Res Function(_FittedModule) _then;

/// Create a copy of FittedModule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? typeId = null,Object? typeName = null,Object? slotType = null,Object? slotIndex = null,Object? state = null,Object? chargeTypeId = freezed,Object? chargeName = freezed,Object? attributes = null,}) {
  return _then(_FittedModule(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,typeName: null == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String,slotType: null == slotType ? _self.slotType : slotType // ignore: cast_nullable_to_non_nullable
as SlotType,slotIndex: null == slotIndex ? _self.slotIndex : slotIndex // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as ModuleState,chargeTypeId: freezed == chargeTypeId ? _self.chargeTypeId : chargeTypeId // ignore: cast_nullable_to_non_nullable
as int?,chargeName: freezed == chargeName ? _self.chargeName : chargeName // ignore: cast_nullable_to_non_nullable
as String?,attributes: null == attributes ? _self._attributes : attributes // ignore: cast_nullable_to_non_nullable
as Map<int, double>,
  ));
}


}


/// @nodoc
mixin _$DroneGroup {

 int get typeId; String get typeName; int get quantity; int get inBay; int get inSpace;
/// Create a copy of DroneGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DroneGroupCopyWith<DroneGroup> get copyWith => _$DroneGroupCopyWithImpl<DroneGroup>(this as DroneGroup, _$identity);

  /// Serializes this DroneGroup to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DroneGroup&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.inBay, inBay) || other.inBay == inBay)&&(identical(other.inSpace, inSpace) || other.inSpace == inSpace));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,typeName,quantity,inBay,inSpace);

@override
String toString() {
  return 'DroneGroup(typeId: $typeId, typeName: $typeName, quantity: $quantity, inBay: $inBay, inSpace: $inSpace)';
}


}

/// @nodoc
abstract mixin class $DroneGroupCopyWith<$Res>  {
  factory $DroneGroupCopyWith(DroneGroup value, $Res Function(DroneGroup) _then) = _$DroneGroupCopyWithImpl;
@useResult
$Res call({
 int typeId, String typeName, int quantity, int inBay, int inSpace
});




}
/// @nodoc
class _$DroneGroupCopyWithImpl<$Res>
    implements $DroneGroupCopyWith<$Res> {
  _$DroneGroupCopyWithImpl(this._self, this._then);

  final DroneGroup _self;
  final $Res Function(DroneGroup) _then;

/// Create a copy of DroneGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? typeId = null,Object? typeName = null,Object? quantity = null,Object? inBay = null,Object? inSpace = null,}) {
  return _then(_self.copyWith(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,typeName: null == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,inBay: null == inBay ? _self.inBay : inBay // ignore: cast_nullable_to_non_nullable
as int,inSpace: null == inSpace ? _self.inSpace : inSpace // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DroneGroup].
extension DroneGroupPatterns on DroneGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DroneGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DroneGroup() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DroneGroup value)  $default,){
final _that = this;
switch (_that) {
case _DroneGroup():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DroneGroup value)?  $default,){
final _that = this;
switch (_that) {
case _DroneGroup() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int typeId,  String typeName,  int quantity,  int inBay,  int inSpace)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DroneGroup() when $default != null:
return $default(_that.typeId,_that.typeName,_that.quantity,_that.inBay,_that.inSpace);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int typeId,  String typeName,  int quantity,  int inBay,  int inSpace)  $default,) {final _that = this;
switch (_that) {
case _DroneGroup():
return $default(_that.typeId,_that.typeName,_that.quantity,_that.inBay,_that.inSpace);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int typeId,  String typeName,  int quantity,  int inBay,  int inSpace)?  $default,) {final _that = this;
switch (_that) {
case _DroneGroup() when $default != null:
return $default(_that.typeId,_that.typeName,_that.quantity,_that.inBay,_that.inSpace);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DroneGroup implements DroneGroup {
  const _DroneGroup({required this.typeId, required this.typeName, required this.quantity, this.inBay = 0, this.inSpace = 0});
  factory _DroneGroup.fromJson(Map<String, dynamic> json) => _$DroneGroupFromJson(json);

@override final  int typeId;
@override final  String typeName;
@override final  int quantity;
@override@JsonKey() final  int inBay;
@override@JsonKey() final  int inSpace;

/// Create a copy of DroneGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DroneGroupCopyWith<_DroneGroup> get copyWith => __$DroneGroupCopyWithImpl<_DroneGroup>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DroneGroupToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DroneGroup&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.inBay, inBay) || other.inBay == inBay)&&(identical(other.inSpace, inSpace) || other.inSpace == inSpace));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,typeName,quantity,inBay,inSpace);

@override
String toString() {
  return 'DroneGroup(typeId: $typeId, typeName: $typeName, quantity: $quantity, inBay: $inBay, inSpace: $inSpace)';
}


}

/// @nodoc
abstract mixin class _$DroneGroupCopyWith<$Res> implements $DroneGroupCopyWith<$Res> {
  factory _$DroneGroupCopyWith(_DroneGroup value, $Res Function(_DroneGroup) _then) = __$DroneGroupCopyWithImpl;
@override @useResult
$Res call({
 int typeId, String typeName, int quantity, int inBay, int inSpace
});




}
/// @nodoc
class __$DroneGroupCopyWithImpl<$Res>
    implements _$DroneGroupCopyWith<$Res> {
  __$DroneGroupCopyWithImpl(this._self, this._then);

  final _DroneGroup _self;
  final $Res Function(_DroneGroup) _then;

/// Create a copy of DroneGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? typeId = null,Object? typeName = null,Object? quantity = null,Object? inBay = null,Object? inSpace = null,}) {
  return _then(_DroneGroup(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,typeName: null == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,inBay: null == inBay ? _self.inBay : inBay // ignore: cast_nullable_to_non_nullable
as int,inSpace: null == inSpace ? _self.inSpace : inSpace // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CargoItem {

 int get typeId; String get typeName; int get quantity;
/// Create a copy of CargoItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CargoItemCopyWith<CargoItem> get copyWith => _$CargoItemCopyWithImpl<CargoItem>(this as CargoItem, _$identity);

  /// Serializes this CargoItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CargoItem&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,typeName,quantity);

@override
String toString() {
  return 'CargoItem(typeId: $typeId, typeName: $typeName, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class $CargoItemCopyWith<$Res>  {
  factory $CargoItemCopyWith(CargoItem value, $Res Function(CargoItem) _then) = _$CargoItemCopyWithImpl;
@useResult
$Res call({
 int typeId, String typeName, int quantity
});




}
/// @nodoc
class _$CargoItemCopyWithImpl<$Res>
    implements $CargoItemCopyWith<$Res> {
  _$CargoItemCopyWithImpl(this._self, this._then);

  final CargoItem _self;
  final $Res Function(CargoItem) _then;

/// Create a copy of CargoItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? typeId = null,Object? typeName = null,Object? quantity = null,}) {
  return _then(_self.copyWith(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,typeName: null == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CargoItem].
extension CargoItemPatterns on CargoItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CargoItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CargoItem() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CargoItem value)  $default,){
final _that = this;
switch (_that) {
case _CargoItem():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CargoItem value)?  $default,){
final _that = this;
switch (_that) {
case _CargoItem() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int typeId,  String typeName,  int quantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CargoItem() when $default != null:
return $default(_that.typeId,_that.typeName,_that.quantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int typeId,  String typeName,  int quantity)  $default,) {final _that = this;
switch (_that) {
case _CargoItem():
return $default(_that.typeId,_that.typeName,_that.quantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int typeId,  String typeName,  int quantity)?  $default,) {final _that = this;
switch (_that) {
case _CargoItem() when $default != null:
return $default(_that.typeId,_that.typeName,_that.quantity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CargoItem implements CargoItem {
  const _CargoItem({required this.typeId, required this.typeName, required this.quantity});
  factory _CargoItem.fromJson(Map<String, dynamic> json) => _$CargoItemFromJson(json);

@override final  int typeId;
@override final  String typeName;
@override final  int quantity;

/// Create a copy of CargoItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CargoItemCopyWith<_CargoItem> get copyWith => __$CargoItemCopyWithImpl<_CargoItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CargoItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CargoItem&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.typeName, typeName) || other.typeName == typeName)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,typeName,quantity);

@override
String toString() {
  return 'CargoItem(typeId: $typeId, typeName: $typeName, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class _$CargoItemCopyWith<$Res> implements $CargoItemCopyWith<$Res> {
  factory _$CargoItemCopyWith(_CargoItem value, $Res Function(_CargoItem) _then) = __$CargoItemCopyWithImpl;
@override @useResult
$Res call({
 int typeId, String typeName, int quantity
});




}
/// @nodoc
class __$CargoItemCopyWithImpl<$Res>
    implements _$CargoItemCopyWith<$Res> {
  __$CargoItemCopyWithImpl(this._self, this._then);

  final _CargoItem _self;
  final $Res Function(_CargoItem) _then;

/// Create a copy of CargoItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? typeId = null,Object? typeName = null,Object? quantity = null,}) {
  return _then(_CargoItem(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,typeName: null == typeName ? _self.typeName : typeName // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FittingStats {

 double get cpuUsed; double get cpuMax; double get powerUsed; double get powerMax; int get calibrationUsed; int get calibrationMax; double get capacitorCapacity; double get capacitorRecharge; double get capacitorStable; bool get isCapStable; DefenseProfile get defenses; double get dpsTotal; double get dpsGuns; double get dpsDrones; double get dpsMissiles; double get volley; double get optimalRange; double get falloffRange; double get maxVelocity; double get inertiaModifier; double get alignTime; double get warpSpeed; double get massKg; double get targetRange; double get scanResolution; int get maxLockedTargets; double get signatureRadius; double get droneBandwidthUsed; double get droneBandwidthMax; double get droneBayUsed; double get droneBayMax; double get shipCost; double get moduleCost; double get totalCost;
/// Create a copy of FittingStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FittingStatsCopyWith<FittingStats> get copyWith => _$FittingStatsCopyWithImpl<FittingStats>(this as FittingStats, _$identity);

  /// Serializes this FittingStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FittingStats&&(identical(other.cpuUsed, cpuUsed) || other.cpuUsed == cpuUsed)&&(identical(other.cpuMax, cpuMax) || other.cpuMax == cpuMax)&&(identical(other.powerUsed, powerUsed) || other.powerUsed == powerUsed)&&(identical(other.powerMax, powerMax) || other.powerMax == powerMax)&&(identical(other.calibrationUsed, calibrationUsed) || other.calibrationUsed == calibrationUsed)&&(identical(other.calibrationMax, calibrationMax) || other.calibrationMax == calibrationMax)&&(identical(other.capacitorCapacity, capacitorCapacity) || other.capacitorCapacity == capacitorCapacity)&&(identical(other.capacitorRecharge, capacitorRecharge) || other.capacitorRecharge == capacitorRecharge)&&(identical(other.capacitorStable, capacitorStable) || other.capacitorStable == capacitorStable)&&(identical(other.isCapStable, isCapStable) || other.isCapStable == isCapStable)&&(identical(other.defenses, defenses) || other.defenses == defenses)&&(identical(other.dpsTotal, dpsTotal) || other.dpsTotal == dpsTotal)&&(identical(other.dpsGuns, dpsGuns) || other.dpsGuns == dpsGuns)&&(identical(other.dpsDrones, dpsDrones) || other.dpsDrones == dpsDrones)&&(identical(other.dpsMissiles, dpsMissiles) || other.dpsMissiles == dpsMissiles)&&(identical(other.volley, volley) || other.volley == volley)&&(identical(other.optimalRange, optimalRange) || other.optimalRange == optimalRange)&&(identical(other.falloffRange, falloffRange) || other.falloffRange == falloffRange)&&(identical(other.maxVelocity, maxVelocity) || other.maxVelocity == maxVelocity)&&(identical(other.inertiaModifier, inertiaModifier) || other.inertiaModifier == inertiaModifier)&&(identical(other.alignTime, alignTime) || other.alignTime == alignTime)&&(identical(other.warpSpeed, warpSpeed) || other.warpSpeed == warpSpeed)&&(identical(other.massKg, massKg) || other.massKg == massKg)&&(identical(other.targetRange, targetRange) || other.targetRange == targetRange)&&(identical(other.scanResolution, scanResolution) || other.scanResolution == scanResolution)&&(identical(other.maxLockedTargets, maxLockedTargets) || other.maxLockedTargets == maxLockedTargets)&&(identical(other.signatureRadius, signatureRadius) || other.signatureRadius == signatureRadius)&&(identical(other.droneBandwidthUsed, droneBandwidthUsed) || other.droneBandwidthUsed == droneBandwidthUsed)&&(identical(other.droneBandwidthMax, droneBandwidthMax) || other.droneBandwidthMax == droneBandwidthMax)&&(identical(other.droneBayUsed, droneBayUsed) || other.droneBayUsed == droneBayUsed)&&(identical(other.droneBayMax, droneBayMax) || other.droneBayMax == droneBayMax)&&(identical(other.shipCost, shipCost) || other.shipCost == shipCost)&&(identical(other.moduleCost, moduleCost) || other.moduleCost == moduleCost)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,cpuUsed,cpuMax,powerUsed,powerMax,calibrationUsed,calibrationMax,capacitorCapacity,capacitorRecharge,capacitorStable,isCapStable,defenses,dpsTotal,dpsGuns,dpsDrones,dpsMissiles,volley,optimalRange,falloffRange,maxVelocity,inertiaModifier,alignTime,warpSpeed,massKg,targetRange,scanResolution,maxLockedTargets,signatureRadius,droneBandwidthUsed,droneBandwidthMax,droneBayUsed,droneBayMax,shipCost,moduleCost,totalCost]);

@override
String toString() {
  return 'FittingStats(cpuUsed: $cpuUsed, cpuMax: $cpuMax, powerUsed: $powerUsed, powerMax: $powerMax, calibrationUsed: $calibrationUsed, calibrationMax: $calibrationMax, capacitorCapacity: $capacitorCapacity, capacitorRecharge: $capacitorRecharge, capacitorStable: $capacitorStable, isCapStable: $isCapStable, defenses: $defenses, dpsTotal: $dpsTotal, dpsGuns: $dpsGuns, dpsDrones: $dpsDrones, dpsMissiles: $dpsMissiles, volley: $volley, optimalRange: $optimalRange, falloffRange: $falloffRange, maxVelocity: $maxVelocity, inertiaModifier: $inertiaModifier, alignTime: $alignTime, warpSpeed: $warpSpeed, massKg: $massKg, targetRange: $targetRange, scanResolution: $scanResolution, maxLockedTargets: $maxLockedTargets, signatureRadius: $signatureRadius, droneBandwidthUsed: $droneBandwidthUsed, droneBandwidthMax: $droneBandwidthMax, droneBayUsed: $droneBayUsed, droneBayMax: $droneBayMax, shipCost: $shipCost, moduleCost: $moduleCost, totalCost: $totalCost)';
}


}

/// @nodoc
abstract mixin class $FittingStatsCopyWith<$Res>  {
  factory $FittingStatsCopyWith(FittingStats value, $Res Function(FittingStats) _then) = _$FittingStatsCopyWithImpl;
@useResult
$Res call({
 double cpuUsed, double cpuMax, double powerUsed, double powerMax, int calibrationUsed, int calibrationMax, double capacitorCapacity, double capacitorRecharge, double capacitorStable, bool isCapStable, DefenseProfile defenses, double dpsTotal, double dpsGuns, double dpsDrones, double dpsMissiles, double volley, double optimalRange, double falloffRange, double maxVelocity, double inertiaModifier, double alignTime, double warpSpeed, double massKg, double targetRange, double scanResolution, int maxLockedTargets, double signatureRadius, double droneBandwidthUsed, double droneBandwidthMax, double droneBayUsed, double droneBayMax, double shipCost, double moduleCost, double totalCost
});


$DefenseProfileCopyWith<$Res> get defenses;

}
/// @nodoc
class _$FittingStatsCopyWithImpl<$Res>
    implements $FittingStatsCopyWith<$Res> {
  _$FittingStatsCopyWithImpl(this._self, this._then);

  final FittingStats _self;
  final $Res Function(FittingStats) _then;

/// Create a copy of FittingStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cpuUsed = null,Object? cpuMax = null,Object? powerUsed = null,Object? powerMax = null,Object? calibrationUsed = null,Object? calibrationMax = null,Object? capacitorCapacity = null,Object? capacitorRecharge = null,Object? capacitorStable = null,Object? isCapStable = null,Object? defenses = null,Object? dpsTotal = null,Object? dpsGuns = null,Object? dpsDrones = null,Object? dpsMissiles = null,Object? volley = null,Object? optimalRange = null,Object? falloffRange = null,Object? maxVelocity = null,Object? inertiaModifier = null,Object? alignTime = null,Object? warpSpeed = null,Object? massKg = null,Object? targetRange = null,Object? scanResolution = null,Object? maxLockedTargets = null,Object? signatureRadius = null,Object? droneBandwidthUsed = null,Object? droneBandwidthMax = null,Object? droneBayUsed = null,Object? droneBayMax = null,Object? shipCost = null,Object? moduleCost = null,Object? totalCost = null,}) {
  return _then(_self.copyWith(
cpuUsed: null == cpuUsed ? _self.cpuUsed : cpuUsed // ignore: cast_nullable_to_non_nullable
as double,cpuMax: null == cpuMax ? _self.cpuMax : cpuMax // ignore: cast_nullable_to_non_nullable
as double,powerUsed: null == powerUsed ? _self.powerUsed : powerUsed // ignore: cast_nullable_to_non_nullable
as double,powerMax: null == powerMax ? _self.powerMax : powerMax // ignore: cast_nullable_to_non_nullable
as double,calibrationUsed: null == calibrationUsed ? _self.calibrationUsed : calibrationUsed // ignore: cast_nullable_to_non_nullable
as int,calibrationMax: null == calibrationMax ? _self.calibrationMax : calibrationMax // ignore: cast_nullable_to_non_nullable
as int,capacitorCapacity: null == capacitorCapacity ? _self.capacitorCapacity : capacitorCapacity // ignore: cast_nullable_to_non_nullable
as double,capacitorRecharge: null == capacitorRecharge ? _self.capacitorRecharge : capacitorRecharge // ignore: cast_nullable_to_non_nullable
as double,capacitorStable: null == capacitorStable ? _self.capacitorStable : capacitorStable // ignore: cast_nullable_to_non_nullable
as double,isCapStable: null == isCapStable ? _self.isCapStable : isCapStable // ignore: cast_nullable_to_non_nullable
as bool,defenses: null == defenses ? _self.defenses : defenses // ignore: cast_nullable_to_non_nullable
as DefenseProfile,dpsTotal: null == dpsTotal ? _self.dpsTotal : dpsTotal // ignore: cast_nullable_to_non_nullable
as double,dpsGuns: null == dpsGuns ? _self.dpsGuns : dpsGuns // ignore: cast_nullable_to_non_nullable
as double,dpsDrones: null == dpsDrones ? _self.dpsDrones : dpsDrones // ignore: cast_nullable_to_non_nullable
as double,dpsMissiles: null == dpsMissiles ? _self.dpsMissiles : dpsMissiles // ignore: cast_nullable_to_non_nullable
as double,volley: null == volley ? _self.volley : volley // ignore: cast_nullable_to_non_nullable
as double,optimalRange: null == optimalRange ? _self.optimalRange : optimalRange // ignore: cast_nullable_to_non_nullable
as double,falloffRange: null == falloffRange ? _self.falloffRange : falloffRange // ignore: cast_nullable_to_non_nullable
as double,maxVelocity: null == maxVelocity ? _self.maxVelocity : maxVelocity // ignore: cast_nullable_to_non_nullable
as double,inertiaModifier: null == inertiaModifier ? _self.inertiaModifier : inertiaModifier // ignore: cast_nullable_to_non_nullable
as double,alignTime: null == alignTime ? _self.alignTime : alignTime // ignore: cast_nullable_to_non_nullable
as double,warpSpeed: null == warpSpeed ? _self.warpSpeed : warpSpeed // ignore: cast_nullable_to_non_nullable
as double,massKg: null == massKg ? _self.massKg : massKg // ignore: cast_nullable_to_non_nullable
as double,targetRange: null == targetRange ? _self.targetRange : targetRange // ignore: cast_nullable_to_non_nullable
as double,scanResolution: null == scanResolution ? _self.scanResolution : scanResolution // ignore: cast_nullable_to_non_nullable
as double,maxLockedTargets: null == maxLockedTargets ? _self.maxLockedTargets : maxLockedTargets // ignore: cast_nullable_to_non_nullable
as int,signatureRadius: null == signatureRadius ? _self.signatureRadius : signatureRadius // ignore: cast_nullable_to_non_nullable
as double,droneBandwidthUsed: null == droneBandwidthUsed ? _self.droneBandwidthUsed : droneBandwidthUsed // ignore: cast_nullable_to_non_nullable
as double,droneBandwidthMax: null == droneBandwidthMax ? _self.droneBandwidthMax : droneBandwidthMax // ignore: cast_nullable_to_non_nullable
as double,droneBayUsed: null == droneBayUsed ? _self.droneBayUsed : droneBayUsed // ignore: cast_nullable_to_non_nullable
as double,droneBayMax: null == droneBayMax ? _self.droneBayMax : droneBayMax // ignore: cast_nullable_to_non_nullable
as double,shipCost: null == shipCost ? _self.shipCost : shipCost // ignore: cast_nullable_to_non_nullable
as double,moduleCost: null == moduleCost ? _self.moduleCost : moduleCost // ignore: cast_nullable_to_non_nullable
as double,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of FittingStats
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DefenseProfileCopyWith<$Res> get defenses {
  
  return $DefenseProfileCopyWith<$Res>(_self.defenses, (value) {
    return _then(_self.copyWith(defenses: value));
  });
}
}


/// Adds pattern-matching-related methods to [FittingStats].
extension FittingStatsPatterns on FittingStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FittingStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FittingStats() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FittingStats value)  $default,){
final _that = this;
switch (_that) {
case _FittingStats():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FittingStats value)?  $default,){
final _that = this;
switch (_that) {
case _FittingStats() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double cpuUsed,  double cpuMax,  double powerUsed,  double powerMax,  int calibrationUsed,  int calibrationMax,  double capacitorCapacity,  double capacitorRecharge,  double capacitorStable,  bool isCapStable,  DefenseProfile defenses,  double dpsTotal,  double dpsGuns,  double dpsDrones,  double dpsMissiles,  double volley,  double optimalRange,  double falloffRange,  double maxVelocity,  double inertiaModifier,  double alignTime,  double warpSpeed,  double massKg,  double targetRange,  double scanResolution,  int maxLockedTargets,  double signatureRadius,  double droneBandwidthUsed,  double droneBandwidthMax,  double droneBayUsed,  double droneBayMax,  double shipCost,  double moduleCost,  double totalCost)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FittingStats() when $default != null:
return $default(_that.cpuUsed,_that.cpuMax,_that.powerUsed,_that.powerMax,_that.calibrationUsed,_that.calibrationMax,_that.capacitorCapacity,_that.capacitorRecharge,_that.capacitorStable,_that.isCapStable,_that.defenses,_that.dpsTotal,_that.dpsGuns,_that.dpsDrones,_that.dpsMissiles,_that.volley,_that.optimalRange,_that.falloffRange,_that.maxVelocity,_that.inertiaModifier,_that.alignTime,_that.warpSpeed,_that.massKg,_that.targetRange,_that.scanResolution,_that.maxLockedTargets,_that.signatureRadius,_that.droneBandwidthUsed,_that.droneBandwidthMax,_that.droneBayUsed,_that.droneBayMax,_that.shipCost,_that.moduleCost,_that.totalCost);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double cpuUsed,  double cpuMax,  double powerUsed,  double powerMax,  int calibrationUsed,  int calibrationMax,  double capacitorCapacity,  double capacitorRecharge,  double capacitorStable,  bool isCapStable,  DefenseProfile defenses,  double dpsTotal,  double dpsGuns,  double dpsDrones,  double dpsMissiles,  double volley,  double optimalRange,  double falloffRange,  double maxVelocity,  double inertiaModifier,  double alignTime,  double warpSpeed,  double massKg,  double targetRange,  double scanResolution,  int maxLockedTargets,  double signatureRadius,  double droneBandwidthUsed,  double droneBandwidthMax,  double droneBayUsed,  double droneBayMax,  double shipCost,  double moduleCost,  double totalCost)  $default,) {final _that = this;
switch (_that) {
case _FittingStats():
return $default(_that.cpuUsed,_that.cpuMax,_that.powerUsed,_that.powerMax,_that.calibrationUsed,_that.calibrationMax,_that.capacitorCapacity,_that.capacitorRecharge,_that.capacitorStable,_that.isCapStable,_that.defenses,_that.dpsTotal,_that.dpsGuns,_that.dpsDrones,_that.dpsMissiles,_that.volley,_that.optimalRange,_that.falloffRange,_that.maxVelocity,_that.inertiaModifier,_that.alignTime,_that.warpSpeed,_that.massKg,_that.targetRange,_that.scanResolution,_that.maxLockedTargets,_that.signatureRadius,_that.droneBandwidthUsed,_that.droneBandwidthMax,_that.droneBayUsed,_that.droneBayMax,_that.shipCost,_that.moduleCost,_that.totalCost);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double cpuUsed,  double cpuMax,  double powerUsed,  double powerMax,  int calibrationUsed,  int calibrationMax,  double capacitorCapacity,  double capacitorRecharge,  double capacitorStable,  bool isCapStable,  DefenseProfile defenses,  double dpsTotal,  double dpsGuns,  double dpsDrones,  double dpsMissiles,  double volley,  double optimalRange,  double falloffRange,  double maxVelocity,  double inertiaModifier,  double alignTime,  double warpSpeed,  double massKg,  double targetRange,  double scanResolution,  int maxLockedTargets,  double signatureRadius,  double droneBandwidthUsed,  double droneBandwidthMax,  double droneBayUsed,  double droneBayMax,  double shipCost,  double moduleCost,  double totalCost)?  $default,) {final _that = this;
switch (_that) {
case _FittingStats() when $default != null:
return $default(_that.cpuUsed,_that.cpuMax,_that.powerUsed,_that.powerMax,_that.calibrationUsed,_that.calibrationMax,_that.capacitorCapacity,_that.capacitorRecharge,_that.capacitorStable,_that.isCapStable,_that.defenses,_that.dpsTotal,_that.dpsGuns,_that.dpsDrones,_that.dpsMissiles,_that.volley,_that.optimalRange,_that.falloffRange,_that.maxVelocity,_that.inertiaModifier,_that.alignTime,_that.warpSpeed,_that.massKg,_that.targetRange,_that.scanResolution,_that.maxLockedTargets,_that.signatureRadius,_that.droneBandwidthUsed,_that.droneBandwidthMax,_that.droneBayUsed,_that.droneBayMax,_that.shipCost,_that.moduleCost,_that.totalCost);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FittingStats implements FittingStats {
  const _FittingStats({this.cpuUsed = 0.0, this.cpuMax = 0.0, this.powerUsed = 0.0, this.powerMax = 0.0, this.calibrationUsed = 0, this.calibrationMax = 0, this.capacitorCapacity = 0.0, this.capacitorRecharge = 0.0, this.capacitorStable = 0.0, this.isCapStable = false, this.defenses = const DefenseProfile(), this.dpsTotal = 0.0, this.dpsGuns = 0.0, this.dpsDrones = 0.0, this.dpsMissiles = 0.0, this.volley = 0.0, this.optimalRange = 0.0, this.falloffRange = 0.0, this.maxVelocity = 0.0, this.inertiaModifier = 0.0, this.alignTime = 0.0, this.warpSpeed = 0.0, this.massKg = 0.0, this.targetRange = 0.0, this.scanResolution = 0.0, this.maxLockedTargets = 0, this.signatureRadius = 0.0, this.droneBandwidthUsed = 0.0, this.droneBandwidthMax = 0.0, this.droneBayUsed = 0.0, this.droneBayMax = 0.0, this.shipCost = 0.0, this.moduleCost = 0.0, this.totalCost = 0.0});
  factory _FittingStats.fromJson(Map<String, dynamic> json) => _$FittingStatsFromJson(json);

@override@JsonKey() final  double cpuUsed;
@override@JsonKey() final  double cpuMax;
@override@JsonKey() final  double powerUsed;
@override@JsonKey() final  double powerMax;
@override@JsonKey() final  int calibrationUsed;
@override@JsonKey() final  int calibrationMax;
@override@JsonKey() final  double capacitorCapacity;
@override@JsonKey() final  double capacitorRecharge;
@override@JsonKey() final  double capacitorStable;
@override@JsonKey() final  bool isCapStable;
@override@JsonKey() final  DefenseProfile defenses;
@override@JsonKey() final  double dpsTotal;
@override@JsonKey() final  double dpsGuns;
@override@JsonKey() final  double dpsDrones;
@override@JsonKey() final  double dpsMissiles;
@override@JsonKey() final  double volley;
@override@JsonKey() final  double optimalRange;
@override@JsonKey() final  double falloffRange;
@override@JsonKey() final  double maxVelocity;
@override@JsonKey() final  double inertiaModifier;
@override@JsonKey() final  double alignTime;
@override@JsonKey() final  double warpSpeed;
@override@JsonKey() final  double massKg;
@override@JsonKey() final  double targetRange;
@override@JsonKey() final  double scanResolution;
@override@JsonKey() final  int maxLockedTargets;
@override@JsonKey() final  double signatureRadius;
@override@JsonKey() final  double droneBandwidthUsed;
@override@JsonKey() final  double droneBandwidthMax;
@override@JsonKey() final  double droneBayUsed;
@override@JsonKey() final  double droneBayMax;
@override@JsonKey() final  double shipCost;
@override@JsonKey() final  double moduleCost;
@override@JsonKey() final  double totalCost;

/// Create a copy of FittingStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FittingStatsCopyWith<_FittingStats> get copyWith => __$FittingStatsCopyWithImpl<_FittingStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FittingStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FittingStats&&(identical(other.cpuUsed, cpuUsed) || other.cpuUsed == cpuUsed)&&(identical(other.cpuMax, cpuMax) || other.cpuMax == cpuMax)&&(identical(other.powerUsed, powerUsed) || other.powerUsed == powerUsed)&&(identical(other.powerMax, powerMax) || other.powerMax == powerMax)&&(identical(other.calibrationUsed, calibrationUsed) || other.calibrationUsed == calibrationUsed)&&(identical(other.calibrationMax, calibrationMax) || other.calibrationMax == calibrationMax)&&(identical(other.capacitorCapacity, capacitorCapacity) || other.capacitorCapacity == capacitorCapacity)&&(identical(other.capacitorRecharge, capacitorRecharge) || other.capacitorRecharge == capacitorRecharge)&&(identical(other.capacitorStable, capacitorStable) || other.capacitorStable == capacitorStable)&&(identical(other.isCapStable, isCapStable) || other.isCapStable == isCapStable)&&(identical(other.defenses, defenses) || other.defenses == defenses)&&(identical(other.dpsTotal, dpsTotal) || other.dpsTotal == dpsTotal)&&(identical(other.dpsGuns, dpsGuns) || other.dpsGuns == dpsGuns)&&(identical(other.dpsDrones, dpsDrones) || other.dpsDrones == dpsDrones)&&(identical(other.dpsMissiles, dpsMissiles) || other.dpsMissiles == dpsMissiles)&&(identical(other.volley, volley) || other.volley == volley)&&(identical(other.optimalRange, optimalRange) || other.optimalRange == optimalRange)&&(identical(other.falloffRange, falloffRange) || other.falloffRange == falloffRange)&&(identical(other.maxVelocity, maxVelocity) || other.maxVelocity == maxVelocity)&&(identical(other.inertiaModifier, inertiaModifier) || other.inertiaModifier == inertiaModifier)&&(identical(other.alignTime, alignTime) || other.alignTime == alignTime)&&(identical(other.warpSpeed, warpSpeed) || other.warpSpeed == warpSpeed)&&(identical(other.massKg, massKg) || other.massKg == massKg)&&(identical(other.targetRange, targetRange) || other.targetRange == targetRange)&&(identical(other.scanResolution, scanResolution) || other.scanResolution == scanResolution)&&(identical(other.maxLockedTargets, maxLockedTargets) || other.maxLockedTargets == maxLockedTargets)&&(identical(other.signatureRadius, signatureRadius) || other.signatureRadius == signatureRadius)&&(identical(other.droneBandwidthUsed, droneBandwidthUsed) || other.droneBandwidthUsed == droneBandwidthUsed)&&(identical(other.droneBandwidthMax, droneBandwidthMax) || other.droneBandwidthMax == droneBandwidthMax)&&(identical(other.droneBayUsed, droneBayUsed) || other.droneBayUsed == droneBayUsed)&&(identical(other.droneBayMax, droneBayMax) || other.droneBayMax == droneBayMax)&&(identical(other.shipCost, shipCost) || other.shipCost == shipCost)&&(identical(other.moduleCost, moduleCost) || other.moduleCost == moduleCost)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,cpuUsed,cpuMax,powerUsed,powerMax,calibrationUsed,calibrationMax,capacitorCapacity,capacitorRecharge,capacitorStable,isCapStable,defenses,dpsTotal,dpsGuns,dpsDrones,dpsMissiles,volley,optimalRange,falloffRange,maxVelocity,inertiaModifier,alignTime,warpSpeed,massKg,targetRange,scanResolution,maxLockedTargets,signatureRadius,droneBandwidthUsed,droneBandwidthMax,droneBayUsed,droneBayMax,shipCost,moduleCost,totalCost]);

@override
String toString() {
  return 'FittingStats(cpuUsed: $cpuUsed, cpuMax: $cpuMax, powerUsed: $powerUsed, powerMax: $powerMax, calibrationUsed: $calibrationUsed, calibrationMax: $calibrationMax, capacitorCapacity: $capacitorCapacity, capacitorRecharge: $capacitorRecharge, capacitorStable: $capacitorStable, isCapStable: $isCapStable, defenses: $defenses, dpsTotal: $dpsTotal, dpsGuns: $dpsGuns, dpsDrones: $dpsDrones, dpsMissiles: $dpsMissiles, volley: $volley, optimalRange: $optimalRange, falloffRange: $falloffRange, maxVelocity: $maxVelocity, inertiaModifier: $inertiaModifier, alignTime: $alignTime, warpSpeed: $warpSpeed, massKg: $massKg, targetRange: $targetRange, scanResolution: $scanResolution, maxLockedTargets: $maxLockedTargets, signatureRadius: $signatureRadius, droneBandwidthUsed: $droneBandwidthUsed, droneBandwidthMax: $droneBandwidthMax, droneBayUsed: $droneBayUsed, droneBayMax: $droneBayMax, shipCost: $shipCost, moduleCost: $moduleCost, totalCost: $totalCost)';
}


}

/// @nodoc
abstract mixin class _$FittingStatsCopyWith<$Res> implements $FittingStatsCopyWith<$Res> {
  factory _$FittingStatsCopyWith(_FittingStats value, $Res Function(_FittingStats) _then) = __$FittingStatsCopyWithImpl;
@override @useResult
$Res call({
 double cpuUsed, double cpuMax, double powerUsed, double powerMax, int calibrationUsed, int calibrationMax, double capacitorCapacity, double capacitorRecharge, double capacitorStable, bool isCapStable, DefenseProfile defenses, double dpsTotal, double dpsGuns, double dpsDrones, double dpsMissiles, double volley, double optimalRange, double falloffRange, double maxVelocity, double inertiaModifier, double alignTime, double warpSpeed, double massKg, double targetRange, double scanResolution, int maxLockedTargets, double signatureRadius, double droneBandwidthUsed, double droneBandwidthMax, double droneBayUsed, double droneBayMax, double shipCost, double moduleCost, double totalCost
});


@override $DefenseProfileCopyWith<$Res> get defenses;

}
/// @nodoc
class __$FittingStatsCopyWithImpl<$Res>
    implements _$FittingStatsCopyWith<$Res> {
  __$FittingStatsCopyWithImpl(this._self, this._then);

  final _FittingStats _self;
  final $Res Function(_FittingStats) _then;

/// Create a copy of FittingStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cpuUsed = null,Object? cpuMax = null,Object? powerUsed = null,Object? powerMax = null,Object? calibrationUsed = null,Object? calibrationMax = null,Object? capacitorCapacity = null,Object? capacitorRecharge = null,Object? capacitorStable = null,Object? isCapStable = null,Object? defenses = null,Object? dpsTotal = null,Object? dpsGuns = null,Object? dpsDrones = null,Object? dpsMissiles = null,Object? volley = null,Object? optimalRange = null,Object? falloffRange = null,Object? maxVelocity = null,Object? inertiaModifier = null,Object? alignTime = null,Object? warpSpeed = null,Object? massKg = null,Object? targetRange = null,Object? scanResolution = null,Object? maxLockedTargets = null,Object? signatureRadius = null,Object? droneBandwidthUsed = null,Object? droneBandwidthMax = null,Object? droneBayUsed = null,Object? droneBayMax = null,Object? shipCost = null,Object? moduleCost = null,Object? totalCost = null,}) {
  return _then(_FittingStats(
cpuUsed: null == cpuUsed ? _self.cpuUsed : cpuUsed // ignore: cast_nullable_to_non_nullable
as double,cpuMax: null == cpuMax ? _self.cpuMax : cpuMax // ignore: cast_nullable_to_non_nullable
as double,powerUsed: null == powerUsed ? _self.powerUsed : powerUsed // ignore: cast_nullable_to_non_nullable
as double,powerMax: null == powerMax ? _self.powerMax : powerMax // ignore: cast_nullable_to_non_nullable
as double,calibrationUsed: null == calibrationUsed ? _self.calibrationUsed : calibrationUsed // ignore: cast_nullable_to_non_nullable
as int,calibrationMax: null == calibrationMax ? _self.calibrationMax : calibrationMax // ignore: cast_nullable_to_non_nullable
as int,capacitorCapacity: null == capacitorCapacity ? _self.capacitorCapacity : capacitorCapacity // ignore: cast_nullable_to_non_nullable
as double,capacitorRecharge: null == capacitorRecharge ? _self.capacitorRecharge : capacitorRecharge // ignore: cast_nullable_to_non_nullable
as double,capacitorStable: null == capacitorStable ? _self.capacitorStable : capacitorStable // ignore: cast_nullable_to_non_nullable
as double,isCapStable: null == isCapStable ? _self.isCapStable : isCapStable // ignore: cast_nullable_to_non_nullable
as bool,defenses: null == defenses ? _self.defenses : defenses // ignore: cast_nullable_to_non_nullable
as DefenseProfile,dpsTotal: null == dpsTotal ? _self.dpsTotal : dpsTotal // ignore: cast_nullable_to_non_nullable
as double,dpsGuns: null == dpsGuns ? _self.dpsGuns : dpsGuns // ignore: cast_nullable_to_non_nullable
as double,dpsDrones: null == dpsDrones ? _self.dpsDrones : dpsDrones // ignore: cast_nullable_to_non_nullable
as double,dpsMissiles: null == dpsMissiles ? _self.dpsMissiles : dpsMissiles // ignore: cast_nullable_to_non_nullable
as double,volley: null == volley ? _self.volley : volley // ignore: cast_nullable_to_non_nullable
as double,optimalRange: null == optimalRange ? _self.optimalRange : optimalRange // ignore: cast_nullable_to_non_nullable
as double,falloffRange: null == falloffRange ? _self.falloffRange : falloffRange // ignore: cast_nullable_to_non_nullable
as double,maxVelocity: null == maxVelocity ? _self.maxVelocity : maxVelocity // ignore: cast_nullable_to_non_nullable
as double,inertiaModifier: null == inertiaModifier ? _self.inertiaModifier : inertiaModifier // ignore: cast_nullable_to_non_nullable
as double,alignTime: null == alignTime ? _self.alignTime : alignTime // ignore: cast_nullable_to_non_nullable
as double,warpSpeed: null == warpSpeed ? _self.warpSpeed : warpSpeed // ignore: cast_nullable_to_non_nullable
as double,massKg: null == massKg ? _self.massKg : massKg // ignore: cast_nullable_to_non_nullable
as double,targetRange: null == targetRange ? _self.targetRange : targetRange // ignore: cast_nullable_to_non_nullable
as double,scanResolution: null == scanResolution ? _self.scanResolution : scanResolution // ignore: cast_nullable_to_non_nullable
as double,maxLockedTargets: null == maxLockedTargets ? _self.maxLockedTargets : maxLockedTargets // ignore: cast_nullable_to_non_nullable
as int,signatureRadius: null == signatureRadius ? _self.signatureRadius : signatureRadius // ignore: cast_nullable_to_non_nullable
as double,droneBandwidthUsed: null == droneBandwidthUsed ? _self.droneBandwidthUsed : droneBandwidthUsed // ignore: cast_nullable_to_non_nullable
as double,droneBandwidthMax: null == droneBandwidthMax ? _self.droneBandwidthMax : droneBandwidthMax // ignore: cast_nullable_to_non_nullable
as double,droneBayUsed: null == droneBayUsed ? _self.droneBayUsed : droneBayUsed // ignore: cast_nullable_to_non_nullable
as double,droneBayMax: null == droneBayMax ? _self.droneBayMax : droneBayMax // ignore: cast_nullable_to_non_nullable
as double,shipCost: null == shipCost ? _self.shipCost : shipCost // ignore: cast_nullable_to_non_nullable
as double,moduleCost: null == moduleCost ? _self.moduleCost : moduleCost // ignore: cast_nullable_to_non_nullable
as double,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of FittingStats
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DefenseProfileCopyWith<$Res> get defenses {
  
  return $DefenseProfileCopyWith<$Res>(_self.defenses, (value) {
    return _then(_self.copyWith(defenses: value));
  });
}
}


/// @nodoc
mixin _$DefenseProfile {

 double get shieldHp; double get shieldRecharge; ResistProfile get shieldResists; double get shieldEhp; double get armorHp; ResistProfile get armorResists; double get armorEhp; double get hullHp; ResistProfile get hullResists; double get hullEhp; double get totalEhp; double get effectiveShieldBoost; double get effectiveArmorRepair;
/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DefenseProfileCopyWith<DefenseProfile> get copyWith => _$DefenseProfileCopyWithImpl<DefenseProfile>(this as DefenseProfile, _$identity);

  /// Serializes this DefenseProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DefenseProfile&&(identical(other.shieldHp, shieldHp) || other.shieldHp == shieldHp)&&(identical(other.shieldRecharge, shieldRecharge) || other.shieldRecharge == shieldRecharge)&&(identical(other.shieldResists, shieldResists) || other.shieldResists == shieldResists)&&(identical(other.shieldEhp, shieldEhp) || other.shieldEhp == shieldEhp)&&(identical(other.armorHp, armorHp) || other.armorHp == armorHp)&&(identical(other.armorResists, armorResists) || other.armorResists == armorResists)&&(identical(other.armorEhp, armorEhp) || other.armorEhp == armorEhp)&&(identical(other.hullHp, hullHp) || other.hullHp == hullHp)&&(identical(other.hullResists, hullResists) || other.hullResists == hullResists)&&(identical(other.hullEhp, hullEhp) || other.hullEhp == hullEhp)&&(identical(other.totalEhp, totalEhp) || other.totalEhp == totalEhp)&&(identical(other.effectiveShieldBoost, effectiveShieldBoost) || other.effectiveShieldBoost == effectiveShieldBoost)&&(identical(other.effectiveArmorRepair, effectiveArmorRepair) || other.effectiveArmorRepair == effectiveArmorRepair));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shieldHp,shieldRecharge,shieldResists,shieldEhp,armorHp,armorResists,armorEhp,hullHp,hullResists,hullEhp,totalEhp,effectiveShieldBoost,effectiveArmorRepair);

@override
String toString() {
  return 'DefenseProfile(shieldHp: $shieldHp, shieldRecharge: $shieldRecharge, shieldResists: $shieldResists, shieldEhp: $shieldEhp, armorHp: $armorHp, armorResists: $armorResists, armorEhp: $armorEhp, hullHp: $hullHp, hullResists: $hullResists, hullEhp: $hullEhp, totalEhp: $totalEhp, effectiveShieldBoost: $effectiveShieldBoost, effectiveArmorRepair: $effectiveArmorRepair)';
}


}

/// @nodoc
abstract mixin class $DefenseProfileCopyWith<$Res>  {
  factory $DefenseProfileCopyWith(DefenseProfile value, $Res Function(DefenseProfile) _then) = _$DefenseProfileCopyWithImpl;
@useResult
$Res call({
 double shieldHp, double shieldRecharge, ResistProfile shieldResists, double shieldEhp, double armorHp, ResistProfile armorResists, double armorEhp, double hullHp, ResistProfile hullResists, double hullEhp, double totalEhp, double effectiveShieldBoost, double effectiveArmorRepair
});


$ResistProfileCopyWith<$Res> get shieldResists;$ResistProfileCopyWith<$Res> get armorResists;$ResistProfileCopyWith<$Res> get hullResists;

}
/// @nodoc
class _$DefenseProfileCopyWithImpl<$Res>
    implements $DefenseProfileCopyWith<$Res> {
  _$DefenseProfileCopyWithImpl(this._self, this._then);

  final DefenseProfile _self;
  final $Res Function(DefenseProfile) _then;

/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shieldHp = null,Object? shieldRecharge = null,Object? shieldResists = null,Object? shieldEhp = null,Object? armorHp = null,Object? armorResists = null,Object? armorEhp = null,Object? hullHp = null,Object? hullResists = null,Object? hullEhp = null,Object? totalEhp = null,Object? effectiveShieldBoost = null,Object? effectiveArmorRepair = null,}) {
  return _then(_self.copyWith(
shieldHp: null == shieldHp ? _self.shieldHp : shieldHp // ignore: cast_nullable_to_non_nullable
as double,shieldRecharge: null == shieldRecharge ? _self.shieldRecharge : shieldRecharge // ignore: cast_nullable_to_non_nullable
as double,shieldResists: null == shieldResists ? _self.shieldResists : shieldResists // ignore: cast_nullable_to_non_nullable
as ResistProfile,shieldEhp: null == shieldEhp ? _self.shieldEhp : shieldEhp // ignore: cast_nullable_to_non_nullable
as double,armorHp: null == armorHp ? _self.armorHp : armorHp // ignore: cast_nullable_to_non_nullable
as double,armorResists: null == armorResists ? _self.armorResists : armorResists // ignore: cast_nullable_to_non_nullable
as ResistProfile,armorEhp: null == armorEhp ? _self.armorEhp : armorEhp // ignore: cast_nullable_to_non_nullable
as double,hullHp: null == hullHp ? _self.hullHp : hullHp // ignore: cast_nullable_to_non_nullable
as double,hullResists: null == hullResists ? _self.hullResists : hullResists // ignore: cast_nullable_to_non_nullable
as ResistProfile,hullEhp: null == hullEhp ? _self.hullEhp : hullEhp // ignore: cast_nullable_to_non_nullable
as double,totalEhp: null == totalEhp ? _self.totalEhp : totalEhp // ignore: cast_nullable_to_non_nullable
as double,effectiveShieldBoost: null == effectiveShieldBoost ? _self.effectiveShieldBoost : effectiveShieldBoost // ignore: cast_nullable_to_non_nullable
as double,effectiveArmorRepair: null == effectiveArmorRepair ? _self.effectiveArmorRepair : effectiveArmorRepair // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<$Res> get shieldResists {
  
  return $ResistProfileCopyWith<$Res>(_self.shieldResists, (value) {
    return _then(_self.copyWith(shieldResists: value));
  });
}/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<$Res> get armorResists {
  
  return $ResistProfileCopyWith<$Res>(_self.armorResists, (value) {
    return _then(_self.copyWith(armorResists: value));
  });
}/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<$Res> get hullResists {
  
  return $ResistProfileCopyWith<$Res>(_self.hullResists, (value) {
    return _then(_self.copyWith(hullResists: value));
  });
}
}


/// Adds pattern-matching-related methods to [DefenseProfile].
extension DefenseProfilePatterns on DefenseProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DefenseProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DefenseProfile() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DefenseProfile value)  $default,){
final _that = this;
switch (_that) {
case _DefenseProfile():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DefenseProfile value)?  $default,){
final _that = this;
switch (_that) {
case _DefenseProfile() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double shieldHp,  double shieldRecharge,  ResistProfile shieldResists,  double shieldEhp,  double armorHp,  ResistProfile armorResists,  double armorEhp,  double hullHp,  ResistProfile hullResists,  double hullEhp,  double totalEhp,  double effectiveShieldBoost,  double effectiveArmorRepair)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DefenseProfile() when $default != null:
return $default(_that.shieldHp,_that.shieldRecharge,_that.shieldResists,_that.shieldEhp,_that.armorHp,_that.armorResists,_that.armorEhp,_that.hullHp,_that.hullResists,_that.hullEhp,_that.totalEhp,_that.effectiveShieldBoost,_that.effectiveArmorRepair);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double shieldHp,  double shieldRecharge,  ResistProfile shieldResists,  double shieldEhp,  double armorHp,  ResistProfile armorResists,  double armorEhp,  double hullHp,  ResistProfile hullResists,  double hullEhp,  double totalEhp,  double effectiveShieldBoost,  double effectiveArmorRepair)  $default,) {final _that = this;
switch (_that) {
case _DefenseProfile():
return $default(_that.shieldHp,_that.shieldRecharge,_that.shieldResists,_that.shieldEhp,_that.armorHp,_that.armorResists,_that.armorEhp,_that.hullHp,_that.hullResists,_that.hullEhp,_that.totalEhp,_that.effectiveShieldBoost,_that.effectiveArmorRepair);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double shieldHp,  double shieldRecharge,  ResistProfile shieldResists,  double shieldEhp,  double armorHp,  ResistProfile armorResists,  double armorEhp,  double hullHp,  ResistProfile hullResists,  double hullEhp,  double totalEhp,  double effectiveShieldBoost,  double effectiveArmorRepair)?  $default,) {final _that = this;
switch (_that) {
case _DefenseProfile() when $default != null:
return $default(_that.shieldHp,_that.shieldRecharge,_that.shieldResists,_that.shieldEhp,_that.armorHp,_that.armorResists,_that.armorEhp,_that.hullHp,_that.hullResists,_that.hullEhp,_that.totalEhp,_that.effectiveShieldBoost,_that.effectiveArmorRepair);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DefenseProfile implements DefenseProfile {
  const _DefenseProfile({this.shieldHp = 0.0, this.shieldRecharge = 0.0, this.shieldResists = const ResistProfile(), this.shieldEhp = 0.0, this.armorHp = 0.0, this.armorResists = const ResistProfile(), this.armorEhp = 0.0, this.hullHp = 0.0, this.hullResists = const ResistProfile(), this.hullEhp = 0.0, this.totalEhp = 0.0, this.effectiveShieldBoost = 0.0, this.effectiveArmorRepair = 0.0});
  factory _DefenseProfile.fromJson(Map<String, dynamic> json) => _$DefenseProfileFromJson(json);

@override@JsonKey() final  double shieldHp;
@override@JsonKey() final  double shieldRecharge;
@override@JsonKey() final  ResistProfile shieldResists;
@override@JsonKey() final  double shieldEhp;
@override@JsonKey() final  double armorHp;
@override@JsonKey() final  ResistProfile armorResists;
@override@JsonKey() final  double armorEhp;
@override@JsonKey() final  double hullHp;
@override@JsonKey() final  ResistProfile hullResists;
@override@JsonKey() final  double hullEhp;
@override@JsonKey() final  double totalEhp;
@override@JsonKey() final  double effectiveShieldBoost;
@override@JsonKey() final  double effectiveArmorRepair;

/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DefenseProfileCopyWith<_DefenseProfile> get copyWith => __$DefenseProfileCopyWithImpl<_DefenseProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DefenseProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DefenseProfile&&(identical(other.shieldHp, shieldHp) || other.shieldHp == shieldHp)&&(identical(other.shieldRecharge, shieldRecharge) || other.shieldRecharge == shieldRecharge)&&(identical(other.shieldResists, shieldResists) || other.shieldResists == shieldResists)&&(identical(other.shieldEhp, shieldEhp) || other.shieldEhp == shieldEhp)&&(identical(other.armorHp, armorHp) || other.armorHp == armorHp)&&(identical(other.armorResists, armorResists) || other.armorResists == armorResists)&&(identical(other.armorEhp, armorEhp) || other.armorEhp == armorEhp)&&(identical(other.hullHp, hullHp) || other.hullHp == hullHp)&&(identical(other.hullResists, hullResists) || other.hullResists == hullResists)&&(identical(other.hullEhp, hullEhp) || other.hullEhp == hullEhp)&&(identical(other.totalEhp, totalEhp) || other.totalEhp == totalEhp)&&(identical(other.effectiveShieldBoost, effectiveShieldBoost) || other.effectiveShieldBoost == effectiveShieldBoost)&&(identical(other.effectiveArmorRepair, effectiveArmorRepair) || other.effectiveArmorRepair == effectiveArmorRepair));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,shieldHp,shieldRecharge,shieldResists,shieldEhp,armorHp,armorResists,armorEhp,hullHp,hullResists,hullEhp,totalEhp,effectiveShieldBoost,effectiveArmorRepair);

@override
String toString() {
  return 'DefenseProfile(shieldHp: $shieldHp, shieldRecharge: $shieldRecharge, shieldResists: $shieldResists, shieldEhp: $shieldEhp, armorHp: $armorHp, armorResists: $armorResists, armorEhp: $armorEhp, hullHp: $hullHp, hullResists: $hullResists, hullEhp: $hullEhp, totalEhp: $totalEhp, effectiveShieldBoost: $effectiveShieldBoost, effectiveArmorRepair: $effectiveArmorRepair)';
}


}

/// @nodoc
abstract mixin class _$DefenseProfileCopyWith<$Res> implements $DefenseProfileCopyWith<$Res> {
  factory _$DefenseProfileCopyWith(_DefenseProfile value, $Res Function(_DefenseProfile) _then) = __$DefenseProfileCopyWithImpl;
@override @useResult
$Res call({
 double shieldHp, double shieldRecharge, ResistProfile shieldResists, double shieldEhp, double armorHp, ResistProfile armorResists, double armorEhp, double hullHp, ResistProfile hullResists, double hullEhp, double totalEhp, double effectiveShieldBoost, double effectiveArmorRepair
});


@override $ResistProfileCopyWith<$Res> get shieldResists;@override $ResistProfileCopyWith<$Res> get armorResists;@override $ResistProfileCopyWith<$Res> get hullResists;

}
/// @nodoc
class __$DefenseProfileCopyWithImpl<$Res>
    implements _$DefenseProfileCopyWith<$Res> {
  __$DefenseProfileCopyWithImpl(this._self, this._then);

  final _DefenseProfile _self;
  final $Res Function(_DefenseProfile) _then;

/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shieldHp = null,Object? shieldRecharge = null,Object? shieldResists = null,Object? shieldEhp = null,Object? armorHp = null,Object? armorResists = null,Object? armorEhp = null,Object? hullHp = null,Object? hullResists = null,Object? hullEhp = null,Object? totalEhp = null,Object? effectiveShieldBoost = null,Object? effectiveArmorRepair = null,}) {
  return _then(_DefenseProfile(
shieldHp: null == shieldHp ? _self.shieldHp : shieldHp // ignore: cast_nullable_to_non_nullable
as double,shieldRecharge: null == shieldRecharge ? _self.shieldRecharge : shieldRecharge // ignore: cast_nullable_to_non_nullable
as double,shieldResists: null == shieldResists ? _self.shieldResists : shieldResists // ignore: cast_nullable_to_non_nullable
as ResistProfile,shieldEhp: null == shieldEhp ? _self.shieldEhp : shieldEhp // ignore: cast_nullable_to_non_nullable
as double,armorHp: null == armorHp ? _self.armorHp : armorHp // ignore: cast_nullable_to_non_nullable
as double,armorResists: null == armorResists ? _self.armorResists : armorResists // ignore: cast_nullable_to_non_nullable
as ResistProfile,armorEhp: null == armorEhp ? _self.armorEhp : armorEhp // ignore: cast_nullable_to_non_nullable
as double,hullHp: null == hullHp ? _self.hullHp : hullHp // ignore: cast_nullable_to_non_nullable
as double,hullResists: null == hullResists ? _self.hullResists : hullResists // ignore: cast_nullable_to_non_nullable
as ResistProfile,hullEhp: null == hullEhp ? _self.hullEhp : hullEhp // ignore: cast_nullable_to_non_nullable
as double,totalEhp: null == totalEhp ? _self.totalEhp : totalEhp // ignore: cast_nullable_to_non_nullable
as double,effectiveShieldBoost: null == effectiveShieldBoost ? _self.effectiveShieldBoost : effectiveShieldBoost // ignore: cast_nullable_to_non_nullable
as double,effectiveArmorRepair: null == effectiveArmorRepair ? _self.effectiveArmorRepair : effectiveArmorRepair // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<$Res> get shieldResists {
  
  return $ResistProfileCopyWith<$Res>(_self.shieldResists, (value) {
    return _then(_self.copyWith(shieldResists: value));
  });
}/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<$Res> get armorResists {
  
  return $ResistProfileCopyWith<$Res>(_self.armorResists, (value) {
    return _then(_self.copyWith(armorResists: value));
  });
}/// Create a copy of DefenseProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<$Res> get hullResists {
  
  return $ResistProfileCopyWith<$Res>(_self.hullResists, (value) {
    return _then(_self.copyWith(hullResists: value));
  });
}
}


/// @nodoc
mixin _$ResistProfile {

 double get em; double get thermal; double get kinetic; double get explosive;
/// Create a copy of ResistProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResistProfileCopyWith<ResistProfile> get copyWith => _$ResistProfileCopyWithImpl<ResistProfile>(this as ResistProfile, _$identity);

  /// Serializes this ResistProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResistProfile&&(identical(other.em, em) || other.em == em)&&(identical(other.thermal, thermal) || other.thermal == thermal)&&(identical(other.kinetic, kinetic) || other.kinetic == kinetic)&&(identical(other.explosive, explosive) || other.explosive == explosive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,em,thermal,kinetic,explosive);

@override
String toString() {
  return 'ResistProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
}


}

/// @nodoc
abstract mixin class $ResistProfileCopyWith<$Res>  {
  factory $ResistProfileCopyWith(ResistProfile value, $Res Function(ResistProfile) _then) = _$ResistProfileCopyWithImpl;
@useResult
$Res call({
 double em, double thermal, double kinetic, double explosive
});




}
/// @nodoc
class _$ResistProfileCopyWithImpl<$Res>
    implements $ResistProfileCopyWith<$Res> {
  _$ResistProfileCopyWithImpl(this._self, this._then);

  final ResistProfile _self;
  final $Res Function(ResistProfile) _then;

/// Create a copy of ResistProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? em = null,Object? thermal = null,Object? kinetic = null,Object? explosive = null,}) {
  return _then(_self.copyWith(
em: null == em ? _self.em : em // ignore: cast_nullable_to_non_nullable
as double,thermal: null == thermal ? _self.thermal : thermal // ignore: cast_nullable_to_non_nullable
as double,kinetic: null == kinetic ? _self.kinetic : kinetic // ignore: cast_nullable_to_non_nullable
as double,explosive: null == explosive ? _self.explosive : explosive // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ResistProfile].
extension ResistProfilePatterns on ResistProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResistProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResistProfile() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResistProfile value)  $default,){
final _that = this;
switch (_that) {
case _ResistProfile():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResistProfile value)?  $default,){
final _that = this;
switch (_that) {
case _ResistProfile() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double em,  double thermal,  double kinetic,  double explosive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResistProfile() when $default != null:
return $default(_that.em,_that.thermal,_that.kinetic,_that.explosive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double em,  double thermal,  double kinetic,  double explosive)  $default,) {final _that = this;
switch (_that) {
case _ResistProfile():
return $default(_that.em,_that.thermal,_that.kinetic,_that.explosive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double em,  double thermal,  double kinetic,  double explosive)?  $default,) {final _that = this;
switch (_that) {
case _ResistProfile() when $default != null:
return $default(_that.em,_that.thermal,_that.kinetic,_that.explosive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResistProfile extends ResistProfile {
  const _ResistProfile({this.em = 0.0, this.thermal = 0.0, this.kinetic = 0.0, this.explosive = 0.0}): super._();
  factory _ResistProfile.fromJson(Map<String, dynamic> json) => _$ResistProfileFromJson(json);

@override@JsonKey() final  double em;
@override@JsonKey() final  double thermal;
@override@JsonKey() final  double kinetic;
@override@JsonKey() final  double explosive;

/// Create a copy of ResistProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResistProfileCopyWith<_ResistProfile> get copyWith => __$ResistProfileCopyWithImpl<_ResistProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResistProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResistProfile&&(identical(other.em, em) || other.em == em)&&(identical(other.thermal, thermal) || other.thermal == thermal)&&(identical(other.kinetic, kinetic) || other.kinetic == kinetic)&&(identical(other.explosive, explosive) || other.explosive == explosive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,em,thermal,kinetic,explosive);

@override
String toString() {
  return 'ResistProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
}


}

/// @nodoc
abstract mixin class _$ResistProfileCopyWith<$Res> implements $ResistProfileCopyWith<$Res> {
  factory _$ResistProfileCopyWith(_ResistProfile value, $Res Function(_ResistProfile) _then) = __$ResistProfileCopyWithImpl;
@override @useResult
$Res call({
 double em, double thermal, double kinetic, double explosive
});




}
/// @nodoc
class __$ResistProfileCopyWithImpl<$Res>
    implements _$ResistProfileCopyWith<$Res> {
  __$ResistProfileCopyWithImpl(this._self, this._then);

  final _ResistProfile _self;
  final $Res Function(_ResistProfile) _then;

/// Create a copy of ResistProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? em = null,Object? thermal = null,Object? kinetic = null,Object? explosive = null,}) {
  return _then(_ResistProfile(
em: null == em ? _self.em : em // ignore: cast_nullable_to_non_nullable
as double,thermal: null == thermal ? _self.thermal : thermal // ignore: cast_nullable_to_non_nullable
as double,kinetic: null == kinetic ? _self.kinetic : kinetic // ignore: cast_nullable_to_non_nullable
as double,explosive: null == explosive ? _self.explosive : explosive // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$ShipType {

 int get typeId; String get name; String get description; int get groupId; String get groupName; String get raceName; int get highSlots; int get medSlots; int get lowSlots; int get rigSlots; int get turretSlots; int get launcherSlots; Map<int, double> get baseAttributes; List<ShipBonus> get bonuses; List<SkillRequirement> get skillRequirements;
/// Create a copy of ShipType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShipTypeCopyWith<ShipType> get copyWith => _$ShipTypeCopyWithImpl<ShipType>(this as ShipType, _$identity);

  /// Serializes this ShipType to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShipType&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.raceName, raceName) || other.raceName == raceName)&&(identical(other.highSlots, highSlots) || other.highSlots == highSlots)&&(identical(other.medSlots, medSlots) || other.medSlots == medSlots)&&(identical(other.lowSlots, lowSlots) || other.lowSlots == lowSlots)&&(identical(other.rigSlots, rigSlots) || other.rigSlots == rigSlots)&&(identical(other.turretSlots, turretSlots) || other.turretSlots == turretSlots)&&(identical(other.launcherSlots, launcherSlots) || other.launcherSlots == launcherSlots)&&const DeepCollectionEquality().equals(other.baseAttributes, baseAttributes)&&const DeepCollectionEquality().equals(other.bonuses, bonuses)&&const DeepCollectionEquality().equals(other.skillRequirements, skillRequirements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,name,description,groupId,groupName,raceName,highSlots,medSlots,lowSlots,rigSlots,turretSlots,launcherSlots,const DeepCollectionEquality().hash(baseAttributes),const DeepCollectionEquality().hash(bonuses),const DeepCollectionEquality().hash(skillRequirements));

@override
String toString() {
  return 'ShipType(typeId: $typeId, name: $name, description: $description, groupId: $groupId, groupName: $groupName, raceName: $raceName, highSlots: $highSlots, medSlots: $medSlots, lowSlots: $lowSlots, rigSlots: $rigSlots, turretSlots: $turretSlots, launcherSlots: $launcherSlots, baseAttributes: $baseAttributes, bonuses: $bonuses, skillRequirements: $skillRequirements)';
}


}

/// @nodoc
abstract mixin class $ShipTypeCopyWith<$Res>  {
  factory $ShipTypeCopyWith(ShipType value, $Res Function(ShipType) _then) = _$ShipTypeCopyWithImpl;
@useResult
$Res call({
 int typeId, String name, String description, int groupId, String groupName, String raceName, int highSlots, int medSlots, int lowSlots, int rigSlots, int turretSlots, int launcherSlots, Map<int, double> baseAttributes, List<ShipBonus> bonuses, List<SkillRequirement> skillRequirements
});




}
/// @nodoc
class _$ShipTypeCopyWithImpl<$Res>
    implements $ShipTypeCopyWith<$Res> {
  _$ShipTypeCopyWithImpl(this._self, this._then);

  final ShipType _self;
  final $Res Function(ShipType) _then;

/// Create a copy of ShipType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? typeId = null,Object? name = null,Object? description = null,Object? groupId = null,Object? groupName = null,Object? raceName = null,Object? highSlots = null,Object? medSlots = null,Object? lowSlots = null,Object? rigSlots = null,Object? turretSlots = null,Object? launcherSlots = null,Object? baseAttributes = null,Object? bonuses = null,Object? skillRequirements = null,}) {
  return _then(_self.copyWith(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,raceName: null == raceName ? _self.raceName : raceName // ignore: cast_nullable_to_non_nullable
as String,highSlots: null == highSlots ? _self.highSlots : highSlots // ignore: cast_nullable_to_non_nullable
as int,medSlots: null == medSlots ? _self.medSlots : medSlots // ignore: cast_nullable_to_non_nullable
as int,lowSlots: null == lowSlots ? _self.lowSlots : lowSlots // ignore: cast_nullable_to_non_nullable
as int,rigSlots: null == rigSlots ? _self.rigSlots : rigSlots // ignore: cast_nullable_to_non_nullable
as int,turretSlots: null == turretSlots ? _self.turretSlots : turretSlots // ignore: cast_nullable_to_non_nullable
as int,launcherSlots: null == launcherSlots ? _self.launcherSlots : launcherSlots // ignore: cast_nullable_to_non_nullable
as int,baseAttributes: null == baseAttributes ? _self.baseAttributes : baseAttributes // ignore: cast_nullable_to_non_nullable
as Map<int, double>,bonuses: null == bonuses ? _self.bonuses : bonuses // ignore: cast_nullable_to_non_nullable
as List<ShipBonus>,skillRequirements: null == skillRequirements ? _self.skillRequirements : skillRequirements // ignore: cast_nullable_to_non_nullable
as List<SkillRequirement>,
  ));
}

}


/// Adds pattern-matching-related methods to [ShipType].
extension ShipTypePatterns on ShipType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShipType value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShipType() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShipType value)  $default,){
final _that = this;
switch (_that) {
case _ShipType():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShipType value)?  $default,){
final _that = this;
switch (_that) {
case _ShipType() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int typeId,  String name,  String description,  int groupId,  String groupName,  String raceName,  int highSlots,  int medSlots,  int lowSlots,  int rigSlots,  int turretSlots,  int launcherSlots,  Map<int, double> baseAttributes,  List<ShipBonus> bonuses,  List<SkillRequirement> skillRequirements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShipType() when $default != null:
return $default(_that.typeId,_that.name,_that.description,_that.groupId,_that.groupName,_that.raceName,_that.highSlots,_that.medSlots,_that.lowSlots,_that.rigSlots,_that.turretSlots,_that.launcherSlots,_that.baseAttributes,_that.bonuses,_that.skillRequirements);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int typeId,  String name,  String description,  int groupId,  String groupName,  String raceName,  int highSlots,  int medSlots,  int lowSlots,  int rigSlots,  int turretSlots,  int launcherSlots,  Map<int, double> baseAttributes,  List<ShipBonus> bonuses,  List<SkillRequirement> skillRequirements)  $default,) {final _that = this;
switch (_that) {
case _ShipType():
return $default(_that.typeId,_that.name,_that.description,_that.groupId,_that.groupName,_that.raceName,_that.highSlots,_that.medSlots,_that.lowSlots,_that.rigSlots,_that.turretSlots,_that.launcherSlots,_that.baseAttributes,_that.bonuses,_that.skillRequirements);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int typeId,  String name,  String description,  int groupId,  String groupName,  String raceName,  int highSlots,  int medSlots,  int lowSlots,  int rigSlots,  int turretSlots,  int launcherSlots,  Map<int, double> baseAttributes,  List<ShipBonus> bonuses,  List<SkillRequirement> skillRequirements)?  $default,) {final _that = this;
switch (_that) {
case _ShipType() when $default != null:
return $default(_that.typeId,_that.name,_that.description,_that.groupId,_that.groupName,_that.raceName,_that.highSlots,_that.medSlots,_that.lowSlots,_that.rigSlots,_that.turretSlots,_that.launcherSlots,_that.baseAttributes,_that.bonuses,_that.skillRequirements);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShipType implements ShipType {
  const _ShipType({required this.typeId, required this.name, required this.description, required this.groupId, required this.groupName, this.raceName = '', this.highSlots = 0, this.medSlots = 0, this.lowSlots = 0, this.rigSlots = 0, this.turretSlots = 0, this.launcherSlots = 0, final  Map<int, double> baseAttributes = const {}, final  List<ShipBonus> bonuses = const [], final  List<SkillRequirement> skillRequirements = const []}): _baseAttributes = baseAttributes,_bonuses = bonuses,_skillRequirements = skillRequirements;
  factory _ShipType.fromJson(Map<String, dynamic> json) => _$ShipTypeFromJson(json);

@override final  int typeId;
@override final  String name;
@override final  String description;
@override final  int groupId;
@override final  String groupName;
@override@JsonKey() final  String raceName;
@override@JsonKey() final  int highSlots;
@override@JsonKey() final  int medSlots;
@override@JsonKey() final  int lowSlots;
@override@JsonKey() final  int rigSlots;
@override@JsonKey() final  int turretSlots;
@override@JsonKey() final  int launcherSlots;
 final  Map<int, double> _baseAttributes;
@override@JsonKey() Map<int, double> get baseAttributes {
  if (_baseAttributes is EqualUnmodifiableMapView) return _baseAttributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_baseAttributes);
}

 final  List<ShipBonus> _bonuses;
@override@JsonKey() List<ShipBonus> get bonuses {
  if (_bonuses is EqualUnmodifiableListView) return _bonuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bonuses);
}

 final  List<SkillRequirement> _skillRequirements;
@override@JsonKey() List<SkillRequirement> get skillRequirements {
  if (_skillRequirements is EqualUnmodifiableListView) return _skillRequirements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skillRequirements);
}


/// Create a copy of ShipType
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShipTypeCopyWith<_ShipType> get copyWith => __$ShipTypeCopyWithImpl<_ShipType>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShipTypeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShipType&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.raceName, raceName) || other.raceName == raceName)&&(identical(other.highSlots, highSlots) || other.highSlots == highSlots)&&(identical(other.medSlots, medSlots) || other.medSlots == medSlots)&&(identical(other.lowSlots, lowSlots) || other.lowSlots == lowSlots)&&(identical(other.rigSlots, rigSlots) || other.rigSlots == rigSlots)&&(identical(other.turretSlots, turretSlots) || other.turretSlots == turretSlots)&&(identical(other.launcherSlots, launcherSlots) || other.launcherSlots == launcherSlots)&&const DeepCollectionEquality().equals(other._baseAttributes, _baseAttributes)&&const DeepCollectionEquality().equals(other._bonuses, _bonuses)&&const DeepCollectionEquality().equals(other._skillRequirements, _skillRequirements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,name,description,groupId,groupName,raceName,highSlots,medSlots,lowSlots,rigSlots,turretSlots,launcherSlots,const DeepCollectionEquality().hash(_baseAttributes),const DeepCollectionEquality().hash(_bonuses),const DeepCollectionEquality().hash(_skillRequirements));

@override
String toString() {
  return 'ShipType(typeId: $typeId, name: $name, description: $description, groupId: $groupId, groupName: $groupName, raceName: $raceName, highSlots: $highSlots, medSlots: $medSlots, lowSlots: $lowSlots, rigSlots: $rigSlots, turretSlots: $turretSlots, launcherSlots: $launcherSlots, baseAttributes: $baseAttributes, bonuses: $bonuses, skillRequirements: $skillRequirements)';
}


}

/// @nodoc
abstract mixin class _$ShipTypeCopyWith<$Res> implements $ShipTypeCopyWith<$Res> {
  factory _$ShipTypeCopyWith(_ShipType value, $Res Function(_ShipType) _then) = __$ShipTypeCopyWithImpl;
@override @useResult
$Res call({
 int typeId, String name, String description, int groupId, String groupName, String raceName, int highSlots, int medSlots, int lowSlots, int rigSlots, int turretSlots, int launcherSlots, Map<int, double> baseAttributes, List<ShipBonus> bonuses, List<SkillRequirement> skillRequirements
});




}
/// @nodoc
class __$ShipTypeCopyWithImpl<$Res>
    implements _$ShipTypeCopyWith<$Res> {
  __$ShipTypeCopyWithImpl(this._self, this._then);

  final _ShipType _self;
  final $Res Function(_ShipType) _then;

/// Create a copy of ShipType
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? typeId = null,Object? name = null,Object? description = null,Object? groupId = null,Object? groupName = null,Object? raceName = null,Object? highSlots = null,Object? medSlots = null,Object? lowSlots = null,Object? rigSlots = null,Object? turretSlots = null,Object? launcherSlots = null,Object? baseAttributes = null,Object? bonuses = null,Object? skillRequirements = null,}) {
  return _then(_ShipType(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,raceName: null == raceName ? _self.raceName : raceName // ignore: cast_nullable_to_non_nullable
as String,highSlots: null == highSlots ? _self.highSlots : highSlots // ignore: cast_nullable_to_non_nullable
as int,medSlots: null == medSlots ? _self.medSlots : medSlots // ignore: cast_nullable_to_non_nullable
as int,lowSlots: null == lowSlots ? _self.lowSlots : lowSlots // ignore: cast_nullable_to_non_nullable
as int,rigSlots: null == rigSlots ? _self.rigSlots : rigSlots // ignore: cast_nullable_to_non_nullable
as int,turretSlots: null == turretSlots ? _self.turretSlots : turretSlots // ignore: cast_nullable_to_non_nullable
as int,launcherSlots: null == launcherSlots ? _self.launcherSlots : launcherSlots // ignore: cast_nullable_to_non_nullable
as int,baseAttributes: null == baseAttributes ? _self._baseAttributes : baseAttributes // ignore: cast_nullable_to_non_nullable
as Map<int, double>,bonuses: null == bonuses ? _self._bonuses : bonuses // ignore: cast_nullable_to_non_nullable
as List<ShipBonus>,skillRequirements: null == skillRequirements ? _self._skillRequirements : skillRequirements // ignore: cast_nullable_to_non_nullable
as List<SkillRequirement>,
  ));
}


}


/// @nodoc
mixin _$ShipBonus {

 int get skillTypeId; String get skillName; String get bonusText; double get bonusAmount; int get attributeId;
/// Create a copy of ShipBonus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShipBonusCopyWith<ShipBonus> get copyWith => _$ShipBonusCopyWithImpl<ShipBonus>(this as ShipBonus, _$identity);

  /// Serializes this ShipBonus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShipBonus&&(identical(other.skillTypeId, skillTypeId) || other.skillTypeId == skillTypeId)&&(identical(other.skillName, skillName) || other.skillName == skillName)&&(identical(other.bonusText, bonusText) || other.bonusText == bonusText)&&(identical(other.bonusAmount, bonusAmount) || other.bonusAmount == bonusAmount)&&(identical(other.attributeId, attributeId) || other.attributeId == attributeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillTypeId,skillName,bonusText,bonusAmount,attributeId);

@override
String toString() {
  return 'ShipBonus(skillTypeId: $skillTypeId, skillName: $skillName, bonusText: $bonusText, bonusAmount: $bonusAmount, attributeId: $attributeId)';
}


}

/// @nodoc
abstract mixin class $ShipBonusCopyWith<$Res>  {
  factory $ShipBonusCopyWith(ShipBonus value, $Res Function(ShipBonus) _then) = _$ShipBonusCopyWithImpl;
@useResult
$Res call({
 int skillTypeId, String skillName, String bonusText, double bonusAmount, int attributeId
});




}
/// @nodoc
class _$ShipBonusCopyWithImpl<$Res>
    implements $ShipBonusCopyWith<$Res> {
  _$ShipBonusCopyWithImpl(this._self, this._then);

  final ShipBonus _self;
  final $Res Function(ShipBonus) _then;

/// Create a copy of ShipBonus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? skillTypeId = null,Object? skillName = null,Object? bonusText = null,Object? bonusAmount = null,Object? attributeId = null,}) {
  return _then(_self.copyWith(
skillTypeId: null == skillTypeId ? _self.skillTypeId : skillTypeId // ignore: cast_nullable_to_non_nullable
as int,skillName: null == skillName ? _self.skillName : skillName // ignore: cast_nullable_to_non_nullable
as String,bonusText: null == bonusText ? _self.bonusText : bonusText // ignore: cast_nullable_to_non_nullable
as String,bonusAmount: null == bonusAmount ? _self.bonusAmount : bonusAmount // ignore: cast_nullable_to_non_nullable
as double,attributeId: null == attributeId ? _self.attributeId : attributeId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ShipBonus].
extension ShipBonusPatterns on ShipBonus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShipBonus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShipBonus() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShipBonus value)  $default,){
final _that = this;
switch (_that) {
case _ShipBonus():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShipBonus value)?  $default,){
final _that = this;
switch (_that) {
case _ShipBonus() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int skillTypeId,  String skillName,  String bonusText,  double bonusAmount,  int attributeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShipBonus() when $default != null:
return $default(_that.skillTypeId,_that.skillName,_that.bonusText,_that.bonusAmount,_that.attributeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int skillTypeId,  String skillName,  String bonusText,  double bonusAmount,  int attributeId)  $default,) {final _that = this;
switch (_that) {
case _ShipBonus():
return $default(_that.skillTypeId,_that.skillName,_that.bonusText,_that.bonusAmount,_that.attributeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int skillTypeId,  String skillName,  String bonusText,  double bonusAmount,  int attributeId)?  $default,) {final _that = this;
switch (_that) {
case _ShipBonus() when $default != null:
return $default(_that.skillTypeId,_that.skillName,_that.bonusText,_that.bonusAmount,_that.attributeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShipBonus implements ShipBonus {
  const _ShipBonus({required this.skillTypeId, required this.skillName, required this.bonusText, required this.bonusAmount, required this.attributeId});
  factory _ShipBonus.fromJson(Map<String, dynamic> json) => _$ShipBonusFromJson(json);

@override final  int skillTypeId;
@override final  String skillName;
@override final  String bonusText;
@override final  double bonusAmount;
@override final  int attributeId;

/// Create a copy of ShipBonus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShipBonusCopyWith<_ShipBonus> get copyWith => __$ShipBonusCopyWithImpl<_ShipBonus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShipBonusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShipBonus&&(identical(other.skillTypeId, skillTypeId) || other.skillTypeId == skillTypeId)&&(identical(other.skillName, skillName) || other.skillName == skillName)&&(identical(other.bonusText, bonusText) || other.bonusText == bonusText)&&(identical(other.bonusAmount, bonusAmount) || other.bonusAmount == bonusAmount)&&(identical(other.attributeId, attributeId) || other.attributeId == attributeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillTypeId,skillName,bonusText,bonusAmount,attributeId);

@override
String toString() {
  return 'ShipBonus(skillTypeId: $skillTypeId, skillName: $skillName, bonusText: $bonusText, bonusAmount: $bonusAmount, attributeId: $attributeId)';
}


}

/// @nodoc
abstract mixin class _$ShipBonusCopyWith<$Res> implements $ShipBonusCopyWith<$Res> {
  factory _$ShipBonusCopyWith(_ShipBonus value, $Res Function(_ShipBonus) _then) = __$ShipBonusCopyWithImpl;
@override @useResult
$Res call({
 int skillTypeId, String skillName, String bonusText, double bonusAmount, int attributeId
});




}
/// @nodoc
class __$ShipBonusCopyWithImpl<$Res>
    implements _$ShipBonusCopyWith<$Res> {
  __$ShipBonusCopyWithImpl(this._self, this._then);

  final _ShipBonus _self;
  final $Res Function(_ShipBonus) _then;

/// Create a copy of ShipBonus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? skillTypeId = null,Object? skillName = null,Object? bonusText = null,Object? bonusAmount = null,Object? attributeId = null,}) {
  return _then(_ShipBonus(
skillTypeId: null == skillTypeId ? _self.skillTypeId : skillTypeId // ignore: cast_nullable_to_non_nullable
as int,skillName: null == skillName ? _self.skillName : skillName // ignore: cast_nullable_to_non_nullable
as String,bonusText: null == bonusText ? _self.bonusText : bonusText // ignore: cast_nullable_to_non_nullable
as String,bonusAmount: null == bonusAmount ? _self.bonusAmount : bonusAmount // ignore: cast_nullable_to_non_nullable
as double,attributeId: null == attributeId ? _self.attributeId : attributeId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ModuleType {

 int get typeId; String get name; int get groupId; String get groupName; SlotType get slotType; int get metaLevel; int get techLevel; double get cpu; double get powergrid; int get calibration; Map<int, double> get baseAttributes; List<DogmaEffect> get effects; List<SkillRequirement> get skillRequirements; List<int> get acceptedChargeGroups;
/// Create a copy of ModuleType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModuleTypeCopyWith<ModuleType> get copyWith => _$ModuleTypeCopyWithImpl<ModuleType>(this as ModuleType, _$identity);

  /// Serializes this ModuleType to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModuleType&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.slotType, slotType) || other.slotType == slotType)&&(identical(other.metaLevel, metaLevel) || other.metaLevel == metaLevel)&&(identical(other.techLevel, techLevel) || other.techLevel == techLevel)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.powergrid, powergrid) || other.powergrid == powergrid)&&(identical(other.calibration, calibration) || other.calibration == calibration)&&const DeepCollectionEquality().equals(other.baseAttributes, baseAttributes)&&const DeepCollectionEquality().equals(other.effects, effects)&&const DeepCollectionEquality().equals(other.skillRequirements, skillRequirements)&&const DeepCollectionEquality().equals(other.acceptedChargeGroups, acceptedChargeGroups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,name,groupId,groupName,slotType,metaLevel,techLevel,cpu,powergrid,calibration,const DeepCollectionEquality().hash(baseAttributes),const DeepCollectionEquality().hash(effects),const DeepCollectionEquality().hash(skillRequirements),const DeepCollectionEquality().hash(acceptedChargeGroups));

@override
String toString() {
  return 'ModuleType(typeId: $typeId, name: $name, groupId: $groupId, groupName: $groupName, slotType: $slotType, metaLevel: $metaLevel, techLevel: $techLevel, cpu: $cpu, powergrid: $powergrid, calibration: $calibration, baseAttributes: $baseAttributes, effects: $effects, skillRequirements: $skillRequirements, acceptedChargeGroups: $acceptedChargeGroups)';
}


}

/// @nodoc
abstract mixin class $ModuleTypeCopyWith<$Res>  {
  factory $ModuleTypeCopyWith(ModuleType value, $Res Function(ModuleType) _then) = _$ModuleTypeCopyWithImpl;
@useResult
$Res call({
 int typeId, String name, int groupId, String groupName, SlotType slotType, int metaLevel, int techLevel, double cpu, double powergrid, int calibration, Map<int, double> baseAttributes, List<DogmaEffect> effects, List<SkillRequirement> skillRequirements, List<int> acceptedChargeGroups
});




}
/// @nodoc
class _$ModuleTypeCopyWithImpl<$Res>
    implements $ModuleTypeCopyWith<$Res> {
  _$ModuleTypeCopyWithImpl(this._self, this._then);

  final ModuleType _self;
  final $Res Function(ModuleType) _then;

/// Create a copy of ModuleType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? typeId = null,Object? name = null,Object? groupId = null,Object? groupName = null,Object? slotType = null,Object? metaLevel = null,Object? techLevel = null,Object? cpu = null,Object? powergrid = null,Object? calibration = null,Object? baseAttributes = null,Object? effects = null,Object? skillRequirements = null,Object? acceptedChargeGroups = null,}) {
  return _then(_self.copyWith(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,slotType: null == slotType ? _self.slotType : slotType // ignore: cast_nullable_to_non_nullable
as SlotType,metaLevel: null == metaLevel ? _self.metaLevel : metaLevel // ignore: cast_nullable_to_non_nullable
as int,techLevel: null == techLevel ? _self.techLevel : techLevel // ignore: cast_nullable_to_non_nullable
as int,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as double,powergrid: null == powergrid ? _self.powergrid : powergrid // ignore: cast_nullable_to_non_nullable
as double,calibration: null == calibration ? _self.calibration : calibration // ignore: cast_nullable_to_non_nullable
as int,baseAttributes: null == baseAttributes ? _self.baseAttributes : baseAttributes // ignore: cast_nullable_to_non_nullable
as Map<int, double>,effects: null == effects ? _self.effects : effects // ignore: cast_nullable_to_non_nullable
as List<DogmaEffect>,skillRequirements: null == skillRequirements ? _self.skillRequirements : skillRequirements // ignore: cast_nullable_to_non_nullable
as List<SkillRequirement>,acceptedChargeGroups: null == acceptedChargeGroups ? _self.acceptedChargeGroups : acceptedChargeGroups // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ModuleType].
extension ModuleTypePatterns on ModuleType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModuleType value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModuleType() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModuleType value)  $default,){
final _that = this;
switch (_that) {
case _ModuleType():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModuleType value)?  $default,){
final _that = this;
switch (_that) {
case _ModuleType() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int typeId,  String name,  int groupId,  String groupName,  SlotType slotType,  int metaLevel,  int techLevel,  double cpu,  double powergrid,  int calibration,  Map<int, double> baseAttributes,  List<DogmaEffect> effects,  List<SkillRequirement> skillRequirements,  List<int> acceptedChargeGroups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModuleType() when $default != null:
return $default(_that.typeId,_that.name,_that.groupId,_that.groupName,_that.slotType,_that.metaLevel,_that.techLevel,_that.cpu,_that.powergrid,_that.calibration,_that.baseAttributes,_that.effects,_that.skillRequirements,_that.acceptedChargeGroups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int typeId,  String name,  int groupId,  String groupName,  SlotType slotType,  int metaLevel,  int techLevel,  double cpu,  double powergrid,  int calibration,  Map<int, double> baseAttributes,  List<DogmaEffect> effects,  List<SkillRequirement> skillRequirements,  List<int> acceptedChargeGroups)  $default,) {final _that = this;
switch (_that) {
case _ModuleType():
return $default(_that.typeId,_that.name,_that.groupId,_that.groupName,_that.slotType,_that.metaLevel,_that.techLevel,_that.cpu,_that.powergrid,_that.calibration,_that.baseAttributes,_that.effects,_that.skillRequirements,_that.acceptedChargeGroups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int typeId,  String name,  int groupId,  String groupName,  SlotType slotType,  int metaLevel,  int techLevel,  double cpu,  double powergrid,  int calibration,  Map<int, double> baseAttributes,  List<DogmaEffect> effects,  List<SkillRequirement> skillRequirements,  List<int> acceptedChargeGroups)?  $default,) {final _that = this;
switch (_that) {
case _ModuleType() when $default != null:
return $default(_that.typeId,_that.name,_that.groupId,_that.groupName,_that.slotType,_that.metaLevel,_that.techLevel,_that.cpu,_that.powergrid,_that.calibration,_that.baseAttributes,_that.effects,_that.skillRequirements,_that.acceptedChargeGroups);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModuleType implements ModuleType {
  const _ModuleType({required this.typeId, required this.name, required this.groupId, required this.groupName, required this.slotType, this.metaLevel = 0, this.techLevel = 1, this.cpu = 0.0, this.powergrid = 0.0, this.calibration = 0, final  Map<int, double> baseAttributes = const {}, final  List<DogmaEffect> effects = const [], final  List<SkillRequirement> skillRequirements = const [], final  List<int> acceptedChargeGroups = const []}): _baseAttributes = baseAttributes,_effects = effects,_skillRequirements = skillRequirements,_acceptedChargeGroups = acceptedChargeGroups;
  factory _ModuleType.fromJson(Map<String, dynamic> json) => _$ModuleTypeFromJson(json);

@override final  int typeId;
@override final  String name;
@override final  int groupId;
@override final  String groupName;
@override final  SlotType slotType;
@override@JsonKey() final  int metaLevel;
@override@JsonKey() final  int techLevel;
@override@JsonKey() final  double cpu;
@override@JsonKey() final  double powergrid;
@override@JsonKey() final  int calibration;
 final  Map<int, double> _baseAttributes;
@override@JsonKey() Map<int, double> get baseAttributes {
  if (_baseAttributes is EqualUnmodifiableMapView) return _baseAttributes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_baseAttributes);
}

 final  List<DogmaEffect> _effects;
@override@JsonKey() List<DogmaEffect> get effects {
  if (_effects is EqualUnmodifiableListView) return _effects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_effects);
}

 final  List<SkillRequirement> _skillRequirements;
@override@JsonKey() List<SkillRequirement> get skillRequirements {
  if (_skillRequirements is EqualUnmodifiableListView) return _skillRequirements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_skillRequirements);
}

 final  List<int> _acceptedChargeGroups;
@override@JsonKey() List<int> get acceptedChargeGroups {
  if (_acceptedChargeGroups is EqualUnmodifiableListView) return _acceptedChargeGroups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_acceptedChargeGroups);
}


/// Create a copy of ModuleType
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModuleTypeCopyWith<_ModuleType> get copyWith => __$ModuleTypeCopyWithImpl<_ModuleType>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModuleTypeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModuleType&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.slotType, slotType) || other.slotType == slotType)&&(identical(other.metaLevel, metaLevel) || other.metaLevel == metaLevel)&&(identical(other.techLevel, techLevel) || other.techLevel == techLevel)&&(identical(other.cpu, cpu) || other.cpu == cpu)&&(identical(other.powergrid, powergrid) || other.powergrid == powergrid)&&(identical(other.calibration, calibration) || other.calibration == calibration)&&const DeepCollectionEquality().equals(other._baseAttributes, _baseAttributes)&&const DeepCollectionEquality().equals(other._effects, _effects)&&const DeepCollectionEquality().equals(other._skillRequirements, _skillRequirements)&&const DeepCollectionEquality().equals(other._acceptedChargeGroups, _acceptedChargeGroups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,typeId,name,groupId,groupName,slotType,metaLevel,techLevel,cpu,powergrid,calibration,const DeepCollectionEquality().hash(_baseAttributes),const DeepCollectionEquality().hash(_effects),const DeepCollectionEquality().hash(_skillRequirements),const DeepCollectionEquality().hash(_acceptedChargeGroups));

@override
String toString() {
  return 'ModuleType(typeId: $typeId, name: $name, groupId: $groupId, groupName: $groupName, slotType: $slotType, metaLevel: $metaLevel, techLevel: $techLevel, cpu: $cpu, powergrid: $powergrid, calibration: $calibration, baseAttributes: $baseAttributes, effects: $effects, skillRequirements: $skillRequirements, acceptedChargeGroups: $acceptedChargeGroups)';
}


}

/// @nodoc
abstract mixin class _$ModuleTypeCopyWith<$Res> implements $ModuleTypeCopyWith<$Res> {
  factory _$ModuleTypeCopyWith(_ModuleType value, $Res Function(_ModuleType) _then) = __$ModuleTypeCopyWithImpl;
@override @useResult
$Res call({
 int typeId, String name, int groupId, String groupName, SlotType slotType, int metaLevel, int techLevel, double cpu, double powergrid, int calibration, Map<int, double> baseAttributes, List<DogmaEffect> effects, List<SkillRequirement> skillRequirements, List<int> acceptedChargeGroups
});




}
/// @nodoc
class __$ModuleTypeCopyWithImpl<$Res>
    implements _$ModuleTypeCopyWith<$Res> {
  __$ModuleTypeCopyWithImpl(this._self, this._then);

  final _ModuleType _self;
  final $Res Function(_ModuleType) _then;

/// Create a copy of ModuleType
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? typeId = null,Object? name = null,Object? groupId = null,Object? groupName = null,Object? slotType = null,Object? metaLevel = null,Object? techLevel = null,Object? cpu = null,Object? powergrid = null,Object? calibration = null,Object? baseAttributes = null,Object? effects = null,Object? skillRequirements = null,Object? acceptedChargeGroups = null,}) {
  return _then(_ModuleType(
typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,slotType: null == slotType ? _self.slotType : slotType // ignore: cast_nullable_to_non_nullable
as SlotType,metaLevel: null == metaLevel ? _self.metaLevel : metaLevel // ignore: cast_nullable_to_non_nullable
as int,techLevel: null == techLevel ? _self.techLevel : techLevel // ignore: cast_nullable_to_non_nullable
as int,cpu: null == cpu ? _self.cpu : cpu // ignore: cast_nullable_to_non_nullable
as double,powergrid: null == powergrid ? _self.powergrid : powergrid // ignore: cast_nullable_to_non_nullable
as double,calibration: null == calibration ? _self.calibration : calibration // ignore: cast_nullable_to_non_nullable
as int,baseAttributes: null == baseAttributes ? _self._baseAttributes : baseAttributes // ignore: cast_nullable_to_non_nullable
as Map<int, double>,effects: null == effects ? _self._effects : effects // ignore: cast_nullable_to_non_nullable
as List<DogmaEffect>,skillRequirements: null == skillRequirements ? _self._skillRequirements : skillRequirements // ignore: cast_nullable_to_non_nullable
as List<SkillRequirement>,acceptedChargeGroups: null == acceptedChargeGroups ? _self._acceptedChargeGroups : acceptedChargeGroups // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}


/// @nodoc
mixin _$DogmaEffect {

 int get effectId; String get name; bool get isOffensive; bool get isAssistance;
/// Create a copy of DogmaEffect
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DogmaEffectCopyWith<DogmaEffect> get copyWith => _$DogmaEffectCopyWithImpl<DogmaEffect>(this as DogmaEffect, _$identity);

  /// Serializes this DogmaEffect to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DogmaEffect&&(identical(other.effectId, effectId) || other.effectId == effectId)&&(identical(other.name, name) || other.name == name)&&(identical(other.isOffensive, isOffensive) || other.isOffensive == isOffensive)&&(identical(other.isAssistance, isAssistance) || other.isAssistance == isAssistance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,effectId,name,isOffensive,isAssistance);

@override
String toString() {
  return 'DogmaEffect(effectId: $effectId, name: $name, isOffensive: $isOffensive, isAssistance: $isAssistance)';
}


}

/// @nodoc
abstract mixin class $DogmaEffectCopyWith<$Res>  {
  factory $DogmaEffectCopyWith(DogmaEffect value, $Res Function(DogmaEffect) _then) = _$DogmaEffectCopyWithImpl;
@useResult
$Res call({
 int effectId, String name, bool isOffensive, bool isAssistance
});




}
/// @nodoc
class _$DogmaEffectCopyWithImpl<$Res>
    implements $DogmaEffectCopyWith<$Res> {
  _$DogmaEffectCopyWithImpl(this._self, this._then);

  final DogmaEffect _self;
  final $Res Function(DogmaEffect) _then;

/// Create a copy of DogmaEffect
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? effectId = null,Object? name = null,Object? isOffensive = null,Object? isAssistance = null,}) {
  return _then(_self.copyWith(
effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isOffensive: null == isOffensive ? _self.isOffensive : isOffensive // ignore: cast_nullable_to_non_nullable
as bool,isAssistance: null == isAssistance ? _self.isAssistance : isAssistance // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DogmaEffect].
extension DogmaEffectPatterns on DogmaEffect {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DogmaEffect value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DogmaEffect() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DogmaEffect value)  $default,){
final _that = this;
switch (_that) {
case _DogmaEffect():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DogmaEffect value)?  $default,){
final _that = this;
switch (_that) {
case _DogmaEffect() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int effectId,  String name,  bool isOffensive,  bool isAssistance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DogmaEffect() when $default != null:
return $default(_that.effectId,_that.name,_that.isOffensive,_that.isAssistance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int effectId,  String name,  bool isOffensive,  bool isAssistance)  $default,) {final _that = this;
switch (_that) {
case _DogmaEffect():
return $default(_that.effectId,_that.name,_that.isOffensive,_that.isAssistance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int effectId,  String name,  bool isOffensive,  bool isAssistance)?  $default,) {final _that = this;
switch (_that) {
case _DogmaEffect() when $default != null:
return $default(_that.effectId,_that.name,_that.isOffensive,_that.isAssistance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DogmaEffect implements DogmaEffect {
  const _DogmaEffect({required this.effectId, required this.name, this.isOffensive = false, this.isAssistance = false});
  factory _DogmaEffect.fromJson(Map<String, dynamic> json) => _$DogmaEffectFromJson(json);

@override final  int effectId;
@override final  String name;
@override@JsonKey() final  bool isOffensive;
@override@JsonKey() final  bool isAssistance;

/// Create a copy of DogmaEffect
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DogmaEffectCopyWith<_DogmaEffect> get copyWith => __$DogmaEffectCopyWithImpl<_DogmaEffect>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DogmaEffectToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DogmaEffect&&(identical(other.effectId, effectId) || other.effectId == effectId)&&(identical(other.name, name) || other.name == name)&&(identical(other.isOffensive, isOffensive) || other.isOffensive == isOffensive)&&(identical(other.isAssistance, isAssistance) || other.isAssistance == isAssistance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,effectId,name,isOffensive,isAssistance);

@override
String toString() {
  return 'DogmaEffect(effectId: $effectId, name: $name, isOffensive: $isOffensive, isAssistance: $isAssistance)';
}


}

/// @nodoc
abstract mixin class _$DogmaEffectCopyWith<$Res> implements $DogmaEffectCopyWith<$Res> {
  factory _$DogmaEffectCopyWith(_DogmaEffect value, $Res Function(_DogmaEffect) _then) = __$DogmaEffectCopyWithImpl;
@override @useResult
$Res call({
 int effectId, String name, bool isOffensive, bool isAssistance
});




}
/// @nodoc
class __$DogmaEffectCopyWithImpl<$Res>
    implements _$DogmaEffectCopyWith<$Res> {
  __$DogmaEffectCopyWithImpl(this._self, this._then);

  final _DogmaEffect _self;
  final $Res Function(_DogmaEffect) _then;

/// Create a copy of DogmaEffect
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? effectId = null,Object? name = null,Object? isOffensive = null,Object? isAssistance = null,}) {
  return _then(_DogmaEffect(
effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isOffensive: null == isOffensive ? _self.isOffensive : isOffensive // ignore: cast_nullable_to_non_nullable
as bool,isAssistance: null == isAssistance ? _self.isAssistance : isAssistance // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SkillRequirement {

 int get skillTypeId; String get skillName; int get requiredLevel;
/// Create a copy of SkillRequirement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillRequirementCopyWith<SkillRequirement> get copyWith => _$SkillRequirementCopyWithImpl<SkillRequirement>(this as SkillRequirement, _$identity);

  /// Serializes this SkillRequirement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillRequirement&&(identical(other.skillTypeId, skillTypeId) || other.skillTypeId == skillTypeId)&&(identical(other.skillName, skillName) || other.skillName == skillName)&&(identical(other.requiredLevel, requiredLevel) || other.requiredLevel == requiredLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillTypeId,skillName,requiredLevel);

@override
String toString() {
  return 'SkillRequirement(skillTypeId: $skillTypeId, skillName: $skillName, requiredLevel: $requiredLevel)';
}


}

/// @nodoc
abstract mixin class $SkillRequirementCopyWith<$Res>  {
  factory $SkillRequirementCopyWith(SkillRequirement value, $Res Function(SkillRequirement) _then) = _$SkillRequirementCopyWithImpl;
@useResult
$Res call({
 int skillTypeId, String skillName, int requiredLevel
});




}
/// @nodoc
class _$SkillRequirementCopyWithImpl<$Res>
    implements $SkillRequirementCopyWith<$Res> {
  _$SkillRequirementCopyWithImpl(this._self, this._then);

  final SkillRequirement _self;
  final $Res Function(SkillRequirement) _then;

/// Create a copy of SkillRequirement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? skillTypeId = null,Object? skillName = null,Object? requiredLevel = null,}) {
  return _then(_self.copyWith(
skillTypeId: null == skillTypeId ? _self.skillTypeId : skillTypeId // ignore: cast_nullable_to_non_nullable
as int,skillName: null == skillName ? _self.skillName : skillName // ignore: cast_nullable_to_non_nullable
as String,requiredLevel: null == requiredLevel ? _self.requiredLevel : requiredLevel // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillRequirement].
extension SkillRequirementPatterns on SkillRequirement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillRequirement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillRequirement() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillRequirement value)  $default,){
final _that = this;
switch (_that) {
case _SkillRequirement():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillRequirement value)?  $default,){
final _that = this;
switch (_that) {
case _SkillRequirement() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int skillTypeId,  String skillName,  int requiredLevel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillRequirement() when $default != null:
return $default(_that.skillTypeId,_that.skillName,_that.requiredLevel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int skillTypeId,  String skillName,  int requiredLevel)  $default,) {final _that = this;
switch (_that) {
case _SkillRequirement():
return $default(_that.skillTypeId,_that.skillName,_that.requiredLevel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int skillTypeId,  String skillName,  int requiredLevel)?  $default,) {final _that = this;
switch (_that) {
case _SkillRequirement() when $default != null:
return $default(_that.skillTypeId,_that.skillName,_that.requiredLevel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillRequirement implements SkillRequirement {
  const _SkillRequirement({required this.skillTypeId, required this.skillName, required this.requiredLevel});
  factory _SkillRequirement.fromJson(Map<String, dynamic> json) => _$SkillRequirementFromJson(json);

@override final  int skillTypeId;
@override final  String skillName;
@override final  int requiredLevel;

/// Create a copy of SkillRequirement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillRequirementCopyWith<_SkillRequirement> get copyWith => __$SkillRequirementCopyWithImpl<_SkillRequirement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillRequirementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillRequirement&&(identical(other.skillTypeId, skillTypeId) || other.skillTypeId == skillTypeId)&&(identical(other.skillName, skillName) || other.skillName == skillName)&&(identical(other.requiredLevel, requiredLevel) || other.requiredLevel == requiredLevel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillTypeId,skillName,requiredLevel);

@override
String toString() {
  return 'SkillRequirement(skillTypeId: $skillTypeId, skillName: $skillName, requiredLevel: $requiredLevel)';
}


}

/// @nodoc
abstract mixin class _$SkillRequirementCopyWith<$Res> implements $SkillRequirementCopyWith<$Res> {
  factory _$SkillRequirementCopyWith(_SkillRequirement value, $Res Function(_SkillRequirement) _then) = __$SkillRequirementCopyWithImpl;
@override @useResult
$Res call({
 int skillTypeId, String skillName, int requiredLevel
});




}
/// @nodoc
class __$SkillRequirementCopyWithImpl<$Res>
    implements _$SkillRequirementCopyWith<$Res> {
  __$SkillRequirementCopyWithImpl(this._self, this._then);

  final _SkillRequirement _self;
  final $Res Function(_SkillRequirement) _then;

/// Create a copy of SkillRequirement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? skillTypeId = null,Object? skillName = null,Object? requiredLevel = null,}) {
  return _then(_SkillRequirement(
skillTypeId: null == skillTypeId ? _self.skillTypeId : skillTypeId // ignore: cast_nullable_to_non_nullable
as int,skillName: null == skillName ? _self.skillName : skillName // ignore: cast_nullable_to_non_nullable
as String,requiredLevel: null == requiredLevel ? _self.requiredLevel : requiredLevel // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CharacterSkill {

 int get skillId; int get level;
/// Create a copy of CharacterSkill
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CharacterSkillCopyWith<CharacterSkill> get copyWith => _$CharacterSkillCopyWithImpl<CharacterSkill>(this as CharacterSkill, _$identity);

  /// Serializes this CharacterSkill to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CharacterSkill&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.level, level) || other.level == level));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillId,level);

@override
String toString() {
  return 'CharacterSkill(skillId: $skillId, level: $level)';
}


}

/// @nodoc
abstract mixin class $CharacterSkillCopyWith<$Res>  {
  factory $CharacterSkillCopyWith(CharacterSkill value, $Res Function(CharacterSkill) _then) = _$CharacterSkillCopyWithImpl;
@useResult
$Res call({
 int skillId, int level
});




}
/// @nodoc
class _$CharacterSkillCopyWithImpl<$Res>
    implements $CharacterSkillCopyWith<$Res> {
  _$CharacterSkillCopyWithImpl(this._self, this._then);

  final CharacterSkill _self;
  final $Res Function(CharacterSkill) _then;

/// Create a copy of CharacterSkill
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? skillId = null,Object? level = null,}) {
  return _then(_self.copyWith(
skillId: null == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CharacterSkill].
extension CharacterSkillPatterns on CharacterSkill {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CharacterSkill value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CharacterSkill() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CharacterSkill value)  $default,){
final _that = this;
switch (_that) {
case _CharacterSkill():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CharacterSkill value)?  $default,){
final _that = this;
switch (_that) {
case _CharacterSkill() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int skillId,  int level)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CharacterSkill() when $default != null:
return $default(_that.skillId,_that.level);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int skillId,  int level)  $default,) {final _that = this;
switch (_that) {
case _CharacterSkill():
return $default(_that.skillId,_that.level);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int skillId,  int level)?  $default,) {final _that = this;
switch (_that) {
case _CharacterSkill() when $default != null:
return $default(_that.skillId,_that.level);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CharacterSkill implements CharacterSkill {
  const _CharacterSkill({required this.skillId, required this.level});
  factory _CharacterSkill.fromJson(Map<String, dynamic> json) => _$CharacterSkillFromJson(json);

@override final  int skillId;
@override final  int level;

/// Create a copy of CharacterSkill
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CharacterSkillCopyWith<_CharacterSkill> get copyWith => __$CharacterSkillCopyWithImpl<_CharacterSkill>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CharacterSkillToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CharacterSkill&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.level, level) || other.level == level));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillId,level);

@override
String toString() {
  return 'CharacterSkill(skillId: $skillId, level: $level)';
}


}

/// @nodoc
abstract mixin class _$CharacterSkillCopyWith<$Res> implements $CharacterSkillCopyWith<$Res> {
  factory _$CharacterSkillCopyWith(_CharacterSkill value, $Res Function(_CharacterSkill) _then) = __$CharacterSkillCopyWithImpl;
@override @useResult
$Res call({
 int skillId, int level
});




}
/// @nodoc
class __$CharacterSkillCopyWithImpl<$Res>
    implements _$CharacterSkillCopyWith<$Res> {
  __$CharacterSkillCopyWithImpl(this._self, this._then);

  final _CharacterSkill _self;
  final $Res Function(_CharacterSkill) _then;

/// Create a copy of CharacterSkill
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? skillId = null,Object? level = null,}) {
  return _then(_CharacterSkill(
skillId: null == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
