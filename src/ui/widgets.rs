//! Shared panels and formatting. Display strings use resolved EVE names,
//! never raw numeric IDs. Every formatter is total: malformed dates and
//! non-finite amounts render a placeholder instead of panicking.

use chrono::{DateTime, Utc};

use super::theme;

/// Thousands-group a digit string (no sign, no fraction).
fn group_digits(digits: &str) -> String {
    let mut grouped = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    grouped
}

/// Format an ISK amount with thousands separators and two decimals.
pub fn format_isk(amount: f64) -> String {
    if !amount.is_finite() {
        tracing::warn!("[UI] format_isk non-finite amount");
        return "0.00 ISK".to_string();
    }
    let sign = if amount < 0.0 { "-" } else { "" };
    let abs = amount.abs();
    // Above this magnitude the i64 split loses the fraction (and
    // the carry could overflow); render the f64 directly and
    // group its integer digits instead. Finite hostile totals
    // must format, never panic.
    if abs >= 9.0e18 {
        let rendered = format!("{abs:.2}");
        let (digits, frac_part) = match rendered.split_once('.') {
            Some((whole_part, frac_part)) => (whole_part, frac_part),
            None => (rendered.as_str(), "00"),
        };
        return format!("{sign}{}.{frac_part} ISK", group_digits(digits));
    }
    let mut whole = abs.floor() as i64;
    let mut frac = ((abs - whole as f64) * 100.0).round() as i64;
    if frac >= 100 {
        whole = whole.saturating_add(1);
        frac -= 100;
    }
    let digits = whole.to_string();
    let mut grouped = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    format!("{sign}{grouped}.{frac:02} ISK")
}

/// Signed ISK for journal rows (`+1,250.00 ISK` / `-150.00 ISK`).
pub fn format_isk_signed(amount: f64) -> String {
    if amount > 0.0 && amount.is_finite() {
        format!("+{}", format_isk(amount))
    } else {
        format_isk(amount)
    }
}

/// Fitting resource amount: thousands-grouped with exactly one
/// decimal, always (`114.0 tf`, `1,234.5 MW`). Fitting needs can
/// carry a fractional `.5` CPU, so integer display would be lossy;
/// the one-decimal shape follows Flutter's readout.
pub fn format_fitting_amount(value: f64, unit: &str) -> String {
    if !value.is_finite() {
        tracing::warn!("[UI] format_fitting_amount non-finite amount");
        return format!("0.0 {unit}");
    }
    let sign = if value < 0.0 { "-" } else { "" };
    let abs = value.abs();
    // Same huge-magnitude guard as format_isk: hostile remote
    // quantities can push a finite total past i64 range, where
    // the split below would overflow on the carry.
    if abs >= 9.0e18 {
        let rendered = format!("{abs:.1}");
        let (digits, frac_part) = match rendered.split_once('.') {
            Some((whole_part, frac_part)) => (whole_part, frac_part),
            None => (rendered.as_str(), "0"),
        };
        return format!("{sign}{}.{frac_part} {unit}", group_digits(digits));
    }
    let mut whole = abs.floor() as i64;
    let mut frac = ((abs - whole as f64) * 10.0).round() as i64;
    if frac >= 10 {
        whole = whole.saturating_add(1);
        frac -= 10;
    }
    let digits = whole.to_string();
    let mut grouped = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    format!("{sign}{grouped}.{frac} {unit}")
}

/// Fitting resistance percentage: exactly one decimal with no
/// space before `%` (`33.0%`, `-10.0%`). Thin adapter over
/// [`format_fitting_amount`]: it inherits grouping, rounding,
/// sign handling, and the huge/non-finite guards, and only
/// removes the separator space before the unit.
pub fn format_fitting_percent(value: f64) -> String {
    let formatted = format_fitting_amount(value, "%");
    match formatted.strip_suffix(" %") {
        Some(number) => format!("{number}%"),
        None => formatted,
    }
}

/// Compact skill-point formatting (`5,200,000 SP`).
pub fn format_sp(points: i64) -> String {
    let digits = points.unsigned_abs().to_string();
    let mut grouped = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i).is_multiple_of(3) {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    let sign = if points < 0 { "-" } else { "" };
    format!("{sign}{grouped} SP")
}

/// Format a remaining duration as `Xd Xh Xm` (live countdowns tick from
/// stored finish dates; the formatter itself is pure).
pub fn format_countdown(total_seconds: i64) -> String {
    if total_seconds <= 0 {
        return "0m".to_string();
    }
    let days = total_seconds / 86_400;
    let hours = (total_seconds % 86_400) / 3_600;
    let minutes = (total_seconds % 3_600) / 60;
    if days > 0 {
        format!("{days}d {hours}h {minutes}m")
    } else if hours > 0 {
        format!("{hours}h {minutes}m")
    } else if minutes > 0 {
        format!("{minutes}m")
    } else {
        format!("{}s", total_seconds % 60)
    }
}

/// Parse an ESI RFC 3339 date. Malformed input yields `None`, never a panic.
pub fn parse_esi_date(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .map(|parsed| parsed.with_timezone(&Utc))
        .ok()
}

/// Seconds from `now` until `finish` (negative when already finished).
pub fn seconds_until(finish: &str, now: DateTime<Utc>) -> Option<i64> {
    parse_esi_date(finish).map(|end| (end - now).num_seconds())
}

/// Human countdown for a finish date: `in 5d 0h 0m`, `finished`, or a
/// placeholder for paused/unparseable entries.
pub fn countdown_label(finish: Option<&str>, now: DateTime<Utc>) -> String {
    match finish {
        None => "paused".to_string(),
        Some(value) => match seconds_until(value, now) {
            Some(secs) if secs > 0 => format!("in {}", format_countdown(secs)),
            Some(_) => "finished".to_string(),
            None => {
                tracing::debug!("[UI] unparseable finish date");
                "unknown finish".to_string()
            }
        },
    }
}

/// Short date for tables (`2026-11-14 10:00`). Unparseable input gets
/// fixed words: values here are remote text and must never render
/// verbatim (a pseudo-date like `700000001` is a raw ID on screen).
pub fn format_date_short(value: &str) -> String {
    match parse_esi_date(value) {
        Some(date) => date.format("%Y-%m-%d %H:%M").to_string(),
        None => "date unavailable".to_string(),
    }
}

/// Linear progress between two ESI dates at `now`, clamped to `0.0..=1.0`.
pub fn progress_fraction(start: Option<&str>, finish: Option<&str>, now: DateTime<Utc>) -> f32 {
    let (Some(start), Some(finish)) = (start, finish) else {
        return 0.0;
    };
    let (Some(start), Some(finish)) = (parse_esi_date(start), parse_esi_date(finish)) else {
        return 0.0;
    };
    let total = (finish - start).num_seconds();
    if total <= 0 {
        return 0.0;
    }
    let elapsed = (now - start).num_seconds();
    (elapsed as f64 / total as f64).clamp(0.0, 1.0) as f32
}

/// Compact integer count with thousands grouping (`150,000`, `-1,250`).
pub fn format_count(count: i64) -> String {
    let digits = count.unsigned_abs().to_string();
    let sign = if count < 0 { "-" } else { "" };
    format!("{sign}{}", group_digits(&digits))
}

/// Semantic text color for ISK / signed values.
pub fn isk_color(amount: f64) -> egui::Color32 {
    if !amount.is_finite() {
        theme::TEXT_PRIMARY
    } else if amount > 0.0 {
        theme::POSITIVE
    } else if amount < 0.0 {
        theme::NEGATIVE
    } else {
        theme::TEXT_PRIMARY
    }
}

/// Framed card container using Mimir's EVE dark theme tokens.
pub fn card(ui: &mut egui::Ui, add_contents: impl FnOnce(&mut egui::Ui)) {
    egui::Frame::none()
        .fill(theme::BG_CARD)
        .stroke(egui::Stroke::new(1.0_f32, theme::BORDER_SUBTLE))
        .rounding(egui::Rounding::same(8.0))
        .inner_margin(egui::Margin::symmetric(14.0, 10.0))
        .outer_margin(egui::Margin::symmetric(0.0, 4.0))
        .show(ui, add_contents);
}

/// Compact KPI tile with a muted uppercase-style label and large colored value.
pub fn metric_tile(ui: &mut egui::Ui, label: &str, value: &str, value_color: egui::Color32) {
    egui::Frame::none()
        .fill(theme::BG_CARD_ALT)
        .stroke(egui::Stroke::new(1.0_f32, theme::BORDER_SUBTLE))
        .rounding(egui::Rounding::same(8.0))
        .inner_margin(egui::Margin::symmetric(14.0, 10.0))
        .show(ui, |ui| {
            ui.set_min_width(180.0);
            ui.vertical(|ui| {
                ui.label(
                    egui::RichText::new(label)
                        .size(11.5)
                        .color(theme::TEXT_SECONDARY),
                );
                ui.add_space(2.0);
                ui.label(
                    egui::RichText::new(value)
                        .size(17.0)
                        .strong()
                        .color(value_color),
                );
            });
        });
}

/// Rounded status or tag pill.
pub fn badge(ui: &mut egui::Ui, text: &str, bg: egui::Color32, fg: egui::Color32) {
    egui::Frame::none()
        .fill(bg)
        .stroke(egui::Stroke::new(1.0_f32, fg.gamma_multiply(0.45)))
        .rounding(egui::Rounding::same(10.0))
        .inner_margin(egui::Margin::symmetric(8.0, 2.0))
        .show(ui, |ui| {
            ui.label(egui::RichText::new(text).size(11.5).strong().color(fg));
        });
}

/// Accent section title inside cards and views.
pub fn section_title(ui: &mut egui::Ui, text: &str) {
    ui.label(
        egui::RichText::new(text)
            .size(15.5)
            .strong()
            .color(theme::ACCENT_CYAN),
    );
}

/// Case-insensitive substring match used by every search box.
pub fn matches_search(haystack: &str, needle: &str) -> bool {
    needle.is_empty() || haystack.to_lowercase().contains(&needle.to_lowercase())
}

pub fn loading_panel(ui: &mut egui::Ui, label: &str) {
    ui.horizontal(|ui| {
        ui.spinner();
        ui.label(label);
    });
}

pub fn empty_panel(ui: &mut egui::Ui, label: &str) {
    ui.label(label);
}

/// Plain error panel with no Retry button, for failures nothing can
/// retry (for example bundled data that failed validation).
pub fn error_panel(ui: &mut egui::Ui, message: &str) {
    tracing::debug!("[UI] error panel without retry shown");
    ui.colored_label(egui::Color32::LIGHT_RED, message);
}

/// Error panel whose Retry button reports the click back to the caller so
/// the view can set `AppState::retry_requested` for the integrator.
pub fn error_panel_with_retry(ui: &mut egui::Ui, message: &str) -> bool {
    ui.colored_label(egui::Color32::LIGHT_RED, message);
    if ui.button("Retry").clicked() {
        tracing::info!("[UI] retry clicked");
        return true;
    }
    false
}

pub fn no_character_panel(ui: &mut egui::Ui) {
    ui.heading("No character selected");
    ui.label("Add a character with EVE SSO, or try the offline demo.");
    ui.label("Keys: 1-9, 0, E switch views, PageUp/PageDown switch character.");
}

/// Demo/offline notice shown at the top of data views.
pub fn mode_notice(ui: &mut egui::Ui, demo: bool, offline: bool) {
    let message = if demo {
        Some((
            "DEMO",
            "Demo data: invented sample rows, no network or EVE account involved.",
            theme::WARNING_BG,
            theme::WARNING,
        ))
    } else if offline {
        Some((
            "OFFLINE",
            "Offline: showing cached data; it may be stale.",
            theme::WARNING_BG,
            theme::WARNING,
        ))
    } else {
        None
    };
    if let Some((tag, text, bg, fg)) = message {
        egui::Frame::none()
            .fill(bg)
            .stroke(egui::Stroke::new(1.0_f32, fg.gamma_multiply(0.45)))
            .rounding(egui::Rounding::same(6.0))
            .inner_margin(egui::Margin::symmetric(10.0, 6.0))
            .outer_margin(egui::Margin::symmetric(0.0, 4.0))
            .show(ui, |ui| {
                ui.horizontal(|ui| {
                    badge(ui, tag, bg, fg);
                    ui.colored_label(fg, text);
                });
            });
    }
}

/// Search text box. Returns `true` while it holds keyboard focus so the
/// shell can suppress single-key navigation, and grabs focus when the
/// shell saw `/` (`focus_search` is consumed by the caller).
pub fn search_box(ui: &mut egui::Ui, text: &mut String, hint: &str, grab_focus: bool) -> bool {
    let mut has_focus = false;
    ui.horizontal(|ui| {
        let width = (ui.available_width() - 60.0).clamp(200.0, 460.0);
        let response = ui.add(
            egui::TextEdit::singleline(text)
                .hint_text(hint)
                .desired_width(width),
        );
        if response.changed() {
            tracing::debug!("[UI] search changed len={}", text.len());
        }
        if grab_focus {
            response.request_focus();
        }
        has_focus = response.has_focus();
        if !text.is_empty() && ui.button("Clear").clicked() {
            tracing::debug!("[UI] search cleared");
            text.clear();
        }
    });
    has_focus
}

#[cfg(test)]
mod tests {
    use super::*;

    fn now() -> DateTime<Utc> {
        parse_esi_date("2026-11-15T12:00:00Z").expect("fixed test date parses")
    }

    #[test]
    fn formats_isk_and_countdowns() {
        assert_eq!(format_isk(1_234_567.5), "1,234,567.50 ISK");
        assert_eq!(format_isk(-150.0), "-150.00 ISK");
        assert_eq!(format_isk(0.0), "0.00 ISK");
        assert_eq!(format_countdown(90_061), "1d 1h 1m");
        assert_eq!(format_countdown(0), "0m");
    }

    #[test]
    fn fitting_amount_formats_one_grouped_decimal() {
        assert_eq!(format_fitting_amount(0.0, "tf"), "0.0 tf");
        assert_eq!(format_fitting_amount(114.0, "tf"), "114.0 tf");
        // Fractional .5 CPU rows exist in the catalogue, so the
        // tenth is always rendered, never dropped.
        assert_eq!(format_fitting_amount(126.5, "tf"), "126.5 tf");
        assert_eq!(format_fitting_amount(1_234.5, "MW"), "1,234.5 MW");
        // Rounding can carry into a new thousands group.
        assert_eq!(format_fitting_amount(999.95, "tf"), "1,000.0 tf");
        assert_eq!(format_fitting_amount(-3.0, "tf"), "-3.0 tf");
        assert_eq!(format_fitting_amount(f64::NAN, "tf"), "0.0 tf");
        assert_eq!(format_fitting_amount(f64::INFINITY, "MW"), "0.0 MW");
        // Hostile remote quantities can push a finite total past
        // i64 range; formatting must never panic or print a sign
        // the value does not have (reviewer F1 reproduction).
        let huge = format_fitting_amount(30.0 * i64::MAX as f64, "tf");
        assert!(huge.ends_with(".0 tf"), "huge renders one decimal: {huge}");
        assert!(!huge.starts_with('-'), "positive stays positive: {huge}");
        let parsed: f64 = huge
            .trim_end_matches(" tf")
            .replace(',', "")
            .parse()
            .expect("grouped digits parse back");
        assert!(parsed > 9.0e18, "magnitude preserved: {parsed}");
        let huge_negative = format_fitting_amount(-30.0 * i64::MAX as f64, "MW");
        assert!(
            huge_negative.starts_with("-") && !huge_negative.starts_with("--"),
            "single sign: {huge_negative}"
        );
    }

    #[test]
    fn fitting_percent_formats_one_grouped_decimal_without_space() {
        assert_eq!(format_fitting_percent(0.0), "0.0%");
        assert_eq!(format_fitting_percent(33.0), "33.0%");
        assert_eq!(format_fitting_percent(67.5), "67.5%");
        // Rounding pins (ship resistances design section 5): the
        // catalogue keeps the exact value, the string rounds.
        assert_eq!(format_fitting_percent(43.125), "43.1%");
        assert_eq!(format_fitting_percent(43.75), "43.8%");
        assert_eq!(format_fitting_percent(79.375), "79.4%");
        assert_eq!(format_fitting_percent(100.0), "100.0%");
        assert_eq!(format_fitting_percent(-10.0), "-10.0%");
        assert_eq!(format_fitting_percent(-600.0), "-600.0%");
        // Inherited guards: grouping, huge magnitude, non-finite
        // fallback (reachable only synthetically, section 5).
        assert_eq!(format_fitting_percent(1_234.5), "1,234.5%");
        let huge = format_fitting_percent(30.0 * i64::MAX as f64);
        assert!(huge.ends_with(".0%"), "huge renders one decimal: {huge}");
        assert!(!huge.starts_with('-'), "positive stays positive: {huge}");
        let parsed: f64 = huge
            .trim_end_matches('%')
            .replace(',', "")
            .parse()
            .expect("grouped digits parse back");
        assert!(parsed > 9.0e18, "magnitude preserved: {parsed}");
        assert_eq!(format_fitting_percent(f64::NAN), "0.0%");
        assert_eq!(format_fitting_percent(f64::INFINITY), "0.0%");
    }

    #[test]
    fn isk_rollover_signed_and_non_finite() {
        assert_eq!(format_isk(999.999), "1,000.00 ISK");
        // Same huge-magnitude guard as the fitting formatter.
        let huge_isk = format_isk(30.0 * i64::MAX as f64);
        assert!(
            huge_isk.ends_with(".00 ISK"),
            "huge ISK renders: {huge_isk}"
        );
        assert!(!huge_isk.starts_with('-'));
        assert_eq!(format_isk(f64::NAN), "0.00 ISK");
        assert_eq!(format_isk(f64::INFINITY), "0.00 ISK");
        assert_eq!(format_isk_signed(10.0), "+10.00 ISK");
        assert_eq!(format_isk_signed(-10.0), "-10.00 ISK");
        assert_eq!(format_sp(5_200_000), "5,200,000 SP");
        assert_eq!(format_sp(-1_000), "-1,000 SP");
    }

    #[test]
    fn countdowns_and_progress_are_total() {
        assert_eq!(format_countdown(59), "59s");
        assert_eq!(format_countdown(-5), "0m");
        assert_eq!(
            countdown_label(Some("2026-11-20T12:00:00Z"), now()),
            "in 5d 0h 0m"
        );
        assert_eq!(
            countdown_label(Some("2026-11-10T12:00:00Z"), now()),
            "finished"
        );
        assert_eq!(countdown_label(None, now()), "paused");
        assert_eq!(countdown_label(Some("not-a-date"), now()), "unknown finish");
        assert_eq!(
            progress_fraction(
                Some("2026-11-10T12:00:00Z"),
                Some("2026-11-20T12:00:00Z"),
                now()
            ),
            0.5
        );
        assert_eq!(progress_fraction(None, None, now()), 0.0);
        assert_eq!(progress_fraction(Some("x"), Some("y"), now()), 0.0);
        assert_eq!(
            format_date_short("2026-11-14T10:00:00Z"),
            "2026-11-14 10:00"
        );
        // Unparseable remote date text never renders verbatim (probe
        // regression: a numeric or attacker-shaped pseudo-date must not
        // reach the screen as if it were a real date).
        assert_eq!(format_date_short("garbage"), "date unavailable");
        assert_eq!(format_date_short("700000001"), "date unavailable");
        assert_eq!(
            format_date_short("PWNED-REMOTE-STRING-123"),
            "date unavailable"
        );
    }

    #[test]
    fn search_match_is_case_insensitive() {
        assert!(matches_search("Small Hybrid Turret", "hybrid"));
        assert!(matches_search("Gunnery", ""));
        assert!(!matches_search("Gunnery", "mining"));
    }

    #[test]
    fn count_and_isk_color_helpers_work() {
        assert_eq!(format_count(0), "0");
        assert_eq!(format_count(150_000), "150,000");
        assert_eq!(format_count(-1234), "-1,234");
        assert_eq!(isk_color(10.0), theme::POSITIVE);
        assert_eq!(isk_color(-10.0), theme::NEGATIVE);
        assert_eq!(isk_color(0.0), theme::TEXT_PRIMARY);
        assert_eq!(isk_color(f64::NAN), theme::TEXT_PRIMARY);
    }
}
