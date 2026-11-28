//! Pure mining ledger math: session yield/residue totals, compressed
//! conversions, hub valuation, and ore-hold countdowns.
//! No egui, network, or database work happens here.

use crate::daemon::{LogEvent, LogEventKind};
use crate::fitting::dogma_catalogue::DogmaCatalogue;

/// SDE dogma attribute for a dedicated mining hold.
pub const MINING_HOLD_ATTRIBUTE_ID: i64 = 1556;
/// SDE dogma attribute for a specialized ore hold.
pub const SPECIALIZED_ORE_HOLD_ATTRIBUTE_ID: i64 = 3272;

/// One observed mining yield sample. Names are resolved display names,
/// never raw type ids.
#[derive(Debug, Clone, PartialEq)]
pub struct MiningSample {
    pub ore_name: String,
    pub yield_m3: f64,
    pub residue_m3: f64,
}

/// Aggregated yield and residue for a session or fleet.
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct SessionTotals {
    pub yield_m3: f64,
    pub residue_m3: f64,
    pub samples: usize,
}

impl SessionTotals {
    pub fn total_m3(&self) -> f64 {
        self.yield_m3.max(0.0) + self.residue_m3.max(0.0)
    }
    pub fn residue_ratio(&self) -> f64 {
        residue_ratio(self.yield_m3, self.residue_m3)
    }
}

/// Exact residue share: `residue / max(yield + residue, 1e-9)`.
pub fn residue_ratio(yield_m3: f64, residue_m3: f64) -> f64 {
    let y = yield_m3.max(0.0);
    let r = residue_m3.max(0.0);
    r / (y + r).max(1e-9)
}

/// Rolling rate in cubic metres per hour; zero without elapsed time.
pub fn m3_per_hour(total_m3: f64, elapsed_secs: f64) -> f64 {
    if elapsed_secs <= 0.0 || total_m3 <= 0.0 {
        return 0.0;
    }
    total_m3 / elapsed_secs * 3600.0
}

/// ISK per hour for a valued total; zero without elapsed time.
pub fn isk_per_hour(total_isk: f64, elapsed_secs: f64) -> f64 {
    if elapsed_secs <= 0.0 || total_isk <= 0.0 {
        return 0.0;
    }
    total_isk / elapsed_secs * 3600.0
}

/// Compressed batches from a raw quantity and SDE `portionSize`
/// (for example 100 raw units become 1 compressed batch).
pub fn compressed_batches(quantity: i64, portion_size: i64) -> i64 {
    if quantity <= 0 || portion_size <= 0 {
        return 0;
    }
    quantity / portion_size
}

/// Raw units needed for one compressed batch.
pub fn compressed_portion_size(raw_portion_size: i64) -> i64 {
    if raw_portion_size <= 0 {
        1
    } else {
        raw_portion_size
    }
}

/// Hub valuation state. Absent prices are never shown as 0 ISK/hr.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum HubValuation {
    AwaitingHubQuote,
    Priced { isk_per_hour: f64, total_isk: f64 },
}

impl HubValuation {
    pub fn label(&self) -> &'static str {
        match self {
            Self::AwaitingHubQuote => "Awaiting Hub Quote",
            Self::Priced { .. } => "Hub Quote",
        }
    }
}

/// Value mined volume at an optional hub price per cubic metre.
pub fn hub_valuation(yield_m3: f64, elapsed_secs: f64, price_per_m3: Option<f64>) -> HubValuation {
    let Some(price) = price_per_m3.filter(|p| *p > 0.0) else {
        tracing::debug!("[MINING] hub valuation awaiting quote yield_m3={yield_m3:.2}");
        return HubValuation::AwaitingHubQuote;
    };
    let total_isk = yield_m3.max(0.0) * price;
    HubValuation::Priced {
        isk_per_hour: isk_per_hour(total_isk, elapsed_secs),
        total_isk,
    }
}

/// Ore-hold countdown state.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum HoldCountdown {
    CapacityUnknown,
    Known {
        capacity_m3: f64,
        fill_fraction: f64,
        remaining_secs: Option<f64>,
    },
}

impl HoldCountdown {
    pub fn label(&self) -> &'static str {
        match self {
            Self::CapacityUnknown => "Capacity Unknown",
            Self::Known { .. } => "Ore Hold",
        }
    }
}

/// Hold capacity from the two SDE hold attributes, mining hold first.
pub fn hold_capacity_m3(
    mining_hold: Option<f64>,
    specialized_ore_hold: Option<f64>,
) -> Option<f64> {
    mining_hold
        .filter(|v| *v > 0.0)
        .or_else(|| specialized_ore_hold.filter(|v| *v > 0.0))
}

/// Hold capacity for an observed ship type through the Dogma catalogue.
pub fn hold_capacity_for_ship(dogma: &DogmaCatalogue, ship_type_id: Option<i64>) -> Option<f64> {
    let ship_type_id = ship_type_id?;
    let capacity = hold_capacity_m3(
        dogma.attribute(ship_type_id, MINING_HOLD_ATTRIBUTE_ID),
        dogma.attribute(ship_type_id, SPECIALIZED_ORE_HOLD_ATTRIBUTE_ID),
    );
    tracing::debug!(
        "[MINING] hold capacity resolved known={}",
        capacity.is_some()
    );
    capacity
}

/// Countdown until the hold fills at the current yield rate.
pub fn hold_countdown(
    capacity_m3: Option<f64>,
    current_m3: f64,
    rate_m3_per_hour: f64,
) -> HoldCountdown {
    let Some(capacity) = capacity_m3.filter(|v| *v > 0.0) else {
        return HoldCountdown::CapacityUnknown;
    };
    let current = current_m3.clamp(0.0, capacity);
    let remaining_secs = if rate_m3_per_hour > 0.0 {
        Some(((capacity - current) / rate_m3_per_hour * 3600.0).max(0.0))
    } else {
        None
    };
    HoldCountdown::Known {
        capacity_m3: capacity,
        fill_fraction: current / capacity,
        remaining_secs,
    }
}

/// Per-character totals for multi-box fleet aggregation.
#[derive(Debug, Clone, PartialEq)]
pub struct CharacterMiningTotals {
    pub character_name: String,
    pub totals: SessionTotals,
}

/// Sum every character's session into one fleet total.
pub fn fleet_totals(characters: &[CharacterMiningTotals]) -> SessionTotals {
    let mut out = SessionTotals::default();
    for character in characters {
        out.yield_m3 += character.totals.yield_m3.max(0.0);
        out.residue_m3 += character.totals.residue_m3.max(0.0);
        out.samples += character.totals.samples;
    }
    tracing::debug!("[MINING] fleet totals characters={}", characters.len());
    out
}

/// One ESI mining ledger row after name resolution by the caller.
#[derive(Debug, Clone, PartialEq)]
pub struct LedgerRow {
    pub date: String,
    pub ore_name: String,
    pub quantity: i64,
    pub volume_m3: f64,
}

/// Merge ESI ledger volume into a live session total.
pub fn merged_yield_m3(session: &SessionTotals, ledger: &[LedgerRow]) -> f64 {
    let ledger_m3: f64 = ledger.iter().map(|r| r.volume_m3.max(0.0)).sum();
    session.yield_m3.max(0.0) + ledger_m3
}

fn extract_m3_near(body: &str, keyword: &str) -> Option<f64> {
    let lower = body.to_lowercase();
    let start = lower.find(keyword)?;
    let tail = &body[start + keyword.len()..];
    let mut chars = tail.chars().peekable();
    while let Some(c) = chars.peek().copied() {
        if c.is_ascii_digit() || c == '.' {
            break;
        }
        chars.next();
    }
    let mut text = String::new();
    for c in chars {
        if c.is_ascii_digit() || c == '.' || c == ',' {
            text.push(c);
        } else {
            break;
        }
    }
    text.replace(',', "").parse::<f64>().ok()
}

/// Parse one mining log body into a sample when it carries a yield
/// volume. Ore names come from a `:`-prefixed segment when present;
/// otherwise the caller-facing name is `Ore`.
pub fn parse_mining_log_body(body: &str) -> Option<MiningSample> {
    let yield_m3 = extract_m3_near(body, "yield")
        .or_else(|| extract_m3_near(body, "mined"))
        .or_else(|| extract_m3_near(body, "m3"))
        .or_else(|| extract_m3_near(body, "m³"))?;
    let residue_m3 = extract_m3_near(body, "residue")
        .or_else(|| extract_m3_near(body, "waste"))
        .unwrap_or(0.0);
    let ore_name = body
        .split(':')
        .nth(1)
        .map(|s| s.split_whitespace().take(2).collect::<Vec<_>>().join(" "))
        .filter(|s| !s.is_empty() && s.chars().any(|c| c.is_alphabetic()))
        .unwrap_or_else(|| "Ore".to_string());
    Some(MiningSample {
        ore_name,
        yield_m3,
        residue_m3,
    })
}

/// Derive session totals from the shell's recent-log-event ring.
/// Only mining-kind events count; unparseable bodies are ignored.
pub fn session_totals_from_log_events(events: &[LogEvent]) -> SessionTotals {
    let mut totals = SessionTotals::default();
    for event in events.iter().filter(|e| e.kind == LogEventKind::Mining) {
        if let Some(sample) = parse_mining_log_body(&event.body) {
            totals.yield_m3 += sample.yield_m3.max(0.0);
            totals.residue_m3 += sample.residue_m3.max(0.0);
            totals.samples += 1;
        }
    }
    tracing::debug!("[MINING] session totals samples={}", totals.samples);
    totals
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::daemon::{LogEvent, LogEventKind, LogSource};

    #[test]
    fn residue_ratio_exact_math() {
        assert_eq!(residue_ratio(90.0, 10.0), 0.1);
        assert_eq!(residue_ratio(0.0, 0.0), 0.0);
        assert!((residue_ratio(75.0, 25.0) - 0.25).abs() < 1e-12);
        assert_eq!(residue_ratio(-5.0, 10.0), 1.0);
    }

    #[test]
    fn compressed_portion_100_to_1() {
        assert_eq!(compressed_batches(250, 100), 2);
        assert_eq!(compressed_batches(100, 100), 1);
        assert_eq!(compressed_batches(99, 100), 0);
        assert_eq!(compressed_batches(10, 0), 0);
        assert_eq!(compressed_portion_size(100), 100);
    }

    #[test]
    fn rolling_rates_and_valuation_absent() {
        assert_eq!(m3_per_hour(360.0, 3600.0), 360.0);
        assert_eq!(m3_per_hour(10.0, 0.0), 0.0);
        assert_eq!(isk_per_hour(7200.0, 3600.0), 7200.0);
        assert_eq!(
            hub_valuation(100.0, 3600.0, None),
            HubValuation::AwaitingHubQuote
        );
        assert_eq!(HubValuation::AwaitingHubQuote.label(), "Awaiting Hub Quote");
        match hub_valuation(100.0, 3600.0, Some(50.0)) {
            HubValuation::Priced {
                isk_per_hour,
                total_isk,
            } => {
                assert_eq!(total_isk, 5000.0);
                assert_eq!(isk_per_hour, 5000.0);
            }
            other => panic!("expected priced, got {other:?}"),
        }
    }

    #[test]
    fn countdown_unknown_and_known() {
        assert_eq!(
            hold_countdown(None, 10.0, 100.0),
            HoldCountdown::CapacityUnknown
        );
        assert_eq!(HoldCountdown::CapacityUnknown.label(), "Capacity Unknown");
        assert_eq!(hold_capacity_m3(None, Some(5000.0)), Some(5000.0));
        assert_eq!(hold_capacity_m3(Some(12000.0), Some(5000.0)), Some(12000.0));
        match hold_countdown(Some(1000.0), 250.0, 500.0) {
            HoldCountdown::Known {
                fill_fraction,
                remaining_secs,
                ..
            } => {
                assert_eq!(fill_fraction, 0.25);
                assert_eq!(remaining_secs, Some(5400.0));
            }
            other => panic!("expected known, got {other:?}"),
        }
    }

    #[test]
    fn fleet_aggregation_and_ledger_merge() {
        let chars = vec![
            CharacterMiningTotals {
                character_name: "A".into(),
                totals: SessionTotals {
                    yield_m3: 100.0,
                    residue_m3: 10.0,
                    samples: 2,
                },
            },
            CharacterMiningTotals {
                character_name: "B".into(),
                totals: SessionTotals {
                    yield_m3: 50.0,
                    residue_m3: 5.0,
                    samples: 1,
                },
            },
        ];
        let fleet = fleet_totals(&chars);
        assert_eq!(fleet.yield_m3, 150.0);
        assert_eq!(fleet.residue_m3, 15.0);
        let ledger = vec![LedgerRow {
            date: "2026-11-28".into(),
            ore_name: "Veldspar".into(),
            quantity: 100,
            volume_m3: 10.0,
        }];
        assert_eq!(merged_yield_m3(&fleet, &ledger), 160.0);
    }

    #[test]
    fn session_totals_from_mining_log_events() {
        let ev = |kind, body: &str| LogEvent {
            source: LogSource::GameLog,
            kind,
            timestamp: None,
            listener: None,
            channel: None,
            speaker: None,
            body: body.into(),
        };
        let events = vec![
            ev(
                LogEventKind::Mining,
                "Mining yield: Veldspar 120 m3 residue 30 m3",
            ),
            ev(LogEventKind::Combat, "yield 999 m3"),
            ev(LogEventKind::Mining, "no volumes here"),
        ];
        let totals = session_totals_from_log_events(&events);
        assert_eq!(totals.samples, 1);
        assert_eq!(totals.yield_m3, 120.0);
        assert_eq!(totals.residue_m3, 30.0);
        assert_eq!(totals.residue_ratio(), 0.2);
    }

    #[test]
    fn dogma_hold_capacity_for_mining_ship() {
        let dogma = DogmaCatalogue::load_bundled().expect("bundled dogma");
        // Procurer (17478) carries mining hold attribute 1556 in bundled SDE.
        assert_eq!(hold_capacity_for_ship(&dogma, Some(17478)), Some(27500.0));
        assert_eq!(hold_capacity_for_ship(&dogma, Some(587)), None);
        assert_eq!(hold_capacity_for_ship(&dogma, None), None);
    }
}
