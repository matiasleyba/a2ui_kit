// The decimal arithmetic recharts' tick maths runs on.
//
// recharts 3.10.1 computes its ticks with `decimal.js-light` (es6/util/scale/
// getNiceTickValues.js:12, es6/util/scale/util/arithmetic.js:6), which
// CopilotKit's lockfile pins at 2.5.1. [JsDecimal] stands in for the part of
// it those two files use: a number read from its JavaScript text, `add`,
// `sub`, `mul`, `div`, `mod`, `pow` of ten, the comparisons, `isint` and
// `toNumber`.
//
// decimal.js-light 2.5.1 (MIT, (c) Michael Mclaughlin), read from its
// published source: `precision: 20` (decimal.js:31); `rounding: 4`
// (decimal.js:49) applies only to `toDecimalPlaces`, `toFixed` and the like,
// "not to arithmetic operations, which are simply truncated at the required
// precision" (README.md:21). So every result here is truncated toward zero
// to 20 significant digits: `round(x, sd, rm)` truncates when `rm` is absent
// (decimal.js:1546-1550, :1588), and `add` (:998), `subtract` (:1785),
// `times` (:605) and `divide` (:1261) call it without one. `mod` is
// `x.minus(trunc(x / y) * y)` (:369-389). The operand capping of `add` and
// `subtract` for exponents far apart (:954-961, :1712-1721) keeps a non-zero
// word below the 20th digit, so their truncated results equal the exact
// ones' truncation, which is what is computed here.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// A decimal number `mantissa × 10^exponent`, as decimal.js-light holds
/// one: exact digits, results truncated to [precision] significant digits.
@immutable
class JsDecimal implements Comparable<JsDecimal> {
  JsDecimal._(BigInt mantissa, int exponent)
    : this._normal(_strip(mantissa, exponent));

  JsDecimal._normal((BigInt, int) value)
    : mantissa = value.$1,
      exponent = value.$2;

  /// [value] as `new Decimal(value)` reads a number: the digits of its
  /// JavaScript text (the shortest that reads back as [value]).
  factory JsDecimal.fromNum(num value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'not a finite number');
    }
    return JsDecimal.parse(value.toDouble().toString());
  }

  /// The decimal written [text] (`-1.5e-7`, `120`, `0.05`).
  factory JsDecimal.parse(String text) {
    final match = _decimalText.firstMatch(text.trim());
    if (match == null) throw FormatException('not a decimal', text);
    final negative = match[1] == '-';
    final whole = match[2]!;
    final fraction = match[3] ?? '';
    final exponent = int.parse(match[4] ?? '0') - fraction.length;
    var mantissa = BigInt.parse('$whole$fraction');
    if (negative) mantissa = -mantissa;
    return JsDecimal._(mantissa, exponent);
  }

  /// 10^[power] (`new Decimal(10).pow(power)`).
  factory JsDecimal.pow10(int power) => JsDecimal._(BigInt.one, power);

  /// [mantissa] × 10^[exponent] truncated toward zero to [precision]
  /// significant digits (decimal.js-light's `round(x, sd)` without a
  /// rounding mode, decimal.js:1546-1550, :1588).
  factory JsDecimal._truncated(BigInt mantissa, int exponent) {
    final digits = _digits(mantissa);
    if (mantissa == BigInt.zero || digits <= precision) {
      return JsDecimal._(mantissa, exponent);
    }
    final drop = digits - precision;
    final kept = mantissa.abs() ~/ _pow10(drop);
    return JsDecimal._(mantissa.isNegative ? -kept : kept, exponent + drop);
  }

  /// Zero.
  static final JsDecimal zero = JsDecimal._(BigInt.zero, 0);

  /// The significant digits each result keeps (decimal.js-light's default
  /// `precision`).
  static const int precision = 20;

  /// The digits, without trailing zeros.
  final BigInt mantissa;

  /// The power of ten [mantissa] is scaled by.
  final int exponent;

  static final BigInt _ten = BigInt.from(10);

  static (BigInt, int) _strip(BigInt mantissa, int exponent) {
    if (mantissa == BigInt.zero) return (BigInt.zero, 0);
    var m = mantissa;
    var e = exponent;
    while (m.remainder(_ten) == BigInt.zero) {
      m = m ~/ _ten;
      e++;
    }
    return (m, e);
  }

  static BigInt _pow10(int n) => _ten.pow(n);

  static int _digits(BigInt m) => m.abs().toString().length;

  /// This plus [other], truncated (decimal.js:998).
  JsDecimal operator +(JsDecimal other) {
    final e = math.min(exponent, other.exponent);
    final a = mantissa * _pow10(exponent - e);
    final b = other.mantissa * _pow10(other.exponent - e);
    return JsDecimal._truncated(a + b, e);
  }

  /// This minus [other], truncated (decimal.js:1785).
  JsDecimal operator -(JsDecimal other) => this + other.negate();

  /// This times [other], truncated (decimal.js:605).
  JsDecimal operator *(JsDecimal other) => JsDecimal._truncated(
    mantissa * other.mantissa,
    exponent + other.exponent,
  );

  /// This divided by [other] (not zero), truncated to [precision] digits
  /// (decimal.js:1261: the long division's digits, then `round(q, pr)`).
  JsDecimal operator /(JsDecimal other) {
    if (other.mantissa == BigInt.zero) {
      throw ArgumentError.value(other, 'other', 'division by zero');
    }
    if (mantissa == BigInt.zero) return zero;
    // A truncated quotient of at least precision + 1 digits: truncating it
    // again at precision gives the exact quotient's truncation.
    final shift = math.max(
      0,
      precision + 1 + _digits(other.mantissa) - _digits(mantissa),
    );
    final quotient = mantissa.abs() * _pow10(shift) ~/ other.mantissa.abs();
    final value = JsDecimal._truncated(
      quotient,
      exponent - other.exponent - shift,
    );
    return mantissa.isNegative != other.mantissa.isNegative
        ? value.negate()
        : value;
  }

  /// This modulo [other]: the remainder of the truncated quotient, so it
  /// keeps this number's sign, truncated (decimal.js-light's `mod`,
  /// decimal.js:369-389).
  JsDecimal remainder(JsDecimal other) {
    if (other.mantissa == BigInt.zero) {
      throw ArgumentError.value(other, 'other', 'division by zero');
    }
    final e = math.min(exponent, other.exponent);
    final a = mantissa * _pow10(exponent - e);
    final b = other.mantissa * _pow10(other.exponent - e);
    final q = a ~/ b;
    return JsDecimal._truncated(a - q * b, e);
  }

  /// This with the other sign.
  JsDecimal negate() => JsDecimal._(-mantissa, exponent);

  /// This without its sign.
  JsDecimal abs() => mantissa.isNegative ? negate() : this;

  /// Whether this is a whole number (`isint`).
  bool get isInteger => exponent >= 0;

  /// Whether this is below zero.
  bool get isNegative => mantissa.isNegative;

  /// The power of ten of the leading digit: `floor(log10(|x|))` exactly.
  int get leadingPower => _digits(mantissa) - 1 + exponent;

  /// The nearest double (`toNumber`, `+x.toString()`).
  double toDouble() => double.parse(toString());

  @override
  int compareTo(JsDecimal other) {
    final e = math.min(exponent, other.exponent);
    final a = mantissa * _pow10(exponent - e);
    final b = other.mantissa * _pow10(other.exponent - e);
    return a.compareTo(b);
  }

  /// Whether this is less than [other] (`lt`).
  bool operator <(JsDecimal other) => compareTo(other) < 0;

  /// Whether this is at most [other] (`lte`).
  bool operator <=(JsDecimal other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is JsDecimal &&
      other.mantissa == mantissa &&
      other.exponent == exponent;

  @override
  int get hashCode => Object.hash(mantissa, exponent);

  /// The digits in exponent notation, which `double.parse` reads exactly.
  @override
  String toString() => mantissa == BigInt.zero ? '0' : '${mantissa}e$exponent';

  static final RegExp _decimalText = RegExp(
    r'^([+-]?)(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );
}

/// recharts' `getDigitCount` (es6/util/scale/util/arithmetic.js:17-25):
/// `Math.floor(new Decimal(value).abs().log(10).toNumber()) + 1`, 1 for 0.
///
/// The logarithm is read back as a double before the floor, so a value a
/// little under a power of ten whose logarithm rounds to that whole number
/// counts the higher digit count (0.09999999999999998 counts 0, as 0.1
/// does). That is reproduced: the exact exponent, one more where the
/// double nearest the logarithm is the next whole number.
///
/// decimal.js-light's `log` divides two natural logarithms worked to 25
/// digits and truncates the quotient to 20 (decimal.js:318-349, "the
/// maximum error of the result is 1 ulp"); that error is 10^-19 of the
/// logarithm, under the 2^-53 a double keeps, so it decides nothing the
/// exact logarithm read back as a double does not.
int rechartsDigitCount(double value) {
  if (value == 0) return 1;
  final d = JsDecimal.fromNum(value).abs();
  final power = d.leadingPower;
  final next = power + 1;
  if (next != 0) {
    // How far log10(d) is under `next`: log10(10^next / d).
    final ratio = ((JsDecimal.pow10(next) - d) / d).toDouble();
    final gap = _log1p(ratio) / math.ln10;
    // Half the gap between `next` and the double beside it on the side of
    // log10(d).
    final magnitude = next.abs().toDouble();
    final binary = (math.log(magnitude) / math.ln2).floor();
    final powerOfTwo = math.pow(2, binary).toDouble() == magnitude;
    // Under a positive power of two the doubles are twice as dense.
    final spacing = next > 0 && powerOfTwo
        ? math.pow(2, binary - 53).toDouble()
        : math.pow(2, binary - 52).toDouble();
    if (gap < spacing / 2) return next + 1;
  }
  return power + 1;
}

double _log1p(double x) => x.abs() < 1e-4 ? x - x * x / 2 : math.log(1 + x);

// PORT STATUS: confidence=high todos=0 upstream=decimal.js-light@2.5.1
