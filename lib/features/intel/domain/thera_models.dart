// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'thera_models.freezed.dart';
part 'thera_models.g.dart';

@freezed
abstract class TheraConnection with _$TheraConnection {
  const factory TheraConnection({
    required String id,
    @JsonKey(name: 'wh_type') required String whType,
    @JsonKey(name: 'max_ship_size') required String maxShipSize,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'remaining_hours') required int remainingHours,
    @JsonKey(name: 'out_system_id') required int outSystemId,
    @JsonKey(name: 'out_system_name') required String outSystemName,
    @JsonKey(name: 'out_signature') required String outSignature,
    @JsonKey(name: 'in_system_id') required int inSystemId,
    @JsonKey(name: 'in_system_class') required String inSystemClass,
    @JsonKey(name: 'in_system_name') required String inSystemName,
    @JsonKey(name: 'in_region_id') required int inRegionId,
    @JsonKey(name: 'in_region_name') required String inRegionName,
    @JsonKey(name: 'in_signature') required String inSignature,
  }) = _TheraConnection;

  factory TheraConnection.fromJson(Map<String, dynamic> json) =>
      _$TheraConnectionFromJson(json);
}
