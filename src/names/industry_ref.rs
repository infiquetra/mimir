//! Bundled industry data (`assets/sde/industry.json`): manufacturing activity 1
//! and reaction activity 11 rows, retained for the Production Chain and Reaction
//! calculators (see `docs/production-chain-design.md` and
//! `docs/industry-reaction-design.md`).

use std::collections::{HashMap, HashSet};

use serde::Deserialize;

use crate::error::{AppError, AppResult};

pub const MANUFACTURING_ACTIVITY_ID: i64 = 1;
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
    manufacturing_blueprints: Vec<i64>,
    reverse_blueprint_index: HashMap<i64, Vec<i64>>,
    buildable_product_type_ids: Vec<i64>,
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
        let mut seen_materials: HashSet<(i64, i64, i64)> = HashSet::new();
        let mut seen_products: HashSet<(i64, i64, i64)> = HashSet::new();

        for row in file.materials {
            if row.activity_id != MANUFACTURING_ACTIVITY_ID
                && row.activity_id != REACTION_ACTIVITY_ID
            {
                continue;
            }
            if row.type_id <= 0 || row.material_type_id <= 0 || row.quantity <= 0 {
                skipped = skipped.saturating_add(1);
                continue;
            }
            if !seen_materials.insert((row.type_id, row.activity_id, row.material_type_id)) {
                skipped = skipped.saturating_add(1);
                continue;
            }
            materials.push(row);
        }

        for row in file.products {
            if row.activity_id != MANUFACTURING_ACTIVITY_ID
                && row.activity_id != REACTION_ACTIVITY_ID
            {
                continue;
            }
            if row.type_id <= 0 || row.product_type_id <= 0 || row.quantity <= 0 {
                skipped = skipped.saturating_add(1);
                continue;
            }
            if !seen_products.insert((row.type_id, row.activity_id, row.product_type_id)) {
                skipped = skipped.saturating_add(1);
                continue;
            }
            products.push(row);
        }

        let mut manufacturing_material_types: HashSet<i64> = HashSet::new();
        let mut reaction_material_types: HashSet<i64> = HashSet::new();
        for row in &materials {
            match row.activity_id {
                MANUFACTURING_ACTIVITY_ID => {
                    manufacturing_material_types.insert(row.type_id);
                }
                REACTION_ACTIVITY_ID => {
                    reaction_material_types.insert(row.type_id);
                }
                _ => {}
            }
        }
        let mut manufacturing_product_types: HashSet<i64> = HashSet::new();
        let mut reaction_product_types: HashSet<i64> = HashSet::new();
        for row in &products {
            match row.activity_id {
                MANUFACTURING_ACTIVITY_ID => {
                    manufacturing_product_types.insert(row.type_id);
                }
                REACTION_ACTIVITY_ID => {
                    reaction_product_types.insert(row.type_id);
                }
                _ => {}
            }
        }
        let mut manufacturing_blueprints: Vec<i64> = manufacturing_material_types
            .intersection(&manufacturing_product_types)
            .copied()
            .collect();
        manufacturing_blueprints.sort_unstable();
        let mut reaction_blueprints: Vec<i64> = reaction_material_types
            .intersection(&reaction_product_types)
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

        // A product row creates a candidate only when its
        // blueprint is buildable at the row's own activity: a
        // blueprint buildable at one activity never leaks its
        // other activity's orphan product rows through the
        // reverse index.
        let buildable_at = |activity_id: i64, blueprint_type_id: i64| -> bool {
            match activity_id {
                MANUFACTURING_ACTIVITY_ID => manufacturing_blueprints
                    .binary_search(&blueprint_type_id)
                    .is_ok(),
                REACTION_ACTIVITY_ID => reaction_blueprints
                    .binary_search(&blueprint_type_id)
                    .is_ok(),
                _ => false,
            }
        };
        let mut reverse_with_activity: HashMap<i64, Vec<(i64, i64)>> = HashMap::new();
        for row in &products {
            if buildable_at(row.activity_id, row.type_id) {
                reverse_with_activity
                    .entry(row.product_type_id)
                    .or_default()
                    .push((row.activity_id, row.type_id));
            }
        }
        let mut reverse_blueprint_index: HashMap<i64, Vec<i64>> = HashMap::new();
        for (product_type_id, mut candidates) in reverse_with_activity {
            candidates.sort_unstable();
            // Sorted by activity then blueprint, so a blueprint
            // making the product at both activities appears
            // consecutively and dedups to one candidate;
            // product_row_for then applies the same probe order.
            let mut blueprint_ids: Vec<i64> = candidates
                .iter()
                .map(|&(_, blueprint_type_id)| blueprint_type_id)
                .collect();
            blueprint_ids.dedup();
            reverse_blueprint_index.insert(product_type_id, blueprint_ids);
        }
        let mut buildable_product_type_ids: Vec<i64> =
            reverse_blueprint_index.keys().copied().collect();
        buildable_product_type_ids.sort_unstable();

        tracing::info!(
            "[INDUSTRY] industry data loaded materials={} products={} manufacturing={} reactions={} skipped={}",
            materials.len(),
            products.len(),
            manufacturing_blueprints.len(),
            reaction_blueprints.len(),
            skipped
        );

        if manufacturing_blueprints.is_empty() && reaction_blueprints.is_empty() {
            return Err(AppError::Message(
                "[INDUSTRY] industry catalogue is empty".to_string(),
            ));
        }

        Ok(Self {
            materials,
            products,
            material_index,
            product_index,
            reaction_blueprints,
            manufacturing_blueprints,
            reverse_blueprint_index,
            buildable_product_type_ids,
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

    pub fn manufacturing_blueprint_count(&self) -> usize {
        self.manufacturing_blueprints.len()
    }

    pub fn manufacturing_blueprint_type_ids(&self) -> &[i64] {
        &self.manufacturing_blueprints
    }

    pub fn is_manufacturing_blueprint(&self, type_id: i64) -> bool {
        self.manufacturing_blueprints
            .binary_search(&type_id)
            .is_ok()
    }

    pub fn buildable_product_count(&self) -> usize {
        self.buildable_product_type_ids.len()
    }

    pub fn buildable_product_type_ids(&self) -> &[i64] {
        &self.buildable_product_type_ids
    }

    pub fn blueprints_producing(&self, product_type_id: i64) -> &[i64] {
        self.reverse_blueprint_index
            .get(&product_type_id)
            .map(Vec::as_slice)
            .unwrap_or(&[])
    }

    pub fn product_row_for(
        &self,
        blueprint_type_id: i64,
        product_type_id: i64,
    ) -> Option<&IndustryProduct> {
        let indices = self.product_index.get(&blueprint_type_id)?;
        // Only a row whose blueprint is buildable at the row's
        // own activity counts, and Manufacturing wins over
        // Reaction when the same blueprint makes the product
        // at both (the probe order the traversal mirrors).
        for activity_id in [MANUFACTURING_ACTIVITY_ID, REACTION_ACTIVITY_ID] {
            let buildable = match activity_id {
                MANUFACTURING_ACTIVITY_ID => self.is_manufacturing_blueprint(blueprint_type_id),
                _ => self.is_reaction_blueprint(blueprint_type_id),
            };
            if !buildable {
                continue;
            }
            if let Some(row) = indices
                .iter()
                .filter_map(|&i| self.products.get(i))
                .find(|row| {
                    row.product_type_id == product_type_id && row.activity_id == activity_id
                })
            {
                return Some(row);
            }
        }
        None
    }

    pub fn reaction_materials(&self, type_id: i64) -> Option<Vec<&IndustryMaterial>> {
        if !self.is_reaction_blueprint(type_id) {
            return None;
        }
        let indices = self.material_index.get(&type_id)?;
        let rows: Vec<&IndustryMaterial> = indices
            .iter()
            .filter_map(|&i| self.materials.get(i))
            .filter(|row| row.activity_id == REACTION_ACTIVITY_ID)
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
            .filter(|row| row.activity_id == REACTION_ACTIVITY_ID)
            .collect();
        if rows.is_empty() {
            None
        } else {
            Some(rows)
        }
    }

    pub fn manufacturing_materials(&self, type_id: i64) -> Option<Vec<&IndustryMaterial>> {
        if !self.is_manufacturing_blueprint(type_id) {
            return None;
        }
        let indices = self.material_index.get(&type_id)?;
        let rows: Vec<&IndustryMaterial> = indices
            .iter()
            .filter_map(|&i| self.materials.get(i))
            .filter(|row| row.activity_id == MANUFACTURING_ACTIVITY_ID)
            .collect();
        if rows.is_empty() {
            None
        } else {
            Some(rows)
        }
    }

    pub fn manufacturing_products(&self, type_id: i64) -> Option<Vec<&IndustryProduct>> {
        if !self.is_manufacturing_blueprint(type_id) {
            return None;
        }
        let indices = self.product_index.get(&type_id)?;
        let rows: Vec<&IndustryProduct> = indices
            .iter()
            .filter_map(|&i| self.products.get(i))
            .filter(|row| row.activity_id == MANUFACTURING_ACTIVITY_ID)
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
        assert_eq!(data.material_count(), 27190);
        assert_eq!(data.product_count(), 4917);
        assert_eq!(data.reaction_blueprint_count(), 112);
        assert_eq!(data.manufacturing_blueprint_count(), 4788);
        let ids = data.reaction_blueprint_type_ids();
        assert_eq!(ids.first(), Some(&45732));
        assert_eq!(ids.last(), Some(&57506));
        let manuf_ids = data.manufacturing_blueprint_type_ids();
        assert_eq!(manuf_ids.first(), Some(&681));
        assert_eq!(manuf_ids.last(), Some(&88734));
        assert!(data.is_reaction_blueprint(57490));
        assert!(!data.is_reaction_blueprint(681));
        assert!(!data.is_reaction_blueprint(34));
        assert!(!data.is_reaction_blueprint(0));
        assert!(!data.is_reaction_blueprint(-1));
        assert!(data.is_reaction_blueprint(45732));
        assert!(data.is_manufacturing_blueprint(681));
        assert!(data.is_manufacturing_blueprint(2813));
        assert!(!data.is_manufacturing_blueprint(57490));
        assert!(!data.is_manufacturing_blueprint(34));
        assert!(!data.is_manufacturing_blueprint(0));
        assert!(!data.is_manufacturing_blueprint(-1));
        assert_eq!(data.buildable_product_count(), 4891);
        let products = data.buildable_product_type_ids();
        assert_eq!(products.first(), Some(&165));
        assert_eq!(products.last(), Some(&88721));
        assert_eq!(data.blueprints_producing(57453), &[57490]);
        assert_eq!(data.blueprints_producing(17404), &[2813]);
        assert!(data.blueprints_producing(34).is_empty());
        assert!(data.blueprints_producing(0).is_empty());
        assert_eq!(data.blueprints_producing(16672), &[45732, 46207]);
        assert_eq!(
            data.blueprints_producing(21527),
            &[21522, 21524, 21526, 21528, 21530]
        );
        let multi: Vec<i64> = data
            .buildable_product_type_ids()
            .iter()
            .copied()
            .filter(|&product| data.blueprints_producing(product).len() > 1)
            .collect();
        assert_eq!(multi, vec![16672, 21527, 22925, 23416, 37161]);
        let row = data
            .product_row_for(57490, 57453)
            .expect("product row for Carbon Fiber");
        assert_eq!(row.activity_id, REACTION_ACTIVITY_ID);
        assert_eq!(row.quantity, 200);
        let row = data
            .product_row_for(2813, 17404)
            .expect("product row for Small Blaster Battery");
        assert_eq!(row.activity_id, MANUFACTURING_ACTIVITY_ID);
        assert_eq!(row.quantity, 1);
        assert!(data.product_row_for(57490, 17404).is_none());
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

        let mats = data.manufacturing_materials(2813).expect("materials 2813");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(2872, 1), (564, 1)]);
        let prods = data.manufacturing_products(2813).expect("products 2813");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(17404, 1)]);

        let mats = data.manufacturing_materials(1115).expect("materials 1115");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(34, 1596), (35, 690), (36, 144)]);
        let prods = data.manufacturing_products(1115).expect("products 1115");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(564, 1)]);

        let mats = data.manufacturing_materials(4316).expect("materials 4316");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(
            got,
            vec![
                (9848, 1),
                (44, 4),
                (3689, 4),
                (9832, 9),
                (16275, 20),
                (3683, 22),
                (16272, 170),
                (16273, 350),
                (17889, 450)
            ]
        );
        let prods = data.manufacturing_products(4316).expect("products 4316");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(4246, 40)]);

        let mats = data.manufacturing_materials(2769).expect("materials 2769");
        let got: Vec<(i64, i64)> = mats
            .iter()
            .map(|r| (r.material_type_id, r.quantity))
            .collect();
        assert_eq!(got, vec![(12238, 1)]);
        let prods = data.manufacturing_products(2769).expect("products 2769");
        let got_p: Vec<(i64, i64)> = prods
            .iter()
            .map(|r| (r.product_type_id, r.quantity))
            .collect();
        assert_eq!(got_p, vec![(12238, 1)]);
    }

    #[test]
    fn bundled_catalogue_invariants() {
        let data = IndustryRef::load_bundled().expect("bundled loads");
        for row in &data.materials {
            assert!(
                row.activity_id == MANUFACTURING_ACTIVITY_ID
                    || row.activity_id == REACTION_ACTIVITY_ID
            );
            assert!(row.type_id > 0);
            assert!(row.material_type_id > 0);
            assert!(row.quantity > 0);
        }
        for row in &data.products {
            assert!(
                row.activity_id == MANUFACTURING_ACTIVITY_ID
                    || row.activity_id == REACTION_ACTIVITY_ID
            );
            assert!(row.type_id > 0);
            assert!(row.product_type_id > 0);
            assert!(row.quantity > 0);
        }

        let mut mat_keys = HashSet::new();
        for row in &data.materials {
            let k = (row.type_id, row.activity_id, row.material_type_id);
            assert!(mat_keys.insert(k), "duplicate material key {k:?}");
        }
        let mut prod_keys = HashSet::new();
        for row in &data.products {
            let k = (row.type_id, row.activity_id, row.product_type_id);
            assert!(prod_keys.insert(k), "duplicate product key {k:?}");
        }

        // Materials per blueprint distribution at activity 1
        let mut counts = HashMap::new();
        for row in data
            .materials
            .iter()
            .filter(|row| row.activity_id == MANUFACTURING_ACTIVITY_ID)
        {
            *counts.entry(row.type_id).or_insert(0) += 1;
        }
        let mut dist = HashMap::new();
        for (_, c) in counts {
            *dist.entry(c).or_insert(0) += 1;
        }
        assert_eq!(dist.len(), 24);
        assert_eq!(dist.get(&1), Some(&346));
        assert_eq!(dist.get(&2), Some(&231));
        assert_eq!(dist.get(&3), Some(&862));
        assert_eq!(dist.get(&4), Some(&769));
        assert_eq!(dist.get(&5), Some(&656));
        assert_eq!(dist.get(&6), Some(&415));
        assert_eq!(dist.get(&7), Some(&499));
        assert_eq!(dist.get(&8), Some(&140));
        assert_eq!(dist.get(&9), Some(&236));
        assert_eq!(dist.get(&10), Some(&199));
        assert_eq!(dist.get(&11), Some(&273));
        assert_eq!(dist.get(&12), Some(&33));
        assert_eq!(dist.get(&13), Some(&33));
        assert_eq!(dist.get(&14), Some(&12));
        assert_eq!(dist.get(&15), Some(&50));
        assert_eq!(dist.get(&16), Some(&5));
        assert_eq!(dist.get(&17), Some(&6));
        assert_eq!(dist.get(&18), Some(&12));
        assert_eq!(dist.get(&19), Some(&15));
        assert_eq!(dist.get(&20), Some(&3));
        assert_eq!(dist.get(&21), Some(&9));
        assert_eq!(dist.get(&22), Some(&2));
        assert_eq!(dist.get(&23), Some(&3));
        assert_eq!(dist.get(&24), Some(&2));

        // Materials per blueprint distribution {2:1,3:69,4:36,5:5,6:1} at activity 11
        let mut counts = HashMap::new();
        for row in data
            .materials
            .iter()
            .filter(|row| row.activity_id == REACTION_ACTIVITY_ID)
        {
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

        // products per blueprint exactly 1 for all 4805 activity-1 and all 112 activity-11
        let mut prod_counts = HashMap::new();
        for row in data
            .products
            .iter()
            .filter(|row| row.activity_id == MANUFACTURING_ACTIVITY_ID)
        {
            *prod_counts.entry(row.type_id).or_insert(0) += 1;
        }
        assert_eq!(prod_counts.len(), 4805);
        for (_, c) in prod_counts {
            assert_eq!(c, 1);
        }
        let mut prod_counts = HashMap::new();
        for row in data
            .products
            .iter()
            .filter(|row| row.activity_id == REACTION_ACTIVITY_ID)
        {
            *prod_counts.entry(row.type_id).or_insert(0) += 1;
        }
        assert_eq!(prod_counts.len(), 112);
        for (_, c) in prod_counts {
            assert_eq!(c, 1);
        }

        let distinct_mat: HashSet<i64> = data
            .materials
            .iter()
            .filter(|row| row.activity_id == MANUFACTURING_ACTIVITY_ID)
            .map(|r| r.material_type_id)
            .collect();
        assert_eq!(distinct_mat.len(), 1571);
        let distinct_prod: HashSet<i64> = data
            .products
            .iter()
            .filter(|row| row.activity_id == MANUFACTURING_ACTIVITY_ID)
            .map(|r| r.product_type_id)
            .collect();
        assert_eq!(distinct_prod.len(), 4797);
        let distinct_mat: HashSet<i64> = data
            .materials
            .iter()
            .filter(|row| row.activity_id == REACTION_ACTIVITY_ID)
            .map(|r| r.material_type_id)
            .collect();
        assert_eq!(distinct_mat.len(), 111);
        let distinct_prod: HashSet<i64> = data
            .products
            .iter()
            .filter(|row| row.activity_id == REACTION_ACTIVITY_ID)
            .map(|r| r.product_type_id)
            .collect();
        assert_eq!(distinct_prod.len(), 111);

        let ids = data.reaction_blueprint_type_ids();
        for w in ids.windows(2) {
            assert!(w[0] < w[1], "strictly ascending");
        }
        let ids = data.manufacturing_blueprint_type_ids();
        for w in ids.windows(2) {
            assert!(w[0] < w[1], "strictly ascending");
        }
        let ids = data.buildable_product_type_ids();
        for w in ids.windows(2) {
            assert!(w[0] < w[1], "strictly ascending");
        }
        let manuf: HashSet<i64> = data
            .manufacturing_blueprint_type_ids()
            .iter()
            .copied()
            .collect();
        let reaction: HashSet<i64> = data.reaction_blueprint_type_ids().iter().copied().collect();
        assert!(manuf.is_disjoint(&reaction));
    }

    fn minimal_valid_json() -> String {
        r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":201,"quantity":20}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#.to_string()
    }

    #[test]
    fn scope_drops_non_reaction_activities_and_ignores_unloaded_garbage() {
        let json = r#"{"activities":"junk","skills":7,"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":8,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("loads with unloaded garbage");
        assert_eq!(data.material_count(), 2);
        assert_eq!(data.product_count(), 2);
        assert_eq!(data.reaction_blueprint_count(), 1);
        assert_eq!(data.manufacturing_blueprint_count(), 1);
        let mats = data.reaction_materials(100).expect("materials");
        assert_eq!(mats.len(), 1);
        assert_eq!(mats[0].quantity, 10);
        let manuf_mats = data.manufacturing_materials(100).expect("manuf materials");
        assert_eq!(manuf_mats.len(), 1);
        assert_eq!(manuf_mats[0].quantity, 10);
    }

    #[test]
    fn dedup_keys_include_activity() {
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":20},{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":999}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":7},{"typeId":100,"activityId":1,"productTypeId":300,"quantity":999}]}"#;
        let data = IndustryRef::from_json(json).expect("both activities kept");
        assert_eq!(data.material_count(), 2);
        assert_eq!(data.product_count(), 2);
        let manuf_mats = data.manufacturing_materials(100).expect("manuf mats");
        assert_eq!(manuf_mats.len(), 1);
        assert_eq!(manuf_mats[0].quantity, 10);
        let reaction_mats = data.reaction_materials(100).expect("reaction mats");
        assert_eq!(reaction_mats.len(), 1);
        assert_eq!(reaction_mats[0].quantity, 20);
        let manuf_prods = data.manufacturing_products(100).expect("manuf prods");
        assert_eq!(manuf_prods.len(), 1);
        assert_eq!(manuf_prods[0].quantity, 5);
        let reaction_prods = data.reaction_products(100).expect("reaction prods");
        assert_eq!(reaction_prods.len(), 1);
        assert_eq!(reaction_prods[0].quantity, 7);
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
        let data = IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5}]}"#,
        )
        .expect("activity-1-only loads");
        assert_eq!(data.manufacturing_blueprint_count(), 1);
        assert_eq!(data.reaction_blueprint_count(), 0);
        let data = IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":5}]}"#,
        )
        .expect("activity-11-only loads");
        assert_eq!(data.manufacturing_blueprint_count(), 0);
        assert_eq!(data.reaction_blueprint_count(), 1);
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[]}"#
        )
        .is_err());
        // Materials without matching product -> both intersections empty
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":10}],"products":[{"typeId":101,"activityId":11,"productTypeId":300,"quantity":5}]}"#
        )
        .is_err());
        assert!(IndustryRef::from_json(
            r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10}],"products":[{"typeId":101,"activityId":1,"productTypeId":300,"quantity":5}]}"#
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
        // reaction_materials 681 is None: 681 is not a reaction blueprint;
        // its activity-1 materials-only fixture rows make it a manufacturing
        // orphan, so the manufacturing accessor is also None while rows count.
        assert!(data.reaction_materials(681).is_none());
        assert!(data.reaction_products(681).is_none());
        assert!(data.manufacturing_materials(681).is_none());
        assert!(data.manufacturing_products(681).is_none());
        // materials-only orphan 102 yields None from both but rows count in materials
        assert_eq!(data.material_count(), 3);
        assert_eq!(data.product_count(), 1);
        assert!(data.reaction_materials(102).is_none());
        assert!(data.reaction_products(102).is_none());
        assert!(!data.is_reaction_blueprint(102));
        assert!(data.is_reaction_blueprint(100));
        assert!(data.blueprints_producing(300).contains(&100));
        let _ = minimal_valid_json;
    }

    #[test]
    fn dual_activity_accessors_filter_by_own_activity() {
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":20},{"typeId":100,"activityId":1,"materialTypeId":201,"quantity":30},{"typeId":100,"activityId":11,"materialTypeId":201,"quantity":40}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":300,"quantity":7}]}"#;
        let data = IndustryRef::from_json(json).expect("dual activity loads");
        assert!(data.is_manufacturing_blueprint(100));
        assert!(data.is_reaction_blueprint(100));
        let manuf = data.manufacturing_materials(100).expect("manuf mats");
        assert_eq!(manuf.len(), 2);
        assert!(manuf.iter().all(|row| row.activity_id == 1));
        let reaction = data.reaction_materials(100).expect("reaction mats");
        assert_eq!(reaction.len(), 2);
        assert!(reaction.iter().all(|row| row.activity_id == 11));
        let manuf_products = data.manufacturing_products(100).expect("manuf prods");
        assert_eq!(manuf_products.len(), 1);
        assert!(manuf_products.iter().all(|row| row.activity_id == 1));
        let reaction_products = data.reaction_products(100).expect("reaction prods");
        assert_eq!(reaction_products.len(), 1);
        assert!(reaction_products.iter().all(|row| row.activity_id == 11));
    }

    #[test]
    fn cross_activity_orphan_never_leaks_through_reverse_index() {
        // Blueprint 100 is buildable only at Manufacturing; its
        // Reaction product row for 301 is an orphan at that
        // activity and must not make 301 buildable.
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":100,"activityId":11,"productTypeId":301,"quantity":7}]}"#;
        let data = IndustryRef::from_json(json).expect("loads");
        assert_eq!(data.blueprints_producing(300), &[100]);
        assert!(data.blueprints_producing(301).is_empty());
        assert!(data.product_row_for(100, 301).is_none());
        let row300 = data.product_row_for(100, 300).expect("300 row");
        assert_eq!(row300.activity_id, 1);
        assert_eq!(row300.quantity, 5);
        // Same blueprint buildable at both activities and making
        // the same product at both: one candidate, and the
        // product row is the Manufacturing one (probe order).
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":100,"activityId":11,"materialTypeId":200,"quantity":20}],"products":[{"typeId":100,"activityId":11,"productTypeId":300,"quantity":7},{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("dual activity loads");
        assert_eq!(data.blueprints_producing(300), &[100]);
        let row = data.product_row_for(100, 300).expect("300 row");
        assert_eq!(row.activity_id, 1);
        assert_eq!(row.quantity, 5);
    }

    #[test]
    fn ambiguous_orphan_and_buildable_reverse_index() {
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":101,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":102,"activityId":1,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":101,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":102,"activityId":1,"productTypeId":400,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("loads");
        assert_eq!(data.blueprints_producing(300), &[100, 101]);
        assert_eq!(data.blueprints_producing(400), &[102]);
        assert!(data.blueprints_producing(999).is_empty());
        let json = r#"{"materials":[{"typeId":100,"activityId":1,"materialTypeId":200,"quantity":10},{"typeId":101,"activityId":1,"materialTypeId":200,"quantity":10}],"products":[{"typeId":100,"activityId":1,"productTypeId":300,"quantity":5},{"typeId":102,"activityId":1,"productTypeId":300,"quantity":5}]}"#;
        let data = IndustryRef::from_json(json).expect("orphan in same fixture still loads");
        assert_eq!(data.blueprints_producing(300), &[100]);
    }
}
