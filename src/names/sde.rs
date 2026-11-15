//! Bundled SDE skill extract (`assets/sde/skills.json`): id to name/group.

use std::collections::HashMap;

use serde::Deserialize;

use crate::error::AppResult;

#[derive(Debug, Clone, Default, Deserialize)]
pub struct SdeGroup {
    #[serde(rename = "groupId", default)]
    pub group_id: i64,
    #[serde(rename = "groupName", default)]
    pub group_name: String,
    #[serde(rename = "categoryId", default)]
    pub category_id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct SdeSkillType {
    #[serde(rename = "typeId", default)]
    pub type_id: i64,
    #[serde(rename = "typeName", default)]
    pub type_name: String,
    #[serde(rename = "groupId", default)]
    pub group_id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
struct SdeFile {
    #[serde(default)]
    groups: Vec<SdeGroup>,
    #[serde(default)]
    types: Vec<SdeSkillType>,
}

/// In-memory SDE index for skill name/group lookups.
#[derive(Debug, Clone, Default)]
pub struct Sde {
    pub groups: Vec<SdeGroup>,
    pub types: Vec<SdeSkillType>,
    by_id: HashMap<i64, usize>,
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
        tracing::info!(
            "[SKILLS] SDE loaded skills={} groups={}",
            file.types.len(),
            file.groups.len()
        );
        Ok(Self {
            groups: file.groups,
            types: file.types,
            by_id,
        })
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

    pub fn skill_group_name(&self, skill_id: i64) -> Option<String> {
        let entry = self.types.get(*self.by_id.get(&skill_id)?)?;
        self.groups
            .iter()
            .find(|g| g.group_id == entry.group_id)
            .map(|g| g.group_name.clone())
    }
}
