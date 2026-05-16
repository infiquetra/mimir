// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Fitting _$FittingFromJson(Map<String, dynamic> json) => _Fitting(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  shipTypeId: (json['shipTypeId'] as num).toInt(),
  shipName: json['shipName'] as String,
  highSlots:
      (json['highSlots'] as List<dynamic>?)
          ?.map((e) => FittedModule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  medSlots:
      (json['medSlots'] as List<dynamic>?)
          ?.map((e) => FittedModule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  lowSlots:
      (json['lowSlots'] as List<dynamic>?)
          ?.map((e) => FittedModule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  rigSlots:
      (json['rigSlots'] as List<dynamic>?)
          ?.map((e) => FittedModule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subsystems:
      (json['subsystems'] as List<dynamic>?)
          ?.map((e) => FittedModule.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  drones:
      (json['drones'] as List<dynamic>?)
          ?.map((e) => DroneGroup.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  cargo:
      (json['cargo'] as List<dynamic>?)
          ?.map((e) => CargoItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$FittingToJson(_Fitting instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'shipTypeId': instance.shipTypeId,
  'shipName': instance.shipName,
  'highSlots': instance.highSlots,
  'medSlots': instance.medSlots,
  'lowSlots': instance.lowSlots,
  'rigSlots': instance.rigSlots,
  'subsystems': instance.subsystems,
  'drones': instance.drones,
  'cargo': instance.cargo,
};

_FittedModule _$FittedModuleFromJson(Map<String, dynamic> json) =>
    _FittedModule(
      typeId: (json['typeId'] as num).toInt(),
      typeName: json['typeName'] as String,
      slotType: $enumDecode(_$SlotTypeEnumMap, json['slotType']),
      slotIndex: (json['slotIndex'] as num).toInt(),
      state:
          $enumDecodeNullable(_$ModuleStateEnumMap, json['state']) ??
          ModuleState.active,
      chargeTypeId: (json['chargeTypeId'] as num?)?.toInt(),
      chargeName: json['chargeName'] as String?,
      attributes:
          (json['attributes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k), (e as num).toDouble()),
          ) ??
          const {},
    );

Map<String, dynamic> _$FittedModuleToJson(
  _FittedModule instance,
) => <String, dynamic>{
  'typeId': instance.typeId,
  'typeName': instance.typeName,
  'slotType': _$SlotTypeEnumMap[instance.slotType]!,
  'slotIndex': instance.slotIndex,
  'state': _$ModuleStateEnumMap[instance.state]!,
  'chargeTypeId': instance.chargeTypeId,
  'chargeName': instance.chargeName,
  'attributes': instance.attributes.map((k, e) => MapEntry(k.toString(), e)),
};

const _$SlotTypeEnumMap = {
  SlotType.high: 'high',
  SlotType.med: 'med',
  SlotType.low: 'low',
  SlotType.rig: 'rig',
  SlotType.subsystem: 'subsystem',
};

const _$ModuleStateEnumMap = {
  ModuleState.offline: 'offline',
  ModuleState.online: 'online',
  ModuleState.active: 'active',
  ModuleState.overloaded: 'overloaded',
};

_DroneGroup _$DroneGroupFromJson(Map<String, dynamic> json) => _DroneGroup(
  typeId: (json['typeId'] as num).toInt(),
  typeName: json['typeName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  inBay: (json['inBay'] as num?)?.toInt() ?? 0,
  inSpace: (json['inSpace'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$DroneGroupToJson(_DroneGroup instance) =>
    <String, dynamic>{
      'typeId': instance.typeId,
      'typeName': instance.typeName,
      'quantity': instance.quantity,
      'inBay': instance.inBay,
      'inSpace': instance.inSpace,
    };

_CargoItem _$CargoItemFromJson(Map<String, dynamic> json) => _CargoItem(
  typeId: (json['typeId'] as num).toInt(),
  typeName: json['typeName'] as String,
  quantity: (json['quantity'] as num).toInt(),
);

Map<String, dynamic> _$CargoItemToJson(_CargoItem instance) =>
    <String, dynamic>{
      'typeId': instance.typeId,
      'typeName': instance.typeName,
      'quantity': instance.quantity,
    };

_FittingStats _$FittingStatsFromJson(Map<String, dynamic> json) =>
    _FittingStats(
      cpuUsed: (json['cpuUsed'] as num?)?.toDouble() ?? 0.0,
      cpuMax: (json['cpuMax'] as num?)?.toDouble() ?? 0.0,
      powerUsed: (json['powerUsed'] as num?)?.toDouble() ?? 0.0,
      powerMax: (json['powerMax'] as num?)?.toDouble() ?? 0.0,
      calibrationUsed: (json['calibrationUsed'] as num?)?.toInt() ?? 0,
      calibrationMax: (json['calibrationMax'] as num?)?.toInt() ?? 0,
      capacitorCapacity: (json['capacitorCapacity'] as num?)?.toDouble() ?? 0.0,
      capacitorRecharge: (json['capacitorRecharge'] as num?)?.toDouble() ?? 0.0,
      capacitorStable: (json['capacitorStable'] as num?)?.toDouble() ?? 0.0,
      isCapStable: json['isCapStable'] as bool? ?? false,
      defenses: json['defenses'] == null
          ? const DefenseProfile()
          : DefenseProfile.fromJson(json['defenses'] as Map<String, dynamic>),
      dpsTotal: (json['dpsTotal'] as num?)?.toDouble() ?? 0.0,
      dpsGuns: (json['dpsGuns'] as num?)?.toDouble() ?? 0.0,
      dpsDrones: (json['dpsDrones'] as num?)?.toDouble() ?? 0.0,
      dpsMissiles: (json['dpsMissiles'] as num?)?.toDouble() ?? 0.0,
      volley: (json['volley'] as num?)?.toDouble() ?? 0.0,
      optimalRange: (json['optimalRange'] as num?)?.toDouble() ?? 0.0,
      falloffRange: (json['falloffRange'] as num?)?.toDouble() ?? 0.0,
      maxVelocity: (json['maxVelocity'] as num?)?.toDouble() ?? 0.0,
      inertiaModifier: (json['inertiaModifier'] as num?)?.toDouble() ?? 0.0,
      alignTime: (json['alignTime'] as num?)?.toDouble() ?? 0.0,
      warpSpeed: (json['warpSpeed'] as num?)?.toDouble() ?? 0.0,
      massKg: (json['massKg'] as num?)?.toDouble() ?? 0.0,
      targetRange: (json['targetRange'] as num?)?.toDouble() ?? 0.0,
      scanResolution: (json['scanResolution'] as num?)?.toDouble() ?? 0.0,
      maxLockedTargets: (json['maxLockedTargets'] as num?)?.toInt() ?? 0,
      signatureRadius: (json['signatureRadius'] as num?)?.toDouble() ?? 0.0,
      droneBandwidthUsed:
          (json['droneBandwidthUsed'] as num?)?.toDouble() ?? 0.0,
      droneBandwidthMax: (json['droneBandwidthMax'] as num?)?.toDouble() ?? 0.0,
      droneBayUsed: (json['droneBayUsed'] as num?)?.toDouble() ?? 0.0,
      droneBayMax: (json['droneBayMax'] as num?)?.toDouble() ?? 0.0,
      shipCost: (json['shipCost'] as num?)?.toDouble() ?? 0.0,
      moduleCost: (json['moduleCost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$FittingStatsToJson(_FittingStats instance) =>
    <String, dynamic>{
      'cpuUsed': instance.cpuUsed,
      'cpuMax': instance.cpuMax,
      'powerUsed': instance.powerUsed,
      'powerMax': instance.powerMax,
      'calibrationUsed': instance.calibrationUsed,
      'calibrationMax': instance.calibrationMax,
      'capacitorCapacity': instance.capacitorCapacity,
      'capacitorRecharge': instance.capacitorRecharge,
      'capacitorStable': instance.capacitorStable,
      'isCapStable': instance.isCapStable,
      'defenses': instance.defenses,
      'dpsTotal': instance.dpsTotal,
      'dpsGuns': instance.dpsGuns,
      'dpsDrones': instance.dpsDrones,
      'dpsMissiles': instance.dpsMissiles,
      'volley': instance.volley,
      'optimalRange': instance.optimalRange,
      'falloffRange': instance.falloffRange,
      'maxVelocity': instance.maxVelocity,
      'inertiaModifier': instance.inertiaModifier,
      'alignTime': instance.alignTime,
      'warpSpeed': instance.warpSpeed,
      'massKg': instance.massKg,
      'targetRange': instance.targetRange,
      'scanResolution': instance.scanResolution,
      'maxLockedTargets': instance.maxLockedTargets,
      'signatureRadius': instance.signatureRadius,
      'droneBandwidthUsed': instance.droneBandwidthUsed,
      'droneBandwidthMax': instance.droneBandwidthMax,
      'droneBayUsed': instance.droneBayUsed,
      'droneBayMax': instance.droneBayMax,
      'shipCost': instance.shipCost,
      'moduleCost': instance.moduleCost,
      'totalCost': instance.totalCost,
    };

_DefenseProfile _$DefenseProfileFromJson(
  Map<String, dynamic> json,
) => _DefenseProfile(
  shieldHp: (json['shieldHp'] as num?)?.toDouble() ?? 0.0,
  shieldRecharge: (json['shieldRecharge'] as num?)?.toDouble() ?? 0.0,
  shieldResists: json['shieldResists'] == null
      ? const ResistProfile()
      : ResistProfile.fromJson(json['shieldResists'] as Map<String, dynamic>),
  shieldEhp: (json['shieldEhp'] as num?)?.toDouble() ?? 0.0,
  armorHp: (json['armorHp'] as num?)?.toDouble() ?? 0.0,
  armorResists: json['armorResists'] == null
      ? const ResistProfile()
      : ResistProfile.fromJson(json['armorResists'] as Map<String, dynamic>),
  armorEhp: (json['armorEhp'] as num?)?.toDouble() ?? 0.0,
  hullHp: (json['hullHp'] as num?)?.toDouble() ?? 0.0,
  hullResists: json['hullResists'] == null
      ? const ResistProfile()
      : ResistProfile.fromJson(json['hullResists'] as Map<String, dynamic>),
  hullEhp: (json['hullEhp'] as num?)?.toDouble() ?? 0.0,
  totalEhp: (json['totalEhp'] as num?)?.toDouble() ?? 0.0,
  effectiveShieldBoost:
      (json['effectiveShieldBoost'] as num?)?.toDouble() ?? 0.0,
  effectiveArmorRepair:
      (json['effectiveArmorRepair'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$DefenseProfileToJson(_DefenseProfile instance) =>
    <String, dynamic>{
      'shieldHp': instance.shieldHp,
      'shieldRecharge': instance.shieldRecharge,
      'shieldResists': instance.shieldResists,
      'shieldEhp': instance.shieldEhp,
      'armorHp': instance.armorHp,
      'armorResists': instance.armorResists,
      'armorEhp': instance.armorEhp,
      'hullHp': instance.hullHp,
      'hullResists': instance.hullResists,
      'hullEhp': instance.hullEhp,
      'totalEhp': instance.totalEhp,
      'effectiveShieldBoost': instance.effectiveShieldBoost,
      'effectiveArmorRepair': instance.effectiveArmorRepair,
    };

_ResistProfile _$ResistProfileFromJson(Map<String, dynamic> json) =>
    _ResistProfile(
      em: (json['em'] as num?)?.toDouble() ?? 0.0,
      thermal: (json['thermal'] as num?)?.toDouble() ?? 0.0,
      kinetic: (json['kinetic'] as num?)?.toDouble() ?? 0.0,
      explosive: (json['explosive'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$ResistProfileToJson(_ResistProfile instance) =>
    <String, dynamic>{
      'em': instance.em,
      'thermal': instance.thermal,
      'kinetic': instance.kinetic,
      'explosive': instance.explosive,
    };

_ShipType _$ShipTypeFromJson(Map<String, dynamic> json) => _ShipType(
  typeId: (json['typeId'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String,
  groupId: (json['groupId'] as num).toInt(),
  groupName: json['groupName'] as String,
  raceName: json['raceName'] as String? ?? '',
  highSlots: (json['highSlots'] as num?)?.toInt() ?? 0,
  medSlots: (json['medSlots'] as num?)?.toInt() ?? 0,
  lowSlots: (json['lowSlots'] as num?)?.toInt() ?? 0,
  rigSlots: (json['rigSlots'] as num?)?.toInt() ?? 0,
  turretSlots: (json['turretSlots'] as num?)?.toInt() ?? 0,
  launcherSlots: (json['launcherSlots'] as num?)?.toInt() ?? 0,
  baseAttributes:
      (json['baseAttributes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k), (e as num).toDouble()),
      ) ??
      const {},
  bonuses:
      (json['bonuses'] as List<dynamic>?)
          ?.map((e) => ShipBonus.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  skillRequirements:
      (json['skillRequirements'] as List<dynamic>?)
          ?.map((e) => SkillRequirement.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ShipTypeToJson(_ShipType instance) => <String, dynamic>{
  'typeId': instance.typeId,
  'name': instance.name,
  'description': instance.description,
  'groupId': instance.groupId,
  'groupName': instance.groupName,
  'raceName': instance.raceName,
  'highSlots': instance.highSlots,
  'medSlots': instance.medSlots,
  'lowSlots': instance.lowSlots,
  'rigSlots': instance.rigSlots,
  'turretSlots': instance.turretSlots,
  'launcherSlots': instance.launcherSlots,
  'baseAttributes': instance.baseAttributes.map(
    (k, e) => MapEntry(k.toString(), e),
  ),
  'bonuses': instance.bonuses,
  'skillRequirements': instance.skillRequirements,
};

_ShipBonus _$ShipBonusFromJson(Map<String, dynamic> json) => _ShipBonus(
  skillTypeId: (json['skillTypeId'] as num).toInt(),
  skillName: json['skillName'] as String,
  bonusText: json['bonusText'] as String,
  bonusAmount: (json['bonusAmount'] as num).toDouble(),
  attributeId: (json['attributeId'] as num).toInt(),
);

Map<String, dynamic> _$ShipBonusToJson(_ShipBonus instance) =>
    <String, dynamic>{
      'skillTypeId': instance.skillTypeId,
      'skillName': instance.skillName,
      'bonusText': instance.bonusText,
      'bonusAmount': instance.bonusAmount,
      'attributeId': instance.attributeId,
    };

_ModuleType _$ModuleTypeFromJson(Map<String, dynamic> json) => _ModuleType(
  typeId: (json['typeId'] as num).toInt(),
  name: json['name'] as String,
  groupId: (json['groupId'] as num).toInt(),
  groupName: json['groupName'] as String,
  slotType: $enumDecode(_$SlotTypeEnumMap, json['slotType']),
  metaLevel: (json['metaLevel'] as num?)?.toInt() ?? 0,
  techLevel: (json['techLevel'] as num?)?.toInt() ?? 1,
  cpu: (json['cpu'] as num?)?.toDouble() ?? 0.0,
  powergrid: (json['powergrid'] as num?)?.toDouble() ?? 0.0,
  calibration: (json['calibration'] as num?)?.toInt() ?? 0,
  baseAttributes:
      (json['baseAttributes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k), (e as num).toDouble()),
      ) ??
      const {},
  effects:
      (json['effects'] as List<dynamic>?)
          ?.map((e) => DogmaEffect.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  skillRequirements:
      (json['skillRequirements'] as List<dynamic>?)
          ?.map((e) => SkillRequirement.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  acceptedChargeGroups:
      (json['acceptedChargeGroups'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$ModuleTypeToJson(_ModuleType instance) =>
    <String, dynamic>{
      'typeId': instance.typeId,
      'name': instance.name,
      'groupId': instance.groupId,
      'groupName': instance.groupName,
      'slotType': _$SlotTypeEnumMap[instance.slotType]!,
      'metaLevel': instance.metaLevel,
      'techLevel': instance.techLevel,
      'cpu': instance.cpu,
      'powergrid': instance.powergrid,
      'calibration': instance.calibration,
      'baseAttributes': instance.baseAttributes.map(
        (k, e) => MapEntry(k.toString(), e),
      ),
      'effects': instance.effects,
      'skillRequirements': instance.skillRequirements,
      'acceptedChargeGroups': instance.acceptedChargeGroups,
    };

_DogmaEffect _$DogmaEffectFromJson(Map<String, dynamic> json) => _DogmaEffect(
  effectId: (json['effectId'] as num).toInt(),
  name: json['name'] as String,
  isOffensive: json['isOffensive'] as bool? ?? false,
  isAssistance: json['isAssistance'] as bool? ?? false,
);

Map<String, dynamic> _$DogmaEffectToJson(_DogmaEffect instance) =>
    <String, dynamic>{
      'effectId': instance.effectId,
      'name': instance.name,
      'isOffensive': instance.isOffensive,
      'isAssistance': instance.isAssistance,
    };

_SkillRequirement _$SkillRequirementFromJson(Map<String, dynamic> json) =>
    _SkillRequirement(
      skillTypeId: (json['skillTypeId'] as num).toInt(),
      skillName: json['skillName'] as String,
      requiredLevel: (json['requiredLevel'] as num).toInt(),
    );

Map<String, dynamic> _$SkillRequirementToJson(_SkillRequirement instance) =>
    <String, dynamic>{
      'skillTypeId': instance.skillTypeId,
      'skillName': instance.skillName,
      'requiredLevel': instance.requiredLevel,
    };

_CharacterSkill _$CharacterSkillFromJson(Map<String, dynamic> json) =>
    _CharacterSkill(
      skillId: (json['skillId'] as num).toInt(),
      level: (json['level'] as num).toInt(),
    );

Map<String, dynamic> _$CharacterSkillToJson(_CharacterSkill instance) =>
    <String, dynamic>{'skillId': instance.skillId, 'level': instance.level};
