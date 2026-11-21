// A port of the formatting and logic functions of CopilotKit's function
// library (`BASIC_FUNCTIONS`, `dateOf`, `formatDatePattern` and
// `pluralCategory` in packages/core/src/generative-ui/functions.ts, MIT,
// (c) Atai Barkai): formatNumber, formatCurrency, formatDate, pluralize,
// and, or and not. Where CopilotKit asks JavaScript's `Intl`, this asks
// `package:intl`.

import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/foundation/format/currency.dart';
import 'package:a2ui_kit/src/foundation/format/decimal.dart';
import 'package:a2ui_kit/src/functions/calc.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:intl/date_symbol_data_local.dart' show dateTimeSymbolMap;
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';

/// The boolean of a DynamicBoolean, as CopilotKit's `truthOf` reads it:
/// JavaScript's `Boolean()`, except that a validation result counts as its
/// `valid`.
bool truthOf(Object? value) => calcTruth(value);

/// The `package:intl` form of the BCP 47 [locale], such as `en_US` for
/// `en-US`; `en_US` when `package:intl` has no number data for it.
String intlLocaleOf(String locale) {
  try {
    return Intl.verifiedLocale(
          Intl.canonicalizedLocale(locale),
          NumberFormat.localeExists,
          onFailure: (_) => 'en_US',
        ) ??
        'en_US';
  } on Object {
    return 'en_US';
  }
}

/// A date from an ISO string, a timestamp in milliseconds, or a [DateTime],
/// in local time, as CopilotKit's `dateOf` reads one. A bare `yyyy-MM-dd`
/// is local midnight. Throws when [value] is none of these.
DateTime dateOf(Object? value) {
  final date = switch (value) {
    final DateTime d => d.toLocal(),
    // JavaScript's TimeClip: a finite time within 8.64e15 ms, truncated.
    final num n when n.isFinite && n.abs() <= 8.64e15 =>
      DateTime.fromMillisecondsSinceEpoch(n.truncate()),
    final String s => _parseDate(_dateOnly.hasMatch(s) ? '${s}T00:00' : s),
    _ => null,
  };
  if (date == null) throw A2uiExpressionError('value must be a date');
  return date;
}

final RegExp _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// A year, or a year and month, which JavaScript reads as UTC.
final RegExp _yearMonth = RegExp(r'^([+-]\d{6}|\d{4})(?:-(\d{2}))?$');

DateTime? _parseDate(String text) {
  final short = _yearMonth.firstMatch(text);
  if (short != null) {
    final month = int.parse(short[2] ?? '1');
    if (month < 1 || month > 12) return null;
    return DateTime.utc(int.parse(short[1]!), month).toLocal();
  }
  return DateTime.tryParse(text)?.toLocal();
}

String _pad(int value, int width) => '$value'.padLeft(width, '0');

/// A TR35 field is a run of one letter ("EEE" is one abbreviated weekday,
/// not three), and text in single quotes is literal. Letters that are not
/// fields stay as they are.
final RegExp _dateField = RegExp(r"([A-Za-z])\1*|'(?:[^']|'')*'");

Map<String, DateSymbols>? _dateSymbols;

DateSymbols _dateSymbolsFor(String locale) {
  final symbols = _dateSymbols ??= dateTimeSymbolMap();
  return symbols[locale] ??
      symbols[locale.split('_').first] ??
      symbols['en_US'] ??
      symbols['en']!;
}

/// [date] written with the TR35 [pattern], as CopilotKit's
/// `formatDatePattern` writes it: `y`, `M`, `d`, `E`, `H`, `h`, `m`, `s`
/// and `a` fields, quoted literals, and other letters kept. Month and
/// weekday names are the [locale]'s (a `package:intl` locale).
String formatDatePattern(DateTime date, String pattern, String locale) {
  final hours12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  String numeric(int value, int width) =>
      width >= 2 ? _pad(value, 2) : '$value';
  // Only the text fields need the locale's names.
  DateSymbols names() => _dateSymbolsFor(locale);
  // DateSymbols lists weekdays from Sunday; DateTime numbers Monday as 1.
  final weekday = date.weekday % 7;
  return pattern.replaceAllMapped(_dateField, (match) {
    final token = match[0]!;
    if (token.startsWith("'")) {
      return token.substring(1, token.length - 1).replaceAll("''", "'");
    }
    final width = token.length;
    return switch (token[0]) {
      'y' => width == 2 ? _pad(date.year % 100, 2) : '${date.year}',
      'M' when width >= 4 => names().STANDALONEMONTHS[date.month - 1],
      'M' when width == 3 => names().STANDALONESHORTMONTHS[date.month - 1],
      'M' => numeric(date.month, width),
      'd' => numeric(date.day, width),
      'E' when width >= 4 => names().STANDALONEWEEKDAYS[weekday],
      'E' => names().STANDALONESHORTWEEKDAYS[weekday],
      'H' => numeric(date.hour, width),
      'h' => numeric(hours12, width),
      'm' => _pad(date.minute, 2),
      's' => _pad(date.second, 2),
      'a' => date.hour < 12 ? 'AM' : 'PM',
      _ => token,
    };
  });
}

/// The CLDR plural category of [value] in [locale] (a `package:intl`
/// locale), as `Intl.PluralRules` selects it.
String pluralCategory(double value, String locale) {
  if (!value.isFinite) return 'other';
  // CLDR's plural operands read the absolute value: -1 is "one" in English.
  return Intl.pluralLogic<String>(
    value.abs(),
    zero: 'zero',
    one: 'one',
    two: 'two',
    few: 'few',
    many: 'many',
    other: 'other',
    locale: locale,
    useExplicitNumberCases: false,
  );
}

/// The fraction digits `Intl.NumberFormat` takes: 0 to 100, floored.
/// `package:intl` keeps 15 at most.
int? _fractionDigits(Object? value) {
  final digits = jsOptionalNumber(value, 'decimals');
  if (digits == null) return null;
  if (digits < 0 || digits > 100) {
    throw A2uiExpressionError('maximumFractionDigits value is out of range.');
  }
  return math.min(digits.floor(), 15);
}

/// The functions by name, formatting for the BCP 47 [locale].
Map<String, Object? Function(Map<String, Object?> args)> copilotKitFormatting(
  String locale,
) {
  final intlLocale = intlLocaleOf(locale);
  final english = intlLocale == 'en' || intlLocale == 'en_US';

  NumberFormat numberFormat(Map<String, Object?> args, String? currency) {
    final digits = _fractionDigits(args['decimals']);
    final NumberFormat format;
    if (currency == null) {
      format = NumberFormat.decimalPattern(intlLocale);
      if (digits != null) {
        format
          ..minimumFractionDigits = digits
          ..maximumFractionDigits = digits;
      }
    } else if (english) {
      format = NumberFormat.currency(
        locale: intlLocale,
        name: currency,
        symbol: englishCurrencyPrefix(currency),
        decimalDigits: digits,
      );
    } else {
      format = NumberFormat.simpleCurrency(
        locale: intlLocale,
        name: currency,
        decimalDigits: digits,
      );
    }
    if (args['grouping'] == false) format.turnOffGrouping();
    return format;
  }

  double numberOf(Object? value) {
    final parsed = jsNumberArg(value);
    if (parsed.isNaN) throw A2uiExpressionError('value must be a number');
    return parsed;
  }

  List<Object?> valuesOf(Object? values) {
    if (values is! List) throw A2uiExpressionError('values must be a list');
    return values;
  }

  // `Intl.NumberFormat` rounds the shortest decimal of the value, half away
  // from zero (1.005 is "1.01"); `package:intl` rounds the binary double
  // (1.00499… is "1.00"). So the value is rounded first, to the format's
  // most fraction digits.
  String formatted(NumberFormat format, double value) =>
      format.format(roundLikeIntl(value, format.maximumFractionDigits));

  return {
    'formatNumber': (args) {
      final parsed = numberOf(args['value']);
      return formatted(numberFormat(args, null), parsed);
    },
    'formatCurrency': (args) {
      final parsed = numberOf(args['value']);
      final currency = args['currency'];
      if (currency is! String || currency.isEmpty) {
        throw A2uiExpressionError('currency must be an ISO 4217 code');
      }
      try {
        if (!isCurrencyCode(currency)) throw FormatException(currency);
        return formatted(numberFormat(args, currency.toUpperCase()), parsed);
      } on Object {
        throw A2uiExpressionError('"$currency" is not a currency code');
      }
    },
    'formatDate': (args) {
      final format = args['format'];
      if (format is! String) {
        throw A2uiExpressionError('format must be a string');
      }
      return formatDatePattern(dateOf(args['value']), format, intlLocale);
    },
    'pluralize': (args) {
      final parsed = numberOf(args['value']);
      final category = pluralCategory(parsed, intlLocale);
      final exact = parsed == 0 ? args['zero'] : null;
      return jsText(exact ?? args[category] ?? args['other']);
    },
    'and': (args) => valuesOf(args['values']).every(truthOf),
    'or': (args) => valuesOf(args['values']).any(truthOf),
    'not': (args) => !truthOf(args['value']),
  };
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/core/src/generative-ui/functions.ts
