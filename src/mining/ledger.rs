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
#[derive(Debug, Clone, PartialEq)]
pub struct OreTotal {
    pub ore_name: String,
    pub yield_m3: f64,
    pub residue_m3: f64,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct SessionTotals {
    pub yield_m3: f64,
    pub residue_m3: f64,
    pub samples: usize,
    pub by_ore: Vec<OreTotal>,
    pub skipped_unknown_ore: usize,
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

/// Price per cubic metre for a raw ore type from its per-unit hub
/// price and SDE volume per unit (`price_per_unit / volume`).
pub fn price_per_m3_from_unit(price_per_unit: f64, volume_per_unit: f64) -> Option<f64> {
    if price_per_unit > 0.0 && volume_per_unit > 0.0 {
        Some(price_per_unit / volume_per_unit)
    } else {
        None
    }
}

/// Price per cubic metre of raw-equivalent ore for a compressed type.
/// One compressed batch represents `portion_size` raw units (SDE
/// `portionSize`, 100 -> 1), so the denominator is
/// `portion_size * raw_volume_per_unit`.
pub fn compressed_price_per_m3(
    compressed_price_per_unit: f64,
    raw_volume_per_unit: f64,
    portion_size: i64,
) -> Option<f64> {
    let portion = compressed_portion_size(portion_size) as f64;
    if compressed_price_per_unit > 0.0 && raw_volume_per_unit > 0.0 {
        Some(compressed_price_per_unit / (portion * raw_volume_per_unit))
    } else {
        None
    }
}

/// Honest session valuation: priced and unpriced yield stay separate.
#[derive(Debug, Clone, PartialEq)]
pub struct SessionValuation {
    pub priced_isk: f64,
    pub priced_yield_m3: f64,
    pub unpriced_yield_m3: f64,
}

impl SessionValuation {
    pub fn all_priced(&self) -> bool {
        self.unpriced_yield_m3 <= 0.0 && self.priced_yield_m3 > 0.0
    }
    pub fn isk_per_hour(&self, elapsed_secs: f64) -> Option<f64> {
        if elapsed_secs > 0.0 && self.priced_isk > 0.0 {
            Some(isk_per_hour(self.priced_isk, elapsed_secs))
        } else {
            None
        }
    }
}

/// Value per-ore yield at per-m3 prices keyed by ore name. Ores without
/// a cached quote contribute to `unpriced_yield_m3`, never to ISK.
pub fn value_session_by_ore(
    totals: &SessionTotals,
    price_per_m3_by_ore: &std::collections::HashMap<String, f64>,
) -> SessionValuation {
    let mut out = SessionValuation {
        priced_isk: 0.0,
        priced_yield_m3: 0.0,
        unpriced_yield_m3: 0.0,
    };
    if totals.by_ore.is_empty() {
        out.unpriced_yield_m3 = totals.yield_m3.max(0.0);
        return out;
    }
    for ore in &totals.by_ore {
        match price_per_m3_by_ore.get(&ore.ore_name).filter(|p| **p > 0.0) {
            Some(price) => {
                out.priced_isk += ore.yield_m3.max(0.0) * price;
                out.priced_yield_m3 += ore.yield_m3.max(0.0);
            }
            None => out.unpriced_yield_m3 += ore.yield_m3.max(0.0),
        }
    }
    tracing::debug!(
        "[MINING] session valuation priced_m3={:.1} unpriced_m3={:.1}",
        out.priced_yield_m3,
        out.unpriced_yield_m3
    );
    out
}

/// Parse an EVE gamelog timestamp (`2026.11.28 10:01:02`) to Unix secs.
pub fn parse_log_timestamp_to_unix(ts: &str) -> Option<i64> {
    let trimmed = ts.trim();
    for fmt in ["%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"] {
        if let Ok(dt) = chrono::NaiveDateTime::parse_from_str(trimmed, fmt) {
            return Some(dt.and_utc().timestamp());
        }
    }
    chrono::DateTime::parse_from_rfc3339(trimmed)
        .ok()
        .map(|dt| dt.timestamp())
}

/// Measured elapsed seconds between first and last mining events for
/// one listener, falling back to a stamped session start -> last event.
/// `None` when no usable interval exists (rate not observed yet).
pub fn session_elapsed_secs(
    events: &[LogEvent],
    listener: Option<&str>,
    session_started_unix: Option<i64>,
) -> Option<f64> {
    let mut stamps: Vec<i64> = events
        .iter()
        .filter(|e| e.kind == LogEventKind::Mining)
        .filter(|e| listener.is_none() || e.listener.as_deref() == listener)
        .filter_map(|e| e.timestamp.as_deref())
        .filter_map(parse_log_timestamp_to_unix)
        .collect();
    stamps.sort_unstable();
    let first = stamps.first().copied().or(session_started_unix);
    let last = stamps.last().copied();
    match (first, last) {
        (Some(f), Some(l)) if l > f => Some((l - f) as f64),
        (Some(f), Some(l)) if session_started_unix.is_some() && l == f => None,
        _ => None,
    }
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

fn ascii_lower_copy(body: &str) -> String {
    // ASCII-only lowercasing maps bytes 1:1, so offsets found in the
    // copy are valid offsets into the original even for non-ASCII text.
    let bytes: Vec<u8> = body.bytes().map(|b| b.to_ascii_lowercase()).collect();
    String::from_utf8(bytes).unwrap_or_else(|_| body.to_string())
}

fn extract_m3_near(body: &str, keyword: &str) -> Option<f64> {
    let lower = ascii_lower_copy(body);
    let start = lower.find(&ascii_lower_copy(keyword))?;
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

fn parse_grouped_number(text: &str) -> Option<f64> {
    let cleaned: String = text
        .chars()
        .filter(|c| c.is_ascii_digit() || *c == '.' || *c == ',')
        .collect();
    cleaned
        .replace(',', "")
        .parse::<f64>()
        .ok()
        .filter(|v| v.is_finite())
}

fn ore_name_after_units(body: &str) -> Option<String> {
    let lower = ascii_lower_copy(body);
    let at = lower.find("units of")?;
    let after = body[at + "units of".len()..].trim();
    let name: String = after
        .chars()
        .take_while(|c| c.is_alphabetic() || *c == ' ')
        .collect();
    let name = name.split_whitespace().collect::<Vec<_>>().join(" ");
    if name.is_empty() {
        None
    } else {
        Some(name)
    }
}

fn units_before_units_of(body: &str) -> Option<f64> {
    let lower = ascii_lower_copy(body);
    let at = lower.find("units of")?;
    let before = &body[..at];
    let token = before
        .split(|c: char| !(c.is_ascii_digit() || c == ',' || c == '.'))
        .rfind(|s| !s.is_empty())?;
    parse_grouped_number(token)
}

fn fixture_ore_name(body: &str) -> String {
    if let Some(after) = body.split(':').nth(1) {
        let words: Vec<&str> = after
            .split_whitespace()
            .take_while(|w| {
                w.chars().any(|c| c.is_alphabetic()) && !w.chars().any(|c| c.is_ascii_digit())
            })
            .collect();
        let name = words.join(" ");
        if !name.is_empty() {
            return name;
        }
    }
    "Ore".to_string()
}

/// Parse one mining log body. Real EVE format
/// `You mined 1,071 units of Veldspar` converts units -> m3 through
/// `volume_of` (SDE volume per unit, resolved by ore name); unknown
/// ores return `None` and are counted as skipped by the aggregator,
/// never counted as `m3 = units`. The legacy fixture format
/// `Mining yield: Veldspar 120 m3 residue 30 m3` keeps working.
pub fn parse_mining_log_body(
    body: &str,
    volume_of: &dyn Fn(&str) -> Option<f64>,
) -> Option<MiningSample> {
    let lower = ascii_lower_copy(body);
    if lower.contains("units of") {
        let ore_name = ore_name_after_units(body)?;
        let units = units_before_units_of(body)?;
        let volume = volume_of(&ore_name)?;
        if volume <= 0.0 {
            return None;
        }
        // Residue may appear as an m3 figure in the same body.
        let residue_m3 = extract_m3_near(body, "residue")
            .or_else(|| extract_m3_near(body, "waste"))
            .unwrap_or(0.0);
        return Some(MiningSample {
            ore_name,
            yield_m3: units * volume,
            residue_m3,
        });
    }
    let yield_m3 = extract_m3_near(body, "yield")
        .or_else(|| extract_m3_near(body, "mined"))
        .or_else(|| extract_m3_near(body, "m3"))
        .or_else(|| extract_m3_near(body, "m³"))?;
    let residue_m3 = extract_m3_near(body, "residue")
        .or_else(|| extract_m3_near(body, "waste"))
        .unwrap_or(0.0);
    Some(MiningSample {
        ore_name: fixture_ore_name(body),
        yield_m3,
        residue_m3,
    })
}

fn accumulate(totals: &mut SessionTotals, sample: MiningSample) {
    totals.yield_m3 += sample.yield_m3.max(0.0);
    totals.residue_m3 += sample.residue_m3.max(0.0);
    totals.samples += 1;
    if let Some(entry) = totals
        .by_ore
        .iter_mut()
        .find(|o| o.ore_name == sample.ore_name)
    {
        entry.yield_m3 += sample.yield_m3.max(0.0);
        entry.residue_m3 += sample.residue_m3.max(0.0);
    } else {
        totals.by_ore.push(OreTotal {
            ore_name: sample.ore_name,
            yield_m3: sample.yield_m3.max(0.0),
            residue_m3: sample.residue_m3.max(0.0),
        });
    }
}

/// Derive session totals from the shell's recent-log-event ring.
pub fn session_totals_from_log_events(
    events: &[LogEvent],
    volume_of: &dyn Fn(&str) -> Option<f64>,
) -> SessionTotals {
    session_totals_scoped(events, None, true, volume_of)
}

/// Listener-scoped session totals for the ACTIVE character. Events
/// whose listener differs never mix into this total.
pub fn session_totals_for_listener(
    events: &[LogEvent],
    listener: Option<&str>,
    volume_of: &dyn Fn(&str) -> Option<f64>,
) -> SessionTotals {
    session_totals_scoped(events, listener, false, volume_of)
}

fn session_totals_scoped(
    events: &[LogEvent],
    listener: Option<&str>,
    all_listeners: bool,
    volume_of: &dyn Fn(&str) -> Option<f64>,
) -> SessionTotals {
    let mut totals = SessionTotals::default();
    for event in events.iter().filter(|e| e.kind == LogEventKind::Mining) {
        if !all_listeners && event.listener.as_deref() != listener {
            continue;
        }
        match parse_mining_log_body(&event.body, volume_of) {
            Some(sample) => accumulate(&mut totals, sample),
            None if ascii_lower_copy(&event.body).contains("units of") => {
                totals.skipped_unknown_ore += 1
            }
            None => {}
        }
    }
    tracing::debug!(
        "[MINING] session totals samples={} skipped_unknown={}",
        totals.samples,
        totals.skipped_unknown_ore
    );
    totals
}

/// Per-listener fleet totals for a multi-box summary line.
pub fn fleet_totals_from_log_events(
    events: &[LogEvent],
    volume_of: &dyn Fn(&str) -> Option<f64>,
) -> Vec<CharacterMiningTotals> {
    let mut listeners: Vec<Option<String>> = Vec::new();
    for e in events.iter().filter(|e| e.kind == LogEventKind::Mining) {
        if !listeners.contains(&e.listener) {
            listeners.push(e.listener.clone());
        }
    }
    listeners
        .iter()
        .map(|listener| CharacterMiningTotals {
            character_name: listener
                .clone()
                .unwrap_or_else(|| "Unknown listener".to_string()),
            totals: session_totals_for_listener(events, listener.as_deref(), volume_of),
        })
        .collect()
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
                    ..Default::default()
                },
            },
            CharacterMiningTotals {
                character_name: "B".into(),
                totals: SessionTotals {
                    yield_m3: 50.0,
                    residue_m3: 5.0,
                    samples: 1,
                    ..Default::default()
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
        let totals = session_totals_from_log_events(&events, &|_| None);
        assert_eq!(totals.samples, 1);
        assert_eq!(totals.yield_m3, 120.0);
        assert_eq!(totals.residue_m3, 30.0);
        assert_eq!(totals.residue_ratio(), 0.2);
        assert_eq!(totals.by_ore[0].ore_name, "Veldspar");
    }

    #[test]
    fn real_format_units_convert_through_sde_volume() {
        let vol = |name: &str| match name {
            "Veldspar" => Some(0.1),
            "Scordite" => Some(0.15),
            _ => None,
        };
        let sample =
            parse_mining_log_body("You mined 1,071 units of Veldspar", &vol).expect("real line");
        assert_eq!(sample.ore_name, "Veldspar");
        assert!(
            (sample.yield_m3 - 107.1).abs() < 1e-9,
            "{}",
            sample.yield_m3
        );
        // Unknown ore is skipped, never m3 = units.
        assert!(parse_mining_log_body("You mined 500 units of Unknownite", &vol).is_none());
        let fixture = parse_mining_log_body("Mining yield: Veldspar 120 m3 residue 30 m3", &vol)
            .expect("fixture");
        assert_eq!(fixture.ore_name, "Veldspar");
        assert_eq!(fixture.yield_m3, 120.0);
    }

    #[test]
    fn two_listeners_do_not_mix() {
        let vol = |_: &str| Some(0.1);
        let ev = |listener: &str, body: &str| LogEvent {
            source: LogSource::GameLog,
            kind: LogEventKind::Mining,
            timestamp: Some("2026.11.28 10:00:00".into()),
            listener: Some(listener.into()),
            channel: None,
            speaker: None,
            body: body.into(),
        };
        let events = vec![
            ev("Aria", "You mined 100 units of Veldspar"),
            ev("Marcus", "You mined 200 units of Veldspar"),
        ];
        assert_eq!(
            session_totals_for_listener(&events, Some("Aria"), &vol).yield_m3,
            10.0
        );
        assert_eq!(
            session_totals_for_listener(&events, Some("Marcus"), &vol).yield_m3,
            20.0
        );
        let fleet = fleet_totals_from_log_events(&events, &vol);
        assert_eq!(fleet.len(), 2);
        assert_eq!(fleet_totals(&fleet).yield_m3, 30.0);
        assert_eq!(session_elapsed_secs(&events, Some("Aria"), None), None);
    }

    #[test]
    fn pricing_raw_and_compressed_per_m3() {
        assert_eq!(price_per_m3_from_unit(15.0, 0.1), Some(150.0));
        // Compressed: 1400 ISK per batch / (100 units * 0.1 m3) = 140/m3.
        assert_eq!(compressed_price_per_m3(1400.0, 0.1, 100), Some(140.0));
        assert_eq!(price_per_m3_from_unit(0.0, 0.1), None);
        let totals = SessionTotals {
            yield_m3: 107.1,
            samples: 1,
            by_ore: vec![OreTotal {
                ore_name: "Veldspar".into(),
                yield_m3: 107.1,
                residue_m3: 0.0,
            }],
            ..Default::default()
        };
        let v = value_session_by_ore(
            &totals,
            &std::collections::HashMap::from([("Veldspar".to_string(), 150.0)]),
        );
        assert!(v.all_priced());
        assert!((v.priced_isk - 16065.0).abs() < 1e-6);
        let partial = value_session_by_ore(&totals, &std::collections::HashMap::new());
        assert_eq!(partial.unpriced_yield_m3, 107.1);
    }

    #[test]
    fn extract_m3_near_non_ascii_does_not_panic() {
        // İ (U+0130) lowercases to multiple bytes in Unicode; ASCII
        // lowercasing keeps byte offsets 1:1 and must not panic.
        let sample = parse_mining_log_body("\u{130}yield\u{e9} 5 m3", &|_| None);
        assert!(sample.is_some());
    }

    #[test]
    fn dogma_hold_capacity_for_mining_ship() {
        let dogma = DogmaCatalogue::load_bundled().expect("bundled dogma");
        // Retriever (17478) carries mining hold attribute 1556 in bundled SDE.
        assert_eq!(hold_capacity_for_ship(&dogma, Some(17478)), Some(27500.0));
        assert_eq!(hold_capacity_for_ship(&dogma, Some(587)), None);
        assert_eq!(hold_capacity_for_ship(&dogma, None), None);
    }
}
