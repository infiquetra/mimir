//! Shared panels and formatting. Display strings use resolved EVE names,
//! never raw numeric IDs. Every formatter is total: malformed dates and
//! non-finite amounts render a placeholder instead of panicking.

use chrono::{DateTime, Utc};

/// Format an ISK amount with thousands separators and two decimals.
pub fn format_isk(amount: f64) -> String {
    if !amount.is_finite() {
        tracing::warn!("[UI] format_isk non-finite amount");
        return "0.00 ISK".to_string();
    }
    let sign = if amount < 0.0 { "-" } else { "" };
    let abs = amount.abs();
    let mut whole = abs.floor() as i64;
    let mut frac = ((abs - whole as f64) * 100.0).round() as i64;
    if frac >= 100 {
        whole += 1;
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

pub fn error_panel(ui: &mut egui::Ui, message: &str) {
    let _ = error_panel_with_retry(ui, message);
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
    ui.label("Keys: 1-9 switch views, PageUp/PageDown switch character.");
}

/// Demo/offline notice shown at the top of data views.
pub fn mode_notice(ui: &mut egui::Ui, demo: bool, offline: bool) {
    if demo {
        ui.colored_label(
            egui::Color32::YELLOW,
            "Demo data: invented sample rows, no network or EVE account involved.",
        );
    } else if offline {
        ui.colored_label(
            egui::Color32::YELLOW,
            "Offline: showing cached data; it may be stale.",
        );
    }
}

/// Search text box. Returns `true` while it holds keyboard focus so the
/// shell can suppress single-key navigation, and grabs focus when the
/// shell saw `/` (`focus_search` is consumed by the caller).
pub fn search_box(ui: &mut egui::Ui, text: &mut String, hint: &str, grab_focus: bool) -> bool {
    let response = ui.text_edit_singleline(text);
    if response.changed() {
        tracing::debug!("[UI] search changed len={}", text.len());
    }
    if grab_focus {
        response.request_focus();
    }
    if text.is_empty() {
        ui.label(hint);
    }
    response.has_focus()
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
    fn isk_rollover_signed_and_non_finite() {
        assert_eq!(format_isk(999.999), "1,000.00 ISK");
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
}
