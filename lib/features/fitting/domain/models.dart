import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

enum SlotType { high, med, low, rig, subsystem }
enum ModuleState { offline, online, active, overloaded }

@freezed
abstract class Fitting with _$Fitting {
  const Fitting._();

  const factory Fitting({
    required String id,
    required String name,
    String? description,
    required int shipTypeId,
    required String shipName,
    @Default([]) List<FittedModule> highSlots,
    @Default([]) List<FittedModule> medSlots,
    @Default([]) List<FittedModule> lowSlots,
    @Default([]) List<FittedModule> rigSlots,
    @Default([]) List<FittedModule> subsystems,
    @Default([]) List<DroneGroup> drones,
    @Default([]) List<CargoItem> cargo,
  }) = _Fitting;

  factory Fitting.fromJson(Map<String, dynamic> json) => _$FittingFromJson(json);
  
  List<FittedModule> get allModules => [
    ...highSlots,
    ...medSlots,
    ...lowSlots,
    ...rigSlots,
    ...subsystems,
  ];
}

@freezed
abstract class FittedModule with _$FittedModule {
  const factory FittedModule({
    required int typeId,
    required String typeName,
    required SlotType slotType,
    required int slotIndex,
    @Default(ModuleState.active) ModuleState state,
    int? chargeTypeId,
    String? chargeName,
    @Default({}) Map<int, double> attributes,
  }) = _FittedModule;

  factory FittedModule.fromJson(Map<String, dynamic> json) => _$FittedModuleFromJson(json);
}

@freezed
abstract class DroneGroup with _$DroneGroup {
  const factory DroneGroup({
    required int typeId,
    required String typeName,
    required int quantity,
    @Default(0) int inBay,
    @Default(0) int inSpace,
  }) = _DroneGroup;

  factory DroneGroup.fromJson(Map<String, dynamic> json) => _$DroneGroupFromJson(json);
}

@freezed
abstract class CargoItem with _$CargoItem {
  const factory CargoItem({
    required int typeId,
    required String typeName,
    required int quantity,
  }) = _CargoItem;

  factory CargoItem.fromJson(Map<String, dynamic> json) => _$CargoItemFromJson(json);
}

@freezed
abstract class FittingStats with _$FittingStats {
  const factory FittingStats({
    @Default(0.0) double cpuUsed,
    @Default(0.0) double cpuMax,
    @Default(0.0) double powerUsed,
    @Default(0.0) double powerMax,
    @Default(0) int calibrationUsed,
    @Default(0) int calibrationMax,
    
    @Default(0.0) double capacitorCapacity,
    @Default(0.0) double capacitorRecharge,
    @Default(0.0) double capacitorStable,
    @Default(false) bool isCapStable,
    
    @Default(DefenseProfile()) DefenseProfile defenses,
    
    @Default(0.0) double dpsTotal,
    @Default(0.0) double dpsGuns,
    @Default(0.0) double dpsDrones,
    @Default(0.0) double dpsMissiles,
    @Default(0.0) double volley,
    @Default(0.0) double optimalRange,
    @Default(0.0) double falloffRange,
    
    @Default(0.0) double maxVelocity,
    @Default(0.0) double inertiaModifier,
    @Default(0.0) double alignTime,
    @Default(0.0) double warpSpeed,
    @Default(0.0) double massKg,
    
    @Default(0.0) double targetRange,
    @Default(0.0) double scanResolution,
    @Default(0) int maxLockedTargets,
    @Default(0.0) double signatureRadius,
    
    @Default(0.0) double droneBandwidthUsed,
    @Default(0.0) double droneBandwidthMax,
    @Default(0.0) double droneBayUsed,
    @Default(0.0) double droneBayMax,
    
    @Default(0.0) double shipCost,
    @Default(0.0) double moduleCost,
    @Default(0.0) double totalCost,
  }) = _FittingStats;

  factory FittingStats.fromJson(Map<String, dynamic> json) => _$FittingStatsFromJson(json);
}

@freezed
abstract class DefenseProfile with _$DefenseProfile {
  const factory DefenseProfile({
    @Default(0.0) double shieldHp,
    @Default(0.0) double shieldRecharge,
    @Default(ResistProfile()) ResistProfile shieldResists,
    @Default(0.0) double shieldEhp,

    @Default(0.0) double armorHp,
    @Default(ResistProfile()) ResistProfile armorResists,
    @Default(0.0) double armorEhp,

    @Default(0.0) double hullHp,
    @Default(ResistProfile()) ResistProfile hullResists,
    @Default(0.0) double hullEhp,

    @Default(0.0) double totalEhp,
    @Default(0.0) double effectiveShieldBoost,
    @Default(0.0) double effectiveArmorRepair,
  }) = _DefenseProfile;

  factory DefenseProfile.fromJson(Map<String, dynamic> json) => _$DefenseProfileFromJson(json);
}

@freezed
abstract class ResistProfile with _$ResistProfile {
  const ResistProfile._();

  const factory ResistProfile({
    @Default(0.0) double em,
    @Default(0.0) double thermal,
    @Default(0.0) double kinetic,
    @Default(0.0) double explosive,
  }) = _ResistProfile;

  factory ResistProfile.fromJson(Map<String, dynamic> json) => _$ResistProfileFromJson(json);
  
  double get omniResist => (em + thermal + kinetic + explosive) / 4;
}

@freezed
abstract class ShipType with _$ShipType {
  const factory ShipType({
    required int typeId,
    required String name,
    required String description,
    required int groupId,
    required String groupName,
    @Default('') String raceName,
    @Default(0) int highSlots,
    @Default(0) int medSlots,
    @Default(0) int lowSlots,
    @Default(0) int rigSlots,
    @Default(0) int turretSlots,
    @Default(0) int launcherSlots,
    @Default({}) Map<int, double> baseAttributes,
    @Default([]) List<ShipBonus> bonuses,
    @Default([]) List<SkillRequirement> skillRequirements,
  }) = _ShipType;

  factory ShipType.fromJson(Map<String, dynamic> json) => _$ShipTypeFromJson(json);
}

@freezed
abstract class ShipBonus with _$ShipBonus {
  const factory ShipBonus({
    required int skillTypeId,
    required String skillName,
    required String bonusText,
    required double bonusAmount,
    required int attributeId,
  }) = _ShipBonus;

  factory ShipBonus.fromJson(Map<String, dynamic> json) => _$ShipBonusFromJson(json);
}

@freezed
abstract class ModuleType with _$ModuleType {
  const factory ModuleType({
    required int typeId,
    required String name,
    required int groupId,
    required String groupName,
    required SlotType slotType,
    @Default(0) int metaLevel,
    @Default(1) int techLevel,
    @Default(0.0) double cpu,
    @Default(0.0) double powergrid,
    @Default(0) int calibration,
    @Default({}) Map<int, double> baseAttributes,
    @Default([]) List<DogmaEffect> effects,
    @Default([]) List<SkillRequirement> skillRequirements,
    @Default([]) List<int> acceptedChargeGroups,
  }) = _ModuleType;

  factory ModuleType.fromJson(Map<String, dynamic> json) => _$ModuleTypeFromJson(json);
}

@freezed
abstract class DogmaEffect with _$DogmaEffect {
  const factory DogmaEffect({
    required int effectId,
    required String name,
    @Default(false) bool isOffensive,
    @Default(false) bool isAssistance,
  }) = _DogmaEffect;

  factory DogmaEffect.fromJson(Map<String, dynamic> json) => _$DogmaEffectFromJson(json);
}

@freezed
abstract class SkillRequirement with _$SkillRequirement {
  const factory SkillRequirement({
    required int skillTypeId,
    required String skillName,
    required int requiredLevel,
  }) = _SkillRequirement;

  factory SkillRequirement.fromJson(Map<String, dynamic> json) => _$SkillRequirementFromJson(json);
}

@freezed
abstract class CharacterSkill with _$CharacterSkill {
  const factory CharacterSkill({
    required int skillId,
    required int level,
  }) = _CharacterSkill;

  factory CharacterSkill.fromJson(Map<String, dynamic> json) => _$CharacterSkillFromJson(json);
}

