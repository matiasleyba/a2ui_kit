// Parity tests of CopilotKit's basic functions and openUrl, ported from
// packages/core/src/generative-ui/__tests__/functions.test.ts (MIT, (c)
// Atai Barkai). Each test names its upstream line.
//
// Parity for: Button, CheckBox, Column, Text, (functions)
//
// openUrl runs as the catalog's own function (`kitFunctions`) with no
// `onOpenUrl`, so it opens through url_launcher, whose platform is a fake
// (`fakeUrlLauncher`): upstream's `window.open` spy, the URL with
// `webOnlyWindowName: '_blank'` its `(url, "_blank", ...)` call.
//
// openUrl has two paths upstream (functions.ts:440-466): on a browser page
// (`pageBase`) WHATWG URL resolves the URL against the page; with no page
// (React Native) `parseUrl` takes only absolute URLs. RULEBOOK section 0
// decides the mapping: the page path on Flutter web, the no-page path on
// every other platform. The VM is a platform with no page; the page path
// runs on it through the platform overrides (`debugKitIsWebOverride` and
// `debugKitPageHrefOverride`, lib/src/foundation/platform.dart; section 6
// item 2), on the page jsdom gives vitest (`http://localhost:3000/`, whose
// origin :150 reads) unless a test names another. :150 and :175 run on the
// page, as upstream runs them, and again off it, where every assertion but
// :150's "/relative" call gives the same result; :212, :231 and :317 run
// off it; :422, :436 and :446 on it.
//
// :422 compares openUrl with the code before React Native was supported,
// which was WHATWG URL against the page and nothing else: here each URL's
// outcome is worked out from the WHATWG URL Standard (section 4.4, the
// basic URL parser, with section 3.5's host parser; section 4.5, the URL
// serializer) against that page, the URL opened or the error thrown.
//
// Not ported (bound to internals):
// - functions.test.ts:150 and :175, the "noopener,noreferrer" features of
//   `window.open`: url_launcher_web opens its new tab without an opener; no
//   platform interface carries them. The URL and `_blank` are tested.
// - functions.test.ts:317, its oracle check (`expect(whatwg !== undefined,
//   "the oracle agrees with the table")`, :325-327): it checks upstream's
//   table against jsdom's URL, not the code under test. The table's IPv4
//   values are worked out from the WHATWG URL Standard instead (below).
//
// Not ours (JavaScript platform values and CopilotKit's machinery):
// - functions.test.ts:120 "throws a PlatformError ... that names what is
//   missing": it stubs the JavaScript global `Intl` away. Dart's formatting
//   needs no platform object, so there is no missing-platform case.
// - functions.test.ts:201 "says openUrl is unavailable instead of calling a
//   valid URL invalid": a React Native `window` without `open`. A Flutter
//   app always has an opener (url_launcher or `onOpenUrl`).
// - functions.test.ts:231's run per React Native version ("validates with
//   the URL class of React Native %s in place"): the JavaScript URL
//   polyfill of each version. Dart has one `Uri`, so the cases run once,
//   at :231 below.
// - functions.test.ts:471, :488, :504 (the reason the dispatcher gives):
//   CopilotKit's function dispatcher, not this package (a2ui_core reports a
//   failed function to the surface).
//
// The group "beyond functions.test.ts" at the end holds our own vectors
// for the same functions (currency digits, Intl rounding, date fields,
// plural categories, JavaScript truth, the validators' messages, openUrl
// off a page, on a reserved page and through `onOpenUrl`, and more of the
// URL Standard on the web path), which upstream does not assert.

import 'dart:convert';
import 'dart:ui' show CheckedState;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/format/decimal.dart';
import 'package:a2ui_kit/src/foundation/platform.dart';
import 'package:a2ui_kit/src/functions/formatting.dart';
import 'package:a2ui_kit/src/functions/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart'
    show
        FakeUrlLauncher,
        fakeUrlLauncher,
        openedInNewTab,
        portQueue,
        renderStandard;

final Map<String, Object? Function(Map<String, Object?>)> _functions = {
  ...copilotKitFormatting('en-US'),
  ...copilotKitValidators,
};

/// Upstream's `fn(name, args)`: `BASIC_FUNCTIONS[name]!(args)`.
Object? _fn(String name, Map<String, Object?> args) => _functions[name]!(args);

/// The validation result of the validator [name].
ValidationResult _check(String name, Map<String, Object?> args) =>
    _fn(name, args)! as ValidationResult;

/// vitest's `toThrow(text)` for an [A2uiExpressionError].
Matcher _throwsExpression(String message) => throwsA(
  isA<A2uiExpressionError>().having(
    (e) => e.message,
    'message',
    contains(message),
  ),
);

/// vitest's `toThrow(new ExpressionError(message))`: the same class and
/// exactly that message.
Matcher _throwsExactly(String message) => throwsA(
  isA<A2uiExpressionError>().having((e) => e.message, 'message', message),
);

/// The catalog's openUrl with no `onOpenUrl`, so that it opens through
/// url_launcher: upstream's `openUrlSafely`, whose `window.open` spy is a
/// [fakeUrlLauncher] the test puts in place first. [options] gives an
/// `onOpenUrl` instead.
Future<void> Function(Object? url) _openUrl({
  A2uiKitOptions options = const A2uiKitOptions(),
}) {
  final catalog = a2uiKitStandardCatalog(options: options);
  final function = catalog.functions['openUrl']!;
  final context = DataContext(DataModel(), (name, args, context) => null, '/');
  return (url) async {
    final result = function.execute({'url': url}, context);
    if (result is Future<Object?>) await result;
  };
}

/// jsdom's page in vitest, where upstream's page tests run: `http://
/// localhost:3000/` (its `window.location.origin` is `http://
/// localhost:3000`).
const String _jsdomPage = 'http://localhost:3000/';

/// Runs the rest of the test on the web path, on the page [href]: the
/// platform overrides of lib/src/foundation/platform.dart, reset after the
/// test.
void _onTheWeb([String href = _jsdomPage]) {
  debugKitIsWebOverride = true;
  debugKitPageHrefOverride = href;
  addTearDown(() {
    debugKitIsWebOverride = null;
    debugKitPageHrefOverride = null;
  });
}

/// What opening [url] does (upstream's `outcome`, functions.test.ts:
/// 370-379): the URLs it opened, or the message of the ExpressionError it
/// threw.
Future<Object> _outcome(
  Future<void> Function(Object? url) open,
  FakeUrlLauncher launcher,
  String url,
) async {
  final before = launcher.launches.length;
  try {
    await open(url);
  } on A2uiExpressionError catch (error) {
    return 'ExpressionError: ${error.message}';
  }
  return [for (final launch in launcher.launches.skip(before)) launch.url];
}

Map<String, Object?> _text(String id, Object? text) => {
  'id': id,
  'component': 'Text',
  'text': text,
};

List<String> _texts(WidgetTester tester) => [
  for (final text in tester.widgetList<RichText>(find.byType(RichText)))
    text.text.toPlainText(),
];

void main() {
  group('basic functions', () {
    // functions.test.ts:20
    test(
      'implements every built-in function that the shared list names',
      () async {
        // GENERATIVE_UI_FUNCTIONS: A2UI_BASIC_FUNCTIONS and
        // COPILOTKIT_FUNCTIONS (shared/src/generative-ui/basic-functions.ts).
        const names = [
          'required',
          'regex',
          'length',
          'numeric',
          'email',
          'formatString',
          'formatNumber',
          'formatCurrency',
          'formatDate',
          'pluralize',
          'openUrl',
          'and',
          'or',
          'not',
          'calc',
          'series',
        ];
        final functions = a2uiKitStandardCatalog().functions;
        expect(functions.keys.toList()..sort(), [...names]..sort());
        // `Object.keys(BASIC_FUNCTIONS)` is the map of implementations: each
        // name has a body, not the catalog's fallback for a function declared
        // but not implemented.
        final context = DataContext(
          DataModel(),
          (name, args, context) => null,
          '/',
        );
        for (final name in names) {
          Object? error;
          try {
            final result = functions[name]!.execute({}, context);
            if (result is Future<Object?>) await result;
            if (result is ReadonlySignal<Object?>) result.value;
          } on Object catch (thrown) {
            error = thrown;
          }
          expect(
            error,
            isNot(
              isA<A2uiExpressionError>().having(
                (e) => e.message,
                'message',
                contains('is not available in this version of a2ui_kit'),
              ),
            ),
            reason: name,
          );
        }
      },
    );

    // functions.test.ts:25
    test('validates with required, regex, length, numeric and email', () {
      expect(
        _fn('required', {'value': ''}),
        const ValidationResult(
          valid: false,
          message: 'Required',
          code: 'required',
        ),
      );
      expect(_check('required', {'value': <Object?>[]}).valid, false);
      expect(_check('required', {'value': 0}).valid, true);
      expect(
        _check('regex', {
          'value': 'AB-12',
          'pattern': r'^[A-Z]{2}-\d{2}$',
        }).valid,
        true,
      );
      expect(
        _check('regex', {'value': 'ab', 'pattern': r'^[A-Z]+$'}).valid,
        false,
      );
      expect(
        _check('length', {'value': 'abc', 'min': 2, 'max': 3}).valid,
        true,
      );
      expect(
        _fn('length', {'value': 'abcd', 'max': 3}),
        const ValidationResult(
          valid: false,
          message: 'At most 3 characters',
          code: 'tooLong',
        ),
      );
      expect(_check('length', {'value': 'a', 'min': 2}).code, 'tooShort');
      expect(
        _check('regex', {'value': 'ab', 'pattern': r'^[A-Z]+$'}).code,
        'pattern',
      );
      expect(_check('numeric', {'value': 'x'}).code, 'notANumber');
      expect(_check('numeric', {'value': 0, 'min': 1}).code, 'tooSmall');
      expect(_check('numeric', {'value': 11, 'max': 10}).code, 'tooLarge');
      expect(_check('email', {'value': 'a@b'}).code, 'email');
      expect(
        _check('numeric', {'value': '7', 'min': 1, 'max': 10}).valid,
        true,
      );
      expect(_check('numeric', {'value': 'x'}).valid, false);
      expect(_check('numeric', {'value': 11, 'max': 10}).message, 'At most 10');
      expect(_check('email', {'value': 'a@b.co'}).valid, true);
      expect(_check('email', {'value': 'a@b'}).valid, false);
    });

    // functions.test.ts:58
    test('formats numbers, currency and dates', () {
      expect(_fn('formatNumber', {'value': 1234567.891}), '1,234,567.891');
      expect(
        _fn('formatNumber', {
          'value': 1234.5,
          'decimals': 2,
          'grouping': false,
        }),
        '1234.50',
      );
      expect(
        _fn('formatCurrency', {'value': 12.5, 'currency': 'EUR'}),
        '€12.50',
      );
      expect(
        _fn('formatCurrency', {
          'value': 1200,
          'currency': 'JPY',
          'decimals': 0,
        }),
        '¥1,200',
      );
      expect(
        _fn('formatDate', {'value': '2026-10-19', 'format': 'yyyy-MM-dd'}),
        '2026-10-19',
      );
      expect(
        _fn('formatDate', {
          'value': '2026-10-19T14:05:09',
          'format': 'MMM d, yyyy HH:mm',
        }),
        'Oct 19, 2026 14:05',
      );
      expect(
        _fn('formatDate', {
          'value': '2026-10-19T14:05:00',
          'format': "h:mm a 'o''clock'",
        }),
        "2:05 PM o'clock",
      );
      expect(
        _fn('formatDate', {'value': '2026-10-19', 'format': 'EEEE'}),
        'Monday',
      );
      expect(
        _fn('formatDate', {'value': '2026-11-07', 'format': 'EEE, MMM d'}),
        'Sat, Nov 7',
      );
      expect(
        _fn('formatDate', {
          'value': '2026-11-07',
          'format': "d/M/yy 'at' HH:mm",
        }),
        '7/11/26 at 00:00',
      );
    });

    // functions.test.ts:95
    test('pluralizes by the locale category, with zero first', () {
      const args = {'zero': 'none', 'one': 'item', 'other': 'items'};
      expect(_fn('pluralize', {'value': 0, ...args}), 'none');
      expect(_fn('pluralize', {'value': 1, ...args}), 'item');
      expect(_fn('pluralize', {'value': 5, ...args}), 'items');
      expect(_fn('pluralize', {'value': 1, 'other': 'items'}), 'items');
    });

    // functions.test.ts:103
    test('rejects bad arguments with an ExpressionError', () {
      expect(
        () => _fn('formatCurrency', {'value': 1}),
        throwsA(isA<A2uiExpressionError>()),
      );
      expect(
        () => _fn('formatCurrency', {'value': 1, 'currency': 'nope'}),
        _throwsExpression('not a currency code'),
      );
      expect(
        () => _fn('formatDate', {'value': 'yesterday', 'format': 'd'}),
        _throwsExpression('must be a date'),
      );
      expect(
        () => _fn('regex', {'value': 'a', 'pattern': '('}),
        _throwsExpression('not a regular expression'),
      );
      expect(
        () => _fn('and', {'values': true}),
        _throwsExpression('values must be a list'),
      );
    });
  });

  group('openUrl', () {
    // functions.test.ts:150, on the page (upstream's jsdom page)
    test('opens http(s) URLs in a new tab with noopener, and refuses other '
        'schemes', () async {
      _onTheWeb();
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      await open('https://example.com/docs');
      expect(launcher.opened, [openedInNewTab('https://example.com/docs')]);
      await open('/relative');
      // `${window.location.origin}/relative`.
      expect(
        launcher.opened.last,
        openedInNewTab('http://localhost:3000/relative'),
      );
      await expectLater(
        open('javascript:alert(1)'),
        _throwsExpression('only http(s) URLs'),
      );
      await expectLater(
        open('data:text/html,hi'),
        _throwsExpression('only http(s) URLs'),
      );
      await expectLater(open(42), _throwsExpression('url must be a string'));
      await pumpEventQueue();
      expect(launcher.launches, hasLength(2));
    });

    // functions.test.ts:150, off the web: no page to resolve "/relative"
    // against (functions.ts:456-458).
    test('opens http(s) URLs in a new tab and refuses other schemes and '
        'relative URLs off the web', () async {
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      await open('https://example.com/docs');
      expect(launcher.opened, [openedInNewTab('https://example.com/docs')]);
      await expectLater(
        open('/relative'),
        _throwsExactly('"/relative" is not an absolute URL'),
      );
      await expectLater(
        open('javascript:alert(1)'),
        _throwsExpression('only http(s) URLs'),
      );
      await expectLater(
        open('data:text/html,hi'),
        _throwsExpression('only http(s) URLs'),
      );
      await expectLater(open(42), _throwsExpression('url must be a string'));
      await pumpEventQueue();
      expect(launcher.launches, hasLength(1));
    });

    // functions.test.ts:175, on the page; the same assertions hold off the
    // web (parseUrl, functions.ts:341-375), where it runs again.
    for (final onTheWeb in [true, false]) {
      test('takes the scheme in any case on the web, as WHATWG URL does'
          '${onTheWeb ? '' : ' (off the web too)'}', () async {
        if (onTheWeb) _onTheWeb();
        final launcher = fakeUrlLauncher();
        final open = _openUrl();
        await open('HTTPS://Example.com/Docs');
        expect(
          launcher.opened.last,
          openedInNewTab('https://example.com/Docs'),
        );
        await expectLater(
          open('JavaScript:alert(1)'),
          _throwsExpression('openUrl takes only http(s) URLs, not javascript:'),
        );
        await expectLater(
          open('https://'),
          _throwsExpression('"https://" is not a URL'),
        );
        // WHATWG keeps a backslash in the fragment and query; the page
        // opens.
        await open(r'https://example.com/a?q=1\2#x\y');
        expect(
          launcher.opened.last,
          openedInNewTab(r'https://example.com/a?q=1\2#x\y'),
        );
        await pumpEventQueue();
        expect(launcher.launches, hasLength(2));
      });
    }

    // functions.test.ts:212
    test('validates absolute http(s) URLs without a base when open exists but '
        'location does not', () async {
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      await open('https://example.com/docs');
      expect(launcher.opened, [openedInNewTab('https://example.com/docs')]);
      await expectLater(
        open('/relative'),
        _throwsExpression('"/relative" is not an absolute URL'),
      );
      await expectLater(
        open('javascript:alert(1)'),
        _throwsExpression('only http(s) URLs'),
      );
      await pumpEventQueue();
      expect(launcher.launches, hasLength(1));
    });

    // functions.test.ts:231 (once: Dart has one Uri class)
    test('validates as the URL class of React Native does', () async {
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      Future<String?> refusal(String url) async {
        try {
          await open(url);
        } on A2uiExpressionError catch (error) {
          return error.message;
        }
        return null;
      }

      expect(await refusal('/relative'), '"/relative" is not an absolute URL');
      expect(await refusal('https://'), '"https://" is not a URL');
      expect(
        await refusal('ftp://example.com/'),
        'openUrl takes only http(s) URLs, not ftp:',
      );
      expect(await refusal('HTTPS://example.com/docs'), isNull);
      await pumpEventQueue();
      expect(launcher.opened, [openedInNewTab('https://example.com/docs')]);
    });

    // functions.test.ts:262, the IP literals of :317, against WHATWG URL as
    // the oracle. Upstream's oracle for an IPv4 host is `new URL(target)
    // .href`; the hrefs below are worked out from the WHATWG URL Standard:
    // section 3.5 "Host parsing", the IPv4 parser (hex "0x" and octal "0"
    // parts, the last part filling the remaining bytes, one trailing empty
    // part dropped), and section 3.6 "Host serializing" (dotted decimal).
    // An IPv6 literal keeps its spelling, lowercase: upstream's own literal
    // expectation, not the oracle's.
    const validHosts = {
      '192.168.0.1': 'https://192.168.0.1/a',
      '0.0.0.0': 'https://0.0.0.0/a',
      '255.255.255.255': 'https://255.255.255.255/a',
      '1.2.3.4.': 'https://1.2.3.4/a',
      '0x7f.1': 'https://127.0.0.1/a',
      '0x7f000001': 'https://127.0.0.1/a',
      '017.0.0.1': 'https://15.0.0.1/a',
      '4294967295': 'https://255.255.255.255/a',
      '[::1]': 'https://[::1]/a',
      '[::]': 'https://[::]/a',
      '[2001:db8::]': 'https://[2001:db8::]/a',
      '[2001:DB8:0:0:8:800:200C:417A]':
          'https://[2001:db8:0:0:8:800:200c:417a]/a',
      '[1:2:3:4:5:6:7:8]': 'https://[1:2:3:4:5:6:7:8]/a',
      '[::1:2:3:4:5:6:7]': 'https://[::1:2:3:4:5:6:7]/a',
      '[1:2:3:4:5:6:7::]': 'https://[1:2:3:4:5:6:7::]/a',
      '[::ffff:192.168.0.1]': 'https://[::ffff:192.168.0.1]/a',
      '[1:2:3:4:5:6:1.2.3.4]': 'https://[1:2:3:4:5:6:1.2.3.4]/a',
      '[::1.2.3.4]': 'https://[::1.2.3.4]/a',
    };
    const invalidHosts = [
      '999.999.999.999',
      '256.0.0.1',
      '1.2.3.256',
      '1.2.3.4.5',
      '4294967296',
      '09.1.1.1',
      '0x7g.1',
      'example.123',
      '1..2.3',
      '[:::]',
      '[1::2::3]',
      '[:1::]',
      '[1:]',
      '[::1:]',
      '[12345::]',
      '[1:2:3:4:5:6:7:8:9]',
      '[1:2:3:4::5:6:7:8]',
      '[1:2:3:4:5:6:7]',
      '[g::1]',
      '[1.2.3.4]',
      '[1.2.3.4::]',
      '[::1.2.3]',
      '[::256.1.1.1]',
      '[::01.2.3.4]',
      '[::1.2.3.4:5]',
      '[1:2:3:4:5:6:7:1.2.3.4]',
      '[fe80::1%25eth0]',
    ];
    for (final MapEntry(key: host, value: href) in validHosts.entries) {
      // functions.test.ts:317
      test('checks the IP host $host as WHATWG URL does', () async {
        final launcher = fakeUrlLauncher();
        await _openUrl()('https://$host/a');
        expect(launcher.opened, [openedInNewTab(href)]);
      });
    }
    for (final host in invalidHosts) {
      // functions.test.ts:317
      test('checks the IP host $host as WHATWG URL does', () async {
        final launcher = fakeUrlLauncher();
        final target = 'https://$host/a';
        await expectLater(
          _openUrl()(target),
          _throwsExactly('"$target" is not a URL'),
        );
        await pumpEventQueue();
        expect(launcher.launches, isEmpty);
      });
    }
  });

  group('openUrl on a browser page keeps the pre-React-Native behaviour', () {
    // functions.test.ts:382-417 (WEB_PARITY_URLS), each with its outcome on
    // jsdom's page `http://localhost:3000/`, worked out from the WHATWG URL
    // Standard (see the header): the URLs opened, or the error. Section 4.4's
    // states named: "relative" copies the page's host, port and path, and
    // drops the path's last segment for a path; "special authority slashes"
    // and "special authority ignore slashes" skip a scheme's missing or extra
    // slashes; in "path" a backslash is a slash and a space is `%20` (the
    // path percent-encode set); tabs and newlines are removed, and leading
    // and trailing C0 controls and spaces cut, before parsing. Section 3.5:
    // an empty label and `_` are a domain's; a space, and an empty host in
    // a special URL, are not; a host that ends in a number is IPv4 (`0x7f.1`
    // is 127.0.0.1); a port over 65535 fails.
    const open = 'https://example.com/docs';
    const outcomes = <String, Object>{
      open: [open],
      'http://example.com': ['http://example.com/'],
      'HTTPS://Example.com/Docs': ['https://example.com/Docs'],
      'Http://example.com': ['http://example.com/'],
      '/relative': ['http://localhost:3000/relative'],
      'relative/path?q=1#h': ['http://localhost:3000/relative/path?q=1#h'],
      '?only=query': ['http://localhost:3000/?only=query'],
      '#only-hash': ['http://localhost:3000/#only-hash'],
      '//example.com/protocol-relative': [
        'http://example.com/protocol-relative',
      ],
      'https://example..com/': ['https://example..com/'],
      'https://.example.com/': ['https://.example.com/'],
      'https://example.com./': ['https://example.com./'],
      'https://exa_mple.com/': ['https://exa_mple.com/'],
      'https://EXAMPLE.com:8443/a b': ['https://example.com:8443/a%20b'],
      'https://user:pass@example.com/': ['https://user:pass@example.com/'],
      'https://[::1]:8080/': ['https://[::1]:8080/'],
      'https://192.168.0.1/': ['https://192.168.0.1/'],
      'https://0x7f.1/': ['https://127.0.0.1/'],
      // UTS #46 (tr46@6.0.0's table: U+4F8B and U+3048 valid), then
      // Punycode (RFC 3492): "例え" is "r8jz45g".
      'https://例え.jp/': ['https://xn--r8jz45g.jp/'],
      'https:example.com': ['https://example.com/'],
      'http:example.com': ['http://localhost:3000/example.com'],
      'https:///path': ['https://path/'],
      'https://': 'ExpressionError: "https://" is not a URL',
      'https://exa mple.com/':
          'ExpressionError: "https://exa mple.com/" is not a URL',
      'https://example.com:99999/':
          'ExpressionError: "https://example.com:99999/" is not a URL',
      r'https://exa\mple.com/': ['https://exa/mple.com/'],
      r'https://example.com/a\b': ['https://example.com/a/b'],
      'https://example.com/a\nb': ['https://example.com/ab'],
      '  https://example.com/trim  ': ['https://example.com/trim'],
      'javascript:alert(1)':
          'ExpressionError: openUrl takes only http(s) URLs, not javascript:',
      'JavaScript:alert(1)':
          'ExpressionError: openUrl takes only http(s) URLs, not javascript:',
      'data:text/html,hi':
          'ExpressionError: openUrl takes only http(s) URLs, not data:',
      'ftp://example.com/':
          'ExpressionError: openUrl takes only http(s) URLs, not ftp:',
      'mailto:a@b.co':
          'ExpressionError: openUrl takes only http(s) URLs, not mailto:',
    };
    for (final MapEntry(key: url, value: outcome) in outcomes.entries) {
      // functions.test.ts:422
      test(
        '${jsonEncode(url)} gives the same result as before',
        skip:
            url == 'https://例え.jp/' &&
            portQueue(
              'port-queue: openUrl: a non-ASCII host waits for UTS #46 '
              "(tr46's mapping table, NFC, Punycode) on the web path: "
              'whatwg_url.dart refuses it as "https://例え.jp/" is not a URL '
              '(INV-201)',
            ),
        () async {
          _onTheWeb();
          final launcher = fakeUrlLauncher();
          expect(await _outcome(_openUrl(), launcher, url), outcome);
        },
      );
    }

    // functions.test.ts:436
    test('opens hosts WHATWG URL accepts, such as empty labels', () async {
      _onTheWeb();
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      await open('https://example..com/');
      await open('https://.example.com/');
      expect(
        [for (final launch in launcher.launches) launch.url],
        ['https://example..com/', 'https://.example.com/'],
      );
    });

    // functions.test.ts:446. Against `file:///Users/me/page.html`, "/relative"
    // is `file:///relative` and "x.html" `file:///Users/me/x.html` (section
    // 4.4's "file" and "file slash" states: the page's path, its last segment
    // dropped for a path), so both are refused for their scheme; upstream
    // counts the opened URL twice, once from openUrl and once from the code
    // before React Native.
    test(
      'resolves against a page that is not http(s), as WHATWG URL does',
      () async {
        _onTheWeb('file:///Users/me/page.html');
        final launcher = fakeUrlLauncher();
        final open = _openUrl();
        expect(await _outcome(open, launcher, 'https://example..com/'), [
          'https://example..com/',
        ]);
        for (final url in ['/relative', 'x.html']) {
          expect(
            await _outcome(open, launcher, url),
            'ExpressionError: openUrl takes only http(s) URLs, not file:',
          );
        }
        expect(
          [for (final launch in launcher.launches) launch.url],
          ['https://example..com/'],
        );
      },
    );
  });

  group('beyond functions.test.ts (ours)', () {
    // functions.ts:440-466 off a page: `parseUrl` (functions.ts:341) checks
    // the host with `HOSTNAME` (functions.ts:242), which allows no empty
    // label, so the URLs that :436 opens on a page are refused here. The
    // mirror of :436 off the web.
    test('refuses a host with an empty label where there is no page', () async {
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      for (final url in ['https://example..com/', 'https://.example.com/']) {
        await expectLater(open(url), _throwsExactly('"$url" is not a URL'));
      }
      await pumpEventQueue();
      expect(launcher.launches, isEmpty);
    });

    // functions.ts:390-401, `pageBase`: a page whose host is reserved
    // (`.invalid`, with or without its trailing dot) is no page, so the
    // no-page path decides (functions.ts:455-467), as a React Native
    // location polyfill would.
    for (final page in [
      'http://react-native.invalid/',
      'http://INVALID./index.html',
    ]) {
      test('takes a page on a reserved host ($page) for no page', () async {
        _onTheWeb(page);
        final launcher = fakeUrlLauncher();
        final open = _openUrl();
        await expectLater(
          open('/relative'),
          _throwsExactly('"/relative" is not an absolute URL'),
        );
        await expectLater(
          open('https://example..com/'),
          _throwsExactly('"https://example..com/" is not a URL'),
        );
        await open('https://example.com/docs');
        expect(launcher.opened, [openedInNewTab('https://example.com/docs')]);
      });
    }

    // RULEBOOK section 0: the page path on the web only. The same URL opens
    // against the page on the web, and is refused off it, whatever page the
    // override names.
    test('resolves a relative URL against the page only on the web', () async {
      debugKitPageHrefOverride = _jsdomPage;
      addTearDown(() => debugKitPageHrefOverride = null);
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      debugKitIsWebOverride = false;
      addTearDown(() => debugKitIsWebOverride = null);
      await expectLater(
        open('x.html'),
        _throwsExactly('"x.html" is not an absolute URL'),
      );
      debugKitIsWebOverride = true;
      await open('x.html');
      expect(launcher.opened, [openedInNewTab('http://localhost:3000/x.html')]);
    });

    test('takes no page on the web path when none is known', () async {
      debugKitIsWebOverride = true;
      addTearDown(() => debugKitIsWebOverride = null);
      final launcher = fakeUrlLauncher();
      await expectLater(
        _openUrl()('/relative'),
        _throwsExactly('"/relative" is not an absolute URL'),
      );
      expect(launcher.launches, isEmpty);
    });

    test(
      'hands the URL to onOpenUrl, as a Uri, and opens nothing itself',
      () async {
        final launcher = fakeUrlLauncher();
        final opened = <Uri>[];
        final open = _openUrl(options: A2uiKitOptions(onOpenUrl: opened.add));
        await open('HTTPS://Example.com/Docs?q=1');
        _onTheWeb();
        await open('/relative');
        expect(opened, [
          Uri.parse('https://example.com/Docs?q=1'),
          Uri.parse('http://localhost:3000/relative'),
        ]);
        await expectLater(
          open('ftp://example.com/'),
          _throwsExactly('openUrl takes only http(s) URLs, not ftp:'),
        );
        expect(opened, hasLength(2));
        expect(launcher.launches, isEmpty);
      },
    );

    // More of the URL Standard on the web path, each worked out from it: the
    // IPv6 serializer compresses the first longest run of two or more zero
    // pieces (section 3.6) and writes an embedded IPv4 address in hex; a
    // scheme's default port is dropped, and one over 65535 fails (section
    // 4.4, "port" state); dot
    // segments, `%2e` included, are resolved ("path" state); the special-
    // query set encodes `'` and the fragment set a backtick (section 1.3);
    // a path's non-ASCII code point is UTF-8 percent-encoded; a username's
    // second `@` is `%40`; a host is percent-decoded before it is checked,
    // and a U+0000 in it fails (section 3.5); a relative URL resolves
    // against the page's directory.
    const webOutcomes = <String, Object>{
      'https://[2001:DB8:0:0:8:800:200C:417A]/': [
        'https://[2001:db8::8:800:200c:417a]/',
      ],
      'https://[::1.2.3.4]/': ['https://[::102:304]/'],
      'https://[1:0:0:2:0:0:0:3]/': ['https://[1:0:0:2::3]/'],
      'https://[1:0:0:2:0:0:3:4]/': ['https://[1::2:0:0:3:4]/'],
      'https://[::1': 'ExpressionError: "https://[::1" is not a URL',
      'https://example.com:443/': ['https://example.com/'],
      'http://example.com:80/': ['http://example.com/'],
      'https://example.com:080/': ['https://example.com:80/'],
      'https://example.com:65535/': ['https://example.com:65535/'],
      'https://example.com:65536/':
          'ExpressionError: "https://example.com:65536/" is not a URL',
      'HTTP://EXAMPLE.COM:8080': ['http://example.com:8080/'],
      'https://example.com/a/./b/../c': ['https://example.com/a/c'],
      'https://example.com/%2e%2E/x': ['https://example.com/x'],
      "https://example.com/a?b='c d'#e`f": [
        'https://example.com/a?b=%27c%20d%27#e%60f',
      ],
      'https://example.com/?q=a#b#c': ['https://example.com/?q=a#b#c'],
      'https://example.com/ü': ['https://example.com/%C3%BC'],
      'https://a b@example.com/': ['https://a%20b@example.com/'],
      'https://u@@example.com/': ['https://u%40@example.com/'],
      'https://ex%41mple.com/': ['https://example.com/'],
      'https://exa%00mple.com/':
          'ExpressionError: "https://exa%00mple.com/" is not a URL',
      'https://4294967295/': ['https://255.255.255.255/'],
      'https://4294967296/':
          'ExpressionError: "https://4294967296/" is not a URL',
      'https://1.2.3.4.5/':
          'ExpressionError: "https://1.2.3.4.5/" is not a URL',
      '../d': ['https://host.test/a/d'],
      './e?x': ['https://host.test/a/b/e?x'],
      'f': ['https://host.test/a/b/f'],
    };
    for (final MapEntry(key: url, value: outcome) in webOutcomes.entries) {
      test('opens ${jsonEncode(url)} on the web as WHATWG URL does', () async {
        _onTheWeb('https://host.test/a/b/c.html');
        final launcher = fakeUrlLauncher();
        expect(await _outcome(_openUrl(), launcher, url), outcome);
      });
    }

    // Off the web, CopilotKit's parseUrl (functions.ts:341-375), each outcome
    // read from it: a C0 control after the scheme fails (:350), a backslash
    // before the query fails and one after it is kept (:357), white space
    // in the userinfo or a port over 65535 fails (:366), a missing path is
    // "/" and a space in it `%20` (:369-373), the userinfo and the port are
    // kept as written and an empty port dropped, the host lowercased (:364),
    // an IPv4 part may be octal (:290), a scheme needs "//" (:350).
    const offTheWeb = <String, Object>{
      'https://example.com/a\u0001b':
          'ExpressionError: "https://example.com/a\u0001b" is not a URL',
      r'https://example.com/a\b':
          r'ExpressionError: "https://example.com/a\b" is not a URL',
      r'https://example.com/a?q=\b': [r'https://example.com/a?q=\b'],
      'https://a b@example.com/':
          'ExpressionError: "https://a b@example.com/" is not a URL',
      'https://example.com:65536/':
          'ExpressionError: "https://example.com:65536/" is not a URL',
      'https://example.com:65535/': ['https://example.com:65535/'],
      'https://example.com?q=1': ['https://example.com/?q=1'],
      'https://example.com#frag': ['https://example.com/#frag'],
      'https://example.com/a b': ['https://example.com/a%20b'],
      'https://example.com:080/': ['https://example.com:080/'],
      'https://example.com:/': ['https://example.com/'],
      'https://u:p@Example.com/': ['https://u:p@example.com/'],
      ' https://example.com/x ': ['https://example.com/x'],
      'https://1.2.3.04/': ['https://1.2.3.4/'],
      'https://example.com./': ['https://example.com./'],
      'https:example.com': 'ExpressionError: "https:example.com" is not a URL',
    };
    for (final MapEntry(key: url, value: outcome) in offTheWeb.entries) {
      test('opens ${jsonEncode(url)} off the web as parseUrl does', () async {
        final launcher = fakeUrlLauncher();
        expect(await _outcome(_openUrl(), launcher, url), outcome);
      });
    }

    test('takes only a non-empty string', () async {
      final launcher = fakeUrlLauncher();
      final open = _openUrl();
      for (final url in [
        null,
        '',
        42,
        true,
        <Object?>['https://x.y/'],
      ]) {
        await expectLater(open(url), _throwsExactly('url must be a string'));
      }
      expect(launcher.launches, isEmpty);
    });

    group('validators, as CopilotKit words them', () {
      ValidationResult invalid(String message, String code) =>
          ValidationResult(valid: false, message: message, code: code);
      const valid = ValidationResult(valid: true);

      test('required fails on null, "" and [] only', () {
        expect(_fn('required', {}), invalid('Required', 'required'));
        expect(_fn('required', {'value': ''}), invalid('Required', 'required'));
        expect(_fn('required', {'value': <Object?>[]}), isNot(valid));
        expect(_fn('required', {'value': false}), valid);
        expect(_fn('required', {'value': 0}), valid);
      });

      test('regex is unanchored and needs a string pattern', () {
        expect(_fn('regex', {'value': 'ab12', 'pattern': r'\d+'}), valid);
        expect(
          _fn('regex', {'value': 'ab', 'pattern': r'^\d+$'}),
          invalid('Invalid format', 'pattern'),
        );
        expect(
          () => _fn('regex', {'value': 'a', 'pattern': 1}),
          _throwsExpression('pattern must be a string'),
        );
        expect(
          () => _fn('regex', {'value': 'a', 'pattern': '('}),
          _throwsExpression('is not a regular expression'),
        );
      });

      test('length takes both bounds inclusively', () {
        final bounds = {'min': 2, 'max': 3};
        expect(
          _fn('length', {'value': 'a', ...bounds}),
          invalid('At least 2 characters', 'tooShort'),
        );
        expect(_fn('length', {'value': 'ab', ...bounds}), valid);
        expect(_fn('length', {'value': 'abc', ...bounds}), valid);
        expect(
          _fn('length', {'value': 'abcd', ...bounds}),
          invalid('At most 3 characters', 'tooLong'),
        );
        expect(_fn('length', {'value': '', 'min': 0}), valid);
        expect(_fn('length', {'value': null, 'max': 0}), valid);
        expect(_fn('length', {'value': 12345, 'max': 5}), valid);
      });

      test('length and numeric give the bound in the message', () {
        expect(
          _fn('length', {'value': 'ab', 'min': 3}),
          invalid('At least 3 characters', 'tooShort'),
        );
        expect(
          _fn('length', {'value': 'abcd', 'max': 3}),
          invalid('At most 3 characters', 'tooLong'),
        );
        expect(
          _fn('numeric', {'value': 'x'}),
          invalid('Must be a number', 'notANumber'),
        );
        expect(
          _fn('numeric', {'value': '4', 'min': 5}),
          invalid('At least 5', 'tooSmall'),
        );
        expect(
          _fn('numeric', {'value': 9.5, 'max': 9}),
          invalid('At most 9', 'tooLarge'),
        );
        expect(
          () => _fn('numeric', {'value': 1, 'min': 'x'}),
          _throwsExpression('min must be a number'),
        );
      });

      test('email', () {
        expect(_fn('email', {'value': 'a@b.co'}), valid);
        expect(
          _fn('email', {'value': 'a@b'}),
          invalid('Invalid email address', 'email'),
        );
      });
    });

    group('formatCurrency', () {
      test("uses the currency's own fraction digits", () {
        expect(
          _fn('formatCurrency', {'value': 1234.5, 'currency': 'JPY'}),
          '¥1,235',
        );
        expect(
          _fn('formatCurrency', {'value': 1.5, 'currency': 'BHD'}),
          'BHD\u{a0}1.500',
        );
        expect(
          _fn('formatCurrency', {'value': 12, 'currency': 'usd'}),
          r'$12.00',
        );
      });

      test(
        "writes CLDR English symbols, apart from the number when they're words",
        () {
          expect(
            _fn('formatCurrency', {'value': 12.5, 'currency': 'CAD'}),
            r'CA$12.50',
          );
          expect(
            _fn('formatCurrency', {'value': 12.5, 'currency': 'CHF'}),
            'CHF\u{a0}12.50',
          );
          expect(
            _fn('formatCurrency', {'value': -3, 'currency': 'INR'}),
            '-₹3.00',
          );
        },
      );

      test('needs a number and a code, as CopilotKit says', () {
        expect(
          () => _fn('formatCurrency', {'value': 'x', 'currency': 'EUR'}),
          _throwsExpression('value must be a number'),
        );
        expect(
          () => _fn('formatCurrency', {'value': 1, 'currency': ''}),
          _throwsExpression('currency must be an ISO 4217 code'),
        );
      });
    });

    group('formatNumber', () {
      test('reads numeric text, rejects other values, checks decimals', () {
        expect(_fn('formatNumber', {'value': ' 1e3 '}), '1,000');
        expect(
          () => _fn('formatNumber', {'value': true}),
          _throwsExpression('value must be a number'),
        );
        expect(
          () => _fn('formatNumber', {'value': 1, 'decimals': 'x'}),
          _throwsExpression('decimals must be a number'),
        );
        expect(
          () => _fn('formatNumber', {'value': 1, 'decimals': 101}),
          _throwsExpression('out of range'),
        );
        // Only a literal false turns grouping off, as `grouping !== false`.
        expect(_fn('formatNumber', {'value': 1234, 'grouping': 0}), '1,234');
      });

      test('rounds the shortest decimal half away from zero, as Intl does', () {
        // `new Intl.NumberFormat("en-US", {minimumFractionDigits: 2,
        // maximumFractionDigits: 2}).format(1.005)` is "1.01": ICU rounds
        // the decimal 1.005, not the double just below it.
        expect(_fn('formatNumber', {'value': 1.005, 'decimals': 2}), '1.01');
        expect(_fn('formatNumber', {'value': 2.675, 'decimals': 2}), '2.68');
        expect(_fn('formatNumber', {'value': -2.675, 'decimals': 2}), '-2.68');
        // The default format keeps at most three decimals.
        expect(_fn('formatNumber', {'value': 1.0005}), '1.001');
        expect(_fn('formatNumber', {'value': 0.1 + 0.2}), '0.3');
        expect(_fn('formatNumber', {'value': 9.995, 'decimals': 2}), '10.00');
        expect(_fn('formatNumber', {'value': 1.25, 'decimals': 1}), '1.3');
        expect(
          _fn('formatCurrency', {'value': 1.005, 'currency': 'USD'}),
          r'$1.01',
        );
        expect(
          _fn('formatCurrency', {'value': 0.125, 'currency': 'EUR'}),
          '€0.13',
        );
        expect(_fn('formatCurrency', {'value': 2.5, 'currency': 'JPY'}), '¥3');
      });
    });

    group('roundedDecimalDigits', () {
      test('rounds the shortest decimal of a magnitude', () {
        expect(roundedDecimalDigits(1.005, 2), (whole: '1', fraction: '01'));
        expect(roundedDecimalDigits(0.0006, 3), (whole: '0', fraction: '001'));
        expect(roundedDecimalDigits(9.999, 2), (whole: '10', fraction: '00'));
        expect(roundedDecimalDigits(1.5e-7, 7), (
          whole: '0',
          fraction: '0000002',
        ));
        expect(roundedDecimalDigits(1e21, 0), (
          whole: '1000000000000000000000',
          fraction: '',
        ));
        expect(roundedDecimalDigits(12, 1), (whole: '12', fraction: '0'));
        expect(roundLikeIntl(-0.004, 2).isNegative, isTrue);
        expect(roundLikeIntl(-0.004, 2), 0);
        expect(roundLikeIntl(double.infinity, 2), double.infinity);
      });
    });

    group('formatDate', () {
      test('reads a timestamp in milliseconds as a local date', () {
        final midnight = DateTime(2026, 11, 7).millisecondsSinceEpoch;
        expect(
          _fn('formatDate', {'value': midnight, 'format': 'yyyy-MM-dd HH:mm'}),
          '2026-11-07 00:00',
        );
        expect(
          _fn('formatDate', {'value': midnight + 0.9, 'format': 'ss'}),
          '00',
        );
        expect(
          () => _fn('formatDate', {'value': double.nan, 'format': 'd'}),
          _throwsExpression('must be a date'),
        );
      });

      test('shows an instant with an offset in local time', () {
        final local = DateTime.parse('2026-10-19T14:05:00Z').toLocal();
        expect(
          _fn('formatDate', {
            'value': '2026-10-19T14:05:00Z',
            'format': 'H:mm d',
          }),
          '${local.hour}:${'${local.minute}'.padLeft(2, '0')} ${local.day}',
        );
      });

      test('takes runs of a letter as one field and keeps other letters', () {
        expect(
          _fn('formatDate', {
            'value': '2026-03-04T05:06:07',
            'format': 'yy y M MM MMMM',
          }),
          '26 2026 3 03 March',
        );
        expect(
          _fn('formatDate', {
            'value': '2026-03-04T15:06:07',
            'format': 'd dd h hh H HH m s a',
          }),
          '4 04 3 03 15 15 06 07 PM',
        );
        expect(
          _fn('formatDate', {
            'value': '2026-03-04T00:00',
            'format': "EEEEE 'T' T Z''",
          }),
          'Wednesday T T Z',
        );
        expect(
          _fn('formatDate', {'value': '2026-03-04T00:30', 'format': 'h:mm a'}),
          '12:30 AM',
        );
      });

      test('needs a string format and a date', () {
        expect(
          () => _fn('formatDate', {'value': '2026-10-19'}),
          _throwsExpression('format must be a string'),
        );
        expect(
          () => _fn('formatDate', {'value': true, 'format': 'd'}),
          _throwsExpression('must be a date'),
        );
      });
    });

    group('pluralize', () {
      test("uses the locale's category, not an exact number form", () {
        const forms = {'one': 'item', 'two': 'pair', 'other': 'items'};
        expect(_fn('pluralize', {'value': 2, ...forms}), 'items');
        expect(_fn('pluralize', {'value': -1, ...forms}), 'item');
        expect(_fn('pluralize', {'value': 1.5, ...forms}), 'items');
        expect(_fn('pluralize', {'value': '1', ...forms}), 'item');
        expect(_fn('pluralize', {'value': 3}), '');
        expect(
          () => _fn('pluralize', {'value': 'many', ...forms}),
          _throwsExpression('value must be a number'),
        );
      });
    });

    group('and, or and not', () {
      test('take any number of values with JavaScript truth', () {
        expect(
          _fn('and', {
            'values': [true],
          }),
          isTrue,
        );
        expect(_fn('and', {'values': <Object?>[]}), isTrue);
        expect(_fn('or', {'values': <Object?>[]}), isFalse);
        expect(
          _fn('and', {
            'values': ['Ada', 1, <Object?>[]],
          }),
          isTrue,
        );
        expect(
          _fn('and', {
            'values': ['Ada', 0],
          }),
          isFalse,
        );
        expect(
          _fn('or', {
            'values': ['', null, 'x'],
          }),
          isTrue,
        );
        expect(_fn('not', {'value': 'Ada'}), isFalse);
        expect(_fn('not', {'value': ''}), isTrue);
        expect(_fn('not', {}), isTrue);
        expect(
          _fn('and', {
            'values': [const ValidationResult(valid: false)],
          }),
          isFalse,
        );
        expect(
          _fn('or', {
            'values': [
              {'valid': true},
            ],
          }),
          isTrue,
        );
      });
    });

    group('through a surface', () {
      testWidgets('and, or and not read bound values with JavaScript truth', (
        tester,
      ) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['send', 'both', 'one'],
            },
            {
              'id': 'send',
              'component': 'Button',
              'label': 'Send',
              'disabled': {
                '@call': 'not',
                'args': {
                  'value': {'@path': '/name'},
                },
              },
              'onClick': {
                'event': {'name': 'send'},
              },
            },
            {
              'id': 'both',
              'component': 'CheckBox',
              'label': 'Both',
              'value': {
                '@call': 'and',
                'args': {
                  'values': [
                    {'@path': '/name'},
                    true,
                  ],
                },
              },
            },
            {
              'id': 'one',
              'component': 'CheckBox',
              'label': 'One',
              'value': {
                '@call': 'and',
                'args': {
                  'values': [true],
                },
              },
            },
          ],
          data: {'name': 'Ada'},
        );
        await tester.tap(find.text('Send'));
        await tester.pump();
        expect(view.actions, hasLength(1));
        // Both check boxes read as checked.
        for (final name in ['Both', 'One']) {
          expect(
            tester
                .getSemantics(find.text(name, findRichText: true))
                .flagsCollection
                .isChecked,
            CheckedState.isTrue,
            reason: name,
          );
        }
        expect(view.errors, isEmpty);
      });

      testWidgets('formatDate, formatCurrency, pluralize and formatString', (
        tester,
      ) async {
        final view = await renderStandard(
          tester,
          [
            {
              'id': 'root',
              'component': 'Column',
              'children': ['date', 'yen', 'plural', 'list', 'log'],
            },
            _text('date', {
              '@call': 'formatDate',
              'args': {'value': '2026-11-07', 'format': 'EEE, MMM d'},
            }),
            _text('yen', {
              '@call': 'formatCurrency',
              'args': {'value': 1234.5, 'currency': 'JPY'},
            }),
            _text('plural', {
              '@call': 'pluralize',
              'args': {
                'value': 2,
                'one': 'item',
                'two': 'pair',
                'other': 'items',
              },
            }),
            _text('list', {
              '@call': 'formatString',
              'args': {'value': r'Tags: ${/tags}'},
            }),
            _text('log', {
              '@call': 'calc',
              'args': {'expression': "'log=' + floor(log10(1000))"},
            }),
          ],
          data: {
            'tags': ['a', 'b'],
          },
        );
        expect(
          _texts(tester),
          containsAll(['Sat, Nov 7', '¥1,235', 'items', 'Tags: a,b', 'log=3']),
        );
        expect(view.errors, isEmpty);
      });

      testWidgets('formatString refuses a function the catalog lacks', (
        tester,
      ) async {
        final view = await renderStandard(tester, [
          _text('root', {
            '@call': 'formatString',
            'args': {'value': r'${nope()}'},
          }),
        ]);
        await tester.pump();
        expect(
          view.errors.map((e) => e.message),
          contains(contains('"nope" is not a basic function')),
        );
      });
    });
  });
}
