#!/usr/bin/env python3
"""Generate assets/sde/planet_schematics.json from pinned CCP SDE 3503375.

Canonical source is the pinned CCP archive named in the same build as
``scripts/sde/generate_exploration_sde.py`` (build 3503375):

  https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-3503375-jsonl.zip

Network exists only inside this script at asset-generation time; the
shipped app performs zero network work for planet schematics
(``src/names/planet_schematics.rs`` loads via ``include_str!``).  The
script downloads once to ``scripts/sde/`` and reuses the cache on
later runs, following the ``generate_exploration_sde.py`` precedent.

The script reads exactly one member, ``planetSchematics.jsonl``.  It
never reads ``types.jsonl`` (type names are the resolver's job), never
reads Fuzzwork, and never hand-carries rows.  Every schematic carries
its English name (``name.en``) verbatim; the other seven languages are
dropped.  Type direction is decided by ``isInput`` alone, never by
position (the output entry is not reliably last).

If the pinned archive cannot be fetched or any self-validation below
fails, this script exits nonzero and writes no output.
"""

import collections
import hashlib
import json
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
OUTPUT = os.path.join("assets", "sde", "planet_schematics.json")

MEMBER = "planetSchematics.jsonl"
BYTE_BUDGET = 40000

# The 18 facility type IDs in the pinned ``planetSchematics.jsonl``,
# in the three sets tied 1:1 to ``cycleTime`` (design section 2.1):
# the 8 advanced facilities on the 45 3600-second schematics 65-111,
# the 8 basic facilities on the 15 1800-second schematics 121-135,
# and the 2 high-tech plants on the 8 3600-second schematics 112-119.
ADVANCED_PINS = (2470, 2472, 2474, 2480, 2484, 2485, 2491, 2494)
BASIC_PINS = (2469, 2471, 2473, 2481, 2483, 2490, 2492, 2493)
HIGH_TECH_PINS = (2475, 2482)
PIN_UNIVERSE = sorted(
    set(ADVANCED_PINS) | set(BASIC_PINS) | set(HIGH_TECH_PINS)
)

# Seven spot oracles (full-row equality after the inputs/output split),
# chosen to pin each trap in design section 2.1.
SPOTS = [
    {
        "schematicId": 65,
        "name": "Superconductors",
        "cycleTime": 3600,
        "pins": list(ADVANCED_PINS),
        "inputs": [(2389, 40), (3645, 40)],
        "output": (9838, 5),
    },
    {
        "schematicId": 75,
        "name": "Enriched Uranium",
        "cycleTime": 3600,
        "pins": list(ADVANCED_PINS),
        "inputs": [(2399, 40), (2400, 40)],
        "output": (44, 5),
    },
    {
        "schematicId": 89,
        "name": "Ukomi Superconductor",
        "cycleTime": 3600,
        "pins": list(ADVANCED_PINS),
        "inputs": [(3691, 10), (9838, 10)],
        "output": (17136, 3),
    },
    {
        "schematicId": 95,
        "name": "Gel-Matrix Biopaste",
        "cycleTime": 3600,
        "pins": list(ADVANCED_PINS),
        "inputs": [(2317, 10), (2329, 10), (9838, 10)],
        "output": (2348, 3),
    },
    {
        "schematicId": 112,
        "name": "Organic Mortar Applicators",
        "cycleTime": 3600,
        "pins": [2475, 2482],
        "inputs": [(2344, 6), (2393, 40), (9848, 6)],
        "output": (2870, 1),
    },
    {
        "schematicId": 121,
        "name": "Water",
        "cycleTime": 1800,
        "pins": list(BASIC_PINS),
        "inputs": [(2268, 3000)],
        "output": (3645, 20),
    },
    {
        "schematicId": 135,
        "name": "Industrial Fibers",
        "cycleTime": 1800,
        "pins": list(BASIC_PINS),
        "inputs": [(2305, 3000)],
        "output": (2397, 20),
    },
]


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


def is_int(value):
    return type(value) is int


def is_pos_int(value):
    return type(value) is int and value > 0


def main():
    zip_path = ensure_archive()
    with zipfile.ZipFile(zip_path) as zf:
        if MEMBER not in zf.namelist():
            fail(f"member {MEMBER} missing from archive")
        member_sha256 = sha256_of_member(zf, MEMBER)

        problems = []

        def check(condition, message):
            if not condition:
                problems.append(message)

        # Raw read: every non-blank line must parse; a malformed line
        # is a validation problem, not a traceback.
        raw_rows = []
        with zf.open(MEMBER) as fh:
            line_no = 0
            for raw_line in fh:
                line_no += 1
                stripped = raw_line.strip()
                if not stripped:
                    continue
                try:
                    raw_rows.append(json.loads(stripped))
                except json.JSONDecodeError as exc:
                    problems.append(f"line {line_no} malformed: {exc}")

    # --- row shape -------------------------------------------------
    check(len(raw_rows) == 68, f"rows != 68, got {len(raw_rows)}")

    parsed = []
    for idx, row in enumerate(raw_rows):
        where = f"row {idx} (_key={row.get('_key') if isinstance(row, dict) else '?'})"
        if not isinstance(row, dict):
            check(False, f"{where} is not an object")
            continue
        check(
            set(row.keys()) == {"_key", "cycleTime", "name", "pins", "types"},
            f"{where} key set != (_key,cycleTime,name,pins,types)",
        )
        sid = row.get("_key")
        check(is_pos_int(sid), f"{where} _key is not a positive integer")
        parsed.append(row)

    ids = [r["_key"] for r in parsed if is_pos_int(r.get("_key"))]
    check(len(set(ids)) == len(ids), "schematic IDs are not unique")
    check(
        set(ids) == set(range(65, 136)) - {93, 101, 120},
        f"schematic ID set != {{65..135}} \\ {{93,101,120}}",
    )

    # --- names ------------------------------------------------------
    names = []
    for row in parsed:
        sid = row.get("_key")
        where = f"schematic {sid}"
        name_map = row.get("name")
        en = None
        if isinstance(name_map, dict):
            en = name_map.get("en")
        check(
            isinstance(en, str) and bool(en.strip()),
            f"{where} name.en missing or empty",
        )
        if isinstance(en, str):
            names.append(en)
    check(len(set(names)) == 68, "name.en values are not 68 unique")

    # --- cycle times -------------------------------------------------
    cycle_dist = collections.Counter()
    for row in parsed:
        sid = row.get("_key")
        ct = row.get("cycleTime")
        check(is_pos_int(ct), f"schematic {sid} cycleTime not a positive integer")
        if is_pos_int(ct):
            cycle_dist[ct] += 1
    check(
        cycle_dist == collections.Counter({1800: 15, 3600: 53}),
        f"cycleTime distribution != {{1800:15,3600:53}}, got {dict(cycle_dist)}",
    )

    # --- pins ---------------------------------------------------------
    pin_size_dist = collections.Counter()
    pin_universe = set()
    pin_set_counts = collections.Counter()
    for row in parsed:
        sid = row.get("_key")
        where = f"schematic {sid}"
        pins = row.get("pins")
        check(
            isinstance(pins, list) and len(pins) > 0,
            f"{where} pins must be a non-empty list",
        )
        if not isinstance(pins, list):
            continue
        for pin in pins:
            check(is_pos_int(pin), f"{where} pin {pin!r} not a positive integer")
        if all(is_pos_int(p) for p in pins):
            check(
                all(a < b for a, b in zip(pins, pins[1:])),
                f"{where} pins not strictly ascending",
            )
            pin_universe.update(pins)
            pin_size_dist[len(pins)] += 1
            pin_set_counts[tuple(pins)] += 1
    check(
        pin_size_dist == collections.Counter({8: 60, 2: 8}),
        f"pin size distribution != {{8:60,2:8}}, got {dict(pin_size_dist)}",
    )
    check(
        sorted(pin_universe) == PIN_UNIVERSE,
        f"pin universe != 18 design IDs, got {sorted(pin_universe)}",
    )
    check(
        pin_set_counts.get(ADVANCED_PINS, 0) == 45,
        "advanced pin set count != 45",
    )
    check(
        pin_set_counts.get(BASIC_PINS, 0) == 15, "basic pin set count != 15"
    )
    check(
        pin_set_counts.get(HIGH_TECH_PINS, 0) == 8,
        "high-tech pin set count != 8",
    )

    # --- type entries -------------------------------------------------
    total_type_entries = 0
    all_type_ids = set()
    input_qty_set = set()
    output_qty_set = set()
    io_dist = collections.Counter()
    for row in parsed:
        sid = row.get("_key")
        where = f"schematic {sid}"
        types = row.get("types")
        check(isinstance(types, list), f"{where} types must be a list")
        if not isinstance(types, list):
            continue
        total_type_entries += len(types)
        inputs = []
        outputs = []
        seen = set()
        for entry in types:
            if not isinstance(entry, dict):
                check(False, f"{where} type entry is not an object")
                continue
            check(
                set(entry.keys()) == {"_key", "isInput", "quantity"},
                f"{where} type entry key set != (_key,isInput,quantity)",
            )
            tid = entry.get("_key")
            qty = entry.get("quantity")
            is_input = entry.get("isInput")
            check(is_pos_int(tid), f"{where} type _key not a positive integer")
            check(is_pos_int(qty), f"{where} type quantity not a positive integer")
            check(
                isinstance(is_input, bool),
                f"{where} type isInput is not a JSON bool",
            )
            if is_pos_int(tid):
                check(tid not in seen, f"{where} repeats type {tid}")
                seen.add(tid)
                all_type_ids.add(tid)
            if isinstance(is_input, bool):
                if is_input:
                    inputs.append(entry)
                    if is_pos_int(qty):
                        input_qty_set.add(qty)
                else:
                    outputs.append(entry)
                    if is_pos_int(qty):
                        output_qty_set.add(qty)
        input_ids = {
            e.get("_key") for e in inputs if is_pos_int(e.get("_key"))
        }
        output_ids = {
            e.get("_key") for e in outputs if is_pos_int(e.get("_key"))
        }
        check(
            not (input_ids & output_ids),
            f"{where} has a type as both input and output",
        )
        io_dist[(len(inputs), len(outputs))] += 1

    check(total_type_entries == 203, f"type entries != 203, got {total_type_entries}")
    check(len(all_type_ids) == 83, f"distinct type IDs != 83, got {len(all_type_ids)}")
    check(
        io_dist == collections.Counter({(1, 1): 15, (2, 1): 39, (3, 1): 14}),
        f"(inputs,outputs) distribution != {{(1,1):15,(2,1):39,(3,1):14}}, "
        f"got {dict(io_dist)}",
    )
    check(
        input_qty_set == {6, 10, 40, 3000},
        f"input quantity set != {{6,10,40,3000}}, got {sorted(input_qty_set)}",
    )
    check(
        output_qty_set == {1, 3, 5, 20},
        f"output quantity set != {{1,3,5,20}}, got {sorted(output_qty_set)}",
    )

    # Fail with the collected validation list before indexing
    # into rows to build the emitted document: a shape-malformed
    # member lists its problems instead of trace-backing.
    if problems:
        for p in problems:
            print(f"VALIDATION: {p}", file=sys.stderr)
        fail(f"self-validation failed with {len(problems)} problem(s)")

    # --- emitted schematics -------------------------------------------
    schematics = []
    for row in sorted(parsed, key=lambda r: r["_key"]):
        inputs = []
        output = None
        for entry in row["types"]:
            item = {"typeId": entry["_key"], "quantity": entry["quantity"]}
            if entry["isInput"]:
                inputs.append(item)
            else:
                output = item
        inputs.sort(key=lambda item: item["typeId"])
        schematics.append(
            {
                "schematicId": row["_key"],
                "name": row["name"]["en"],
                "cycleTime": row["cycleTime"],
                "pins": sorted(row["pins"]),
                "inputs": inputs,
                "output": output,
            }
        )

    # --- spot oracles ---------------------------------------------------
    by_id = {s["schematicId"]: s for s in schematics}
    for spot in SPOTS:
        sid = spot["schematicId"]
        got = by_id.get(sid)
        check(got is not None, f"spot schematic {sid} missing")
        if got is None:
            continue
        exp_inputs = [
            {"typeId": tid, "quantity": qty} for tid, qty in spot["inputs"]
        ]
        exp_output = {"typeId": spot["output"][0], "quantity": spot["output"][1]}
        check(got["name"] == spot["name"], f"spot {sid} name != {spot['name']!r}")
        check(
            got["cycleTime"] == spot["cycleTime"],
            f"spot {sid} cycleTime != {spot['cycleTime']}",
        )
        check(got["pins"] == spot["pins"], f"spot {sid} pins mismatch")
        check(got["inputs"] == exp_inputs, f"spot {sid} inputs mismatch")
        check(got["output"] == exp_output, f"spot {sid} output mismatch")

    # --- manifest ---------------------------------------------------------
    input_total = sum(len(s["inputs"]) for s in schematics)
    output_total = sum(1 for s in schematics if s["output"] is not None)
    manifest = {
        "sdeBuild": SDE_BUILD,
        "datasetSchema": 1,
        "sourceFiles": [{"name": MEMBER, "sha256": member_sha256}],
        "rowCounts": {
            "schematics": len(schematics),
            "typeEntries": total_type_entries,
            "inputs": input_total,
            "outputs": output_total,
        },
        "generatedBy": "scripts/sde/generate_planet_schematics_sde.py",
    }
    check(
        manifest["rowCounts"]
        == {"schematics": 68, "typeEntries": 203, "inputs": 135, "outputs": 68},
        f"manifest rowCounts mismatch: {manifest['rowCounts']}",
    )

    document = {"manifest": manifest, "schematics": schematics}

    if problems:
        for p in problems:
            print(f"VALIDATION: {p}", file=sys.stderr)
        fail(f"self-validation failed with {len(problems)} problem(s)")

    # Deterministic write: validate the budget on the serialized form
    # so the generator fails rather than writes past it.
    text = json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    byte_len = len(text.encode("utf-8"))
    if byte_len > BYTE_BUDGET:
        fail(f"output is {byte_len} bytes, over the {BYTE_BUDGET} budget")

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as fh:
        fh.write(text)

    digest = hashlib.sha256(open(OUTPUT, "rb").read()).hexdigest()
    s65 = by_id[65]
    s121 = by_id[121]
    print(f"wrote {OUTPUT} ({byte_len} bytes)")
    print(
        f"manifest rowCounts schematics={manifest['rowCounts']['schematics']} "
        f"typeEntries={manifest['rowCounts']['typeEntries']} "
        f"inputs={manifest['rowCounts']['inputs']} "
        f"outputs={manifest['rowCounts']['outputs']}"
    )
    print(f"sha256(output)={digest}")
    print(
        f"spot 65={s65['name']} 121={s121['name']}"
    )


if __name__ == "__main__":
    main()
