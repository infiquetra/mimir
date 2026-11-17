// Pure skill-training estimates (design sections 3 and 6).
//
// Every constant here is quoted from an inspected in-repo body.
//
// SP per level: SDE dogma attribute 275 `skillTimeConstant`
// description, verbatim: *"This attribute is a multiplier to the
// number of skill points required to train. Skill points required
// to train a skill = 250 * skillTimeConstant * sqrt(32)^(skillLevel
// - 1)"* (committed archive `scripts/sde/eve-online-static-data-
// 3503375-jsonl.zip` into `dogmaAttributes.jsonl`), read as the
// **cumulative** SP total at which a level is reached. The rank-1
// totals (250 / 8000 / 45255 / 256000) match the demo fixtures in
// `assets/demo/skillqueue.json` (`skillpoints_in_skill` and queue
// `level_start_sp` / `level_end_sp` pairs). The retired Flutter
// formula `250 * rank * 2^(L-1)` summed (7750 for 0 to 5) is rejected:
// it understates rank-1 0 to 5 by a factor of 33 and reproduces no
// fixture total (design section 3.1).
//
// Training rate: `primary + secondary / 2` SP per minute, two
// independent witnesses: the retired Flutter calculator
// (`skill_training_calculator.dart`, *"Primary attribute +
// (Secondary attribute / 2)"*, `Duration(minutes:
// (SP / rate).ceil())`) and `CharacterAttributes.spPerHour`
// (`(primary + secondary / 2.0) * 60.0`). A plan total is the **sum
// of per-entry times**, each at its own skill's rate (the Flutter
// progress-provider shape), not a shared-rate total (section 3.2).
//
// Attribute names: the five lowercase strings in the bundled
// extract (`assets/sde/skills.json`, 495 types, every type carrying
// `rank`, `primaryAttribute` and `secondaryAttribute`) resolving
// through attribute ids 164-168 (`charisma`, `intelligence`,
// `memory`, `perception`, `willpower`).
//
// There are no guessed defaults anywhere: Flutter's 20/20 attribute
// default and rank-1 fallback are rejected (rank 1). Missing rank,
// attributes not loaded, and unknown attribute strings all degrade to
// `None` — never to a guessed number.

use std::collections::BTreeMap;

use crate::esi::models::CharacterAttributes;
use crate::names::sde::Sde;

use super::plans::SkillPlan;

/// One trained skill's loaded facts, for estimate inputs.
///
/// Mirrors the `Skill` model (`trained_skill_level` /
/// `skillpoints_in_skill`) reduced to the two fields section 6 reads.
/// `active_skill_level` is never read — the parity rule in fitting
/// resources.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TrainedSkill {
    pub trained_level: i32,
    pub skillpoints_in_skill: i64,
}

/// Cumulative SP at which `level` is reached for a skill of the given
/// rank: `round(250 × rank × sqrt(32)^(level-1))` for `level` in
/// `1..=5`, and `0` for `level = 0` (design section 6.1).
///
/// `rank <= 0` yields `None` (the extract uses `0` for "omitted";
/// there is no fallback rank). `level` clamps to `0..=5`. Arithmetic
/// is `f64`, **round once on the full product** — rounding a rank-1
/// base first and multiplying after gives different values at some
/// ranks (rank 5, level 4: round-once 226274 against 45255 × 5 =
/// 226275); the SDE text is one product, so one rounding.
pub fn cumulative_sp(rank: i64, level: i32) -> Option<i64> {
    if rank <= 0 {
        return None;
    }
    let level = level.clamp(0, 5);
    if level == 0 {
        return Some(0);
    }
    Some((250.0 * rank as f64 * 32f64.sqrt().powi(level - 1)).round() as i64)
}

/// SP remaining to reach `target_level` for one skill, crediting
/// partial progress (design section 6.2).
///
/// Effective current SP is `max(cumulative_sp(rank,
/// trained_level), skillpoints_in_skill)` when a trained row exists,
/// else `0` for an untrained skill. Using the loaded
/// `skillpoints_in_skill` credits partial progress into the next
/// level, which a level-only difference would overstate; the `max`
/// with the level threshold means a stale or inconsistent SP figure
/// can never move a character *backwards* below the level ESI already
/// reports complete. Remaining is
/// `max(0, cumulative_sp(rank, target) - effective)`. Completion is a
/// **level** fact, not an SP fact (Flutter parity): SP at or past the
/// target threshold with the level not yet reported trained yields
/// remaining `0` but is *not* complete — the progress count follows
/// levels, the SP figure follows SP, and neither impersonates the
/// other.
pub fn sp_remaining(rank: i64, trained: Option<TrainedSkill>, target_level: i32) -> Option<i64> {
    let target_cum = cumulative_sp(rank, target_level)?;
    let effective = match trained {
        Some(t) => {
            let trained_level = t.trained_level.clamp(0, 5);
            // rank > 0 here (cumulative_sp already succeeded), so this
            // is always Some; the `?` is the total-function shape.
            let threshold = cumulative_sp(rank, trained_level)?;
            threshold.max(t.skillpoints_in_skill)
        }
        None => 0,
    };
    Some((target_cum - effective).max(0))
}

/// One character attribute by its lowercase extract name (design
/// section 6.3). Matches exactly `"charisma"`, `"intelligence"`,
/// `"memory"`, `"perception"`, `"willpower"` — the full value set
/// verified in the extract — to the five `CharacterAttributes`
/// fields. Any other string (including case variants) yields `None`;
/// there is no fallback value.
pub fn attribute_value(attrs: &CharacterAttributes, attribute_name: &str) -> Option<i32> {
    match attribute_name {
        "charisma" => Some(attrs.charisma),
        "intelligence" => Some(attrs.intelligence),
        "memory" => Some(attrs.memory),
        "perception" => Some(attrs.perception),
        "willpower" => Some(attrs.willpower),
        _ => None,
    }
}

/// Minutes to train `sp_remaining` SP at a `primary`/`secondary`
/// attribute pair (design section 6.3). Rate is
/// `primary + secondary / 2` SP per minute; minutes are
/// `ceil(sp_remaining / rate)`. `sp_remaining <= 0` yields `Some(0)`;
/// rate `<= 0` yields `None` (a partially defaulted attributes
/// payload deserializes missing fields to `0`, and `0/0` must read
/// as unavailable, never as infinite or a panic).
pub fn training_minutes(sp_remaining: i64, primary: i32, secondary: i32) -> Option<i64> {
    if sp_remaining <= 0 {
        return Some(0);
    }
    let rate = primary as f64 + secondary as f64 / 2.0;
    if rate <= 0.0 {
        return None;
    }
    Some((sp_remaining as f64 / rate).ceil() as i64)
}

/// Estimate for one plan entry (design section 6.4). `trained_level`
/// is `None` when skills are not loaded at all. `sp_remaining` and
/// `minutes` are `None` whenever the inputs needed for them are
/// unavailable — a number that does not exist is never guessed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EntryEstimate {
    pub skill_id: i64,
    pub trained_level: Option<i32>,
    pub complete: bool,
    pub sp_remaining: Option<i64>,
    pub minutes: Option<i64>,
}

/// Aggregate progress for one plan (design section 6.4). Totals are
/// all-or-nothing (rank 1): `total_sp_remaining` is `Some` only when
/// every incomplete entry has `Some` SP, and likewise independently
/// for `total_minutes`. Complete entries contribute `0` and never
/// block a total. Percent complete is deliberately **not** returned —
/// the UI renders the bar fraction as
/// `complete_count / entries.len()` with the empty case worded
/// separately.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanProgress {
    pub entries: Vec<EntryEstimate>,
    pub complete_count: usize,
    pub total_sp_remaining: Option<i64>,
    pub total_minutes: Option<i64>,
}

/// Per-entry and total progress for one plan (design section 6.4).
///
/// * `trained = None` (skills bundle not `Ready`): every entry gets
///   `trained_level: None`, `complete: false`, SP/minutes `None`;
///   totals `None`. The plan still renders and edits.
/// * `trained = Some(map)`: a missing key means untrained (level `0`,
///   `0` SP).
/// * Unknown skill or rank `<= 0`: that entry's SP and minutes are
///   `None`; `trained_level`/`complete` still resolve (they need no
///   rank).
/// * `attributes = None`, an unrecognized attribute string, or a
///   non-positive rate: that entry's minutes are `None`; SP
///   remaining is unaffected.
/// * Empty plan: counts `0`, totals `Some(0)` (vacuously complete).
pub fn plan_progress(
    plan: &SkillPlan,
    sde: &Sde,
    trained: Option<&BTreeMap<i64, TrainedSkill>>,
    attributes: Option<&CharacterAttributes>,
) -> PlanProgress {
    let mut entries: Vec<EntryEstimate> = Vec::with_capacity(plan.entries.len());
    let mut complete_count: usize = 0;

    for entry in &plan.entries {
        let trained_level: Option<i32> = trained.map(|map| {
            map.get(&entry.skill_id)
                .map(|t| t.trained_level.clamp(0, 5))
                .unwrap_or(0)
        });
        let complete = match trained_level {
            None => false,
            Some(level) => level >= entry.target_level.clamp(0, 5),
        };
        if complete {
            complete_count = complete_count.saturating_add(1);
        }

        let sp: Option<i64> = match trained {
            None => None,
            Some(map) => match sde.skill(entry.skill_id) {
                None => None,
                Some(skill) => {
                    let trained_skill = map.get(&entry.skill_id).copied();
                    sp_remaining(skill.rank, trained_skill, entry.target_level)
                }
            },
        };

        let minutes: Option<i64> = match sp {
            None => None,
            Some(remaining) => match (attributes, sde.skill(entry.skill_id)) {
                (Some(attrs), Some(skill)) => {
                    let primary = attribute_value(attrs, &skill.primary_attribute);
                    let secondary = attribute_value(attrs, &skill.secondary_attribute);
                    match (primary, secondary) {
                        (Some(p), Some(s)) => training_minutes(remaining, p, s),
                        _ => None,
                    }
                }
                _ => None,
            },
        };

        entries.push(EntryEstimate {
            skill_id: entry.skill_id,
            trained_level,
            complete,
            sp_remaining: sp,
            minutes,
        });
    }

    if plan.entries.is_empty() {
        return PlanProgress {
            entries,
            complete_count: 0,
            total_sp_remaining: Some(0),
            total_minutes: Some(0),
        };
    }

    let total_sp_remaining = {
        let mut sum: i64 = 0;
        let mut all_some = true;
        for e in entries.iter().filter(|e| !e.complete) {
            match e.sp_remaining {
                Some(v) => sum = sum.saturating_add(v),
                None => {
                    all_some = false;
                    break;
                }
            }
        }
        if all_some {
            Some(sum)
        } else {
            None
        }
    };
    let total_minutes = {
        let mut sum: i64 = 0;
        let mut all_some = true;
        for e in entries.iter().filter(|e| !e.complete) {
            match e.minutes {
                Some(v) => sum = sum.saturating_add(v),
                None => {
                    all_some = false;
                    break;
                }
            }
        }
        if all_some {
            Some(sum)
        } else {
            None
        }
    };

    PlanProgress {
        entries,
        complete_count,
        total_sp_remaining,
        total_minutes,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::skills::plans::SkillPlanEntry;

    fn attrs(
        charisma: i32,
        intelligence: i32,
        memory: i32,
        perception: i32,
        willpower: i32,
    ) -> CharacterAttributes {
        CharacterAttributes {
            charisma,
            intelligence,
            memory,
            perception,
            willpower,
            ..Default::default()
        }
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

    // T1: cumulative_sp_matches_sde_formula_literals (design section 12).
    #[test]
    fn cumulative_sp_matches_sde_formula_literals() {
        // Rank 1. L0 = 0 by definition; L1 = 250 (250 × 1 × 1);
        // L2 = 1414 (250 × sqrt(32) = 250 × 5.656854249492381 =
        //   1414.21… → round → 1414); L3 = 8000 (250 × 32);
        // L4 = 45255 (250 × 181.01933598375618 = 45254.83… → 45255);
        // L5 = 256000 (250 × 1024). The four non-trivial values are
        // exactly the demo-fixture witnesses of section 0 source 3
        // (skillpoints_in_skill 8000 / 45255 / 256000 and queue
        // level_start_sp→level_end_sp pairs).
        assert_eq!(cumulative_sp(1, 0), Some(0));
        assert_eq!(cumulative_sp(1, 1), Some(250)); // 250 × 1 × 1
        assert_eq!(cumulative_sp(1, 2), Some(1414)); // 250 × 5.656854249492381 = 1414.21… → 1414
        assert_eq!(cumulative_sp(1, 3), Some(8000)); // 250 × 32
        assert_eq!(cumulative_sp(1, 4), Some(45255)); // 250 × 181.01933598375618 = 45254.83… → 45255
        assert_eq!(cumulative_sp(1, 5), Some(256000)); // 250 × 1024
    }

    // T2: cumulative_sp_scales_by_rank_rounding_once.
    #[test]
    fn cumulative_sp_scales_by_rank_rounding_once() {
        // Rank 5 L3 = 40000 (250 × 5 × 32 = 40000).
        assert_eq!(cumulative_sp(5, 3), Some(40000));
        // Rank 5 L5 = 1280000 (250 × 5 × 1024 = 1280000).
        assert_eq!(cumulative_sp(5, 5), Some(1280000));
        // Rank 5 L4 = 226274 (250 × 5 × 181.01933598375618 =
        //   226274.16… → 226274). Comment: rank-1 base × 5 would give
        //   45255 × 5 = 226275 — this assertion pins round-once
        //   (section 6.1): one rounding on the full product.
        assert_eq!(cumulative_sp(5, 4), Some(226274)); // 250 × 5 × 181.01933598375618 = 226274.16… → 226274; NOT 45255 × 5 = 226275
                                                       // Rank 16 L5 = 4096000 (250 × 16 × 1024 = 4096000).
        assert_eq!(cumulative_sp(16, 5), Some(4096000));
        // Rank 2 L4 = 90510 (500 × 181.019… = 90509.66… → 90510).
        assert_eq!(cumulative_sp(2, 4), Some(90510)); // 500 × 181.01933598375618 = 90509.66… → 90510
    }

    // T3: cumulative_sp_rejects_missing_rank_and_clamps_level.
    #[test]
    fn cumulative_sp_rejects_missing_rank_and_clamps_level() {
        assert_eq!(cumulative_sp(0, 3), None); // rank 0 = extract omitted
        assert_eq!(cumulative_sp(-1, 3), None);
        assert_eq!(cumulative_sp(0, 5), None);
        // Level clamps to 0..=5: level -3 behaves as 0; level 9 as 5.
        assert_eq!(cumulative_sp(1, -3), Some(0));
        assert_eq!(cumulative_sp(1, 9), Some(256000)); // rank 1 L5 = 250 × 1024
        assert_eq!(cumulative_sp(1, 6), Some(256000));
    }

    // T4: sp_remaining_credits_partial_progress.
    #[test]
    fn sp_remaining_credits_partial_progress() {
        // Rank 1 untrained → L1 = 250 (250 × 1 × 1 - 0).
        assert_eq!(sp_remaining(1, None, 1), Some(250));
        // Rank 1 trained 4 with 45255 SP → L5 = 210745
        //   (256000 - 45255 = 210745).
        assert_eq!(
            sp_remaining(
                1,
                Some(TrainedSkill {
                    trained_level: 4,
                    skillpoints_in_skill: 45255
                }),
                5
            ),
            Some(210745)
        );
        // Rank 1 trained 3 with 10000 SP → L4 = 35255
        //   (45255 - 10000 = 35255: the 2000 SP past the level-3
        //   threshold is credited).
        assert_eq!(
            sp_remaining(
                1,
                Some(TrainedSkill {
                    trained_level: 3,
                    skillpoints_in_skill: 10000
                }),
                4
            ),
            Some(35255)
        );
        // Trained 3 with a stale 100 SP → L4 = 37255
        //   (45255 - 8000 = 37255: the level threshold wins over the
        //   stale figure, section 6.2).
        assert_eq!(
            sp_remaining(
                1,
                Some(TrainedSkill {
                    trained_level: 3,
                    skillpoints_in_skill: 100
                }),
                4
            ),
            Some(37255)
        );
        // Trained 5 → L5 = 0.
        assert_eq!(
            sp_remaining(
                1,
                Some(TrainedSkill {
                    trained_level: 5,
                    skillpoints_in_skill: 256000
                }),
                5
            ),
            Some(0)
        );
        // Trained 4 → target 3 clamps to 0.
        assert_eq!(
            sp_remaining(
                1,
                Some(TrainedSkill {
                    trained_level: 4,
                    skillpoints_in_skill: 45255
                }),
                3
            ),
            Some(0)
        );
        // Rank 0 → None.
        assert_eq!(sp_remaining(0, None, 5), None);
        assert_eq!(
            sp_remaining(
                0,
                Some(TrainedSkill {
                    trained_level: 3,
                    skillpoints_in_skill: 8000
                }),
                5
            ),
            None
        );
    }

    // T5: training_minutes_ceilings_and_unavailable.
    #[test]
    fn training_minutes_ceilings_and_unavailable() {
        // 900 SP at 20/20 → 30 (rate 20 + 20/2 = 30; 900/30 = 30
        //   exactly — formula-shape witness shared with sources 4/5,
        //   comment notes 1800 SP/hour equivalence: 30 SP/min × 60).
        assert_eq!(training_minutes(900, 20, 20), Some(30));
        // 50 SP at 20/20 → 2 (50/30 = 1.66… → ceil 2).
        assert_eq!(training_minutes(50, 20, 20), Some(2));
        // 210745 SP at 25/20 → 6022 (rate 25 + 20/2 = 35;
        //   210745/35 = 6021.28… → 6022).
        assert_eq!(training_minutes(210745, 25, 20), Some(6022));
        // 210745 SP at 25/24 → 5696 (rate 25 + 24/2 = 37;
        //   210745/37 = 5695.81… → 5696 — demo character 90000001's
        //   perception/willpower, source 7).
        assert_eq!(training_minutes(210745, 25, 24), Some(5696));
        // 0 SP → Some(0).
        assert_eq!(training_minutes(0, 20, 20), Some(0));
        // Rate at 0/0 → None.
        assert_eq!(training_minutes(100, 0, 0), None);
        // Negative attribute pair → None (rate <= 0).
        assert_eq!(training_minutes(100, -5, -5), None);
        // Negative SP clamps through the Some(0) arm.
        assert_eq!(training_minutes(-50, 20, 20), Some(0));
    }

    // T6: attribute_value_maps_the_five_extract_names_only.
    #[test]
    fn attribute_value_maps_the_five_extract_names_only() {
        // Distinct sentinels per field so a swapped mapping fails.
        let attrs = attrs(11, 22, 33, 44, 55);
        assert_eq!(attribute_value(&attrs, "charisma"), Some(11));
        assert_eq!(attribute_value(&attrs, "intelligence"), Some(22));
        assert_eq!(attribute_value(&attrs, "memory"), Some(33));
        assert_eq!(attribute_value(&attrs, "perception"), Some(44));
        assert_eq!(attribute_value(&attrs, "willpower"), Some(55));
        assert_eq!(attribute_value(&attrs, "Perception"), None);
        assert_eq!(attribute_value(&attrs, ""), None);
        assert_eq!(attribute_value(&attrs, "luck"), None);
    }

    // T7: plan_progress_sums_per_entry_times.
    #[test]
    fn plan_progress_sums_per_entry_times() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        // Gunnery (3300, rank 1, perception/willpower) trained 4
        //   (45255 SP) → target 5. Small Hybrid Turret (3301, rank 1,
        //   perception/willpower — verified from the extract) trained
        //   level 3 with 7969 SP toward level 5: cumulative L5 =
        //   256000, effective = max(8000, 7969) = 8000, so remaining =
        //   248000? No — we deliberately synthesize a distinguishing
        //   remainder. Follow the design's first example literally:
        //   two 31-SP remainders at rate 30 give 2 + 2 = 4, not
        //   ceil(62/30) = 3. With attributes 20/20 (rate 30) and a
        //   remainder of 31 each, each entry is ceil(31/30) = 2.
        //   Build the 31 remainder as: rank-1 target L1 = 250, trained
        //   level 0 with 219 SP → 250 - 219 = 31.
        let mut trained: BTreeMap<i64, TrainedSkill> = BTreeMap::new();
        trained.insert(
            3300,
            TrainedSkill {
                trained_level: 4,
                skillpoints_in_skill: 45255,
            },
        );
        trained.insert(
            3301,
            TrainedSkill {
                trained_level: 0,
                skillpoints_in_skill: 219,
            },
        );

        // First plan: the Gunnery 4→5 case with demo attributes 25/24
        // (rate 37) — per-entry 5696 (210745/37 = 5695.81… → 5696).
        // Plus the 3301 entry at target L1: 250 - 219 = 31 SP → 1 min
        // at rate 37 (ceil(31/37) = 1). Total = 5696 + 1 = 5697.
        let attributes = attrs(20, 27, 21, 25, 24);
        let plan = plan_with(vec![
            SkillPlanEntry {
                skill_id: 3300,
                target_level: 5,
            },
            SkillPlanEntry {
                skill_id: 3301,
                target_level: 1,
            },
        ]);
        let progress = plan_progress(&plan, &sde, Some(&trained), Some(&attributes));
        assert_eq!(progress.entries.len(), 2);
        assert!(!progress.entries[0].complete);
        assert_eq!(progress.entries[0].sp_remaining, Some(210745)); // 256000 - 45255
        assert_eq!(progress.entries[0].minutes, Some(5696)); // ceil(210745/37) = ceil(5695.81…) = 5696
        assert_eq!(progress.entries[1].sp_remaining, Some(31)); // 250 - 219
        assert_eq!(progress.entries[1].minutes, Some(1)); // ceil(31/37) = 1
        assert_eq!(progress.total_sp_remaining, Some(210776)); // 210745 + 31 = 210776
        assert_eq!(progress.total_minutes, Some(5697)); // 5696 + 1 = 5697
        assert_eq!(progress.complete_count, 0);

        // Distinguishing plan: two 31-SP remainders at rate 30
        // (attributes 20/20): each ceil(31/30) = 2, total 2 + 2 = 4,
        // not ceil(62/30) = 3. If the total were computed as
        // sum-then-ceil it would be 3; ceil-then-sum gives 4.
        let attributes20 = attrs(20, 20, 20, 20, 20);
        let mut trained2: BTreeMap<i64, TrainedSkill> = BTreeMap::new();
        trained2.insert(
            3300,
            TrainedSkill {
                trained_level: 0,
                skillpoints_in_skill: 219,
            },
        );
        trained2.insert(
            3301,
            TrainedSkill {
                trained_level: 0,
                skillpoints_in_skill: 219,
            },
        );
        let plan2 = plan_with(vec![
            SkillPlanEntry {
                skill_id: 3300,
                target_level: 1,
            },
            SkillPlanEntry {
                skill_id: 3301,
                target_level: 1,
            },
        ]);
        let progress2 = plan_progress(&plan2, &sde, Some(&trained2), Some(&attributes20));
        assert_eq!(progress2.entries[0].sp_remaining, Some(31)); // 250 - 219
        assert_eq!(progress2.entries[0].minutes, Some(2)); // ceil(31/30) = 2
        assert_eq!(progress2.entries[1].sp_remaining, Some(31)); // 250 - 219
        assert_eq!(progress2.entries[1].minutes, Some(2)); // ceil(31/30) = 2
        assert_eq!(progress2.total_sp_remaining, Some(62)); // 31 + 31 = 62
        assert_eq!(progress2.total_minutes, Some(4)); // 2 + 2 = 4, NOT ceil(62/30) = 3

        // Sanity: sum-then-ceil would be 3, visible in the literal.
        assert_eq!((62f64 / 30.0).ceil() as i64, 3);
    }

    // T8: plan_progress_totals_are_all_or_nothing.
    #[test]
    fn plan_progress_totals_are_all_or_nothing() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let attributes = attrs(20, 27, 21, 25, 24);
        let mut trained: BTreeMap<i64, TrainedSkill> = BTreeMap::new();
        trained.insert(
            3300,
            TrainedSkill {
                trained_level: 4,
                skillpoints_in_skill: 45255,
            },
        );
        // Unknown skill 999999 (absent from the extract).
        trained.insert(
            999999,
            TrainedSkill {
                trained_level: 0,
                skillpoints_in_skill: 0,
            },
        );

        let plan = plan_with(vec![
            SkillPlanEntry {
                skill_id: 3300,
                target_level: 5,
            },
            SkillPlanEntry {
                skill_id: 999999,
                target_level: 5,
            },
        ]);
        let progress = plan_progress(&plan, &sde, Some(&trained), Some(&attributes));
        // The known entry keeps its own Some values.
        assert_eq!(progress.entries[0].sp_remaining, Some(210745)); // 256000 - 45255
        assert_eq!(progress.entries[0].minutes, Some(5696)); // ceil(210745/37)
                                                             // The unknown entry has no SP/minutes but its level still resolves.
        assert_eq!(progress.entries[1].sp_remaining, None);
        assert_eq!(progress.entries[1].minutes, None);
        assert_eq!(progress.entries[1].trained_level, Some(0));
        assert!(!progress.entries[1].complete);
        // Both totals are None (all-or-nothing).
        assert_eq!(progress.total_sp_remaining, None);
        assert_eq!(progress.total_minutes, None);

        // Making the unknown entry complete restores both totals:
        // complete entries contribute 0 and never block.
        let mut trained_complete: BTreeMap<i64, TrainedSkill> = BTreeMap::new();
        trained_complete.insert(
            3300,
            TrainedSkill {
                trained_level: 4,
                skillpoints_in_skill: 45255,
            },
        );
        trained_complete.insert(
            999999,
            TrainedSkill {
                trained_level: 5,
                skillpoints_in_skill: 999999,
            },
        );
        let progress_complete =
            plan_progress(&plan, &sde, Some(&trained_complete), Some(&attributes));
        assert!(progress_complete.entries[1].complete);
        assert_eq!(progress_complete.total_sp_remaining, Some(210745)); // 210745 + 0 complete
        assert_eq!(progress_complete.total_minutes, Some(5696)); // 5696 + 0 complete
        assert_eq!(progress_complete.complete_count, 1);
    }

    // T9: plan_progress_without_inputs_is_unavailable_not_zero.
    #[test]
    fn plan_progress_without_inputs_is_unavailable_not_zero() {
        let sde = Sde::load_bundled().expect("bundled SDE loads");
        let plan = plan_with(vec![
            SkillPlanEntry {
                skill_id: 3300,
                target_level: 5,
            },
            SkillPlanEntry {
                skill_id: 3301,
                target_level: 3,
            },
        ]);
        let attributes = attrs(20, 27, 21, 25, 24);

        // trained = None: all entries unavailable, totals None, count 0.
        let no_trained = plan_progress(&plan, &sde, None, Some(&attributes));
        assert_eq!(no_trained.complete_count, 0);
        assert_eq!(no_trained.entries.len(), 2);
        for entry in &no_trained.entries {
            assert_eq!(entry.trained_level, None);
            assert!(!entry.complete);
            assert_eq!(entry.sp_remaining, None);
            assert_eq!(entry.minutes, None);
        }
        assert_eq!(no_trained.total_sp_remaining, None);
        assert_eq!(no_trained.total_minutes, None);

        // attributes = None with trained present: SP present, minutes
        // None per entry and in total.
        let mut trained: BTreeMap<i64, TrainedSkill> = BTreeMap::new();
        trained.insert(
            3300,
            TrainedSkill {
                trained_level: 4,
                skillpoints_in_skill: 45255,
            },
        );
        trained.insert(
            3301,
            TrainedSkill {
                trained_level: 0,
                skillpoints_in_skill: 0,
            },
        );
        let no_attributes = plan_progress(&plan, &sde, Some(&trained), None);
        assert_eq!(no_attributes.entries[0].sp_remaining, Some(210745)); // 256000 - 45255
        assert_eq!(no_attributes.entries[0].minutes, None);
        // Second entry untrained → target 3 = 8000 - 0 = 8000 SP.
        assert_eq!(no_attributes.entries[1].sp_remaining, Some(8000));
        assert_eq!(no_attributes.entries[1].minutes, None);
        assert_eq!(no_attributes.total_sp_remaining, Some(218745)); // 210745 + 8000 = 218745
        assert_eq!(no_attributes.total_minutes, None);

        // Empty plan → counts 0, totals Some(0).
        let empty = SkillPlan {
            entries: Vec::new(),
            ..plan_with(vec![])
        };
        let empty_progress = plan_progress(&empty, &sde, Some(&trained), Some(&attributes));
        assert_eq!(empty_progress.complete_count, 0);
        assert_eq!(empty_progress.entries.len(), 0);
        assert_eq!(empty_progress.total_sp_remaining, Some(0));
        assert_eq!(empty_progress.total_minutes, Some(0));

        // Empty plan is vacuously complete even without inputs.
        let empty_no_inputs = plan_progress(&empty, &sde, None, None);
        assert_eq!(empty_no_inputs.total_sp_remaining, Some(0));
        assert_eq!(empty_no_inputs.total_minutes, Some(0));
        assert_eq!(empty_no_inputs.complete_count, 0);
    }
}
