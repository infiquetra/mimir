#!/usr/bin/env python3
"""Generate assets/sde/fitting_types.json from committed SDE CSV caches.

Design: docs/fittings-import-design.md, section 4.1, extended by
docs/fitting-resources-design.md section 5. Reads only the committed
Fuzzwork caches under scripts/sde/ (invTypes.csv.bz2, invGroups.csv.bz2,
dgmTypeEffects.csv.bz2, dgmTypeAttributes.csv.bz2); never the network.
Fails loudly (nonzero exit, no output written) if a cache file is
missing or self-validation fails, following the
generate_exploration_sde.py precedent.

Row rule: published == 1, typeID > 0, typeName non-empty after
stripping. All categories are kept (cargo can be any inventory type).
categoryId is denormalized from invGroups; a type whose group is
missing keeps categoryId 0 and is counted in the output. slotEffects
is the sorted, de-duplicated subset of the type's dgmTypeEffects rows
in {11, 12, 13, 2663, 3772} (the "_slotTypeFor" effects in Flutter's
sde_service.dart at ed698d3).

Resource attributes (docs/fitting-resources-design.md section 2) are
joined from dgmTypeAttributes.csv.bz2: ship CPU/power output (48/11)
and module CPU/power need (50/30), the dogmaAttributes.jsonl names
cpuOutput/powerOutput/cpu/power and Flutter dogma_attributes.dart at
ed698d3 (cpuOutput = 48, powerOutput = 11, cpuLoad = 50,
powerLoad = 30). Emission is additive and sparse: category 6 rows
gain cpuOutput/powerOutput when present; category 7 rows with
non-empty slotEffects gain cpu/power when present; every other row
is byte-identical to the pre-resources catalogue. Subsystem output
rows are deliberately not emitted (no locked computation reads them).

Output is deterministic: types sorted by typeId, compact separators,
no timestamps. Shape: {"types":[{"typeId":..,"typeName":..,
"categoryId":..,"slotEffects":[..]}, ...]} with camelCase keys
matching assets/sde/skills.json, plus the four optional resource keys
where present and, on category 6 rows only, the five optional base
ship stat keys (docs/ship-base-stats-design.md section 3) plus the
twelve optional base ship resonance keys (docs/ship-resistances-design.md
section 3). Bay capacities and usage (docs/bay-capacities-design.md
section 3) append six further keys after the existing ones in the
locked order: `volume` on every row from the invTypes `volume`
column, `cargoCapacity` on every category 6 row from the invTypes
`capacity` column, and sparse `droneCapacity`/`droneBandwidth`/
`fighterCapacity` (dogma 283/1271/2055) on category 6 rows and
`droneBandwidthUsed` (dogma 1272) wherever a row exists. Rig
calibration (docs/rig-calibration-design.md section 3.1) appends
`upgradeCapacity` (dogma 1132) on category 6 rows and
`upgradeCost` (dogma 1153) on slot-effect-2663 rows after the bay
keys. Navigation and targeting (docs/nav-targeting-design.md
section 3) appends eleven further keys after `launcherFitted`
in the locked order: `warpSpeedMultiplier` (dogma 600), `agility`
(70), `signatureRadius` (552), `maxTargetRange` (76),
`scanResolution` (564), `scanRadarStrength` (208),
`scanLadarStrength` (209), `scanMagnetometricStrength` (210),
`scanGravimetricStrength` (211), `maxLockedTargets` (192) — all
dogma rows, sparse on category 6 rows only — plus `mass` from
the invTypes `mass` column on category 6 rows only. Dogma 1281
`baseWarpSpeed` is read only for a fail-loud tripwire (constant
1.0 on every category-6 row, never emitted); dogma 4 `mass`,
1169, and 1908 are never read.
Slot layout (docs/slot-layout-design.md section 3.1) appends
nine further keys after the calibration keys in the locked order:
`hiSlots` (dogma 14), `medSlots` (13), `lowSlots` (12),
`rigSlots` (1137), `maxSubSystems` (1367), `turretSlotsLeft`
(102), `launcherSlotsLeft` (101) on category 6 rows only, sparse
by presence, and sparse boolean markers `turretFitted` (effect
42) and `launcherFitted` (effect 40) wherever a marker row
exists. Dogma 1154 `upgradeSlotsLeft`, attribute 47 `slots`, and
the subsystem modifiers 1368/1369/1374-1376 are never read here.
"""

import bz2
import csv
import json
import math
import os
import re
import sys
from collections import Counter
from collections import defaultdict
from io import StringIO

SLOT_EFFECT_IDS = {11, 12, 13, 2663, 3772}

# Resource attribute ids (docs/fitting-resources-design.md section 2):
# dogmaAttributes.jsonl _key 48 "cpuOutput", 11 "powerOutput",
# 50 "cpu", 30 "power"; Flutter dogma_attributes.dart at ed698d3
# (cpuOutput = 48, powerOutput = 11, cpuLoad = 50, powerLoad = 30).
RESOURCE_ATTR_IDS = {48, 11, 50, 30}
SHIP_CPU_OUTPUT_ATTR = 48
SHIP_POWER_OUTPUT_ATTR = 11
MODULE_CPU_NEED_ATTR = 50
MODULE_POWER_NEED_ATTR = 30

# Base ship attribute ids (docs/ship-base-stats-design.md section 2):
# dogmaAttributes.jsonl _key 263 "shieldCapacity", 265 "armorHP",
# 9 "hp", 482 "capacitorCapacity", 37 "maxVelocity"; Flutter
# dogma_attributes.dart at ed698d3 (shieldCapacity = 263,
# armorHp = 265, hullHp = 9, capacitorCapacity = 482,
# maxVelocity = 37).
BASE_STAT_ATTR_IDS = {263, 265, 9, 482, 37, 479, 55}
SHIELD_CAPACITY_ATTR = 263
ARMOR_HP_ATTR = 265
HULL_HP_ATTR = 9
CAPACITOR_CAPACITY_ATTR = 482
MAX_VELOCITY_ATTR = 37

# Recharge durations (docs/ship-recharge-times-design.md):
# dogmaAttributes.jsonl _key 479 "shieldRechargeRate" and
# 55 "rechargeRate", both unit 101 Milliseconds; Flutter
# dogma_attributes.dart at ed698d3 (shieldRechargeTime = 479,
# capacitorRechargeTime = 55). Values stay raw milliseconds in
# the catalogue; conversion to seconds lives in the pure layer.
SHIELD_RECHARGE_ATTR = 479
CAPACITOR_RECHARGE_ATTR = 55

# Base ship resonance attribute ids (docs/ship-resistances-design.md
# section 2): dogmaAttributes.jsonl in
# scripts/sde/eve-online-static-data-3503375-jsonl.zip names
# 271 shieldEmDamageResonance, 274 shieldThermalDamageResonance,
# 273 shieldKineticDamageResonance, 272 shieldExplosiveDamageResonance,
# 267 armorEmDamageResonance, 270 armorThermalDamageResonance,
# 269 armorKineticDamageResonance, 268 armorExplosiveDamageResonance,
# 113 emDamageResonance, 110 thermalDamageResonance,
# 109 kineticDamageResonance, 111 explosiveDamageResonance, each
# unit 108 "Inverse Absolute Percent" (dogmaUnits.jsonl: "Used for
# resistance.\n0.0 = 100% 1.0 = 0%") with default value 1.0; Flutter
# dogma_attributes.dart at ed698d3 gives the same twelve numbers.
# The hull set is the emDamageResonance family (113/110/109/111),
# NOT 974-977 (hullEmDamageResonance et al.): those four share the
# identical SDE English display names ("Structure EM Damage
# Resistance" etc.) but are Damage Control bonus-attribute
# inputs (Flutter effect 2302 maps them onto 113/110/109/111),
# present on only 9 of 404 ships at 1.0, while 113/110/109/111
# are present on all 404 ships at 0.67. Emitting 974-977 as hull
# base would show invented resistances.
RESIST_ATTR_IDS = {271, 274, 273, 272, 267, 270, 269, 268,
                   113, 110, 109, 111}
SHIELD_EM_RESONANCE_ATTR = 271
SHIELD_THERMAL_RESONANCE_ATTR = 274
SHIELD_KINETIC_RESONANCE_ATTR = 273
SHIELD_EXPLOSIVE_RESONANCE_ATTR = 272
ARMOR_EM_RESONANCE_ATTR = 267
ARMOR_THERMAL_RESONANCE_ATTR = 270
ARMOR_KINETIC_RESONANCE_ATTR = 269
ARMOR_EXPLOSIVE_RESONANCE_ATTR = 268
HULL_EM_RESONANCE_ATTR = 113
HULL_THERMAL_RESONANCE_ATTR = 110
HULL_KINETIC_RESONANCE_ATTR = 109
HULL_EXPLOSIVE_RESONANCE_ATTR = 111

# Bay attributes (docs/bay-capacities-design.md section 3):
# dogmaAttributes.jsonl _key 283 "droneCapacity", 1271
# "droneBandwidth", 2055 "fighterCapacity", 1272
# "droneBandwidthUsed" (units 9 "m3" and 128 "Mbit/sec"); Flutter
# dogma_attributes.dart at ed698d3 gives the same four numbers.
# Ship cargo capacity and per-type volume come from the invTypes
# columns instead: dgmTypeAttributes carries zero rows for dogma
# 38 "capacity", dogma 161 "volume" is a decoy (6 rows, none in
# the catalogue), and Flutter's key 38 was its synthesized
# invTypes.volume — never a dogma read.
BAY_ATTR_IDS = {283, 1271, 2055, 1272}
DRONE_CAPACITY_ATTR = 283
DRONE_BANDWIDTH_ATTR = 1271
FIGHTER_CAPACITY_ATTR = 2055
DRONE_BANDWIDTH_USED_ATTR = 1272

# Rig calibration (docs/rig-calibration-design.md section 3.1):
# dogmaAttributes.jsonl _key 1132 "upgradeCapacity" (unit 120
# attributePoints, display "points"; attributeCategory 7,
# "Attribute on ships used for ship upgrades") and 1153
# "upgradeCost" (no unitID key; attributeCategory 1, "How much of
# the upgrade capacity is used when this is fitted to a ship.").
# Dogma 560 "cloakingTargetingDelay" (unit 101 Milliseconds) is
# the recalibration decoy and is never read here.
CALIBRATION_ATTR_IDS = {1132, 1153}
SHIP_CALIBRATION_ATTR = 1132
RIG_CALIBRATION_ATTR = 1153

# Slot layout (docs/slot-layout-design.md section 2.1):
# dogmaAttributes.jsonl _key 14 "hiSlots", 13 "medSlots",
# 12 "lowSlots", 1137 "rigSlots", 1367 "maxSubSystems",
# 102 "turretSlotsLeft", 101 "launcherSlotsLeft", each dataType
# 4 (float) with valueFloat present and valueInt the string
# "None". Catalogue keys are the dogma names verbatim. Dogma
# 1154 "upgradeSlotsLeft" is the unchosen rig source and is
# never read; attribute 47 "slots", 64, 106, 212, 1366, 2056,
# and the subsystem modifiers 1368/1369/1374-1376 are barred.
SLOT_LAYOUT_ATTR_IDS = {14, 13, 12, 1137, 1367, 102, 101}
HI_SLOTS_ATTR = 14
MED_SLOTS_ATTR = 13
LOW_SLOTS_ATTR = 12
RIG_SLOTS_ATTR = 1137
MAX_SUBSYSTEMS_ATTR = 1367
TURRET_SLOTS_LEFT_ATTR = 102
LAUNCHER_SLOTS_LEFT_ATTR = 101

# Hardpoint consumption markers (docs/slot-layout-design.md
# section 2.3): dogmaEffects.jsonl _key 40 "launcherFitted"
# ("Requires a launcher hardpoint") and 42 "turretFitted"
# ("Requires a turret hardpoint"), both pure markers with no
# modifier payload. Attribute 47 is not a substitute and is
# never read.
LAUNCHER_FITTED_EFFECT = 40
TURRET_FITTED_EFFECT = 42

# Navigation and targeting (docs/nav-targeting-design.md section 2/3):
# dogmaAttributes.jsonl _key 600 "warpSpeedMultiplier" (unit 104 "x"),
# 70 "agility" ("Inertia Modifier", unit 104 "x"), 552
# "signatureRadius" (unit 1 "m"), 76 "maxTargetRange" (unit 1 "m"),
# 564 "scanResolution" (unit 102 "mm"), 208 "scanRadarStrength",
# 209 "scanLadarStrength", 210 "scanMagnetometricStrength",
# 211 "scanGravimetricStrength" (all unit 120 "points"), 192
# "maxLockedTargets" (no unitID; a count). Catalogue keys are the
# dogma names verbatim. Dogma 1281 "baseWarpSpeed" (unit 144
# "AU/s") is the constant-1.0 tripwire input only, never emitted
# (design section 2.1). Dogma 4 "mass" is barred as a value source
# (zero ship rows, design section 2.4); mass comes from the
# invTypes `mass` column under the `volume` precedent. Sensor
# adjacents 238-241/1027-1030/1473-1476/1136/1371, agility
# adjacents 151/169/559/2690, signature adjacents 554/652/973/
# 983/1477, target-count adjacents 235/3034/193, dogma 101
# (slot layout), 79, and 765 are barred (design section 2.7).
NAV_TARGETING_ATTR_IDS = {600, 70, 552, 76, 564, 208, 209, 210, 211, 192}
WARP_SPEED_MULTIPLIER_ATTR = 600
AGILITY_ATTR = 70
SIGNATURE_RADIUS_ATTR = 552
MAX_TARGET_RANGE_ATTR = 76
SCAN_RESOLUTION_ATTR = 564
SCAN_RADAR_STRENGTH_ATTR = 208
SCAN_LADAR_STRENGTH_ATTR = 209
SCAN_MAGNETOMETRIC_STRENGTH_ATTR = 210
SCAN_GRAVIMETRIC_STRENGTH_ATTR = 211
MAX_LOCKED_TARGETS_ATTR = 192
BASE_WARP_SPEED_ATTR = 1281

CACHES = {
    "invTypes": "invTypes.csv.bz2",
    "invGroups": "invGroups.csv.bz2",
    "dgmTypeEffects": "dgmTypeEffects.csv.bz2",
    "dgmTypeAttributes": "dgmTypeAttributes.csv.bz2",
}

OUTPUT = os.path.join("assets", "sde", "fitting_types.json")

# Section 3 oracle spot checks: (typeId, typeName, categoryId, required
# slot effect). Verified against the caches during design; a future
# cache refresh that changes these must surface loudly, not silently.
ORACLES = [
    (587, "Rifter", 6, None),
    (29986, "Legion", 6, None),
    (2048, "Damage Control II", 7, 11),
    (1183, "Small Armor Repairer II", 7, 11),
    (438, "1MN Afterburner II", 7, 13),
    (448, "Warp Scrambler II", 7, 13),
    (2889, "200mm AutoCannon II", 7, 12),
    (31668, "Small Projectile Burst Aerator I", 7, 2663),
    (45623, "Legion Core - Augmented Antimatter Reactor", 32, 3772),
    (2456, "Hobgoblin II", 18, None),
    (40556, "Templar II", 87, None),
    (185, "EMP S", 8, None),
    (21898, "Republic Fleet EMP S", 8, None),
    (28668, "Nanite Repair Paste", 8, None),
    (34, "Tritanium", 4, None),
]

# Resource attribute oracle pins (docs/fitting-resources-design.md
# section 5): each value read directly from
# dgmTypeAttributes.csv.bz2 during design. Tuple shape:
# (typeId, key-or-None, expected value-or-None). A None key means no
# resource key may be present on that row at all.
RESOURCE_ORACLES = [
    (587, "cpuOutput", 130.0),
    (587, "powerOutput", 41.0),
    (2048, "cpu", 30.0),
    (2048, "power", 1.0),
    (1183, "cpu", 6.0),
    (1183, "power", 6.0),
    (438, "cpu", 15.0),
    (438, "power", 11.0),
    (448, "cpu", 36.0),
    (448, "power", 1.0),
    (2889, "cpu", 9.0),
    (2889, "power", 4.0),
    (31668, None, None),
    (45623, None, None),
    (37303, "cpu", 126.5),
    (1355, "power", 0.0),
    (1236, None, None),
]

# Base ship attribute oracle pins (docs/ship-base-stats-design.md
# section 3): each value read directly from
# dgmTypeAttributes.csv.bz2 during design. Tuple shape:
# (typeId, key-or-None, expected value-or-None). A None key means
# none of the five new keys may be present on that row at all.
SHIP_STAT_ORACLES = [
    (587, "shieldCapacity", 450.0),
    (587, "armorHP", 450.0),
    (587, "hp", 350.0),
    (587, "capacitorCapacity", 250.0),
    (587, "maxVelocity", 365.0),
    (597, "shieldCapacity", 350.0),
    (597, "armorHP", 500.0),
    (597, "hp", 450.0),
    (597, "capacitorCapacity", 400.0),
    (597, "maxVelocity", 355.0),
    (587, "shieldRechargeRate", 625000.0),
    (587, "rechargeRate", 125000.0),
    (597, "shieldRechargeRate", 625000.0),
    (597, "rechargeRate", 160000.0),
    (29986, "shieldCapacity", 1800.0),
    (29986, "armorHP", 2900.0),
    (29986, "hp", 1800.0),
    (29986, "capacitorCapacity", 1800.0),
    (29986, "maxVelocity", 185.0),
    (638, "shieldCapacity", 7700.0),
    (638, "armorHP", 6380.0),
    (638, "hp", 7040.0),
    (638, "capacitorCapacity", 5500.0),
    (638, "maxVelocity", 113.0),
    (3532, "capacitorCapacity", 187.5),
    (11172, "capacitorCapacity", 218.75),
    (78333, "maxVelocity", 322.3),
    (2048, None, None),
    (31668, None, None),
    (45623, None, None),
]

# Base ship resonance oracle pins (docs/ship-resistances-design.md
# section 3): each value read directly from
# dgmTypeAttributes.csv.bz2 during design. Tuple shape:
# (typeId, key-or-None, expected value-or-None). A None key means
# none of the twelve new keys may be present on that row at all.
# Rifter 587 also carries the 974-977 decoy rows at 1.0, which
# must not appear under any key (tripwire).
RESIST_ORACLES = [
    (587, "shieldEmDamageResonance", 1.0),
    (587, "shieldThermalDamageResonance", 0.8),
    (587, "shieldKineticDamageResonance", 0.6),
    (587, "shieldExplosiveDamageResonance", 0.5),
    (587, "armorEmDamageResonance", 0.4),
    (587, "armorThermalDamageResonance", 0.65),
    (587, "armorKineticDamageResonance", 0.75),
    (587, "armorExplosiveDamageResonance", 0.9),
    (587, "emDamageResonance", 0.67),
    (587, "thermalDamageResonance", 0.67),
    (587, "kineticDamageResonance", 0.67),
    (587, "explosiveDamageResonance", 0.67),
    (597, "shieldEmDamageResonance", 1.0),
    (597, "shieldThermalDamageResonance", 0.8),
    (597, "shieldKineticDamageResonance", 0.6),
    (597, "shieldExplosiveDamageResonance", 0.5),
    (597, "armorEmDamageResonance", 0.5),
    (597, "armorThermalDamageResonance", 0.65),
    (597, "armorKineticDamageResonance", 0.75),
    (597, "armorExplosiveDamageResonance", 0.8),
    (597, "emDamageResonance", 0.67),
    (597, "thermalDamageResonance", 0.67),
    (597, "kineticDamageResonance", 0.67),
    (597, "explosiveDamageResonance", 0.67),
    (32209, "armorEmDamageResonance", 0.1),
    (32209, "armorThermalDamageResonance", 0.325),
    (32209, "shieldEmDamageResonance", 1.0),
    (29986, "armorExplosiveDamageResonance", 0.4),
    (29986, "armorKineticDamageResonance", 0.5625),
    (29986, "shieldExplosiveDamageResonance", 0.25),
    (29986, "shieldKineticDamageResonance", 0.45),
    (11957, "armorKineticDamageResonance", 0.46875),
    (11957, "armorThermalDamageResonance", 0.20625),
    (2048, None, None),
    (31668, None, None),
    (45623, None, None),
]

# Bay oracles (docs/bay-capacities-design.md section 3.3): each
# value read directly from invTypes.csv.bz2 / dgmTypeAttributes.csv.bz2
# during design. Tuple shape mirrors RESIST_ORACLES:
# (typeId, key-or-None, expected-or-None). A None key means the key
# must be absent from that row.
BAY_ORACLES = [
    (587, "cargoCapacity", 140.0),
    (587, "droneCapacity", 0.0),
    (587, "droneBandwidth", 0.0),
    (587, "volume", 27289.0),
    (593, "cargoCapacity", 140.0),
    (593, "droneCapacity", 40.0),
    (593, "droneBandwidth", 25.0),
    (638, "cargoCapacity", 830.0),
    (638, "droneCapacity", 75.0),
    (638, "droneBandwidth", 50.0),
    (670, "cargoCapacity", 0.0),
    (2863, "cargoCapacity", 100.0),
    (23911, "fighterCapacity", 70000.0),
    (23911, "cargoCapacity", 875.0),
    (23911, "droneCapacity", 0.0),
    (45647, "fighterCapacity", 40000.0),
    (45647, "cargoCapacity", 2750.0),
    (2456, "volume", 5.0),
    (2456, "droneBandwidthUsed", 5.0),
    (2488, "volume", 5.0),
    (2488, "droneBandwidthUsed", 5.0),
    (34, "volume", 0.01),
    (185, "volume", 0.0025),
    (28668, "volume", 0.01),
    (40556, "volume", 1000.0),
    (23059, "volume", 1000.0),
    (60478, "volume", 5.0),
    (587, "fighterCapacity", None),
    (593, "fighterCapacity", None),
    (2863, "droneCapacity", None),
    (2863, "droneBandwidth", None),
    (2863, "fighterCapacity", None),
    (60478, "droneBandwidthUsed", None),
    (60479, "droneBandwidthUsed", None),
    (60480, "droneBandwidthUsed", None),
    (60481, "droneBandwidthUsed", None),
    (2456, "cargoCapacity", None),
    (34, "cargoCapacity", None),
    (34, "droneBandwidthUsed", None),
    (587, "droneBandwidthUsed", None),
]

# Calibration oracles (docs/rig-calibration-design.md section 3.3):
# each value read directly from dgmTypeAttributes.csv.bz2 during
# design. Tuple shape mirrors BAY_ORACLES: (typeId, key,
# expected-or-None). A None expected means the key must be absent.
CALIBRATION_ORACLES = [
    (587, "upgradeCapacity", 400.0),
    (597, "upgradeCapacity", 400.0),
    (3514, "upgradeCapacity", 350.0),
    (635, "upgradeCapacity", 300.0),
    (672, "upgradeCapacity", 1.0),
    (588, "upgradeCapacity", 0.0),
    (670, "upgradeCapacity", None),
    (2863, "upgradeCapacity", None),
    (33328, "upgradeCapacity", None),
    (31668, "upgradeCost", 200.0),
    (25736, "upgradeCost", 50.0),
    (4395, "upgradeCost", 150.0),
    (4399, "upgradeCost", 300.0),
    (37146, "upgradeCost", 100.0),
    (37147, "upgradeCost", 150.0),
    (587, "upgradeCost", None),
    (31668, "upgradeCapacity", None),
    (37146, "upgradeCapacity", None),
    (2048, "upgradeCost", None),
    (35825, "upgradeCapacity", None),
]

# Slot layout oracles (docs/slot-layout-design.md section 3.3):
# each value read directly from dgmTypeAttributes.csv.bz2 /
# dgmTypeEffects.csv.bz2 during design. Tuple shape mirrors
# CALIBRATION_ORACLES: (typeId, key, expected-or-None). A None
# expected means the key must be absent from that row.
SLOT_LAYOUT_ORACLES = [
    # Rifter 587: low 4.0, med 3.0, high 3.0, launcher 2.0,
    # turret 3.0, rig 3.0, maxSubSystems absent.
    (587, "lowSlots", 4.0),
    (587, "medSlots", 3.0),
    (587, "hiSlots", 3.0),
    (587, "launcherSlotsLeft", 2.0),
    (587, "turretSlotsLeft", 3.0),
    (587, "rigSlots", 3.0),
    (587, "maxSubSystems", None),
    # Osprey 620: 3.0 / 5.0 / 5.0 / 2.0 / 1.0 / 3.0 / absent.
    (620, "lowSlots", 3.0),
    (620, "medSlots", 5.0),
    (620, "hiSlots", 5.0),
    (620, "launcherSlotsLeft", 2.0),
    (620, "turretSlotsLeft", 1.0),
    (620, "rigSlots", 3.0),
    (620, "maxSubSystems", None),
    # Raven 638: 5.0 / 7.0 / 7.0 / 6.0 / 4.0 / 3.0 / absent.
    (638, "lowSlots", 5.0),
    (638, "medSlots", 7.0),
    (638, "hiSlots", 7.0),
    (638, "launcherSlotsLeft", 6.0),
    (638, "turretSlotsLeft", 4.0),
    (638, "rigSlots", 3.0),
    (638, "maxSubSystems", None),
    # Erebus 671: 7.0 / 6.0 / 8.0 / 0.0 / 6.0 / 3.0 / absent.
    (671, "lowSlots", 7.0),
    (671, "medSlots", 6.0),
    (671, "hiSlots", 8.0),
    (671, "launcherSlotsLeft", 0.0),
    (671, "turretSlotsLeft", 6.0),
    (671, "rigSlots", 3.0),
    (671, "maxSubSystems", None),
    # Legion 29986 (and identically 29984 Tengu, 29988 Proteus,
    # 29990 Loki): 0.0 / 0.0 / 0.0 / 0.0 / 0.0 / 3.0 / 5.0.
    (29986, "lowSlots", 0.0),
    (29986, "medSlots", 0.0),
    (29986, "hiSlots", 0.0),
    (29986, "launcherSlotsLeft", 0.0),
    (29986, "turretSlotsLeft", 0.0),
    (29986, "rigSlots", 3.0),
    (29986, "maxSubSystems", 5.0),
    (29984, "maxSubSystems", 5.0),
    (29988, "maxSubSystems", 5.0),
    (29990, "maxSubSystems", 5.0),
    # Capsule 670: low/med/high/rig/maxSubSystems absent,
    # launcherSlotsLeft 0.0 present, turretSlotsLeft 0.0 present.
    # (33328 identical on presence.)
    (670, "lowSlots", None),
    (670, "medSlots", None),
    (670, "hiSlots", None),
    (670, "rigSlots", None),
    (670, "maxSubSystems", None),
    (670, "launcherSlotsLeft", 0.0),
    (670, "turretSlotsLeft", 0.0),
    (33328, "lowSlots", None),
    (33328, "medSlots", None),
    (33328, "hiSlots", None),
    (33328, "rigSlots", None),
    (33328, "maxSubSystems", None),
    (33328, "launcherSlotsLeft", 0.0),
    (33328, "turretSlotsLeft", 0.0),
    # Primae 2863: turretSlotsLeft absent, rigSlots absent,
    # medSlots 0.0, hiSlots 0.0, lowSlots 4.0,
    # launcherSlotsLeft 0.0. Noctis 2998: turretSlotsLeft
    # absent, high 8.0, rig 3.0.
    (2863, "turretSlotsLeft", None),
    (2863, "rigSlots", None),
    (2863, "medSlots", 0.0),
    (2863, "hiSlots", 0.0),
    (2863, "lowSlots", 4.0),
    (2863, "launcherSlotsLeft", 0.0),
    (2998, "turretSlotsLeft", None),
    (2998, "hiSlots", 8.0),
    (2998, "rigSlots", 3.0),
    # Echelon 3532 present-zero pin: lowSlots 0.0 and hiSlots
    # 0.0 present.
    (3532, "lowSlots", 0.0),
    (3532, "hiSlots", 0.0),
    # Reaper 588 un-chosen-source pin: rigSlots absent even
    # though 1154 = 0.0 exists in the cache.
    (588, "rigSlots", None),
    (596, "rigSlots", None),
    (601, "rigSlots", None),
    (606, "rigSlots", None),
    (33079, "rigSlots", None),
    (33081, "rigSlots", None),
    (33083, "rigSlots", None),
    # Punisher 597 (demo hull): launcherSlotsLeft 0.0 present,
    # turretSlotsLeft 4.0, low 5.0, med 2.0, high 4.0, rig 3.0.
    (597, "launcherSlotsLeft", 0.0),
    (597, "turretSlotsLeft", 4.0),
    (597, "lowSlots", 5.0),
    (597, "medSlots", 2.0),
    (597, "hiSlots", 4.0),
    (597, "rigSlots", 3.0),
    # Category gates: module, rig, subsystem, and material rows
    # carry none of the seven ship keys.
    (2048, "hiSlots", None),
    (2048, "medSlots", None),
    (2048, "lowSlots", None),
    (2048, "rigSlots", None),
    (2048, "maxSubSystems", None),
    (2048, "turretSlotsLeft", None),
    (2048, "launcherSlotsLeft", None),
    (31668, "hiSlots", None),
    (31668, "medSlots", None),
    (31668, "lowSlots", None),
    (31668, "rigSlots", None),
    (31668, "maxSubSystems", None),
    (31668, "turretSlotsLeft", None),
    (31668, "launcherSlotsLeft", None),
    (45623, "hiSlots", None),
    (45623, "medSlots", None),
    (45623, "lowSlots", None),
    (45623, "rigSlots", None),
    (45623, "maxSubSystems", None),
    (45623, "turretSlotsLeft", None),
    (45623, "launcherSlotsLeft", None),
    (34, "hiSlots", None),
    (34, "medSlots", None),
    (34, "lowSlots", None),
    (34, "rigSlots", None),
    (34, "maxSubSystems", None),
    (34, "turretSlotsLeft", None),
    (34, "launcherSlotsLeft", None),
    # Markers: effect 42 turretFitted / effect 40
    # launcherFitted.
    (2889, "turretFitted", True),
    (2889, "launcherFitted", None),
    (499, "launcherFitted", True),
    (499, "turretFitted", None),
    (10631, "launcherFitted", True),
    (2410, "launcherFitted", True),
    # 405 carries neither marker (known neither).
    (405, "turretFitted", None),
    (405, "launcherFitted", None),
    # Decoy pins: attribute 47 present, markers absent.
    (27914, "turretFitted", None),
    (27914, "launcherFitted", None),
    (24348, "turretFitted", None),
    (24348, "launcherFitted", None),
    (60313, "turretFitted", None),
    (60313, "launcherFitted", None),
    (443, "turretFitted", None),
    (443, "launcherFitted", None),
    # False-negative pin: 37450 carries turretFitted true
    # with no 47 row.
    (37450, "turretFitted", True),
    # Category-66 pin: no category gate.
    (35921, "launcherFitted", True),
    # 587 carries neither marker key.
    (587, "turretFitted", None),
    (587, "launcherFitted", None),
]

# Expected slot layout key counts (design section 3.1).
SLOT_LAYOUT_EXPECTED_COUNTS = {
    "hiSlots": 402,
    "medSlots": 402,
    "lowSlots": 402,
    "rigSlots": 380,
    "maxSubSystems": 4,
    "turretSlotsLeft": 402,
    "launcherSlotsLeft": 404,
    "turretFitted": 658,
    "launcherFitted": 147,
}

# Pinned tech-3 carrier set (design section 3.4).
TECH3_CARRIER_SET = {29984, 29986, 29988, 29990}

# Navigation and targeting oracles (docs/nav-targeting-design.md
# section 7): each value read directly from
# dgmTypeAttributes.csv.bz2 / invTypes.csv.bz2 during design.
# Tuple shape mirrors CALIBRATION_ORACLES: (typeId, key,
# expected-or-None). A None expected means the key must be
# absent from that row.
NAV_TARGETING_ORACLES = [
    # Rifter 587: warp 5.0, agility 3.2, mass 1067000.0,
    # signature 35.0, range 22500.0, scan 660.0,
    # sensors 0.0/8.0/0.0/0.0, targets 4.0.
    (587, "warpSpeedMultiplier", 5.0),
    (587, "agility", 3.2),
    (587, "mass", 1067000.0),
    (587, "signatureRadius", 35.0),
    (587, "maxTargetRange", 22500.0),
    (587, "scanResolution", 660.0),
    (587, "scanRadarStrength", 0.0),
    (587, "scanLadarStrength", 8.0),
    (587, "scanMagnetometricStrength", 0.0),
    (587, "scanGravimetricStrength", 0.0),
    (587, "maxLockedTargets", 4.0),
    # Punisher 597: warp 5.0, agility 2.9, mass 1190000.0,
    # signature 37.0, range 25000.0, scan 640.0,
    # sensors 10.0/0.0/0.0/0.0, targets 4.0.
    (597, "warpSpeedMultiplier", 5.0),
    (597, "agility", 2.9),
    (597, "mass", 1190000.0),
    (597, "signatureRadius", 37.0),
    (597, "maxTargetRange", 25000.0),
    (597, "scanResolution", 640.0),
    (597, "scanRadarStrength", 10.0),
    (597, "scanLadarStrength", 0.0),
    (597, "scanMagnetometricStrength", 0.0),
    (597, "scanGravimetricStrength", 0.0),
    (597, "maxLockedTargets", 4.0),
    # Capsule 670 explicit zeros + absence: range 0.0 present,
    # targets 0.0 present, scanResolution absent.
    (670, "maxTargetRange", 0.0),
    (670, "maxLockedTargets", 0.0),
    (670, "scanResolution", None),
    (670, "scanRadarStrength", 0.0),
    (670, "scanLadarStrength", 3.0),
    (670, "scanMagnetometricStrength", 0.0),
    (670, "scanGravimetricStrength", 0.0),
    # Zephyr 2078 scanResolution absence pin.
    (2078, "scanResolution", None),
    # Apotheosis 29266 all-four-positive sensor pin + absence.
    (29266, "scanRadarStrength", 10.0),
    (29266, "scanLadarStrength", 10.0),
    (29266, "scanMagnetometricStrength", 10.0),
    (29266, "scanGravimetricStrength", 10.0),
    (29266, "scanResolution", None),
    # Category gates: module and commodity rows carry none of
    # the eleven keys.
    (2048, "warpSpeedMultiplier", None),
    (2048, "agility", None),
    (2048, "signatureRadius", None),
    (2048, "maxTargetRange", None),
    (2048, "scanResolution", None),
    (2048, "scanRadarStrength", None),
    (2048, "scanLadarStrength", None),
    (2048, "scanMagnetometricStrength", None),
    (2048, "scanGravimetricStrength", None),
    (2048, "maxLockedTargets", None),
    (2048, "mass", None),
    (34, "warpSpeedMultiplier", None),
    (34, "agility", None),
    (34, "signatureRadius", None),
    (34, "maxTargetRange", None),
    (34, "scanResolution", None),
    (34, "scanRadarStrength", None),
    (34, "scanLadarStrength", None),
    (34, "scanMagnetometricStrength", None),
    (34, "scanGravimetricStrength", None),
    (34, "maxLockedTargets", None),
    (34, "mass", None),
]

# Expected navigation and targeting key counts (design section 3).
NAV_TARGETING_EXPECTED_COUNTS = {
    "warpSpeedMultiplier": 404,
    "agility": 404,
    "signatureRadius": 404,
    "maxTargetRange": 404,
    "scanResolution": 390,
    "scanRadarStrength": 404,
    "scanLadarStrength": 404,
    "scanMagnetometricStrength": 404,
    "scanGravimetricStrength": 404,
    "maxLockedTargets": 404,
    "mass": 404,
}

_STACKED_SUFFIX_RE = re.compile(r" x[0-9]+$")


def normalize(name):
    return " ".join(name.lower().split())


def fail(message):
    print(f"VALIDATION: {message}", file=sys.stderr)
    sys.exit(1)


def load_csv(path):
    with bz2.BZ2File(path, "rb") as handle:
        text = handle.read().decode("utf-8")
    return list(csv.DictReader(StringIO(text)))


def main():
    cache_dir = os.path.join("scripts", "sde")
    for key, filename in CACHES.items():
        path = os.path.join(cache_dir, filename)
        if not os.path.exists(path):
            print(
                f"missing committed cache {path}; this generator never "
                "downloads — fetch the cache and re-run",
                file=sys.stderr,
            )
            sys.exit(1)

    inv_types = load_csv(os.path.join(cache_dir, CACHES["invTypes"]))
    inv_groups = load_csv(os.path.join(cache_dir, CACHES["invGroups"]))
    type_effects = load_csv(os.path.join(cache_dir, CACHES["dgmTypeEffects"]))
    type_attributes = load_csv(
        os.path.join(cache_dir, CACHES["dgmTypeAttributes"])
    )

    group_to_category = {}
    for row in inv_groups:
        group_to_category[int(row["groupID"])] = int(row["categoryID"])

    # Published category-6 type ids, for the navigation and
    # targeting negative/integral gate below (see its comment).
    category6_ship_ids = {
        int(row["typeID"])
        for row in inv_types
        if row["published"] == "1"
        and int(row["typeID"]) > 0
        and row["typeName"].strip()
        and group_to_category.get(int(row["groupID"])) == 6
    }

    effects_by_type = defaultdict(set)
    for row in type_effects:
        effects_by_type[int(row["typeID"])].add(int(row["effectID"]))

    # Base resource attributes per type (design section 5): only the
    # four locked attributes, each parsed from valueFloat. An
    # unparseable, duplicated, non-finite, or negative wanted row
    # fails loudly and writes nothing.
    resources_by_type = {}
    seen_resource_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in RESOURCE_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_resource_keys:
            fail(
                f"duplicate resource row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable resource value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite resource value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative resource value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_resource_keys.add(key)
        resources_by_type.setdefault(type_id, {})[attribute_id] = value

    # Base ship attributes per type (design section 3): only the
    # five locked attributes, each parsed from valueFloat. An
    # unparseable, duplicated, non-finite, or negative wanted row
    # fails loudly and writes nothing.
    base_stats_by_type = {}
    seen_base_stat_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in BASE_STAT_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_base_stat_keys:
            fail(
                f"duplicate ship base stat row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable ship base stat value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite ship base stat value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative ship base stat value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_base_stat_keys.add(key)
        base_stats_by_type.setdefault(type_id, {})[attribute_id] = value

    # Base ship resonances per type (design section 3): only the
    # twelve locked attributes, each parsed from valueFloat. An
    # unparseable, duplicated, non-finite, or negative wanted row
    # fails loudly and writes nothing. A value above 1 is NOT a
    # failure: the scan also sees unpublished NPC rows carrying
    # 1.1/1.2/7.0, and such a resonance renders its true signed
    # percent (design section 2).
    resonances_by_type = {}
    seen_resonance_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in RESIST_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_resonance_keys:
            fail(
                f"duplicate ship resistance row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable ship resistance value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite ship resistance value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative ship resistance value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_resonance_keys.add(key)
        resonances_by_type.setdefault(type_id, {})[attribute_id] = value

    # Bay attributes per type (design section 3): only the four
    # locked attributes, each parsed from valueFloat. An
    # unparseable, duplicated, non-finite, or negative wanted row
    # fails loudly and writes nothing.
    bays_by_type = {}
    seen_bay_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in BAY_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_bay_keys:
            fail(
                f"duplicate bay row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable bay value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite bay value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative bay value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_bay_keys.add(key)
        bays_by_type.setdefault(type_id, {})[attribute_id] = value

    # Rig calibration attributes per type (design section 3.1):
    # only the two locked attributes, each parsed from
    # valueFloat. An unparseable, duplicated, non-finite, or
    # negative wanted row fails loudly and writes nothing.
    calibrations_by_type = {}
    seen_calibration_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in CALIBRATION_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_calibration_keys:
            fail(
                f"duplicate calibration row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable calibration value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite calibration value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative calibration value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_calibration_keys.add(key)
        calibrations_by_type.setdefault(type_id, {})[attribute_id] = value

    # Slot layout attributes per type (design section 3.1):
    # only the seven locked attributes, each parsed from
    # valueFloat. An unparseable, duplicated, non-finite,
    # negative, or non-integral wanted row fails loudly and
    # writes nothing. Integrality is locked: every cached
    # value of all seven attributes is an integral float.
    slot_layouts_by_type = {}
    seen_slot_layout_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in SLOT_LAYOUT_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_slot_layout_keys:
            fail(
                f"duplicate slot layout row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable slot layout value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite slot layout value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative slot layout value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if float(value).is_integer() is False:
            fail(
                f"non-integral slot layout value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_slot_layout_keys.add(key)
        slot_layouts_by_type.setdefault(type_id, {})[attribute_id] = value

    # Base warp speed (design section 2.1): dogma 1281 is read
    # only for the constant-1.0 tripwire. Fail-loud on duplicate,
    # unparseable, or non-finite rows; the per-row == 1.0 check
    # runs in the type loop where category is known. Never
    # emitted.
    base_warp_by_type = {}
    seen_base_warp_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id != BASE_WARP_SPEED_ATTR:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_base_warp_keys:
            fail(
                f"duplicate base warp speed row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable base warp speed value "
                f"{row['valueFloat']!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite base warp speed value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_base_warp_keys.add(key)
        base_warp_by_type[type_id] = value

    # Navigation and targeting attributes per type (design
    # section 3): only the ten locked attributes, each parsed
    # from valueFloat. An unparseable, duplicated, or
    # non-finite wanted row fails loudly and writes nothing.
    # Attribute 192 additionally fails loud on non-integral
    # values (the pure layer renders it as an integer count).
    # DEVIATION from design section 3 ("existing shape binds
    # negative/integral globally"): negative/integral checks
    # are gated below on `category6_ship_ids`, because
    # attribute 76 carries -20000.0 on four category-32
    # subsystem rows (45610/45613/45616/45619) — subsystem
    # modifier rows that are never emitted — which a global
    # check would fail on. The gate preserves design intent:
    # any row that can be emitted is validated, and nothing
    # that is validated differently can ever render.
    nav_targeting_by_type = {}
    seen_nav_targeting_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in NAV_TARGETING_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_nav_targeting_keys:
            fail(
                f"duplicate navigation and targeting row "
                f"(type {type_id}, attribute {attribute_id}) in "
                "dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable navigation and targeting value "
                f"{row['valueFloat']!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite navigation and targeting value "
                f"{value!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if value < 0 and type_id in category6_ship_ids:
            fail(
                f"negative navigation and targeting value "
                f"{value!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if (
            attribute_id == MAX_LOCKED_TARGETS_ATTR
            and float(value).is_integer() is False
            and type_id in category6_ship_ids
        ):
            fail(
                f"non-integral navigation and targeting value "
                f"{value!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        seen_nav_targeting_keys.add(key)
        nav_targeting_by_type.setdefault(type_id, {})[attribute_id] = value

    types = []
    missing_group = 0
    resource_key_counts = Counter()
    base_stat_key_counts = Counter()
    resonance_key_counts = Counter()
    bay_key_counts = Counter()
    calibration_key_counts = Counter()
    slot_layout_key_counts = Counter()
    nav_targeting_key_counts = Counter()
    for row in inv_types:
        if row["published"] != "1":
            continue
        type_id = int(row["typeID"])
        name = row["typeName"]
        if type_id <= 0 or not name.strip():
            continue
        category_id = group_to_category.get(int(row["groupID"]))
        if category_id is None:
            missing_group += 1
            category_id = 0
        slot_effects = sorted(
            effects_by_type.get(type_id, set()) & SLOT_EFFECT_IDS
        )
        entry = {
            "typeId": type_id,
            "typeName": name,
            "categoryId": category_id,
            "slotEffects": slot_effects,
        }
        # Additive, sparse resource emission (design section 5):
        # category 6 rows gain ship outputs, category 7 rows with a
        # slot effect gain module needs, after the four existing keys
        # in their existing order. Every other row is byte-identical.
        resources = resources_by_type.get(type_id, {})
        if category_id == 6:
            if SHIP_CPU_OUTPUT_ATTR in resources:
                entry["cpuOutput"] = resources[SHIP_CPU_OUTPUT_ATTR]
                resource_key_counts["cpuOutput"] += 1
            if SHIP_POWER_OUTPUT_ATTR in resources:
                entry["powerOutput"] = resources[SHIP_POWER_OUTPUT_ATTR]
                resource_key_counts["powerOutput"] += 1
            # Additive, sparse base ship stat emission (design
            # section 3): category 6 rows gain the five stats
            # after the resource keys in their existing order.
            # Every other row is byte-identical.
            base_stats = base_stats_by_type.get(type_id, {})
            if SHIELD_CAPACITY_ATTR in base_stats:
                entry["shieldCapacity"] = base_stats[SHIELD_CAPACITY_ATTR]
                base_stat_key_counts["shieldCapacity"] += 1
            if ARMOR_HP_ATTR in base_stats:
                entry["armorHP"] = base_stats[ARMOR_HP_ATTR]
                base_stat_key_counts["armorHP"] += 1
            if HULL_HP_ATTR in base_stats:
                entry["hp"] = base_stats[HULL_HP_ATTR]
                base_stat_key_counts["hp"] += 1
            if CAPACITOR_CAPACITY_ATTR in base_stats:
                entry["capacitorCapacity"] = base_stats[CAPACITOR_CAPACITY_ATTR]
                base_stat_key_counts["capacitorCapacity"] += 1
            if MAX_VELOCITY_ATTR in base_stats:
                entry["maxVelocity"] = base_stats[MAX_VELOCITY_ATTR]
                base_stat_key_counts["maxVelocity"] += 1
            if SHIELD_RECHARGE_ATTR in base_stats:
                entry["shieldRechargeRate"] = base_stats[SHIELD_RECHARGE_ATTR]
                base_stat_key_counts["shieldRechargeRate"] += 1
            if CAPACITOR_RECHARGE_ATTR in base_stats:
                entry["rechargeRate"] = base_stats[CAPACITOR_RECHARGE_ATTR]
                base_stat_key_counts["rechargeRate"] += 1
            # Additive, sparse base ship resonance emission
            # (design section 3): category 6 rows gain the twelve
            # resonances, as resonances never pre-converted, after
            # the base stat keys in this locked key order.
            # Every other row is byte-identical.
            resonances = resonances_by_type.get(type_id, {})
            if SHIELD_EM_RESONANCE_ATTR in resonances:
                entry["shieldEmDamageResonance"] = resonances[SHIELD_EM_RESONANCE_ATTR]
                resonance_key_counts["shieldEmDamageResonance"] += 1
            if SHIELD_THERMAL_RESONANCE_ATTR in resonances:
                entry["shieldThermalDamageResonance"] = resonances[SHIELD_THERMAL_RESONANCE_ATTR]
                resonance_key_counts["shieldThermalDamageResonance"] += 1
            if SHIELD_KINETIC_RESONANCE_ATTR in resonances:
                entry["shieldKineticDamageResonance"] = resonances[SHIELD_KINETIC_RESONANCE_ATTR]
                resonance_key_counts["shieldKineticDamageResonance"] += 1
            if SHIELD_EXPLOSIVE_RESONANCE_ATTR in resonances:
                entry["shieldExplosiveDamageResonance"] = resonances[SHIELD_EXPLOSIVE_RESONANCE_ATTR]
                resonance_key_counts["shieldExplosiveDamageResonance"] += 1
            if ARMOR_EM_RESONANCE_ATTR in resonances:
                entry["armorEmDamageResonance"] = resonances[ARMOR_EM_RESONANCE_ATTR]
                resonance_key_counts["armorEmDamageResonance"] += 1
            if ARMOR_THERMAL_RESONANCE_ATTR in resonances:
                entry["armorThermalDamageResonance"] = resonances[ARMOR_THERMAL_RESONANCE_ATTR]
                resonance_key_counts["armorThermalDamageResonance"] += 1
            if ARMOR_KINETIC_RESONANCE_ATTR in resonances:
                entry["armorKineticDamageResonance"] = resonances[ARMOR_KINETIC_RESONANCE_ATTR]
                resonance_key_counts["armorKineticDamageResonance"] += 1
            if ARMOR_EXPLOSIVE_RESONANCE_ATTR in resonances:
                entry["armorExplosiveDamageResonance"] = resonances[ARMOR_EXPLOSIVE_RESONANCE_ATTR]
                resonance_key_counts["armorExplosiveDamageResonance"] += 1
            if HULL_EM_RESONANCE_ATTR in resonances:
                entry["emDamageResonance"] = resonances[HULL_EM_RESONANCE_ATTR]
                resonance_key_counts["emDamageResonance"] += 1
            if HULL_THERMAL_RESONANCE_ATTR in resonances:
                entry["thermalDamageResonance"] = resonances[HULL_THERMAL_RESONANCE_ATTR]
                resonance_key_counts["thermalDamageResonance"] += 1
            if HULL_KINETIC_RESONANCE_ATTR in resonances:
                entry["kineticDamageResonance"] = resonances[HULL_KINETIC_RESONANCE_ATTR]
                resonance_key_counts["kineticDamageResonance"] += 1
            if HULL_EXPLOSIVE_RESONANCE_ATTR in resonances:
                entry["explosiveDamageResonance"] = resonances[HULL_EXPLOSIVE_RESONANCE_ATTR]
                resonance_key_counts["explosiveDamageResonance"] += 1
        elif category_id == 7 and slot_effects:
            if MODULE_CPU_NEED_ATTR in resources:
                entry["cpu"] = resources[MODULE_CPU_NEED_ATTR]
                resource_key_counts["cpu"] += 1
            if MODULE_POWER_NEED_ATTR in resources:
                entry["power"] = resources[MODULE_POWER_NEED_ATTR]
                resource_key_counts["power"] += 1
        # Additive bay emission (design section 3.1): new keys
        # append after the existing keys in the locked order
        # volume, cargoCapacity, droneCapacity, droneBandwidth,
        # fighterCapacity, droneBandwidthUsed. `volume` comes from
        # the invTypes `volume` column on every row (validated
        # fail-loud, "0E-10" parses to a present 0.0);
        # `cargoCapacity` comes from the invTypes `capacity`
        # column on every category 6 row; the four dogma keys are
        # sparse, present exactly when a source row exists.
        try:
            volume_value = float(row["volume"])
        except (TypeError, ValueError):
            fail(
                f"unparseable volume value {row['volume']!r} "
                f"for type {type_id}"
            )
        if not math.isfinite(volume_value):
            fail(
                f"non-finite volume value {volume_value!r} for "
                f"type {type_id}"
            )
        if volume_value < 0:
            fail(
                f"negative volume value {volume_value!r} for "
                f"type {type_id}"
            )
        entry["volume"] = volume_value
        bay_key_counts["volume"] += 1
        if category_id == 6:
            try:
                cargo_capacity_value = float(row["capacity"])
            except (TypeError, ValueError):
                fail(
                    f"unparseable capacity value {row['capacity']!r} "
                    f"for type {type_id}"
                )
            if not math.isfinite(cargo_capacity_value):
                fail(
                    f"non-finite capacity value {cargo_capacity_value!r} "
                    f"for type {type_id}"
                )
            if cargo_capacity_value < 0:
                fail(
                    f"negative capacity value {cargo_capacity_value!r} "
                    f"for type {type_id}"
                )
            entry["cargoCapacity"] = cargo_capacity_value
            bay_key_counts["cargoCapacity"] += 1
            bays = bays_by_type.get(type_id, {})
            if DRONE_CAPACITY_ATTR in bays:
                entry["droneCapacity"] = bays[DRONE_CAPACITY_ATTR]
                bay_key_counts["droneCapacity"] += 1
            if DRONE_BANDWIDTH_ATTR in bays:
                entry["droneBandwidth"] = bays[DRONE_BANDWIDTH_ATTR]
                bay_key_counts["droneBandwidth"] += 1
            if FIGHTER_CAPACITY_ATTR in bays:
                entry["fighterCapacity"] = bays[FIGHTER_CAPACITY_ATTR]
                bay_key_counts["fighterCapacity"] += 1
        bays = bays_by_type.get(type_id, {})
        if DRONE_BANDWIDTH_USED_ATTR in bays:
            # Sparse wherever a 1272 row exists; the loader
            # invariant asserts every such row is category 18.
            entry["droneBandwidthUsed"] = bays[DRONE_BANDWIDTH_USED_ATTR]
            bay_key_counts["droneBandwidthUsed"] += 1
        # Additive calibration emission (design section 3.1):
        # new keys append after the bay keys in the locked order
        # upgradeCapacity, upgradeCost. Each row gains at most one.
        calibrations = calibrations_by_type.get(type_id, {})
        if category_id == 6 and SHIP_CALIBRATION_ATTR in calibrations:
            entry["upgradeCapacity"] = calibrations[SHIP_CALIBRATION_ATTR]
            calibration_key_counts["upgradeCapacity"] += 1
        if slot_effects == [2663] and RIG_CALIBRATION_ATTR in calibrations:
            entry["upgradeCost"] = calibrations[RIG_CALIBRATION_ATTR]
            calibration_key_counts["upgradeCost"] += 1
        # Additive slot layout emission (design section 3.1):
        # nine keys append after the calibration keys in the
        # locked order hiSlots, medSlots, lowSlots, rigSlots,
        # maxSubSystems, turretSlotsLeft, launcherSlotsLeft,
        # turretFitted, launcherFitted. The seven ship keys are
        # sparse by presence on category 6 rows only; the two
        # markers are sparse true-only on any published row with
        # no category gate.
        layouts = slot_layouts_by_type.get(type_id, {})
        if category_id == 6:
            if HI_SLOTS_ATTR in layouts:
                entry["hiSlots"] = layouts[HI_SLOTS_ATTR]
                slot_layout_key_counts["hiSlots"] += 1
            if MED_SLOTS_ATTR in layouts:
                entry["medSlots"] = layouts[MED_SLOTS_ATTR]
                slot_layout_key_counts["medSlots"] += 1
            if LOW_SLOTS_ATTR in layouts:
                entry["lowSlots"] = layouts[LOW_SLOTS_ATTR]
                slot_layout_key_counts["lowSlots"] += 1
            if RIG_SLOTS_ATTR in layouts:
                entry["rigSlots"] = layouts[RIG_SLOTS_ATTR]
                slot_layout_key_counts["rigSlots"] += 1
            if MAX_SUBSYSTEMS_ATTR in layouts:
                entry["maxSubSystems"] = layouts[MAX_SUBSYSTEMS_ATTR]
                slot_layout_key_counts["maxSubSystems"] += 1
            if TURRET_SLOTS_LEFT_ATTR in layouts:
                entry["turretSlotsLeft"] = layouts[TURRET_SLOTS_LEFT_ATTR]
                slot_layout_key_counts["turretSlotsLeft"] += 1
            if LAUNCHER_SLOTS_LEFT_ATTR in layouts:
                entry["launcherSlotsLeft"] = layouts[LAUNCHER_SLOTS_LEFT_ATTR]
                slot_layout_key_counts["launcherSlotsLeft"] += 1
        type_effects_set = effects_by_type.get(type_id, set())
        if TURRET_FITTED_EFFECT in type_effects_set:
            entry["turretFitted"] = True
            slot_layout_key_counts["turretFitted"] += 1
        if LAUNCHER_FITTED_EFFECT in type_effects_set:
            entry["launcherFitted"] = True
            slot_layout_key_counts["launcherFitted"] += 1
        # Additive navigation and targeting emission (design
        # section 3): ten dogma keys append after launcherFitted
        # in the locked order, sparse by presence on category 6
        # rows only, plus `mass` from the invTypes `mass`
        # column on category 6 rows only (fail-loud float
        # parse, the `cargoCapacity` shape). Dogma 1281 is
        # never emitted; the tripwire asserts == 1.0 on every
        # category-6 row (a missing or non-1.0 row fails loud
        # before any wrong number can render).
        if category_id == 6:
            if base_warp_by_type.get(type_id) != 1.0:
                fail(
                    f"ship type {type_id} baseWarpSpeed="
                    f"{base_warp_by_type.get(type_id)!r}, expected 1.0"
                )
            nav_targeting = nav_targeting_by_type.get(type_id, {})
            if WARP_SPEED_MULTIPLIER_ATTR in nav_targeting:
                entry["warpSpeedMultiplier"] = nav_targeting[WARP_SPEED_MULTIPLIER_ATTR]
                nav_targeting_key_counts["warpSpeedMultiplier"] += 1
            if AGILITY_ATTR in nav_targeting:
                entry["agility"] = nav_targeting[AGILITY_ATTR]
                nav_targeting_key_counts["agility"] += 1
            if SIGNATURE_RADIUS_ATTR in nav_targeting:
                entry["signatureRadius"] = nav_targeting[SIGNATURE_RADIUS_ATTR]
                nav_targeting_key_counts["signatureRadius"] += 1
            if MAX_TARGET_RANGE_ATTR in nav_targeting:
                entry["maxTargetRange"] = nav_targeting[MAX_TARGET_RANGE_ATTR]
                nav_targeting_key_counts["maxTargetRange"] += 1
            if SCAN_RESOLUTION_ATTR in nav_targeting:
                entry["scanResolution"] = nav_targeting[SCAN_RESOLUTION_ATTR]
                nav_targeting_key_counts["scanResolution"] += 1
            if SCAN_RADAR_STRENGTH_ATTR in nav_targeting:
                entry["scanRadarStrength"] = nav_targeting[SCAN_RADAR_STRENGTH_ATTR]
                nav_targeting_key_counts["scanRadarStrength"] += 1
            if SCAN_LADAR_STRENGTH_ATTR in nav_targeting:
                entry["scanLadarStrength"] = nav_targeting[SCAN_LADAR_STRENGTH_ATTR]
                nav_targeting_key_counts["scanLadarStrength"] += 1
            if SCAN_MAGNETOMETRIC_STRENGTH_ATTR in nav_targeting:
                entry["scanMagnetometricStrength"] = nav_targeting[SCAN_MAGNETOMETRIC_STRENGTH_ATTR]
                nav_targeting_key_counts["scanMagnetometricStrength"] += 1
            if SCAN_GRAVIMETRIC_STRENGTH_ATTR in nav_targeting:
                entry["scanGravimetricStrength"] = nav_targeting[SCAN_GRAVIMETRIC_STRENGTH_ATTR]
                nav_targeting_key_counts["scanGravimetricStrength"] += 1
            if MAX_LOCKED_TARGETS_ATTR in nav_targeting:
                entry["maxLockedTargets"] = nav_targeting[MAX_LOCKED_TARGETS_ATTR]
                nav_targeting_key_counts["maxLockedTargets"] += 1
            try:
                mass_value = float(row["mass"])
            except (TypeError, ValueError):
                fail(
                    f"unparseable mass value {row['mass']!r} "
                    f"for type {type_id}"
                )
            if not math.isfinite(mass_value):
                fail(
                    f"non-finite mass value {mass_value!r} for "
                    f"type {type_id}"
                )
            if mass_value < 0:
                fail(
                    f"negative mass value {mass_value!r} for "
                    f"type {type_id}"
                )
            entry["mass"] = mass_value
            nav_targeting_key_counts["mass"] += 1
        types.append(entry)

    types.sort(key=lambda entry: entry["typeId"])

    # Self-validation against the section 3 oracles.
    by_id = {entry["typeId"]: entry for entry in types}
    for type_id, type_name, category_id, effect in ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"oracle type {type_id} ({type_name}) missing from extract")
        if entry["typeName"] != type_name:
            fail(
                f"oracle type {type_id} named {entry['typeName']!r}, "
                f"expected {type_name!r}"
            )
        if entry["categoryId"] != category_id:
            fail(
                f"oracle type {type_id} category {entry['categoryId']}, "
                f"expected {category_id}"
            )
        if effect is not None and effect not in entry["slotEffects"]:
            fail(
                f"oracle type {type_id} slotEffects {entry['slotEffects']}, "
                f"expected to contain {effect}"
            )

    # Resource attribute oracles (design section 5). A None key means
    # no resource key may be present on that row at all.
    for type_id, key, expected in RESOURCE_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"resource oracle type {type_id} missing from extract")
        if key is None:
            present = [
                name
                for name in ("cpuOutput", "powerOutput", "cpu", "power")
                if name in entry
            ]
            if present:
                fail(
                    f"resource oracle type {type_id} carries "
                    f"{present}, expected no resource keys"
                )
        elif entry.get(key) != expected:
            fail(
                f"resource oracle type {type_id} {key}="
                f"{entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pin: type 1355 must carry power present as 0.0,
    # never absent (the two are distinct in the locked model).
    zero_power_entry = by_id.get(1355)
    if zero_power_entry is None or "power" not in zero_power_entry:
        fail("resource oracle type 1355 power key must be present as 0.0")

    # Base ship attribute oracles (design section 3). A None key
    # means none of the five new keys may be present at all.
    for type_id, key, expected in SHIP_STAT_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"ship stat oracle type {type_id} missing from extract")
        if key is None:
            present = [
                name
                for name in (
                    "shieldCapacity",
                    "armorHP",
                    "hp",
                    "capacitorCapacity",
                    "maxVelocity",
                    "shieldRechargeRate",
                    "rechargeRate",
                )
                if name in entry
            ]
            if present:
                fail(
                    f"ship stat oracle type {type_id} carries "
                    f"{present}, expected no base stat keys"
                )
        elif entry.get(key) != expected:
            fail(
                f"ship stat oracle type {type_id} {key}="
                f"{entry.get(key)!r}, expected {expected!r}"
            )

    # Base ship resonance oracles (design section 3). A None key
    # means none of the twelve new keys may be present at all.
    for type_id, key, expected in RESIST_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"ship resistance oracle type {type_id} missing from extract")
        if key is None:
            present = [
                name
                for name in (
                    "shieldEmDamageResonance",
                    "shieldThermalDamageResonance",
                    "shieldKineticDamageResonance",
                    "shieldExplosiveDamageResonance",
                    "armorEmDamageResonance",
                    "armorThermalDamageResonance",
                    "armorKineticDamageResonance",
                    "armorExplosiveDamageResonance",
                    "emDamageResonance",
                    "thermalDamageResonance",
                    "kineticDamageResonance",
                    "explosiveDamageResonance",
                )
                if name in entry
            ]
            if present:
                fail(
                    f"ship resistance oracle type {type_id} carries "
                    f"{present}, expected no resistance keys"
                )
        elif entry.get(key) != expected:
            fail(
                f"ship resistance oracle type {type_id} {key}="
                f"{entry.get(key)!r}, expected {expected!r}"
            )

    # Bay oracles (design section 3.3). A None expected value
    # means the key must be absent from that row.
    for type_id, key, expected in BAY_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"bay oracle type {type_id} missing from extract")
        if expected is None:
            if key in entry:
                fail(
                    f"bay oracle type {type_id} carries {key}="
                    f"{entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"bay oracle type {type_id} {key}="
                f"{entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pin: type 670 must carry cargoCapacity
    # present as 0.0, never absent (the two are distinct).
    zero_cargo_entry = by_id.get(670)
    if zero_cargo_entry is None or "cargoCapacity" not in zero_cargo_entry:
        fail("bay oracle type 670 cargoCapacity key must be present as 0.0")

    # Calibration oracles (design section 3.3). A None expected
    # value means the key must be absent from that row.
    for type_id, key, expected in CALIBRATION_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"calibration oracle type {type_id} missing from extract")
        if expected is None:
            if key in entry:
                fail(
                    f"calibration oracle type {type_id} carries {key}="
                    f"{entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"calibration oracle type {type_id} {key}="
                f"{entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pin: type 588 must carry upgradeCapacity
    # present as 0.0, never absent (the two are distinct).
    zero_calibration_entry = by_id.get(588)
    if (
        zero_calibration_entry is None
        or "upgradeCapacity" not in zero_calibration_entry
    ):
        fail(
            "calibration oracle type 588 upgradeCapacity key must be "
            "present as 0.0"
        )

    # Slot layout oracles (design section 3.3). A None expected
    # value means the key must be absent from that row. Markers
    # compare as booleans: the emitted value is JSON true.
    for type_id, key, expected in SLOT_LAYOUT_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"slot layout oracle type {type_id} missing from extract")
        if expected is None:
            if key in entry:
                fail(
                    f"slot layout oracle type {type_id} carries {key}="
                    f"{entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"slot layout oracle type {type_id} {key}="
                f"{entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pin: type 3532 must carry lowSlots and
    # hiSlots present as 0.0, never absent (the two are
    # distinct, the calibration 588 pin style).
    zero_slot_entry = by_id.get(3532)
    if (
        zero_slot_entry is None
        or "lowSlots" not in zero_slot_entry
        or "hiSlots" not in zero_slot_entry
    ):
        fail(
            "slot layout oracle type 3532 lowSlots/hiSlots keys must "
            "be present as 0.0"
        )
    # Un-chosen-source pin: rigSlots must be absent on all
    # seven 1154-only hulls. A regression to 1154 or a 1154
    # fallback fails here (design section 3.3).
    for type_id in (588, 596, 601, 606, 33079, 33081, 33083):
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"slot layout oracle type {type_id} missing from extract")
        if "rigSlots" in entry:
            fail(
                f"slot layout oracle type {type_id} carries rigSlots="
                f"{entry['rigSlots']!r}, expected absent (1154 trap)"
            )

    # Catalogue-wide invariant (design sections 5 and 3): every
    # category-6 row carries both ship outputs and all seven base
    # ship stats, so a future cache refresh that drops a ship row
    # fails loudly instead of blanking that ship.
    for entry in types:
        if entry["categoryId"] == 6 and (
            "cpuOutput" not in entry or "powerOutput" not in entry
        ):
            fail(
                f"ship type {entry['typeId']} missing cpuOutput/powerOutput"
            )
        if entry["categoryId"] == 6 and any(
            key not in entry
            for key in (
                "shieldCapacity",
                "armorHP",
                "hp",
                "capacitorCapacity",
                "maxVelocity",
                "shieldRechargeRate",
                "rechargeRate",
            )
        ):
            fail(
                f"ship type {entry['typeId']} missing base ship stats"
            )
        if entry["categoryId"] == 6 and any(
            key not in entry
            for key in (
                "shieldEmDamageResonance",
                "shieldThermalDamageResonance",
                "shieldKineticDamageResonance",
                "shieldExplosiveDamageResonance",
                "armorEmDamageResonance",
                "armorThermalDamageResonance",
                "armorKineticDamageResonance",
                "armorExplosiveDamageResonance",
                "emDamageResonance",
                "thermalDamageResonance",
                "kineticDamageResonance",
                "explosiveDamageResonance",
            )
        ):
            fail(
                f"ship type {entry['typeId']} missing ship resistances"
            )
        # Bay invariants (design section 3.4): every present bay
        # value is finite and >= 0.0; `volume` is present on every
        # row; `cargoCapacity` is present on every category 6 row
        # and on no other row; the three ship bay keys appear only
        # on category 6 rows (absence is allowed, never required);
        # `droneBandwidthUsed` appears only on category 18 rows.
        # Absence stays distinct from 0.0.
        for key in (
            "volume",
            "cargoCapacity",
            "droneCapacity",
            "droneBandwidth",
            "fighterCapacity",
            "droneBandwidthUsed",
        ):
            if key in entry:
                value = entry[key]
                if (
                    not isinstance(value, (int, float))
                    or isinstance(value, bool)
                    or not math.isfinite(float(value))
                    or float(value) < 0
                ):
                    fail(
                        f"type {entry['typeId']} {key}={value!r} "
                        "is not finite and non-negative"
                    )
        if "volume" not in entry:
            fail(f"type {entry['typeId']} missing volume")
        if entry["categoryId"] == 6 and "cargoCapacity" not in entry:
            fail(f"ship type {entry['typeId']} missing cargoCapacity")
        if entry["categoryId"] != 6 and "cargoCapacity" in entry:
            fail(
                f"non-ship type {entry['typeId']} carries cargoCapacity"
            )
        for key in (
            "droneCapacity",
            "droneBandwidth",
            "fighterCapacity",
        ):
            if key in entry and entry["categoryId"] != 6:
                fail(
                    f"non-ship type {entry['typeId']} carries {key}"
                )
        if "droneBandwidthUsed" in entry and entry["categoryId"] != 18:
            fail(
                f"non-drone type {entry['typeId']} carries "
                "droneBandwidthUsed"
            )
        # Calibration invariants (design section 3.4): every
        # present calibration value is finite and >= 0.0;
        # upgradeCapacity only on category 6 (absence allowed);
        # upgradeCost only on slotEffects == [2663] and on every
        # such row; no row carries both keys.
        for key in ("upgradeCapacity", "upgradeCost"):
            if key in entry:
                value = entry[key]
                if (
                    not isinstance(value, (int, float))
                    or isinstance(value, bool)
                    or not math.isfinite(float(value))
                    or float(value) < 0
                ):
                    fail(
                        f"type {entry['typeId']} {key}={value!r} "
                        "is not finite and non-negative"
                    )
        if "upgradeCapacity" in entry and entry["categoryId"] != 6:
            fail(
                f"non-ship type {entry['typeId']} carries upgradeCapacity"
            )
        if "upgradeCost" in entry and entry["slotEffects"] != [2663]:
            fail(
                f"non-rig type {entry['typeId']} carries upgradeCost"
            )
        if entry["slotEffects"] == [2663] and "upgradeCost" not in entry:
            fail(f"rig type {entry['typeId']} missing upgradeCost")
        if "upgradeCapacity" in entry and "upgradeCost" in entry:
            fail(f"type {entry['typeId']} carries both calibration keys")
        # Slot layout invariants (design section 3.4): every
        # present ship layout value is finite, non-negative,
        # and integral (not a bool); each of the seven keys
        # appears only on category 6 rows (absence allowed,
        # never required); markers are true-only, only on
        # rows whose slotEffects is exactly [12], and never on
        # the same row.
        for key in (
            "hiSlots",
            "medSlots",
            "lowSlots",
            "rigSlots",
            "maxSubSystems",
            "turretSlotsLeft",
            "launcherSlotsLeft",
        ):
            if key in entry:
                value = entry[key]
                if (
                    not isinstance(value, (int, float))
                    or isinstance(value, bool)
                    or not math.isfinite(float(value))
                    or float(value) < 0
                    or float(value).is_integer() is False
                ):
                    fail(
                        f"type {entry['typeId']} {key}={value!r} "
                        "is not finite, non-negative, and integral"
                    )
                if entry["categoryId"] != 6:
                    fail(
                        f"non-ship type {entry['typeId']} carries {key}"
                    )
        for key in ("turretFitted", "launcherFitted"):
            if key in entry and entry[key] is not True:
                fail(
                    f"type {entry['typeId']} {key}={entry[key]!r} "
                    "is not true-only"
                )
        if (
            "turretFitted" in entry or "launcherFitted" in entry
        ) and entry["slotEffects"] != [12]:
            fail(
                f"type {entry['typeId']} carries a hardpoint marker "
                f"without slotEffects [12]: {entry['slotEffects']}"
            )
        if "turretFitted" in entry and "launcherFitted" in entry:
            fail(
                f"type {entry['typeId']} carries both hardpoint markers"
            )
        # Navigation and targeting invariants (design section
        # 3.4): every present nav/targeting value is finite and
        # >= 0.0 (not a bool), `maxLockedTargets` is integral;
        # each of the eleven keys appears only on category 6
        # rows (absence allowed, never required). Absence stays
        # distinct from 0.0.
        for key in (
            "warpSpeedMultiplier",
            "agility",
            "signatureRadius",
            "maxTargetRange",
            "scanResolution",
            "scanRadarStrength",
            "scanLadarStrength",
            "scanMagnetometricStrength",
            "scanGravimetricStrength",
            "maxLockedTargets",
            "mass",
        ):
            if key in entry:
                value = entry[key]
                if (
                    not isinstance(value, (int, float))
                    or isinstance(value, bool)
                    or not math.isfinite(float(value))
                    or float(value) < 0
                ):
                    fail(
                        f"type {entry['typeId']} {key}={value!r} "
                        "is not finite and non-negative"
                    )
                if key == "maxLockedTargets" and float(value).is_integer() is False:
                    fail(
                        f"type {entry['typeId']} {key}={value!r} "
                        "is not integral"
                    )
                if entry["categoryId"] != 6:
                    fail(
                        f"non-ship type {entry['typeId']} carries {key}"
                    )

    # Invariants the parser relies on (design sections 5.2, 6.3): no
    # shipment name may contain the header delimiters, and no published
    # name may already look like a stacked "Name xN" line.
    for entry in types:
        if entry["categoryId"] == 6 and any(
            char in entry["typeName"] for char in ",[]"
        ):
            fail(
                f"ship type {entry['typeId']} name contains a header delimiter"
            )
        if _STACKED_SUFFIX_RE.search(entry["typeName"]):
            fail(
                f"type {entry['typeId']} name looks like a stacked line"
            )

    # Slot layout catalogue-wide locks (design section 3.4):
    # maxSubSystems carriers are exactly the four tech-3 hulls,
    # and key counts equal the section 3.1 expectations.
    max_sub_carriers = {
        entry["typeId"] for entry in types if "maxSubSystems" in entry
    }
    if max_sub_carriers != TECH3_CARRIER_SET:
        fail(
            f"maxSubSystems carriers {sorted(max_sub_carriers)}, "
            f"expected {sorted(TECH3_CARRIER_SET)}"
        )
    for key, expected in SLOT_LAYOUT_EXPECTED_COUNTS.items():
        actual = slot_layout_key_counts[key]
        if actual != expected:
            fail(
                f"slot layout key {key} count {actual}, expected {expected}"
            )

    # Navigation and targeting oracles (design section 3.3). A
    # None expected value means the key must be absent from
    # that row.
    for type_id, key, expected in NAV_TARGETING_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"navigation and targeting oracle type {type_id} missing")
        if expected is None:
            if key in entry:
                fail(
                    f"navigation and targeting oracle type {type_id} "
                    f"carries {key}={entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"navigation and targeting oracle type {type_id} "
                f"{key}={entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pins: Capsule 670 range/targets present as
    # 0.0, never absent (the two are distinct).
    zero_nav_entry = by_id.get(670)
    if (
        zero_nav_entry is None
        or "maxTargetRange" not in zero_nav_entry
        or "maxLockedTargets" not in zero_nav_entry
    ):
        fail(
            "navigation and targeting oracle type 670 "
            "maxTargetRange/maxLockedTargets keys must be present "
            "as 0.0"
        )
    for key, expected in NAV_TARGETING_EXPECTED_COUNTS.items():
        actual = nav_targeting_key_counts[key]
        if actual != expected:
            fail(
                f"navigation and targeting key {key} count {actual}, "
                f"expected {expected}"
            )

    duplicate_names = sum(
        1
        for count in Counter(
            normalize(entry["typeName"]) for entry in types
        ).values()
        if count > 1
    )

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump({"types": types}, handle, separators=(",", ":"))
        handle.write("\n")

    print(f"wrote {OUTPUT}")
    print(f"types={len(types)} missing_group_category0={missing_group}")
    print(f"duplicate_normalized_names={duplicate_names}")
    print(
        f"resource_keys cpuOutput={resource_key_counts['cpuOutput']} "
        f"powerOutput={resource_key_counts['powerOutput']} "
        f"cpu={resource_key_counts['cpu']} "
        f"power={resource_key_counts['power']}"
    )
    print(
        f"base_stat_keys shieldCapacity={base_stat_key_counts['shieldCapacity']} "
        f"armorHP={base_stat_key_counts['armorHP']} "
        f"hp={base_stat_key_counts['hp']} "
        f"capacitorCapacity={base_stat_key_counts['capacitorCapacity']} "
        f"maxVelocity={base_stat_key_counts['maxVelocity']} "
        f"shieldRechargeRate={base_stat_key_counts['shieldRechargeRate']} "
        f"rechargeRate={base_stat_key_counts['rechargeRate']}"
    )
    print(
        f"resistance_keys shieldEmDamageResonance={resonance_key_counts['shieldEmDamageResonance']} "
        f"shieldThermalDamageResonance={resonance_key_counts['shieldThermalDamageResonance']} "
        f"shieldKineticDamageResonance={resonance_key_counts['shieldKineticDamageResonance']} "
        f"shieldExplosiveDamageResonance={resonance_key_counts['shieldExplosiveDamageResonance']} "
        f"armorEmDamageResonance={resonance_key_counts['armorEmDamageResonance']} "
        f"armorThermalDamageResonance={resonance_key_counts['armorThermalDamageResonance']} "
        f"armorKineticDamageResonance={resonance_key_counts['armorKineticDamageResonance']} "
        f"armorExplosiveDamageResonance={resonance_key_counts['armorExplosiveDamageResonance']} "
        f"emDamageResonance={resonance_key_counts['emDamageResonance']} "
        f"thermalDamageResonance={resonance_key_counts['thermalDamageResonance']} "
        f"kineticDamageResonance={resonance_key_counts['kineticDamageResonance']} "
        f"explosiveDamageResonance={resonance_key_counts['explosiveDamageResonance']}"
    )
    print(
        f"bay_keys volume={bay_key_counts['volume']} "
        f"cargoCapacity={bay_key_counts['cargoCapacity']} "
        f"droneCapacity={bay_key_counts['droneCapacity']} "
        f"droneBandwidth={bay_key_counts['droneBandwidth']} "
        f"fighterCapacity={bay_key_counts['fighterCapacity']} "
        f"droneBandwidthUsed={bay_key_counts['droneBandwidthUsed']}"
    )
    print(
        f"calibration_keys upgradeCapacity={calibration_key_counts['upgradeCapacity']} "
        f"upgradeCost={calibration_key_counts['upgradeCost']}"
    )
    print(
        f"slot_layout_keys hiSlots={slot_layout_key_counts['hiSlots']} "
        f"medSlots={slot_layout_key_counts['medSlots']} "
        f"lowSlots={slot_layout_key_counts['lowSlots']} "
        f"rigSlots={slot_layout_key_counts['rigSlots']} "
        f"maxSubSystems={slot_layout_key_counts['maxSubSystems']} "
        f"turretSlotsLeft={slot_layout_key_counts['turretSlotsLeft']} "
        f"launcherSlotsLeft={slot_layout_key_counts['launcherSlotsLeft']} "
        f"turretFitted={slot_layout_key_counts['turretFitted']} "
        f"launcherFitted={slot_layout_key_counts['launcherFitted']}"
    )
    print(
        f"nav_targeting_keys warpSpeedMultiplier={nav_targeting_key_counts['warpSpeedMultiplier']} "
        f"agility={nav_targeting_key_counts['agility']} "
        f"signatureRadius={nav_targeting_key_counts['signatureRadius']} "
        f"maxTargetRange={nav_targeting_key_counts['maxTargetRange']} "
        f"scanResolution={nav_targeting_key_counts['scanResolution']} "
        f"scanRadarStrength={nav_targeting_key_counts['scanRadarStrength']} "
        f"scanLadarStrength={nav_targeting_key_counts['scanLadarStrength']} "
        f"scanMagnetometricStrength={nav_targeting_key_counts['scanMagnetometricStrength']} "
        f"scanGravimetricStrength={nav_targeting_key_counts['scanGravimetricStrength']} "
        f"maxLockedTargets={nav_targeting_key_counts['maxLockedTargets']} "
        f"mass={nav_targeting_key_counts['mass']}"
    )


if __name__ == "__main__":
    main()
