import csv
import json
import os
import urllib.request
from io import StringIO

# Fuzzwork mirror of CCP's Static Data Export. The dump moved its flat
# *.csv.bz2 files into a csv/ folder of plain CSVs (verified 2026-09-08:
# the old bz2 URLs 404), so everything is fetched from csv/ now.
BASE_URL = "https://www.fuzzwork.co.uk/dump/latest/csv/"
FILES = {
    "invCategories": "invCategories.csv",
    "invGroups": "invGroups.csv",
    "invTypes": "invTypes.csv",
    "dgmTypeAttributes": "dgmTypeAttributes.csv",
    "dgmTypeEffects": "dgmTypeEffects.csv",
    "dgmEffects": "dgmEffects.csv",
}

# Categories to include for fitting
TARGET_CATEGORIES = {
    6,   # Ship
    7,   # Module
    8,   # Charge
    18,  # Drone
    20,  # Implant
    22,  # Deployable
    32,  # Subsystem
}

def download_csv(filename):
    url = BASE_URL + filename
    cache_path = os.path.join("scripts/sde", filename)

    if not os.path.exists(cache_path):
        print(f"Downloading {url}...")
        urllib.request.urlretrieve(url, cache_path)
    else:
        print(f"Using cached {cache_path}...")

    with open(cache_path, newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

def parse_modifier_info(raw):
    """Normalize CCP's resolved modifier list (dgmEffects.modifierInfo).

    The SDE publishes the modifiers each effect applies — operator, modified
    and modifying attribute, domain, and for skill-scaled bonuses the skill
    and the group they are restricted to. This replaced the retired
    dgmExpressions table and is the same data ESI serves per effect.
    """
    if not raw:
        return []
    modifiers = []
    for m in json.loads(raw):
        # A modifier without a modified attribute cannot be applied by any
        # dogma consumer; drop it instead of shipping a null.
        if m.get("modifiedAttributeID") is None:
            continue
        modifier = {
            "func": m.get("func", ""),
            "operator": m.get("operation", -1),
            "modifiedAttributeId": m["modifiedAttributeID"],
            "domain": m.get("domain", "shipID"),
        }
        if m.get("modifyingAttributeID") is not None:
            modifier["modifyingAttributeId"] = m["modifyingAttributeID"]
        if m.get("skillTypeID") is not None:
            modifier["skillTypeId"] = m["skillTypeID"]
        if m.get("groupID") is not None:
            modifier["groupId"] = m["groupID"]
        modifiers.append(modifier)
    return modifiers

def main():
    os.makedirs("scripts/sde", exist_ok=True)
    os.makedirs("assets/sde", exist_ok=True)

    print("Loading data...")
    categories_raw = download_csv(FILES["invCategories"])
    groups_raw = download_csv(FILES["invGroups"])
    types_raw = download_csv(FILES["invTypes"])
    attributes_raw = download_csv(FILES["dgmTypeAttributes"])
    effects_raw = download_csv(FILES["dgmTypeEffects"])
    effect_meta_raw = download_csv(FILES["dgmEffects"])

    print("Processing effect metadata...")
    effect_meta = {}
    for row in effect_meta_raw:
        modifiers = parse_modifier_info(row.get("modifierInfo"))
        effect_meta[int(row["effectID"])] = {
            "name": row["effectName"],
            "modifiers": modifiers,
        }

    print("Processing Categories...")
    categories = []
    for row in categories_raw:
        cat_id = int(row['categoryID'])
        if cat_id in TARGET_CATEGORIES:
            categories.append({
                "categoryId": cat_id,
                "categoryName": row['categoryName']
            })

    print("Processing Groups...")
    target_groups = set()
    groups = []
    for row in groups_raw:
        cat_id = int(row['categoryID'])
        if cat_id in TARGET_CATEGORIES:
            group_id = int(row['groupID'])
            target_groups.add(group_id)
            groups.append({
                "groupId": group_id,
                "groupName": row['groupName'],
                "categoryId": cat_id
            })

    print("Processing Types...")
    target_types = set()
    types_dict = {}
    for row in types_raw:
        group_id = int(row['groupID'])
        published = row['published'] == '1'
        if group_id in target_groups and published:
            type_id = int(row['typeID'])
            target_types.add(type_id)
            types_dict[type_id] = {
                "typeId": type_id,
                "typeName": row['typeName'],
                "groupId": group_id,
                "description": row['description'],
                "dogmaAttributes": [],
                "dogmaEffects": []
            }
            # mass lives in the invTypes column, not in dgmTypeAttributes,
            # but dogma consumers (align time) need it as attribute 4.
            mass = row.get('mass')
            if mass and mass != 'None':
                types_dict[type_id]["dogmaAttributes"].append({
                    "attributeId": 4,
                    "value": float(mass)
                })

    print("Processing Attributes...")
    for row in attributes_raw:
        type_id = int(row['typeID'])
        if type_id in target_types:
            attr_id = int(row['attributeID'])
            # Prefer valueFloat, fallback to valueInt
            value = row['valueFloat']
            if not value or value == 'None':
                value = row['valueInt']

            if value and value != 'None':
                types_dict[type_id]["dogmaAttributes"].append({
                    "attributeId": attr_id,
                    "value": float(value)
                })

    print("Processing Effects...")
    referenced_effects = set()
    for row in effects_raw:
        type_id = int(row['typeID'])
        if type_id in target_types:
            effect_id = int(row['effectID'])
            is_default = row['isDefault'] == '1'
            referenced_effects.add(effect_id)
            entry = {
                "effectId": effect_id,
                "isDefault": is_default,
                "name": effect_meta.get(effect_id, {}).get("name", ""),
            }
            types_dict[type_id]["dogmaEffects"].append(entry)

    print("Compiling final JSON...")
    final_data = {
        "categories": categories,
        "groups": groups,
        "types": list(types_dict.values())
    }

    out_path = "assets/sde/dogma.json"
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(final_data, f, separators=(',', ':'))

    # Resolved modifiers are kept in their own asset: the fitting engine
    # needs them on every launch (even with a seeded database), while the
    # full type dump is only imported once.
    modifiers_data = {
        str(effect_id): effect_meta[effect_id]
        for effect_id in sorted(referenced_effects)
        if effect_id in effect_meta
        and (effect_meta[effect_id]["modifiers"] or effect_meta[effect_id]["name"])
    }
    modifiers_path = "assets/sde/effect_modifiers.json"
    with open(modifiers_path, 'w', encoding='utf-8') as f:
        json.dump(modifiers_data, f, separators=(',', ':'))

    print(f"Done! Wrote {len(types_dict)} types to {out_path}")
    print(f"Wrote {len(modifiers_data)} effect modifier entries to {modifiers_path}")

if __name__ == "__main__":
    main()
