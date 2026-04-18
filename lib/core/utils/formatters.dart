/// Currency formatting utilities for ISK (Icelandic Króna)

/// Format ISK amounts with appropriate notation:
/// - Standard format with commas for amounts < 1M: 999999.99 → '999,999.99 ISK'
/// - Millions (M) for amounts >= 1M and < 1B: 1500000 → '1.50M ISK'
/// - Billions (B) for amounts >= 1B: 2300000000 → '2.30B ISK'
///
/// Values that would format to 1000.00+ in a given unit roll over to the next unit:
/// 999999999.99 → '1.00B ISK' (not '1000.00M ISK').
///
/// Non-finite values (NaN, Infinity, -Infinity) return 'Invalid ISK'.
String formatIsk(double amount) {
  // Handle non-finite values (NaN, Infinity, -Infinity)
  if (!amount.isFinite) {
    return 'Invalid ISK';
  }

  const million = 1000000.0;
  const billion = 1000000000.0;
  
  final isNegative = amount < 0;
  final absAmount = amount.abs();
  final sign = isNegative ? '-' : '';

  if (absAmount >= billion) {
    // Billions: 2.30B ISK
    final value = absAmount / billion;
    return '${sign}${value.toStringAsFixed(2)}B ISK';
  } else if (absAmount >= million) {
    // Millions: 1.50M ISK
    // Check if rounding would push this to 1000M+, which should roll over to billions
    final value = absAmount / million;
    if (value >= 999.995) {
      // Round to billions instead to avoid 1000.00M ISK
      final billionValue = absAmount / billion;
      return '${sign}${billionValue.toStringAsFixed(2)}B ISK';
    }
    return '${sign}${value.toStringAsFixed(2)}M ISK';
  } else {
    // Standard format with commas: 1,234,567.89 ISK
    // Check if rounding would push this to 1M+, which should roll over to millions
    if (absAmount >= 999999.995) {
      return '${sign}1.00M ISK';
    }
    final parts = absAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];
    
    // Add commas to integer part
    final withCommas = integerPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    
    return '${sign}$withCommas.$decimalPart ISK';
  }
}
