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
where present.
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

    types = []
    missing_group = 0
    resource_key_counts = Counter()
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
        elif category_id == 7 and slot_effects:
            if MODULE_CPU_NEED_ATTR in resources:
                entry["cpu"] = resources[MODULE_CPU_NEED_ATTR]
                resource_key_counts["cpu"] += 1
            if MODULE_POWER_NEED_ATTR in resources:
                entry["power"] = resources[MODULE_POWER_NEED_ATTR]
                resource_key_counts["power"] += 1
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

    # Catalogue-wide invariant (design section 5): every category-6
    # row carries both ship outputs, so a future cache refresh that
    # drops a ship output fails loudly instead of blanking that ship.
    for entry in types:
        if entry["categoryId"] == 6 and (
            "cpuOutput" not in entry or "powerOutput" not in entry
        ):
            fail(
                f"ship type {entry['typeId']} missing cpuOutput/powerOutput"
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


if __name__ == "__main__":
    main()
