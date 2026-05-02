#!/usr/bin/env python3
import json
import requests
import concurrent.futures
import sys
from typing import List, Tuple

IMAGE_SERVER_URL = "https://images.evetech.net/types/{type_id}/icon?size=64"
SDE_FILE = "assets/sde/skills.json"

def check_image(type_id: int, name: str) -> Tuple[int, str, bool, int]:
    url = IMAGE_SERVER_URL.format(type_id=type_id)
    try:
        # Use HEAD request to be efficient
        response = requests.head(url, timeout=10)
        return (type_id, name, response.status_code == 200, response.status_code)
    except Exception as e:
        return (type_id, name, False, -1)

def validate_skills():
    print(f"Loading SDE from {SDE_FILE}...")
    try:
        with open(SDE_FILE, 'r') as f:
            skills = json.load(f)
    except FileNotFoundError:
        print(f"Error: {SDE_FILE} not found.")
        sys.exit(1)

    print(f"Found {len(skills['types'])} skills. Validating images against EVE API...")
    
    results = []
    total_types = len(skills['types'])
    # Use ThreadPoolExecutor for concurrent network requests
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        future_to_skill = {
            executor.submit(check_image, skill['typeId'], skill['typeName']): skill 
            for skill in skills['types']
        }
        
        count = 0
        for future in concurrent.futures.as_completed(future_to_skill):
            type_id, name, success, status = future.result()
            results.append((type_id, name, success, status))
            count += 1
            if count % 50 == 0:
                print(f"Progress: {count}/{total_types} checked...")

    invalid = [r for r in results if not r[2]]
    
    print("\n" + "="*60)
    print(f"VALIDATION SUMMARY")
    print("="*60)
    print(f"Total skills checked: {total_types}")
    print(f"Valid images:        {total_types - len(invalid)}")
    print(f"Invalid images:      {len(invalid)}")
    print("="*60)

    if invalid:
        print("\nINVALID IDS FOUND:")
        print(f"{'Type ID':<10} | {'Status':<10} | {'Name'}")
        print("-" * 50)
        for type_id, name, success, status in sorted(invalid):
            print(f"{type_id:<10} | {status:<10} | {name}")
        print("-" * 50)
        print(f"\nTip: These IDs either don't exist or don't have an 'icon' on the EVE image server.")
    else:
        print("\nAll skill images are valid!")

if __name__ == "__main__":
    validate_skills()
