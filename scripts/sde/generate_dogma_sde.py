import bz2
import csv
import json
import os
import urllib.request
from collections import defaultdict
from io import StringIO

# URLs for Fuzzwork CSV dumps
BASE_URL = "https://www.fuzzwork.co.uk/dump/latest/"
FILES = {
    "invCategories": "invCategories.csv.bz2",
    "invGroups": "invGroups.csv.bz2",
    "invTypes": "invTypes.csv.bz2",
    "dgmTypeAttributes": "dgmTypeAttributes.csv.bz2",
    "dgmTypeEffects": "dgmTypeEffects.csv.bz2"
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

def download_and_extract_csv(filename):
    url = BASE_URL + filename
    cache_path = os.path.join("scripts/sde", filename)
    
    if not os.path.exists(cache_path):
        print(f"Downloading {url}...")
        urllib.request.urlretrieve(url, cache_path)
    else:
        print(f"Using cached {cache_path}...")
        
    print(f"Extracting {filename}...")
    with bz2.BZ2File(cache_path, 'rb') as f:
        content = f.read().decode('utf-8')
    
    return list(csv.DictReader(StringIO(content)))

def main():
    os.makedirs("scripts/sde", exist_ok=True)
    os.makedirs("assets/sde", exist_ok=True)

    print("Loading data...")
    categories_raw = download_and_extract_csv(FILES["invCategories"])
    groups_raw = download_and_extract_csv(FILES["invGroups"])
    types_raw = download_and_extract_csv(FILES["invTypes"])
    attributes_raw = download_and_extract_csv(FILES["dgmTypeAttributes"])
    effects_raw = download_and_extract_csv(FILES["dgmTypeEffects"])

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
    for row in effects_raw:
        type_id = int(row['typeID'])
        if type_id in target_types:
            effect_id = int(row['effectID'])
            is_default = row['isDefault'] == '1'
            types_dict[type_id]["dogmaEffects"].append({
                "effectId": effect_id,
                "isDefault": is_default
            })

    print("Compiling final JSON...")
    final_data = {
        "categories": categories,
        "groups": groups,
        "types": list(types_dict.values())
    }

    out_path = "assets/sde/dogma.json"
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(final_data, f, separators=(',', ':'))

    print(f"Done! Wrote {len(types_dict)} types to {out_path}")

if __name__ == "__main__":
    main()
