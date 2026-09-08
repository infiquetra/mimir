/// Common Dogma attribute IDs used for fitting calculations.
class DogmaAttributes {
  static const int cpuOutput = 48;
  static const int powerOutput = 11;
  static const int capacitorCapacity = 482;
  static const int capacitorRechargeTime = 55;
  static const int capacitorNeed = 6;
  static const int duration = 73; // module cycle time, milliseconds

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
  static const int hullEmResist = 974;
  static const int hullThermalResist = 977;
  static const int hullKineticResist = 976;
  static const int hullExplosiveResist = 975;

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
}
