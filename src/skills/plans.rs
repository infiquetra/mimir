//! Skill plan model and validation (design section 4).
//!
//! A `SkillPlan` is a named list of `SkillPlanEntry`s owned by one
//! character forever (`I6`). The vector index *is* the sort position
//! (`I3`) — there is no stored ordering field in memory. Invariants
//! `I1`–`I5` are enforced by [`validate_plan`] (plus the schema
//! `UNIQUE` index and the picker); invalid data never reaches SQLite
//! and never renders as valid.
//!
//! [`SkillPlanAction`] lives here (section 13 decision): it is part of
//! the pure mutation vocabulary the demo applier consumes, so state
//! depends on skills and never the reverse.

/// One entry in a skill plan: a skill and the level the user wants.
///
/// `target_level` is always `1..=5` after validation (invariant `I2`,
/// design section 4). It is stored as a plain `i32` so the type stays
/// `Default`-constructible; the invariant lives in [`validate_plan`],
/// not in the type.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SkillPlanEntry {
    pub skill_id: i64,
    pub target_level: i32,
}

/// A named skill plan owned by exactly one character forever (`I6`).
///
/// `plan_id` is storage-assigned (live) or session-assigned (demo).
/// `entries` order is display order: `entries[i]` is position `i`
/// (`I3`). `description` is `""` for none — there is no `Option` in
/// state. Timestamps are caller-supplied RFC 3339 text; there is
/// deliberately no `Option` and no empty-means-unknown contract here,
/// the empty string only ever appears transiently in a draft action.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct SkillPlan {
    pub plan_id: i64,
    pub character_id: i64,
    pub name: String,
    pub description: String,
    pub created_at: String,
    pub updated_at: String,
    pub entries: Vec<SkillPlanEntry>,
}

/// Validation failure for one plan, without any user text in the kind
/// (design section 10 logging rule: only the `reason=` token is logged
/// for a rejection, never the offending name or description).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlanValidationError {
    /// Invariant `I1`: the same `skill_id` appears twice in `entries`.
    DuplicateSkill,
    /// Invariant `I2`: a `target_level` outside `1..=5`.
    BadTarget,
    /// Invariant `I4`: name or description outside its limits. Carries
    /// the exact editor string from section 8.3.
    BadText(&'static str),
}

impl std::fmt::Display for PlanValidationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DuplicateSkill => write!(f, "duplicate skill in plan entries"),
            Self::BadTarget => write!(f, "target level must be between 1 and 5"),
            Self::BadText(msg) => write!(f, "{msg}"),
        }
    }
}

impl std::error::Error for PlanValidationError {}

/// Trim and validate a plan name and description (invariant `I4`).
///
/// Returns the normalized `(name, description)` on success, or the exact
/// editor error string from design section 8.3 on failure, shared by
/// the editor (live validity) and the action applier (defense in depth
/// at rank 2). Character counts are Unicode scalar counts
/// (`.chars().count()`), following the fittings name rule's unit
/// (design section 4).
pub fn normalize_plan_text(
    name: &str,
    description: &str,
) -> Result<(String, String), &'static str> {
    let name = name.trim();
    let description = description.trim();
    if name.is_empty() {
        return Err("Plan name is required");
    }
    if name.chars().count() > 100 {
        return Err("Plan name must be 100 characters or less");
    }
    if description.chars().count() > 500 {
        return Err("Description must be 500 characters or less");
    }
    Ok((name.to_string(), description.to_string()))
}

/// Validate every invariant of one plan (`I1`, `I2`, `I4`).
///
/// `I3` (order is the vector) and `I5`/`I6` are unrepresentable as
/// failures in memory: unknown skills are legal here and `character_id`
/// is never mutated by any action. What this function rejects is exactly
/// what the schema `UNIQUE` index plus storage writes cannot defend on
/// their own — duplicates and out-of-range targets plus bad text —
/// so every write path (storage repository and demo applier) calls it
/// before mutating anything.
pub fn validate_plan(plan: &SkillPlan) -> Result<(), PlanValidationError> {
    // Text first: it is the cheapest rejection and carries the exact
    // editor strings the UI renders (design section 8.3).
    if let Err(msg) = normalize_plan_text(&plan.name, &plan.description) {
        tracing::debug!("[PLANS] plan rejected reason=bad_text");
        return Err(PlanValidationError::BadText(msg));
    }
    // I1: one entry per skill per plan.
    let mut seen = std::collections::BTreeSet::new();
    for entry in &plan.entries {
        if !seen.insert(entry.skill_id) {
            tracing::debug!("[PLANS] plan rejected reason=duplicate_skill");
            return Err(PlanValidationError::DuplicateSkill);
        }
    }
    // I2: target level in 1..=5.
    for entry in &plan.entries {
        if !(1..=5).contains(&entry.target_level) {
            tracing::debug!("[PLANS] plan rejected reason=bad_target");
            return Err(PlanValidationError::BadTarget);
        }
    }
    Ok(())
}

/// The single queued mutation for a plan list (design section 7).
///
/// Storage replaces the whole entries vector in one transaction
/// regardless, so the channel matches the write shape exactly: add,
/// remove and reorder are all `ReplaceEntries` with the full new
/// vector. Every variant carries its `character_id`; an action stamped
/// for a character who is no longer active is dropped whole by the
/// shell.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SkillPlanAction {
    Create {
        character_id: i64,
        name: String,
        description: String,
    },
    UpdateText {
        character_id: i64,
        plan_id: i64,
        name: String,
        description: String,
    },
    DeletePlan {
        character_id: i64,
        plan_id: i64,
    },
    ReplaceEntries {
        character_id: i64,
        plan_id: i64,
        entries: Vec<SkillPlanEntry>,
    },
}

/// Outcome of [`apply_demo_action`]: the same vocabulary storage
/// reports (created id / applied / not-found / invalid), so the shell
/// sets the same status strings in both modes (design section 9).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DemoApplyOutcome {
    /// `Create` succeeded; carries the allocated plan id.
    Created(i64),
    /// `UpdateText`, `ReplaceEntries` or `DeletePlan` succeeded.
    Applied,
    /// No plan with that id for that character.
    NotFound,
    /// Normalize/validate failed; nothing was mutated. Carries the
    /// editor string for text failures.
    Invalid(&'static str),
}

/// Apply one queued action to an in-memory demo plan list.
///
/// Takes **no connection** — demo persistence is impossible by
/// signature, not by discipline (design section 9, rank 3). Runs the
/// same `normalize_plan_text` / [`validate_plan`] checks storage runs,
/// stamps `created_at` / `updated_at` from `now`, allocates ids from
/// the session counter (start at 1), and keeps list order
/// most-recently-updated-first to match the live ordering
/// (`updated_at DESC, plan_id DESC`). On `Invalid` or `NotFound`
/// nothing is mutated and the counter is untouched.
pub fn apply_demo_action(
    plans: &mut Vec<SkillPlan>,
    next_plan_id: &mut i64,
    action: &SkillPlanAction,
    now: &str,
) -> DemoApplyOutcome {
    tracing::debug!(
        "[PLANS] apply_demo_action plans={} action={}",
        plans.len(),
        match action {
            SkillPlanAction::Create { .. } => "create",
            SkillPlanAction::UpdateText { .. } => "update_text",
            SkillPlanAction::DeletePlan { .. } => "delete_plan",
            SkillPlanAction::ReplaceEntries { .. } => "replace_entries",
        }
    );
    match action {
        SkillPlanAction::Create {
            character_id,
            name,
            description,
        } => {
            let (name, description) = match normalize_plan_text(name, description) {
                Ok(pair) => pair,
                Err(msg) => return DemoApplyOutcome::Invalid(msg),
            };
            let plan = SkillPlan {
                plan_id: *next_plan_id,
                character_id: *character_id,
                name,
                description,
                created_at: now.to_string(),
                updated_at: now.to_string(),
                entries: Vec::new(),
            };
            if let Err(err) = validate_plan(&plan) {
                return DemoApplyOutcome::Invalid(err_message(&err));
            }
            *next_plan_id += 1;
            let plan_id = plan.plan_id;
            plans.push(plan);
            sort_most_recent_first(plans);
            DemoApplyOutcome::Created(plan_id)
        }
        SkillPlanAction::UpdateText {
            character_id,
            plan_id,
            name,
            description,
        } => {
            let (name, description) = match normalize_plan_text(name, description) {
                Ok(pair) => pair,
                Err(msg) => return DemoApplyOutcome::Invalid(msg),
            };
            let Some(index) = plans
                .iter()
                .position(|p| p.plan_id == *plan_id && p.character_id == *character_id)
            else {
                return DemoApplyOutcome::NotFound;
            };
            let mut candidate = plans[index].clone();
            candidate.name = name;
            candidate.description = description;
            candidate.updated_at = now.to_string();
            if let Err(err) = validate_plan(&candidate) {
                return DemoApplyOutcome::Invalid(err_message(&err));
            }
            plans[index] = candidate;
            sort_most_recent_first(plans);
            DemoApplyOutcome::Applied
        }
        SkillPlanAction::DeletePlan {
            character_id,
            plan_id,
        } => {
            let Some(index) = plans
                .iter()
                .position(|p| p.plan_id == *plan_id && p.character_id == *character_id)
            else {
                return DemoApplyOutcome::NotFound;
            };
            plans.remove(index);
            DemoApplyOutcome::Applied
        }
        SkillPlanAction::ReplaceEntries {
            character_id,
            plan_id,
            entries,
        } => {
            let Some(index) = plans
                .iter()
                .position(|p| p.plan_id == *plan_id && p.character_id == *character_id)
            else {
                return DemoApplyOutcome::NotFound;
            };
            let mut candidate = plans[index].clone();
            candidate.entries = entries.clone();
            candidate.updated_at = now.to_string();
            if let Err(err) = validate_plan(&candidate) {
                return DemoApplyOutcome::Invalid(err_message(&err));
            }
            plans[index] = candidate;
            sort_most_recent_first(plans);
            DemoApplyOutcome::Applied
        }
    }
}

/// Most-recently-updated-first, matching `list_skill_plans` storage
/// order (`updated_at DESC, plan_id DESC` — design section 5.3).
fn sort_most_recent_first(plans: &mut [SkillPlan]) {
    plans.sort_by(|a, b| {
        b.updated_at
            .cmp(&a.updated_at)
            .then_with(|| b.plan_id.cmp(&a.plan_id))
    });
}

/// The `&'static str` a `DemoApplyOutcome::Invalid` carries.
fn err_message(err: &PlanValidationError) -> &'static str {
    match err {
        PlanValidationError::DuplicateSkill => "duplicate skill in plan",
        PlanValidationError::BadTarget => "target level must be between 1 and 5",
        PlanValidationError::BadText(msg) => msg,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // T10: plan_validation_enforces_invariants (design section 12).
    #[test]
    fn plan_validation_enforces_invariants() {
        let base = SkillPlan {
            plan_id: 1,
            character_id: 90000001,
            name: "PvP".to_string(),
            description: String::new(),
            created_at: "2026-11-15T00:00:00Z".to_string(),
            updated_at: "2026-11-15T00:00:00Z".to_string(),
            entries: vec![
                SkillPlanEntry {
                    skill_id: 3300,
                    target_level: 5,
                },
                SkillPlanEntry {
                    skill_id: 3301,
                    target_level: 3,
                },
            ],
        };
        assert!(validate_plan(&base).is_ok());

        // Duplicate skill rejected.
        let mut dup = base.clone();
        dup.entries = vec![
            SkillPlanEntry {
                skill_id: 3300,
                target_level: 5,
            },
            SkillPlanEntry {
                skill_id: 3300,
                target_level: 3,
            },
        ];
        assert_eq!(
            validate_plan(&dup),
            Err(PlanValidationError::DuplicateSkill)
        );

        // Target 0 and target 6 rejected.
        for bad_target in [0, 6] {
            let mut plan = base.clone();
            plan.entries = vec![SkillPlanEntry {
                skill_id: 3300,
                target_level: bad_target,
            }];
            assert_eq!(
                validate_plan(&plan),
                Err(PlanValidationError::BadTarget),
                "target {bad_target}"
            );
        }

        // Empty and whitespace-only names give the exact string.
        for empty_name in ["", "   ", "\t\n "] {
            let mut plan = base.clone();
            plan.name = empty_name.to_string();
            assert_eq!(
                validate_plan(&plan),
                Err(PlanValidationError::BadText("Plan name is required")),
                "name {empty_name:?}"
            );
        }

        // 101-char name and 501-char description give their exact strings.
        // "a".repeat(101) has 101 scalars; 100 is the inclusive bound.
        let long_name = "a".repeat(101);
        // normalize_plan_text is the single source: validate_plan must
        // carry its message through unchanged.
        assert_eq!(
            normalize_plan_text(&long_name, ""),
            Err("Plan name must be 100 characters or less")
        );
        let long_description = "a".repeat(501);
        assert_eq!(
            normalize_plan_text("PvP", &long_description),
            Err("Description must be 500 characters or less")
        );
        let mut plan_long_name = base.clone();
        plan_long_name.name = long_name;
        assert_eq!(
            validate_plan(&plan_long_name),
            Err(PlanValidationError::BadText(
                "Plan name must be 100 characters or less"
            ))
        );
        let mut plan_long_desc = base.clone();
        plan_long_desc.description = long_description;
        assert_eq!(
            validate_plan(&plan_long_desc),
            Err(PlanValidationError::BadText(
                "Description must be 500 characters or less"
            ))
        );

        // Trimming normalizes: "  PvP  " is accepted and stored as "PvP".
        let (name, description) =
            normalize_plan_text("  PvP  ", "  focused  ").expect("trimmed text normalizes");
        assert_eq!(name, "PvP");
        assert_eq!(description, "focused");

        // Boundary inclusive: 100-char name and 500-char description.
        let name_100 = "a".repeat(100);
        let desc_500 = "a".repeat(500);
        let (name, description) =
            normalize_plan_text(&name_100, &desc_500).expect("boundary lengths accepted");
        assert_eq!(name.chars().count(), 100);
        assert_eq!(description.chars().count(), 500);
        let mut boundary = base.clone();
        boundary.name = name_100;
        boundary.description = desc_500;
        assert!(validate_plan(&boundary).is_ok());

        // Unicode scalar counts, not bytes: 100 accented chars accepted.
        let name_unicode = "é".repeat(100);
        assert!(normalize_plan_text(&name_unicode, "").is_ok());
        let name_unicode_101 = "é".repeat(101);
        assert_eq!(
            normalize_plan_text(&name_unicode_101, ""),
            Err("Plan name must be 100 characters or less")
        );
    }

    // T19: demo_action_applier_mutates_memory_only (design section 12).
    // Taking no connection is the type-level proof; this pins the semantics.
    #[test]
    fn demo_action_applier_mutates_memory_only() {
        let mut plans: Vec<SkillPlan> = Vec::new();
        let mut next_plan_id: i64 = 1;

        // Create allocates ids 1, 2, ... and stamps both timestamps.
        let now1 = "2026-11-15T00:00:00Z";
        let first = SkillPlanAction::Create {
            character_id: 90000001,
            name: "  PvP  ".to_string(),
            description: "warm-up".to_string(),
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &first, now1),
            DemoApplyOutcome::Created(1)
        );
        assert_eq!(plans.len(), 1);
        assert_eq!(plans[0].plan_id, 1);
        assert_eq!(plans[0].name, "PvP"); // normalized
        assert_eq!(plans[0].created_at, now1);
        assert_eq!(plans[0].updated_at, now1);
        assert_eq!(next_plan_id, 2);

        let now2 = "2026-11-15T01:00:00Z";
        let second = SkillPlanAction::Create {
            character_id: 90000001,
            name: "PvE".to_string(),
            description: String::new(),
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &second, now2),
            DemoApplyOutcome::Created(2)
        );
        assert_eq!(plans.len(), 2);
        assert_eq!(next_plan_id, 3);
        // Most-recently-updated-first: the newer plan is on top.
        assert_eq!(plans[0].plan_id, 2);
        assert_eq!(plans[1].plan_id, 1);

        // Rename via UpdateText, stamped with the new `now`.
        let now3 = "2026-11-15T02:00:00Z";
        let rename = SkillPlanAction::UpdateText {
            character_id: 90000001,
            plan_id: 1,
            name: "PvP Elite".to_string(),
            description: "warm-up".to_string(),
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &rename, now3),
            DemoApplyOutcome::Applied
        );
        assert_eq!(plans[0].plan_id, 1); // now most recent
        assert_eq!(plans[0].name, "PvP Elite");
        assert_eq!(plans[0].updated_at, now3);

        // Replace entries add/remove/reorder in one call.
        let now4 = "2026-11-15T03:00:00Z";
        let replace = SkillPlanAction::ReplaceEntries {
            character_id: 90000001,
            plan_id: 1,
            entries: vec![
                SkillPlanEntry {
                    skill_id: 3300,
                    target_level: 5,
                },
                SkillPlanEntry {
                    skill_id: 3301,
                    target_level: 3,
                },
            ],
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &replace, now4),
            DemoApplyOutcome::Applied
        );
        let plan = plans.iter().find(|p| p.plan_id == 1).expect("plan 1");
        assert_eq!(
            plan.entries,
            vec![
                SkillPlanEntry {
                    skill_id: 3300,
                    target_level: 5,
                },
                SkillPlanEntry {
                    skill_id: 3301,
                    target_level: 3,
                },
            ]
        );
        assert_eq!(plan.updated_at, now4);

        // Delete removes exactly that plan.
        let delete = SkillPlanAction::DeletePlan {
            character_id: 90000001,
            plan_id: 2,
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &delete, now4),
            DemoApplyOutcome::Applied
        );
        assert_eq!(plans.len(), 1);
        assert_eq!(plans[0].plan_id, 1);

        // Not-found reports and mutates nothing.
        let missing = SkillPlanAction::DeletePlan {
            character_id: 90000001,
            plan_id: 999,
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &missing, now4),
            DemoApplyOutcome::NotFound
        );
        assert_eq!(plans.len(), 1);

        // Invalid input reports invalid and mutates nothing, including
        // the counter and the stored text.
        let before = plans.clone();
        let invalid_create = SkillPlanAction::Create {
            character_id: 90000001,
            name: "   ".to_string(),
            description: String::new(),
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &invalid_create, now4),
            DemoApplyOutcome::Invalid("Plan name is required")
        );
        assert_eq!(plans, before);
        assert_eq!(next_plan_id, 3);

        let invalid_replace = SkillPlanAction::ReplaceEntries {
            character_id: 90000001,
            plan_id: 1,
            entries: vec![
                SkillPlanEntry {
                    skill_id: 3300,
                    target_level: 5,
                },
                SkillPlanEntry {
                    skill_id: 3300,
                    target_level: 3,
                },
            ],
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &invalid_replace, now4),
            DemoApplyOutcome::Invalid("duplicate skill in plan")
        );
        assert_eq!(plans, before);
        assert_eq!(next_plan_id, 3);

        // The counter never runs backwards; the next create gets 4.
        let next = SkillPlanAction::Create {
            character_id: 90000001,
            name: "Fleet".to_string(),
            description: String::new(),
        };
        assert_eq!(
            apply_demo_action(&mut plans, &mut next_plan_id, &next, now4),
            DemoApplyOutcome::Created(3)
        );
        assert_eq!(next_plan_id, 4);
    }
}
