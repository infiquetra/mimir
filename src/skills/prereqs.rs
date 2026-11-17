// Pure skill-prerequisite evaluation (design sections 3 and 5).
//
// Trained-only, direct-only: an edge `(p, r)` is unmet exactly when the
// clamped trained level of `p` is below `r`, with a missing trained
// row reading as 0. No target level, no recursion, no plan crediting.

use std::collections::BTreeMap;

use crate::names::sde::Sde;

use super::plans::SkillPlan;
use super::training::TrainedSkill;

/// One direct prerequisite the character has not
/// trained to the required level. Carries ids and
/// levels only: the interface resolves `skill_id`
/// to a display name, so a raw id never becomes
/// user-facing text inside this type.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct UnmetPrerequisite {
    pub skill_id: i64,
    pub required_level: i32,
    pub trained_level: i32, // clamped 0..=5; 0 = untrained
}

pub fn unmet_prerequisites(
    sde: &Sde,
    skill_id: i64,
    trained: &BTreeMap<i64, TrainedSkill>,
) -> Vec<UnmetPrerequisite> {
    let Some(skill) = sde.skill(skill_id) else {
        return Vec::new();
    };
    let mut out: Vec<UnmetPrerequisite> = Vec::new();
    for edge in &skill.prerequisites {
        let trained_level = trained
            .get(&edge.skill_id)
            .map(|t| t.trained_level.clamp(0, 5))
            .unwrap_or(0);
        if trained_level < edge.level {
            out.push(UnmetPrerequisite {
                skill_id: edge.skill_id,
                required_level: edge.level,
                trained_level,
            });
        }
    }
    out
}

pub fn plan_prerequisite_warnings(
    plan: &SkillPlan,
    sde: &Sde,
    trained: Option<&BTreeMap<i64, TrainedSkill>>,
) -> Vec<Vec<UnmetPrerequisite>> {
    let Some(map) = trained else {
        return vec![Vec::new(); plan.entries.len()];
    };
    plan.entries
        .iter()
        .map(|entry| unmet_prerequisites(sde, entry.skill_id, map))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::skills::plans::SkillPlanEntry;

    fn trained_map(entries: Vec<(i64, i32)>) -> BTreeMap<i64, TrainedSkill> {
        entries
            .into_iter()
            .map(|(skill_id, trained_level)| {
                (
                    skill_id,
                    TrainedSkill {
                        trained_level,
                        skillpoints_in_skill: 0,
                    },
                )
            })
            .collect()
    }

    fn plan_with(entries: Vec<SkillPlanEntry>) -> SkillPlan {
        SkillPlan {
            plan_id: 1,
            character_id: 90000001,
            name: "Test".to_string(),
            description: String::new(),
            created_at: "2026-11-15T00:00:00Z".to_string(),
            updated_at: "2026-11-15T00:00:00Z".to_string(),
            entries,
        }
    }

    fn entry(skill_id: i64, target_level: i32) -> SkillPlanEntry {
        SkillPlanEntry {
            skill_id,
            target_level,
        }
    }

    // E1: unmet_lists_both_edges_in_file_order (design section 12.2).
    #[test]
    fn unmet_lists_both_edges_in_file_order() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![(3300, 1)]);
        assert_eq!(
            unmet_prerequisites(&sde, 3304, &trained),
            vec![
                UnmetPrerequisite {
                    skill_id: 3300,
                    required_level: 3,
                    trained_level: 1
                },
                UnmetPrerequisite {
                    skill_id: 3301,
                    required_level: 3,
                    trained_level: 0
                },
            ]
        );
    }

    // E2: met_at_and_above_required_is_empty (design section 12.2).
    #[test]
    fn met_at_and_above_required_is_empty() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![(3300, 3), (3301, 3)]);
        assert_eq!(unmet_prerequisites(&sde, 3304, &trained), Vec::new());
        let trained = trained_map(vec![(3300, 5), (3301, 4)]);
        assert_eq!(unmet_prerequisites(&sde, 3304, &trained), Vec::new());
    }

    // E3: only_the_short_edge_is_reported (design section 12.2).
    #[test]
    fn only_the_short_edge_is_reported() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![(3300, 3), (3301, 2)]);
        assert_eq!(
            unmet_prerequisites(&sde, 3304, &trained),
            vec![UnmetPrerequisite {
                skill_id: 3301,
                required_level: 3,
                trained_level: 2
            }]
        );
    }

    // E4: direct_only_never_descends (design section 12.2).
    #[test]
    fn direct_only_never_descends() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![]);
        let unmet = unmet_prerequisites(&sde, 3344, &trained);
        assert_eq!(
            unmet,
            vec![
                UnmetPrerequisite {
                    skill_id: 20533,
                    required_level: 5,
                    trained_level: 0
                },
                UnmetPrerequisite {
                    skill_id: 3336,
                    required_level: 3,
                    trained_level: 0
                },
                UnmetPrerequisite {
                    skill_id: 3348,
                    required_level: 5,
                    trained_level: 0
                },
            ]
        );
        assert!(unmet.iter().all(|u| u.skill_id != 20342));
    }

    // E5: unknown_and_root_skills_have_no_warnings (design section 12.2).
    #[test]
    fn unknown_and_root_skills_have_no_warnings() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![]);
        assert_eq!(unmet_prerequisites(&sde, 999999, &trained), Vec::new());
        assert_eq!(unmet_prerequisites(&sde, 3300, &trained), Vec::new());
    }

    // E6: trained_level_clamps_and_sp_is_ignored (design section 12.2).
    #[test]
    fn trained_level_clamps_and_sp_is_ignored() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![(3300, 9)]);
        assert_eq!(unmet_prerequisites(&sde, 3301, &trained), Vec::new());
        let trained = trained_map(vec![(3300, -2)]);
        assert_eq!(
            unmet_prerequisites(&sde, 3301, &trained),
            vec![UnmetPrerequisite {
                skill_id: 3300,
                required_level: 1,
                trained_level: 0
            }]
        );
        let mut trained = BTreeMap::new();
        trained.insert(
            3300,
            TrainedSkill {
                trained_level: 0,
                skillpoints_in_skill: 999999,
            },
        );
        assert_eq!(
            unmet_prerequisites(&sde, 3301, &trained),
            vec![UnmetPrerequisite {
                skill_id: 3300,
                required_level: 1,
                trained_level: 0
            }]
        );
    }

    // E7b: earlier plan entries never count as trained (design
    // section 3 trained-only decision; reviewer Finding 1). The
    // prerequisite skill sits EARLIER in the plan at a target that
    // would satisfy the edge, so any plan-order crediting would
    // silence the warning and fail this test.
    #[test]
    fn earlier_plan_entries_never_count_as_trained() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        // Gunnery 3300 to 5 first, then Medium Hybrid Turret 3304
        // (requires Gunnery 3 and Small Hybrid Turret 3301 level 3).
        let plan = plan_with(vec![entry(3300, 5), entry(3304, 3)]);
        let trained = trained_map(vec![]);
        let warnings = plan_prerequisite_warnings(&plan, &sde, Some(&trained));
        assert_eq!(warnings.len(), 2);
        assert_eq!(warnings[0], Vec::new(), "Gunnery is a root skill");
        assert_eq!(
            warnings[1],
            vec![
                UnmetPrerequisite {
                    skill_id: 3300,
                    required_level: 3,
                    trained_level: 0
                },
                UnmetPrerequisite {
                    skill_id: 3301,
                    required_level: 3,
                    trained_level: 0
                },
            ],
            "the earlier Gunnery entry must not count as trained"
        );
    }

    // E7: plan_warnings_parallel_and_none_is_empty (design section 12.2).
    #[test]
    fn plan_warnings_parallel_and_none_is_empty() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let plan = plan_with(vec![entry(3304, 3), entry(3300, 5), entry(999999, 2)]);
        let trained = trained_map(vec![(3300, 1)]);
        assert_eq!(
            plan_prerequisite_warnings(&plan, &sde, Some(&trained)),
            vec![
                vec![
                    UnmetPrerequisite {
                        skill_id: 3300,
                        required_level: 3,
                        trained_level: 1
                    },
                    UnmetPrerequisite {
                        skill_id: 3301,
                        required_level: 3,
                        trained_level: 0
                    },
                ],
                Vec::new(),
                Vec::new(),
            ]
        );
        assert_eq!(
            plan_prerequisite_warnings(&plan, &sde, None),
            vec![Vec::new(), Vec::new(), Vec::new()]
        );
        let empty = plan_with(Vec::new());
        assert_eq!(
            plan_prerequisite_warnings(&empty, &sde, Some(&trained)),
            Vec::<Vec<UnmetPrerequisite>>::new()
        );
        assert_eq!(
            plan_prerequisite_warnings(&empty, &sde, None),
            Vec::<Vec<UnmetPrerequisite>>::new()
        );
    }

    // E8: target_level_does_not_change_warnings (design section 12.2).
    #[test]
    fn target_level_does_not_change_warnings() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let trained = trained_map(vec![(3300, 1)]);
        let expected = vec![vec![
            UnmetPrerequisite {
                skill_id: 3300,
                required_level: 3,
                trained_level: 1,
            },
            UnmetPrerequisite {
                skill_id: 3301,
                required_level: 3,
                trained_level: 0,
            },
        ]];
        let plan_target_1 = plan_with(vec![entry(3304, 1)]);
        let plan_target_5 = plan_with(vec![entry(3304, 5)]);
        assert_eq!(
            plan_prerequisite_warnings(&plan_target_1, &sde, Some(&trained)),
            expected
        );
        assert_eq!(
            plan_prerequisite_warnings(&plan_target_5, &sde, Some(&trained)),
            expected
        );
    }

    // E9: synthetic_bounds_unknown_and_cycles (design section 12.2).
    #[test]
    fn synthetic_bounds_unknown_and_cycles() {
        let json = r#"{"categories":[],"groups":[],"types":[{"typeId":1,"typeName":"Skill One","prerequisites":[{"skillId":2,"level":0},{"skillId":3,"level":6},{"skillId":999999,"level":2}]},{"typeId":2,"typeName":"Skill Two"},{"typeId":3,"typeName":"Skill Three"}]}"#;
        let sde = Sde::from_json(json).expect("synthetic SDE loads");
        let trained = trained_map(vec![(3, 5)]);
        assert_eq!(
            unmet_prerequisites(&sde, 1, &trained),
            vec![
                UnmetPrerequisite {
                    skill_id: 3,
                    required_level: 6,
                    trained_level: 5
                },
                UnmetPrerequisite {
                    skill_id: 999999,
                    required_level: 2,
                    trained_level: 0
                },
            ]
        );
        let trained = trained_map(vec![(3, 5), (999999, 2)]);
        assert_eq!(
            unmet_prerequisites(&sde, 1, &trained),
            vec![UnmetPrerequisite {
                skill_id: 3,
                required_level: 6,
                trained_level: 5
            }]
        );
        let json = r#"{"categories":[],"groups":[],"types":[{"typeId":1,"typeName":"Skill One","prerequisites":[{"skillId":2,"level":1}]},{"typeId":2,"typeName":"Skill Two","prerequisites":[{"skillId":1,"level":1},{"skillId":2,"level":2}]}]}"#;
        let sde = Sde::from_json(json).expect("cycle SDE loads");
        let trained = trained_map(vec![(2, 1)]);
        assert_eq!(
            unmet_prerequisites(&sde, 2, &trained),
            vec![
                UnmetPrerequisite {
                    skill_id: 1,
                    required_level: 1,
                    trained_level: 0
                },
                UnmetPrerequisite {
                    skill_id: 2,
                    required_level: 2,
                    trained_level: 1
                },
            ]
        );
    }
}
