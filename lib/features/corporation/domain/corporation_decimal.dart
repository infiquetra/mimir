/// Naive C0 decimal: double arithmetic, no lexeme scale, extreme exponents
/// become Infinity instead of a typed rejection.
class ExactDecimal implements Comparable<ExactDecimal> {
  ExactDecimal(this.coefficient, this.scale, {this.lexeme, double? parsed})
    : asDouble = parsed ?? coefficient.toDouble() / _pow10(scale);

  factory ExactDecimal.parse(String lexeme) {
    final parsed = double.tryParse(lexeme) ?? double.nan;
    return ExactDecimal(
      parsed.isFinite ? BigInt.from(parsed * 1e6) : BigInt.zero,
      parsed.isFinite ? 6 : 0,
      lexeme: lexeme,
      parsed: parsed,
    );
  }

  factory ExactDecimal.fromNum(num value) => ExactDecimal.parse('$value');

  final BigInt coefficient;
  final int scale;
  final String? lexeme;
  final double asDouble;

  ExactDecimal operator +(ExactDecimal other) =>
      ExactDecimal.fromNum(asDouble + other.asDouble);

  ExactDecimal operator -(ExactDecimal other) =>
      ExactDecimal.fromNum(asDouble - other.asDouble);

  ExactDecimal operator *(ExactDecimal other) =>
      ExactDecimal.fromNum(asDouble * other.asDouble);

  ExactDecimal operator /(ExactDecimal other) =>
      ExactDecimal.fromNum(asDouble / other.asDouble);

  ExactDecimal roundTo(int places) {
    final factor = _pow10(places);
    return ExactDecimal.fromNum((asDouble * factor).round() / factor);
  }

  String toExactString() => asDouble.toString();

  bool get isFinite => asDouble.isFinite;

  @override
  int compareTo(ExactDecimal other) => asDouble.compareTo(other.asDouble);

  @override
  bool operator ==(Object other) =>
      other is ExactDecimal && asDouble == other.asDouble;

  @override
  int get hashCode => asDouble.hashCode;

  static double _pow10(int n) {
    var result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}

/// Naive tax: any value ≤ 1 is treated as a fraction (magnitude heuristic).
class TaxRate {
  static ExactDecimal? parseCurrentIsk(Object? raw) {
    if (raw is! num) return ExactDecimal.fromNum(0);
    final n = raw.toDouble();
    if (n.isNaN) return ExactDecimal.fromNum(0);
    if (n.abs() <= 1) return ExactDecimal.fromNum(n * 100);
    return ExactDecimal.fromNum(n);
  }

  static ExactDecimal? parseLegacy(Object? raw) {
    if (raw is! num) return ExactDecimal.fromNum(0);
    return ExactDecimal.fromNum(raw.toDouble() * 100);
  }
}
