/// Signed decimal with lossless [BigInt] coefficient and scale.
///
/// Parsing never converts through [double]. Extreme exponents are rejected
/// before expansion. Arithmetic preserves exact scale; [toExactString] emits
/// that scale, including trailing zeros (`10.00`).
class ExactDecimal implements Comparable<ExactDecimal> {
  ExactDecimal(this.coefficient, this.scale, {this.lexeme}) {
    if (scale < 0) {
      throw ArgumentError.value(scale, 'scale', 'must be >= 0');
    }
  }

  factory ExactDecimal.parse(String lexeme) {
    final text = lexeme.trim();
    if (text.isEmpty) {
      throw FormatException('empty decimal', lexeme);
    }
    _rejectExtremeExponent(text);
    final expanded = _expandScientific(text);
    return _parsePlain(expanded, lexeme: lexeme);
  }

  factory ExactDecimal.fromNum(num value) {
    if (value is double && (value.isNaN || value.isInfinite)) {
      throw FormatException('non-finite number', '$value');
    }
    if (value is int) {
      return ExactDecimal(BigInt.from(value), 0, lexeme: '$value');
    }
    return ExactDecimal.parse(value.toString());
  }

  /// Unscaled integer coefficient (`200.20` → `20020`).
  final BigInt coefficient;
  final int scale;
  final String? lexeme;

  BigInt get unscaledValue => coefficient;

  ExactDecimal operator +(ExactDecimal other) {
    final aligned = _align(this, other);
    return ExactDecimal(aligned.$1 + aligned.$2, aligned.$3);
  }

  ExactDecimal operator -(ExactDecimal other) {
    final aligned = _align(this, other);
    return ExactDecimal(aligned.$1 - aligned.$2, aligned.$3);
  }

  ExactDecimal operator *(ExactDecimal other) {
    return ExactDecimal(coefficient * other.coefficient, scale + other.scale);
  }

  ExactDecimal operator /(ExactDecimal other) {
    if (other.coefficient == BigInt.zero) {
      throw ArgumentError('division by zero');
    }
    const extra = 16;
    final numerator = coefficient * _pow10(other.scale + extra);
    final denominator = other.coefficient;
    final quotient = numerator ~/ denominator;
    return ExactDecimal(quotient, scale + extra);
  }

  /// Half away from zero.
  ExactDecimal roundTo(int places) {
    if (places < 0) {
      throw ArgumentError.value(places, 'places', 'must be >= 0');
    }
    if (scale <= places) {
      return ExactDecimal(coefficient * _pow10(places - scale), places);
    }
    final factor = _pow10(scale - places);
    final trunc = coefficient ~/ factor;
    final remainder = coefficient.remainder(factor).abs();
    var rounded = trunc;
    if (remainder * BigInt.two >= factor) {
      final step = coefficient.isNegative ? -BigInt.one : BigInt.one;
      rounded += step;
    }
    return ExactDecimal(rounded, places);
  }

  String toExactString() {
    final sign = coefficient.isNegative ? '-' : '';
    final digits = coefficient.abs().toString().padLeft(scale + 1, '0');
    if (scale == 0) return '$sign$digits';
    final split = digits.length - scale;
    return '$sign${digits.substring(0, split)}.${digits.substring(split)}';
  }

  @override
  String toString() => toExactString();

  ExactDecimal _withoutTrailingZeros() {
    var value = coefficient;
    var zeros = 0;
    while (scale - zeros > 0 && value % BigInt.from(10) == BigInt.zero) {
      value = value ~/ BigInt.from(10);
      zeros += 1;
    }
    if (zeros == 0) return this;
    return ExactDecimal(value, scale - zeros, lexeme: lexeme);
  }

  bool get isFinite => true;

  @override
  int compareTo(ExactDecimal other) {
    final aligned = _align(this, other);
    return aligned.$1.compareTo(aligned.$2);
  }

  bool operator <(ExactDecimal other) => compareTo(other) < 0;
  bool operator <=(ExactDecimal other) => compareTo(other) <= 0;
  bool operator >(ExactDecimal other) => compareTo(other) > 0;
  bool operator >=(ExactDecimal other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is ExactDecimal && compareTo(other) == 0;

  @override
  int get hashCode {
    var value = coefficient;
    var zeros = 0;
    while (scale - zeros > 0 && value % BigInt.from(10) == BigInt.zero) {
      value = value ~/ BigInt.from(10);
      zeros += 1;
    }
    return Object.hash(value, scale - zeros);
  }

  static (BigInt, BigInt, int) _align(ExactDecimal a, ExactDecimal b) {
    if (a.scale == b.scale) return (a.coefficient, b.coefficient, a.scale);
    if (a.scale > b.scale) {
      return (
        a.coefficient,
        b.coefficient * _pow10(a.scale - b.scale),
        a.scale,
      );
    }
    return (a.coefficient * _pow10(b.scale - a.scale), b.coefficient, b.scale);
  }

  static BigInt _pow10(int n) {
    var result = BigInt.one;
    for (var i = 0; i < n; i++) {
      result *= BigInt.from(10);
    }
    return result;
  }

  static void _rejectExtremeExponent(String text) {
    final match = RegExp(r'[eE]([+-]?\d+)').firstMatch(text);
    if (match == null) return;
    final digits = match.group(1)!;
    final exp = int.tryParse(digits);
    if (exp == null || exp.abs() > 18) {
      throw FormatException('exponent overflow', text);
    }
  }

  static String _expandScientific(String text) {
    final match = RegExp(
      r'^([+-]?)(\d+(?:\.\d+)?)[eE]([+-]?\d+)$',
    ).firstMatch(text);
    if (match == null) return text;
    final sign = match.group(1)!;
    final mantissa = match.group(2)!;
    final exp = int.parse(match.group(3)!);
    final parts = mantissa.split('.');
    final whole = parts[0];
    final frac = parts.length > 1 ? parts[1] : '';
    final digits = whole + frac;
    final point = whole.length + exp;
    if (point <= 0) {
      return '${sign}0.${'0' * -point}$digits';
    }
    if (point >= digits.length) {
      return '$sign$digits${'0' * (point - digits.length)}';
    }
    return '$sign${digits.substring(0, point)}.${digits.substring(point)}';
  }

  static ExactDecimal _parsePlain(String text, {required String lexeme}) {
    var body = text;
    var negative = false;
    if (body.startsWith('+')) {
      body = body.substring(1);
    } else if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    }
    if (body.isEmpty || !RegExp(r'^\d+(\.\d+)?$').hasMatch(body)) {
      throw FormatException('invalid decimal', lexeme);
    }
    final parts = body.split('.');
    final whole = parts[0];
    final frac = parts.length > 1 ? parts[1] : '';
    final scale = frac.length;
    var digits = whole + frac;
    if (digits.isEmpty) digits = '0';
    var coefficient = BigInt.parse(digits);
    if (negative && coefficient != BigInt.zero) {
      coefficient = -coefficient;
    }
    return ExactDecimal(coefficient, scale, lexeme: lexeme);
  }
}

/// Current ISK/LP taxes are already percents 0–100. Legacy `tax_rate` is a
/// fraction (`0.10` → `10`). No magnitude heuristic.
class TaxRate {
  static final _zero = ExactDecimal(BigInt.zero, 0);
  static final _hundred = ExactDecimal(BigInt.from(100), 0);

  static ExactDecimal? parseCurrentIsk(Object? raw) {
    final parsed = _finiteDecimal(raw);
    if (parsed == null) return null;
    if (parsed < _zero || parsed > _hundred) return null;
    return parsed;
  }

  static ExactDecimal? parseLegacy(Object? raw) {
    final parsed = _finiteDecimal(raw);
    if (parsed == null) return null;
    return (parsed * _hundred)._withoutTrailingZeros();
  }

  static ExactDecimal? _finiteDecimal(Object? raw) {
    if (raw is! num) return null;
    if (raw is double && (raw.isNaN || raw.isInfinite)) return null;
    try {
      return ExactDecimal.fromNum(raw);
    } on FormatException {
      return null;
    }
  }
}
