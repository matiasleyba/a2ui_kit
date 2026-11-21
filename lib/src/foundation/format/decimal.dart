/// Decimal rounding as JavaScript's `Intl.NumberFormat` does it.
///
/// ICU rounds the shortest decimal that reads back as the number (the text
/// `Number.prototype.toString` writes), half away from zero. So 1.005 is
/// "1.01" at two decimals, though the binary double just below 1.005 that
/// it stands for would round down, as `toStringAsFixed` and `package:intl`
/// round it ("1.00").
library;

/// The digits of [magnitude] (finite, not negative) at [fractionDigits]
/// decimals, rounded as ICU rounds: `whole` has no leading zeros (at least
/// "0") and `fraction` has exactly [fractionDigits] digits.
///
/// With [shift], the digits are those of [magnitude] × 10^[shift], shifted
/// in decimal, so exactly: a percentage is shift 2, thousands are shift -3.
({String whole, String fraction}) roundedDecimalDigits(
  num magnitude,
  int fractionDigits, {
  int shift = 0,
}) {
  assert(magnitude.isFinite && !magnitude.isNegative, 'a finite magnitude');
  assert(fractionDigits >= 0, 'fraction digits');
  final shortest = _shortestDecimal.firstMatch(magnitude.toString())!;
  var digits = '${shortest[1]}${shortest[2] ?? ''}';
  // The count of digits before the decimal point.
  var point = shortest[1]!.length + int.parse(shortest[3] ?? '0') + shift;
  if (point < 0) {
    digits = '${'0' * -point}$digits';
    point = 0;
  }
  if (point > digits.length) digits = digits.padRight(point, '0');
  final keep = point + fractionDigits;
  if (keep < digits.length) {
    final up = digits.codeUnitAt(keep) >= 0x35; // '5'
    final kept = digits.substring(0, keep).split('');
    if (up) {
      var i = kept.length - 1;
      for (; i >= 0 && kept[i] == '9'; i--) {
        kept[i] = '0';
      }
      if (i >= 0) {
        kept[i] = String.fromCharCode(kept[i].codeUnitAt(0) + 1);
      } else {
        kept.insert(0, '1');
        point++;
      }
    }
    digits = kept.join();
  }
  digits = digits.padRight(point + fractionDigits, '0');
  var whole = digits.substring(0, point).replaceFirst(RegExp('^0+'), '');
  if (whole.isEmpty) whole = '0';
  return (whole: whole, fraction: digits.substring(point));
}

/// [value] rounded to [fractionDigits] decimals as ICU rounds it, as a
/// double: hand it to `package:intl` at that many decimals and it writes
/// what `Intl.NumberFormat` writes. A value that is not finite stays as it
/// is; a negative value that rounds to zero is -0.0.
double roundLikeIntl(double value, int fractionDigits) {
  if (!value.isFinite) return value;
  final (:whole, :fraction) = roundedDecimalDigits(value.abs(), fractionDigits);
  final magnitude = double.parse(fraction.isEmpty ? whole : '$whole.$fraction');
  return value.isNegative ? -magnitude : magnitude;
}

/// Dart's shortest round-trip text of a non-negative number: digits, an
/// optional fraction and an optional exponent (`1e+21`, `1.5e-7`).
final RegExp _shortestDecimal = RegExp(r'^(\d+)(?:\.(\d+))?(?:e([+-]?\d+))?$');

// PORT STATUS: confidence=high todos=0 upstream=none
