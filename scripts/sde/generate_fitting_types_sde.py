#!/usr/bin/env python3
"""Generate assets/sde/fitting_types.json from committed SDE CSV caches.

Design: docs/fittings-import-design.md, section 4.1. Reads only the
committed Fuzzwork caches under scripts/sde/ (invTypes.csv.bz2,
invGroups.csv.bz2, dgmTypeEffects.csv.bz2); never the network. Fails
loudly (nonzero exit, no output written) if a cache file is missing or
self-validation fails, following the generate_exploration_sde.py
precedent.

Row rule: published == 1, typeID > 0, typeName non-empty after
stripping. All categories are kept (cargo can be any inventory type).
categoryId is denormalized from invGroups; a type whose group is
missing keeps categoryId 0 and is counted in the output. slotEffects
is the sorted, de-duplicated subset of the type's dgmTypeEffects rows
in {11, 12, 13, 2663, 3772} (the "_slotTypeFor" effects in Flutter's
sde_service.dart at ed698d3).

Output is deterministic: types sorted by typeId, compact separators,
no timestamps. Shape: {"types":[{"typeId":..,"typeName":..,
"categoryId":..,"slotEffects":[..]}, ...]} with camelCase keys
matching assets/sde/skills.json.
"""

import bz2
import csv
import json
import os
import re
import sys
from collections import Counter
from collections import defaultdict
from io import StringIO

SLOT_EFFECT_IDS = {11, 12, 13, 2663, 3772}

CACHES = {
    "invTypes": "invTypes.csv.bz2",
    "invGroups": "invGroups.csv.bz2",
    "dgmTypeEffects": "dgmTypeEffects.csv.bz2",
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

    group_to_category = {}
    for row in inv_groups:
        group_to_category[int(row["groupID"])] = int(row["categoryID"])

    effects_by_type = defaultdict(set)
    for row in type_effects:
        effects_by_type[int(row["typeID"])].add(int(row["effectID"]))

    types = []
    missing_group = 0
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
        types.append(
            {
                "typeId": type_id,
                "typeName": name,
                "categoryId": category_id,
                "slotEffects": slot_effects,
            }
        )

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


if __name__ == "__main__":
    main()
