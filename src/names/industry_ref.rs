//! Bundled industry reaction data (`assets/sde/industry.json`):

use std::collections::{HashMap, HashSet};

use serde::Deserialize;

use crate::error::{AppError, AppResult};

pub const REACTION_ACTIVITY_ID: i64 = 11;

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct IndustryMaterial {
    #[serde(rename = "typeId")]
    pub type_id: i64,
    #[serde(rename = "activityId")]
    pub activity_id: i64,
    #[serde(rename = "materialTypeId")]
    pub material_type_id: i64,
    #[serde(rename = "quantity")]
    pub quantity: i64,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct IndustryProduct {
    #[serde(rename = "typeId")]
    pub type_id: i64,
    #[serde(rename = "activityId")]
    pub activity_id: i64,
    #[serde(rename = "productTypeId")]
    pub product_type_id: i64,
    #[serde(rename = "quantity")]
    pub quantity: i64,
}

#[derive(Debug, Clone, Deserialize, Default)]
struct IndustryFile {
    #[serde(default)]
    materials: Vec<IndustryMaterial>,
    #[serde(default)]
    products: Vec<IndustryProduct>,
}

#[derive(Debug, Clone, Default)]
pub struct IndustryRef {
    pub materials: Vec<IndustryMaterial>,
    pub products: Vec<IndustryProduct>,
    material_index: HashMap<i64, Vec<usize>>,
    product_index: HashMap<i64, Vec<usize>>,
    reaction_blueprints: Vec<i64>,
}

impl IndustryRef {
    pub fn load_bundled() -> AppResult<Self> {
        tracing::debug!("[INDUSTRY] loading bundled industry data");
        Self::from_json(include_str!("../../assets/sde/industry.json"))
    }

    pub fn from_json(json: &str) -> AppResult<Self> {
        let file: IndustryFile = serde_json::from_str(json)?;
        let mut materials = Vec::new();
        let mut products = Vec::new();
        let mut skipped: usize = 0;
        let mut seen_materials: HashSet<(i64, i64)> = HashSet::new();
        let mut seen_products: HashSet<(i64, i64)> = HashSet::new();

        for row in file.materials {
            if row.activity_id != REACTION_ACTIVITY_ID {
                continue;
            }
            if row.type_id <= 0 || row.material_type_id <= 0 || row.quantity <= 0 {
                skipped = skipped.saturating_add(1);
                continue;
            }
            if !seen_materials.insert((row.type_id, row.material_type_id)) {
                skipped = skipped.saturating_add(1);
                continue;
            }
            materials.push(row);
        }

        for row in file.products {
            if row.activity_id != REACTION_ACTIVITY_ID {
                continue;
            }
            if row.type_id <= 0 || row.product_type_id <= 0 || row.quantity <= 0 {
                skipped = skipped.saturating_add(1);
                continue;
            }
            if !seen_products.insert((row.type_id, row.product_type_id)) {
                skipped = skipped.saturating_add(1);
                continue;
            }
            products.push(row);
        }

        let material_types: HashSet<i64> = materials.iter().map(|r| r.type_id).collect();
        let product_types: HashSet<i64> = products.iter().map(|r| r.type_id).collect();
        let mut reaction_blueprints: Vec<i64> = material_types
            .intersection(&product_types)
            .copied()
            .collect();
        reaction_blueprints.sort_unstable();

        let mut material_index: HashMap<i64, Vec<usize>> = HashMap::new();
        for (idx, row) in materials.iter().enumerate() {
            material_index.entry(row.type_id).or_default().push(idx);
        }
        let mut product_index: HashMap<i64, Vec<usize>> = HashMap::new();
        for (idx, row) in products.iter().enumerate() {
            product_index.entry(row.type_id).or_default().push(idx);
        }

        tracing::info!(
            "[INDUSTRY] industry reaction data loaded materials={} products={} reactions={} skipped={}",
            materials.len(),
            products.len(),
            reaction_blueprints.len(),
            skipped
        );

        if reaction_blueprints.is_empty() {
            return Err(AppError::Message(
                "[INDUSTRY] industry reaction catalogue is empty".to_string(),
            ));
        }

        Ok(Self {
            materials,
            products,
            material_index,
            product_index,
            reaction_blueprints,
        })
    }

    pub fn material_count(&self) -> usize {
        self.materials.len()
    }

    pub fn product_count(&self) -> usize {
        self.products.len()
    }

    pub fn reaction_blueprint_count(&self) -> usize {
        self.reaction_blueprints.len()
    }

    pub fn reaction_blueprint_type_ids(&self) -> &[i64] {
        &self.reaction_blueprints
    }

    pub fn is_reaction_blueprint(&self, type_id: i64) -> bool {
        self.reaction_blueprints.binary_search(&type_id).is_ok()
    }

    pub fn reaction_materials(&self, type_id: i64) -> Option<Vec<&IndustryMaterial>> {
        if !self.is_reaction_blueprint(type_id) {
            return None;
        }
        let indices = self.material_index.get(&type_id)?;
        let rows: Vec<&IndustryMaterial> = indices
            .iter()
            .filter_map(|&i| self.materials.get(i))
            .collect();
        if rows.is_empty() {
            None
        } else {
            Some(rows)
        }
    }

    pub fn reaction_products(&self, type_id: i64) -> Option<Vec<&IndustryProduct>> {
        if !self.is_reaction_blueprint(type_id) {
            return None;
        }
        let indices = self.product_index.get(&type_id)?;
        let rows: Vec<&IndustryProduct> = indices
            .iter()
            .filter_map(|&i| self.products.get(i))
            .collect();
        if rows.is_empty() {
            None
        } else {
            Some(rows)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bundled_catalogue_pins() {
        let data = IndustryRef::load_bundled().expect("bundled industry data loads");
        assert_eq!(data.material_count(), 384);
        assert_eq!(data.product_count(), 112);
        assert_eq!(data.reaction_blueprint_count(), 112);
        let ids = data.reaction_blueprint_type_ids();
        assert_eq!(ids.first(), Some(&45732));
        assert_eq!(ids.last(), Some(&57506));
        assert!(data.is_reaction_blueprint(57490));
        assert!(!data.is_reaction_blueprint(681));
        assert!(!data.is_reaction_blueprint(34));
        assert!(!data.is_reaction_blueprint(0));
        assert!(!data.is_reaction_blueprint(-1));
        assert!(data.is_reaction_blueprint(45732));
    }

    #[test]
    fn bundled_real_data_spot_pins() {
        let data = IndustryRef::load_bundled().expect("bundled loads");

        let mats = data.reaction_materials(57490).expect("materials 57490");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(4246, 5), (16633, 100), (16635, 100)]);
        let prods = data.reaction_products(57490).expect("products 57490");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(57453, 200)]);

        let mats = data.reaction_materials(46209).expect("materials 46209");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(4051, 5), (16659, 100), (16662, 100)]);
        let prods = data.reaction_products(46209).expect("products 46209");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(16679, 3000)]);

        let mats = data.reaction_materials(46157).expect("materials 46157");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(4246, 5), (30372, 100), (30373, 100), (37, 300)]);
        let prods = data.reaction_products(46157).expect("products 46157");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(30306, 160)]);

        let mats = data.reaction_materials(45732).expect("materials 45732");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(16657, 100), (16661, 100)]);
        let prods = data.reaction_products(45732).expect("products 45732");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(16672, 20)]);
    }

    #[test]
    fn bundled_catalogue_invariants() {
        let data = IndustryRef::load_bundled().expect("bundled loads");
        for row in &data.materials {
            assert_eq!(row.activity_id, REACTION_ACTIVITY_ID);
            assert!(row.type_id > 0);
            assert!(row.material_type_id > 0);
            assert!(row.quantity > 0);
        }
        for row in &data.products {
            assert_eq!(row.activity_id, REACTION_ACTIVITY_ID);
            assert!(row.type_id > 0);
            assert!(row.product_type_id > 0);
            assert!(row.quantity > 0);
        }

        let mut mat_keys = HashSet::new();
        for row in &data.materials {
            let k = (row.type_id, row.material_type_id);
            assert!(mat_keys.insert(k), "duplicate material key {k:?}");
        }
        let mut prod_keys = HashSet::new();
        for row in &data.products {
            let k = (row.type_id, row.product_type_id);
            assert!(prod_keys.insert(k), "duplicate product key {k:?}");
        }

        // Materials per blueprint distribution {2:1,3:69,4:36,5:5,6:1}
        let mut counts = HashMap::new();
        for row in &data.materials {
            *counts.entry(row.type_id).or_insert(0) += 1;
        }
        let mut dist = HashMap::new();
        for (_, c) in counts {
            *dist.entry(c).or_insert(0) += 1;
        }
        assert_eq!(dist.get(&2), Some(&1));
        assert_eq!(dist.get(&3), Some(&69));
        assert_eq!(dist.get(&4), Some(&36));
        assert_eq!(dist.get(&5), Some(&5));
        assert_eq!(dist.get(&6), Some(&1));
        assert_eq!(dist.len(), 5);

        // products per blueprint exactly 1 for all 112
        let mut prod_counts = HashMap::new();
        for row in &data.products {
            *prod_counts.entry(row.type_id).or_insert(0) += 1;
        }
        assert_eq!(prod_counts.len(), 112);
        for (_, c) in prod_counts {
            assert_eq!(c, 1);
        }

        let distinct_mat: HashSet<i64> =
            data.materials.iter().map(|r| r.material_type_id).collect();
        assert_eq!(distinct_mat.len(), 111);
        let distinct_prod: HashSet<i64> = data.products.iter().map(|r| r.product_type_id).collect();
        assert_eq!(distinct_prod.len(), 111);

        let ids = data.reaction_blueprint_type_ids();
        for w in ids.windows(2) {
            assert!(w[0] < w[1], "strictly ascending");
        }
    }

    fn minimal_valid_json() -> String {
        r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":201,"quantity":20}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#.to_string()
    }

    #[test]
    fn scope_drops_non_reaction_activities_and_ignores_unloaded_garbage() {
        let json = r#"{"activities":"junk","skills":7,"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":8,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("loads with unloaded garbage");
        assert_eq!(data.material_count(), 1);
        assert_eq!(data.product_count(), 1);
        assert_eq!(data.reaction_blueprint_count(), 1);
        let mats = data.reaction_materials(100).expect("materials");
        assert_eq!(mats.len(), 1);
        assert_eq!(mats[0].quantity, 10);
    }

    #[test]
    fn invalid_rows_are_skipped_and_empty_or_malformed_fails() {
        // Skips: type 0, negative, material/product 0, quantity 0 or negative
        let json = r#"{"materials":[{"typeId":0,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":-1,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":0,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":0},{"typeId":100,"activityId":11,"materialTypeId":201,"quantity":-5},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":101,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":0,"activityId":11,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":0,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":0},{"typeId":100,"activityId":11,"productTypeId":301,"quantity":-1},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5},{"typeId":101,"activityId":11,"productTypeId":300,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("valid siblings load");
        // retained: 100 material 200, 101 material 200 => 2
        assert_eq!(data.material_count(), 2);
        // retained: 100 product 300, 101 product 300 => 2
        assert_eq!(data.product_count(), 2);
        assert_eq!(data.reaction_blueprint_count(), 2);

        // Duplicates: repeated primary key keeps first, different material keeps both
        let json = r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":999},{"typeId":100,"activityId":11,"materialTypeId":201,"quantity":20}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":999},{"typeId":100,"activityId":11,"productTypeId":301,"quantity":7}]}"#;
        let data = IndustryRef::from_json(json).expect("duplicates handled");
        assert_eq!(data.material_count(), 2);
        assert_eq!(data.product_count(), 2);
        let mats = data.reaction_materials(100).expect("mats");
        assert_eq!(mats.len(), 2);
        assert_eq!(mats[0].quantity, 10);
        assert_eq!(mats[1].material_type_id, 201);
        let prods = data.reaction_products(100).expect("prods");
        assert_eq!(prods.len(), 2);
        assert_eq!(prods[0].quantity, 5);
        assert_eq!(prods[1].product_type_id, 301);

        // Failures
        assert!(IndustryRef::from_json("not json").is_err());
        assert!(IndustryRef::from_json("{}").is_err());
        assert!(IndustryRef::from_json(r#"{"materials":[],"products":[]}"#).is_err());
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5}]}"#
        )
        .is_err());
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[]}"#
        )
        .is_err());
        // Materials without matching product -> empty intersection
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":101,"activityId":11,"productTypeId":300,"quantity":5}]}"#
        )
        .is_err());
        // Row missing quantity
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#
        )
        .is_err());
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":11,"productTypeId":300}]}"#
        )
        .is_err());

        // Accessors:
        let json = r#"{"materials":[{"typeId":681,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":102,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("loads");
        // reaction_materials 681 is None even though activity-1 rows exist (dropped)
        assert!(data.reaction_materials(681).is_none());
        assert!(data.reaction_products(681).is_none());
        // materials-only orphan 102 yields None from both but rows count in materials
        assert_eq!(data.material_count(), 2);
        assert_eq!(data.product_count(), 1);
        assert!(data.reaction_materials(102).is_none());
        assert!(data.reaction_products(102).is_none());
        assert!(!data.is_reaction_blueprint(102));
        assert!(data.is_reaction_blueprint(100));
        let _ = minimal_valid_json;
    }
}
