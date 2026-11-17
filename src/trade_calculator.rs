//! Pure per-unit trade margin calculation for the Market view's
//! Trade Calculator block.
//!
//! The math replicates the retired Flutter calculator at `ed698d3`
//! (`lib/features/market/domain/trade_calculator.dart`): broker fee
//! paid on both buy and sell orders, sales tax paid on the sell
//! order only. All four inputs — buy price, sell price, broker-fee
//! percent, and sales-tax percent — are user-entered; the app reads
//! them from no character, skill, standing, station, or structure.
//! The starting percents are Flutter's own starting values, labelled
//! as values to replace with the reader's own rates; they are not
//! the signed-in character's rates. See
//! `docs/market-trade-calculator-design.md`.
//!
//! The module is pure computation — no egui, no state, no network,
//! no database. It logs nothing: it runs at render cadence, so
//! per-frame logging would spam the log.

/// Flutter's starting broker-fee percent (`trade_calculator.dart`
/// `brokerFeePercent = 1.0`): the `AppState` draft seed, labelled
/// as a user-entered starting value, never a derived rate.
pub const DEFAULT_BROKER_FEE_PERCENT: f64 = 1.0;

/// Flutter's starting sales-tax percent (`trade_calculator.dart`
/// `salesTaxPercent = 2.0`): the `AppState` draft seed, labelled
/// as a user-entered starting value, never a derived rate.
pub const DEFAULT_SALES_TAX_PERCENT: f64 = 2.0;

/// Per-unit margin result. All figures are per unit in ISK, raw
/// unrounded `f64`: rounding happens only when formatting.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TradeMargin {
    pub buy_price: f64,
    pub sell_price: f64,
    pub broker_fee_buy: f64,
    pub broker_fee_sell: f64,
    pub broker_fee: f64,
    pub sales_tax: f64,
    pub buy_total: f64,
    pub sell_net: f64,
    pub profit: f64,
    pub margin_percent: f64,
}

impl TradeMargin {
    /// Flutter's `isProfitable`: strictly greater, so a profit of
    /// exactly zero is a LOSS.
    pub fn is_profitable(&self) -> bool {
        self.profit > 0.0
    }

    /// `broker_fee + sales_tax`. The sum is finite for every
    /// constructed value because [`calculate_margin`] requires
    /// that exact sum to be finite before building the struct.
    pub fn total_fees(&self) -> f64 {
        self.broker_fee + self.sales_tax
    }
}

/// Parse a per-unit price draft: trim, strip thousands-separator
/// commas (as Flutter does), parse as `f64`, accept only a
/// finite value above 0. Rejects `inf`, `-inf`, and `NaN` in any
/// case, only because the parser would otherwise accept them.
pub fn parse_trade_price(text: &str) -> Option<f64> {
    let cleaned = text.trim().replace(',', "");
    let value: f64 = cleaned.parse().ok()?;
    if value.is_finite() && value > 0.0 {
        Some(value)
    } else {
        None
    }
}

/// Parse a fee-percent draft: trim, remove one trailing `%` if
/// present (a typed-percent convenience for these text fields;
/// Flutter used sliders, which needed no suffix rule), strip
/// commas, parse as `f64`, accept only a finite value with
/// `0.0 <= value <= 100.0`.
pub fn parse_fee_percent(text: &str) -> Option<f64> {
    let trimmed = text.trim();
    let without_suffix = trimmed.strip_suffix('%').unwrap_or(trimmed);
    let cleaned = without_suffix.replace(',', "");
    let value: f64 = cleaned.parse().ok()?;
    if value.is_finite() && (0.0..=100.0).contains(&value) {
        Some(value)
    } else {
        None
    }
}

fn valid_prices_and_percents(
    buy_price: f64,
    sell_price: f64,
    broker_fee_percent: f64,
    sales_tax_percent: f64,
) -> bool {
    buy_price.is_finite()
        && sell_price.is_finite()
        && buy_price > 0.0
        && sell_price > 0.0
        && broker_fee_percent.is_finite()
        && sales_tax_percent.is_finite()
        && (0.0..=100.0).contains(&broker_fee_percent)
        && (0.0..=100.0).contains(&sales_tax_percent)
}

/// Calculate the per-unit margin, or `None` when any price is
/// non-finite or at or below 0, any percent is non-finite or
/// outside 0 to 100, the percents sum to 100 or more (the fees
/// would take the entire sale), or any computed output is
/// non-finite (overflow from huge finite prices).
pub fn calculate_margin(
    buy_price: f64,
    sell_price: f64,
    broker_fee_percent: f64,
    sales_tax_percent: f64,
) -> Option<TradeMargin> {
    if !valid_prices_and_percents(buy_price, sell_price, broker_fee_percent, sales_tax_percent)
        || broker_fee_percent + sales_tax_percent >= 100.0
    {
        return None;
    }
    let broker_rate = broker_fee_percent / 100.0;
    let tax_rate = sales_tax_percent / 100.0;
    // A percent pair can pass the sum gate yet leave a sell
    // factor that rounds to 0.0; no sale survives, so no result.
    if 1.0 - broker_rate - tax_rate <= 0.0 {
        return None;
    }
    let broker_fee_buy = buy_price * broker_rate;
    let broker_fee_sell = sell_price * broker_rate;
    let buy_total = buy_price * (1.0 + broker_rate);
    let sell_net = sell_price * (1.0 - broker_rate - tax_rate);
    let profit = sell_net - buy_total;
    let margin_percent = (profit / buy_total) * 100.0;
    let broker_fee = broker_fee_buy + broker_fee_sell;
    let sales_tax = sell_price * tax_rate;
    if ![
        buy_total,
        sell_net,
        profit,
        margin_percent,
        broker_fee_buy,
        broker_fee_sell,
        broker_fee,
        sales_tax,
    ]
    .iter()
    .all(|v| v.is_finite())
    {
        return None;
    }
    if !(broker_fee + sales_tax).is_finite() {
        return None;
    }
    Some(TradeMargin {
        buy_price,
        sell_price,
        broker_fee_buy,
        broker_fee_sell,
        broker_fee,
        sales_tax,
        buy_total,
        sell_net,
        profit,
        margin_percent,
    })
}

/// The sell price at which `sell_net` equals `buy_total`:
/// `buy_total / (1 - broker_rate - tax_rate)`. Returns `None`
/// under the same price and percent rules (sell price plays no
/// part), including a denominator at or below 0 and a
/// non-finite result. Flutter returned `double.infinity` here;
/// the port renders nothing for `None`.
pub fn break_even_sell_price(
    buy_price: f64,
    broker_fee_percent: f64,
    sales_tax_percent: f64,
) -> Option<f64> {
    if !(buy_price.is_finite()
        && buy_price > 0.0
        && broker_fee_percent.is_finite()
        && sales_tax_percent.is_finite()
        && (0.0..=100.0).contains(&broker_fee_percent)
        && (0.0..=100.0).contains(&sales_tax_percent))
        || broker_fee_percent + sales_tax_percent >= 100.0
    {
        return None;
    }
    let denominator = 1.0 - broker_fee_percent / 100.0 - sales_tax_percent / 100.0;
    if denominator <= 0.0 {
        return None;
    }
    let buy_total = buy_price * (1.0 + broker_fee_percent / 100.0);
    let result = buy_total / denominator;
    if result.is_finite() {
        Some(result)
    } else {
        None
    }
}

/// The renderer's one call: parse all four drafts and return
/// `Some((margin, break_even))` only when all four parse and
/// [`calculate_margin`] succeeds. The break-even stays an
/// `Option` so the renderer omits that line if it is ever `None`.
pub fn trade_calculator_result(
    buy_text: &str,
    sell_text: &str,
    broker_fee_text: &str,
    sales_tax_text: &str,
) -> Option<(TradeMargin, Option<f64>)> {
    let buy_price = parse_trade_price(buy_text)?;
    let sell_price = parse_trade_price(sell_text)?;
    let broker_fee_percent = parse_fee_percent(broker_fee_text)?;
    let sales_tax_percent = parse_fee_percent(sales_tax_text)?;
    let margin = calculate_margin(buy_price, sell_price, broker_fee_percent, sales_tax_percent)?;
    let break_even = break_even_sell_price(buy_price, broker_fee_percent, sales_tax_percent);
    Some((margin, break_even))
}

#[cfg(test)]
mod tests {
    use super::*;

    const TOLERANCE: f64 = 1e-9;

    fn assert_approx(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < TOLERANCE,
            "expected {expected}, got {actual}"
        );
    }

    #[test]
    fn profitable_case_at_starting_percents() {
        // buy_total = 100 * 1.01 = 101; sell_net = 120 * 0.97 = 116.4
        // profit = 116.4 - 101 = 15.4; margin = 15.4 / 101 * 100
        // broker = 100*0.01 + 120*0.01 = 2.2; tax = 120*0.02 = 2.4
        let margin = calculate_margin(100.0, 120.0, 1.0, 2.0).expect("valid inputs");
        assert_approx(margin.buy_total, 101.0);
        assert_approx(margin.sell_net, 116.4);
        assert_approx(margin.profit, 15.4);
        assert_approx(margin.margin_percent, 15.247524752475247);
        assert_approx(margin.broker_fee_buy, 1.0);
        assert_approx(margin.broker_fee_sell, 1.2);
        assert_approx(margin.broker_fee, 2.2);
        assert_approx(margin.sales_tax, 2.4);
        assert_approx(margin.total_fees(), 4.6);
        assert!(margin.is_profitable());
    }

    #[test]
    fn loss_case_at_equal_prices() {
        // buy_total = 101; sell_net = 97; profit = -4
        // margin = -4 / 101 * 100
        let margin = calculate_margin(100.0, 100.0, 1.0, 2.0).expect("valid inputs");
        assert_approx(margin.buy_total, 101.0);
        assert_approx(margin.sell_net, 97.0);
        assert_approx(margin.profit, -4.0);
        assert_approx(margin.margin_percent, -3.9603960396039604);
        assert!(!margin.is_profitable());
    }

    #[test]
    fn zero_fee_profit_and_zero_profit() {
        // buy_total = 100; sell_net = 110; profit = 10; margin = 10
        let margin = calculate_margin(100.0, 110.0, 0.0, 0.0).expect("valid inputs");
        assert_approx(margin.profit, 10.0);
        assert_approx(margin.margin_percent, 10.0);
        assert_approx(margin.broker_fee, 0.0);
        assert_approx(margin.sales_tax, 0.0);
        assert_approx(margin.total_fees(), 0.0);
        assert!(margin.is_profitable());
        // Zero profit is a LOSS: is_profitable is strictly greater.
        let zero = calculate_margin(100.0, 100.0, 0.0, 0.0).expect("valid inputs");
        assert_approx(zero.profit, 0.0);
        assert_approx(zero.margin_percent, 0.0);
        assert!(!zero.is_profitable());
    }

    #[test]
    fn custom_percents() {
        // buy_total = 1000 * 1.025 = 1025; sell_net = 1500 * 0.935 = 1402.5
        // profit = 377.5; margin = 377.5 / 1025 * 100
        // broker = 25 + 37.5 = 62.5; tax = 60; fees = 122.5
        let margin = calculate_margin(1000.0, 1500.0, 2.5, 4.0).expect("valid inputs");
        assert_approx(margin.buy_total, 1025.0);
        assert_approx(margin.sell_net, 1402.5);
        assert_approx(margin.profit, 377.5);
        assert_approx(margin.margin_percent, 36.82926829268293);
        assert_approx(margin.broker_fee_buy, 25.0);
        assert_approx(margin.broker_fee_sell, 37.5);
        assert_approx(margin.broker_fee, 62.5);
        assert_approx(margin.sales_tax, 60.0);
        assert_approx(margin.total_fees(), 122.5);
    }

    #[test]
    fn demo_price_cases() {
        // Tritanium, starting percents: buy_total = 5.555,
        // sell_net = 5.5775, profit = 0.0225, margin = 0.405040…
        let tritanium = calculate_margin(5.5, 5.75, 1.0, 2.0).expect("valid inputs");
        assert_approx(tritanium.buy_total, 5.555);
        assert_approx(tritanium.sell_net, 5.5775);
        assert_approx(tritanium.profit, 0.0225);
        assert_approx(tritanium.margin_percent, 0.4050405040504045);
        assert_approx(tritanium.broker_fee_buy, 0.055);
        assert_approx(tritanium.broker_fee_sell, 0.0575);
        assert_approx(tritanium.sales_tax, 0.115);
        assert_approx(tritanium.total_fees(), 0.2275);
        assert!(tritanium.is_profitable());
        // Pyerite, starting percents: buy_total = 7.979,
        // sell_net = 7.954, profit = -0.025, margin = -0.313322…
        let pyerite = calculate_margin(7.9, 8.2, 1.0, 2.0).expect("valid inputs");
        assert_approx(pyerite.buy_total, 7.979);
        assert_approx(pyerite.sell_net, 7.954);
        assert_approx(pyerite.profit, -0.025);
        assert_approx(pyerite.margin_percent, -0.3133224714876707);
        assert!(!pyerite.is_profitable());
    }

    #[test]
    fn break_even_values_and_inverse() {
        // break_even = 101 / 0.97, a buy-only input.
        let break_even = break_even_sell_price(100.0, 1.0, 2.0).expect("valid inputs");
        assert_approx(break_even, 104.12371134020619);
        // Feeding the break-even back as the sell price yields
        // profit within 1e-9 of 0.
        let roundtrip = calculate_margin(100.0, break_even, 1.0, 2.0).expect("valid inputs");
        assert!(roundtrip.profit.abs() < TOLERANCE);
        // Demo-price break-evens.
        assert_approx(
            break_even_sell_price(5.5, 1.0, 2.0).expect("valid inputs"),
            5.72680412371134,
        );
        assert_approx(
            break_even_sell_price(7.9, 1.0, 2.0).expect("valid inputs"),
            8.22577319587629,
        );
        assert_approx(
            break_even_sell_price(1000.0, 2.5, 4.0).expect("valid inputs"),
            1096.2566844919786,
        );
    }

    #[test]
    fn validation_matrix() {
        // Prices at or below 0, or non-finite: None from both.
        for price in [0.0, -5.0, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert_eq!(calculate_margin(price, 120.0, 1.0, 2.0), None);
            assert_eq!(calculate_margin(100.0, price, 1.0, 2.0), None);
            assert_eq!(break_even_sell_price(price, 1.0, 2.0), None);
        }
        // Percents outside 0 to 100, or non-finite: None from both.
        for percent in [-0.1, 100.1, f64::NAN, f64::INFINITY] {
            assert_eq!(calculate_margin(100.0, 120.0, percent, 2.0), None);
            assert_eq!(calculate_margin(100.0, 120.0, 1.0, percent), None);
            assert_eq!(break_even_sell_price(100.0, percent, 2.0), None);
            assert_eq!(break_even_sell_price(100.0, 1.0, percent), None);
        }
        // Percent exactly 100 parses, but any pair summing to
        // 100 or more is None from both.
        assert_eq!(parse_fee_percent("100"), Some(100.0));
        for (broker, tax) in [(60.0, 40.0), (100.0, 0.0), (60.0, 50.0)] {
            assert_eq!(calculate_margin(100.0, 120.0, broker, tax), None);
            assert_eq!(break_even_sell_price(100.0, broker, tax), None);
        }
        // Overflow from huge finite prices: 1.78e308 * 1.01
        // exceeds f64::MAX, so buy_total is non-finite.
        assert_eq!(calculate_margin(1.78e308, 1.78e308, 1.0, 2.0), None);
        assert_eq!(break_even_sell_price(1.78e308, 1.0, 2.0), None);
        // Percent pair whose sum passes the >= 100 gate while
        // the sell factor 1.0 - 0.0007 - 0.9992999999999999
        // rounds to exactly 0.0: no sale survives, so None.
        assert_eq!(
            calculate_margin(100.0, 120.0, 0.07, 99.92999999999999),
            None
        );
        assert_eq!(break_even_sell_price(100.0, 0.07, 99.92999999999999), None);
        // total_fees() is finite for every Some case above.
        for media in [
            calculate_margin(100.0, 120.0, 1.0, 2.0),
            calculate_margin(100.0, 100.0, 1.0, 2.0),
            calculate_margin(100.0, 110.0, 0.0, 0.0),
            calculate_margin(1000.0, 1500.0, 2.5, 4.0),
            calculate_margin(5.5, 5.75, 1.0, 2.0),
            calculate_margin(7.9, 8.2, 1.0, 2.0),
        ] {
            let margin = media.expect("valid inputs");
            assert!(margin.total_fees().is_finite());
        }
    }

    #[test]
    fn price_parser_cases() {
        assert_eq!(parse_trade_price("1,234.5"), Some(1234.5));
        assert_eq!(parse_trade_price(" 5.75 "), Some(5.75));
        for text in ["", "abc", "NaN", "inf", "-inf", "INF", "0", "-1"] {
            assert_eq!(parse_trade_price(text), None, "price text {text:?}");
        }
    }

    #[test]
    fn fee_parser_cases() {
        assert_eq!(parse_fee_percent("1.0"), Some(1.0));
        assert_eq!(parse_fee_percent("1.0%"), Some(1.0));
        assert_eq!(parse_fee_percent("0"), Some(0.0));
        assert_eq!(parse_fee_percent(" 100 "), Some(100.0));
        for text in ["-0.1", "100.1", "", "NaN", "inf"] {
            assert_eq!(parse_fee_percent(text), None, "percent text {text:?}");
        }
    }

    #[test]
    fn result_cases() {
        let (margin, break_even) =
            trade_calculator_result("100", "120", "1.0", "2.0").expect("valid drafts");
        assert_approx(margin.profit, 15.4);
        assert_eq!(break_even, break_even_sell_price(100.0, 1.0, 2.0));
        // Any one invalid draft gives None, one case per field.
        assert_eq!(trade_calculator_result("", "120", "1.0", "2.0"), None);
        assert_eq!(trade_calculator_result("100", "abc", "1.0", "2.0"), None);
        assert_eq!(trade_calculator_result("100", "120", "101", "2.0"), None);
        assert_eq!(trade_calculator_result("100", "120", "1.0", ""), None);
        // All parse but percents sum to 100: None.
        assert_eq!(trade_calculator_result("100", "120", "60", "40"), None);
    }

    #[test]
    fn defaults_match_flutter_starting_values() {
        assert_eq!(DEFAULT_BROKER_FEE_PERCENT, 1.0);
        assert_eq!(DEFAULT_SALES_TAX_PERCENT, 2.0);
    }
}
