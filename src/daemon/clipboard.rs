//! Pure clipboard classification for EFT fits, DNA links, and survey scans.
//!
//! The classifier never reads the OS clipboard; `arboard` polling is
//! deferred shell wiring. `Ignored` text is dropped in memory and is
//! never logged or persisted (only byte counts / variants are logged).

/// Recognized clipboard payloads. Payload strings are the recognized
/// paste itself (needed by a future import CTA); `Ignored` carries
/// nothing so unrecognized text cannot leak into storage or logs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClipboardKind {
    EftFit { ship: String, name: String },
    ShipDna,
    SurveyScan { rows: usize },
    Ignored,
}

impl ClipboardKind {
    pub fn variant_name(&self) -> &'static str {
        match self {
            Self::EftFit { .. } => "EftFit",
            Self::ShipDna => "ShipDna",
            Self::SurveyScan { .. } => "SurveyScan",
            Self::Ignored => "Ignored",
        }
    }
}

/// Hash-only dedupe key for clipboard text: the raw text is never
/// stored, logged, or persisted beyond the classify call.
pub fn clipboard_text_hash(text: &str) -> u64 {
    use std::hash::{Hash, Hasher};
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    text.hash(&mut hasher);
    hasher.finish()
}

/// Pure demo / opt-in guard for the deferred clipboard poller.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ClipboardGuard {
    pub demo: bool,
    pub clipboard_opt_in: bool,
}

impl ClipboardGuard {
    pub fn may_poll(self) -> bool {
        !self.demo && self.clipboard_opt_in
    }
}

/// Run one guarded clipboard read through `read` and classify it.
///
/// When the guard denies polling, `read` is never called (zero reads).
/// `Ignored` results collapse to `None`: dropped, never persisted.
/// A recognized kind is returned only as a typed value for a future
/// toast CTA; this function never mutates any active fit.
pub fn poll_clipboard_once(
    guard: ClipboardGuard,
    read: impl FnOnce() -> Option<String>,
) -> Option<ClipboardKind> {
    if !guard.may_poll() {
        tracing::debug!(
            "[DAEMON] clipboard poll skipped demo={} opt_in={}",
            guard.demo,
            guard.clipboard_opt_in
        );
        return None;
    }
    let text = read()?;
    match classify(&text) {
        ClipboardKind::Ignored => None,
        kind => Some(kind),
    }
}

fn is_positive_number(field: &str) -> bool {
    !field.is_empty()
        && field.len() <= 10
        && field.bytes().all(|b| b.is_ascii_digit())
        && !field.starts_with('0')
}

fn is_dna_body(body: &str) -> bool {
    let body = body.trim();
    if body.is_empty() || body.contains(['\n', '\r', '\t', ' ']) {
        return false;
    }
    let parts: Vec<&str> = body.split(':').collect();
    if parts.len() < 2 {
        return false;
    }
    // First field is the ship type number; trailing `::` is allowed.
    if !parts
        .first()
        .map(|f| is_positive_number(f))
        .unwrap_or(false)
    {
        return false;
    }
    let mut saw_segment = false;
    for part in &parts[1..] {
        if part.is_empty() {
            continue; // `::` terminator
        }
        saw_segment = true;
        let fields: Vec<&str> = part.split(';').collect();
        if fields.len() > 2 || !fields.iter().all(|f| is_positive_number(f)) {
            return false;
        }
    }
    saw_segment
}

fn classify_dna(text: &str) -> bool {
    let trimmed = text.trim();
    if let Some(rest) = trimmed.strip_prefix("fitting:") {
        return is_dna_body(rest);
    }
    is_dna_body(trimmed)
}

fn classify_survey(text: &str) -> Option<usize> {
    let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    if lines.is_empty() {
        return None;
    }
    for line in &lines {
        let cols: Vec<&str> = line.split('\t').collect();
        if cols.len() < 3 {
            return None;
        }
        if cols[0].trim().is_empty() || cols[0].trim().chars().all(|c| c.is_ascii_digit()) {
            return None;
        }
        // At least one later column must be numeric (quantity / volume /
        // distance), allowing thousands separators and decimals.
        let has_number = cols[1..].iter().any(|col| {
            let cleaned: String = col
                .trim()
                .trim_end_matches(['m', '³', 'k'])
                .replace([',', ' '], "");
            !cleaned.is_empty()
                && cleaned.chars().all(|c| c.is_ascii_digit() || c == '.')
                && cleaned.chars().any(|c| c.is_ascii_digit())
        });
        if !has_number {
            return None;
        }
    }
    Some(lines.len())
}

/// Classify one clipboard string in memory. No OS access, no logging
/// of the text itself.
pub fn classify(text: &str) -> ClipboardKind {
    let trimmed = text.trim();
    let kind = classify_inner(trimmed);
    tracing::debug!(
        "[DAEMON] clipboard classify variant={} bytes={}",
        kind.variant_name(),
        text.len()
    );
    kind
}

fn classify_inner(trimmed: &str) -> ClipboardKind {
    if trimmed.is_empty() {
        return ClipboardKind::Ignored;
    }
    // EFT: first non-empty line is `[Ship, Fit Name]`.
    if let Some(first) = trimmed.lines().next() {
        let first = first.trim();
        if first.starts_with('[') && first.ends_with(']') && first.len() > 2 {
            let inner = &first[1..first.len() - 1];
            if let Some((ship, name)) = inner.split_once(',') {
                let ship = ship.trim();
                let name = name.trim();
                if !ship.is_empty()
                    && !name.is_empty()
                    && !ship.contains(['[', ']'])
                    && !name.contains(['[', ']'])
                {
                    return ClipboardKind::EftFit {
                        ship: ship.to_string(),
                        name: name.to_string(),
                    };
                }
            }
            // Any other bracketed single header is not a survey/DNA paste.
            if !first.contains(',') {
                // Fall through: `[Empty Low slot]` etc. end up Ignored
                // unless a later rule matches (they do not).
            }
        }
    }
    if classify_dna(trimmed) {
        return ClipboardKind::ShipDna;
    }
    if trimmed.contains('\t') {
        if let Some(rows) = classify_survey(trimmed) {
            return ClipboardKind::SurveyScan { rows };
        }
    }
    ClipboardKind::Ignored
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classifies_twelve_plus_fixtures_with_full_precision() {
        let eft = "[Rifter, Brawl]\n200mm AutoCannon I\n[Empty Low slot]\n";
        let cases: Vec<(&str, ClipboardKind)> = vec![
            (
                eft,
                ClipboardKind::EftFit {
                    ship: "Rifter".into(),
                    name: "Brawl".into(),
                },
            ),
            (
                "[Vexor, Drone Boat]\n",
                ClipboardKind::EftFit {
                    ship: "Vexor".into(),
                    name: "Drone Boat".into(),
                },
            ),
            ("fitting:587:11577;1:25861;1::", ClipboardKind::ShipDna),
            ("587:11577;1:25861;1::", ClipboardKind::ShipDna),
            ("fitting:670:11577;2::", ClipboardKind::ShipDna),
            (
                "Veldspar\t10000\t1000 m3\t5 km\nScordite\t5000\t750 m3\t7 km\n",
                ClipboardKind::SurveyScan { rows: 2 },
            ),
            (
                "Pyroxeres\t12,345\t1,234.5 m3\t10 km",
                ClipboardKind::SurveyScan { rows: 1 },
            ),
            // Negatives: all Ignored.
            ("hello world, just chatting", ClipboardKind::Ignored),
            ("[Empty Low slot]", ClipboardKind::Ignored),
            ("[Rifter]", ClipboardKind::Ignored),
            ("[Rifter, ]", ClipboardKind::Ignored),
            ("https://example.com/fit/587:11577", ClipboardKind::Ignored),
            ("fitting:abc:11577::", ClipboardKind::Ignored),
            ("587:notanumber::", ClipboardKind::Ignored),
            ("Veldspar,10000,1000", ClipboardKind::Ignored),
            ("12:30:45 timestamp text", ClipboardKind::Ignored),
            ("", ClipboardKind::Ignored),
            ("{\"fit\": 587}", ClipboardKind::Ignored),
            ("name\tvalue\nfoo\tbar", ClipboardKind::Ignored),
        ];
        assert!(cases.len() >= 12);
        for (input, expected) in cases {
            assert_eq!(classify(input), expected, "input variant mismatch");
        }
    }

    #[test]
    fn survey_requires_tab_and_numeric_columns() {
        assert_eq!(classify("a,b,c\n1,2,3"), ClipboardKind::Ignored);
        assert!(matches!(
            classify("Veldspar\t100\t10 m3\t1 km"),
            ClipboardKind::SurveyScan { rows: 1 }
        ));
    }

    #[test]
    fn eft_empty_slot_marker_is_not_a_fit() {
        assert_eq!(classify("[Empty High slot]\n"), ClipboardKind::Ignored);
    }
}
