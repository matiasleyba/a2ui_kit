// Parity tests of CopilotKit's theme, ported from
// packages/shared/src/generative-ui/standard/__tests__/theme.test.ts
// (MIT, (c) Atai Barkai). Each test names its upstream line.
//
// Parity for: Box, Text, (engine)
//
// CopilotKit themes a surface with a stylesheet of CSS variables. Flutter
// has no stylesheet: an app gives its ThemeData an A2uiKitTheme (one for
// light, one for dark), and every surface below reads it. Each upstream
// test asserts stylesheet text, so each is bound to internals; where
// Flutter can observe the behaviour it guards, the tests below check it on
// the theme. Colours are upstream's: "#d97706", "#1f2937", "red" and
// "blue", and the built-in values they meet (rgb(252, 252, 252), #1f1f1f).
//
// Not ported (bound to internals):
// - theme.test.ts:6, no stylesheet for a theme without variables: tested
//   as a theme with no values being the look itself.
// - :11, the rules and their selectors: tested as the theme's values
//   reaching a widget under the app (`A2uiKitTheme.of`, what every
//   component reads) in light and in dark mode, and its dark values in dark
//   mode only. That a surface draws with that theme is tested at :45 (a
//   Box).
// - :22, the stylesheet id: tested as theme equality.
// - :30, leaving out values and names that could break out of the CSS
//   rule: no counterpart, since a theme holds typed colours, not CSS text.
// - :45, the `.dark` selector of no specificity: tested as the built-in
//   dark values in a dark app, and a theme value winning over them.
// - :56, the theme rule's specificity over an app rule on `.a2ui-surface`:
//   no counterpart, since Flutter has no cascade (a surface reads the
//   nearest A2uiKitTheme, test/foundation/theme_test.dart).
//
// Later phase (no Dart yet):
// - theme.test.ts:6, a theme with only `mapStyle` (the Map component).

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/parity.dart';

/// `"--a2ui-color-accent": "#d97706"`.
const Color _amber = Color(0xffd97706);

/// `"--a2ui-color-panel": "#1f2937"`.
const Color _slate = Color(0xff1f2937);

/// The standard look, dark.
final A2uiKitTheme _standardDark = A2uiKitTheme.standard(Brightness.dark);

/// The theme a surface of the standard look reads in an app of [theme],
/// [darkTheme] and [themeMode].
Future<A2uiKitTheme> _themeInApp(
  WidgetTester tester, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
}) async {
  late A2uiKitTheme found;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: Builder(
        builder: (context) {
          found = A2uiKitTheme.of(context, look: A2uiKitLook.standard);
          return const SizedBox();
        },
      ),
    ),
  );
  return found;
}

void main() {
  group('themeStyleSheet', () {
    // theme.test.ts:6 (behaviour)
    test('a theme without values leaves the look as it is', () {
      expect(standardLight.withColors(const {}), standardLight);
      expect(_standardDark.withColors(const {}), _standardDark);
    });

    // theme.test.ts:11 (behaviour)
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('in ${mode.name} mode, the theme reaches the widgets under '
          'the app and its dark values apply in dark mode only', (
        tester,
      ) async {
        final dark = mode == ThemeMode.dark;
        final found = await _themeInApp(
          tester,
          // The top-level value, in both themes.
          theme: ThemeData(
            extensions: [
              standardLight.withColors({A2uiColorToken.accent: _amber}),
            ],
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            extensions: [
              _standardDark.withColors({
                A2uiColorToken.accent: _amber,
                A2uiColorToken.panel: _slate,
              }),
            ],
          ),
          themeMode: mode,
        );
        expect(found.brightness, dark ? Brightness.dark : Brightness.light);
        expect(found.color(A2uiColorToken.accent), _amber);
        // In light mode the panel keeps the built-in rgb(252, 252, 252).
        expect(
          found.color(A2uiColorToken.panel),
          dark ? _slate : const Color(0xfffcfcfc),
        );
      });
    }

    // theme.test.ts:22 (behaviour)
    test('the same theme is the same, another theme is not', () {
      final theme = standardLight.withColors({
        A2uiColorToken.accent: const Color(0xffff0000),
      });
      final copy = standardLight.withColors({
        A2uiColorToken.accent: const Color(0xffff0000),
      });
      expect(copy, theme);
      expect(copy.hashCode, theme.hashCode);
      expect(
        standardLight.withColors({
          A2uiColorToken.accent: const Color(0xff0000ff),
        }),
        isNot(theme),
      );
    });
  });

  group('the built-in dark values', () {
    // theme.test.ts:45
    test('hold the dark surface', () {
      // `--a2ui-color-surface:#1f1f1f`.
      expect(
        _standardDark.color(A2uiColorToken.surface),
        const Color(0xff1f1f1f),
      );
    });

    // theme.test.ts:45 (behaviour: `:where(.dark .a2ui-surface, ...)`)
    testWidgets('apply when the app is dark', (tester) async {
      final found = await _themeInApp(
        tester,
        theme: ThemeData(brightness: Brightness.dark),
      );
      expect(found, _standardDark);
      expect(found.color(A2uiColorToken.surface), const Color(0xff1f1f1f));
    });

    // theme.test.ts:45 (behaviour)
    testWidgets('a surface in dark mode draws with them', (tester) async {
      await renderStandard(tester, [
        {
          'id': 'root',
          'component': 'Box',
          'background': 'surface',
          'children': ['x'],
        },
        {'id': 'x', 'component': 'Text', 'text': 'x'},
      ], brightness: Brightness.dark);
      // The Box's background, as painted.
      expect(
        paintedPage(tester),
        paints..something(paintedFill(const Color(0xff1f1f1f))),
      );
    });

    // theme.test.ts:45 (behaviour: no specificity, so any theme rule wins)
    test('any theme value wins over them', () {
      expect(
        _standardDark
            .withColors({A2uiColorToken.surface: _slate})
            .color(A2uiColorToken.surface),
        _slate,
      );
    });
  });
}
