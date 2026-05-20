// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thera_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TheraConnection {

 String get id;@JsonKey(name: 'wh_type') String get whType;@JsonKey(name: 'max_ship_size') String get maxShipSize;@JsonKey(name: 'expires_at') DateTime get expiresAt;@JsonKey(name: 'remaining_hours') int get remainingHours;@JsonKey(name: 'out_system_id') int get outSystemId;@JsonKey(name: 'out_system_name') String get outSystemName;@JsonKey(name: 'out_signature') String get outSignature;@JsonKey(name: 'in_system_id') int get inSystemId;@JsonKey(name: 'in_system_class') String get inSystemClass;@JsonKey(name: 'in_system_name') String get inSystemName;@JsonKey(name: 'in_region_id') int get inRegionId;@JsonKey(name: 'in_region_name') String get inRegionName;@JsonKey(name: 'in_signature') String get inSignature;
/// Create a copy of TheraConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TheraConnectionCopyWith<TheraConnection> get copyWith => _$TheraConnectionCopyWithImpl<TheraConnection>(this as TheraConnection, _$identity);

  /// Serializes this TheraConnection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TheraConnection&&(identical(other.id, id) || other.id == id)&&(identical(other.whType, whType) || other.whType == whType)&&(identical(other.maxShipSize, maxShipSize) || other.maxShipSize == maxShipSize)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.remainingHours, remainingHours) || other.remainingHours == remainingHours)&&(identical(other.outSystemId, outSystemId) || other.outSystemId == outSystemId)&&(identical(other.outSystemName, outSystemName) || other.outSystemName == outSystemName)&&(identical(other.outSignature, outSignature) || other.outSignature == outSignature)&&(identical(other.inSystemId, inSystemId) || other.inSystemId == inSystemId)&&(identical(other.inSystemClass, inSystemClass) || other.inSystemClass == inSystemClass)&&(identical(other.inSystemName, inSystemName) || other.inSystemName == inSystemName)&&(identical(other.inRegionId, inRegionId) || other.inRegionId == inRegionId)&&(identical(other.inRegionName, inRegionName) || other.inRegionName == inRegionName)&&(identical(other.inSignature, inSignature) || other.inSignature == inSignature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,whType,maxShipSize,expiresAt,remainingHours,outSystemId,outSystemName,outSignature,inSystemId,inSystemClass,inSystemName,inRegionId,inRegionName,inSignature);

@override
String toString() {
  return 'TheraConnection(id: $id, whType: $whType, maxShipSize: $maxShipSize, expiresAt: $expiresAt, remainingHours: $remainingHours, outSystemId: $outSystemId, outSystemName: $outSystemName, outSignature: $outSignature, inSystemId: $inSystemId, inSystemClass: $inSystemClass, inSystemName: $inSystemName, inRegionId: $inRegionId, inRegionName: $inRegionName, inSignature: $inSignature)';
}


}

/// @nodoc
abstract mixin class $TheraConnectionCopyWith<$Res>  {
  factory $TheraConnectionCopyWith(TheraConnection value, $Res Function(TheraConnection) _then) = _$TheraConnectionCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'wh_type') String whType,@JsonKey(name: 'max_ship_size') String maxShipSize,@JsonKey(name: 'expires_at') DateTime expiresAt,@JsonKey(name: 'remaining_hours') int remainingHours,@JsonKey(name: 'out_system_id') int outSystemId,@JsonKey(name: 'out_system_name') String outSystemName,@JsonKey(name: 'out_signature') String outSignature,@JsonKey(name: 'in_system_id') int inSystemId,@JsonKey(name: 'in_system_class') String inSystemClass,@JsonKey(name: 'in_system_name') String inSystemName,@JsonKey(name: 'in_region_id') int inRegionId,@JsonKey(name: 'in_region_name') String inRegionName,@JsonKey(name: 'in_signature') String inSignature
});




}
/// @nodoc
class _$TheraConnectionCopyWithImpl<$Res>
    implements $TheraConnectionCopyWith<$Res> {
  _$TheraConnectionCopyWithImpl(this._self, this._then);

  final TheraConnection _self;
  final $Res Function(TheraConnection) _then;

/// Create a copy of TheraConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? whType = null,Object? maxShipSize = null,Object? expiresAt = null,Object? remainingHours = null,Object? outSystemId = null,Object? outSystemName = null,Object? outSignature = null,Object? inSystemId = null,Object? inSystemClass = null,Object? inSystemName = null,Object? inRegionId = null,Object? inRegionName = null,Object? inSignature = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,whType: null == whType ? _self.whType : whType // ignore: cast_nullable_to_non_nullable
as String,maxShipSize: null == maxShipSize ? _self.maxShipSize : maxShipSize // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,remainingHours: null == remainingHours ? _self.remainingHours : remainingHours // ignore: cast_nullable_to_non_nullable
as int,outSystemId: null == outSystemId ? _self.outSystemId : outSystemId // ignore: cast_nullable_to_non_nullable
as int,outSystemName: null == outSystemName ? _self.outSystemName : outSystemName // ignore: cast_nullable_to_non_nullable
as String,outSignature: null == outSignature ? _self.outSignature : outSignature // ignore: cast_nullable_to_non_nullable
as String,inSystemId: null == inSystemId ? _self.inSystemId : inSystemId // ignore: cast_nullable_to_non_nullable
as int,inSystemClass: null == inSystemClass ? _self.inSystemClass : inSystemClass // ignore: cast_nullable_to_non_nullable
as String,inSystemName: null == inSystemName ? _self.inSystemName : inSystemName // ignore: cast_nullable_to_non_nullable
as String,inRegionId: null == inRegionId ? _self.inRegionId : inRegionId // ignore: cast_nullable_to_non_nullable
as int,inRegionName: null == inRegionName ? _self.inRegionName : inRegionName // ignore: cast_nullable_to_non_nullable
as String,inSignature: null == inSignature ? _self.inSignature : inSignature // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TheraConnection].
extension TheraConnectionPatterns on TheraConnection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TheraConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TheraConnection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TheraConnection value)  $default,){
final _that = this;
switch (_that) {
case _TheraConnection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TheraConnection value)?  $default,){
final _that = this;
switch (_that) {
case _TheraConnection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'wh_type')  String whType, @JsonKey(name: 'max_ship_size')  String maxShipSize, @JsonKey(name: 'expires_at')  DateTime expiresAt, @JsonKey(name: 'remaining_hours')  int remainingHours, @JsonKey(name: 'out_system_id')  int outSystemId, @JsonKey(name: 'out_system_name')  String outSystemName, @JsonKey(name: 'out_signature')  String outSignature, @JsonKey(name: 'in_system_id')  int inSystemId, @JsonKey(name: 'in_system_class')  String inSystemClass, @JsonKey(name: 'in_system_name')  String inSystemName, @JsonKey(name: 'in_region_id')  int inRegionId, @JsonKey(name: 'in_region_name')  String inRegionName, @JsonKey(name: 'in_signature')  String inSignature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TheraConnection() when $default != null:
return $default(_that.id,_that.whType,_that.maxShipSize,_that.expiresAt,_that.remainingHours,_that.outSystemId,_that.outSystemName,_that.outSignature,_that.inSystemId,_that.inSystemClass,_that.inSystemName,_that.inRegionId,_that.inRegionName,_that.inSignature);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'wh_type')  String whType, @JsonKey(name: 'max_ship_size')  String maxShipSize, @JsonKey(name: 'expires_at')  DateTime expiresAt, @JsonKey(name: 'remaining_hours')  int remainingHours, @JsonKey(name: 'out_system_id')  int outSystemId, @JsonKey(name: 'out_system_name')  String outSystemName, @JsonKey(name: 'out_signature')  String outSignature, @JsonKey(name: 'in_system_id')  int inSystemId, @JsonKey(name: 'in_system_class')  String inSystemClass, @JsonKey(name: 'in_system_name')  String inSystemName, @JsonKey(name: 'in_region_id')  int inRegionId, @JsonKey(name: 'in_region_name')  String inRegionName, @JsonKey(name: 'in_signature')  String inSignature)  $default,) {final _that = this;
switch (_that) {
case _TheraConnection():
return $default(_that.id,_that.whType,_that.maxShipSize,_that.expiresAt,_that.remainingHours,_that.outSystemId,_that.outSystemName,_that.outSignature,_that.inSystemId,_that.inSystemClass,_that.inSystemName,_that.inRegionId,_that.inRegionName,_that.inSignature);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'wh_type')  String whType, @JsonKey(name: 'max_ship_size')  String maxShipSize, @JsonKey(name: 'expires_at')  DateTime expiresAt, @JsonKey(name: 'remaining_hours')  int remainingHours, @JsonKey(name: 'out_system_id')  int outSystemId, @JsonKey(name: 'out_system_name')  String outSystemName, @JsonKey(name: 'out_signature')  String outSignature, @JsonKey(name: 'in_system_id')  int inSystemId, @JsonKey(name: 'in_system_class')  String inSystemClass, @JsonKey(name: 'in_system_name')  String inSystemName, @JsonKey(name: 'in_region_id')  int inRegionId, @JsonKey(name: 'in_region_name')  String inRegionName, @JsonKey(name: 'in_signature')  String inSignature)?  $default,) {final _that = this;
switch (_that) {
case _TheraConnection() when $default != null:
return $default(_that.id,_that.whType,_that.maxShipSize,_that.expiresAt,_that.remainingHours,_that.outSystemId,_that.outSystemName,_that.outSignature,_that.inSystemId,_that.inSystemClass,_that.inSystemName,_that.inRegionId,_that.inRegionName,_that.inSignature);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TheraConnection implements TheraConnection {
  const _TheraConnection({required this.id, @JsonKey(name: 'wh_type') required this.whType, @JsonKey(name: 'max_ship_size') required this.maxShipSize, @JsonKey(name: 'expires_at') required this.expiresAt, @JsonKey(name: 'remaining_hours') required this.remainingHours, @JsonKey(name: 'out_system_id') required this.outSystemId, @JsonKey(name: 'out_system_name') required this.outSystemName, @JsonKey(name: 'out_signature') required this.outSignature, @JsonKey(name: 'in_system_id') required this.inSystemId, @JsonKey(name: 'in_system_class') required this.inSystemClass, @JsonKey(name: 'in_system_name') required this.inSystemName, @JsonKey(name: 'in_region_id') required this.inRegionId, @JsonKey(name: 'in_region_name') required this.inRegionName, @JsonKey(name: 'in_signature') required this.inSignature});
  factory _TheraConnection.fromJson(Map<String, dynamic> json) => _$TheraConnectionFromJson(json);

@override final  String id;
@override@JsonKey(name: 'wh_type') final  String whType;
@override@JsonKey(name: 'max_ship_size') final  String maxShipSize;
@override@JsonKey(name: 'expires_at') final  DateTime expiresAt;
@override@JsonKey(name: 'remaining_hours') final  int remainingHours;
@override@JsonKey(name: 'out_system_id') final  int outSystemId;
@override@JsonKey(name: 'out_system_name') final  String outSystemName;
@override@JsonKey(name: 'out_signature') final  String outSignature;
@override@JsonKey(name: 'in_system_id') final  int inSystemId;
@override@JsonKey(name: 'in_system_class') final  String inSystemClass;
@override@JsonKey(name: 'in_system_name') final  String inSystemName;
@override@JsonKey(name: 'in_region_id') final  int inRegionId;
@override@JsonKey(name: 'in_region_name') final  String inRegionName;
@override@JsonKey(name: 'in_signature') final  String inSignature;

/// Create a copy of TheraConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TheraConnectionCopyWith<_TheraConnection> get copyWith => __$TheraConnectionCopyWithImpl<_TheraConnection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TheraConnectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TheraConnection&&(identical(other.id, id) || other.id == id)&&(identical(other.whType, whType) || other.whType == whType)&&(identical(other.maxShipSize, maxShipSize) || other.maxShipSize == maxShipSize)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.remainingHours, remainingHours) || other.remainingHours == remainingHours)&&(identical(other.outSystemId, outSystemId) || other.outSystemId == outSystemId)&&(identical(other.outSystemName, outSystemName) || other.outSystemName == outSystemName)&&(identical(other.outSignature, outSignature) || other.outSignature == outSignature)&&(identical(other.inSystemId, inSystemId) || other.inSystemId == inSystemId)&&(identical(other.inSystemClass, inSystemClass) || other.inSystemClass == inSystemClass)&&(identical(other.inSystemName, inSystemName) || other.inSystemName == inSystemName)&&(identical(other.inRegionId, inRegionId) || other.inRegionId == inRegionId)&&(identical(other.inRegionName, inRegionName) || other.inRegionName == inRegionName)&&(identical(other.inSignature, inSignature) || other.inSignature == inSignature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,whType,maxShipSize,expiresAt,remainingHours,outSystemId,outSystemName,outSignature,inSystemId,inSystemClass,inSystemName,inRegionId,inRegionName,inSignature);

@override
String toString() {
  return 'TheraConnection(id: $id, whType: $whType, maxShipSize: $maxShipSize, expiresAt: $expiresAt, remainingHours: $remainingHours, outSystemId: $outSystemId, outSystemName: $outSystemName, outSignature: $outSignature, inSystemId: $inSystemId, inSystemClass: $inSystemClass, inSystemName: $inSystemName, inRegionId: $inRegionId, inRegionName: $inRegionName, inSignature: $inSignature)';
}


}

/// @nodoc
abstract mixin class _$TheraConnectionCopyWith<$Res> implements $TheraConnectionCopyWith<$Res> {
  factory _$TheraConnectionCopyWith(_TheraConnection value, $Res Function(_TheraConnection) _then) = __$TheraConnectionCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'wh_type') String whType,@JsonKey(name: 'max_ship_size') String maxShipSize,@JsonKey(name: 'expires_at') DateTime expiresAt,@JsonKey(name: 'remaining_hours') int remainingHours,@JsonKey(name: 'out_system_id') int outSystemId,@JsonKey(name: 'out_system_name') String outSystemName,@JsonKey(name: 'out_signature') String outSignature,@JsonKey(name: 'in_system_id') int inSystemId,@JsonKey(name: 'in_system_class') String inSystemClass,@JsonKey(name: 'in_system_name') String inSystemName,@JsonKey(name: 'in_region_id') int inRegionId,@JsonKey(name: 'in_region_name') String inRegionName,@JsonKey(name: 'in_signature') String inSignature
});




}
/// @nodoc
class __$TheraConnectionCopyWithImpl<$Res>
    implements _$TheraConnectionCopyWith<$Res> {
  __$TheraConnectionCopyWithImpl(this._self, this._then);

  final _TheraConnection _self;
  final $Res Function(_TheraConnection) _then;

/// Create a copy of TheraConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? whType = null,Object? maxShipSize = null,Object? expiresAt = null,Object? remainingHours = null,Object? outSystemId = null,Object? outSystemName = null,Object? outSignature = null,Object? inSystemId = null,Object? inSystemClass = null,Object? inSystemName = null,Object? inRegionId = null,Object? inRegionName = null,Object? inSignature = null,}) {
  return _then(_TheraConnection(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,whType: null == whType ? _self.whType : whType // ignore: cast_nullable_to_non_nullable
as String,maxShipSize: null == maxShipSize ? _self.maxShipSize : maxShipSize // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,remainingHours: null == remainingHours ? _self.remainingHours : remainingHours // ignore: cast_nullable_to_non_nullable
as int,outSystemId: null == outSystemId ? _self.outSystemId : outSystemId // ignore: cast_nullable_to_non_nullable
as int,outSystemName: null == outSystemName ? _self.outSystemName : outSystemName // ignore: cast_nullable_to_non_nullable
as String,outSignature: null == outSignature ? _self.outSignature : outSignature // ignore: cast_nullable_to_non_nullable
as String,inSystemId: null == inSystemId ? _self.inSystemId : inSystemId // ignore: cast_nullable_to_non_nullable
as int,inSystemClass: null == inSystemClass ? _self.inSystemClass : inSystemClass // ignore: cast_nullable_to_non_nullable
as String,inSystemName: null == inSystemName ? _self.inSystemName : inSystemName // ignore: cast_nullable_to_non_nullable
as String,inRegionId: null == inRegionId ? _self.inRegionId : inRegionId // ignore: cast_nullable_to_non_nullable
as int,inRegionName: null == inRegionName ? _self.inRegionName : inRegionName // ignore: cast_nullable_to_non_nullable
as String,inSignature: null == inSignature ? _self.inSignature : inSignature // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
