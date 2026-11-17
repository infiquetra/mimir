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
keys.
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

    types = []
    missing_group = 0
    resource_key_counts = Counter()
    base_stat_key_counts = Counter()
    resonance_key_counts = Counter()
    bay_key_counts = Counter()
    calibration_key_counts = Counter()
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


if __name__ == "__main__":
    main()
