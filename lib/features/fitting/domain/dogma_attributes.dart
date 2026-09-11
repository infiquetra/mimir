/// Common Dogma attribute IDs used for fitting calculations.
class DogmaAttributes {
  static const int cpuOutput = 48;
  static const int powerOutput = 11;
  static const int capacitorCapacity = 482;
  static const int capacitorRechargeTime = 55;
  static const int capacitorNeed = 6;
  static const int duration = 73; // module cycle time, milliseconds
  static const int capacitorBonus = 67; // cap booster charge gain, GJ
  static const int reactivationDelay = 1795; // added to the cycle, ms

  static const int shieldCapacity = 263;
  static const int shieldRechargeTime = 479;
  static const int shieldEmResist = 271;
  static const int shieldThermalResist = 274;
  static const int shieldKineticResist = 273;
  static const int shieldExplosiveResist = 272;

  static const int armorHp = 265;
  static const int armorEmResist = 267;
  static const int armorThermalResist = 270;
  static const int armorKineticResist = 269;
  static const int armorExplosiveResist = 268;

  static const int hullHp = 9;
  // Hull resonances live on the ship (emDamageResonance family), not on the
  // Damage Control's own bonus attributes 974-977.
  static const int hullEmResist = 113;
  static const int hullThermalResist = 110;
  static const int hullKineticResist = 109;
  static const int hullExplosiveResist = 111;

  static const int maxVelocity = 37;
  static const int mass = 4;
  static const int inertiaModifier = 70;
  static const int warpSpeedMultiplier = 600;
  static const int speedFactor = 20; // propulsion modules' speed multiplier

  static const int maxTargetRange = 76;
  static const int scanResolution = 564;
  static const int maxLockedTargets = 192;
  static const int signatureRadius = 552;

  static const int droneBandwidth = 1271;
  static const int droneCapacity = 283;
  static const int bandwidthNeeded = 1272; // per-drone bandwidth cost
  static const int volume = 38; // item volume in m3 (invTypes column)

  static const int turretDamageMultiplier = 64;
  static const int missileDamageMultiplier = 212;

  // Weapon cycle and range attributes (turrets and launchers).
  static const int rateOfFire = 51; // cycle time in milliseconds
  static const int optimalRange = 54;
  static const int falloff = 158;
  static const int trackingSpeed = 160;

  // Damage components carried by charges (ammo, missiles) and drones.
  static const int emDamage = 114;
  static const int explosiveDamage = 116;
  static const int kineticDamage = 117;
  static const int thermalDamage = 118;
  static const List<int> damageComponents = [
    emDamage,
    explosiveDamage,
    kineticDamage,
    thermalDamage,
  ];

  // Module fitting requirements
  static const int cpuLoad = 50;
  static const int powerLoad = 30;
  static const int upgradeLoad = 1153; // calibration

  // Skill-owned cycle bonuses (design §3.2).
  static const int skillLevel = 280;
  static const int turretSpeeBonus = 441;
  static const int rofBonus = 293;

  // Fighter hull, squadron, and ability attributes (design §3.2).
  static const int fighterCapacity = 2055;
  static const int fighterTubes = 2216;
  static const int fighterLightSlots = 2217;
  static const int fighterSupportSlots = 2218;
  static const int fighterHeavySlots = 2219;
  static const int fighterSquadronMaxSize = 2215;
  static const int fighterSquadronIsLight = 2212;
  static const int fighterSquadronIsSupport = 2213;
  static const int fighterSquadronIsHeavy = 2214;
  static const int fighterSquadronRole = 2270;
  static const int fighterDamageMultiplier = 2226;
  static const int fighterEmDamage = 2227;
  static const int fighterThermalDamage = 2228;
  static const int fighterKineticDamage = 2229;
  static const int fighterExplosiveDamage = 2230;
  static const int fighterDurationMs = 2233;
  static const int fighterRefuelingTime = 2426;

  // Fighter missiles ability (effect 6431) and bomb (effect 6485).
  static const int fighterMissilesDamageMultiplier = 2130;
  static const int fighterMissilesEmDamage = 2131;
  static const int fighterMissilesThermalDamage = 2132;
  static const int fighterMissilesKineticDamage = 2133;
  static const int fighterMissilesExplosiveDamage = 2134;
  static const int fighterMissilesDurationMs = 2182;
  static const int fighterBombTypeId = 2324;
  static const int fighterBombDurationMs = 2349;

  // Ship-attribute adds published by buffer modules (op 2 modAdd).
  static const int shieldCapacityBonus = 72; // MSE / LSE HP add
  static const int armorHpBonusAdd = 1159; // armor plate HP add
  static const int signatureRadiusAdd = 983; // extender signature add
  static const int massAdd = 796; // plate mass add
}
