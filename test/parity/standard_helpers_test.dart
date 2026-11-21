// Parity tests of CopilotKit's shared standard helpers, ported from
// packages/shared/src/generative-ui/standard/__tests__/standard-helpers.test.ts
// (MIT, (c) Atai Barkai). Each test names its upstream file and line.
//
// Parity for: Box, Column, Row, Text, (engine)
//
// Its Chart helpers (`chartConfig`, `normalizeSeries`, `makeFormatter`,
// `resolveCssColor`, `withAlpha`, lines 197-340) are ported in
// test/parity/chart_test.dart.
//
// `layoutStyle(props)` is `ContainerCss.layout` (CopilotKit's layoutStyle,
// property by property), `radiusStyle` its `radiusOf`, `px` is
// `A2uiLength.pixels`, `safeHref` and `openUrl` are `safeHref` and
// `openSafeUrl` (lib/src/foundation/interaction/links.dart), whose opener,
// with no `onOpenUrl`, is url_launcher: a fake `UrlLauncherPlatform`
// (`fakeUrlLauncher`) is upstream's stubbed `window.open`, and
// `webOnlyWindowName: '_blank'` its `"_blank"` target. Upstream's
// `calc(var(--spacing, 0.25rem) * n)` is 4n px, `var(--a2ui-radius-lg,
// 12px)` 12px.
//
// Not ported (bound to internals):
// - standard-helpers.test.ts:39 `boxSizing: "border-box"`: every Flutter
//   box holds its padding and border inside its size (A2uiBoxStyle). The
//   other keys, set and unset, are tested.
// - standard-helpers.test.ts:66 `not.toHaveProperty("gap")`: a React style
//   object applied in sorted key order, where a `gap` key would erase
//   `columnGap`. That the longhands win over the shorthand is tested.
// - standard-helpers.test.ts:127 "drops undefined entries and keeps zero"
//   (`defined`): removes `undefined` values from a JavaScript object; a Dart
//   prop map has no `undefined`, and a prop ContainerCss leaves unset is
//   null (tested at :39).
// - standard-helpers.test.ts:174 the `"noopener,noreferrer"` features of
//   `window.open`: url_launcher_web opens its new tab with them; no
//   platform interface carries them. The URL and the `_blank` window are
//   tested.
//
// Not ours:
// - standard-helpers.test.ts:192 "does nothing on the server, where there
//   is no window": server rendering, a JavaScript platform value (`window`
//   undefined); a Flutter app always runs with its platform's window.
//
// The layoutStyle and radiusStyle tests read `ContainerCss`, the CSS a
// container is given, before `flexContainer`, `CssFlex` and
// `RenderCssFlex` draw it. What each value does is drawn and checked in
// the layout parity files:
// - align center: layout_parity_test.dart (layout-parity.test.tsx:102,
//   Row children centred) and layout_test.dart (layout.test.tsx:145);
// - justify spaceBetween: layout_test.dart (layout.test.tsx:84) and
//   layout_parity_test.dart (:102, the last Text at the Row's end);
// - padding in 4px steps: layout_test.dart (layout.test.tsx:64, :187);
// - minWidth 0 and maxWidth 100%: layout_test.dart (layout.test.tsx:112,
//   containers inside their parent at 1000px);
// - flush and disableAutoSpacing: layout_parity_test.dart
//   (layout-parity.test.tsx:179, no padding, no gap);
// - gap and its longhands: layout_test.dart (layout.test.tsx:133, 8px
//   between Row children unless a gap is given);
// - scrollable: layout_test.dart (layout.test.tsx:321, queued) and
//   tokens_test.dart (tokens.test.ts:130, queued);
// - radius: layout_test.dart (layout.test.tsx:64's `lg`, :187's Card).
// `clip` (overflow: hidden) and the corner-object radius of :99 are drawn
// by no parity test: they stand on these reads alone.
//
// Later phase (no Dart yet):
// - standard-helpers.test.ts:154 "reads the host of a URL with or without a
//   scheme", :161 "gives undefined for text that is not a URL" and :166
//   "builds the favicon URL with the host encoded" (`hostOf`, `faviconSrc`:
//   Favicon, LinkCard).
// - standard-helpers.test.ts:343 "guards numeric property comparisons with
//   a has check, at any depth", :362 "leaves comparisons that do not compare
//   a property with a number", :371 "guards the filter of each style layer
//   and keeps layers without one" and :383 "returns a style without layers
//   as it is" (`guardNumericFilter`, `guardStyleFilters`: Map).
// - standard-helpers.test.ts:390 "accepts a marker with finite coordinates
//   only" and :402 "recognizes a module with a Map constructor"
//   (`isValidMarker`, `isMapLibre`: Map).

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// Upstream's `layoutStyle(props)`, in the standard look at a 16px font.
ContainerCss _layout(Map<String, Object?> props) => ContainerCss.layout(
  ComponentProps(props),
  theme: standardLight,
  fontSize: 16,
);

/// Upstream's `radiusStyle(value)`.
BorderRadiusGeometry? _radius(Object? value) =>
    _layout(const {}).radiusOf(value);

/// A context under a surface of the standard catalog with no `onOpenUrl`,
/// so its links open through url_launcher, which [fakeUrlLauncher]
/// records: upstream's stubbed `window.open`.
Future<BuildContext> _kitContext(WidgetTester tester) async {
  await renderStandard(tester, [
    {'id': 'root', 'component': 'Text', 'text': 'x'},
  ]);
  return tester.element(find.text('x', findRichText: true));
}

void main() {
  group('layoutStyle', () {
    // standard-helpers.test.ts:39
    test('maps the layout props to flex container CSS and leaves out unset '
        'props', () {
      final css = _layout({
        'align': 'center',
        'justify': 'spaceBetween',
        'padding': 2,
      });
      // display: flex.
      expect(css.inline, isFalse);
      // alignItems: center.
      expect(css.align, A2uiAlign.center);
      // justifyContent: space-between.
      expect(css.justify, A2uiJustify.spaceBetween);
      // padding: calc(var(--spacing, 0.25rem) * 2).
      expect(css.padding, const EdgeInsets.all(8));
      // minWidth: 0.
      expect(css.minWidth, A2uiLength.zero);
      // maxWidth: 100%.
      expect(css.maxWidth, const A2uiLength.percent(1));
      // Nothing else: each other property keeps CSS's initial value.
      expect(css.direction, Axis.horizontal);
      expect(css.wrap, A2uiWrap.nowrap);
      expect(css.hasGap, isFalse);
      expect(css.gap, isNull);
      expect(css.rowGap, isNull);
      expect(css.columnGap, isNull);
      expect(css.background, isNull);
      expect(css.borderColor, isNull);
      expect(css.radius, isNull);
      expect(css.shadow, isNull);
      expect(css.width, isNull);
      expect(css.height, isNull);
      expect(css.minHeight, isNull);
      expect(css.maxHeight, isNull);
      expect(css.aspectRatio, isNull);
      expect(css.scroll, isFalse);
      expect(css.clip, isFalse);
    });

    // standard-helpers.test.ts:56
    test('removes the padding for flush and sets overflow for scrollable and '
        'clip', () {
      // padding: 0.
      expect(_layout({'padding': 4, 'flush': true}).padding, EdgeInsets.zero);
      // overflow: auto.
      final scrollable = _layout({'scrollable': true, 'clip': true});
      expect(scrollable.scroll, isTrue);
      expect(scrollable.clip, isFalse);
      // overflow: hidden.
      final clip = _layout({'clip': true});
      expect(clip.clip, isTrue);
      expect(clip.scroll, isFalse);
    });

    // standard-helpers.test.ts:66
    test('lets rowGap and columnGap win over gap, with no shorthand to '
        'override them', () {
      final both = _layout({'gap': 2, 'columnGap': 6}).toFlex();
      // rowGap: calc(var(--spacing, 0.25rem) * 2).
      expect(both.rowGap, 8);
      // columnGap: calc(var(--spacing, 0.25rem) * 6).
      expect(both.columnGap, 24);
      final rowOnly = _layout({'rowGap': 1});
      // rowGap: calc(var(--spacing, 0.25rem) * 1).
      expect(rowOnly.toFlex().rowGap, 4);
      // No columnGap.
      expect(rowOnly.columnGap, isNull);
    });

    // standard-helpers.test.ts:82
    test('keeps the gap shorthand when no longhand is set', () {
      // gap: calc(var(--spacing, 0.25rem) * 3).
      expect(_layout({'gap': 3}).gap, const A2uiLength.px(12));
      // gap: 0.
      expect(_layout({'disableAutoSpacing': true}).gap, A2uiLength.zero);
      // No gap.
      expect(_layout(const {}).gap, isNull);
    });
  });

  group('radiusStyle', () {
    // standard-helpers.test.ts:92
    test('gives one border radius for a token or a number', () {
      // var(--a2ui-radius-lg, 12px).
      expect(_radius('lg'), BorderRadius.circular(12));
      // 8px.
      expect(_radius(8), BorderRadius.circular(8));
    });

    // standard-helpers.test.ts:99
    test('gives one radius for each corner of a corner object', () {
      expect(
        _radius({
          'topLeft': 'lg',
          'topRight': '2px',
          'bottomLeft': 'full',
          'bottomRight': '0',
        }),
        const BorderRadius.only(
          // var(--a2ui-radius-lg, 12px).
          topLeft: Radius.circular(12),
          topRight: Radius.circular(2),
          bottomLeft: Radius.circular(9999),
          // "0": BorderRadius.only's default corner, Radius.zero.
        ),
      );
    });

    // standard-helpers.test.ts:115
    test('gives no CSS when the radius is not set', () {
      expect(_radius(null), isNull);
    });
  });

  group('px and defined', () {
    // standard-helpers.test.ts:121
    test('gives pixels for a number and passes a string through', () {
      expect(A2uiLength.pixels(12), const A2uiLength.px(12));
      // The CSS length 1rem: 16px (CSS Values 4 §6.1.1, `rem` is the root
      // element's font size; its initial `medium` is 16px in every
      // browser, CSS Fonts 4 §2.5).
      expect(A2uiLength.pixels('1rem'), const A2uiLength.px(16));
      expect(A2uiLength.pixels(null), isNull);
    });
  });

  group('safeHref', () {
    for (final (url, expected) in [
      (' https://example.com/a ', 'https://example.com/a'),
      ('http://example.com', 'http://example.com'),
      ('HTTPS://EXAMPLE.COM', 'HTTPS://EXAMPLE.COM'),
      ('mailto:team@example.com', 'mailto:team@example.com'),
    ]) {
      // standard-helpers.test.ts:136
      test('accepts $url', () {
        expect(safeHref(url), expected);
      });
    }

    for (final url in [
      'javascript:alert(1)',
      ' data:text/html,hi',
      '/relative/path',
    ]) {
      // standard-helpers.test.ts:145
      test('rejects $url', () {
        expect(safeHref(url), isNull);
      });
    }
  });

  group('openUrl', () {
    // standard-helpers.test.ts:174
    testWidgets('opens a safe URL in a new tab without an opener', (
      tester,
    ) async {
      final launcher = fakeUrlLauncher();
      final context = await _kitContext(tester);
      await openSafeUrl(context, ' https://example.com ');
      expect(launcher.opened, [openedInNewTab('https://example.com')]);
    });

    // standard-helpers.test.ts:185
    testWidgets('ignores an unsafe scheme', (tester) async {
      final launcher = fakeUrlLauncher();
      final context = await _kitContext(tester);
      await openSafeUrl(context, 'javascript:alert(1)');
      await tester.pump();
      // Nothing reaches the platform: upstream's spy sees every open.
      expect(launcher.launches, isEmpty);
    });
  });
}
