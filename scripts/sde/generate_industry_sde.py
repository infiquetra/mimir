import bz2
import csv
import json
import os
import urllib.request
from io import StringIO

# URLs for Fuzzwork CSV dumps
BASE_URL = "https://www.fuzzwork.co.uk/dump/latest/"
FILES = {
    "industryActivity": "industryActivity.csv.bz2",
    "industryActivityMaterials": "industryActivityMaterials.csv.bz2",
    "industryActivityProbabilities": "industryActivityProbabilities.csv.bz2",
    "industryActivityProducts": "industryActivityProducts.csv.bz2",
    "industryActivitySkills": "industryActivitySkills.csv.bz2",
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

    print("Loading industry data...")
    activities_raw = download_and_extract_csv(FILES["industryActivity"])
    materials_raw = download_and_extract_csv(FILES["industryActivityMaterials"])
    probabilities_raw = download_and_extract_csv(FILES["industryActivityProbabilities"])
    products_raw = download_and_extract_csv(FILES["industryActivityProducts"])
    skills_raw = download_and_extract_csv(FILES["industryActivitySkills"])

    print("Processing Activities...")
    activities = []
    for row in activities_raw:
        activities.append({
            "typeId": int(row['typeID']),
            "activityId": int(row['activityID']),
            "time": int(row['time'])
        })

    print("Processing Materials...")
    materials = []
    for row in materials_raw:
        materials.append({
            "typeId": int(row['typeID']),
            "activityId": int(row['activityID']),
            "materialTypeId": int(row['materialTypeID']),
            "quantity": int(row['quantity'])
        })

    print("Processing Probabilities...")
    probabilities = []
    for row in probabilities_raw:
        probabilities.append({
            "typeId": int(row['typeID']),
            "activityId": int(row['activityID']),
            "productTypeId": int(row['productTypeID']),
            "probability": float(row['probability'])
        })

    print("Processing Products...")
    products = []
    for row in products_raw:
        products.append({
            "typeId": int(row['typeID']),
            "activityId": int(row['activityID']),
            "productTypeId": int(row['productTypeID']),
            "quantity": int(row['quantity'])
        })

    print("Processing Skills...")
    skills = []
    for row in skills_raw:
        skills.append({
            "typeId": int(row['typeID']),
            "activityId": int(row['activityID']),
            "skillId": int(row['skillID']),
            "level": int(row['level'])
        })

    print("Compiling final JSON...")
    final_data = {
        "activities": activities,
        "materials": materials,
        "probabilities": probabilities,
        "products": products,
        "skills": skills
    }

    out_path = "assets/sde/industry.json"
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(final_data, f, separators=(',', ':'))

    print(f"Done! Wrote industry data to {out_path}")

if __name__ == "__main__":
    main()
