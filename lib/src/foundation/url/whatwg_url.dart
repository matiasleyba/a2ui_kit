// The URL Standard's basic URL parser and URL serializer (WHATWG, sections
// 3.5 to 4.5), as `new URL(url, base)` runs them in a browser: a port of
// whatwg-url@16.0.1, the standard's reference implementation, which jsdom (the
// environment of CopilotKit's openUrl tests) uses (lib/url-state-machine.js,
// lib/percent-encoding.js, lib/infra.js, lib/URL-impl.js; MIT, (c) Sebastian
// Mayr; fetched from registry.npmjs.org and checked against the sha512 in
// CopilotKit's pnpm-lock.yaml:28264). Each function names its lines.
//
// It runs as the URL constructor runs it: UTF-8, and no state override (the
// setters' `stateOverride` branches are left out, since nothing here sets a
// URL's parts). Validation errors (`parseError`) change no result, so they
// are not kept.

import 'dart:convert';

/// A URL record (URL Standard section 4.1): what [WhatwgUrl.parse] gives.
final class WhatwgUrl {
  WhatwgUrl._();

  /// The scheme, lowercase, without its colon.
  String scheme = '';

  /// The username, percent-encoded.
  String username = '';

  /// The password, percent-encoded.
  String password = '';

  /// Null, a domain, an opaque host or the empty host (a `String`), an IPv4
  /// address (an `int`) or an IPv6 address (eight 16-bit pieces).
  Object? host;

  /// The port, or null for none or the scheme's default.
  int? port;

  /// The path: a list of segments, or a `String` (an opaque path).
  Object path = <String>[];

  /// The query, without its `?`, or null.
  String? query;

  /// The fragment, without its `#`, or null.
  String? fragment;

  /// `URL.prototype.protocol`: the scheme and a colon.
  String get protocol => '$scheme:';

  /// Whether the path is opaque (a URL such as `mailto:a@b.co`).
  bool get hasOpaquePath => path is String;

  List<String> get _segments => path as List<String>;

  /// `URL.prototype.href`: the URL serializer (url-state-machine.js:1145-1179,
  /// :1192-1202).
  String get href {
    final out = StringBuffer('$scheme:');
    final host = this.host;
    if (host != null) {
      out.write('//');
      if (username != '' || password != '') {
        out.write(username);
        if (password != '') out.write(':$password');
        out.write('@');
      }
      out.write(_serializeHost(host));
      if (port != null) out.write(':$port');
    }
    if (host == null &&
        !hasOpaquePath &&
        _segments.length > 1 &&
        _segments[0] == '') {
      out.write('/.');
    }
    if (hasOpaquePath) {
      out.write(path);
    } else {
      for (final segment in _segments) {
        out.write('/$segment');
      }
    }
    if (query != null) out.write('?$query');
    if (fragment != null) out.write('#$fragment');
    return out.toString();
  }

  /// `new URL(url, base)` (URL-impl.js:9-22): [url] parsed against [base],
  /// or null where the constructor throws (a base or a URL that does not
  /// parse).
  static WhatwgUrl? parse(String url, [String? base]) {
    WhatwgUrl? parsedBase;
    if (base != null) {
      parsedBase = basicParse(base);
      if (parsedBase == null) return null;
    }
    return basicParse(url, base: parsedBase);
  }

  /// The basic URL parser (url-state-machine.js:504-561, :1246-1257) of
  /// [input] against [base]; null on failure.
  static WhatwgUrl? basicParse(String input, {WhatwgUrl? base}) =>
      _Parser(input, base).run();
}

/// The failure of a parser step (url-state-machine.js:26, `failure`).
final Object _failure = Object();

/// Special schemes and their default ports (url-state-machine.js:17-24).
const Map<String, int?> _specialSchemes = {
  'ftp': 21,
  'file': null,
  'http': 80,
  'https': 443,
  'ws': 80,
  'wss': 443,
};

bool _isSpecialScheme(String scheme) => _specialSchemes.containsKey(scheme);

// Code points (infra.js:5-19; url-state-machine.js:13-15, `p`).
const int _tab = 0x09;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _space = 0x20;
const int _quote = 0x22;
const int _hash = 0x23;
const int _percent = 0x25;
const int _apostrophe = 0x27;
const int _plus = 0x2B;
const int _minus = 0x2D;
const int _dot = 0x2E;
const int _slash = 0x2F;
const int _colon = 0x3A;
const int _semicolon = 0x3B;
const int _less = 0x3C;
const int _equals = 0x3D;
const int _greater = 0x3E;
const int _question = 0x3F;
const int _at = 0x40;
const int _openBracket = 0x5B;
const int _backslash = 0x5C;
const int _closeBracket = 0x5D;
const int _caret = 0x5E;
const int _backtick = 0x60;
const int _openBrace = 0x7B;
const int _pipe = 0x7C;
const int _closeBrace = 0x7D;

bool _isAsciiDigit(int? c) => c != null && c >= 0x30 && c <= 0x39;

bool _isAsciiAlpha(int? c) =>
    c != null && ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A));

bool _isAsciiAlphanumeric(int? c) => _isAsciiAlpha(c) || _isAsciiDigit(c);

bool _isAsciiHex(int? c) =>
    _isAsciiDigit(c) ||
    (c != null && ((c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66)));

int _hexValue(int c) => c <= 0x39 ? c - 0x30 : (c | 0x20) - 0x61 + 10;

/// [c] lowercased if it is an ASCII upper alpha.
int _asciiLower(int c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c;

String _asciiLowercase(String text) =>
    String.fromCharCodes(text.codeUnits.map(_asciiLower));

// Percent-encode sets, on bytes (percent-encoding.js:45-79).
bool _isC0ControlPercentEncode(int c) => c <= 0x1F || c > 0x7E;

bool _isFragmentPercentEncode(int c) =>
    _isC0ControlPercentEncode(c) ||
    const {_space, _quote, _less, _greater, _backtick}.contains(c);

bool _isQueryPercentEncode(int c) =>
    _isC0ControlPercentEncode(c) ||
    const {_space, _quote, _hash, _less, _greater}.contains(c);

bool _isSpecialQueryPercentEncode(int c) =>
    _isQueryPercentEncode(c) || c == _apostrophe;

bool _isPathPercentEncode(int c) =>
    _isQueryPercentEncode(c) ||
    const {_question, _backtick, _openBrace, _closeBrace, _caret}.contains(c);

bool _isUserinfoPercentEncode(int c) =>
    _isPathPercentEncode(c) ||
    const {
      _slash,
      _colon,
      _semicolon,
      _equals,
      _at,
      _openBracket,
      _backslash,
      _closeBracket,
      _pipe,
    }.contains(c);

/// Percent-encodes the byte [c] (percent-encoding.js:9-17).
String _percentEncode(int c) =>
    '%${c.toRadixString(16).toUpperCase().padLeft(2, '0')}';

/// The UTF-8 percent-encoding of the code point [codePoint] with [inSet]
/// (percent-encoding.js:97-116). A lone surrogate encodes as U+FFFD, as
/// `TextEncoder` and Dart's `utf8` both write it.
String _utf8PercentEncodeCodePoint(int codePoint, bool Function(int) inSet) {
  final out = StringBuffer();
  for (final byte in utf8.encode(String.fromCharCode(codePoint))) {
    out.write(inSet(byte) ? _percentEncode(byte) : String.fromCharCode(byte));
  }
  return out.toString();
}

/// The UTF-8 percent-encoding of [input] (percent-encoding.js:120-131).
String _utf8PercentEncodeString(String input, bool Function(int) inSet) => [
  for (final codePoint in input.runes)
    _utf8PercentEncodeCodePoint(codePoint, inSet),
].join();

/// Percent-decodes [input]'s UTF-8 bytes (percent-encoding.js:19-43).
List<int> _percentDecodeString(String input) {
  final bytes = utf8.encode(input);
  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    final byte = bytes[i];
    if (byte != _percent ||
        i + 2 >= bytes.length ||
        !_isAsciiHex(bytes[i + 1]) ||
        !_isAsciiHex(bytes[i + 2])) {
      out.add(byte);
    } else {
      out.add(_hexValue(bytes[i + 1]) * 16 + _hexValue(bytes[i + 2]));
      i += 2;
    }
  }
  return out;
}

/// url-state-machine.js:58-60.
bool _containsForbiddenHostCodePoint(String text) => text.runes.any(
  (c) =>
      c == 0x00 ||
      c == _tab ||
      c == _lineFeed ||
      c == _carriageReturn ||
      c == _space ||
      c == _hash ||
      c == _slash ||
      c == _colon ||
      c == _less ||
      c == _greater ||
      c == _question ||
      c == _at ||
      c == _openBracket ||
      c == _backslash ||
      c == _closeBracket ||
      c == _caret ||
      c == _pipe,
);

/// url-state-machine.js:62-64.
bool _containsForbiddenDomainCodePoint(String text) =>
    _containsForbiddenHostCodePoint(text) ||
    text.runes.any((c) => c <= 0x1F || c == _percent || c == 0x7F);

/// The IPv4 number parser (url-state-machine.js:82-114). A `BigInt`, so a
/// long part compares as JavaScript's `parseInt` does with the bounds below.
Object _parseIpv4Number(String text) {
  var input = text;
  if (input.isEmpty) return _failure;
  var radix = 10;
  if (input.length >= 2 &&
      input[0] == '0' &&
      (input[1] == 'x' || input[1] == 'X')) {
    input = input.substring(2);
    radix = 16;
  } else if (input.length >= 2 && input[0] == '0') {
    input = input.substring(1);
    radix = 8;
  }
  if (input.isEmpty) return BigInt.zero;
  final allowed = switch (radix) {
    10 => RegExp(r'^[0-9]+$'),
    16 => RegExp(r'^[0-9A-Fa-f]+$'),
    _ => RegExp(r'^[0-7]+$'),
  };
  if (!allowed.hasMatch(input)) return _failure;
  return BigInt.parse(input, radix: radix);
}

/// The IPv4 parser (url-state-machine.js:116-156).
Object _parseIpv4(String input) {
  final parts = input.split('.');
  if (parts.last == '' && parts.length > 1) parts.removeLast();
  if (parts.length > 4) return _failure;
  final numbers = <BigInt>[];
  for (final part in parts) {
    final n = _parseIpv4Number(part);
    if (identical(n, _failure)) return _failure;
    numbers.add(n as BigInt);
  }
  final byteMax = BigInt.from(255);
  for (var i = 0; i < numbers.length - 1; i++) {
    if (numbers[i] > byteMax) return _failure;
  }
  if (numbers.last >= BigInt.from(256).pow(5 - numbers.length)) {
    return _failure;
  }
  var ipv4 = numbers.removeLast();
  for (var counter = 0; counter < numbers.length; counter++) {
    ipv4 += numbers[counter] * BigInt.from(256).pow(3 - counter);
  }
  return ipv4.toInt();
}

/// The IPv4 serializer (url-state-machine.js:158-171).
String _serializeIpv4(int address) {
  var output = '';
  var n = address;
  for (var i = 1; i <= 4; i++) {
    output = '${n % 256}$output';
    if (i != 4) output = '.$output';
    n ~/= 256;
  }
  return output;
}

/// The IPv6 parser (url-state-machine.js:173-300).
Object _parseIpv6(String text) {
  final address = List<int>.filled(8, 0);
  var pieceIndex = 0;
  int? compress;
  var pointer = 0;
  final input = text.runes.toList();
  int? at(int index) =>
      index >= 0 && index < input.length ? input[index] : null;

  if (at(pointer) == _colon) {
    if (at(pointer + 1) != _colon) return _failure;
    pointer += 2;
    pieceIndex++;
    compress = pieceIndex;
  }

  while (pointer < input.length) {
    if (pieceIndex == 8) return _failure;
    if (at(pointer) == _colon) {
      if (compress != null) return _failure;
      pointer++;
      pieceIndex++;
      compress = pieceIndex;
      continue;
    }
    var value = 0;
    var length = 0;
    while (length < 4 && _isAsciiHex(at(pointer))) {
      value = value * 0x10 + _hexValue(at(pointer)!);
      pointer++;
      length++;
    }
    if (at(pointer) == _dot) {
      if (length == 0) return _failure;
      pointer -= length;
      if (pieceIndex > 6) return _failure;
      var numbersSeen = 0;
      while (at(pointer) != null) {
        int? ipv4Piece;
        if (numbersSeen > 0) {
          if (at(pointer) == _dot && numbersSeen < 4) {
            pointer++;
          } else {
            return _failure;
          }
        }
        if (!_isAsciiDigit(at(pointer))) return _failure;
        while (_isAsciiDigit(at(pointer))) {
          final number = at(pointer)! - 0x30;
          if (ipv4Piece == null) {
            ipv4Piece = number;
          } else if (ipv4Piece == 0) {
            return _failure;
          } else {
            ipv4Piece = ipv4Piece * 10 + number;
          }
          if (ipv4Piece > 255) return _failure;
          pointer++;
        }
        address[pieceIndex] = address[pieceIndex] * 0x100 + ipv4Piece!;
        numbersSeen++;
        if (numbersSeen == 2 || numbersSeen == 4) pieceIndex++;
      }
      if (numbersSeen != 4) return _failure;
      break;
    } else if (at(pointer) == _colon) {
      pointer++;
      if (at(pointer) == null) return _failure;
    } else if (at(pointer) != null) {
      return _failure;
    }
    address[pieceIndex] = value;
    pieceIndex++;
  }

  if (compress != null) {
    var swaps = pieceIndex - compress;
    pieceIndex = 7;
    while (pieceIndex != 0 && swaps > 0) {
      final temp = address[compress + swaps - 1];
      address[compress + swaps - 1] = address[pieceIndex];
      address[pieceIndex] = temp;
      pieceIndex--;
      swaps--;
    }
  } else if (pieceIndex != 8) {
    return _failure;
  }
  return address;
}

/// The first of the longest runs of two or more zero pieces, or null
/// (url-state-machine.js:386-414).
int? _compressedPieceIndex(List<int> address) {
  int? longestIndex;
  var longestSize = 1;
  int? foundIndex;
  var foundSize = 0;
  for (var pieceIndex = 0; pieceIndex < address.length; pieceIndex++) {
    if (address[pieceIndex] != 0) {
      if (foundSize > longestSize) {
        longestIndex = foundIndex;
        longestSize = foundSize;
      }
      foundIndex = null;
      foundSize = 0;
    } else {
      foundIndex ??= pieceIndex;
      foundSize++;
    }
  }
  if (foundSize > longestSize) return foundIndex;
  return longestIndex;
}

/// The IPv6 serializer (url-state-machine.js:302-329).
String _serializeIpv6(List<int> address) {
  final out = StringBuffer();
  final compress = _compressedPieceIndex(address);
  var ignore0 = false;
  for (var pieceIndex = 0; pieceIndex <= 7; pieceIndex++) {
    if (ignore0 && address[pieceIndex] == 0) continue;
    ignore0 = false;
    if (compress == pieceIndex) {
      out.write(pieceIndex == 0 ? '::' : ':');
      ignore0 = true;
      continue;
    }
    out.write(address[pieceIndex].toRadixString(16));
    if (pieceIndex != 7) out.write(':');
  }
  return out.toString();
}

/// The host serializer (url-state-machine.js:416-427).
String _serializeHost(Object host) => switch (host) {
  final int ipv4 => _serializeIpv4(ipv4),
  final List<int> ipv6 => '[${_serializeIpv6(ipv6)}]',
  _ => host as String,
};

/// Whether [input] ends in a number (url-state-machine.js:357-376).
bool _endsInANumber(String input) {
  final parts = input.split('.');
  if (parts.last == '') {
    if (parts.length == 1) return false;
    parts.removeLast();
  }
  final last = parts.last;
  if (!identical(_parseIpv4Number(last), _failure)) return true;
  return RegExp(r'^[0-9]+$').hasMatch(last);
}

/// The opaque-host parser (url-state-machine.js:378-384).
Object _parseOpaqueHost(String input) {
  if (_containsForbiddenHostCodePoint(input)) return _failure;
  return _utf8PercentEncodeString(input, _isC0ControlPercentEncode);
}

/// "Domain to ASCII" with beStrict false (url-state-machine.js:429-452), for
/// an ASCII domain: tr46@6.0.0's `toASCII` with whatwg-url's options
/// (index.js:269-316) maps an ASCII domain to its ASCII lowercase (its
/// mapping table, lib/mappingTable.json, maps U+0041-U+005A to a-z and
/// gives every other ASCII code point the status valid), and no ASCII label
/// fails its checks (validateLabel, index.js:70-194: no ASCII code point is
/// a combining mark or in a bidi domain, lib/regexes.js), except one that
/// begins with `xn--`, which is decoded as Punycode and checked as Unicode.
/// The URL Standard says as much (section 3.3, domain to ASCII, step 1: for
/// an ASCII domain with no `xn--` label it is ASCII lowercasing).
Object _domainToAscii(String domain) {
  // TODO(port): UTS #46 processing (tr46@6.0.0, index.js:35-316: its mapping
  // table, NFC, the bidi and joiner rules, Punycode) for a domain with a
  // non-ASCII code point or an `xn--` label; such a host is refused until
  // then, so no host opens that the browser would map to another one.
  if (domain.codeUnits.any((unit) => unit > 0x7F)) return _failure;
  final result = _asciiLowercase(domain);
  if (result.split('.').any((label) => label.startsWith('xn--'))) {
    return _failure;
  }
  if (result.isEmpty) return _failure;
  if (_containsForbiddenDomainCodePoint(result)) return _failure;
  return result;
}

/// The host parser (url-state-machine.js:331-355).
Object _parseHost(String input, {required bool isOpaque}) {
  if (input.startsWith('[')) {
    if (!input.endsWith(']')) return _failure;
    return _parseIpv6(input.substring(1, input.length - 1));
  }
  if (isOpaque) return _parseOpaqueHost(input);
  final domain = utf8.decode(_percentDecodeString(input), allowMalformed: true);
  final asciiDomain = _domainToAscii(domain);
  if (identical(asciiDomain, _failure)) return _failure;
  final ascii = asciiDomain as String;
  if (_endsInANumber(ascii)) return _parseIpv4(ascii);
  return ascii;
}

/// Leading and trailing C0 controls and spaces cut (url-state-machine.js:
/// 454-470).
String _trimControlChars(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && text.codeUnitAt(start) <= 0x20) {
    start++;
  }
  while (end > start && text.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  return text.substring(start, end);
}

/// Every tab and newline removed (url-state-machine.js:472-474).
String _trimTabAndNewline(String text) =>
    text.replaceAll(RegExp('[\t\n\r]'), '');

bool _isSingleDot(String buffer) =>
    buffer == '.' || _asciiLowercase(buffer) == '%2e';

bool _isDoubleDot(String buffer) =>
    const {'..', '%2e.', '.%2e', '%2e%2e'}.contains(_asciiLowercase(buffer));

bool _isWindowsDriveLetterCodePoints(int? first, int? second) =>
    _isAsciiAlpha(first) && (second == _colon || second == _pipe);

bool _isWindowsDriveLetterString(String text) =>
    text.length == 2 &&
    _isAsciiAlpha(text.codeUnitAt(0)) &&
    (text[1] == ':' || text[1] == '|');

bool _isNormalizedWindowsDriveLetter(String text) =>
    text.length == 2 && _isAsciiAlpha(text.codeUnitAt(0)) && text[1] == ':';

enum _State {
  schemeStart,
  scheme,
  noScheme,
  specialRelativeOrAuthority,
  pathOrAuthority,
  relative,
  relativeSlash,
  specialAuthoritySlashes,
  specialAuthorityIgnoreSlashes,
  authority,
  host,
  port,
  file,
  fileSlash,
  fileHost,
  pathStart,
  path,
  opaquePath,
  query,
  fragment,
}

/// What a state's step gives: go on, or fail (no step without a state
/// override ends the parser early with success).
enum _Step { next, fail }

/// The basic URL parser's state machine (url-state-machine.js:504-1143).
final class _Parser {
  _Parser(String text, this.base)
    // url-state-machine.js:526-546.
    : input = _trimTabAndNewline(_trimControlChars(text)).runes.toList();

  final WhatwgUrl? base;
  final WhatwgUrl url = WhatwgUrl._();
  final List<int> input;
  int pointer = 0;
  _State state = _State.schemeStart;
  String buffer = '';
  bool atSignSeen = false;
  bool insideBrackets = false;
  bool passwordTokenSeen = false;

  int? at(int index) =>
      index >= 0 && index < input.length ? input[index] : null;

  bool get special => _isSpecialScheme(url.scheme);

  List<String> get segments => url._segments;

  /// url-state-machine.js:548-560.
  WhatwgUrl? run() {
    for (; pointer <= input.length; pointer++) {
      if (step(at(pointer)) == _Step.fail) return null;
    }
    return url;
  }

  _Step step(int? c) => switch (state) {
    _State.schemeStart => schemeStart(c),
    _State.scheme => schemeState(c),
    _State.noScheme => noScheme(c),
    _State.specialRelativeOrAuthority => specialRelativeOrAuthority(c),
    _State.pathOrAuthority => pathOrAuthority(c),
    _State.relative => relative(c),
    _State.relativeSlash => relativeSlash(c),
    _State.specialAuthoritySlashes => specialAuthoritySlashes(c),
    _State.specialAuthorityIgnoreSlashes => specialAuthorityIgnoreSlashes(c),
    _State.authority => authority(c),
    _State.host => hostState(c),
    _State.port => portState(c),
    _State.file => file(c),
    _State.fileSlash => fileSlash(c),
    _State.fileHost => fileHost(c),
    _State.pathStart => pathStart(c),
    _State.path => pathState(c),
    _State.opaquePath => opaquePath(c),
    _State.query => queryState(c),
    _State.fragment => fragmentState(c),
  };

  /// url-state-machine.js:563-576.
  _Step schemeStart(int? c) {
    if (_isAsciiAlpha(c)) {
      buffer += String.fromCharCode(_asciiLower(c!));
      state = _State.scheme;
    } else {
      state = _State.noScheme;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:578-633.
  _Step schemeState(int? c) {
    if (_isAsciiAlphanumeric(c) || c == _plus || c == _minus || c == _dot) {
      buffer += String.fromCharCode(_asciiLower(c!));
    } else if (c == _colon) {
      url.scheme = buffer;
      buffer = '';
      if (url.scheme == 'file') {
        state = _State.file;
      } else if (special && base != null && base!.scheme == url.scheme) {
        state = _State.specialRelativeOrAuthority;
      } else if (special) {
        state = _State.specialAuthoritySlashes;
      } else if (at(pointer + 1) == _slash) {
        state = _State.pathOrAuthority;
        pointer++;
      } else {
        url.path = '';
        state = _State.opaquePath;
      }
    } else {
      buffer = '';
      state = _State.noScheme;
      pointer = -1;
    }
    return _Step.next;
  }

  /// url-state-machine.js:635-653.
  _Step noScheme(int? c) {
    final base = this.base;
    if (base == null || (base.hasOpaquePath && c != _hash)) {
      return _Step.fail;
    } else if (base.hasOpaquePath && c == _hash) {
      url
        ..scheme = base.scheme
        ..path = base.path
        ..query = base.query
        ..fragment = '';
      state = _State.fragment;
    } else if (base.scheme == 'file') {
      state = _State.file;
      pointer--;
    } else {
      state = _State.relative;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:655-666.
  _Step specialRelativeOrAuthority(int? c) {
    if (c == _slash && at(pointer + 1) == _slash) {
      state = _State.specialAuthorityIgnoreSlashes;
      pointer++;
    } else {
      state = _State.relative;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:668-677.
  _Step pathOrAuthority(int? c) {
    if (c == _slash) {
      state = _State.authority;
    } else {
      state = _State.path;
      pointer--;
    }
    return _Step.next;
  }

  void copyAuthorityFromBase() {
    final base = this.base!;
    url
      ..username = base.username
      ..password = base.password
      ..host = base.host
      ..port = base.port;
  }

  /// url-state-machine.js:679-708.
  _Step relative(int? c) {
    final base = this.base!;
    url.scheme = base.scheme;
    if (c == _slash) {
      state = _State.relativeSlash;
    } else if (special && c == _backslash) {
      state = _State.relativeSlash;
    } else {
      copyAuthorityFromBase();
      url
        ..path = List<String>.of(base._segments)
        ..query = base.query;
      if (c == _question) {
        url.query = '';
        state = _State.query;
      } else if (c == _hash) {
        url.fragment = '';
        state = _State.fragment;
      } else if (c != null) {
        url.query = null;
        if (segments.isNotEmpty) segments.removeLast();
        state = _State.path;
        pointer--;
      }
    }
    return _Step.next;
  }

  /// url-state-machine.js:710-728.
  _Step relativeSlash(int? c) {
    if (special && (c == _slash || c == _backslash)) {
      state = _State.specialAuthorityIgnoreSlashes;
    } else if (c == _slash) {
      state = _State.authority;
    } else {
      copyAuthorityFromBase();
      state = _State.path;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:730-741.
  _Step specialAuthoritySlashes(int? c) {
    if (c == _slash && at(pointer + 1) == _slash) {
      state = _State.specialAuthorityIgnoreSlashes;
      pointer++;
    } else {
      state = _State.specialAuthorityIgnoreSlashes;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:743-752.
  _Step specialAuthorityIgnoreSlashes(int? c) {
    if (c != _slash && c != _backslash) {
      state = _State.authority;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:754-793. The buffer's code points are walked as
  /// code points, as the standard says ("for each codePoint in buffer");
  /// whatwg-url indexes them by UTF-16 unit (:763-765), which differs only
  /// for a character beyond the BMP in a username or password.
  _Step authority(int? c) {
    if (c == _at) {
      if (atSignSeen) buffer = '%40$buffer';
      atSignSeen = true;
      for (final codePoint in buffer.runes) {
        if (codePoint == _colon && !passwordTokenSeen) {
          passwordTokenSeen = true;
          continue;
        }
        final encoded = _utf8PercentEncodeCodePoint(
          codePoint,
          _isUserinfoPercentEncode,
        );
        if (passwordTokenSeen) {
          url.password += encoded;
        } else {
          url.username += encoded;
        }
      }
      buffer = '';
    } else if (c == null ||
        c == _slash ||
        c == _question ||
        c == _hash ||
        (special && c == _backslash)) {
      if (atSignSeen && buffer == '') return _Step.fail;
      pointer -= buffer.runes.length + 1;
      buffer = '';
      state = _State.host;
    } else {
      buffer += String.fromCharCode(c);
    }
    return _Step.next;
  }

  /// url-state-machine.js:795-851.
  _Step hostState(int? c) {
    if (c == _colon && !insideBrackets) {
      if (buffer == '') return _Step.fail;
      final host = _parseHost(buffer, isOpaque: !special);
      if (identical(host, _failure)) return _Step.fail;
      url.host = host;
      buffer = '';
      state = _State.port;
    } else if (c == null ||
        c == _slash ||
        c == _question ||
        c == _hash ||
        (special && c == _backslash)) {
      pointer--;
      if (special && buffer == '') return _Step.fail;
      final host = _parseHost(buffer, isOpaque: !special);
      if (identical(host, _failure)) return _Step.fail;
      url.host = host;
      buffer = '';
      state = _State.pathStart;
    } else {
      if (c == _openBracket) insideBrackets = true;
      if (c == _closeBracket) insideBrackets = false;
      buffer += String.fromCharCode(c);
    }
    return _Step.next;
  }

  /// url-state-machine.js:853-882.
  _Step portState(int? c) {
    if (_isAsciiDigit(c)) {
      buffer += String.fromCharCode(c!);
    } else if (c == null ||
        c == _slash ||
        c == _question ||
        c == _hash ||
        (special && c == _backslash)) {
      if (buffer != '') {
        final port = BigInt.parse(buffer);
        if (port > BigInt.from(65535)) return _Step.fail;
        final value = port.toInt();
        url.port = value == _specialSchemes[url.scheme] ? null : value;
        buffer = '';
      }
      state = _State.pathStart;
      pointer--;
    } else {
      return _Step.fail;
    }
    return _Step.next;
  }

  /// url-state-machine.js:886-891.
  bool startsWithWindowsDriveLetter(int index) {
    final length = input.length - index;
    return length >= 2 &&
        _isWindowsDriveLetterCodePoints(at(index), at(index + 1)) &&
        (length == 2 ||
            const {
              _slash,
              _backslash,
              _question,
              _hash,
            }.contains(at(index + 2)));
  }

  /// url-state-machine.js:476-486.
  void shortenPath() {
    if (segments.isEmpty) return;
    if (url.scheme == 'file' &&
        segments.length == 1 &&
        _isNormalizedWindowsDriveLetter(segments[0])) {
      return;
    }
    segments.removeLast();
  }

  /// url-state-machine.js:893-930.
  _Step file(int? c) {
    url
      ..scheme = 'file'
      ..host = '';
    final base = this.base;
    if (c == _slash || c == _backslash) {
      state = _State.fileSlash;
    } else if (base != null && base.scheme == 'file') {
      url
        ..host = base.host
        ..path = List<String>.of(base._segments)
        ..query = base.query;
      if (c == _question) {
        url.query = '';
        state = _State.query;
      } else if (c == _hash) {
        url.fragment = '';
        state = _State.fragment;
      } else if (c != null) {
        url.query = null;
        if (!startsWithWindowsDriveLetter(pointer)) {
          shortenPath();
        } else {
          url.path = <String>[];
        }
        state = _State.path;
        pointer--;
      }
    } else {
      state = _State.path;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:932-951.
  _Step fileSlash(int? c) {
    if (c == _slash || c == _backslash) {
      state = _State.fileHost;
    } else {
      final base = this.base;
      if (base != null && base.scheme == 'file') {
        final baseSegments = base._segments;
        if (!startsWithWindowsDriveLetter(pointer) &&
            baseSegments.isNotEmpty &&
            _isNormalizedWindowsDriveLetter(baseSegments[0])) {
          segments.add(baseSegments[0]);
        }
        url.host = base.host;
      }
      state = _State.path;
      pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:953-987.
  _Step fileHost(int? c) {
    if (c == null ||
        c == _slash ||
        c == _backslash ||
        c == _question ||
        c == _hash) {
      pointer--;
      if (_isWindowsDriveLetterString(buffer)) {
        state = _State.path;
      } else if (buffer == '') {
        url.host = '';
        state = _State.pathStart;
      } else {
        var host = _parseHost(buffer, isOpaque: !special);
        if (identical(host, _failure)) return _Step.fail;
        if (host == 'localhost') host = '';
        url.host = host;
        buffer = '';
        state = _State.pathStart;
      }
    } else {
      buffer += String.fromCharCode(c);
    }
    return _Step.next;
  }

  /// url-state-machine.js:989-1015.
  _Step pathStart(int? c) {
    if (special) {
      state = _State.path;
      if (c != _slash && c != _backslash) pointer--;
    } else if (c == _question) {
      url.query = '';
      state = _State.query;
    } else if (c == _hash) {
      url.fragment = '';
      state = _State.fragment;
    } else if (c != null) {
      state = _State.path;
      if (c != _slash) pointer--;
    }
    return _Step.next;
  }

  /// url-state-machine.js:1017-1060.
  _Step pathState(int? c) {
    final slashLike = c == _slash || (special && c == _backslash);
    if (c == null || slashLike || c == _question || c == _hash) {
      if (_isDoubleDot(buffer)) {
        shortenPath();
        if (!slashLike) segments.add('');
      } else if (_isSingleDot(buffer) && !slashLike) {
        segments.add('');
      } else if (!_isSingleDot(buffer)) {
        if (url.scheme == 'file' &&
            segments.isEmpty &&
            _isWindowsDriveLetterString(buffer)) {
          buffer = '${buffer[0]}:';
        }
        segments.add(buffer);
      }
      buffer = '';
      if (c == _question) {
        url.query = '';
        state = _State.query;
      }
      if (c == _hash) {
        url.fragment = '';
        state = _State.fragment;
      }
    } else {
      buffer += _utf8PercentEncodeCodePoint(c, _isPathPercentEncode);
    }
    return _Step.next;
  }

  /// url-state-machine.js:1062-1094.
  _Step opaquePath(int? c) {
    if (c == _question) {
      url.query = '';
      state = _State.query;
    } else if (c == _hash) {
      url.fragment = '';
      state = _State.fragment;
    } else if (c == _space) {
      final remaining = at(pointer + 1);
      final space = remaining == _question || remaining == _hash ? '%20' : ' ';
      url.path = '${url.path}$space';
    } else if (c != null) {
      final encoded = _utf8PercentEncodeCodePoint(c, _isC0ControlPercentEncode);
      url.path = '${url.path}$encoded';
    }
    return _Step.next;
  }

  /// url-state-machine.js:1096-1128, in UTF-8 (the URL constructor's
  /// encoding): "percent-encode after encoding" with UTF-8 is the UTF-8
  /// percent-encoding of the buffer with the (special-)query set.
  _Step queryState(int? c) {
    if (c == _hash || c == null) {
      final encoded = _utf8PercentEncodeString(
        buffer,
        special ? _isSpecialQueryPercentEncode : _isQueryPercentEncode,
      );
      url.query = '${url.query}$encoded';
      buffer = '';
      if (c == _hash) {
        url.fragment = '';
        state = _State.fragment;
      }
    } else {
      buffer += String.fromCharCode(c);
    }
    return _Step.next;
  }

  /// url-state-machine.js:1130-1143.
  _Step fragmentState(int? c) {
    if (c != null) {
      final encoded = _utf8PercentEncodeCodePoint(c, _isFragmentPercentEncode);
      url.fragment = '${url.fragment}$encoded';
    }
    return _Step.next;
  }
}

// PORT STATUS: confidence=medium todos=1 upstream=whatwg-url@16.0.1/lib/url-state-machine.js
