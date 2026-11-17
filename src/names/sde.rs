//! Bundled SDE skill extract (`assets/sde/skills.json`): id to name/group.

use std::collections::HashMap;

use serde::Deserialize;

use crate::error::AppResult;

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct SdeCategory {
    #[serde(rename = "categoryId", default)]
    pub category_id: i64,
    #[serde(rename = "categoryName", default)]
    pub category_name: String,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct SdeGroup {
    #[serde(rename = "groupId", default)]
    pub group_id: i64,
    #[serde(rename = "groupName", default)]
    pub group_name: String,
    #[serde(rename = "categoryId", default)]
    pub category_id: i64,
}

/// One direct prerequisite edge from the bundled
/// extract: another skill and the level it must be
/// trained to before the owning skill can train.
#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct SdePrerequisite {
    #[serde(rename = "skillId", default)]
    pub skill_id: i64,
    #[serde(default)]
    pub level: i32,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct SdeSkillType {
    #[serde(rename = "typeId", default)]
    pub type_id: i64,
    #[serde(rename = "typeName", default)]
    pub type_name: String,
    #[serde(rename = "groupId", default)]
    pub group_id: i64,
    /// Skill rank (training-time multiplier); 0 when the extract omits it.
    #[serde(default)]
    pub rank: i64,
    #[serde(rename = "primaryAttribute", default)]
    pub primary_attribute: String,
    #[serde(rename = "secondaryAttribute", default)]
    pub secondary_attribute: String,
    /// Direct prerequisites, in extract file order.
    /// Empty for the 29 root skills whose JSON omits
    /// the key.
    #[serde(default)]
    pub prerequisites: Vec<SdePrerequisite>,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct SdeFile {
    #[serde(default)]
    categories: Vec<SdeCategory>,
    #[serde(default)]
    groups: Vec<SdeGroup>,
    #[serde(default)]
    types: Vec<SdeSkillType>,
}

/// In-memory SDE index for skill name/group lookups.
#[derive(Debug, Clone, Default)]
pub struct Sde {
    pub categories: Vec<SdeCategory>,
    pub groups: Vec<SdeGroup>,
    pub types: Vec<SdeSkillType>,
    by_id: HashMap<i64, usize>,
    group_by_id: HashMap<i64, usize>,
}

impl Sde {
    pub fn load_bundled() -> AppResult<Self> {
        tracing::debug!("[SKILLS] loading bundled SDE skills extract");
        Self::from_json(include_str!("../../assets/sde/skills.json"))
    }

    pub fn from_json(json: &str) -> AppResult<Self> {
        let file: SdeFile = serde_json::from_str(json)?;
        let mut by_id = HashMap::new();
        for (i, t) in file.types.iter().enumerate() {
            by_id.insert(t.type_id, i);
        }
        let mut group_by_id = HashMap::new();
        for (i, g) in file.groups.iter().enumerate() {
            group_by_id.insert(g.group_id, i);
        }
        let prerequisite_count: usize = file.types.iter().map(|t| t.prerequisites.len()).sum();
        tracing::info!(
            "[SKILLS] SDE loaded skills={} groups={} categories={} prerequisites={}",
            file.types.len(),
            file.groups.len(),
            file.categories.len(),
            prerequisite_count
        );
        Ok(Self {
            categories: file.categories,
            groups: file.groups,
            types: file.types,
            by_id,
            group_by_id,
        })
    }

    /// Number of skills in the bundled extract (0 after a failed load).
    pub fn skill_count(&self) -> usize {
        self.types.len()
    }

    pub fn contains(&self, skill_id: i64) -> bool {
        self.by_id.contains_key(&skill_id)
    }

    /// Full SDE entry for a skill, when the extract knows it.
    pub fn skill(&self, skill_id: i64) -> Option<&SdeSkillType> {
        self.types.get(*self.by_id.get(&skill_id)?)
    }

    /// Skill display name; SDE misses fall back to "Unknown Skill" so the
    /// interface never renders a raw numeric EVE ID.
    pub fn skill_name(&self, skill_id: i64) -> String {
        match self.by_id.get(&skill_id) {
            Some(&i) => self.types[i].type_name.clone(),
            None => {
                tracing::warn!("[SKILLS] SDE miss skill_id={}", skill_id);
                "Unknown Skill".to_string()
            }
        }
    }

    /// Like [`Self::skill_name`] but silent on a miss: for per-frame
    /// rendering of many rows, where a warning per frame would flood logs.
    pub fn skill_name_quiet(&self, skill_id: i64) -> String {
        match self.skill(skill_id) {
            Some(entry) => entry.type_name.clone(),
            None => "Unknown Skill".to_string(),
        }
    }

    pub fn group(&self, group_id: i64) -> Option<&SdeGroup> {
        self.groups.get(*self.group_by_id.get(&group_id)?)
    }

    /// Display name of a skill group (e.g. group 255 is "Gunnery").
    pub fn group_name(&self, group_id: i64) -> Option<String> {
        self.group(group_id).map(|g| g.group_name.clone())
    }

    pub fn skill_group_name(&self, skill_id: i64) -> Option<String> {
        let entry = self.skill(skill_id)?;
        self.group_name(entry.group_id)
    }

    /// Every skill in a group, sorted by display name (catalogue view).
    pub fn skills_in_group(&self, group_id: i64) -> Vec<&SdeSkillType> {
        let mut out: Vec<&SdeSkillType> = self
            .types
            .iter()
            .filter(|t| t.group_id == group_id)
            .collect();
        out.sort_by(|a, b| a.type_name.cmp(&b.type_name));
        out
    }

    /// Groups sorted by display name (catalogue view).
    pub fn groups_sorted(&self) -> Vec<&SdeGroup> {
        let mut out: Vec<&SdeGroup> = self.groups.iter().collect();
        out.sort_by(|a, b| a.group_name.cmp(&b.group_name));
        out
    }

    /// Case-insensitive substring search over skill names.
    pub fn search_skills(&self, query: &str) -> Vec<&SdeSkillType> {
        tracing::debug!("[SKILLS] search_skills query_len={}", query.len());
        let needle = query.to_lowercase();
        let mut out: Vec<&SdeSkillType> = self
            .types
            .iter()
            .filter(|t| t.type_name.to_lowercase().contains(&needle))
            .collect();
        out.sort_by(|a, b| a.type_name.cmp(&b.type_name));
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bundled_sde_loads_and_resolves_known_skills() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        assert!(sde.skill_count() > 400);
        assert_eq!(sde.skill_name(3300), "Gunnery");
        assert_eq!(sde.skill_name(3301), "Small Hybrid Turret");
        assert_eq!(sde.skill_group_name(3300).as_deref(), Some("Gunnery"));
        assert!(sde.contains(3300));
    }

    #[test]
    fn sde_miss_falls_back_to_unknown_skill() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        assert_eq!(sde.skill_name(999999), "Unknown Skill");
        assert_eq!(sde.skill_name_quiet(999999), "Unknown Skill");
        assert_eq!(sde.skill_group_name(999999), None);
    }

    #[test]
    fn group_listing_and_search_are_sorted() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let gunnery = sde.skills_in_group(255);
        assert!(gunnery.iter().any(|s| s.type_id == 3300));
        let names: Vec<&str> = gunnery.iter().map(|s| s.type_name.as_str()).collect();
        let mut sorted = names.clone();
        sorted.sort_unstable();
        assert_eq!(names, sorted);
        let found = sde.search_skills("hybrid turret");
        assert!(found.iter().any(|s| s.type_id == 3301));
    }

    #[test]
    fn rank_and_attributes_parse_from_extract() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let gunnery = sde.skill(3300).expect("gunnery present");
        assert_eq!(gunnery.rank, 1);
        assert_eq!(gunnery.primary_attribute, "perception");
        assert_eq!(gunnery.secondary_attribute, "willpower");
    }

    #[test]
    fn malformed_json_is_an_error_not_a_panic() {
        assert!(Sde::from_json("{not json").is_err());
    }

    // P1: prerequisites_parse_in_file_order (design section 12.1).
    #[test]
    fn prerequisites_parse_in_file_order() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let pairs = |skill_id: i64| -> Vec<(i64, i32)> {
            sde.skill(skill_id)
                .expect("skill present")
                .prerequisites
                .iter()
                .map(|p| (p.skill_id, p.level))
                .collect()
        };
        assert_eq!(pairs(3304), vec![(3300, 3), (3301, 3)]);
        assert_eq!(pairs(3301), vec![(3300, 1)]);
        assert_eq!(pairs(3344), vec![(20533, 5), (3336, 3), (3348, 5)]);
    }

    // P2: root_skills_empty_and_bundled_edges_resolve (design section 12.1).
    #[test]
    fn root_skills_empty_and_bundled_edges_resolve() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        assert!(sde
            .skill(3300)
            .expect("gunnery present")
            .prerequisites
            .is_empty());
        let total_edges: usize = sde.types.iter().map(|t| t.prerequisites.len()).sum();
        assert_eq!(total_edges, 749);
        let with_edges = sde
            .types
            .iter()
            .filter(|t| !t.prerequisites.is_empty())
            .count();
        assert_eq!(with_edges, 466);
        for t in &sde.types {
            for edge in &t.prerequisites {
                assert!(
                    (1..=5).contains(&edge.level),
                    "edge level {} out of 1..=5",
                    edge.level
                );
                assert!(
                    sde.contains(edge.skill_id),
                    "edge skill_id {}",
                    edge.skill_id
                );
            }
        }
    }

    // P3: prerequisites_default_on_partial_json (design section 12.1).
    #[test]
    fn prerequisites_default_on_partial_json() {
        let json = r#"{"categories":[],"groups":[],"types":[{"typeId":1,"typeName":"No Key"},{"typeId":2,"typeName":"Partial Skill Id","prerequisites":[{"skillId":3300}]},{"typeId":3,"typeName":"Partial Level","prerequisites":[{"level":2}]}]}"#;
        let sde = Sde::from_json(json).expect("partial SDE loads");
        assert!(sde
            .skill(1)
            .expect("type 1 present")
            .prerequisites
            .is_empty());
        assert_eq!(
            sde.skill(2).expect("type 2 present").prerequisites,
            vec![SdePrerequisite {
                skill_id: 3300,
                level: 0
            }]
        );
        assert_eq!(
            sde.skill(3).expect("type 3 present").prerequisites,
            vec![SdePrerequisite {
                skill_id: 0,
                level: 2
            }]
        );
    }
}
