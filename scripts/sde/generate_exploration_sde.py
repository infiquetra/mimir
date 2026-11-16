#!/usr/bin/env python3
"""Generate assets/sde/exploration.json from pinned CCP SDE 3503375.

Canonical source is the pinned CCP archive named in Product spec
``docs/specs/exploration-module.md`` section 4.1 and architecture spec
``docs/specs/exploration-module-design.md`` section 2.1:

  https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip

Network exists only inside this script at asset-generation time; the
shipped app performs zero network work for the Exploration view
(exploration_ref.rs loads via ``include_str!``).  The script downloads
once to ``scripts/sde/`` and reuses the cache on later runs, following
the ``generate_dogma_sde.py`` precedent.

Effects (36 family/strength rows) are transcribed from the inspected
Flutter deriver (``EffectCatalog`` in
``lib/features/exploration/domain/exploration_reference_deriver.dart``
at ed698d3) and Product spec section 4.2.  The two inspected copies are
carried below and cross-checked; percentages are never derived from
dogma multipliers at extraction time.  Types and systems are extracted
from the pinned archive only: no Fuzzwork "latest", no hand-typed rows,
no values from memory or fixture files.

If the pinned archive cannot be fetched or any self-validation below
fails, this script exits nonzero and writes no output.
"""

import hashlib
import json
import math
import os
import sys
import urllib.request
import zipfile

SDE_BUILD = 3503375
ARCHIVE_URL = (
    "https://developers.eveonline.com/static-data/tranquility/"
    "eve-online-static-data-3503375-jsonl.zip"
)
CACHE_NAME = "eve-online-static-data-3503375-jsonl.zip"
OUTPUT = os.path.join("assets", "sde", "exploration.json")

# --- Effect constants transcribed from inspected bodies -----------------
# Deriver lines 221-224 define the four sequences; Product section 4.2
# tables row by row carry the same values.  A cross-check below sums
# them so the two inspected copies cannot silently diverge.
FAMILY_ORDER = [
    "pulsar",
    "blackHole",
    "cataclysmicVariable",
    "magnetar",
    "redGiant",
    "wolfRayet",
]

BEACONS = {
    "pulsar": [30844, 30865, 30866, 30867, 30868, 30869],
    "blackHole": [30845, 30850, 30851, 30852, 30853, 30854],
    # Strengths 4-6 deliberately not in ascending ID order (spec 4.2).
    "cataclysmicVariable": [30846, 30880, 30881, 30884, 30883, 30882],
    "magnetar": [30847, 30860, 30861, 30862, 30863, 30864],
    "redGiant": [30848, 30870, 30871, 30872, 30873, 30874],
    "wolfRayet": [30849, 30875, 30876, 30877, 30878, 30879],
}

PLUS30 = [30, 44, 58, 72, 86, 100]
PLUS15 = [15, 22, 29, 36, 43, 50]
MINUS15 = [-15, -22, -29, -36, -43, -50]
WOLF_RAYET_SMALL = [60, 88, 116, 144, 172, 200]

# Deriver ``_vectors`` (attribute -> strength vector) per family.
VECTORS = {
    "pulsar": {
        146: PLUS30,
        652: PLUS30,
        1465: PLUS15,
        1466: PLUS15,
        1467: PLUS15,
        1468: PLUS15,
        1500: MINUS15,
        1966: PLUS30,
    },
    "blackHole": {
        169: PLUS15,
        237: PLUS30,
        1469: PLUS15,
        1470: PLUS30,
        1483: PLUS30,
        1969: MINUS15,
    },
    "cataclysmicVariable": {
        1495: MINUS15,
        1496: MINUS15,
        1497: PLUS30,
        1498: PLUS30,
        1499: PLUS30,
        1500: PLUS15,
        1840: MINUS15,
    },
    "magnetar": {
        237: MINUS15,
        244: MINUS15,
        1482: PLUS30,
        1967: PLUS30,
        1968: MINUS15,
    },
    "redGiant": {
        1485: PLUS15,
        1486: PLUS30,
        1487: PLUS30,
        1488: PLUS30,
    },
    "wolfRayet": {
        148: PLUS30,
        652: MINUS15,
        1489: PLUS15,
        1490: PLUS15,
        1491: PLUS15,
        1492: PLUS15,
        1493: WOLF_RAYET_SMALL,
    },
}

# Product section 4.2 row headings (without the parenthesised source
# attribute).  Resonance ranges 1465-1468 and 1489-1492 are one
# rendered row each; the bundled file stores four attribute rows with
# the shared label and the view renders the label once per effect.
LABELS = {
    146: "Shield capacity",
    652: "Signature radius",
    1465: "Armor damage resonance, all types",
    1466: "Armor damage resonance, all types",
    1467: "Armor damage resonance, all types",
    1468: "Armor damage resonance, all types",
    1500: "Capacitor recharge time",
    1966: "Energy warfare strength",
    169: "Inertia/agility attribute",
    237: "Maximum targeting range",
    1469: "Missile velocity",
    1470: "Maximum ship velocity",
    1483: "Explosion velocity",
    1969: "Stasis web strength",
    1495: "Local armor repair amount",
    1496: "Local shield boost amount",
    1497: "Remote shield boost amount",
    1498: "Remote armor repair amount",
    1499: "Capacitor capacity",
    1840: "Remote capacitor transfer amount",
    244: "Tracking speed",
    1482: "Damage multiplier",
    1967: "Explosion radius",
    1968: "Target painter strength",
    1485: "Heat damage",
    1486: "Overload bonus",
    1487: "Smartbomb range",
    1488: "Smartbomb damage; applicable bomb damage/drain/ECM strength",
    148: "Armor HP",
    1489: "Shield damage resonance, all types",
    1490: "Shield damage resonance, all types",
    1491: "Shield damage resonance, all types",
    1492: "Shield damage resonance, all types",
    1493: "Small weapon damage",
}

VORTON_EFFECT_IDS = {11946, 11947, 11948, 11953}

SPECIAL_CLASSES = {1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 16, 17, 18, 25}

# Code derivation: a normal wormhole name is "Wormhole <CODE>"; the
# visible code is the text after that prefix.  Any other group-988 name
# (currently QA Wormhole A/B) keeps its full name as its code so no
# character is invented or dropped.
WORMHOLE_PREFIX = "Wormhole "

# Attributes read individually (Product section 4.1).  1382 is minutes
# stored raw; the x60 conversion happens in Rust.
WORMHOLE_ATTRS = (1381, 1382, 1383, 1384, 1385, 1457)


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def cache_path():
    return os.path.join("scripts", "sde", CACHE_NAME)


def ensure_archive():
    path = cache_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        print(f"Using cached {path} ...")
    else:
        print(f"Downloading {ARCHIVE_URL} ...")
        urllib.request.urlretrieve(ARCHIVE_URL, path)
        print(f"Downloaded to {path}")
    return path


def sha256_of_member(zf, name):
    h = hashlib.sha256()
    with zf.open(name) as fh:
        while True:
            chunk = fh.read(1 << 20)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def iter_jsonl(zf, name):
    with zf.open(name) as fh:
        for line in fh:
            line = line.strip()
            if line:
                yield json.loads(line)


def en_name(obj):
    name = obj.get("name") or {}
    if isinstance(name, dict):
        return name.get("en", "")
    return str(name)


def wormhole_code(en):
    if en.startswith(WORMHOLE_PREFIX):
        return en[len(WORMHOLE_PREFIX):]
    return en


def attr_as_int(value):
    iv = int(value)
    if iv != value:
        fail(f"dogma value {value!r} is not integral")
    return iv


def main():
    # Cross-check the two inspected effect copies agree on sequence
    # sums (deriver vectors vs Product tables).
    for seq in (PLUS30, PLUS15, MINUS15, WOLF_RAYET_SMALL):
        if len(seq) != 6:
            fail(f"effect sequence {seq!r} is not length 6")
    if sum(PLUS30) != 390 or sum(PLUS15) != 195:
        fail("effect sequence sums do not match Product 4.2")
    if sum(MINUS15) != -195 or sum(WOLF_RAYET_SMALL) != 780:
        fail("effect sequence sums do not match Product 4.2")

    zip_path = ensure_archive()
    with zipfile.ZipFile(zip_path) as zf:
        # --- types (group 988) + beacon existence (group 920) ---------
        wanted = set()
        for fam in FAMILY_ORDER:
            wanted.update(BEACONS[fam])
        types_988 = []
        beacons_present = set()
        with zf.open("types.jsonl") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                gid = obj.get("groupID")
                if gid == 988:
                    types_988.append(obj)
                elif gid == 920 and obj.get("_key") in wanted:
                    beacons_present.add(obj["_key"])
        if beacons_present != wanted:
            fail(
                f"beacon types missing from archive: "
                f"{sorted(wanted - beacons_present)}"
            )
        if not types_988:
            fail("no group-988 types found in types.jsonl")
        seen_ids = set()
        for obj in types_988:
            tid = obj["_key"]
            if tid in seen_ids:
                fail(f"duplicate type id {tid}")
            seen_ids.add(tid)

        # --- dogma for group-988 types only ---------------------------
        ids_988 = {obj["_key"] for obj in types_988}
        dogma = {}
        with zf.open("typeDogma.jsonl") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                if obj["_key"] in ids_988:
                    dogma[obj["_key"]] = {
                        a["attributeID"]: a["value"]
                        for a in obj.get("dogmaAttributes", [])
                    }

        types_rows = []
        for obj in sorted(types_988, key=lambda o: o["_key"]):
            tid = obj["_key"]
            en = en_name(obj)
            attrs = dogma.get(tid, {})
            row = {
                "typeId": tid,
                "code": wormhole_code(en),
                "name": en,
                "published": bool(obj.get("published", False)),
            }
            class_v = attrs.get(1381)
            dist_v = attrs.get(1457)
            time_v = attrs.get(1382)
            total_v = attrs.get(1383)
            regen_v = attrs.get(1384)
            jump_v = attrs.get(1385)
            if class_v is not None:
                row["rawTargetClass"] = attr_as_int(class_v)
            if dist_v is not None:
                row["rawTargetDistribution"] = attr_as_int(dist_v)
            if time_v is not None:
                minutes = attr_as_int(time_v)
                if minutes < 0:
                    fail(f"type {tid} has negative lifetime minutes")
                row["rawMaxStableTimeMinutes"] = minutes
            for key, value in (
                ("rawTotalMassKg", total_v),
                ("rawJumpMassKg", jump_v),
                ("rawRegenKg", regen_v),
            ):
                if value is not None:
                    fv = float(value)
                    if not math.isfinite(fv) or fv < 0:
                        fail(f"type {tid} has invalid mass {key}={fv!r}")
                    row[key] = fv
            # Empty identity is a hard validation error (render identity).
            if not row["code"] or not row["name"]:
                fail(f"type {tid} has empty code/name")
            types_rows.append(row)

        # --- regions / constellations / systems / secondary suns ------
        regions = {}
        with zf.open("mapRegions.jsonl") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                regions[obj["_key"]] = obj
        if not regions:
            fail("no regions found in mapRegions.jsonl")

        constellations = {}
        with zf.open("mapConstellations.jsonl") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                constellations[obj["_key"]] = obj
        if not constellations:
            fail("no constellations found in mapConstellations.jsonl")

        suns = {}
        with zf.open("mapSecondarySuns.jsonl") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                suns[obj["solarSystemID"]] = obj

        systems_rows = []
        seen_sys = set()
        with zf.open("mapSolarSystems.jsonl") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                sid = obj["_key"]
                if sid in seen_sys:
                    fail(f"duplicate system id {sid}")
                seen_sys.add(sid)
                sys_class = obj.get("wormholeClassID")
                const_id = obj.get("constellationID")
                region_id = obj.get("regionID")
                const_obj = constellations.get(const_id) or {}
                region_obj = regions.get(region_id) or {}
                const_class = const_obj.get("wormholeClassID")
                region_class = region_obj.get("wormholeClassID")
                if sys_class is not None:
                    inherited = sys_class
                    source = "system"
                elif const_class is not None:
                    inherited = const_class
                    source = "constellation"
                elif region_class is not None:
                    inherited = region_class
                    source = "region"
                else:
                    inherited = None
                    source = None
                # Special identity wins; keep only special-class systems.
                if inherited not in SPECIAL_CLASSES:
                    continue
                # Const/region names must resolve inside the same archive.
                if const_id not in constellations:
                    fail(f"system {sid} has unresolved constellation {const_id}")
                if region_id not in regions:
                    fail(f"system {sid} has unresolved region {region_id}")
                sun = suns.get(sid)
                beacon = None
                visual = None
                verified_absent = False
                if sun is not None:
                    beacon = sun.get("effectBeaconTypeID")
                    visual = sun.get("typeID")
                    if beacon is None:
                        verified_absent = True
                name_en = en_name(obj)
                if not name_en:
                    fail(f"system {sid} has empty name")
                row = {
                    "systemId": sid,
                    "name": name_en,
                    "constellationId": const_id,
                    "regionId": region_id,
                    "constellationName": en_name(const_obj),
                    "regionName": en_name(region_obj),
                    "rawSecurity": float(obj["securityStatus"])
                    if obj.get("securityStatus") is not None
                    else None,
                    "rawClass": sys_class,
                    "inheritedClass": inherited,
                    "inheritanceSource": source,
                    "effectBeaconTypeId": beacon,
                    "visualSunTypeId": visual,
                    "effectVerifiedAbsent": verified_absent,
                }
                # Drop None optional columns to keep output small; Rust
                # restores None via #[serde(default)].
                row = {k: v for k, v in row.items() if v is not None}
                # effectVerifiedAbsent False must stay present (bool).
                row["effectVerifiedAbsent"] = verified_absent
                systems_rows.append(row)

        systems_rows.sort(key=lambda r: (r["name"], r["systemId"]))

        # --- effects (36 rows from inspected vectors) -----------------
        effects_rows = []
        for fam in FAMILY_ORDER:
            for strength in range(1, 7):
                beacon = BEACONS[fam][strength - 1]
                modifiers = []
                for attr_id, vec in sorted(VECTORS[fam].items()):
                    if attr_id not in LABELS:
                        fail(f"missing Product label for attribute {attr_id}")
                    modifiers.append(
                        {
                            "attributeId": attr_id,
                            "label": LABELS[attr_id],
                            "percent": float(vec[strength - 1]),
                        }
                    )
                effects_rows.append(
                    {
                        "family": fam,
                        "strength": strength,
                        "beaconTypeId": beacon,
                        "modifiers": modifiers,
                    }
                )
        if len(effects_rows) != 36:
            fail(f"effects must be 36 rows, got {len(effects_rows)}")

        # --- source checksums -----------------------------------------
        source_names = [
            "types.jsonl",
            "typeDogma.jsonl",
            "mapSolarSystems.jsonl",
            "mapConstellations.jsonl",
            "mapRegions.jsonl",
            "mapSecondarySuns.jsonl",
            "groups.jsonl",
        ]
        source_files = [
            {"name": name, "sha256": sha256_of_member(zf, name)}
            for name in source_names
        ]

    manifest = {
        "sdeBuild": SDE_BUILD,
        "datasetSchema": 1,
        "sourceFiles": source_files,
        "rowCounts": {
            "types": len(types_rows),
            "systems": len(systems_rows),
            "effects": len(effects_rows),
            "statics": 0,
        },
        "generatedBy": "scripts/sde/generate_exploration_sde.py",
    }
    document = {
        "manifest": manifest,
        "types": types_rows,
        "systems": systems_rows,
        "effects": effects_rows,
        "statics": [],
    }

    # --- self-validation (design section 4 rule 5) ---------------------
    problems = []

    def check(condition, message):
        if not condition:
            problems.append(message)

    check(len(effects_rows) == 36, "effects != 36")
    check(
        len({(e["family"], e["strength"]) for e in effects_rows}) == 36,
        "effects (family, strength) not unique",
    )
    all_beacons = [b for fam in FAMILY_ORDER for b in BEACONS[fam]]
    check(len(all_beacons) == 36 and len(set(all_beacons)) == 36,
    "beacon set is not 36 unique")
    for e in effects_rows:
        check(1 <= e["strength"] <= 6, f"strength out of range {e}")
    check(
        len({t["typeId"] for t in types_rows}) == len(types_rows),
        "duplicate type IDs",
    )
    check(
        len({s["systemId"] for s in systems_rows}) == len(systems_rows),
        "duplicate system IDs",
    )
    check(
        len({e["beaconTypeId"] for e in effects_rows}) == 36,
        "duplicate beacon IDs",
    )
    # C729: Product section 4.1 and the architecture spec state 28
    # variants, but pinned build 3503375 contains 27 (verified
    # 2026-11-16 by counting group-988 rows named in types.jsonl and
    # dogma 1381==-1 rows).  Never invent a 28th row: validate the true
    # archive count and record the deviation.  If a future pinned build
    # restores the 28th variant this check must be revisited.
    c729 = [t for t in types_rows if t["code"] == "C729"]
    check(
        len(c729) == 27,
        f"C729 variants {len(c729)} != pinned-archive truth 27",
    )
    by_id = {t["typeId"]: t for t in types_rows}
    k162 = by_id.get(30831)
    check(k162 is not None, "K162 type 30831 missing")
    if k162 is not None:
        for key in (
            "rawTargetClass",
            "rawTargetDistribution",
            "rawMaxStableTimeMinutes",
            "rawTotalMassKg",
            "rawJumpMassKg",
            "rawRegenKg",
        ):
            check(key not in k162, f"K162 has dogma key {key}")
    b274 = by_id.get(30677)
    check(b274 is not None, "B274 type 30677 missing")
    if b274 is not None:
        check(b274.get("rawTargetClass") == 7, "B274 class != 7")
        check(b274.get("rawMaxStableTimeMinutes") == 1440, "B274 time != 1440")
        check(b274.get("rawTotalMassKg") == 2000000000.0, "B274 total != 2e9")
        check(b274.get("rawJumpMassKg") == 375000000.0, "B274 jump != 375M")
    i078 = by_id.get(92287)
    check(i078 is not None, "I078 type 92287 missing")
    if i078 is not None:
        check(i078.get("rawTargetClass") == 25, "I078 class != 25")
        check(i078.get("rawMaxStableTimeMinutes") == 270, "I078 time != 270")
    for t in types_rows:
        for key in ("rawTotalMassKg", "rawJumpMassKg", "rawRegenKg"):
            if key in t:
                v = t[key]
                check(
                    isinstance(v, float) and math.isfinite(v) and v >= 0,
                    f"type {t['typeId']} invalid {key}",
                )
        if "rawMaxStableTimeMinutes" in t:
            check(
                t["rawMaxStableTimeMinutes"] >= 0,
                f"type {t['typeId']} negative lifetime",
            )
    class13 = [
        s for s in systems_rows if s.get("inheritedClass") == 13
    ]
    check(len(class13) == 25, f"class-13 systems {len(class13)} != 25")
    for s in class13:
        check(
            s.get("effectBeaconTypeId") == 30879,
            f"class-13 {s['systemId']} beacon != 30879",
        )
    by_sys_name = {s["name"]: s for s in systems_rows}
    j005926 = by_sys_name.get("J005926")
    check(j005926 is not None, "system J005926 missing")
    if j005926 is not None:
        check(
            j005926.get("effectBeaconTypeId") == 30848,
            "J005926 beacon != 30848 (Red Giant 1)",
        )
    j010569 = by_sys_name.get("J010569")
    check(j010569 is not None, "system J010569 missing")
    if j010569 is not None:
        check(
            j010569.get("effectBeaconTypeId") == 30849,
            "J010569 beacon != 30849 (Wolf-Rayet 1)",
        )
    # Constellation/region names must be non-empty inside same archive.
    for s in systems_rows:
        check(bool(s.get("constellationName")), f"system {s['systemId']} no constellation")
        check(bool(s.get("regionName")), f"system {s['systemId']} no region")

    if problems:
        for p in problems:
            print(f"VALIDATION: {p}", file=sys.stderr)
        fail(f"self-validation failed with {len(problems)} problem(s)")

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as fh:
        json.dump(document, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write("\n")
    digest = hashlib.sha256(open(OUTPUT, "rb").read()).hexdigest()
    print(f"wrote {OUTPUT}")
    print(
        f"manifest rowCounts types={len(types_rows)} "
        f"systems={len(systems_rows)} effects={len(effects_rows)} statics=0"
    )
    print(f"sha256(output)={digest}")
    print(
        f"spot C729={len(c729)} K162={k162['code'] if k162 else None} "
        f"B274={b274['typeId'] if b274 else None} "
        f"class13={len(class13)} J005926={j005926['systemId'] if j005926 else None} "
        f"J010569={j010569['systemId'] if j010569 else None}"
    )


if __name__ == "__main__":
    main()
