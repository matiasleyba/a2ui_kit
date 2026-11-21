// Parity tests of CopilotKit's standard tokens, ported from
// packages/shared/src/generative-ui/standard/__tests__/tokens.test.ts
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: Box, Column, Row, Text, Markdown, (engine)
//
// The token functions write CSS; the theme resolves the same props to
// values. `var(--a2ui-color-<token>, <fallback>)` reads as the fallback in
// the standard look and the theme's colour of that token once a theme sets
// one; `calc(var(--spacing, 0.25rem) * n)` as n spacing steps of 4px; a
// value that is no token passes through as CSS, so it resolves to what CSS
// makes of it (nothing, when it is no valid colour or length).
//
// Not ported (bound to internals):
// - tokens.test.ts:93 and :102, `titleFont`: no component calls it (Title
//   takes the host's heading styles, text.test.tsx:103) and the port has no
//   counterpart. Also `textFont`'s default argument: textScale takes a
//   size.
// - :102, FONT_FAMILY containing "-apple-system, ui-sans-serif, system-ui":
//   a CSS font stack for hosts that want one. The surface keeps the app's
//   font (port/inventory.tsv, INV-015), tested under :117.
// - :117 and :130, STANDARD_CSS text: tested as what each rule does. The
//   surface takes the host's font family, size, line height and ink; the h2
//   fallback is 1.5em, 600 and 1.3; Markdown keeps its list bullets; the
//   last Text of a spaceBetween Row is set right; a scrollable container
//   takes the keyboard focus and shows a 2px focus ring 2px out.
//
// Later phase (no Dart yet): none.

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// A colour no look uses: what a theme sets, to show that a prop follows
/// its variable.
const Color _themed = Color(0xff123456);

/// CSS `var(--a2ui-color-<token>, <fallback>)` as [resolve] reads it: the
/// [fallback] in the standard look, and the theme's colour of [token] once
/// a theme sets it.
void _expectVar(
  Color? Function(A2uiKitTheme theme) resolve,
  A2uiColorToken token,
  Color fallback,
) {
  expect(resolve(standardLight), fallback);
  expect(resolve(standardLight.withColors({token: _themed})), _themed);
}

/// The RichText showing exactly [text].
RichText _rich(WidgetTester tester, String text) =>
    tester.widget<RichText>(find.text(text, findRichText: true));

/// The text style of the host around the surface: the app's, at the
/// harness's Scaffold body.
TextStyle _host(WidgetTester tester) => DefaultTextStyle.of(
  tester.element(find.byType(SingleChildScrollView).first),
).style;

void main() {
  group('standard tokens', () {
    // tokens.test.ts:19
    test('maps numbers to 4px steps and passes strings through', () {
      // `calc(var(--spacing, 0.25rem) * 3)`: 0.25rem is 4px.
      expect(standardLight.spacingStep, 4);
      expect(
        A2uiLength.steps(3, step: standardLight.spacingStep),
        const A2uiLength.px(12),
      );
      expect(
        A2uiLength.steps('12px', step: standardLight.spacingStep),
        const A2uiLength.px(12),
      );
      expect(A2uiLength.steps(null, step: standardLight.spacingStep), isNull);
    });

    // tokens.test.ts:25
    test('maps radius tokens and passes raw values through', () {
      // `var(--a2ui-radius-lg, 12px)`.
      expect(standardLight.radius('lg'), 12);
      expect(
        standardLight
            .copyWith(radii: {...standardLight.radii, A2uiRadius.lg: 20})
            .radius('lg'),
        20,
      );
      expect(standardLight.radius('full'), 9999);
      expect(standardLight.radius(6), 6);
      expect(standardLight.radius(null), isNull);
    });

    // tokens.test.ts:25 (the raw "3px 4px", through a Box)
    testWidgets('passes a raw radius through as CSS: "3px 4px"', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Box',
          'background': 'surface-secondary',
          'radius': '3px 4px',
          'children': ['x'],
        },
        {'id': 'x', 'component': 'Text', 'text': 'x'},
      ]);
      // `border-radius: 3px 4px`: 3px at the top left and bottom right, 4px
      // at the top right and bottom left (CSS Backgrounds 3 §5.1, the
      // `border-radius` shorthand: two values are top-left/bottom-right,
      // then top-right/bottom-left). The box as painted.
      expect(
        paintedPage(tester),
        paints..something(
          paintedCorners(
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(4),
            bottomRight: const Radius.circular(3),
            bottomLeft: const Radius.circular(4),
          ),
        ),
      );
    });

    // tokens.test.ts:33
    test('maps semantic colors and passes raw CSS through', () {
      _expectVar(
        (theme) => theme.textColor('secondary'),
        A2uiColorToken.textSecondary,
        const Color(0xff5d5d5d),
      );
      // CSS Color 4 §5.2 (hex notation): `#123` is `#112233`.
      expect(standardLight.textColor('#123'), const Color(0xff112233));
      expect(standardLight.textColor(null), isNull);
      _expectVar(
        (theme) => theme.backgroundColor('surface-secondary'),
        A2uiColorToken.surfaceSecondary,
        const Color(0xfff7f7f8),
      );
      // CSS Color 4 §6.1 (named colors): rebeccapurple is #663399.
      expect(
        standardLight.backgroundColor('rebeccapurple'),
        const Color(0xff663399),
      );
      _expectVar(
        (theme) => theme.borderColor('subtle'),
        A2uiColorToken.borderSubtle,
        const Color.from(alpha: .05, red: 0, green: 0, blue: 0),
      );
      _expectVar(
        (theme) => theme.borderColor('default'),
        A2uiColorToken.borderDefault,
        const Color.from(alpha: .1, red: 0, green: 0, blue: 0),
      );
    });

    // tokens.test.ts:51
    test('does not read inherited object keys as tokens', () {
      // Neither is a token, so each passes through as CSS that is no colour
      // and no length: a browser drops it (CSS Syntax 3 / Cascade 4: a
      // declaration whose value does not parse is invalid at parse time
      // and ignored; CSS Color 4 has no colour named "constructor").
      expect(standardLight.textColor('constructor'), isNull);
      expect(standardLight.radius('toString'), isNull);
    });

    // tokens.test.ts:56
    test('maps background and text tokens to their fallback values', () {
      _expectVar(
        (theme) => theme.backgroundColor('surface'),
        A2uiColorToken.surface,
        const Color(0xffffffff),
      );
      expect(
        standardLight.backgroundColor('surface-soft'),
        const Color(0xfffcfcfc),
      );
      expect(
        standardLight.backgroundColor('surface-tertiary'),
        const Color(0xffececec),
      );
      expect(
        standardLight.backgroundColor('info'),
        const Color.from(alpha: .08, red: 0, green: 104 / 255, blue: 188 / 255),
      );
      expect(
        standardLight.backgroundColor('success-solid'),
        const Color(0xff00805d),
      );
      expect(standardLight.textColor('default'), const Color(0xff0d0d0d));
      expect(standardLight.textColor('tertiary'), const Color(0xff8e8e8e));
    });

    // tokens.test.ts:66
    test('gives a panel in a Card the inner panel fill or a lighter '
        'tint', () {
      _expectVar(
        (theme) => theme.panelBackground('surface-soft'),
        A2uiColorToken.panel,
        const Color(0xfffcfcfc),
      );
      _expectVar(
        (theme) => theme.panelBackground('danger'),
        A2uiColorToken.dangerSoft,
        const Color.from(
          alpha: .06,
          red: 193 / 255,
          green: 50 / 255,
          blue: 44 / 255,
        ),
      );
      _expectVar(
        (theme) => theme.panelBackground('info-solid'),
        A2uiColorToken.infoSolid,
        const Color(0xff0068bc),
      );
      expect(standardLight.panelBackground(null), isNull);
    });

    // tokens.test.ts:79
    test('has the size lists', () {
      expect(
        [for (final size in TitleSize.values) size.wire],
        ['sm', 'md', 'lg', 'xl', '2xl', '3xl', '4xl', '5xl'],
      );
      expect(
        [for (final size in A2uiTextSize.values) size.wire],
        ['3xs', '2xs', 'xs', 'sm', 'md', 'lg'],
      );
    });

    // tokens.test.ts:93
    test('uses md as the default font size', () {
      // textFont(): md, 1em with a 1.625 line height.
      expect(textScale(A2uiTextSize.md), (1.0, 1.625));
    });

    // tokens.test.ts:102
    test('gives the type scale in em of the host size', () {
      expect(textScale(A2uiTextSize.sm), (.875, 1.429));
      expect(textScale(A2uiTextSize.threeXs).$1, .625);
      expect(textScale(A2uiTextSize.twoXs).$1, .6875);
      expect(textScale(A2uiTextSize.xs).$1, .75);
      expect(textScale(A2uiTextSize.lg).$1, 1.125);
    });

    // tokens.test.ts:117 (behaviour: `.a2ui-surface{font:inherit}` and no
    // font-family)
    testWidgets('the surface keeps the font family of the host', (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Text', 'text': 'plain'},
      ]);
      final drawn = _rich(tester, 'plain').text.style!;
      expect(drawn.fontFamily, _host(tester).fontFamily);
      expect(drawn.fontFamilyFallback, _host(tester).fontFamilyFallback);
    });

    // tokens.test.ts:117 (behaviour: `.a2ui-surface{font:inherit;
    // color:inherit}`)
    testWidgets('the surface takes the size, line height and ink of the host', (
      tester,
    ) async {
      // A host whose type is none of the look's own (16px, the font's
      // line height, #0d0d0d): a surface that sets its own fails here.
      await renderStandard(
        tester,
        [
          {'id': 'root', 'component': 'Text', 'text': 'plain'},
        ],
        host: const TextStyle(
          fontSize: 18,
          height: 1.7,
          color: Color(0xff123456),
          fontWeight: FontWeight.w300,
        ),
      );
      final drawn = _rich(tester, 'plain').text.style!;
      final host = _host(tester);
      expect(host.fontSize, 18);
      expect(drawn.fontSize, host.fontSize);
      expect(drawn.height, host.height);
      expect(drawn.color, host.color);
      expect(drawn.fontWeight, host.fontWeight);
    });

    // The same rule's other side: the playground look is the playground's
    // page, its own type (16px, 1.5, its ink) over any host.
    testWidgets('the playground look keeps its own type over the host', (
      tester,
    ) async {
      await renderStandard(
        tester,
        [
          {'id': 'root', 'component': 'Text', 'text': 'plain'},
        ],
        theme: A2uiKitTheme.playground(Brightness.light),
        host: const TextStyle(fontSize: 18, color: Color(0xff123456)),
      );
      final drawn = _rich(tester, 'plain').text.style!;
      expect(drawn.fontSize, 16);
      expect(drawn.height, 1.5);
      expect(
        drawn.color!.toARGB32(),
        A2uiKitTheme.playground(
          Brightness.light,
        ).color(A2uiColorToken.textDefault).toARGB32(),
      );
    });

    // tokens.test.ts:117
    test('falls back to h2 headings of 1.5em, weight 600 and line height '
        '1.3', () {
      expect(
        standardLight.typography.heading(A2uiHeadingLevel.h2),
        const A2uiHeadingStyle(
          fontSizeEm: 1.5,
          fontWeight: FontWeight.w600,
          lineHeight: 1.3,
        ),
      );
    });

    // tokens.test.ts:117 (behaviour: no `.a2ui-surface :is(ul,ol)` reset)
    testWidgets("Markdown keeps its list bullets: the reset is the List's", (
      tester,
    ) async {
      await renderStandard(tester, [
        {'id': 'root', 'component': 'Markdown', 'text': '- one\n- two'},
      ]);
      expect(richTexts(tester), ['•', 'one', '•', 'two']);
    });

    // tokens.test.ts:117 (behaviour: `[data-a2ui-row="spaceBetween"]>
    // [data-a2ui-text]:last-child:not(:first-child){text-align:right`)
    testWidgets('sets the last Text of a spaceBetween Row right', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['pair', 'single'],
        },
        {
          'id': 'pair',
          'component': 'Row',
          'justify': 'spaceBetween',
          'children': ['k', 'v'],
        },
        {'id': 'k', 'component': 'Text', 'text': 'Total'},
        {'id': 'v', 'component': 'Text', 'text': r'$29'},
        {
          'id': 'single',
          'component': 'Row',
          'justify': 'spaceBetween',
          'children': ['alone'],
        },
        {'id': 'alone', 'component': 'Text', 'text': 'Alone'},
      ]);
      expect(_rich(tester, r'$29').textAlign, TextAlign.right);
      // Not the first child, and not an only child.
      expect(_rich(tester, 'Total').textAlign, TextAlign.start);
      expect(_rich(tester, 'Alone').textAlign, TextAlign.start);
    });

    // tokens.test.ts:130 (behaviour)
    testWidgets('gives a focusable scroll container a visible focus ring', (
      tester,
    ) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'scrollable': true,
          'height': '100px',
          'children': [for (var i = 0; i < 8; i++) 'l$i'],
        },
        for (var i = 0; i < 8; i++)
          {'id': 'l$i', 'component': 'Text', 'text': 'Line $i'},
      ]);
      // The offsets of the visible FocusRings: those around "Line 0", or
      // every one on the page.
      List<double> visibleRings(Finder rings) => [
        for (final ring in tester.widgetList<FocusRing>(rings))
          if (ring.visible) ring.offset,
      ];
      final allRings = find.byType(FocusRing);
      final aroundLines = find.ancestor(
        of: find.text('Line 0', findRichText: true),
        matching: find.byType(FocusRing),
      );
      // `:focus-visible`: before any key, no ring shows (a ring that
      // always shows is no fix).
      expect(visibleRings(allRings), isEmpty);
      // A scrollable container takes the keyboard focus (`tabIndex: 0`).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // The focus is the scroll container's: Page Down (an arrow key in a
      // browser; Flutter maps the arrows to focus moves off the web)
      // scrolls the lines, not the page around the surface.
      final page = find.byType(Scrollable).first;
      final lines = find
          .ancestor(
            of: find.text('Line 0', findRichText: true),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(lines).position.pixels,
        greaterThan(0),
      );
      expect(tester.state<ScrollableState>(page).position.pixels, 0);
      // `outline: 2px solid var(--a2ui-color-focus, #0285ff);
      // outline-offset: 2px`: the kit's 2px FocusRing, 2px out, in the
      // focus colour, around the lines and nowhere else.
      expect(visibleRings(aroundLines), [2.0]);
      expect(visibleRings(allRings), [2.0]);
      expect(
        standardLight.color(A2uiColorToken.focus),
        const Color(0xff0285ff),
      );
    });

    // tokens.test.ts:136
    test('uses the documented catalog id', () {
      expect(kA2uiStandardCatalogId, 'copilotkit/standard@1');
    });
  });
}
