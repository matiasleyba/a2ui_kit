// The number formats of the charts, as JavaScript's `Intl.NumberFormat`
// ("en-US") writes them.
//
// `formatPlaygroundValue`, `playgroundTickFormatter` and `shortLabel` port
// the playground's `format.ts` (`formatNumber`) and `chart-kit.tsx`
// (`fmtValue`, `tickFormatter`, `shortLabel`); `standardChartFormatter`
// ports `makeFormatter` of CopilotKit's standard Chart (`chart-config.ts`).
// MIT, (c) Atai Barkai.

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/format/currency.dart';
import 'package:a2ui_kit/src/foundation/format/decimal.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// [whole] with a comma between groups of three digits; with [minimum2],
/// only from five digits on (ICU's `min2` grouping of compact numbers).
String _grouped(String whole, {bool minimum2 = false}) {
  if (whole.length < (minimum2 ? 5 : 4)) return whole;
  final out = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return out.toString();
}

/// The digits of [value] (finite) as en-US writes them, without a sign: at
/// most [maxFractionDigits] decimals (at least [minFractionDigits]), times
/// 10^[shift], grouped.
String _digits(
  double value, {
  required int maxFractionDigits,
  int minFractionDigits = 0,
  int shift = 0,
  bool grouping = true,
}) {
  final (:whole, :fraction) = roundedDecimalDigits(
    value.abs(),
    maxFractionDigits,
    shift: shift,
  );
  var kept = fraction;
  while (kept.length > minFractionDigits && kept.endsWith('0')) {
    kept = kept.substring(0, kept.length - 1);
  }
  final text = grouping ? _grouped(whole) : whole;
  return kept.isEmpty ? text : '$text.$kept';
}

/// JavaScript's text of a number `Intl.NumberFormat` cannot round: NaN and
/// the infinities.
String _nonFinite(double value) => value.isNaN
    ? 'NaN'
    : value > 0
    ? '∞'
    : '-∞';

/// [value] as `Intl.NumberFormat("en-US", {maximumFractionDigits})`
/// writes it: grouped, rounded half away from zero, "-0" for a negative
/// value that rounds to zero.
String formatEnNumber(
  double value, {
  int maxFractionDigits = 3,
  int minFractionDigits = 0,
}) {
  if (!value.isFinite) return _nonFinite(value);
  final digits = _digits(
    value,
    maxFractionDigits: maxFractionDigits,
    minFractionDigits: minFractionDigits,
  );
  return '${value.isNegative ? '-' : ''}$digits';
}

const List<String> _compactSuffixes = ['', 'K', 'M', 'B', 'T'];

/// The digits and suffix of [magnitude] in en-US compact notation, at most
/// [maxFractionDigits] decimals, times 10^[shift].
String _compactDigits(
  double magnitude,
  int maxFractionDigits, {
  int shift = 0,
}) {
  var k = 0;
  // The thousands, from the rounded value: 999.96 is "1K", as in ICU.
  for (var pass = 0; pass < 6; pass++) {
    final (:whole, fraction: _) = roundedDecimalDigits(
      magnitude,
      maxFractionDigits,
      shift: shift - 3 * k,
    );
    if (whole.length <= 3 || k == _compactSuffixes.length - 1) break;
    k = ((whole.length - 1) ~/ 3 + k).clamp(0, _compactSuffixes.length - 1);
  }
  final (:whole, :fraction) = roundedDecimalDigits(
    magnitude,
    maxFractionDigits,
    shift: shift - 3 * k,
  );
  final kept = fraction.replaceFirst(RegExp(r'0+$'), '');
  final text = _grouped(whole, minimum2: true);
  return '${kept.isEmpty ? text : '$text.$kept'}${_compactSuffixes[k]}';
}

/// [value] in `Intl.NumberFormat("en-US", {notation: "compact",
/// maximumFractionDigits})`: `1.2K`, `38.4K`, `1M`, `999`.
String formatEnCompact(double value, {int maxFractionDigits = 1}) {
  if (!value.isFinite) return _nonFinite(value);
  final sign = value.isNegative ? '-' : '';
  return '$sign${_compactDigits(value.abs(), maxFractionDigits)}';
}

/// The fraction digits of [code] (2 for USD, 0 for JPY, 3 for BHD), from
/// CLDR's currency data in `package:intl`.
int _currencyDigits(String code) {
  try {
    return NumberFormat.currency(locale: 'en_US', name: code).decimalDigits ??
        2;
  } on Object {
    return 2;
  }
}

/// [value] in `Intl.NumberFormat("en-US", {style: "currency", currency,
/// maximumFractionDigits})`, compact with [compact]: `$4,200`, `$12.50`,
/// `-$16K`, `CHF 12.50`.
String formatEnCurrency(
  double value,
  String currency, {
  int? maxFractionDigits,
  bool compact = false,
}) {
  if (!value.isFinite) return _nonFinite(value);
  final code = currency.toUpperCase();
  final digits = _currencyDigits(code);
  final max = maxFractionDigits ?? digits;
  final sign = value.isNegative ? '-' : '';
  final number = compact
      ? _compactDigits(value.abs(), max)
      : _digits(
          value,
          maxFractionDigits: max,
          minFractionDigits: max < digits ? max : digits,
        );
  return '$sign${englishCurrencyPrefix(code)}$number';
}

/// The playground's `formatNumber` (`format.ts`): [value] in [format],
/// with [unit] after it. A value that is not a finite number is written
/// as text ("" for null).
///
/// - `number`: at most 2 decimals; `compact`: `1.2K`, at most 1 decimal;
/// - `currency`: [currency] with no decimals from 1,000, else 2;
/// - `percent`: the value itself (not × 100), at most 1 decimal, then `%`;
///   a `%` unit is not repeated;
/// - [unit] follows with a space, or straight after when it starts with
///   `%` or `°`.
String formatPlaygroundValue(
  Object? value, {
  A2uiValueFormat format = A2uiValueFormat.number,
  String? unit,
  String currency = 'USD',
}) {
  if (value is! num || !value.isFinite) {
    return value == null ? '' : jsText(value);
  }
  final v = value.toDouble();
  final out = switch (format) {
    A2uiValueFormat.currency => formatEnCurrency(
      v,
      currency,
      maxFractionDigits: v.abs() >= 1000 ? 0 : 2,
    ),
    A2uiValueFormat.percent => '${formatEnNumber(v, maxFractionDigits: 1)}%',
    A2uiValueFormat.compact => formatEnCompact(v),
    A2uiValueFormat.number => formatEnNumber(v, maxFractionDigits: 2),
  };
  var suffix = unit;
  if (format == A2uiValueFormat.percent && suffix?.trim() == '%') {
    suffix = null;
  }
  if (suffix == null || suffix.isEmpty) return out;
  final tight = suffix.startsWith('%') || suffix.startsWith('°');
  return '$out${tight ? '' : ' '}$suffix';
}

/// The playground's `fmtValue`: [value] in [format] (number when null).
String fmtValue(Object? value, [A2uiValueFormat? format, String? unit]) =>
    formatPlaygroundValue(
      value,
      format: format ?? A2uiValueFormat.number,
      unit: unit,
    );

/// The playground's `tickFormatter`: short axis ticks: `$1.2K` for
/// currency (no unit), `34%` for percent, compact from 1,000 with the
/// [unit] otherwise (`1.4M ms`).
String Function(double value) playgroundTickFormatter([
  A2uiValueFormat? format,
  String? unit,
]) => (v) {
  if (format == A2uiValueFormat.currency) {
    final compact = formatPlaygroundValue(
      v.abs(),
      format: A2uiValueFormat.compact,
    );
    return '${v < 0 ? '-' : ''}\$$compact';
  }
  if (format == A2uiValueFormat.percent) {
    return formatPlaygroundValue(v, format: A2uiValueFormat.percent);
  }
  return formatPlaygroundValue(
    v,
    format: v.abs() >= 1000 ? A2uiValueFormat.compact : A2uiValueFormat.number,
    unit: unit,
  );
};

/// The playground's `shortLabel`: [value] as text, cut to [max] characters
/// with an ellipsis.
String shortLabel(Object? value, [int max = 14]) {
  final text = value == null ? '' : jsText(value);
  return text.length > max ? '${text.substring(0, max - 1)}…' : text;
}

/// The value formatter of CopilotKit's standard Chart (`makeFormatter`):
/// en-US with no decimals (percent: 1), compact from 10,000 ("$1.6K" is
/// never written: "$16K"); `percent` reads fractions (0.25 is "25%");
/// [currency] is USD by default. A malformed currency code falls back to
/// plain numbers, as `Intl.NumberFormat` throws for it. Null when there is
/// no [format]. A value that is not a number is written as text.
String Function(Object? value)? standardChartFormatter(
  ChartFormat? format,
  String? currency,
) {
  if (format == null) return null;
  final code = currency ?? 'USD';
  String formatOf(double v, {required bool compact}) {
    if (!v.isFinite) return _nonFinite(v);
    final sign = v.isNegative ? '-' : '';
    switch (format) {
      case ChartFormat.currency:
        if (!isCurrencyCode(code)) return formatEnNumber(v);
        return formatEnCurrency(
          v,
          code,
          maxFractionDigits: 0,
          compact: compact,
        );
      case ChartFormat.percent:
        final digits = compact
            ? _compactDigits(v.abs(), 1, shift: 2)
            : _digits(v, maxFractionDigits: 1, shift: 2);
        return '$sign$digits%';
      case ChartFormat.number:
        return compact
            ? formatEnCompact(v, maxFractionDigits: 0)
            : formatEnNumber(v, maxFractionDigits: 0);
    }
  }

  return (value) => switch (value) {
    final num n => formatOf(n.toDouble(), compact: n.abs() >= 10000),
    null => '',
    _ => jsText(value),
  };
}

/// The text a recharts axis or tooltip shows for [value] without a
/// formatter: JavaScript's `String(value)`.
String rechartsText(Object? value) => value is num
    ? jsNumberString(value)
    : value == null
    ? ''
    : jsText(value);

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/format.ts, chart-kit.tsx; packages/shared/src/generative-ui/standard/chart-config.ts
