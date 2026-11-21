/// The symbols of CLDR's English locale (what `Intl.NumberFormat("en-US")`
/// writes) that differ from the currency code and from `package:intl`'s
/// simple symbols.
const Map<String, String> _englishSymbols = {
  'AUD': r'A$',
  'BRL': r'R$',
  'CAD': r'CA$',
  'CNY': 'CN¥',
  'EUR': '€',
  'GBP': '£',
  'HKD': r'HK$',
  'ILS': '₪',
  'INR': '₹',
  'JPY': '¥',
  'KRW': '₩',
  'MXN': r'MX$',
  'NZD': r'NZ$',
  'PHP': '₱',
  'TWD': r'NT$',
  'USD': r'$',
  'VND': '₫',
  'XAF': 'FCFA',
  'XCD': r'EC$',
  'XOF': 'F${_narrowNoBreakSpace}CFA',
  'XPF': 'CFPF',
};

final RegExp _endsWithLetter = RegExp(r'\p{L}$', unicode: true);

const String _noBreakSpace = '\u{a0}';
const String _narrowNoBreakSpace = '\u{202f}';

/// The English symbol of the ISO 4217 [code] (upper case): `$` for USD,
/// `CA$` for CAD, the code itself for a currency with no symbol.
String englishCurrencySymbol(String code) => _englishSymbols[code] ?? code;

/// What `Intl.NumberFormat("en-US")` writes before a number in [code]: its
/// symbol, set apart by a no-break space when it ends in a letter (ICU's
/// currency spacing: `CHF 12.50`, `$12.50`).
String englishCurrencyPrefix(String code) {
  final symbol = englishCurrencySymbol(code);
  return _endsWithLetter.hasMatch(symbol) ? '$symbol$_noBreakSpace' : symbol;
}

/// Whether [code] has the form of an ISO 4217 code (three letters), which
/// `Intl.NumberFormat` needs; another code throws a `RangeError` there.
bool isCurrencyCode(String code) => _currencyCode.hasMatch(code);

final RegExp _currencyCode = RegExp(r'^[A-Za-z]{3}$');

// PORT STATUS: confidence=high todos=0 upstream=none (CLDR's English locale)
