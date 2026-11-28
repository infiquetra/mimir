//! Localized Survey Scanner clipboard parser and belt valuation.
//! Pure functions only: clipboard text is parsed in memory and never
//! logged beyond row counts.

use std::collections::HashMap;

const QUANTITY_HEADERS: &[&str] = &[
    "quantity",
    "menge",
    "quantité",
    "quantite",
    "количество",
    "数量",
    "cantidad",
    "수량",
    "quantidade",
    "量",
];
const VOLUME_HEADERS: &[&str] = &[
    "volume",
    "volumen",
    "объём",
    "объем",
    "体積",
    "体积",
    "부피",
    "volume (m3)",
];
const DISTANCE_HEADERS: &[&str] = &[
    "distance",
    "entfernung",
    "расстояние",
    "距離",
    "距离",
    "distancia",
    "distância",
    "거리",
];
const NAME_HEADERS: &[&str] = &[
    "asteroid",
    "asteroid type",
    "name",
    "ore",
    "тип",
    "名称",
    "이름",
];

fn is_header(cell: &str, set: &[&str]) -> bool {
    let c = cell.trim().to_lowercase();
    set.iter().any(|h| c == *h || c.starts_with(h))
}

fn find_header(cells: &[&str], set: &[&str]) -> Option<usize> {
    cells.iter().position(|c| is_header(c, set))
}

/// Locale inferred from the survey header language. Separators are
/// never guessed per-cell: German uses '.' grouping / ',' decimal,
/// English uses ',' grouping / '.' decimal.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum SurveyLocale {
    #[default]
    English,
    German,
    French,
    Russian,
    OtherCommaDecimal,
}

impl SurveyLocale {
    fn decimal(self) -> char {
        match self {
            Self::English => '.',
            _ => ',',
        }
    }
    fn grouping(self) -> char {
        match self {
            Self::German => '.',
            Self::English => ',',
            _ => ' ',
        }
    }
}

fn detect_locale(cells: &[&str]) -> SurveyLocale {
    let joined = cells
        .iter()
        .map(|c| c.trim().to_lowercase())
        .collect::<Vec<_>>()
        .join("\t");
    if joined.contains("menge") || joined.contains("volumen") || joined.contains("entfernung") {
        return SurveyLocale::German;
    }
    if joined.contains("quantité") || joined.contains("quantite") {
        return SurveyLocale::French;
    }
    if joined.contains("количество") || joined.contains("объём") || joined.contains("объем")
    {
        return SurveyLocale::Russian;
    }
    if joined.contains("cantidad") || joined.contains("quantidade") {
        return SurveyLocale::OtherCommaDecimal;
    }
    SurveyLocale::English
}

pub fn parse_localized_number(field: &str) -> Option<f64> {
    parse_localized_number_for(field, SurveyLocale::English).map(|(v, _)| v)
}

/// Parse a number in `locale`, returning (value, unit suffix if any).
pub fn parse_localized_number_for(
    field: &str,
    locale: SurveyLocale,
) -> Option<(f64, Option<String>)> {
    let mut cleaned = field.trim().to_string();
    let mut unit = None;
    for suffix in ["m³", "m3", "km", "m"] {
        if let Some(rest) = cleaned.strip_suffix(suffix) {
            unit = Some(suffix.to_string());
            cleaned = rest.trim().to_string();
            break;
        }
    }
    if cleaned.is_empty() || !cleaned.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }
    let decimal = locale.decimal();
    let grouping = locale.grouping();
    let mut normalized = String::new();
    for c in cleaned.chars() {
        if c == grouping || c == ' ' || c == '\u{a0}' {
            continue;
        }
        if c == decimal {
            normalized.push('.');
        } else {
            normalized.push(c);
        }
    }
    // English grouping commas already removed above; a stray comma in
    // comma-decimal locales is the decimal handled there.
    normalized
        .parse::<f64>()
        .ok()
        .filter(|v| v.is_finite())
        .map(|v| (v, unit))
}

/// Convert a parsed distance to kilometres: metre values divide by 1000.
pub fn distance_to_km(value: f64, unit: Option<&str>) -> f64 {
    match unit {
        Some("m") => value / 1000.0,
        _ => value,
    }
}

/// One parsed survey row. `ore_name` is the pasted resolved name.
#[derive(Debug, Clone, PartialEq)]
pub struct SurveyRow {
    pub ore_name: String,
    pub quantity: i64,
    pub volume_m3: f64,
    pub distance_km: f64,
}

impl SurveyRow {
    pub fn unit_volume_m3(&self) -> Option<f64> {
        if self.quantity > 0 {
            Some(self.volume_m3 / self.quantity as f64)
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct BeltValuation {
    /// `None` when any row lacks a hub price; never a fabricated zero.
    pub remaining_isk: Option<f64>,
    /// Subtotal over priced rows only (shown beside the badge when
    /// the belt is only partially priced).
    pub priced_isk: f64,
    pub priced_rows: usize,
    pub unpriced_rows: usize,
}

pub const MAX_SURVEY_PASTE_BYTES: usize = 512 * 1024;
pub const MAX_SURVEY_PASTE_ROWS: usize = 5_000;

#[derive(Debug, Clone, Default, PartialEq)]
pub struct SurveyParse {
    pub rows: Vec<SurveyRow>,
    pub skipped_rows: usize,
    /// Whole-paste rejection (oversize / too many rows); never partial.
    pub rejection: Option<String>,
}

/// Stable cache key for a survey paste (hash + length).
pub fn survey_text_cache_key(text: &str) -> (u64, usize) {
    use std::hash::{Hash, Hasher};
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    text.hash(&mut hasher);
    (hasher.finish(), text.len())
}

impl SurveyParse {
    pub fn total_quantity(&self) -> i64 {
        self.rows.iter().map(|r| r.quantity.max(0)).sum()
    }
    pub fn total_volume_m3(&self) -> f64 {
        self.rows.iter().map(|r| r.volume_m3.max(0.0)).sum()
    }
    /// Value the belt at per-unit hub prices keyed by resolved ore name.
    pub fn valuation(&self, price_per_unit: &HashMap<String, f64>) -> BeltValuation {
        let mut total = 0.0;
        let mut priced = 0usize;
        let mut unpriced = 0usize;
        for row in &self.rows {
            match price_per_unit.get(&row.ore_name).filter(|p| **p > 0.0) {
                Some(price) => {
                    priced += 1;
                    total += row.quantity.max(0) as f64 * price;
                }
                None => unpriced += 1,
            }
        }
        BeltValuation {
            remaining_isk: if unpriced == 0 && priced > 0 {
                Some(total)
            } else {
                None
            },
            priced_isk: total,
            priced_rows: priced,
            unpriced_rows: unpriced,
        }
    }
}

/// Parse a tab-separated Survey Scanner paste, with or without a
/// localized header row. Malformed rows are skipped and counted.
pub fn parse_survey_scan(text: &str) -> SurveyParse {
    if text.len() > MAX_SURVEY_PASTE_BYTES {
        tracing::warn!("[MINING] survey paste rejected bytes={}", text.len());
        return SurveyParse {
            rejection: Some(format!(
                "Survey paste too large (max {MAX_SURVEY_PASTE_BYTES} bytes)"
            )),
            ..Default::default()
        };
    }
    let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    if lines.len() > MAX_SURVEY_PASTE_ROWS {
        tracing::warn!("[MINING] survey paste rejected rows={}", lines.len());
        return SurveyParse {
            rejection: Some(format!(
                "Survey paste too many rows (max {MAX_SURVEY_PASTE_ROWS})"
            )),
            ..Default::default()
        };
    }
    let mut rows = Vec::new();
    let mut skipped = 0usize;
    let mut locale = SurveyLocale::English;
    let mut col_map: Option<(usize, usize, usize, usize)> = None; // name, qty, vol, dist
    let mut start = 0usize;
    if let Some(first) = lines.first() {
        let cells: Vec<&str> = first.split('\t').collect();
        locale = detect_locale(&cells);
        if find_header(&cells, QUANTITY_HEADERS).is_some()
            || find_header(&cells, VOLUME_HEADERS).is_some()
            || find_header(&cells, DISTANCE_HEADERS).is_some()
            || find_header(&cells, NAME_HEADERS).is_some()
        {
            col_map = Some((
                find_header(&cells, NAME_HEADERS).unwrap_or(0),
                find_header(&cells, QUANTITY_HEADERS).unwrap_or(1),
                find_header(&cells, VOLUME_HEADERS).unwrap_or(2),
                find_header(&cells, DISTANCE_HEADERS).unwrap_or(3),
            ));
            start = 1;
        }
    }
    for line in &lines[start..] {
        let cells: Vec<&str> = line.split('\t').collect();
        let (ni, qi, vi, di) = col_map.unwrap_or((0, 1, 2, 3));
        let max_idx = ni.max(qi).max(vi).max(di);
        if cells.len() <= max_idx {
            skipped += 1;
            continue;
        }
        let ore_name = cells[ni].trim().to_string();
        let (Some((qty, _)), Some((vol, _))) = (
            parse_localized_number_for(cells[qi], locale),
            parse_localized_number_for(cells[vi], locale),
        ) else {
            skipped += 1;
            continue;
        };
        let distance = parse_localized_number_for(cells[di], locale)
            .map(|(v, unit)| distance_to_km(v, unit.as_deref()))
            .unwrap_or(0.0);
        if ore_name.is_empty() || qty < 0.0 {
            skipped += 1;
            continue;
        }
        rows.push(SurveyRow {
            ore_name,
            quantity: qty as i64,
            volume_m3: vol,
            distance_km: distance,
        });
    }
    tracing::debug!(
        "[MINING] survey parse rows={} skipped={}",
        rows.len(),
        skipped
    );
    SurveyParse {
        rows,
        skipped_rows: skipped,
        rejection: None,
    }
}

/// Crystal profile for Type A / Type B comparison.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CrystalProfile {
    pub yield_m3_per_hour: f64,
    pub residue_ratio: f64,
}

impl CrystalProfile {
    pub fn kept_m3_per_hour(&self) -> f64 {
        self.yield_m3_per_hour.max(0.0) * (1.0 - self.residue_ratio.clamp(0.0, 1.0))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CrystalChoice {
    TypeA,
    TypeB,
}

impl CrystalChoice {
    pub fn label(&self) -> &'static str {
        match self {
            Self::TypeA => "Type A (preserve value)",
            Self::TypeB => "Type B (max ISK/hr)",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CrystalComparison {
    pub type_a_kept_m3_per_hour: f64,
    pub type_b_kept_m3_per_hour: f64,
    pub type_a_isk_per_hour: Option<f64>,
    pub type_b_isk_per_hour: Option<f64>,
    pub recommended: CrystalChoice,
}

/// Compare Type A (preserve value) against Type B (max ISK/hr).
/// Recommendation follows kept volume per hour; ties preserve value.
pub fn crystal_comparison(
    type_a: CrystalProfile,
    type_b: CrystalProfile,
    price_per_m3: Option<f64>,
) -> CrystalComparison {
    let a_kept = type_a.kept_m3_per_hour();
    let b_kept = type_b.kept_m3_per_hour();
    let price = price_per_m3.filter(|p| *p > 0.0);
    CrystalComparison {
        type_a_kept_m3_per_hour: a_kept,
        type_b_kept_m3_per_hour: b_kept,
        type_a_isk_per_hour: price.map(|p| a_kept * p),
        type_b_isk_per_hour: price.map(|p| b_kept * p),
        recommended: if b_kept > a_kept {
            CrystalChoice::TypeB
        } else {
            CrystalChoice::TypeA
        },
    }
}

/// Value recoverable from a finite belt after residue loss.
pub fn recoverable_belt_isk(belt_isk: f64, residue: f64) -> f64 {
    belt_isk.max(0.0) * (1.0 - residue.clamp(0.0, 1.0))
}

/// Dogma attribute carrying a mining crystal's residue percentage and
/// its relative yield factor in the bundled SDE (Type A I: 0 / 1.0,
/// Type B I: 20 / 0.9, Type B II: 30 / 0.8 for Simple crystals).
pub const CRYSTAL_RESIDUE_PERCENT_ATTRIBUTE_ID: i64 = 3160;
pub const CRYSTAL_YIELD_FACTOR_ATTRIBUTE_ID: i64 = 3161;

/// Derive one crystal profile from Dogma attributes scaled by an
/// observed base yield rate. `None` when either attribute is absent.
pub fn crystal_profile_from_dogma(
    dogma: &crate::fitting::dogma_catalogue::DogmaCatalogue,
    crystal_type_id: i64,
    base_yield_m3_per_hour: f64,
) -> Option<CrystalProfile> {
    let residue_percent = dogma.attribute(crystal_type_id, CRYSTAL_RESIDUE_PERCENT_ATTRIBUTE_ID)?;
    let yield_factor = dogma.attribute(crystal_type_id, CRYSTAL_YIELD_FACTOR_ATTRIBUTE_ID)?;
    if base_yield_m3_per_hour <= 0.0 {
        return None;
    }
    Some(CrystalProfile {
        yield_m3_per_hour: base_yield_m3_per_hour * yield_factor.max(0.0),
        residue_ratio: (residue_percent / 100.0).clamp(0.0, 1.0),
    })
}

/// Finite-belt comparison: on a finite belt the recoverable volume
/// (belt * (1 - residue)) decides, not kept-per-hour alone.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FiniteBeltComparison {
    pub comparison: CrystalComparison,
    pub type_a_recoverable_m3: f64,
    pub type_b_recoverable_m3: f64,
    pub type_a_hours: Option<f64>,
    pub type_b_hours: Option<f64>,
}

pub fn finite_belt_comparison(
    type_a: CrystalProfile,
    type_b: CrystalProfile,
    belt_volume_m3: f64,
    price_per_m3: Option<f64>,
) -> FiniteBeltComparison {
    let belt = belt_volume_m3.max(0.0);
    let a_rec = belt * (1.0 - type_a.residue_ratio.clamp(0.0, 1.0));
    let b_rec = belt * (1.0 - type_b.residue_ratio.clamp(0.0, 1.0));
    let price = price_per_m3.filter(|p| *p > 0.0);
    let a_value = price.map(|p| a_rec * p).unwrap_or(a_rec);
    let b_value = price.map(|p| b_rec * p).unwrap_or(b_rec);
    let mut comparison = crystal_comparison(type_a, type_b, price);
    comparison.recommended = if b_value > a_value {
        CrystalChoice::TypeB
    } else {
        CrystalChoice::TypeA
    };
    FiniteBeltComparison {
        comparison,
        type_a_recoverable_m3: a_rec,
        type_b_recoverable_m3: b_rec,
        type_a_hours: if type_a.yield_m3_per_hour > 0.0 {
            Some(belt / type_a.yield_m3_per_hour)
        } else {
            None
        },
        type_b_hours: if type_b.yield_m3_per_hour > 0.0 {
            Some(belt / type_b.yield_m3_per_hour)
        } else {
            None
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn prices() -> HashMap<String, f64> {
        HashMap::from([
            ("Veldspar".to_string(), 10.0),
            ("Scordite".to_string(), 20.0),
        ])
    }

    #[test]
    fn localized_headers_en_de_fr_ru() {
        for text in [
            "Asteroid\tQuantity\tVolume\tDistance\nVeldspar\t1,000\t100 m3\t5 km\n",
            "Asteroid\tMenge\tVolumen\tEntfernung\nVeldspar\t1000\t100 m3\t5 km\n",
            "Asteroid\tQuantité\tVolume\tDistance\nVeldspar\t1000\t100\t5\n",
            "Asteroid\tКоличество\tОбъём\tРасстояние\nVeldspar\t1000\t100\t5\n",
            "Veldspar\t1000\t100 m3\t5 km\nScordite\t500\t75 m3\t7 km\n",
        ] {
            let parsed = parse_survey_scan(text);
            assert_eq!(
                parsed.rows.len(),
                if text.contains("Scordite\t500") { 2 } else { 1 },
                "text: {text:?}"
            );
            assert_eq!(parsed.rows[0].ore_name, "Veldspar");
            assert_eq!(parsed.rows[0].quantity, 1000);
            assert_eq!(parsed.rows[0].volume_m3, 100.0);
        }
    }

    #[test]
    fn malformed_rows_skipped_and_counted() {
        let parsed = parse_survey_scan(
            "Veldspar\t100\t10 m3\t1 km\nBadRow\nScordite\tabc\t10\t1\n\t100\t10\t1\n",
        );
        assert_eq!(parsed.rows.len(), 1);
        assert_eq!(parsed.skipped_rows, 3);
        assert_eq!(parse_survey_scan("").rows.len(), 0);
    }

    #[test]
    fn belt_valuation_and_unpriced() {
        let parsed =
            parse_survey_scan("Veldspar\t1000\t100 m3\t5 km\nScordite\t500\t75 m3\t7 km\n");
        let v = parsed.valuation(&prices());
        assert_eq!(v.remaining_isk, Some(1000.0 * 10.0 + 500.0 * 20.0));
        assert_eq!(parsed.total_volume_m3(), 175.0);
        let partial = parsed.valuation(&HashMap::from([("Veldspar".to_string(), 10.0)]));
        assert_eq!(partial.remaining_isk, None);
        assert_eq!(partial.unpriced_rows, 1);
    }

    #[test]
    fn crystal_a_vs_b_choice() {
        let a = CrystalProfile {
            yield_m3_per_hour: 1000.0,
            residue_ratio: 0.0,
        };
        let b = CrystalProfile {
            yield_m3_per_hour: 1200.0,
            residue_ratio: 0.30,
        };
        let cmp = crystal_comparison(a, b, Some(100.0));
        assert_eq!(cmp.type_a_kept_m3_per_hour, 1000.0);
        assert!((cmp.type_b_kept_m3_per_hour - 840.0).abs() < 1e-9);
        assert_eq!(cmp.recommended, CrystalChoice::TypeA);
        let fast_b = CrystalProfile {
            yield_m3_per_hour: 2000.0,
            residue_ratio: 0.30,
        };
        assert_eq!(
            crystal_comparison(a, fast_b, None).recommended,
            CrystalChoice::TypeB
        );
        assert_eq!(recoverable_belt_isk(1000.0, 0.25), 750.0);
    }

    #[test]
    fn localized_numbers_follow_header_locale() {
        assert_eq!(
            parse_localized_number_for("1.000", SurveyLocale::German).map(|(v, _)| v),
            Some(1000.0)
        );
        assert_eq!(
            parse_localized_number_for("100,5", SurveyLocale::German).map(|(v, _)| v),
            Some(100.5)
        );
        assert_eq!(
            parse_localized_number_for("1,234", SurveyLocale::English).map(|(v, _)| v),
            Some(1234.0)
        );
        let (dist, unit) =
            parse_localized_number_for("1,234 m", SurveyLocale::English).expect("distance");
        assert_eq!(distance_to_km(dist, unit.as_deref()), 1.234);
        // German header threads locale into every column.
        let parsed = parse_survey_scan(
            "Asteroid\tMenge\tVolumen\tEntfernung\nVeldspar\t1.000\t100,5 m3\t1.234 m\n",
        );
        assert_eq!(parsed.rows.len(), 1);
        assert_eq!(parsed.rows[0].quantity, 1000);
        assert_eq!(parsed.rows[0].volume_m3, 100.5);
        assert_eq!(parsed.rows[0].distance_km, 1.234);
    }

    #[test]
    fn survey_paste_caps_reject_whole() {
        assert!(parse_survey_scan(&"x".repeat(MAX_SURVEY_PASTE_BYTES + 1))
            .rejection
            .is_some());
        let many = (0..=MAX_SURVEY_PASTE_ROWS)
            .map(|_| "Veldspar\t1\t1\t1")
            .collect::<Vec<_>>()
            .join("\n");
        assert!(parse_survey_scan(&many).rejection.is_some());
    }

    #[test]
    fn finite_belt_prefers_preserved_value() {
        let a = CrystalProfile {
            yield_m3_per_hour: 1000.0,
            residue_ratio: 0.0,
        };
        let b = CrystalProfile {
            yield_m3_per_hour: 2000.0,
            residue_ratio: 0.30,
        };
        let cmp = finite_belt_comparison(a, b, 10_000.0, Some(100.0));
        assert_eq!(cmp.type_a_recoverable_m3, 10_000.0);
        assert_eq!(cmp.type_b_recoverable_m3, 7_000.0);
        assert_eq!(cmp.comparison.recommended, CrystalChoice::TypeA);
        assert_eq!(cmp.type_b_hours, Some(5.0));
    }

    #[test]
    fn crystal_profiles_from_bundled_dogma() {
        let dogma = crate::fitting::dogma_catalogue::DogmaCatalogue::load_bundled().expect("dogma");
        // Simple Asteroid Mining Crystal Type A I (60276) / Type B I (60279).
        let a = crystal_profile_from_dogma(&dogma, 60276, 1000.0).expect("type A");
        let b = crystal_profile_from_dogma(&dogma, 60279, 1000.0).expect("type B");
        assert_eq!(a.residue_ratio, 0.0);
        assert_eq!(b.residue_ratio, 0.20);
        assert_eq!(b.yield_m3_per_hour, 900.0);
        assert!(crystal_profile_from_dogma(&dogma, 587, 1000.0).is_none());
    }
}
