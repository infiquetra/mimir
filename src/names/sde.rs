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
        tracing::info!(
            "[SKILLS] SDE loaded skills={} groups={} categories={}",
            file.types.len(),
            file.groups.len(),
            file.categories.len()
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

    /// Skill display name; SDE misses fall back to `Skill #<id>` (the only
    /// raw-ID-shaped string the interface may show, matching Flutter).
    pub fn skill_name(&self, skill_id: i64) -> String {
        match self.by_id.get(&skill_id) {
            Some(&i) => self.types[i].type_name.clone(),
            None => {
                tracing::warn!("[SKILLS] SDE miss skill_id={}", skill_id);
                format!("Skill #{skill_id}")
            }
        }
    }

    /// Like [`Self::skill_name`] but silent on a miss: for per-frame
    /// rendering of many rows, where a warning per frame would flood logs.
    pub fn skill_name_quiet(&self, skill_id: i64) -> String {
        match self.skill(skill_id) {
            Some(entry) => entry.type_name.clone(),
            None => format!("Skill #{skill_id}"),
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
    fn sde_miss_falls_back_to_skill_number() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        assert_eq!(sde.skill_name(999999), "Skill #999999");
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
}
