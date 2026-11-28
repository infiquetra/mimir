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

pub fn parse_localized_number(field: &str) -> Option<f64> {
    let mut cleaned = field.trim().to_string();
    for suffix in ["m³", "m3", "km", "m"] {
        if let Some(rest) = cleaned.strip_suffix(suffix) {
            cleaned = rest.trim().to_string();
            break;
        }
    }
    let cleaned: String = cleaned.replace([',', ' ', '\u{a0}'], "");
    if cleaned.is_empty() || !cleaned.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }
    cleaned.parse::<f64>().ok().filter(|v| v.is_finite())
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
    pub priced_rows: usize,
    pub unpriced_rows: usize,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct SurveyParse {
    pub rows: Vec<SurveyRow>,
    pub skipped_rows: usize,
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
            priced_rows: priced,
            unpriced_rows: unpriced,
        }
    }
}

/// Parse a tab-separated Survey Scanner paste, with or without a
/// localized header row. Malformed rows are skipped and counted.
pub fn parse_survey_scan(text: &str) -> SurveyParse {
    let mut rows = Vec::new();
    let mut skipped = 0usize;
    let lines: Vec<&str> = text.lines().filter(|l| !l.trim().is_empty()).collect();
    let mut col_map: Option<(usize, usize, usize, usize)> = None; // name, qty, vol, dist
    let mut start = 0usize;
    if let Some(first) = lines.first() {
        let cells: Vec<&str> = first.split('\t').collect();
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
        let (Some(qty), Some(vol)) = (
            parse_localized_number(cells[qi]),
            parse_localized_number(cells[vi]),
        ) else {
            skipped += 1;
            continue;
        };
        let distance = parse_localized_number(cells[di]).unwrap_or(0.0);
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
}
