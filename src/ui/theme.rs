//! Alidade EVE-inspired space-slate dark theme applied once at startup.

use egui::{Color32, CornerRadius, FontId, Margin, Stroke, TextStyle};

pub const BG_CANVAS: Color32 = Color32::from_rgb(0x0D, 0x11, 0x17);
pub const BG_PANEL: Color32 = Color32::from_rgb(0x12, 0x18, 0x22);
pub const BG_CARD: Color32 = Color32::from_rgb(0x17, 0x1F, 0x2C);
pub const BG_CARD_ALT: Color32 = Color32::from_rgb(0x1C, 0x26, 0x36);
pub const BG_INPUT: Color32 = Color32::from_rgb(0x0A, 0x0E, 0x14);
pub const BG_FAINT: Color32 = Color32::from_rgb(0x15, 0x1D, 0x29);

pub const BORDER_SUBTLE: Color32 = Color32::from_rgb(0x25, 0x32, 0x45);
pub const BORDER_STRONG: Color32 = Color32::from_rgb(0x33, 0x41, 0x55);

pub const ACCENT_CYAN: Color32 = Color32::from_rgb(0x38, 0xBD, 0xF8);
pub const ACCENT_BLUE_FILL: Color32 = Color32::from_rgb(0x16, 0x4E, 0x63);

pub const TEXT_PRIMARY: Color32 = Color32::from_rgb(0xE6, 0xED, 0xF3);
pub const TEXT_SECONDARY: Color32 = Color32::from_rgb(0x8B, 0x9B, 0xB4);
pub const TEXT_MUTED: Color32 = Color32::from_rgb(0x64, 0x74, 0x8B);

pub const POSITIVE: Color32 = Color32::from_rgb(0x34, 0xD3, 0x99);
pub const POSITIVE_BG: Color32 = Color32::from_rgb(0x0E, 0x2A, 0x22);
pub const NEGATIVE: Color32 = Color32::from_rgb(0xF8, 0x71, 0x71);
pub const NEGATIVE_BG: Color32 = Color32::from_rgb(0x33, 0x14, 0x18);
pub const WARNING: Color32 = Color32::from_rgb(0xF5, 0x9E, 0x0B);
pub const WARNING_BG: Color32 = Color32::from_rgb(0x2B, 0x21, 0x11);

/// Left inset (points) clearing the macOS traffic-light buttons
/// when the content view extends under a hidden titlebar; zero on
/// other platforms where native chrome keeps its own controls.
#[cfg(target_os = "macos")]
pub fn traffic_light_inset() -> f32 {
    78.0
}

/// Left inset (points) clearing the macOS traffic-light buttons;
/// zero off macOS.
#[cfg(not(target_os = "macos"))]
pub fn traffic_light_inset() -> f32 {
    0.0
}

/// Configure Alidade's EVE dark theme, spacing, and type scale on the egui context.
pub fn apply(ctx: &egui::Context) {
    let mut visuals = egui::Visuals::dark();
    visuals.dark_mode = true;
    visuals.override_text_color = Some(TEXT_PRIMARY);
    visuals.panel_fill = BG_CANVAS;
    visuals.window_fill = BG_PANEL;
    visuals.extreme_bg_color = BG_INPUT;
    visuals.faint_bg_color = BG_FAINT;
    visuals.code_bg_color = BG_INPUT;
    visuals.warn_fg_color = WARNING;
    visuals.error_fg_color = NEGATIVE;
    visuals.hyperlink_color = ACCENT_CYAN;

    visuals.selection.bg_fill = ACCENT_BLUE_FILL;
    visuals.selection.stroke = Stroke::new(1.0_f32, ACCENT_CYAN);

    let radius = CornerRadius::same(6);
    visuals.window_corner_radius = CornerRadius::same(8);
    visuals.window_stroke = Stroke::new(1.0_f32, BORDER_STRONG);

    visuals.widgets.noninteractive.bg_fill = BG_CARD;
    visuals.widgets.noninteractive.weak_bg_fill = BG_PANEL;
    visuals.widgets.noninteractive.bg_stroke = Stroke::new(1.0_f32, BORDER_SUBTLE);
    visuals.widgets.noninteractive.fg_stroke = Stroke::new(1.0_f32, TEXT_PRIMARY);
    visuals.widgets.noninteractive.corner_radius = radius;

    visuals.widgets.inactive.bg_fill = BG_CARD_ALT;
    visuals.widgets.inactive.weak_bg_fill = BG_CARD;
    visuals.widgets.inactive.bg_stroke = Stroke::new(1.0_f32, BORDER_STRONG);
    visuals.widgets.inactive.fg_stroke = Stroke::new(1.0_f32, TEXT_PRIMARY);
    visuals.widgets.inactive.corner_radius = radius;

    visuals.widgets.hovered.bg_fill = Color32::from_rgb(0x22, 0x30, 0x44);
    visuals.widgets.hovered.weak_bg_fill = Color32::from_rgb(0x22, 0x30, 0x44);
    visuals.widgets.hovered.bg_stroke = Stroke::new(1.0_f32, ACCENT_CYAN);
    visuals.widgets.hovered.fg_stroke = Stroke::new(1.5_f32, TEXT_PRIMARY);
    visuals.widgets.hovered.corner_radius = radius;

    visuals.widgets.active.bg_fill = ACCENT_BLUE_FILL;
    visuals.widgets.active.weak_bg_fill = ACCENT_BLUE_FILL;
    visuals.widgets.active.bg_stroke = Stroke::new(1.0_f32, ACCENT_CYAN);
    visuals.widgets.active.fg_stroke = Stroke::new(1.5_f32, TEXT_PRIMARY);
    visuals.widgets.active.corner_radius = radius;

    visuals.widgets.open.bg_fill = BG_CARD_ALT;
    visuals.widgets.open.weak_bg_fill = BG_CARD;
    visuals.widgets.open.bg_stroke = Stroke::new(1.0_f32, BORDER_STRONG);
    visuals.widgets.open.fg_stroke = Stroke::new(1.0_f32, TEXT_PRIMARY);
    visuals.widgets.open.corner_radius = radius;

    ctx.set_visuals(visuals);

    let mut style = (*ctx.global_style()).clone();
    style.spacing.item_spacing = egui::vec2(8.0, 6.0);
    style.spacing.button_padding = egui::vec2(10.0, 5.0);
    style.spacing.interact_size.y = 26.0;
    style.spacing.window_margin = Margin::same(12);
    style
        .text_styles
        .insert(TextStyle::Heading, FontId::proportional(19.0));
    style
        .text_styles
        .insert(TextStyle::Body, FontId::proportional(14.0));
    style
        .text_styles
        .insert(TextStyle::Button, FontId::proportional(13.5));
    style
        .text_styles
        .insert(TextStyle::Monospace, FontId::monospace(13.0));
    style
        .text_styles
        .insert(TextStyle::Small, FontId::proportional(11.5));
    ctx.set_global_style(style);

    tracing::debug!("[UI] applied Alidade EVE dark theme");
}
