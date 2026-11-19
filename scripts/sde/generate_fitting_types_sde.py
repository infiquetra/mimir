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
Damage per second (docs/fitting-dps-design.md section 3) appends
twenty-eight further keys after `mass` in the locked order:
`speed` (dogma 51) and `damageMultiplier` (64) on categories 7
and 18, the four charge/drone damage components `emDamage`
(114), `explosiveDamage` (116), `kineticDamage` (117),
`thermalDamage` (118) on categories 8 and 18, the fighter
per-type keys on category 87 (`fighterSquadronMaxSize` 2215,
`fighterSquadronIsLight` 2212, `fighterSquadronIsSupport`
2213, `fighterSquadronIsHeavy` 2214, the attack-ability family
2226/2227/2228/2229/2230/2233, the missiles-ability family
2130/2131/2132/2133/2134/2182), the ship tube/slot keys
`fighterTubes` (2216), `fighterLightSlots` (2217),
`fighterSupportSlots` (2218), `fighterHeavySlots` (2219) on
category 6, and the sparse boolean ability markers
`fighterAbilityAttackM` (effect 6465) and
`fighterAbilityMissiles` (effect 6431) on category 87.
Turret ranges (docs/volley-ranges-design.md section 3) append
two further keys after the DPS keys in the locked order:
`maxRange` (dogma 54) then `falloff` (dogma 158), sparse on
category 7 rows only (drones deliberately excluded — nothing
reads a drone's ranges). Catalogue keys are the dogma names
verbatim (`speed`, never Flutter's `rateOfFire`; `maxRange`,
never Flutter's `optimalRange`). Dogma 212 and 160 are never
read here.
Capacitor stability (docs/cap-stability-design.md section 3)
appends three further keys after `falloff` in the locked order:
`capacitorNeed` (dogma 6, unit 114 GJ per activation),
`duration` (dogma 73, unit 101 milliseconds), and
`reloadTime` (dogma 1795, unit 101 milliseconds; the SDE
default 10000.0 is never substituted — an absent row adds 0
to the cycle). All three are sparse on category 7 or 66 rows
carrying a slot effect only. Dogma 67 `capacitorBonus` (the
booster charge gain) is never read: booster injectors ship
nothing (design section 9).
Base active repair (docs/sustained-tank-design.md section 3)
appends eight further keys after `reloadTime` in the locked
order: `shieldBonus` (dogma 68), `armorDamageAmount` (84),
and `structureDamageAmount` (83), the three amount keys under
their verbatim SDE names, then the five effect-name boolean
markers `shieldBoosting` (effect 4), `fueledShieldBoosting`
(4936), `armorRepair` (27), `fueledArmorRepair` (5275), and
`structureRepair` (26). All eight are sparse on category 7
or 66 rows carrying a slot effect **and** a self-repair
effect; remote repairers (effects 6186/6652/6188/6651/7166/
6185) carry the same amount attributes but never gain keys.
`duration` (73) is shared with the capacitor slice and is not
re-emitted. Dogma 1886 `chargedArmorDamageMultiplier` (the
loaded-paste gain) is never read: ancillary modules ship dry
amounts only (design section 2.3).
Module need filters (docs/fitting-need-reductions-design.md
section 4) append two further keys after `structureRepair` in the
locked order: `groupId` (the invTypes `groupID` column) and
`requiredSkillIds` (the six required-skill slots 182, 183, 184,
1285, 1289, 1290 in attribute order, absent slots skipped, always
present including as an empty list) on exactly the category-7
slot rows carrying a need key. Rigs, ships, and every other row
gain neither key.
Charge editing (docs/charge-editing-design.md section 3) appends
two further keys after `requiredSkillIds` in the locked order:
`chargeGroupIds` (the five charge-group slots 604, 605, 606, 609,
610 in attribute order, absent slots skipped) on exactly the
category-7-or-32 rows carrying a slot effect and at least one
group, sparse, and `chargeGroupId` (the invTypes `groupID`
column) on every category-8 row. Any other row gains neither
key, and no row gains both.

Fitted-module resistance modifiers
(docs/resistance-bonuses-design.md section 3) append two
further keys after `chargeGroupId` in the locked order:
`resistanceModifiers`, a sparse array of
[modifiedAttributeId, operator, operand] triples on
category-7 rows only, and `resistanceModifiersUnapplied`,
a sparse `true` beside that array when the carrier's bonus
cannot be grounded from the bundled data. The effect-to-
modifier leg comes from `dogmaEffects.jsonl` inside the
committed `eve-online-static-data-3503375-jsonl.zip` (the
sibling-generator pattern); the operand leg is the type's
own `dgmTypeAttributes` value for the modifier's modifying
attribute. The generator still never downloads: a missing
or unreadable zip fails loudly before anything is written.
"""

import bz2
import csv
import json
import math
import os
import re
import sys
import zipfile
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

# Required-skill attribute ids (docs/fitting-need-reductions-design.md
# section 4): the six required-skill slots 182, 183, 184, 1285,
# 1289, 1290. Source: dogmaAttributes.jsonl (the requiredSlots
# attributes) and Flutter's `requiredSkillAttributeIds` at ed698d3
# (dogma_engine.dart:40-51); the tuple order is the locked emission
# order. Every cached row carries `valueFloat` (`valueInt` is always
# the literal `None`), so values parse from `valueFloat` like every
# other attribute set.
REQUIRED_SKILL_ATTR_IDS = (182, 183, 184, 1285, 1289, 1290)

# Charge-group attribute ids (docs/charge-editing-design.md
# section 2.3): the five charge-group slots 604, 605, 606, 609,
# 610. Source: dogmaAttributes.jsonl in
# scripts/sde/eve-online-static-data-3503375-jsonl.zip names
# 604/605/606/609/610 chargeGroup1-5; 607 carries no row and 608
# is powerNeedMultiplier, both never read. The tuple order is
# the locked emission order. Every cached row carries
# `valueFloat`, parsed like every other attribute set and
# emitted as an integer.
CHARGE_GROUP_ATTR_IDS = (604, 605, 606, 609, 610)

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
# Fitted-module resistance modifiers
# (docs/resistance-bonuses-design.md section 3): the locked
# display order (shield, armor, hull; EM, thermal, kinetic,
# explosive within a layer) and the two applicable operator
# codes (0 postMul, 6 postPercent per Flutter dogma_engine.dart
# at ed698d3). A modifier is classified only when it is
# ItemModifier/shipID on one of the twelve resonances (the
# Flutter routeOwnerModifiers absent/zero skip); every other
# func/domain/operator contributes nothing by data, not taste.
RESIST_MODIFIER_ORDER = [271, 274, 273, 272, 267, 270, 269, 268,
                         113, 110, 109, 111]
RESIST_MODIFIER_OPERATORS = {0, 6}
SDE_ZIP_NAME = "eve-online-static-data-3503375-jsonl.zip"
SDE_ZIP_MEMBER = "dogmaEffects.jsonl"
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

# Damage per second (docs/fitting-dps-design.md section 2/3):
# dogmaAttributes.jsonl _key 51 "speed" (unit 101 Milliseconds),
# 64 "damageMultiplier" (unit 104 "x"), 114 "emDamage",
# 116 "explosiveDamage", 117 "kineticDamage", 118
# "thermalDamage" (all unit 113 damage), 2215
# "fighterSquadronMaxSize", 2212 "fighterSquadronIsLight",
# 2213 "fighterSquadronIsSupport", 2214
# "fighterSquadronIsHeavy", 2226
# "fighterAbilityAttackMissileDamageMultiplier" (unit 104 "x"),
# 2227-2230 "fighterAbilityAttackMissileDamageEM/Therm/Kin/Exp"
# (unit 113), 2233 "fighterAbilityAttackMissileDuration"
# (unit 101 Milliseconds), 2130
# "fighterAbilityMissilesDamageMultiplier" (unit 104 "x"),
# 2131-2134 "fighterAbilityMissilesDamageEM/Therm/Kin/Exp"
# (unit 113), 2182 "fighterAbilityMissilesDuration"
# (unit 101 Milliseconds), 2216 "fighterTubes", 2217
# "fighterLightSlots", 2218 "fighterSupportSlots", 2219
# "fighterHeavySlots". Catalogue keys are the dogma names
# verbatim. Dogma 212 "missileDamageMultiplier" is a
# character-level ballistics bonus input and is never read;
# 54 "maxRange" (unit 1 metre) and 158 "falloff" (unit 1
# metre) are read here for the base volley/turret-range
# slice (docs/volley-ranges-design.md section 3); 160
# "trackingSpeed" is never read.
DPS_ATTR_IDS = {
    51, 64, 114, 116, 117, 118, 2215, 2212, 2213, 2214, 2226, 2227,
    2228, 2229, 2230, 2233, 2130, 2131, 2132, 2133, 2134, 2182, 2216,
    2217, 2218, 2219, 54, 158,
}
SPEED_ATTR = 51
DAMAGE_MULTIPLIER_ATTR = 64
EM_DAMAGE_ATTR = 114
EXPLOSIVE_DAMAGE_ATTR = 116
KINETIC_DAMAGE_ATTR = 117
THERMAL_DAMAGE_ATTR = 118
FIGHTER_SQUADRON_MAX_SIZE_ATTR = 2215
FIGHTER_SQUADRON_IS_LIGHT_ATTR = 2212
FIGHTER_SQUADRON_IS_SUPPORT_ATTR = 2213
FIGHTER_SQUADRON_IS_HEAVY_ATTR = 2214
FIGHTER_ATTACK_DAMAGE_MULTIPLIER_ATTR = 2226
FIGHTER_ATTACK_DAMAGE_EM_ATTR = 2227
FIGHTER_ATTACK_DAMAGE_THERM_ATTR = 2228
FIGHTER_ATTACK_DAMAGE_KIN_ATTR = 2229
FIGHTER_ATTACK_DAMAGE_EXP_ATTR = 2230
FIGHTER_ATTACK_DURATION_ATTR = 2233
FIGHTER_MISSILES_DAMAGE_MULTIPLIER_ATTR = 2130
FIGHTER_MISSILES_DAMAGE_EM_ATTR = 2131
FIGHTER_MISSILES_DAMAGE_THERM_ATTR = 2132
FIGHTER_MISSILES_DAMAGE_KIN_ATTR = 2133
FIGHTER_MISSILES_DAMAGE_EXP_ATTR = 2134
FIGHTER_MISSILES_DURATION_ATTR = 2182
FIGHTER_TUBES_ATTR = 2216
FIGHTER_LIGHT_SLOTS_ATTR = 2217
FIGHTER_SUPPORT_SLOTS_ATTR = 2218
FIGHTER_HEAVY_SLOTS_ATTR = 2219
MAX_RANGE_ATTR = 54
FALLOFF_ATTR = 158

# Capacitor stability (docs/cap-stability-design.md section 3):
# dogmaAttributes.jsonl _key 6 "capacitorNeed" (unit 114 GJ),
# 73 "duration" (unit 101 Milliseconds), 1795 "reloadTime"
# (unit 101 Milliseconds); Flutter dogma_attributes.dart at
# ed698d3 (capacitorNeed = 6, duration = 73,
# reactivationDelay = 1795). Values stay raw milliseconds in
# the catalogue; absence loads as absent (the SDE default
# 10000.0 for reloadTime is never substituted — Flutter's
# `moduleAttr` returns 0.0 for a missing base row). The
# booster gain (67 "capacitorBonus") is never read here:
# booster injectors ship nothing (design section 9).
CAP_ATTR_IDS = {6, 73, 1795}
CAPACITOR_NEED_ATTR = 6
DURATION_ATTR = 73
RELOAD_TIME_ATTR = 1795

# Base active repair (docs/sustained-tank-design.md section 3):
# dogmaAttributes.jsonl _key 68 "shieldBonus", 84
# "armorDamageAmount", 83 "structureDamageAmount" (all unit 113
# damage); Flutter dogma_attributes.dart at ed698d3 gives the
# same three numbers under its editorial names
# shieldBoostAmount, armorRepairAmount, hullRepairAmount.
# Catalogue keys
# are the dogma names verbatim. Dogma 1886
# "chargedArmorDamageMultiplier" (the loaded-paste gain) is
# never read here: ancillary modules ship dry amounts only
# (design section 2.3).
REPAIR_ATTR_IDS = {68, 84, 83}
SHIELD_BONUS_ATTR = 68
ARMOR_DAMAGE_AMOUNT_ATTR = 84
STRUCTURE_DAMAGE_AMOUNT_ATTR = 83

# Self-repair effect routing (docs/sustained-tank-design.md
# section 3): dogmaEffects.jsonl _key 4 "shieldBoosting" and
# 4936 "fueledShieldBoosting" (shield), 27 "armorRepair" and
# 5275 "fueledArmorRepair" (armor), 26 "structureRepair"
# (hull); the catalogue keys are the SDE effect names
# verbatim. The gate requires one of these effects, so a
# remote repairer (6186/6652/6188/6651/7166/6185) never gains
# a key even though the cache carries its amount row.
SHIELD_BOOSTING_EFFECT = 4
FUELED_SHIELD_BOOSTING_EFFECT = 4936
ARMOR_REPAIR_EFFECT = 27
FUELED_ARMOR_REPAIR_EFFECT = 5275
STRUCTURE_REPAIR_EFFECT = 26
REPAIR_SELF_EFFECT_IDS = {4, 4936, 27, 5275, 26}

# Fighter ability markers (docs/fitting-dps-design.md section
# 2.5): dogmaEffects.jsonl _key 6465 "fighterAbilityAttackM"
# (truncated in the SDE itself) and 6431
# "fighterAbilityMissiles", both pure markers. The catalogue
# keys are the SDE effect names verbatim.
FIGHTER_ABILITY_ATTACK_EFFECT = 6465
FIGHTER_ABILITY_MISSILES_EFFECT = 6431

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

# Fitted-module resistance modifier oracles
# (docs/resistance-bonuses-design.md section 3): each value
# read from dogmaEffects.jsonl (committed zip) joined through
# dgmTypeEffects / dgmTypeAttributes during design. Tuple
# shape: (typeId, expected-entries-or-None,
# expected-unapplied). A None entries means neither
# resistanceModifiers nor resistanceModifiersUnapplied may
# be present on that row at all. An empty list means the
# (possibly empty) array must be present and the unapplied
# marker must be true.
RESIST_MODIFIER_ORACLES = [
    (2048, [[271, 0, 0.875], [274, 0, 0.875], [273, 0, 0.875],
            [272, 0, 0.875], [267, 0, 0.85], [270, 0, 0.85],
            [269, 0, 0.85], [268, 0, 0.85], [113, 0, 0.6],
            [110, 0, 0.6], [109, 0, 0.6], [111, 0, 0.6]], False),
    (2281, [[271, 6, -32.5], [274, 6, -32.5],
            [273, 6, -32.5], [272, 6, -32.5]], False),
    (578, [[271, 6, -25.0], [274, 6, -25.0],
           [273, 6, -25.0], [272, 6, -25.0]], False),
    (1306, [[267, 6, -15.36], [270, 6, -15.36],
            [269, 6, -15.36], [268, 6, -15.36]], False),
    (1197, [[267, 6, -24.32]], False),
    (11642, [[267, 6, -55.0]], False),
    (25736, [[267, 6, -30.0]], False),
    (2050, [[271, 6, -37.5], [274, 6, -37.5],
            [273, 6, -37.5], [272, 6, -37.5]], False),
    (34272, [], True),
    (52227, [], True),
    (52230, [], True),
    (1272, None, False),
    (587, None, False),
    (2456, None, False),
]

# Catalogue-wide counts for the resistance modifier emission
# (docs/resistance-bonuses-design.md section 3, design-scripted
# over today's data): rows carrying the key (777 with
# entries plus 14 marked-empty), rows marked unapplied,
# total emitted entries.
RESIST_MODIFIER_ROWS = 791
RESIST_MODIFIER_NONEMPTY_ROWS = 777
RESIST_MODIFIER_MARKED_ROWS = 14
RESIST_MODIFIER_ENTRIES = 1332

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

# Damage-per-second oracles (docs/fitting-dps-design.md
# section 3.2): each value read directly from
# dgmTypeAttributes.csv.bz2 / dgmTypeEffects.csv.bz2 during
# design. Tuple shape mirrors NAV_TARGETING_ORACLES:
# (typeId, key, expected-or-None). A None expected means the
# key must be absent from that row.
DPS_ORACLES = [
    # Turrets: 484 125mm Gatling AutoCannon I, 2889 200mm
    # AutoCannon II.
    (484, "speed", 3000.0),
    (484, "damageMultiplier", 2.0625),
    (2889, "speed", 3750.0),
    (2889, "damageMultiplier", 3.465),
    # Launcher: 2404 Light Missile Launcher II (no 64 row).
    (2404, "speed", 12800.0),
    (2404, "damageMultiplier", None),
    # Charges: 180 Proton S (present explicit zeros pin
    # absence-vs-zero), 21898 Republic Fleet EMP S.
    (180, "emDamage", 3.0),
    (180, "kineticDamage", 2.0),
    (180, "explosiveDamage", 0.0),
    (180, "thermalDamage", 0.0),
    (21898, "emDamage", 10.35),
    (21898, "explosiveDamage", 2.3),
    (21898, "kineticDamage", 1.15),
    (21898, "thermalDamage", 0.0),
    (210, "kineticDamage", 83.0),
    # Drones: 2488 Warrior II, 2456 Hobgoblin II.
    (2488, "speed", 4000.0),
    (2488, "damageMultiplier", 1.56),
    (2488, "explosiveDamage", 20.0),
    (2456, "damageMultiplier", 1.92),
    (2456, "thermalDamage", 20.0),
    # Fighters: 23059 Firbolg I (cache values, size 9.0 and
    # thermal 75.0, not the zip's 6/112.5), 40358 Equite I.
    (23059, "fighterSquadronMaxSize", 9.0),
    (23059, "fighterSquadronIsLight", 1.0),
    (23059, "fighterAbilityAttackMissileDamageMultiplier", 1.0),
    (23059, "fighterAbilityAttackMissileDamageTherm", 75.0),
    (23059, "fighterAbilityAttackMissileDuration", 5000.0),
    (23059, "fighterAbilityMissilesDamageTherm", 138.0),
    (23059, "fighterAbilityMissilesDuration", 14000.0),
    (23059, "fighterAbilityAttackM", True),
    (23059, "fighterAbilityMissiles", True),
    (40358, "fighterSquadronMaxSize", 12.0),
    (40358, "fighterAbilityMissilesDamageEM", 38.0),
    (40358, "fighterAbilityMissilesDuration", 3500.0),
    (40358, "fighterAbilityMissiles", True),
    (40358, "fighterAbilityAttackM", None),
    # Ships: 23911 Thanatos tubes/slots (heavy slots absent).
    (23911, "fighterTubes", 3.0),
    (23911, "fighterLightSlots", 3.0),
    (23911, "fighterSupportSlots", 1.0),
    (23911, "fighterHeavySlots", None),
    # Category and decoy gates: module-carried damage never
    # emitted; mining laser 482 turret marker never leaks;
    # charges carry neither cycle nor multiplier; mutated
    # drone 60478 carries no DPS attributes; no-ability
    # fighter 40568 stays so; non-carrier 587 carries neither.
    (484, "emDamage", None),
    (1563, "emDamage", None),
    (1563, "speed", None),
    (482, "speed", None),
    (482, "damageMultiplier", None),
    (180, "speed", None),
    (180, "damageMultiplier", None),
    (60478, "speed", None),
    (60478, "emDamage", None),
    (40568, "fighterAbilityAttackM", None),
    (40568, "fighterAbilityMissiles", None),
    (587, "fighterTubes", None),
    (587, "speed", None),
    # Turret ranges (docs/volley-ranges-design.md section 3.2):
    # 484, 2889, 565 present values; 47272 Light Entropic
    # Disintegrator I 54-only present/absent pair; 447 Warp
    # Scrambler I present-zero falloff (an inert non-weapon
    # row: no `speed`, never a weapon candidate); launcher
    # 2404, drone 2488, and ship 587 absences.
    (484, "maxRange", 800.0),
    (484, "falloff", 4300.0),
    (2889, "maxRange", 1200.0),
    (2889, "falloff", 5160.0),
    (565, "maxRange", 12000.0),
    (565, "falloff", 6000.0),
    (47272, "maxRange", 6000.0),
    (447, "maxRange", 7500.0),
    (447, "falloff", 0.0),
    (47272, "falloff", None),
    (2404, "maxRange", None),
    (2404, "falloff", None),
    (2488, "maxRange", None),
    (2488, "falloff", None),
    (587, "maxRange", None),
    (587, "falloff", None),
]

# Expected damage-per-second key counts (fitting-dps-design
# section 3.1 and volley-ranges-design section 3.1, scripted
# over the cache joined to the catalogue). DEVIATION:
# `thermalDamage` is 897, not the design's 898 — the design's
# scripted count includes published category-8 type 53343 Yoiul
# Festival Snowball, whose sole thermal row is -10.0, which
# the locked "finite and >= 0.0" invariant cannot admit;
# negative DPS source rows are skipped at load (see the load
# block), so that one row is absent, not zero.
DPS_EXPECTED_COUNTS = {
    "speed": 873,
    "damageMultiplier": 837,
    "emDamage": 897,
    "explosiveDamage": 897,
    "kineticDamage": 897,
    "thermalDamage": 897,
    "fighterSquadronMaxSize": 94,
    "fighterSquadronIsLight": 24,
    "fighterSquadronIsSupport": 12,
    "fighterSquadronIsHeavy": 17,
    "fighterAbilityAttackMissileDamageMultiplier": 62,
    "fighterAbilityAttackMissileDamageEM": 62,
    "fighterAbilityAttackMissileDamageTherm": 62,
    "fighterAbilityAttackMissileDamageKin": 62,
    "fighterAbilityAttackMissileDamageExp": 62,
    "fighterAbilityAttackMissileDuration": 62,
    "fighterAbilityMissilesDamageMultiplier": 65,
    "fighterAbilityMissilesDamageEM": 65,
    "fighterAbilityMissilesDamageTherm": 65,
    "fighterAbilityMissilesDamageKin": 65,
    "fighterAbilityMissilesDamageExp": 65,
    "fighterAbilityMissilesDuration": 65,
    "fighterTubes": 12,
    "fighterLightSlots": 12,
    "fighterSupportSlots": 10,
    "fighterHeavySlots": 7,
    "fighterAbilityAttackM": 54,
    "fighterAbilityMissiles": 56,
    "maxRange": 1157,
    "falloff": 681,
}

# Capacitor stability oracles (docs/cap-stability-design.md
# section 7): each value read directly from
# dgmTypeAttributes.csv.bz2 during build. Tuple shape mirrors
# DPS_ORACLES: (typeId, key, expected-or-None). A None
# expected means the key must be absent from that row.
# Spot literals for 2050/1183/438/448 need + cycle, 2889
# known-zero need with a 51-cycle (duration absent) plus a
# present reload, 561 reload with a 51-cycle, the 522
# battery decoy (carries only the never-emitted 67), a
# category-66 gate pin (35921 reload emitted with no need),
# a category-66 counted pin (35924), and ships absences.
CAP_ORACLES = [
    (2050, "capacitorNeed", 32.0),
    (2050, "duration", 12000.0),
    (2050, "reloadTime", None),
    (1183, "capacitorNeed", 40.0),
    (1183, "duration", 6000.0),
    (1183, "reloadTime", None),
    (438, "capacitorNeed", 22.0),
    (438, "duration", 10000.0),
    (448, "capacitorNeed", 6.0),
    (448, "duration", 5000.0),
    (2889, "capacitorNeed", 0.0),
    (2889, "duration", None),
    (2889, "reloadTime", 10000.0),
    (561, "capacitorNeed", 1.169),
    (561, "duration", None),
    (561, "reloadTime", 5000.0),
    (522, "capacitorNeed", None),
    (522, "duration", None),
    (522, "reloadTime", None),
    (35921, "capacitorNeed", None),
    (35921, "duration", None),
    (35921, "reloadTime", 10000.0),
    (35924, "capacitorNeed", 6000.0),
    (35924, "duration", 30000.0),
    (35924, "reloadTime", None),
    (2048, "capacitorNeed", None),
    (2048, "duration", None),
    (2048, "reloadTime", None),
    (587, "capacitorNeed", None),
    (587, "duration", None),
    (587, "reloadTime", None),
]

# Expected capacitor stability key counts (cap-stability-design
# section 3, scripted over the cache joined to the catalogue
# behind the emission gate: category 7 or 66 carrying a slot
# effect, presence exactly source-row existence). The
# 1,838 counted types (capacitorNeed > 0 with a 73-or-51
# cycle) split 1,814 category 7 and 24 category 66; the
# remaining emitted keys ride rows with no need or a
# present-zero need.
CAP_EXPECTED_COUNTS = {
    "capacitorNeed": 2095,
    "duration": 1489,
    "reloadTime": 986,
}

# Base active repair oracles (docs/sustained-tank-design.md
# section 8): each value read directly from
# dgmTypeAttributes.csv.bz2 / dgmTypeEffects.csv.bz2 during
# design. Tuple shape mirrors CAP_ORACLES: (typeId, key,
# expected-or-None). A None expected means the key must be
# absent from that row. Present-value pins (3540 armor 920.0,
# 10850 shield 104.0, 2355 hull 30.0, 1183 armor 92.0, 33076
# dry armor 52.0 with fueledArmorRepair true, 32774 shield
# 52.0 with fueledShieldBoosting true), marker-only pins for
# the abyssal no-data population (47781 shieldBoosting true
# with shieldBonus absent; 47769 armorRepair true with
# armorDamageAmount absent), absence oracles proving the
# effect gate (3588 Small Remote Shield Booster II carries
# cache amount 85.0 but must gain no key; 11355 Small Remote
# Armor Repairer I likewise; 2048/2050/587 carry no new keys
# at all), and the 1886-absence pin (33076 gains no
# chargedArmorDamageMultiplier key).
REPAIR_ORACLES = [
    (3540, "armorDamageAmount", 920.0),
    (10850, "shieldBonus", 104.0),
    (2355, "structureDamageAmount", 30.0),
    (1183, "armorDamageAmount", 92.0),
    (33076, "armorDamageAmount", 52.0),
    (33076, "fueledArmorRepair", True),
    (32774, "shieldBonus", 52.0),
    (32774, "fueledShieldBoosting", True),
    (47781, "shieldBoosting", True),
    (47781, "shieldBonus", None),
    (47769, "armorRepair", True),
    (47769, "armorDamageAmount", None),
    (3588, "shieldBonus", None),
    (3588, "armorDamageAmount", None),
    (3588, "structureDamageAmount", None),
    (3588, "shieldBoosting", None),
    (3588, "fueledShieldBoosting", None),
    (3588, "armorRepair", None),
    (3588, "fueledArmorRepair", None),
    (3588, "structureRepair", None),
    (11355, "shieldBonus", None),
    (11355, "armorDamageAmount", None),
    (11355, "structureDamageAmount", None),
    (11355, "shieldBoosting", None),
    (11355, "fueledShieldBoosting", None),
    (11355, "armorRepair", None),
    (11355, "fueledArmorRepair", None),
    (11355, "structureRepair", None),
    (2048, "shieldBonus", None),
    (2048, "armorDamageAmount", None),
    (2048, "structureDamageAmount", None),
    (2048, "shieldBoosting", None),
    (2048, "fueledShieldBoosting", None),
    (2048, "armorRepair", None),
    (2048, "fueledArmorRepair", None),
    (2048, "structureRepair", None),
    (2050, "shieldBonus", None),
    (2050, "armorDamageAmount", None),
    (2050, "structureDamageAmount", None),
    (2050, "shieldBoosting", None),
    (2050, "fueledShieldBoosting", None),
    (2050, "armorRepair", None),
    (2050, "fueledArmorRepair", None),
    (2050, "structureRepair", None),
    (587, "shieldBonus", None),
    (587, "armorDamageAmount", None),
    (587, "structureDamageAmount", None),
    (587, "shieldBoosting", None),
    (587, "fueledShieldBoosting", None),
    (587, "armorRepair", None),
    (587, "fueledArmorRepair", None),
    (587, "structureRepair", None),
    (33076, "chargedArmorDamageMultiplier", None),
]

# Expected active repair key counts (sustained-tank-design
# section 3, scripted over the cache joined to the catalogue
# behind the emission gate: category 7 or 66 carrying a slot
# effect and a self-repair effect, presence exactly
# source-row existence). The 233 amount types (99/109/25)
# split 233 present-amount / 17 marker-only out of the 250
# gated self types; the ungated cache totals (145/161/33)
# are never emitted — they are the remote repairers.
REPAIR_EXPECTED_COUNTS = {
    "shieldBonus": 99,
    "armorDamageAmount": 109,
    "structureDamageAmount": 25,
    "shieldBoosting": 94,
    "fueledShieldBoosting": 14,
    "armorRepair": 105,
    "fueledArmorRepair": 12,
    "structureRepair": 25,
}

# Module need-filter oracles (docs/fitting-need-reductions-design.md
# section 4): each value read directly from invTypes.csv.bz2 /
# dgmTypeAttributes.csv.bz2 during design. Tuple shape mirrors
# REPAIR_ORACLES: (typeId, key, expected-or-None). A None expected
# means the key must be absent from that row (1236 carries no
# needs at all; 587 is a ship). `requiredSkillIds` lists are
# complete lists in the locked attribute order 182, 183, 184,
# 1285, 1289, 1290 (absent slots skipped).
NEED_FILTER_ORACLES = [
    (2889, "groupId", 55),
    (2889, "requiredSkillIds", [3302, 3300, 11084]),
    (4256, "groupId", 862),
    (4256, "requiredSkillIds", [28073]),
    (2048, "groupId", 60),
    (2048, "requiredSkillIds", [3394]),
    (1355, "groupId", 769),
    (1355, "requiredSkillIds", [3424]),
    (37303, "groupId", 74),
    (37303, "requiredSkillIds", [41406, 21666, 3300]),
    (33981, "groupId", 1289),
    (33981, "requiredSkillIds", [3455]),
    (1236, "groupId", None),
    (1236, "requiredSkillIds", None),
    (587, "groupId", None),
    (587, "requiredSkillIds", None),
]

# Expected module need-filter key counts (fitting-need-reductions-design
# section 4, scripted over the cache joined to the shipped
# catalogue: the 3,183 cat-7 slot rows carrying a need key —
# 3,177 on CPU, 3,183 on power — gain both filter keys, always
# present including as an empty list; 4,306 required-skill slot
# values in total, 3,175 rows non-empty and 8 empty).
NEED_FILTER_EXPECTED_COUNTS = {
    "groupId": 3183,
    "requiredSkillIds": 3183,
    "requiredSkillValues": 4306,
}

# Charge-group oracles (docs/charge-editing-design.md section
# 3.2): each value read directly from invTypes.csv.bz2 /
# dgmTypeAttributes.csv.bz2 during design. Tuple shape mirrors
# NEED_FILTER_ORACLES: (typeId, key, expected-or-None). A None
# expected means the key must be absent from that row (2048
# lists no groups, 482 Miner II takes no crystal, 16631 is a
# cache carrier outside the emission scope, 2889 is a module
# not a charge, 21898 is a charge not a module). `chargeGroupIds`
# lists are complete lists in the locked attribute order 604,
# 605, 606, 609, 610 (absent slots skipped).
CHARGE_GROUP_ORACLES = [
    (2889, "chargeGroupIds", [83, 372]),
    (450, "chargeGroupIds", [86]),
    (499, "chargeGroupIds", [384, 394]),
    (4256, "chargeGroupIds", [90, 863, 864]),
    (1952, "chargeGroupIds", [910]),
    (3568, "chargeGroupIds", [87]),
    (17912, "chargeGroupIds", [482]),
    (21898, "chargeGroupId", 83),
    (185, "chargeGroupId", 83),
    (210, "chargeGroupId", 384),
    (267, "chargeGroupId", 89),
    (239, "chargeGroupId", 86),
    (28668, "chargeGroupId", 916),
    (29009, "chargeGroupId", 910),
    (11287, "chargeGroupId", 87),
    (2048, "chargeGroupIds", None),
    (482, "chargeGroupIds", None),
    (16631, "chargeGroupIds", None),
    (587, "chargeGroupIds", None),
    (587, "chargeGroupId", None),
    (2889, "chargeGroupId", None),
    (21898, "chargeGroupIds", None),
    (2456, "chargeGroupId", None),
]

# Expected charge-group key counts (charge-editing-design
# section 3.2, scripted over the cache joined to the shipped
# catalogue: the 980 category-7-or-32 slot rows carrying at
# least one group gain `chargeGroupIds`, 1,489 group values in
# total, and every category-8 row gains `chargeGroupId`).
CHARGE_GROUP_EXPECTED_COUNTS = {
    "chargeGroupIds": 980,
    "chargeGroupValues": 1489,
    "chargeGroupId": 1005,
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

    # Fitted-module resistance modifiers (design section 3):
    # the effect-to-modifier leg from dogmaEffects.jsonl
    # inside the committed zip (a missing or unreadable zip
    # fails loudly before anything is written, as a missing
    # cache already does), joined through dgmTypeEffects and
    # the type's own dgmTypeAttributes operand values.
    # Classification is category-7 only; every ItemModifier/
    # shipID resonance modifier is deduplicated by (modified,
    # modifying, operator) and classed exactly one of
    # applicable / unsupported / zero / absent, and a type is
    # marked unapplied iff any modifier is unsupported, or it
    # has no applicable entry, no zero classification, and at
    # least one absent classification. An unparseable or
    # non-finite operand on a classified modifier, a
    # duplicated triple on one type, or two applicable
    # entries sharing a modified attribute fail loudly. Only
    # operands for category-7 candidate types are parsed, so
    # an unrelated broken attribute row cannot stop
    # generation.
    zip_path = os.path.join(cache_dir, SDE_ZIP_NAME)
    if not os.path.exists(zip_path):
        print(
            f"missing committed SDE zip {zip_path}; this "
            "generator never downloads — fetch the cache and "
            "re-run",
            file=sys.stderr,
        )
        sys.exit(1)
    try:
        archive = zipfile.ZipFile(zip_path)
    except (OSError, zipfile.BadZipFile):
        fail(f"unreadable SDE zip {zip_path}")
    with archive:
        if SDE_ZIP_MEMBER not in archive.namelist():
            fail(
                f"member {SDE_ZIP_MEMBER} missing from SDE zip "
                f"{zip_path}"
            )
        effect_modifiers = {}
        try:
            with archive.open(SDE_ZIP_MEMBER) as handle:
                for line in handle:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        fail(
                            "unparseable row in SDE zip member "
                            f"{SDE_ZIP_MEMBER}"
                        )
                    modifier_info = obj.get("modifierInfo") or []
                    if modifier_info:
                        effect_modifiers[obj["_key"]] = modifier_info
        except zipfile.BadZipFile:
            fail(f"unreadable SDE zip member {SDE_ZIP_MEMBER}")
    # Modifying attributes worth reading operands for:
    # every modifying id appearing in an ItemModifier/shipID
    # resonance modifier anywhere in the zip.
    wanted_modifying_ids = set()
    for modifier_info in effect_modifiers.values():
        for modifier in modifier_info:
            if (
                modifier.get("func") == "ItemModifier"
                and modifier.get("domain") == "shipID"
                and modifier.get("modifiedAttributeID")
                in RESIST_ATTR_IDS
            ):
                wanted_modifying_ids.add(
                    modifier["modifyingAttributeID"]
                )
    category_by_type = {}
    for row in inv_types:
        if row["published"] != "1":
            continue
        type_id = int(row["typeID"])
        if type_id > 0 and row["typeName"].strip():
            category_by_type[type_id] = group_to_category.get(
                int(row["groupID"]), 0
            )
    operands_by_type = {}
    seen_operand_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in wanted_modifying_ids:
            continue
        type_id = int(row["typeID"])
        if category_by_type.get(type_id) != 7:
            continue
        key = (type_id, attribute_id)
        if key in seen_operand_keys:
            fail(
                f"duplicate resistance modifier operand row "
                f"(type {type_id}, attribute {attribute_id}) "
                "in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable resistance modifier operand "
                f"{row['valueFloat']!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite resistance modifier operand "
                f"{value!r} for (type {type_id}, attribute "
                f"{attribute_id})"
            )
        seen_operand_keys.add(key)
        operands_by_type.setdefault(type_id, {})[attribute_id] = value
    resist_modifiers_by_type = {}
    for type_id, type_category in category_by_type.items():
        if type_category != 7:
            continue
        triples = set()
        for effect_id in effects_by_type.get(type_id, set()):
            for modifier in effect_modifiers.get(effect_id, []):
                if (
                    modifier.get("func") == "ItemModifier"
                    and modifier.get("domain") == "shipID"
                    and modifier.get("modifiedAttributeID")
                    in RESIST_ATTR_IDS
                ):
                    triples.add(
                        (
                            modifier["modifiedAttributeID"],
                            modifier["modifyingAttributeID"],
                            modifier["operation"],
                        )
                    )
        if not triples:
            continue
        operands = operands_by_type.get(type_id, {})
        applicable = []
        has_unsupported = False
        has_zero = False
        has_absent = False
        seen_modified = set()
        seen_triples = set()
        for modified_id, modifying_id, operator in sorted(triples):
            triple = (modified_id, modifying_id, operator)
            if triple in seen_triples:
                fail(
                    f"duplicated resistance modifier triple "
                    f"{triple} on type {type_id}"
                )
            seen_triples.add(triple)
            if modifying_id not in operands:
                has_absent = True
                continue
            operand = operands[modifying_id]
            if operand == 0.0:
                has_zero = True
                continue
            if operator not in RESIST_MODIFIER_OPERATORS:
                has_unsupported = True
                continue
            if modified_id in seen_modified:
                fail(
                    f"two applicable resistance modifier entries "
                    f"on modified attribute {modified_id} for "
                    f"type {type_id}"
                )
            seen_modified.add(modified_id)
            applicable.append([modified_id, operator, operand])
        applicable.sort(
            key=lambda entry: RESIST_MODIFIER_ORDER.index(entry[0])
        )
        unapplied = has_unsupported or (
            not applicable and not has_zero and has_absent
        )
        if applicable or unapplied:
            resist_modifiers_by_type[type_id] = (
                applicable,
                unapplied,
            )

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

    # Damage-per-second attributes per type (design section
    # 3.1): only the 26 locked attributes, each parsed from
    # valueFloat. An unparseable, duplicated, or non-finite
    # wanted row fails loudly and writes nothing.
    # DEVIATION from the design's global fail-loud on
    # negative values (the navigation deviation's shape, but
    # one step different): the cache carries six negative DPS
    # rows, five on never-emitted categories 8-unpublished/63,
    # and one on published category-8 type 53343 Yoiul
    # Festival Snowball (thermalDamage -10.0), which a
    # global or emitted-gated fail would still trip. A
    # global fail writes nothing and blocks the slice; the
    # locked "finite and >= 0.0" invariant cannot admit the
    # snowball row either. Negative rows are therefore
    # skipped at load (counted for the summary) and never
    # emitted or validated: absence is data, negative
    # damage is not. All other validation is unchanged.
    dps_by_type = {}
    seen_dps_keys = set()
    skipped_negative_dps_rows = 0
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in DPS_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_dps_keys:
            fail(
                f"duplicate damage-per-second row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable damage-per-second value "
                f"{row['valueFloat']!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite damage-per-second value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_dps_keys.add(key)
        if value < 0:
            skipped_negative_dps_rows += 1
            continue
        dps_by_type.setdefault(type_id, {})[attribute_id] = value

    # Capacitor stability attributes per type (design
    # section 3): only the three locked attributes, each
    # parsed from valueFloat. An unparseable, duplicated,
    # non-finite, or negative wanted row fails loudly and
    # writes nothing. (Unlike the DPS load above, which
    # skips negative rows, the cache carries no negative
    # capacitor rows at all — verified at build time — so a
    # future negative fails loud instead of being dropped.)
    cap_by_type = {}
    seen_cap_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in CAP_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_cap_keys:
            fail(
                f"duplicate capacitor stability row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable capacitor stability value "
                f"{row['valueFloat']!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite capacitor stability value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative capacitor stability value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_cap_keys.add(key)
        cap_by_type.setdefault(type_id, {})[attribute_id] = value

    # Base active repair attributes per type (design section 3):
    # only the three locked amount attributes, each parsed from
    # valueFloat. An unparseable, duplicated, non-finite, or
    # negative wanted row fails loudly and writes nothing. The
    # cache carries no negative or zero gated repair rows at
    # all — verified at build time — so a future negative
    # fails loud instead of being dropped.
    repair_by_type = {}
    seen_repair_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in REPAIR_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_repair_keys:
            fail(
                f"duplicate active repair row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable active repair value "
                f"{row['valueFloat']!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite active repair value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value < 0:
            fail(
                f"negative active repair value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        seen_repair_keys.add(key)
        repair_by_type.setdefault(type_id, {})[attribute_id] = value

    # Required skills per type (docs/fitting-need-reductions-design.md
    # section 4): only the six locked attribute ids, each parsed
    # from valueFloat. An unparseable, duplicated, non-finite,
    # non-integral, or non-positive wanted row fails loudly and
    # writes nothing, as does a skill repeated within one type's
    # six slots (membership matching makes duplicates inert at
    # runtime, so a repeated value means the cache changed
    # underneath the design).
    required_skills_by_type = {}
    seen_required_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in REQUIRED_SKILL_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_required_keys:
            fail(
                f"duplicate required-skill row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable required-skill value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite required-skill value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value.is_integer() is False or value <= 0:
            fail(
                f"non-integral or non-positive required-skill value "
                f"{value!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        skill_id = int(value)
        existing = required_skills_by_type.setdefault(type_id, {})
        if skill_id in existing.values():
            fail(
                f"required skill {skill_id} repeated within type "
                f"{type_id} across attributes "
                f"{sorted(existing)} (attribute {attribute_id})"
            )
        seen_required_keys.add(key)
        existing[attribute_id] = skill_id

    # Charge groups per type (docs/charge-editing-design.md
    # section 3.1): only the five locked attributes, each parsed
    # from valueFloat. An unparseable, duplicated, non-finite,
    # non-integral, or non-positive wanted row fails loudly and
    # writes nothing (the capacitor block's global fail-loud
    # shape; the cache carries none of those rows).
    charge_groups_by_type = {}
    seen_charge_group_keys = set()
    for row in type_attributes:
        attribute_id = int(row["attributeID"])
        if attribute_id not in CHARGE_GROUP_ATTR_IDS:
            continue
        type_id = int(row["typeID"])
        key = (type_id, attribute_id)
        if key in seen_charge_group_keys:
            fail(
                f"duplicate charge-group row (type {type_id}, "
                f"attribute {attribute_id}) in dgmTypeAttributes"
            )
        try:
            value = float(row["valueFloat"])
        except (TypeError, ValueError):
            fail(
                f"unparseable charge-group value {row['valueFloat']!r} "
                f"for (type {type_id}, attribute {attribute_id})"
            )
        if not math.isfinite(value):
            fail(
                f"non-finite charge-group value {value!r} for "
                f"(type {type_id}, attribute {attribute_id})"
            )
        if value.is_integer() is False or value <= 0:
            fail(
                f"non-integral or non-positive charge-group value "
                f"{value!r} for (type {type_id}, "
                f"attribute {attribute_id})"
            )
        seen_charge_group_keys.add(key)
        charge_groups_by_type.setdefault(type_id, {})[attribute_id] = int(
            value
        )

    types = []
    missing_group = 0
    resource_key_counts = Counter()
    base_stat_key_counts = Counter()
    resonance_key_counts = Counter()
    bay_key_counts = Counter()
    calibration_key_counts = Counter()
    slot_layout_key_counts = Counter()
    nav_targeting_key_counts = Counter()
    dps_key_counts = Counter()
    cap_key_counts = Counter()
    repair_key_counts = Counter()
    need_filter_key_counts = Counter()
    charge_group_key_counts = Counter()
    resist_modifier_counts = Counter()
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
        # Additive damage-per-second emission (design section
        # 3.1): 28 keys append after `mass` in the locked
        # order. `speed`/`damageMultiplier` sparse on
        # categories 7 and 18; the four damage components
        # sparse on categories 8 and 18 (module-carried
        # damage on category 7 never emitted); the fighter
        # per-type keys sparse on category 87; the tube/slot
        # keys sparse on category 6; the ability markers
        # sparse true-only on category 87. Presence is
        # exactly source-row existence (present 0.0 kept,
        # absence never rewritten as zero); negative source
        # rows were skipped at load (see its deviation).
        dps = dps_by_type.get(type_id, {})
        if category_id in (7, 18):
            if SPEED_ATTR in dps:
                entry["speed"] = dps[SPEED_ATTR]
                dps_key_counts["speed"] += 1
            if DAMAGE_MULTIPLIER_ATTR in dps:
                entry["damageMultiplier"] = dps[DAMAGE_MULTIPLIER_ATTR]
                dps_key_counts["damageMultiplier"] += 1
        if category_id in (8, 18):
            if EM_DAMAGE_ATTR in dps:
                entry["emDamage"] = dps[EM_DAMAGE_ATTR]
                dps_key_counts["emDamage"] += 1
            if EXPLOSIVE_DAMAGE_ATTR in dps:
                entry["explosiveDamage"] = dps[EXPLOSIVE_DAMAGE_ATTR]
                dps_key_counts["explosiveDamage"] += 1
            if KINETIC_DAMAGE_ATTR in dps:
                entry["kineticDamage"] = dps[KINETIC_DAMAGE_ATTR]
                dps_key_counts["kineticDamage"] += 1
            if THERMAL_DAMAGE_ATTR in dps:
                entry["thermalDamage"] = dps[THERMAL_DAMAGE_ATTR]
                dps_key_counts["thermalDamage"] += 1
        if category_id == 87:
            if FIGHTER_SQUADRON_MAX_SIZE_ATTR in dps:
                entry["fighterSquadronMaxSize"] = dps[FIGHTER_SQUADRON_MAX_SIZE_ATTR]
                dps_key_counts["fighterSquadronMaxSize"] += 1
            if FIGHTER_SQUADRON_IS_LIGHT_ATTR in dps:
                entry["fighterSquadronIsLight"] = dps[FIGHTER_SQUADRON_IS_LIGHT_ATTR]
                dps_key_counts["fighterSquadronIsLight"] += 1
            if FIGHTER_SQUADRON_IS_SUPPORT_ATTR in dps:
                entry["fighterSquadronIsSupport"] = dps[FIGHTER_SQUADRON_IS_SUPPORT_ATTR]
                dps_key_counts["fighterSquadronIsSupport"] += 1
            if FIGHTER_SQUADRON_IS_HEAVY_ATTR in dps:
                entry["fighterSquadronIsHeavy"] = dps[FIGHTER_SQUADRON_IS_HEAVY_ATTR]
                dps_key_counts["fighterSquadronIsHeavy"] += 1
            if FIGHTER_ATTACK_DAMAGE_MULTIPLIER_ATTR in dps:
                entry["fighterAbilityAttackMissileDamageMultiplier"] = dps[FIGHTER_ATTACK_DAMAGE_MULTIPLIER_ATTR]
                dps_key_counts["fighterAbilityAttackMissileDamageMultiplier"] += 1
            if FIGHTER_ATTACK_DAMAGE_EM_ATTR in dps:
                entry["fighterAbilityAttackMissileDamageEM"] = dps[FIGHTER_ATTACK_DAMAGE_EM_ATTR]
                dps_key_counts["fighterAbilityAttackMissileDamageEM"] += 1
            if FIGHTER_ATTACK_DAMAGE_THERM_ATTR in dps:
                entry["fighterAbilityAttackMissileDamageTherm"] = dps[FIGHTER_ATTACK_DAMAGE_THERM_ATTR]
                dps_key_counts["fighterAbilityAttackMissileDamageTherm"] += 1
            if FIGHTER_ATTACK_DAMAGE_KIN_ATTR in dps:
                entry["fighterAbilityAttackMissileDamageKin"] = dps[FIGHTER_ATTACK_DAMAGE_KIN_ATTR]
                dps_key_counts["fighterAbilityAttackMissileDamageKin"] += 1
            if FIGHTER_ATTACK_DAMAGE_EXP_ATTR in dps:
                entry["fighterAbilityAttackMissileDamageExp"] = dps[FIGHTER_ATTACK_DAMAGE_EXP_ATTR]
                dps_key_counts["fighterAbilityAttackMissileDamageExp"] += 1
            if FIGHTER_ATTACK_DURATION_ATTR in dps:
                entry["fighterAbilityAttackMissileDuration"] = dps[FIGHTER_ATTACK_DURATION_ATTR]
                dps_key_counts["fighterAbilityAttackMissileDuration"] += 1
            if FIGHTER_MISSILES_DAMAGE_MULTIPLIER_ATTR in dps:
                entry["fighterAbilityMissilesDamageMultiplier"] = dps[FIGHTER_MISSILES_DAMAGE_MULTIPLIER_ATTR]
                dps_key_counts["fighterAbilityMissilesDamageMultiplier"] += 1
            if FIGHTER_MISSILES_DAMAGE_EM_ATTR in dps:
                entry["fighterAbilityMissilesDamageEM"] = dps[FIGHTER_MISSILES_DAMAGE_EM_ATTR]
                dps_key_counts["fighterAbilityMissilesDamageEM"] += 1
            if FIGHTER_MISSILES_DAMAGE_THERM_ATTR in dps:
                entry["fighterAbilityMissilesDamageTherm"] = dps[FIGHTER_MISSILES_DAMAGE_THERM_ATTR]
                dps_key_counts["fighterAbilityMissilesDamageTherm"] += 1
            if FIGHTER_MISSILES_DAMAGE_KIN_ATTR in dps:
                entry["fighterAbilityMissilesDamageKin"] = dps[FIGHTER_MISSILES_DAMAGE_KIN_ATTR]
                dps_key_counts["fighterAbilityMissilesDamageKin"] += 1
            if FIGHTER_MISSILES_DAMAGE_EXP_ATTR in dps:
                entry["fighterAbilityMissilesDamageExp"] = dps[FIGHTER_MISSILES_DAMAGE_EXP_ATTR]
                dps_key_counts["fighterAbilityMissilesDamageExp"] += 1
            if FIGHTER_MISSILES_DURATION_ATTR in dps:
                entry["fighterAbilityMissilesDuration"] = dps[FIGHTER_MISSILES_DURATION_ATTR]
                dps_key_counts["fighterAbilityMissilesDuration"] += 1
            if FIGHTER_ABILITY_ATTACK_EFFECT in type_effects_set:
                entry["fighterAbilityAttackM"] = True
                dps_key_counts["fighterAbilityAttackM"] += 1
            if FIGHTER_ABILITY_MISSILES_EFFECT in type_effects_set:
                entry["fighterAbilityMissiles"] = True
                dps_key_counts["fighterAbilityMissiles"] += 1
        if category_id == 6:
            if FIGHTER_TUBES_ATTR in dps:
                entry["fighterTubes"] = dps[FIGHTER_TUBES_ATTR]
                dps_key_counts["fighterTubes"] += 1
            if FIGHTER_LIGHT_SLOTS_ATTR in dps:
                entry["fighterLightSlots"] = dps[FIGHTER_LIGHT_SLOTS_ATTR]
                dps_key_counts["fighterLightSlots"] += 1
            if FIGHTER_SUPPORT_SLOTS_ATTR in dps:
                entry["fighterSupportSlots"] = dps[FIGHTER_SUPPORT_SLOTS_ATTR]
                dps_key_counts["fighterSupportSlots"] += 1
            if FIGHTER_HEAVY_SLOTS_ATTR in dps:
                entry["fighterHeavySlots"] = dps[FIGHTER_HEAVY_SLOTS_ATTR]
                dps_key_counts["fighterHeavySlots"] += 1
        # Additive turret range emission (volley-ranges-design
        # section 3.1): `maxRange` then `falloff`, sparse on
        # category 7 rows only, appended after the DPS
        # emission so they are the last keys in any row that
        # carries them. Drones (category 18) are excluded
        # deliberately: nothing reads a drone's 54 or 158.
        if category_id == 7:
            if MAX_RANGE_ATTR in dps:
                entry["maxRange"] = dps[MAX_RANGE_ATTR]
                dps_key_counts["maxRange"] += 1
            if FALLOFF_ATTR in dps:
                entry["falloff"] = dps[FALLOFF_ATTR]
                dps_key_counts["falloff"] += 1
        # Additive capacitor stability emission (design
        # section 3): `capacitorNeed`, `duration`,
        # `reloadTime` on category 7 or 66 rows carrying a
        # slot effect only, appended after `falloff` in this
        # locked key order. Presence is exactly source-row
        # existence (present 0.0 kept, absence never rewritten
        # as zero; the SDE default 10000.0 for reloadTime is
        # never substituted). The 67 booster gain is never
        # emitted.
        if category_id in (7, 66) and slot_effects:
            caps = cap_by_type.get(type_id, {})
            if CAPACITOR_NEED_ATTR in caps:
                entry["capacitorNeed"] = caps[CAPACITOR_NEED_ATTR]
                cap_key_counts["capacitorNeed"] += 1
            if DURATION_ATTR in caps:
                entry["duration"] = caps[DURATION_ATTR]
                cap_key_counts["duration"] += 1
            if RELOAD_TIME_ATTR in caps:
                entry["reloadTime"] = caps[RELOAD_TIME_ATTR]
                cap_key_counts["reloadTime"] += 1
        # Additive base active repair emission (design
        # section 3): eight keys append after the capacitor
        # keys in the locked order — amounts in shield /
        # armor / hull order, then markers grouped shield,
        # armor, hull. The gate is the capacitor gate plus a
        # self-repair effect: category 7 or 66 carrying a
        # slot effect and one of {4, 4936, 27, 5275, 26}.
        # Amount presence behind this gate *is* the
        # self-repair classification — a remote repairer never
        # gains an amount key even though the cache carries
        # its amount row (the ungated 145/161/33 totals are
        # rejected for exactly this reason). The markers
        # make the 17 abyssal no-data repairers
        # runtime-identifiable for excluded-with-count.
        # `duration` (73) is shared with the capacitor slice
        # and is not re-emitted; 1886 is never read.
        if (
            category_id in (7, 66)
            and slot_effects
            and (type_effects_set & REPAIR_SELF_EFFECT_IDS)
        ):
            repairs = repair_by_type.get(type_id, {})
            if SHIELD_BONUS_ATTR in repairs:
                entry["shieldBonus"] = repairs[SHIELD_BONUS_ATTR]
                repair_key_counts["shieldBonus"] += 1
            if ARMOR_DAMAGE_AMOUNT_ATTR in repairs:
                entry["armorDamageAmount"] = repairs[ARMOR_DAMAGE_AMOUNT_ATTR]
                repair_key_counts["armorDamageAmount"] += 1
            if STRUCTURE_DAMAGE_AMOUNT_ATTR in repairs:
                entry["structureDamageAmount"] = repairs[STRUCTURE_DAMAGE_AMOUNT_ATTR]
                repair_key_counts["structureDamageAmount"] += 1
            if SHIELD_BOOSTING_EFFECT in type_effects_set:
                entry["shieldBoosting"] = True
                repair_key_counts["shieldBoosting"] += 1
            if FUELED_SHIELD_BOOSTING_EFFECT in type_effects_set:
                entry["fueledShieldBoosting"] = True
                repair_key_counts["fueledShieldBoosting"] += 1
            if ARMOR_REPAIR_EFFECT in type_effects_set:
                entry["armorRepair"] = True
                repair_key_counts["armorRepair"] += 1
            if FUELED_ARMOR_REPAIR_EFFECT in type_effects_set:
                entry["fueledArmorRepair"] = True
                repair_key_counts["fueledArmorRepair"] += 1
            if STRUCTURE_REPAIR_EFFECT in type_effects_set:
                entry["structureRepair"] = True
                repair_key_counts["structureRepair"] += 1
        # Additive module need-filter emission
        # (docs/fitting-need-reductions-design.md section 4): two
        # keys append after the repair keys in the locked order
        # `groupId`, then `requiredSkillIds`, on exactly the
        # population that gains a need key today — category 7,
        # non-empty slotEffects, and at least one of attributes
        # 50/30 present. `groupId` is the invTypes `groupID`
        # column the category lookup already reads; the list
        # carries the six slots in attribute order, absent slots
        # skipped, always present including as an empty list —
        # that always-present shape is what lets the loader tell
        # "proven to require nothing relevant" from "filter data
        # not in this catalogue". Rigs, ships, and every other
        # row gain neither key.
        if (
            category_id == 7
            and slot_effects
            and (
                MODULE_CPU_NEED_ATTR in resources
                or MODULE_POWER_NEED_ATTR in resources
            )
        ):
            try:
                module_group_id = int(row["groupID"])
            except (TypeError, ValueError):
                fail(
                    f"unparseable groupID {row['groupID']!r} "
                    f"for type {type_id}"
                )
            entry["groupId"] = module_group_id
            need_filter_key_counts["groupId"] += 1
            skills = required_skills_by_type.get(type_id, {})
            required_skill_ids = [
                skills[attribute_id]
                for attribute_id in REQUIRED_SKILL_ATTR_IDS
                if attribute_id in skills
            ]
            entry["requiredSkillIds"] = required_skill_ids
            need_filter_key_counts["requiredSkillIds"] += 1
            need_filter_key_counts["requiredSkillValues"] += len(
                required_skill_ids
            )
        # Additive charge-group emission
        # (docs/charge-editing-design.md section 3.1): two keys
        # append after `requiredSkillIds` in the locked order
        # `chargeGroupIds`, then `chargeGroupId`, on mutually
        # exclusive populations. A category-7-or-32 row carrying
        # a slot effect and at least one group gains its accepted
        # groups as integers in attribute order, sparse; a
        # category-8 row gains its inventory group. The
        # category-23 and category-66 group carriers gain no key,
        # because no locked computation reads them.
        if category_id in (7, 32) and slot_effects:
            groups = charge_groups_by_type.get(type_id, {})
            if groups:
                charge_group_ids = [
                    groups[attribute_id]
                    for attribute_id in CHARGE_GROUP_ATTR_IDS
                    if attribute_id in groups
                ]
                entry["chargeGroupIds"] = charge_group_ids
                charge_group_key_counts["chargeGroupIds"] += 1
                charge_group_key_counts["chargeGroupValues"] += len(
                    charge_group_ids
                )
        if category_id == 8:
            try:
                charge_group_id = int(row["groupID"])
            except (TypeError, ValueError):
                fail(
                    f"unparseable groupID {row['groupID']!r} "
                    f"for type {type_id}"
                )
            entry["chargeGroupId"] = charge_group_id
            charge_group_key_counts["chargeGroupId"] += 1
        # Additive, sparse fitted-module resistance modifier
        # emission (design section 3): category 7 rows gain
        # the two keys after the last existing per-type key
        # block, in this locked order. A carrier with at
        # least one applicable entry or an unapplied mark
        # emits the array (possibly empty); an all-zero
        # carrier emits neither key. Every other row is
        # byte-identical.
        if category_id == 7 and type_id in resist_modifiers_by_type:
            mod_entries, mod_unapplied = resist_modifiers_by_type[type_id]
            entry["resistanceModifiers"] = mod_entries
            resist_modifier_counts["resistanceModifiers"] += 1
            if mod_entries:
                resist_modifier_counts["nonEmptyRows"] += 1
            resist_modifier_counts["totalEntries"] += len(mod_entries)
            if mod_unapplied:
                entry["resistanceModifiersUnapplied"] = True
                resist_modifier_counts["unappliedRows"] += 1
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

    # Fitted-module resistance modifier oracles (design
    # section 3). A None entries means neither
    # resistanceModifiers nor resistanceModifiersUnapplied
    # may be present at all.
    for type_id, expected, expected_unapplied in RESIST_MODIFIER_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(
                f"resistance modifier oracle type {type_id} "
                "missing from extract"
            )
        if expected is None:
            if (
                "resistanceModifiers" in entry
                or "resistanceModifiersUnapplied" in entry
            ):
                fail(
                    f"resistance modifier oracle type {type_id} "
                    "carries resistance modifier keys, expected "
                    "neither"
                )
        else:
            if entry.get("resistanceModifiers") != expected:
                fail(
                    f"resistance modifier oracle type {type_id} "
                    f"resistanceModifiers="
                    f"{entry.get('resistanceModifiers')!r}, "
                    f"expected {expected!r}"
                )
            if (
                entry.get("resistanceModifiersUnapplied", False)
                != expected_unapplied
            ):
                fail(
                    f"resistance modifier oracle type {type_id} "
                    "unapplied marker "
                    f"{entry.get('resistanceModifiersUnapplied')!r}, "
                    f"expected {expected_unapplied!r}"
                )
    if resist_modifier_counts["resistanceModifiers"] != RESIST_MODIFIER_ROWS:
        fail(
            f"resistance modifier rows "
            f"{resist_modifier_counts['resistanceModifiers']}, "
            f"expected {RESIST_MODIFIER_ROWS}"
        )
    if resist_modifier_counts["nonEmptyRows"] != RESIST_MODIFIER_NONEMPTY_ROWS:
        fail(
            f"resistance modifier non-empty rows "
            f"{resist_modifier_counts['nonEmptyRows']}, expected "
            f"{RESIST_MODIFIER_NONEMPTY_ROWS}"
        )
    if resist_modifier_counts["unappliedRows"] != RESIST_MODIFIER_MARKED_ROWS:
        fail(
            f"resistance modifier marked rows "
            f"{resist_modifier_counts['unappliedRows']}, expected "
            f"{RESIST_MODIFIER_MARKED_ROWS}"
        )
    if resist_modifier_counts["totalEntries"] != RESIST_MODIFIER_ENTRIES:
        fail(
            f"resistance modifier total entries "
            f"{resist_modifier_counts['totalEntries']}, expected "
            f"{RESIST_MODIFIER_ENTRIES}"
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
        # Fitted-module resistance modifier invariants (design
        # section 3): every present resistanceModifiers value
        # is on a category 7 row; entries are in
        # RESIST_MODIFIER_ORDER with no duplicate modified id,
        # operators in {0, 6}, operands finite and != 0.0;
        # resistanceModifiersUnapplied appears only beside
        # resistanceModifiers and only as true.
        if "resistanceModifiers" in entry:
            if entry["categoryId"] != 7:
                fail(
                    f"non-module type {entry['typeId']} carries "
                    "resistanceModifiers"
                )
            modified_ids = []
            for triple in entry["resistanceModifiers"]:
                if (
                    not isinstance(triple, list)
                    or len(triple) != 3
                    or not all(
                        isinstance(part, (int, float))
                        and not isinstance(part, bool)
                        for part in triple
                    )
                ):
                    fail(
                        f"type {entry['typeId']} malformed "
                        f"resistance modifier {triple!r}"
                    )
                modified_id, operator, operand = triple
                if modified_id not in RESIST_MODIFIER_ORDER:
                    fail(
                        f"type {entry['typeId']} modified id "
                        f"{modified_id} not a ship resonance"
                    )
                if operator not in RESIST_MODIFIER_OPERATORS:
                    fail(
                        f"type {entry['typeId']} operator "
                        f"{operator} not in (0, 6)"
                    )
                if (
                    not math.isfinite(float(operand))
                    or float(operand) == 0.0
                ):
                    fail(
                        f"type {entry['typeId']} operand "
                        f"{operand!r} not finite or zero"
                    )
                modified_ids.append(modified_id)
            order = [
                RESIST_MODIFIER_ORDER.index(modified_id)
                for modified_id in modified_ids
            ]
            if order != sorted(order) or len(set(order)) != len(order):
                fail(
                    f"type {entry['typeId']} resistance modifiers "
                    "not in locked order without duplicates"
                )
        if "resistanceModifiersUnapplied" in entry:
            if "resistanceModifiers" not in entry:
                fail(
                    f"type {entry['typeId']} unapplied marker "
                    "without resistanceModifiers"
                )
            if entry["resistanceModifiersUnapplied"] is not True:
                fail(
                    f"type {entry['typeId']} unapplied marker "
                    "not true"
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
        # Damage-per-second invariants (design sections 3.3):
        # every present DPS value is finite and >= 0.0 (not a
        # bool); `speed`/`damageMultiplier` appear only on
        # category 7 or 18 rows; the four damage components
        # only on category 8 or 18 rows; the fighter per-type
        # keys and both boolean markers only on category-87
        # rows; the four tube/slot keys only on category-6
        # rows; the two turret range keys only on category-7
        # rows. Absence stays distinct from 0.0.
        for key in (
            "speed",
            "damageMultiplier",
            "emDamage",
            "explosiveDamage",
            "kineticDamage",
            "thermalDamage",
            "fighterSquadronMaxSize",
            "fighterSquadronIsLight",
            "fighterSquadronIsSupport",
            "fighterSquadronIsHeavy",
            "fighterAbilityAttackMissileDamageMultiplier",
            "fighterAbilityAttackMissileDamageEM",
            "fighterAbilityAttackMissileDamageTherm",
            "fighterAbilityAttackMissileDamageKin",
            "fighterAbilityAttackMissileDamageExp",
            "fighterAbilityAttackMissileDuration",
            "fighterAbilityMissilesDamageMultiplier",
            "fighterAbilityMissilesDamageEM",
            "fighterAbilityMissilesDamageTherm",
            "fighterAbilityMissilesDamageKin",
            "fighterAbilityMissilesDamageExp",
            "fighterAbilityMissilesDuration",
            "fighterTubes",
            "fighterLightSlots",
            "fighterSupportSlots",
            "fighterHeavySlots",
            "maxRange",
            "falloff",
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
        for key in ("fighterAbilityAttackM", "fighterAbilityMissiles"):
            if key in entry and entry[key] is not True:
                fail(
                    f"type {entry['typeId']} {key}={entry[key]!r} "
                    "is not true-only"
                )
        for key in ("speed", "damageMultiplier"):
            if key in entry and entry["categoryId"] not in (7, 18):
                fail(
                    f"type {entry['typeId']} {key} on non-module/drone "
                    f"category {entry['categoryId']}"
                )
        for key in (
            "emDamage",
            "explosiveDamage",
            "kineticDamage",
            "thermalDamage",
        ):
            if key in entry and entry["categoryId"] not in (8, 18):
                fail(
                    f"type {entry['typeId']} {key} on non-charge/drone "
                    f"category {entry['categoryId']}"
                )
        for key in (
            "fighterSquadronMaxSize",
            "fighterSquadronIsLight",
            "fighterSquadronIsSupport",
            "fighterSquadronIsHeavy",
            "fighterAbilityAttackMissileDamageMultiplier",
            "fighterAbilityAttackMissileDamageEM",
            "fighterAbilityAttackMissileDamageTherm",
            "fighterAbilityAttackMissileDamageKin",
            "fighterAbilityAttackMissileDamageExp",
            "fighterAbilityAttackMissileDuration",
            "fighterAbilityMissilesDamageMultiplier",
            "fighterAbilityMissilesDamageEM",
            "fighterAbilityMissilesDamageTherm",
            "fighterAbilityMissilesDamageKin",
            "fighterAbilityMissilesDamageExp",
            "fighterAbilityMissilesDuration",
            "fighterAbilityAttackM",
            "fighterAbilityMissiles",
        ):
            if key in entry and entry["categoryId"] != 87:
                fail(
                    f"non-fighter type {entry['typeId']} carries {key}"
                )
        for key in (
            "fighterTubes",
            "fighterLightSlots",
            "fighterSupportSlots",
            "fighterHeavySlots",
        ):
            if key in entry and entry["categoryId"] != 6:
                fail(
                    f"non-ship type {entry['typeId']} carries {key}"
                )
        # Turret range invariants (volley-ranges-design
        # section 3.3): `maxRange`/`falloff` appear only on
        # category-7 rows (absence is allowed, never
        # required). Absence stays distinct from 0.0.
        for key in ("maxRange", "falloff"):
            if key in entry and entry["categoryId"] != 7:
                fail(
                    f"non-module type {entry['typeId']} carries {key}"
                )
        # Capacitor stability invariants (design section 3):
        # every present value is finite and >= 0.0 (not a
        # bool); any cap key implies category 7 or 66
        # carrying a slot effect (absence is allowed, never
        # required). Absence stays distinct from 0.0.
        for key in ("capacitorNeed", "duration", "reloadTime"):
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
                if entry["categoryId"] not in (7, 66) or not entry["slotEffects"]:
                    fail(
                        f"type {entry['typeId']} {key} on "
                        f"non-slot category {entry['categoryId']} "
                        f"with slotEffects {entry['slotEffects']}"
                    )
        # Base active repair invariants (sustained-tank-design
        # section 3): every present amount is finite and
        # >= 0.0 (not a bool); any of the eight keys implies
        # category 7 or 66 carrying a slot effect and a
        # self-repair effect; each amount key implies its
        # family's marker; at most one amount key per row;
        # markers are true-only. The loaded-paste key is on
        # no row at all. Absence stays distinct from 0.0.
        for key in (
            "shieldBonus",
            "armorDamageAmount",
            "structureDamageAmount",
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
                if entry["categoryId"] not in (7, 66) or not entry["slotEffects"]:
                    fail(
                        f"type {entry['typeId']} {key} on "
                        f"non-slot category {entry['categoryId']} "
                        f"with slotEffects {entry['slotEffects']}"
                    )
        if (
            "shieldBonus" in entry
            and "shieldBoosting" not in entry
            and "fueledShieldBoosting" not in entry
        ):
            fail(
                f"type {entry['typeId']} shieldBonus without a "
                "shield repair marker"
            )
        if (
            "armorDamageAmount" in entry
            and "armorRepair" not in entry
            and "fueledArmorRepair" not in entry
        ):
            fail(
                f"type {entry['typeId']} armorDamageAmount "
                "without an armor repair marker"
            )
        if (
            "structureDamageAmount" in entry
            and "structureRepair" not in entry
        ):
            fail(
                f"type {entry['typeId']} structureDamageAmount "
                "without a structure repair marker"
            )
        amount_keys = [
            key
            for key in (
                "shieldBonus",
                "armorDamageAmount",
                "structureDamageAmount",
            )
            if key in entry
        ]
        if len(amount_keys) > 1:
            fail(
                f"type {entry['typeId']} carries more than one "
                f"repair amount key: {amount_keys}"
            )
        for key in (
            "shieldBoosting",
            "fueledShieldBoosting",
            "armorRepair",
            "fueledArmorRepair",
            "structureRepair",
        ):
            if key in entry:
                if entry[key] is not True:
                    fail(
                        f"type {entry['typeId']} {key}={entry[key]!r} "
                        "is not true-only"
                    )
                if entry["categoryId"] not in (7, 66) or not entry["slotEffects"]:
                    fail(
                        f"type {entry['typeId']} {key} on "
                        f"non-slot category {entry['categoryId']} "
                        f"with slotEffects {entry['slotEffects']}"
                    )
        if "chargedArmorDamageMultiplier" in entry:
            fail(
                f"type {entry['typeId']} carries "
                "chargedArmorDamageMultiplier, which is never "
                "emitted (dry amounts only)"
            )
        # Module need-filter invariants (fitting-need-reductions-design
        # section 5, restated as fail-loud checks): `groupId` and
        # `requiredSkillIds` are present exactly when a need key
        # is; every group is a positive int (not a bool); every
        # list has at most six positive-int entries with no entry
        # repeated within the row.
        has_need_key = "cpu" in entry or "power" in entry
        if ("groupId" in entry) != has_need_key:
            fail(
                f"type {entry['typeId']} groupId presence does "
                f"not match its need keys"
            )
        if ("requiredSkillIds" in entry) != has_need_key:
            fail(
                f"type {entry['typeId']} requiredSkillIds "
                f"presence does not match its need keys"
            )
        if "groupId" in entry:
            group_value = entry["groupId"]
            if (
                not isinstance(group_value, int)
                or isinstance(group_value, bool)
                or group_value <= 0
            ):
                fail(
                    f"type {entry['typeId']} groupId={group_value!r} "
                    "is not a positive integral id"
                )
        if "requiredSkillIds" in entry:
            skill_list = entry["requiredSkillIds"]
            if len(skill_list) > 6:
                fail(
                    f"type {entry['typeId']} carries "
                    f"{len(skill_list)} requiredSkillIds, "
                    "expected at most six"
                )
            for skill_value in skill_list:
                if (
                    not isinstance(skill_value, int)
                    or isinstance(skill_value, bool)
                    or skill_value <= 0
                ):
                    fail(
                        f"type {entry['typeId']} "
                        f"requiredSkillIds entry {skill_value!r} "
                        "is not a positive integral id"
                    )
            if len(set(skill_list)) != len(skill_list):
                fail(
                    f"type {entry['typeId']} carries a repeated "
                    f"requiredSkillIds entry: {skill_list}"
                )
        # Charge-group invariants (charge-editing-design section
        # 3.1, restated as fail-loud checks): `chargeGroupId` is
        # present exactly when the row is category 8, always a
        # positive int (not a bool); `chargeGroupIds` appears
        # only on category-7-or-32 rows with a slot effect,
        # always a list of one to five positive ints with none
        # repeated. Absence means no group data for the row.
        if ("chargeGroupId" in entry) != (entry["categoryId"] == 8):
            fail(
                f"type {entry['typeId']} chargeGroupId presence does "
                f"not match its category"
            )
        if "chargeGroupId" in entry:
            charge_group_value = entry["chargeGroupId"]
            if (
                not isinstance(charge_group_value, int)
                or isinstance(charge_group_value, bool)
                or charge_group_value <= 0
            ):
                fail(
                    f"type {entry['typeId']} chargeGroupId="
                    f"{charge_group_value!r} is not a positive "
                    "integral id"
                )
        if "chargeGroupIds" in entry:
            if (
                entry["categoryId"] not in (7, 32)
                or not entry["slotEffects"]
            ):
                fail(
                    f"type {entry['typeId']} carries chargeGroupIds "
                    f"on non-slot category {entry['categoryId']} "
                    f"with slotEffects {entry['slotEffects']}"
                )
            group_list = entry["chargeGroupIds"]
            if not 1 <= len(group_list) <= 5:
                fail(
                    f"type {entry['typeId']} carries "
                    f"{len(group_list)} chargeGroupIds, "
                    "expected one to five"
                )
            for group_item in group_list:
                if (
                    not isinstance(group_item, int)
                    or isinstance(group_item, bool)
                    or group_item <= 0
                ):
                    fail(
                        f"type {entry['typeId']} chargeGroupIds entry "
                        f"{group_item!r} is not a positive integral id"
                    )
            if len(set(group_list)) != len(group_list):
                fail(
                    f"type {entry['typeId']} carries a repeated "
                    f"chargeGroupIds entry: {group_list}"
                )
        if "chargeGroupIds" in entry and "chargeGroupId" in entry:
            fail(
                f"type {entry['typeId']} carries both charge group keys"
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

    # Damage-per-second oracles (design section 3.2). A None
    # expected value means the key must be absent from that
    # row.
    for type_id, key, expected in DPS_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"damage-per-second oracle type {type_id} missing")
        if expected is None:
            if key in entry:
                fail(
                    f"damage-per-second oracle type {type_id} "
                    f"carries {key}={entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"damage-per-second oracle type {type_id} "
                f"{key}={entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pin: type 180 must carry all four damage
    # components present (two as 0.0), never absent (the two
    # are distinct, the 588 pin style).
    zero_dps_entry = by_id.get(180)
    if (
        zero_dps_entry is None
        or "explosiveDamage" not in zero_dps_entry
        or "thermalDamage" not in zero_dps_entry
    ):
        fail(
            "damage-per-second oracle type 180 explosiveDamage/"
            "thermalDamage keys must be present as 0.0"
        )
    for key, expected in DPS_EXPECTED_COUNTS.items():
        actual = dps_key_counts[key]
        if actual != expected:
            fail(
                f"damage-per-second key {key} count {actual}, "
                f"expected {expected}"
            )

    # Capacitor stability oracles (design section 3). A None
    # expected value means the key must be absent from that
    # row.
    for type_id, key, expected in CAP_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"capacitor stability oracle type {type_id} missing")
        if expected is None:
            if key in entry:
                fail(
                    f"capacitor stability oracle type {type_id} "
                    f"carries {key}={entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"capacitor stability oracle type {type_id} "
                f"{key}={entry.get(key)!r}, expected {expected!r}"
            )
    # Explicit-zero pin: type 2889 must carry capacitorNeed
    # present as 0.0, never absent (the two are distinct, the
    # 180 pin style).
    zero_cap_entry = by_id.get(2889)
    if (
        zero_cap_entry is None
        or "capacitorNeed" not in zero_cap_entry
    ):
        fail(
            "capacitor stability oracle type 2889 capacitorNeed "
            "key must be present as 0.0"
        )
    for key, expected in CAP_EXPECTED_COUNTS.items():
        actual = cap_key_counts[key]
        if actual != expected:
            fail(
                f"capacitor stability key {key} count {actual}, "
                f"expected {expected}"
            )

    # Base active repair oracles (design section 8). A None
    # expected value means the key must be absent from that
    # row. Markers compare as booleans: the emitted value is
    # JSON true.
    for type_id, key, expected in REPAIR_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"active repair oracle type {type_id} missing")
        if expected is None:
            if key in entry:
                fail(
                    f"active repair oracle type {type_id} "
                    f"carries {key}={entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"active repair oracle type {type_id} "
                f"{key}={entry.get(key)!r}, expected {expected!r}"
            )
    for key, expected in REPAIR_EXPECTED_COUNTS.items():
        actual = repair_key_counts[key]
        if actual != expected:
            fail(
                f"active repair key {key} count {actual}, "
                f"expected {expected}"
            )

    # Module need-filter oracles (design section 4). A None
    # expected value means the key must be absent from that row.
    for type_id, key, expected in NEED_FILTER_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"module need-filter oracle type {type_id} missing")
        if expected is None:
            if key in entry:
                fail(
                    f"module need-filter oracle type {type_id} "
                    f"carries {key}={entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"module need-filter oracle type {type_id} "
                f"{key}={entry.get(key)!r}, expected {expected!r}"
            )
    for key, expected in NEED_FILTER_EXPECTED_COUNTS.items():
        actual = need_filter_key_counts[key]
        if actual != expected:
            fail(
                f"module need-filter key {key} count {actual}, "
                f"expected {expected}"
            )

    # Charge-group oracles (design section 3.2). A None expected
    # value means the key must be absent from that row.
    for type_id, key, expected in CHARGE_GROUP_ORACLES:
        entry = by_id.get(type_id)
        if entry is None:
            fail(f"charge-group oracle type {type_id} missing")
        if expected is None:
            if key in entry:
                fail(
                    f"charge-group oracle type {type_id} "
                    f"carries {key}={entry[key]!r}, expected absent"
                )
        elif entry.get(key) != expected:
            fail(
                f"charge-group oracle type {type_id} "
                f"{key}={entry.get(key)!r}, expected {expected!r}"
            )
    for key, expected in CHARGE_GROUP_EXPECTED_COUNTS.items():
        actual = charge_group_key_counts[key]
        if actual != expected:
            fail(
                f"charge-group key {key} count {actual}, "
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
        f"resistance_modifier_keys resistanceModifiers={resist_modifier_counts['resistanceModifiers']} "
        f"nonEmptyRows={resist_modifier_counts['nonEmptyRows']} "
        f"unappliedRows={resist_modifier_counts['unappliedRows']} "
        f"totalEntries={resist_modifier_counts['totalEntries']}"
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
    print(
        f"dps_keys speed={dps_key_counts['speed']} "
        f"damageMultiplier={dps_key_counts['damageMultiplier']} "
        f"emDamage={dps_key_counts['emDamage']} "
        f"explosiveDamage={dps_key_counts['explosiveDamage']} "
        f"kineticDamage={dps_key_counts['kineticDamage']} "
        f"thermalDamage={dps_key_counts['thermalDamage']} "
        f"fighterSquadronMaxSize={dps_key_counts['fighterSquadronMaxSize']} "
        f"fighterSquadronIsLight={dps_key_counts['fighterSquadronIsLight']} "
        f"fighterSquadronIsSupport={dps_key_counts['fighterSquadronIsSupport']} "
        f"fighterSquadronIsHeavy={dps_key_counts['fighterSquadronIsHeavy']} "
        f"fighterAbilityAttackMissileDamageMultiplier={dps_key_counts['fighterAbilityAttackMissileDamageMultiplier']} "
        f"fighterAbilityAttackMissileDamageEM={dps_key_counts['fighterAbilityAttackMissileDamageEM']} "
        f"fighterAbilityAttackMissileDamageTherm={dps_key_counts['fighterAbilityAttackMissileDamageTherm']} "
        f"fighterAbilityAttackMissileDamageKin={dps_key_counts['fighterAbilityAttackMissileDamageKin']} "
        f"fighterAbilityAttackMissileDamageExp={dps_key_counts['fighterAbilityAttackMissileDamageExp']} "
        f"fighterAbilityAttackMissileDuration={dps_key_counts['fighterAbilityAttackMissileDuration']} "
        f"fighterAbilityMissilesDamageMultiplier={dps_key_counts['fighterAbilityMissilesDamageMultiplier']} "
        f"fighterAbilityMissilesDamageEM={dps_key_counts['fighterAbilityMissilesDamageEM']} "
        f"fighterAbilityMissilesDamageTherm={dps_key_counts['fighterAbilityMissilesDamageTherm']} "
        f"fighterAbilityMissilesDamageKin={dps_key_counts['fighterAbilityMissilesDamageKin']} "
        f"fighterAbilityMissilesDamageExp={dps_key_counts['fighterAbilityMissilesDamageExp']} "
        f"fighterAbilityMissilesDuration={dps_key_counts['fighterAbilityMissilesDuration']} "
        f"fighterTubes={dps_key_counts['fighterTubes']} "
        f"fighterLightSlots={dps_key_counts['fighterLightSlots']} "
        f"fighterSupportSlots={dps_key_counts['fighterSupportSlots']} "
        f"fighterHeavySlots={dps_key_counts['fighterHeavySlots']} "
        f"fighterAbilityAttackM={dps_key_counts['fighterAbilityAttackM']} "
        f"fighterAbilityMissiles={dps_key_counts['fighterAbilityMissiles']} "
        f"maxRange={dps_key_counts['maxRange']} "
        f"falloff={dps_key_counts['falloff']} "
        f"skipped_negative_rows={skipped_negative_dps_rows}"
    )
    print(
        f"cap_keys capacitorNeed={cap_key_counts['capacitorNeed']} "
        f"duration={cap_key_counts['duration']} "
        f"reloadTime={cap_key_counts['reloadTime']}"
    )
    print(
        f"repair_keys shieldBonus={repair_key_counts['shieldBonus']} "
        f"armorDamageAmount={repair_key_counts['armorDamageAmount']} "
        f"structureDamageAmount={repair_key_counts['structureDamageAmount']} "
        f"shieldBoosting={repair_key_counts['shieldBoosting']} "
        f"fueledShieldBoosting={repair_key_counts['fueledShieldBoosting']} "
        f"armorRepair={repair_key_counts['armorRepair']} "
        f"fueledArmorRepair={repair_key_counts['fueledArmorRepair']} "
        f"structureRepair={repair_key_counts['structureRepair']}"
    )
    print(
        f"need_filter_keys groupId={need_filter_key_counts['groupId']} "
        f"requiredSkillIds={need_filter_key_counts['requiredSkillIds']} "
        f"requiredSkillValues={need_filter_key_counts['requiredSkillValues']}"
    )
    print(
        f"charge_group_keys chargeGroupIds={charge_group_key_counts['chargeGroupIds']} "
        f"chargeGroupValues={charge_group_key_counts['chargeGroupValues']} "
        f"chargeGroupId={charge_group_key_counts['chargeGroupId']}"
    )


if __name__ == "__main__":
    main()
