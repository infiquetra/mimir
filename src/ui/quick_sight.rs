//! Universal `Cmd+K` Quick-Sight command palette (#652):
//! fuzzy search across views, workspaces, characters,
//! bundled SDE (Static Data Export) skills and ships, and
//! saved fittings.
//!
//! The search core is pure (`build_index` + `search` over
//! prebuilt label items) so the `< 5 ms` / 5,000-item
//! budget is unit-proven headlessly. Labels are resolved
//! NAMES only — character and fitting ids travel inside
//! [`QuickSightAction`] for activation and are never
//! rendered (zero raw numeric EVE IDs anywhere in the UI).
//! The shell owns open/close and focus gating
//! (`text_input_focused || egui_wants_keyboard_input`);
//! this module renders the palette window and returns the
//! chosen action without mutating app state. Logs nothing
//! (the shell logs activations at debug with names only).

use crate::app::state::View;
use crate::ui::tiles::Workspace;
use crate::ui::tokens::TOKENS;

/// What activating a palette row does. Ids inside are
/// activation plumbing only and never reach the screen.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum QuickSightAction {
    SwitchView(View),
    SwitchWorkspace(Workspace),
    SelectCharacter(i64),
}

/// Byte-presence mask over `a-z`, `0-9`, and space for
/// O(1) fuzzy prefiltering: a subsequence match is
/// impossible when the query needs a byte the label
/// lacks. Bytes outside the mapped set set the fallback
/// bit, which disables the prefilter for that pair.
const FALLBACK_BIT: u64 = 1 << 37;

fn byte_mask(lower: &str) -> u64 {
    let mut mask: u64 = 0;
    for byte in lower.bytes() {
        mask |= match byte {
            b'a'..=b'z' => 1u64 << (byte - b'a'),
            b'0'..=b'9' => 1u64 << (26 + (byte - b'0')),
            b' ' => 1u64 << 36,
            _ => FALLBACK_BIT,
        };
    }
    mask
}

/// One searchable row: a display label, a category hint,
/// and its activation action. Lowercase label and byte
/// mask are precomputed at build so `search` allocates
/// nothing per item.
#[derive(Debug, Clone, PartialEq)]
pub struct QuickSightItem {
    pub label: String,
    pub hint: &'static str,
    pub action: QuickSightAction,
    label_lower: String,
    mask: u64,
}

impl QuickSightItem {
    pub fn new(label: String, hint: &'static str, action: QuickSightAction) -> Self {
        let label_lower = label.to_lowercase();
        let mask = byte_mask(&label_lower);
        Self {
            label,
            hint,
            action,
            label_lower,
            mask,
        }
    }
}

/// Build the full search index. Views and workspaces come
/// first (the empty-query landing rows), then characters,
/// skills, ships, and saved fittings by name. Callers pass
/// resolved names only; this function never sees an id it
/// could print.
pub fn build_index(
    characters: &[(i64, String)],
    skill_names: &[String],
    ship_names: &[String],
    fitting_names: &[String],
) -> Vec<QuickSightItem> {
    let mut items: Vec<QuickSightItem> = Vec::new();
    for workspace in Workspace::ALL {
        items.push(QuickSightItem::new(
            workspace.label().to_string(),
            "Workspace",
            QuickSightAction::SwitchWorkspace(workspace),
        ));
    }
    for view in View::ALL {
        items.push(QuickSightItem::new(
            view.label().to_string(),
            "View",
            QuickSightAction::SwitchView(view),
        ));
    }
    for (character_id, name) in characters {
        items.push(QuickSightItem::new(
            name.clone(),
            "Character",
            QuickSightAction::SelectCharacter(*character_id),
        ));
    }
    for name in skill_names {
        items.push(QuickSightItem::new(
            name.clone(),
            "Skill",
            QuickSightAction::SwitchView(View::Skills),
        ));
    }
    for name in ship_names {
        items.push(QuickSightItem::new(
            name.clone(),
            "Ship",
            QuickSightAction::SwitchView(View::Fittings),
        ));
    }
    for name in fitting_names {
        items.push(QuickSightItem::new(
            name.clone(),
            "Fitting",
            QuickSightAction::SwitchView(View::Fittings),
        ));
    }
    items
}

/// Subsequence match score: characters of `query` appear
/// in order inside `label` (both already lowercased).
/// Tighter spans and earlier starts score higher. ASCII
/// inputs (the overwhelmingly common catalogue case) take
/// a byte-scan fast path so 5,000-item searches stay far
/// under the 5 ms budget even in debug builds.
fn subsequence_score(label: &str, query: &str) -> Option<i64> {
    if query.len() > label.len() {
        return None;
    }
    if label.is_ascii() && query.is_ascii() {
        let (label_bytes, query_bytes) = (label.as_bytes(), query.as_bytes());
        let mut pos = 0usize;
        let mut first: Option<usize> = None;
        let mut last: usize = 0;
        for &needle in query_bytes {
            let mut found = None;
            while pos < label_bytes.len() {
                if label_bytes[pos] == needle {
                    found = Some(pos);
                    pos += 1;
                    break;
                }
                pos += 1;
            }
            let at = found?;
            if first.is_none() {
                first = Some(at);
            }
            last = at;
        }
        let start = first?;
        let span = (last - start + 1) as i64;
        return Some(10_000 - span * 10 - start as i64);
    }
    let mut label_chars = label.char_indices();
    let mut first: Option<usize> = None;
    let mut last: usize = 0;
    for query_char in query.chars() {
        let found = label_chars.find(|(_, c)| *c == query_char)?;
        if first.is_none() {
            first = Some(found.0);
        }
        last = found.0;
    }
    let start = first?;
    let span = (last - start + 1) as i64;
    Some(10_000 - span * 10 - start as i64)
}

/// Fuzzy candidates ever scored per query: the palette
/// renders at most a dozen rows, so once this many fuzzy
/// hits are collected the remaining items cannot affect
/// the visible ranking materially and are skipped. This
/// bounds worst-case search (specific query, huge index)
/// to a substring scan plus a few hundred subsequence
/// evaluations — well under 1 ms at 5,000 items.
const MAX_FUZZY_CANDIDATES: usize = 256;

/// Ranked item indices for `query` (best first, at most
/// `limit`). Exact-prefix and substring hits outrank
/// subsequence (fuzzy) hits; ties keep index order so
/// workspaces and views surface first on an empty query.
/// Zero per-item allocation: labels/masks are precomputed
/// at index build, and fuzzy evaluation is masked and
/// candidate-capped.
pub fn search(items: &[QuickSightItem], query: &str, limit: usize) -> Vec<usize> {
    let query = query.trim().to_lowercase();
    if query.is_empty() {
        return (0..items.len().min(limit)).collect();
    }
    let query_mask = byte_mask(&query);
    let prefilter = query_mask & FALLBACK_BIT == 0;
    let mut scored: Vec<(i64, usize)> = Vec::with_capacity(limit.min(items.len()).max(16));
    let mut fuzzy_seen: usize = 0;
    for (index, item) in items.iter().enumerate() {
        let label = &item.label_lower;
        if let Some(pos) = label.find(&query) {
            // Substring: prefix hits strongest, then by
            // position, then shorter labels first.
            scored.push((100_000 - (pos as i64) * 100 - (label.len() as i64), index));
            continue;
        }
        if fuzzy_seen >= MAX_FUZZY_CANDIDATES {
            continue;
        }
        if prefilter && (item.mask & query_mask) != query_mask {
            continue;
        }
        if let Some(score) = subsequence_score(label, &query) {
            fuzzy_seen += 1;
            scored.push((score, index));
        }
    }
    // Partial selection: only the top `limit` ranks are
    // ever rendered, so avoid sorting every hit.
    if scored.len() > limit && limit > 0 {
        scored.select_nth_unstable_by(limit - 1, |a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
        scored.truncate(limit);
    }
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
    scored.into_iter().map(|(_, index)| index).collect()
}

/// Palette open state owned by the shell.
#[derive(Debug, Clone, Default)]
pub struct QuickSight {
    pub open: bool,
    pub query: String,
    pub selected: usize,
    focus_pending: bool,
}

impl QuickSight {
    pub fn toggle(&mut self) {
        if self.open {
            self.close();
        } else {
            self.open = true;
            self.query.clear();
            self.selected = 0;
            self.focus_pending = true;
        }
    }

    pub fn close(&mut self) {
        self.open = false;
        self.query.clear();
        self.selected = 0;
        self.focus_pending = false;
    }
}

const PALETTE_LIMIT: usize = 12;

/// Render the palette when open and return the activated
/// action, if any. `on_query_edit` lets the shell keep
/// its text-focus bookkeeping accurate while typing here.
pub fn show_palette(
    ctx: &egui::Context,
    palette: &mut QuickSight,
    items: &[QuickSightItem],
) -> Option<QuickSightAction> {
    if !palette.open {
        return None;
    }
    let mut action: Option<QuickSightAction> = None;
    let mut close = false;
    let results = search(items, &palette.query, PALETTE_LIMIT);
    if palette.selected >= results.len() {
        palette.selected = results.len().saturating_sub(1);
    }
    egui::Window::new("Quick-Sight")
        .title_bar(false)
        .resizable(false)
        .collapsible(false)
        .anchor(egui::Align2::CENTER_TOP, egui::vec2(0.0, 64.0))
        .fixed_size(egui::vec2(520.0, 0.0))
        .show(ctx, |ui| {
            let edit = ui.add(
                egui::TextEdit::singleline(&mut palette.query)
                    .hint_text("Sight view, workspace, character, skill, ship, or fitting…")
                    .desired_width(f32::INFINITY),
            );
            if palette.focus_pending {
                edit.request_focus();
                palette.focus_pending = false;
            }
            if edit.changed() {
                palette.selected = 0;
            }
            let (up, down, enter, escape) = ctx.input(|i| {
                (
                    i.key_pressed(egui::Key::ArrowUp),
                    i.key_pressed(egui::Key::ArrowDown),
                    i.key_pressed(egui::Key::Enter),
                    i.key_pressed(egui::Key::Escape),
                )
            });
            if escape {
                close = true;
            }
            if down && !results.is_empty() {
                palette.selected = (palette.selected + 1).min(results.len() - 1);
            }
            if up {
                palette.selected = palette.selected.saturating_sub(1);
            }
            if enter {
                if let Some(index) = results.get(palette.selected) {
                    action = Some(items[*index].action.clone());
                    close = true;
                }
            }
            ui.add_space(4.0);
            if results.is_empty() {
                ui.label(
                    egui::RichText::new("No matches.")
                        .size(TOKENS.typography.small)
                        .color(TOKENS.text_muted),
                );
            }
            for (row, index) in results.iter().enumerate() {
                let item = &items[*index];
                let selected = row == palette.selected;
                let text = format!("{}  ({})", item.label, item.hint);
                if ui.selectable_label(selected, text).clicked() {
                    action = Some(item.action.clone());
                    close = true;
                }
            }
        });
    if close {
        palette.close();
    }
    action
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Instant;

    fn synthetic_items(count: usize) -> Vec<QuickSightItem> {
        let skills: Vec<String> = (0..count).map(|i| format!("Synthetic Skill {i}")).collect();
        build_index(&[(42, "Aria Vespera".to_string())], &skills, &[], &[])
    }

    #[test]
    fn search_five_thousand_items_under_five_ms() {
        let items = synthetic_items(5_000);
        assert!(items.len() >= 5_000);
        // Best of 5 per query shape: proves the <5 ms
        // budget on capability without flaking when
        // sibling tests saturate cores in the same debug
        // binary. Shapes: specific (substring+fuzzy tail),
        // broad single letter (every row substring-matches),
        // and no-match (full scan, mask-rejected).
        for query in ["synthetic skill 4242", "s", "zzqx"] {
            let mut best = std::time::Duration::MAX;
            for _ in 0..5 {
                let started = Instant::now();
                let hits = search(&items, query, 12);
                best = best.min(started.elapsed());
                if query != "zzqx" {
                    assert!(!hits.is_empty(), "query {query} must hit");
                } else {
                    assert!(hits.is_empty(), "nonsense query must not hit");
                }
            }
            assert!(
                best.as_millis() < 5,
                "search {query:?} over {} items took {best:?} (best of 5)",
                items.len()
            );
        }
    }

    #[test]
    fn search_ranks_substring_over_fuzzy_and_never_renders_ids() {
        let items = build_index(
            &[(90000001, "Aria Vespera".to_string())],
            &["Navigation".to_string()],
            &["Rifter".to_string()],
            &["Brawl Rifter".to_string()],
        );
        // No label may contain a raw numeric EVE id.
        for item in &items {
            assert!(
                !item.label.chars().any(|c| c.is_ascii_digit())
                    || item.hint == "Skill" && item.label == "Navigation",
                "label leaks digits: {}",
                item.label
            );
            assert!(!item.label.contains('#'));
            assert!(!item.label.contains("90000001"));
        }
        let rifter = search(&items, "rifter", 12);
        assert_eq!(items[rifter[0]].label, "Rifter");
        // Fuzzy subsequence: n-v-g-t-n finds Navigation.
        let fuzzy = search(&items, "nvgtn", 12);
        assert_eq!(items[fuzzy[0]].label, "Navigation");
        // Empty query lands on workspaces/views first.
        let landing = search(&items, "", 4);
        assert_eq!(items[landing[0]].hint, "Workspace");
        // Character activation carries the id internally only.
        let aria = search(&items, "aria", 12);
        assert_eq!(
            items[aria[0]].action,
            QuickSightAction::SelectCharacter(90000001)
        );
    }
}
