//! Shared panels and formatting. Display strings use resolved EVE names,
//! never raw numeric IDs.

/// Format an ISK amount with thousands separators and two decimals.
pub fn format_isk(amount: f64) -> String {
    let sign = if amount < 0.0 { "-" } else { "" };
    let abs = amount.abs();
    let whole = abs.floor() as i64;
    let frac = ((abs - whole as f64) * 100.0).round() as i64;
    let digits = whole.to_string();
    let mut grouped = String::new();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i) % 3 == 0 {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    format!("{sign}{grouped}.{frac:02} ISK")
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
    } else {
        format!("{minutes}m")
    }
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
    ui.colored_label(egui::Color32::LIGHT_RED, message);
    if ui.button("Retry").clicked() {
        tracing::info!("[UI] retry clicked (stub)");
    }
}

pub fn no_character_panel(ui: &mut egui::Ui) {
    ui.heading("No character selected");
    ui.label("Add a character with EVE SSO, or try the offline demo.");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_isk_and_countdowns() {
        assert_eq!(format_isk(1_234_567.5), "1,234,567.50 ISK");
        assert_eq!(format_isk(-150.0), "-150.00 ISK");
        assert_eq!(format_countdown(90_061), "1d 1h 1m");
        assert_eq!(format_countdown(0), "0m");
    }
}
