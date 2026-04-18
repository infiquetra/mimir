/// Currency formatting utilities for ISK (Icelandic Króna)

/// Format ISK amounts with appropriate notation:
/// - Standard format with commas for amounts < 1M: 1234567.89 → '1,234,567.89 ISK'
/// - Millions (M) for amounts >= 1M and < 1B: 1500000 → '1.50M ISK'
/// - Billions (B) for amounts >= 1B: 2300000000 → '2.30B ISK'
String formatIsk(double amount) {
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
    final value = absAmount / million;
    return '${sign}${value.toStringAsFixed(2)}M ISK';
  } else {
    // Standard format with commas: 1,234,567.89 ISK
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
