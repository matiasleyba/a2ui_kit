// A port of CopilotKit's openUrl (packages/core/src/generative-ui/
// functions.ts:212-468, `openUrlSafely` and its helpers; MIT, (c) Atai
// Barkai): an http(s) URL opens in a new tab, any other is refused.
//
// Upstream has two paths, and RULEBOOK section 0 maps them: on a browser
// page (`pageBase`, :390-401) WHATWG URL resolves the URL against the page
// (`openOnPage`, :408-426), which the kit does on the web ([kitIsWeb]) with
// the page's `location.href` ([kitPageHref]) and the URL Standard's parser
// (foundation/url/whatwg_url.dart); with no page (React Native) only an
// absolute URL is taken, checked by `parseUrl` (:341-375), which the kit
// does on every other platform.
//
// Upstream's other outcomes have no counterpart here: with no `window`
// (server rendering) it does nothing, and a `window` without `open` throws a
// PlatformError (:444-449); a Flutter app always has an opener
// (url_launcher, or `A2uiKitOptions.onOpenUrl`).

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/src/catalog_options.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:a2ui_kit/src/foundation/url/whatwg_url.dart';

/// Opens [url], an http(s) URL, as CopilotKit's `openUrlSafely` does
/// (functions.ts:440-468): through the [options]' `onOpenUrl`, else in a
/// new tab with url_launcher. Throws an [A2uiExpressionError], before
/// opening anything, for a value that is not a string, a URL that does not
/// parse and any scheme but http and https; on the web a relative URL is
/// resolved against the page, elsewhere it is refused.
Future<void> openUrlSafely(Object? url, A2uiKitOptions options) {
  if (url is! String || url.isEmpty) {
    throw A2uiExpressionError('url must be a string');
  }
  final base = pageBase();
  final href = base != null ? _hrefOnPage(url, base) : _hrefWithoutPage(url);
  final open = options.onOpenUrl;
  if (open == null) return launchDefaultHref(href);
  // `onOpenUrl` takes a Dart `Uri`, which may percent-encode what WHATWG
  // keeps (a backslash in the query); one it cannot read is not opened.
  final uri = Uri.tryParse(href);
  if (uri == null) throw A2uiExpressionError('"$url" is not a URL');
  return Future.sync(() => open(uri));
}

/// openUrl on a browser page (functions.ts:408-426): WHATWG URL resolves
/// [url] against [base], and any http(s) URL it accepts opens, in its
/// serialization.
String _hrefOnPage(String url, String base) {
  final parsed = WhatwgUrl.parse(url, base);
  if (parsed == null) throw A2uiExpressionError('"$url" is not a URL');
  if (parsed.protocol != 'https:' && parsed.protocol != 'http:') {
    throw A2uiExpressionError(
      'openUrl takes only http(s) URLs, not ${parsed.protocol}',
    );
  }
  return parsed.href;
}

/// openUrl with no page (functions.ts:455-467).
String _hrefWithoutPage(String url) => switch (parseUrl(url)) {
  UrlRelative() => throw A2uiExpressionError('"$url" is not an absolute URL'),
  UrlOther(:final protocol) => throw A2uiExpressionError(
    'openUrl takes only http(s) URLs, not $protocol',
  ),
  UrlInvalid() => throw A2uiExpressionError('"$url" is not a URL'),
  UrlWeb(:final href) => href,
};

/// The host of a URL with an authority, lowercase, or "" without one
/// (functions.ts:378-379).
final RegExp _pageHost = RegExp(
  r'^[A-Za-z][A-Za-z\d+\-.]*:\/\/(?:[^/?#@]*@)?(\[[^\]]*\]|[^/?#:]*)',
);

/// The URL of the page, to resolve a relative URL against: CopilotKit's
/// `pageBase` (functions.ts:390-401). Null when there is no page (off the
/// web), or when the page's host is reserved (`.invalid` is never a real
/// host, with or without the trailing dot). Upstream's React Native check
/// (`navigator.product`) has no counterpart: a Flutter web app is never
/// React Native.
String? pageBase() {
  final href = kitPageHref;
  if (href == null) return null;
  final pageHost = _pageHost.firstMatch(href.trim())?.group(1) ?? '';
  final hostname = pageHost.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  final isReserved = hostname == 'invalid' || hostname.endsWith('.invalid');
  return isReserved ? null : href;
}

/// An http(s) URL, or why a string is not one (functions.ts:212-217).
sealed class ParsedUrl {
  const ParsedUrl();
}

/// An absolute http(s) URL, as it opens.
final class UrlWeb extends ParsedUrl {
  /// A URL whose host is [hostname], written as [href].
  const UrlWeb(this.hostname, this.href);

  /// The host, normalized.
  final String hostname;

  /// The URL to open.
  final String href;
}

/// A URL with no scheme.
final class UrlRelative extends ParsedUrl {
  /// A relative URL.
  const UrlRelative();
}

/// A URL of a scheme other than http and https.
final class UrlOther extends ParsedUrl {
  /// A URL of [protocol].
  const UrlOther(this.protocol);

  /// Its scheme, lowercase, with its colon (`ftp:`).
  final String protocol;
}

/// An http(s) URL that does not parse.
final class UrlInvalid extends ParsedUrl {
  /// An invalid URL.
  const UrlInvalid();
}

final RegExp _schemePattern = RegExp(r'^([A-Za-z][A-Za-z\d+\-.]*):');

/// True for a C0 control or DEL (`spaces` also counts a space as one)
/// (functions.ts:220-223).
bool _isControl(int code, {bool spaces = false}) =>
    code < 0x20 || code == 0x7f || (spaces && code == 0x20);

/// WHATWG URL ignores leading and trailing C0 controls and spaces
/// (functions.ts:225-232).
String _trimControls(String input) {
  var start = 0;
  var end = input.length;
  while (start < end && _isControl(input.codeUnitAt(start), spaces: true)) {
    start += 1;
  }
  while (end > start && _isControl(input.codeUnitAt(end - 1), spaces: true)) {
    end -= 1;
  }
  return input.substring(start, end);
}

/// functions.ts:234-239.
bool _hasControl(String input) => input.codeUnits.any(_isControl);

/// A host name: no empty label, no forbidden host code point
/// (functions.ts:241-242).
final RegExp _hostname = RegExp(
  r'^[^\s#%/:<>?@[\\\]^|.]+(?:\.[^\s#%/:<>?@[\\\]^|.]+)*\.?$',
);

/// A dotted-decimal IPv4 address inside an IPv6 literal, as WHATWG takes it
/// (functions.ts:244-246).
final RegExp _embeddedIpv4 = RegExp(
  r'^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
  r'(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$',
);
final RegExp _ipv6Piece = RegExp(r'^[\da-f]{1,4}$', caseSensitive: false);

/// The colon-separated pieces of one side of an IPv6 `::`
/// (functions.ts:249-252).
List<String> _ipv6Pieces(String half) => half == '' ? [] : half.split(':');

/// Is [literal] (the inside of `[...]`) an IPv6 address? Eight pieces of one
/// to four hex digits, or fewer with one `::` that stands for at least one
/// zero piece; the last two pieces may be a dotted IPv4 address. No zone
/// (functions.ts:254-283).
bool _isIpv6(String literal) {
  final halves = literal.split('::');
  if (halves.length > 2) return false;
  final head = _ipv6Pieces(halves[0]);
  final tail = halves.length == 2 ? _ipv6Pieces(halves[1]) : <String>[];
  final pieces = [...head, ...tail];
  // Only the last piece of the whole literal may be an IPv4 address.
  final lastCanBeIpv4 = halves.length == 1 || tail.isNotEmpty;
  var count = 0;
  for (var index = 0; index < pieces.length; index += 1) {
    final piece = pieces[index];
    if (_ipv6Piece.hasMatch(piece)) {
      count += 1;
    } else if (lastCanBeIpv4 &&
        index == pieces.length - 1 &&
        _embeddedIpv4.hasMatch(piece)) {
      count += 2;
    } else {
      return false;
    }
  }
  return halves.length == 2 ? count < 8 : count == 8;
}

final RegExp _hexNumber = RegExp(r'^0x[\da-f]*$', caseSensitive: false);
final RegExp _octalNumber = RegExp(r'^0[0-7]+$');
final RegExp _decimalNumber = RegExp(r'^(?:0|[1-9]\d*)$');

/// A WHATWG IPv4 number: decimal, `0x` hex or `0` octal, or null
/// (functions.ts:285-293). A `BigInt`, which compares as JavaScript's
/// numbers do with the bounds of [_ipv4Host].
BigInt? _ipv4Number(String part) {
  if (_hexNumber.hasMatch(part)) {
    return part.length == 2
        ? BigInt.zero
        : BigInt.parse(part.substring(2), radix: 16);
  }
  if (_octalNumber.hasMatch(part)) {
    return BigInt.parse(part.substring(1), radix: 8);
  }
  if (_decimalNumber.hasMatch(part)) return BigInt.parse(part);
  return null;
}

final RegExp _digits = RegExp(r'^\d+$');

/// A host name whose last label is a number is an IPv4 address to WHATWG
/// URL: up to four parts, each decimal, hex or octal, every part but the
/// last at most 255 and the last filling the rest of the 32 bits. Gives the
/// host in dotted decimal, the host itself when it does not end in a
/// number, or null when it is not a valid address (functions.ts:295-322).
String? _ipv4Host(String hostname) {
  final parts = hostname.split('.');
  if (parts.last == '' && parts.length > 1) parts.removeLast();
  final last = parts.last;
  if (!_digits.hasMatch(last) && _ipv4Number(last) == null) return hostname;
  if (parts.length > 4) return null;
  final numbers = parts.map(_ipv4Number).toList();
  if (numbers.any((number) => number == null)) return null;
  final values = [for (final number in numbers) number!];
  final lastValue = values.removeLast();
  if (values.any((value) => value > BigInt.from(255))) return null;
  if (lastValue >= BigInt.from(256).pow(4 - values.length)) return null;
  var address = lastValue;
  for (var index = 0; index < values.length; index++) {
    address += values[index] * BigInt.from(256).pow(3 - index);
  }
  final octets = [
    for (final shift in [24, 16, 8, 0]) (address >> shift).toInt() % 256,
  ];
  return octets.join('.');
}

/// The host of an http(s) URL, normalized, or null when invalid
/// (functions.ts:324-332).
String? _checkHost(String hostname) {
  if (hostname.startsWith('[')) {
    return hostname.endsWith(']') &&
            _isIpv6(hostname.substring(1, hostname.length - 1))
        ? hostname
        : null;
  }
  return _hostname.hasMatch(hostname) ? _ipv4Host(hostname) : null;
}

final RegExp _authorityEnd = RegExp(r'[/?#\\]');
final RegExp _backslashInPath = RegExp(r'^[^?#]*\\');
final RegExp _hostAndPort = RegExp(r'^(\[[^\]]*\]|[^:]*)(?::(\d*))?$');
final RegExp _whiteSpace = RegExp(r'\s');

/// Parses an absolute http(s) URL with no page to resolve against:
/// CopilotKit's `parseUrl` (functions.ts:334-375). The scheme is matched in
/// any case, and an http(s) URL needs "//" and a host.
ParsedUrl parseUrl(String input) {
  final url = _trimControls(input);
  final scheme = _schemePattern.firstMatch(url);
  if (scheme == null) return const UrlRelative();
  final protocol = '${scheme.group(1)!.toLowerCase()}:';
  if (protocol != 'http:' && protocol != 'https:') return UrlOther(protocol);
  final rest = url.substring(scheme.group(0)!.length);
  if (!rest.startsWith('//') || _hasControl(rest)) return const UrlInvalid();
  final afterSlashes = rest.substring(2);
  final authorityEnd = afterSlashes.indexOf(_authorityEnd);
  final authority = authorityEnd < 0
      ? afterSlashes
      : afterSlashes.substring(0, authorityEnd);
  final tail = authorityEnd < 0 ? '' : rest.substring(authorityEnd + 2);
  // A backslash in the path is a slash to WHATWG but not to every opener.
  // WHATWG URL never leaves one there, so only a hand-written URL has it.
  if (_backslashInPath.hasMatch(tail)) return const UrlInvalid();
  final at = authority.lastIndexOf('@');
  final userinfo = at < 0 ? '' : authority.substring(0, at + 1);
  final hostAndPort = _hostAndPort.firstMatch(authority.substring(at + 1));
  if (hostAndPort == null) return const UrlInvalid();
  final hostname = _checkHost(hostAndPort.group(1)!.toLowerCase());
  final port = hostAndPort.group(2) ?? '';
  if (hostname == null ||
      _whiteSpace.hasMatch(userinfo) ||
      (port.isNotEmpty && double.parse(port) > 65535)) {
    return const UrlInvalid();
  }
  final path = tail.startsWith('/') ? tail : '/$tail';
  return UrlWeb(
    hostname,
    '$protocol//$userinfo$hostname${port.isNotEmpty ? ':$port' : ''}'
    '${path.replaceAll(' ', '%20')}',
  );
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/core/src/generative-ui/functions.ts
