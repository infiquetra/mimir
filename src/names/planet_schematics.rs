//! Bundled planet schematics (`assets/sde/planet_schematics.json`): the 68
//! Planetary Industry factory schematics from the pinned SDE build 3503375
//! member `planetSchematics.jsonl` (see `docs/pi-schematics-design.md`).

use std::collections::BTreeMap;

use serde::Deserialize;

use crate::error::{AppError, AppResult};

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct SchematicTypeQty {
    #[serde(rename = "typeId")]
    pub type_id: i64,
    pub quantity: i64,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct PlanetSchematic {
    #[serde(rename = "schematicId")]
    pub schematic_id: i64,
    pub name: String,
    #[serde(rename = "cycleTime")]
    pub cycle_time: i64,
    pub pins: Vec<i64>,
    pub inputs: Vec<SchematicTypeQty>,
    pub output: SchematicTypeQty,
}

impl PlanetSchematic {
    pub fn allows_pin_type(&self, pin_type_id: i64) -> bool {
        if pin_type_id <= 0 {
            return false;
        }
        self.pins.binary_search(&pin_type_id).is_ok()
    }
}

#[derive(Debug, Clone, Deserialize)]
struct PlanetSchematicsManifest {
    // `sdeBuild`/`sourceFiles`/`generatedBy` are intentionally absent:
    // serde ignores unknown keys, so the loader never gates on the pinned
    // build. Carrying an unread field only to satisfy the manifest shape
    // tripped `-D warnings` dead-code; a future rebuild updates data and
    // tests, not loader code (design section 4).
    #[serde(rename = "datasetSchema", default)]
    dataset_schema: i64,
    #[serde(rename = "rowCounts", default)]
    row_counts: BTreeMap<String, usize>,
}

#[derive(Debug, Clone, Deserialize)]
struct PlanetSchematicsFile {
    #[serde(default)]
    manifest: Option<PlanetSchematicsManifest>,
    #[serde(default)]
    schematics: Vec<PlanetSchematic>,
}

pub struct PlanetSchematicsRef {
    pub schematics: Vec<PlanetSchematic>,
}

impl PlanetSchematicsRef {
    pub fn load_bundled() -> AppResult<Self> {
        tracing::debug!("[PI] loading bundled planet schematics");
        Self::from_json(include_str!("../../assets/sde/planet_schematics.json"))
    }

    pub fn from_json(json: &str) -> AppResult<Self> {
        let file: PlanetSchematicsFile = serde_json::from_str(json)?;
        let manifest = file.manifest.ok_or_else(|| {
            AppError::Message("[PI] planet schematics manifest is missing".to_string())
        })?;
        if manifest.dataset_schema != 1 {
            return Err(AppError::Message(
                "[PI] manifest datasetSchema != 1".to_string(),
            ));
        }
        if file.schematics.is_empty() {
            return Err(AppError::Message(
                "[PI] planet schematics catalogue is empty".to_string(),
            ));
        }
        let input_count: usize = file.schematics.iter().map(|s| s.inputs.len()).sum();
        let output_count = file.schematics.len();
        let type_entry_count = input_count + output_count;
        if manifest.row_counts.get("schematics") != Some(&file.schematics.len()) {
            return Err(AppError::Message(
                "[PI] manifest rowCounts.schematics mismatches parsed schematics".to_string(),
            ));
        }
        if manifest.row_counts.get("typeEntries") != Some(&type_entry_count) {
            return Err(AppError::Message(
                "[PI] manifest rowCounts.typeEntries mismatches parsed type entries".to_string(),
            ));
        }
        if manifest.row_counts.get("inputs") != Some(&input_count) {
            return Err(AppError::Message(
                "[PI] manifest rowCounts.inputs mismatches parsed inputs".to_string(),
            ));
        }
        if manifest.row_counts.get("outputs") != Some(&output_count) {
            return Err(AppError::Message(
                "[PI] manifest rowCounts.outputs mismatches parsed outputs".to_string(),
            ));
        }
        for schematic in &file.schematics {
            let id = schematic.schematic_id;
            if id <= 0 {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} schematicId <= 0"
                )));
            }
            if schematic.name.trim().is_empty() {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} name is empty"
                )));
            }
            if schematic.cycle_time <= 0 {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} cycleTime <= 0"
                )));
            }
            if schematic.pins.is_empty() {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} pins is empty"
                )));
            }
            if schematic.pins.iter().any(|&pin| pin <= 0) {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} pins contain a non-positive id"
                )));
            }
            if schematic.pins.windows(2).any(|w| w[0] >= w[1]) {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} pins not strictly ascending"
                )));
            }
            if !(1..=3).contains(&schematic.inputs.len()) {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} inputs count outside 1..=3"
                )));
            }
            for input in &schematic.inputs {
                if input.type_id <= 0 {
                    return Err(AppError::Message(format!(
                        "[PI] schematic {id} input typeId <= 0"
                    )));
                }
                if input.quantity <= 0 {
                    return Err(AppError::Message(format!(
                        "[PI] schematic {id} input quantity <= 0"
                    )));
                }
            }
            if schematic
                .inputs
                .windows(2)
                .any(|w| w[0].type_id >= w[1].type_id)
            {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} inputs not strictly ascending"
                )));
            }
            if schematic.output.type_id <= 0 {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} output typeId <= 0"
                )));
            }
            if schematic.output.quantity <= 0 {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} output quantity <= 0"
                )));
            }
            if schematic
                .inputs
                .iter()
                .any(|input| input.type_id == schematic.output.type_id)
            {
                return Err(AppError::Message(format!(
                    "[PI] schematic {id} output type repeats an input"
                )));
            }
        }
        if file
            .schematics
            .windows(2)
            .any(|w| w[0].schematic_id >= w[1].schematic_id)
        {
            return Err(AppError::Message(
                "[PI] schematic ids not strictly ascending".to_string(),
            ));
        }
        tracing::info!(
            "[PI] planet schematics loaded schematics={} type_entries={}",
            file.schematics.len(),
            type_entry_count
        );
        Ok(Self {
            schematics: file.schematics,
        })
    }

    pub fn schematic_count(&self) -> usize {
        self.schematics.len()
    }

    pub fn type_entry_count(&self) -> usize {
        self.schematics.iter().map(|s| s.inputs.len() + 1).sum()
    }

    pub fn schematic(&self, schematic_id: i64) -> Option<&PlanetSchematic> {
        if schematic_id <= 0 {
            return None;
        }
        self.schematics
            .binary_search_by_key(&schematic_id, |s| s.schematic_id)
            .ok()
            .map(|i| &self.schematics[i])
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::{json, Value};

    fn qty(type_id: i64, quantity: i64) -> SchematicTypeQty {
        SchematicTypeQty { type_id, quantity }
    }

    fn schematic(
        schematic_id: i64,
        name: &str,
        cycle_time: i64,
        pins: Vec<i64>,
        inputs: Vec<SchematicTypeQty>,
        output: SchematicTypeQty,
    ) -> PlanetSchematic {
        PlanetSchematic {
            schematic_id,
            name: name.to_string(),
            cycle_time,
            pins,
            inputs,
            output,
        }
    }

    #[test]
    fn bundled_catalogue_pins() {
        let data = PlanetSchematicsRef::load_bundled().expect("bundled loads");
        assert_eq!(data.schematic_count(), 68);
        assert_eq!(data.type_entry_count(), 203);
        let recomputed_entries: usize = data.schematics.iter().map(|s| s.inputs.len() + 1).sum();
        assert_eq!(recomputed_entries, 203);
        let recomputed_inputs: usize = data.schematics.iter().map(|s| s.inputs.len()).sum();
        assert_eq!(recomputed_inputs, 135);
        assert_eq!(data.schematics.first().map(|s| s.schematic_id), Some(65));
        assert_eq!(data.schematics.last().map(|s| s.schematic_id), Some(135));
        assert!(data.schematic(93).is_none());
        assert!(data.schematic(101).is_none());
        assert!(data.schematic(120).is_none());
        assert!(data.schematic(0).is_none());
        assert!(data.schematic(-1).is_none());

        let mut cycle_1800 = 0usize;
        let mut cycle_3600 = 0usize;
        let mut pin_universe = std::collections::BTreeSet::new();
        for s in &data.schematics {
            assert!(
                (1..=3).contains(&s.inputs.len()),
                "schematic {} inputs outside 1..=3",
                s.schematic_id
            );
            match s.cycle_time {
                1800 => cycle_1800 += 1,
                3600 => cycle_3600 += 1,
                other => panic!("schematic {} cycle {other}", s.schematic_id),
            }
            for input in &s.inputs {
                assert!(
                    [6, 10, 40, 3000].contains(&input.quantity),
                    "schematic {} input quantity {}",
                    s.schematic_id,
                    input.quantity
                );
            }
            assert!(
                [1, 3, 5, 20].contains(&s.output.quantity),
                "schematic {} output quantity {}",
                s.schematic_id,
                s.output.quantity
            );
            for pin in &s.pins {
                pin_universe.insert(*pin);
            }
        }
        assert_eq!(cycle_1800, 15);
        assert_eq!(cycle_3600, 53);
        let universe: Vec<i64> = pin_universe.into_iter().collect();
        assert_eq!(
            universe,
            vec![
                2469, 2470, 2471, 2472, 2473, 2474, 2475, 2480, 2481, 2482, 2483, 2484, 2485, 2490,
                2491, 2492, 2493, 2494
            ]
        );
    }

    #[test]
    fn bundled_real_data_spot_pins() {
        let data = PlanetSchematicsRef::load_bundled().expect("bundled loads");
        let advanced = vec![2470, 2472, 2474, 2480, 2484, 2485, 2491, 2494];
        let basic = vec![2469, 2471, 2473, 2481, 2483, 2490, 2492, 2493];
        assert_eq!(
            data.schematic(65),
            Some(&schematic(
                65,
                "Superconductors",
                3600,
                advanced.clone(),
                vec![qty(2389, 40), qty(3645, 40)],
                qty(9838, 5)
            ))
        );
        assert_eq!(
            data.schematic(75),
            Some(&schematic(
                75,
                "Enriched Uranium",
                3600,
                advanced.clone(),
                vec![qty(2399, 40), qty(2400, 40)],
                qty(44, 5)
            ))
        );
        assert_eq!(
            data.schematic(89),
            Some(&schematic(
                89,
                "Ukomi Superconductor",
                3600,
                advanced.clone(),
                vec![qty(3691, 10), qty(9838, 10)],
                qty(17136, 3)
            ))
        );
        assert_eq!(
            data.schematic(95),
            Some(&schematic(
                95,
                "Gel-Matrix Biopaste",
                3600,
                advanced.clone(),
                vec![qty(2317, 10), qty(2329, 10), qty(9838, 10)],
                qty(2348, 3)
            ))
        );
        assert_eq!(
            data.schematic(112),
            Some(&schematic(
                112,
                "Organic Mortar Applicators",
                3600,
                vec![2475, 2482],
                vec![qty(2344, 6), qty(2393, 40), qty(9848, 6)],
                qty(2870, 1)
            ))
        );
        assert_eq!(
            data.schematic(121),
            Some(&schematic(
                121,
                "Water",
                1800,
                basic.clone(),
                vec![qty(2268, 3000)],
                qty(3645, 20)
            ))
        );
        assert_eq!(
            data.schematic(135),
            Some(&schematic(
                135,
                "Industrial Fibers",
                1800,
                basic,
                vec![qty(2305, 3000)],
                qty(2397, 20)
            ))
        );
        let s65 = data.schematic(65).expect("65");
        assert!(s65.allows_pin_type(2480));
        assert!(!s65.allows_pin_type(2481));
        assert!(!s65.allows_pin_type(2475));
        assert!(!s65.allows_pin_type(0));
    }

    fn minimal_valid_json() -> String {
        r#"{"manifest":{"sdeBuild":3503375,"datasetSchema":1,"sourceFiles":[{"name":"planetSchematics.jsonl","sha256":"x"}],"generatedBy":"scripts/sde/generate_planet_schematics_sde.py","rowCounts":{"schematics":2,"typeEntries":5,"inputs":3,"outputs":2}},"schematics":[{"schematicId":65,"name":"Alpha","cycleTime":3600,"pins":[2470,2480],"inputs":[{"typeId":2389,"quantity":40},{"typeId":3645,"quantity":40}],"output":{"typeId":9838,"quantity":5}},{"schematicId":66,"name":"Beta","cycleTime":1800,"pins":[2475,2482],"inputs":[{"typeId":2268,"quantity":3000}],"output":{"typeId":3645,"quantity":20}}]}"#.to_string()
    }

    fn valid_value() -> Value {
        serde_json::from_str(&minimal_valid_json()).expect("minimal literal parses")
    }

    fn to_json(v: &Value) -> String {
        serde_json::to_string(v).expect("mutated value serializes")
    }

    #[test]
    fn from_json_rejects_invalid_catalogues() {
        let valid =
            PlanetSchematicsRef::from_json(&minimal_valid_json()).expect("minimal literal loads");
        assert_eq!(valid.schematic_count(), 2);
        assert_eq!(valid.type_entry_count(), 5);

        assert!(PlanetSchematicsRef::from_json("{not json").is_err());

        let mut empty = valid_value();
        empty["schematics"] = json!([]);
        empty["manifest"]["rowCounts"] = json!({
            "schematics": 0, "typeEntries": 0, "inputs": 0, "outputs": 0
        });
        assert!(PlanetSchematicsRef::from_json(&to_json(&empty)).is_err());

        let mut no_manifest = valid_value();
        no_manifest
            .as_object_mut()
            .expect("object")
            .remove("manifest");
        assert!(PlanetSchematicsRef::from_json(&to_json(&no_manifest)).is_err());

        let mut schema = valid_value();
        schema["manifest"]["datasetSchema"] = json!(2);
        assert!(PlanetSchematicsRef::from_json(&to_json(&schema)).is_err());

        for key in ["schematics", "typeEntries", "inputs", "outputs"] {
            let mut off = valid_value();
            let current = off["manifest"]["rowCounts"][key].as_i64().expect("count");
            off["manifest"]["rowCounts"][key] = json!(current + 1);
            assert!(
                PlanetSchematicsRef::from_json(&to_json(&off)).is_err(),
                "rowCounts.{key} off by one must fail"
            );
        }

        let mut dup = valid_value();
        dup["schematics"][1]["schematicId"] = json!(65);
        assert!(PlanetSchematicsRef::from_json(&to_json(&dup)).is_err());

        let mut order = valid_value();
        order["schematics"][1]["schematicId"] = json!(64);
        assert!(PlanetSchematicsRef::from_json(&to_json(&order)).is_err());

        let mut zero_id = valid_value();
        zero_id["schematics"][0]["schematicId"] = json!(0);
        assert!(PlanetSchematicsRef::from_json(&to_json(&zero_id)).is_err());

        let mut empty_name = valid_value();
        empty_name["schematics"][0]["name"] = json!("");
        assert!(PlanetSchematicsRef::from_json(&to_json(&empty_name)).is_err());

        let mut blank_name = valid_value();
        blank_name["schematics"][0]["name"] = json!("  ");
        assert!(PlanetSchematicsRef::from_json(&to_json(&blank_name)).is_err());

        let mut zero_cycle = valid_value();
        zero_cycle["schematics"][0]["cycleTime"] = json!(0);
        assert!(PlanetSchematicsRef::from_json(&to_json(&zero_cycle)).is_err());

        let mut no_pins = valid_value();
        no_pins["schematics"][0]["pins"] = json!([]);
        assert!(PlanetSchematicsRef::from_json(&to_json(&no_pins)).is_err());

        let mut unsorted_pins = valid_value();
        unsorted_pins["schematics"][0]["pins"] = json!([2480, 2470]);
        assert!(PlanetSchematicsRef::from_json(&to_json(&unsorted_pins)).is_err());

        let mut dup_pins = valid_value();
        dup_pins["schematics"][0]["pins"] = json!([2470, 2470]);
        assert!(PlanetSchematicsRef::from_json(&to_json(&dup_pins)).is_err());

        let mut zero_pin = valid_value();
        zero_pin["schematics"][0]["pins"] = json!([0, 2470]);
        assert!(PlanetSchematicsRef::from_json(&to_json(&zero_pin)).is_err());

        let mut no_inputs = valid_value();
        no_inputs["schematics"][0]["inputs"] = json!([]);
        no_inputs["manifest"]["rowCounts"]["inputs"] = json!(1);
        no_inputs["manifest"]["rowCounts"]["typeEntries"] = json!(3);
        assert!(PlanetSchematicsRef::from_json(&to_json(&no_inputs)).is_err());

        let mut four_inputs = valid_value();
        four_inputs["schematics"][0]["inputs"]
            .as_array_mut()
            .expect("array")
            .push(json!({"typeId": 2399, "quantity": 40}));
        four_inputs["manifest"]["rowCounts"]["inputs"] = json!(4);
        four_inputs["manifest"]["rowCounts"]["typeEntries"] = json!(6);
        assert!(PlanetSchematicsRef::from_json(&to_json(&four_inputs)).is_err());

        let mut zero_input_qty = valid_value();
        zero_input_qty["schematics"][0]["inputs"][0]["quantity"] = json!(0);
        assert!(PlanetSchematicsRef::from_json(&to_json(&zero_input_qty)).is_err());

        let mut zero_output_qty = valid_value();
        zero_output_qty["schematics"][0]["output"]["quantity"] = json!(0);
        assert!(PlanetSchematicsRef::from_json(&to_json(&zero_output_qty)).is_err());

        let mut zero_input_type = valid_value();
        zero_input_type["schematics"][0]["inputs"][0]["typeId"] = json!(0);
        assert!(PlanetSchematicsRef::from_json(&to_json(&zero_input_type)).is_err());

        let mut neg_output_type = valid_value();
        neg_output_type["schematics"][0]["output"]["typeId"] = json!(-1);
        assert!(PlanetSchematicsRef::from_json(&to_json(&neg_output_type)).is_err());

        let mut unsorted_inputs = valid_value();
        unsorted_inputs["schematics"][0]["inputs"] = json!([
            {"typeId": 3645, "quantity": 40},
            {"typeId": 2389, "quantity": 40}
        ]);
        assert!(PlanetSchematicsRef::from_json(&to_json(&unsorted_inputs)).is_err());

        let mut output_repeats_input = valid_value();
        output_repeats_input["schematics"][0]["output"]["typeId"] = json!(2389);
        assert!(PlanetSchematicsRef::from_json(&to_json(&output_repeats_input)).is_err());
    }
}
