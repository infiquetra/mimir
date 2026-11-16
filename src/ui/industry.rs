//! Industry: the active character's industry jobs and blueprint
//! library, read-only. The view sets request flags only
//! (`retry_requested`, `stepup_requested`); it never fetches.
//! Every rendered string is a resolved EVE name, a section-7 word,
//! a fetched date, or a row count — never a raw numeric ID, and
//! blueprint sentinel values render as words.

use chrono::Utc;

use super::widgets;
use crate::app::state::{
    AppState, BlueprintKindFilter, BlueprintsData, IndustryData, IndustryJobsData, LoadState,
    SectionError, StepUpRequest,
};
use crate::config::EveConfig;
use crate::esi::models::{CharacterBlueprint, IndustryJob};
use crate::names::resolver::NameResolver;

pub fn activity_label(activity_id: i64) -> &'static str {
    match activity_id {
        1 => "Manufacturing",
        3 => "Time efficiency research",
        4 => "Material efficiency research",
        5 => "Copying",
        8 => "Invention",
        11 => "Reaction",
        _ => "Unknown activity",
    }
}

pub fn status_label(status: &str) -> &'static str {
    match status {
        "active" => "Active",
        "paused" => "Paused",
        "ready" => "Ready",
        "delivered" => "Delivered",
        "cancelled" => "Cancelled",
        "reverted" => "Reverted",
        _ => "Unknown status",
    }
}

pub fn is_in_progress_status(status: &str) -> bool {
    matches!(status, "active" | "paused" | "ready")
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct IndustryJobRow {
    pub job_id: i64,
    pub display_type_id: i64,
    pub type_name: String,
    pub activity_label: &'static str,
    pub status_label: &'static str,
    pub in_progress: bool,
    pub runs: i64,
    pub successful_runs: Option<i64>,
    pub facility_name: String,
    pub start_date: String,
    pub end_date: String,
}

fn job_rank(in_progress: bool) -> u8 {
    if in_progress {
        0
    } else {
        1
    }
}

pub fn industry_job_rows(jobs: &[IndustryJob], resolver: &NameResolver) -> Vec<IndustryJobRow> {
    let mut rows: Vec<IndustryJobRow> = jobs
        .iter()
        .map(|job| {
            let display_type_id = match job.product_type_id {
                Some(id) if id > 0 => id,
                _ => job.blueprint_type_id,
            };
            IndustryJobRow {
                job_id: job.job_id,
                display_type_id,
                type_name: resolver.name(display_type_id),
                activity_label: activity_label(job.activity_id),
                status_label: status_label(&job.status),
                in_progress: is_in_progress_status(&job.status),
                runs: job.runs.max(0),
                successful_runs: job.successful_runs.map(|v| v.max(0)),
                facility_name: resolver.location_name(job.facility_id),
                start_date: job.start_date.clone(),
                end_date: job.end_date.clone(),
            }
        })
        .collect();
    rows.sort_by(|a, b| {
        job_rank(a.in_progress)
            .cmp(&job_rank(b.in_progress))
            .then_with(|| a.end_date.is_empty().cmp(&b.end_date.is_empty()))
            .then_with(|| a.end_date.cmp(&b.end_date))
            .then_with(|| a.start_date.cmp(&b.start_date))
            .then(a.job_id.cmp(&b.job_id))
    });
    let counts = job_counts(&rows);
    tracing::debug!(
        "[INDUSTRY] job rows total={} in_progress={}",
        counts.total,
        counts.in_progress
    );
    rows
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct JobCounts {
    pub total: usize,
    pub in_progress: usize,
}

pub fn job_counts(rows: &[IndustryJobRow]) -> JobCounts {
    rows.iter()
        .fold(JobCounts::default(), |acc, row| JobCounts {
            total: acc.total.saturating_add(1),
            in_progress: if row.in_progress {
                acc.in_progress.saturating_add(1)
            } else {
                acc.in_progress
            },
        })
}

pub fn blueprint_is_original(blueprint: &CharacterBlueprint) -> bool {
    blueprint.runs == -1
}

pub fn blueprint_kind_label(blueprint: &CharacterBlueprint) -> &'static str {
    if blueprint_is_original(blueprint) {
        "Original (BPO)"
    } else {
        "Copy (BPC)"
    }
}

pub fn blueprint_quantity_label(quantity: i64) -> String {
    match quantity {
        -1 => "Original".to_string(),
        -2 => "Copy".to_string(),
        q if q < 0 => "Unknown quantity".to_string(),
        q => q.to_string(),
    }
}

pub fn blueprint_runs_label(runs: i64) -> String {
    match runs {
        -1 => "Infinite runs (original)".to_string(),
        r if r < 0 => "Unknown runs".to_string(),
        r => format!("{r} runs"),
    }
}

pub fn efficiency_label(kind: &str, value: i64) -> String {
    format!("{} {}", kind, value.max(0))
}

pub const BLUEPRINT_RENDER_MAX: usize = 100;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct BlueprintRow {
    pub item_id: i64,
    pub type_id: i64,
    pub type_name: String,
    pub kind_label: &'static str,
    pub is_original: bool,
    pub quantity_label: String,
    pub runs_label: String,
    pub material_efficiency: i64,
    pub time_efficiency: i64,
    pub location_name: String,
}

pub fn blueprint_rows(
    blueprints: &[CharacterBlueprint],
    resolver: &NameResolver,
) -> Vec<BlueprintRow> {
    let mut rows: Vec<BlueprintRow> = blueprints
        .iter()
        .map(|bp| BlueprintRow {
            item_id: bp.item_id,
            type_id: bp.type_id,
            type_name: resolver.name(bp.type_id),
            kind_label: blueprint_kind_label(bp),
            is_original: blueprint_is_original(bp),
            quantity_label: blueprint_quantity_label(bp.quantity),
            runs_label: blueprint_runs_label(bp.runs),
            material_efficiency: bp.material_efficiency,
            time_efficiency: bp.time_efficiency,
            location_name: resolver.location_name(bp.location_id),
        })
        .collect();
    rows.sort_by(|a, b| {
        a.type_name
            .to_lowercase()
            .cmp(&b.type_name.to_lowercase())
            .then_with(|| a.type_name.cmp(&b.type_name))
            .then_with(|| {
                a.location_name
                    .to_lowercase()
                    .cmp(&b.location_name.to_lowercase())
            })
            .then(a.item_id.cmp(&b.item_id))
    });
    tracing::debug!("[INDUSTRY] blueprint rows={}", rows.len());
    rows
}

pub fn filter_blueprint_rows<'a>(
    rows: &'a [BlueprintRow],
    query: &str,
    kind: BlueprintKindFilter,
) -> Vec<&'a BlueprintRow> {
    let kept: Vec<&BlueprintRow> = rows
        .iter()
        .filter(|row| match kind {
            BlueprintKindFilter::All => true,
            BlueprintKindFilter::Originals => row.is_original,
            BlueprintKindFilter::Copies => !row.is_original,
        })
        .filter(|row| {
            widgets::matches_search(&row.type_name, query)
                || widgets::matches_search(&row.location_name, query)
        })
        .collect();
    tracing::debug!(
        "[INDUSTRY] blueprint filter kept={} total={}",
        kept.len(),
        rows.len()
    );
    kept
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct BlueprintCounts {
    pub total: usize,
    pub originals: usize,
    pub copies: usize,
}

pub fn blueprint_counts(rows: &[BlueprintRow]) -> BlueprintCounts {
    rows.iter()
        .fold(BlueprintCounts::default(), |acc, row| BlueprintCounts {
            total: acc.total.saturating_add(1),
            originals: if row.is_original {
                acc.originals.saturating_add(1)
            } else {
                acc.originals
            },
            copies: if row.is_original {
                acc.copies
            } else {
                acc.copies.saturating_add(1)
            },
        })
}

/// Uniform per-section failure line, copying the character-detail
/// helper: a scope failure points at the step-up panel above when
/// it is showing. The typed flag is branched on, never the message.
fn section_error_label(ui: &mut egui::Ui, section: &str, error: &SectionError, panel_shown: bool) {
    if error.needs_reauthorize && panel_shown {
        ui.label("Not authorized yet. Re-authorize above to load this section.");
    } else if error.needs_reauthorize {
        ui.label("Not authorized yet for this character.");
    } else {
        ui.label(format!("Could not load {section}: {}", error.message));
    }
}

/// One step-up panel for both sections: the button only sets the
/// generic shell step-up request flag for the active character.
fn industry_reauthorize_panel(ui: &mut egui::Ui, state: &mut AppState) {
    ui.heading("Industry needs two more EVE permissions.");
    ui.label(format!(
        "Industry jobs and the blueprint library will not load for \
         this character until these EVE SSO scopes are granted: {}. \
         Other views are unaffected.",
        EveConfig::INDUSTRY_SCOPES.join(" ")
    ));
    let active_id = state.active_character_id;
    if let Some(name) = state.active_character().map(|c| c.name.clone()) {
        ui.label(format!(
            "Choose Re-authorize and Mimir opens EVE SSO in your browser for {name}, \
             asking for the permissions already granted plus these. Sign in as \
             {name}: approving as a different character is rejected and nothing \
             is saved."
        ));
    }
    let enabled = !state.demo && !state.auth.is_busy() && state.active_character_id.is_some();
    if state.auth.is_busy() {
        ui.spinner();
        ui.label(state.auth.label());
    }
    if ui
        .add_enabled(enabled, egui::Button::new("Re-authorize with EVE SSO"))
        .clicked()
    {
        if let Some(active_id) = active_id {
            tracing::info!(
                "[AUTH] step-up re-authorize requested from Industry view character_id={} scopes={}",
                active_id,
                EveConfig::INDUSTRY_SCOPES.join(" ")
            );
            state.stepup_requested =
                Some(StepUpRequest::new(active_id, EveConfig::INDUSTRY_SCOPES));
            state.status_message =
                "EVE SSO requested: your browser should open to login.eveonline.com.".to_string();
        }
    }
}

fn show_jobs_section(
    ui: &mut egui::Ui,
    jobs: &crate::app::state::SectionResult<IndustryJobsData>,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.heading("Industry jobs");
    match jobs {
        Err(error) => section_error_label(ui, "industry jobs", error, panel_shown),
        Ok(data) => {
            let rows = industry_job_rows(&data.jobs, resolver);
            if rows.is_empty() {
                ui.label("No industry jobs for this character.");
                return;
            }
            let counts = job_counts(&rows);
            ui.label(format!(
                "{} jobs loaded, {} in progress.",
                counts.total, counts.in_progress
            ));
            if data.truncated {
                ui.label("Showing the first pages of jobs only; counts cover the jobs loaded.");
            }
            let now = Utc::now();
            for row in &rows {
                ui.separator();
                ui.label(format!("{} \u{2014} {}", row.type_name, row.activity_label));
                ui.label(format!("Status: {}", row.status_label));
                match row.successful_runs {
                    Some(successful) => {
                        ui.label(format!("Runs: {} ({successful} successful)", row.runs))
                    }
                    None => ui.label(format!("Runs: {}", row.runs)),
                };
                ui.label(format!("Facility: {}", row.facility_name));
                if row.in_progress {
                    if !row.end_date.is_empty() {
                        ui.label(format!(
                            "Ends: {} ({})",
                            widgets::format_date_short(&row.end_date),
                            widgets::countdown_label(Some(&row.end_date), now)
                        ));
                        let span_known = widgets::parse_esi_date(&row.start_date).is_some()
                            && widgets::parse_esi_date(&row.end_date).is_some();
                        if span_known {
                            let fraction = widgets::progress_fraction(
                                Some(&row.start_date),
                                Some(&row.end_date),
                                now,
                            );
                            ui.add(egui::ProgressBar::new(fraction));
                        }
                    }
                } else if !row.end_date.is_empty() {
                    ui.label(format!(
                        "Ended: {}",
                        widgets::format_date_short(&row.end_date)
                    ));
                }
            }
        }
    }
}

fn show_blueprints_section(
    ui: &mut egui::Ui,
    state: &mut AppState,
    blueprints: &crate::app::state::SectionResult<BlueprintsData>,
    resolver: &NameResolver,
    panel_shown: bool,
) {
    ui.heading("Blueprints");
    match blueprints {
        Err(error) => section_error_label(ui, "blueprints", error, panel_shown),
        Ok(data) => {
            let rows = blueprint_rows(&data.blueprints, resolver);
            if rows.is_empty() {
                ui.label("No blueprints for this character.");
                return;
            }
            // Controls render even when a filter matches nothing, so
            // the user can undo it.
            let focus = widgets::search_box(
                ui,
                &mut state.industry_search,
                "Filter blueprints by item or location (press / to focus)",
                state.focus_search,
            );
            state.text_input_focused |= focus;
            if focus {
                state.focus_search = false;
            }
            ui.horizontal_wrapped(|ui| {
                for kind in BlueprintKindFilter::ALL {
                    let selected = state.industry_blueprint_kind == kind;
                    if ui.selectable_label(selected, kind.label()).clicked() {
                        tracing::debug!("[INDUSTRY] blueprint kind filter chosen={}", kind.label());
                        state.industry_blueprint_kind = kind;
                    }
                }
            });
            let counts = blueprint_counts(&rows);
            ui.label(format!(
                "{} blueprints loaded ({} originals, {} copies).",
                counts.total, counts.originals, counts.copies
            ));
            if data.truncated {
                ui.label(
                    "Showing the first pages of blueprints only; counts cover the blueprints loaded.",
                );
            }
            let query = state.industry_search.clone();
            let kind = state.industry_blueprint_kind;
            let filtered = filter_blueprint_rows(&rows, &query, kind);
            if filtered.is_empty() {
                ui.label("No blueprints match the search.");
                return;
            }
            let shown = filtered.len().min(BLUEPRINT_RENDER_MAX);
            ui.label(format!("Showing {shown} of {} blueprints.", filtered.len()));
            for row in filtered.into_iter().take(BLUEPRINT_RENDER_MAX) {
                ui.separator();
                ui.label(format!("{} \u{2014} {}", row.type_name, row.kind_label));
                ui.label(format!(
                    "Quantity: {} \u{00b7} {}",
                    row.quantity_label, row.runs_label
                ));
                ui.label(format!(
                    "{} \u{00b7} {}",
                    efficiency_label("ME", row.material_efficiency),
                    efficiency_label("TE", row.time_efficiency)
                ));
                ui.label(format!("At: {}", row.location_name));
            }
        }
    }
}

pub fn show(ui: &mut egui::Ui, state: &mut AppState, resolver: &NameResolver) {
    ui.heading("Industry");
    widgets::mode_notice(ui, state.demo, state.offline);
    if state.active_character().is_none() {
        widgets::no_character_panel(ui);
        return;
    }
    // Clone the snapshot so the step-up button and search box can
    // borrow `state` mutably.
    let snapshot: LoadState<IndustryData> = state.industry.clone();
    match snapshot {
        LoadState::Loading => widgets::loading_panel(ui, "Loading industry data..."),
        LoadState::Empty => widgets::empty_panel(ui, "No industry data yet."),
        LoadState::Error(e) => {
            if widgets::error_panel_with_retry(ui, &e) {
                tracing::warn!("[INDUSTRY] retry requested after load error");
                state.retry_requested = true;
            }
        }
        LoadState::Ready(bundle) => {
            let panel_shown = !state.demo
                && state.active_character_id.is_some()
                && bundle.needs_industry_stepup();
            if panel_shown {
                tracing::debug!(
                    "[INDUSTRY] showing industry re-authorize guidance (missing scopes)"
                );
                industry_reauthorize_panel(ui, state);
            }
            show_jobs_section(ui, &bundle.jobs, resolver, panel_shown);
            show_blueprints_section(ui, state, &bundle.blueprints, resolver, panel_shown);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn resolver() -> NameResolver {
        let mut r = NameResolver::new();
        r.insert(681, "Bantam Blueprint".to_string());
        r.insert(682, "Destroyer Blueprint".to_string());
        r.insert(587, "Rifter".to_string());
        r.insert(16679, "Ferrogel".to_string());
        r.insert(60003760, "Jita Station".to_string());
        r.insert(60011866, "Amarr Station".to_string());
        r
    }

    fn job(
        job_id: i64,
        status: &str,
        end: &str,
        activity_id: i64,
        product: Option<i64>,
    ) -> IndustryJob {
        IndustryJob {
            job_id,
            facility_id: 60003760,
            activity_id,
            blueprint_type_id: 681,
            product_type_id: product,
            runs: 1,
            status: status.to_string(),
            start_date: "2026-11-10T10:00:00Z".to_string(),
            end_date: end.to_string(),
            ..Default::default()
        }
    }

    fn bp(item_id: i64, type_id: i64, quantity: i64, runs: i64) -> CharacterBlueprint {
        CharacterBlueprint {
            item_id,
            type_id,
            location_id: 60003760,
            quantity,
            runs,
            ..Default::default()
        }
    }

    #[test]
    fn activity_and_status_words_are_fixed_with_word_fallbacks() {
        assert_eq!(activity_label(1), "Manufacturing");
        assert_eq!(activity_label(3), "Time efficiency research");
        assert_eq!(activity_label(4), "Material efficiency research");
        assert_eq!(activity_label(5), "Copying");
        assert_eq!(activity_label(8), "Invention");
        assert_eq!(activity_label(11), "Reaction");
        // Includes values never enumerated in the design map.
        for other in [0, 2, 6, 7, 9, 10, -1, -5, 42, 99, i64::MAX] {
            assert_eq!(activity_label(other), "Unknown activity", "{other}");
            assert!(activity_label(other).parse::<i64>().is_err());
        }
        assert_eq!(status_label("active"), "Active");
        assert_eq!(status_label("paused"), "Paused");
        assert_eq!(status_label("ready"), "Ready");
        assert_eq!(status_label("delivered"), "Delivered");
        assert_eq!(status_label("cancelled"), "Cancelled");
        assert_eq!(status_label("reverted"), "Reverted");
        for other in ["", "Active", "ACTIVE", "weird-future-status", "123"] {
            assert_eq!(status_label(other), "Unknown status", "{other}");
        }
        assert!(is_in_progress_status("active"));
        assert!(is_in_progress_status("paused"));
        assert!(is_in_progress_status("ready"));
        for other in ["delivered", "cancelled", "reverted", "", "Active"] {
            assert!(!is_in_progress_status(other), "{other}");
        }
    }

    #[test]
    fn sentinel_words_classification_and_efficiency() {
        assert_eq!(blueprint_quantity_label(-1), "Original");
        assert_eq!(blueprint_quantity_label(-2), "Copy");
        assert_eq!(blueprint_quantity_label(-3), "Unknown quantity");
        assert_eq!(blueprint_quantity_label(i64::MIN), "Unknown quantity");
        assert_eq!(blueprint_quantity_label(0), "0");
        assert_eq!(blueprint_quantity_label(7), "7");
        assert_eq!(blueprint_runs_label(-1), "Infinite runs (original)");
        assert_eq!(blueprint_runs_label(-2), "Unknown runs");
        assert_eq!(blueprint_runs_label(0), "0 runs");
        assert_eq!(blueprint_runs_label(10), "10 runs");
        // Classification reads runs only, never quantity.
        assert!(blueprint_is_original(&bp(1, 681, -2, -1)));
        assert!(!blueprint_is_original(&bp(2, 681, -2, 5)));
        assert!(!blueprint_is_original(&bp(3, 681, -1, -2)));
        assert!(!blueprint_is_original(&bp(4, 681, -1, 0)));
        assert_eq!(blueprint_kind_label(&bp(1, 681, 3, -1)), "Original (BPO)");
        assert_eq!(blueprint_kind_label(&bp(2, 681, -1, 5)), "Copy (BPC)");
        assert_eq!(efficiency_label("ME", -4), "ME 0");
        assert_eq!(efficiency_label("TE", 14), "TE 14");
        assert_eq!(efficiency_label("ME", 0), "ME 0");
    }

    #[test]
    fn job_rows_display_type_ordering_clamp_and_counts() {
        // Delivered job ends earliest but ranks last; in-progress
        // soonest first; empty end last within its rank.
        let mut neg = job(6, "active", "2026-11-18T10:00:00Z", 1, Some(587));
        neg.runs = -3;
        let jobs = vec![
            job(1, "delivered", "2026-11-11T10:00:00Z", 1, Some(587)),
            job(2, "active", "2026-11-20T10:00:00Z", 1, Some(587)),
            job(3, "ready", "", 5, None),
            job(4, "paused", "2026-11-19T10:00:00Z", 11, Some(16679)),
            job(5, "cancelled", "2026-11-12T10:00:00Z", 1, None),
            neg,
            // Non-positive product falls back to the blueprint type.
            job(7, "active", "2026-11-18T10:00:00Z", 3, Some(0)),
            job(8, "active", "2026-11-18T10:00:00Z", 3, Some(-9)),
        ];
        let rows = industry_job_rows(&jobs, &resolver());
        let ids: Vec<i64> = rows.iter().map(|r| r.job_id).collect();
        assert_eq!(ids, vec![6, 7, 8, 4, 2, 3, 1, 5]);
        // Reaction job (4) interleaves by the same keys, not grouped.
        assert_eq!(rows[3].activity_label, "Reaction");
        assert_eq!(rows[3].type_name, "Ferrogel");
        // Product preference and fallbacks.
        assert_eq!(rows[0].display_type_id, 587);
        assert_eq!(rows[0].type_name, "Rifter");
        assert_eq!(rows[0].runs, 0, "negative runs clamp to 0");
        assert_eq!(rows[1].display_type_id, 681, "product 0 falls back");
        assert_eq!(rows[2].display_type_id, 681, "negative product falls back");
        let copy_job = rows.iter().find(|r| r.job_id == 3).expect("ready job");
        assert_eq!(copy_job.display_type_id, 681, "None falls back");
        assert_eq!(copy_job.activity_label, "Copying");
        assert_eq!(copy_job.facility_name, "Jita Station");
        let counts = job_counts(&rows);
        assert_eq!(
            counts,
            JobCounts {
                total: 8,
                in_progress: 6
            }
        );
        assert!(industry_job_rows(&[], &resolver()).is_empty());
        assert_eq!(job_counts(&[]), JobCounts::default());
    }

    #[test]
    fn job_rows_clamp_negative_successful_runs() {
        // Successful runs decode from remote JSON unvalidated: a negative
        // value must render as zero, never a raw negative count.
        let mut neg = job(9, "delivered", "2026-11-11T10:00:00Z", 1, None);
        neg.successful_runs = Some(-7);
        let mut ok = job(10, "delivered", "2026-11-10T10:00:00Z", 1, None);
        ok.successful_runs = Some(3);
        let none = job(11, "active", "2026-11-12T10:00:00Z", 1, None);
        let rows = industry_job_rows(&[neg, ok, none], &resolver());
        let by_id = |id: i64| {
            rows.iter()
                .find(|r| r.job_id == id)
                .expect("row")
                .successful_runs
        };
        assert_eq!(by_id(9), Some(0));
        assert_eq!(by_id(10), Some(3));
        assert_eq!(by_id(11), None);
    }

    #[test]
    fn job_rows_tie_break_start_then_job_id() {
        let mut later = job(9, "active", "2026-11-20T10:00:00Z", 1, None);
        later.start_date = "2026-11-12T10:00:00Z".to_string();
        let earlier = job(10, "active", "2026-11-20T10:00:00Z", 1, None);
        // earlier.start is 2026-11-10 from the helper.
        let rows = industry_job_rows(&[later, earlier], &resolver());
        assert_eq!(rows[0].job_id, 10);
        assert_eq!(rows[1].job_id, 9);
    }

    #[test]
    fn blueprint_rows_sort_search_kind_and_counts() {
        // Type-ID order (681, 682) differs from name order:
        // "Bantam Blueprint" < "Destroyer Blueprint" by name anyway,
        // so also prove case-insensitive name sort via location tie.
        let blueprints = vec![
            bp(710000002, 682, -2, 5),
            bp(710000001, 681, -1, -1),
            bp(710000003, 681, 3, -1),
        ];
        let rows = blueprint_rows(&blueprints, &resolver());
        assert_eq!(rows[0].type_name, "Bantam Blueprint");
        assert_eq!(rows[0].item_id, 710000001);
        assert_eq!(rows[1].item_id, 710000003);
        assert_eq!(rows[2].type_name, "Destroyer Blueprint");
        assert_eq!(rows[0].quantity_label, "Original");
        assert_eq!(rows[0].runs_label, "Infinite runs (original)");
        assert_eq!(rows[2].quantity_label, "Copy");
        assert_eq!(rows[2].runs_label, "5 runs");

        let counts = blueprint_counts(&rows);
        assert_eq!(
            counts,
            BlueprintCounts {
                total: 3,
                originals: 2,
                copies: 1
            }
        );
        assert_eq!(counts.originals + counts.copies, counts.total);

        // Search matches names and locations, case-insensitively.
        assert_eq!(
            filter_blueprint_rows(&rows, "bantam", BlueprintKindFilter::All).len(),
            2
        );
        assert_eq!(
            filter_blueprint_rows(&rows, "JITA", BlueprintKindFilter::All).len(),
            3
        );
        assert_eq!(
            filter_blueprint_rows(&rows, "", BlueprintKindFilter::All).len(),
            3
        );
        // Anti-Flutter regression: numeric type/item IDs match nothing.
        assert!(filter_blueprint_rows(&rows, "681", BlueprintKindFilter::All).is_empty());
        assert!(filter_blueprint_rows(&rows, "710000001", BlueprintKindFilter::All).is_empty());
        // Kind filter and composition with search.
        assert_eq!(
            filter_blueprint_rows(&rows, "", BlueprintKindFilter::Originals).len(),
            2
        );
        assert_eq!(
            filter_blueprint_rows(&rows, "", BlueprintKindFilter::Copies).len(),
            1
        );
        assert_eq!(
            filter_blueprint_rows(&rows, "bantam", BlueprintKindFilter::Copies).len(),
            0
        );
        assert_eq!(
            filter_blueprint_rows(&rows, "destroyer", BlueprintKindFilter::Copies).len(),
            1
        );
    }

    #[test]
    fn blueprint_sort_is_by_name_not_type_id() {
        // Give the larger type ID the alphabetically earlier name by
        // reusing resolver names: insert in a fresh resolver.
        let mut r = NameResolver::new();
        r.insert(100, "Zulu Blueprint".to_string());
        r.insert(200, "Alpha Blueprint".to_string());
        r.insert(60003760, "Jita Station".to_string());
        r.insert(60011866, "Amarr Station".to_string());
        let mut at_amarr = bp(2, 200, -1, -1);
        at_amarr.location_id = 60011866;
        let at_jita = bp(1, 200, -1, -1);
        let zulu = bp(3, 100, -2, 2);
        let rows = blueprint_rows(&[zulu, at_jita, at_amarr], &r);
        assert_eq!(rows[0].type_name, "Alpha Blueprint");
        // Same name: location name (Amarr < Jita) breaks the tie.
        assert_eq!(rows[0].location_name, "Amarr Station");
        assert_eq!(rows[1].location_name, "Jita Station");
        assert_eq!(rows[2].type_name, "Zulu Blueprint");
    }

    #[test]
    fn render_cap_keeps_counts_over_full_loaded_set() {
        let blueprints: Vec<CharacterBlueprint> = (0..(BLUEPRINT_RENDER_MAX as i64 + 25))
            .map(|i| {
                bp(
                    710100000 + i,
                    681,
                    if i % 2 == 0 { -1 } else { -2 },
                    if i % 2 == 0 { -1 } else { 3 },
                )
            })
            .collect();
        let rows = blueprint_rows(&blueprints, &resolver());
        assert_eq!(rows.len(), BLUEPRINT_RENDER_MAX + 25);
        let counts = blueprint_counts(&rows);
        assert_eq!(counts.total, BLUEPRINT_RENDER_MAX + 25);
        assert_eq!(counts.originals + counts.copies, counts.total);
        let filtered = filter_blueprint_rows(&rows, "", BlueprintKindFilter::All);
        let shown = filtered.len().min(BLUEPRINT_RENDER_MAX);
        assert_eq!(shown, BLUEPRINT_RENDER_MAX);
        assert_eq!(filtered.len(), BLUEPRINT_RENDER_MAX + 25);
    }

    #[test]
    fn empty_resolver_never_renders_raw_ids_or_sentinel_digits() {
        let jobs = vec![
            job(710000101, "active", "2026-11-20T10:00:00Z", 99, Some(587)),
            job(710000102, "future-status", "", 1, None),
        ];
        let rows = industry_job_rows(&jobs, &NameResolver::new());
        for row in &rows {
            assert_eq!(row.type_name, "Unknown Item");
            assert_eq!(row.facility_name, "Unknown Location");
            for text in [
                row.type_name.as_str(),
                row.facility_name.as_str(),
                row.activity_label,
                row.status_label,
            ] {
                assert!(text.parse::<i64>().is_err(), "raw id text: {text}");
                assert_ne!(text, "710000101");
                assert_ne!(text, "587");
            }
        }
        assert_eq!(rows[0].activity_label, "Unknown activity");
        let blueprints = vec![bp(710001001, 681, -1, -1), bp(710001002, 682, -2, 5)];
        let brows = blueprint_rows(&blueprints, &NameResolver::new());
        for row in &brows {
            assert_eq!(row.type_name, "Unknown Item");
            assert_eq!(row.location_name, "Unknown Location");
            for text in [
                row.type_name.as_str(),
                row.location_name.as_str(),
                row.kind_label,
                row.quantity_label.as_str(),
                row.runs_label.as_str(),
            ] {
                assert!(text.parse::<i64>().is_err(), "raw id text: {text}");
                assert_ne!(text, "-1");
                assert_ne!(text, "-2");
                assert!(!text.contains("710001"), "instance id leaked: {text}");
            }
        }
        assert_eq!(brows[0].quantity_label, "Original");
        assert_eq!(brows[1].quantity_label, "Copy");
    }
}
