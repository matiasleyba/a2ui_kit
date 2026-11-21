import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:a2ui_kit/src/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _argb(Color? color) => color!.toARGB32();

void main() {
  group('presets', () {
    test("the standard look is CopilotKit's library fallbacks", () {
      final light = A2uiKitTheme.standard(Brightness.light);
      expect(_argb(light.color(A2uiColorToken.accent)), 0xff0d0d0d);
      expect(_argb(light.color(A2uiColorToken.textSecondary)), 0xff5d5d5d);
      expect(_argb(light.color(A2uiColorToken.chart1)), 0xff7fb0f2);
      expect(light.radii[A2uiRadius.lg], 12);
      final dark = A2uiKitTheme.standard(Brightness.dark);
      expect(_argb(dark.color(A2uiColorToken.textDefault)), 0xffececec);
      expect(_argb(dark.color(A2uiColorToken.accent)), 0xfff2f2f2);
      expect(_argb(dark.color(A2uiColorToken.panel)), 0xff262626);
      // DARK_THEME sets no chart colours, so the light ones stay.
      expect(_argb(dark.color(A2uiColorToken.chart1)), 0xff7fb0f2);
    });

    test("the playground look is playgroundTheme over CopilotKit's", () {
      final light = A2uiKitTheme.playground(Brightness.light);
      expect(_argb(light.color(A2uiColorToken.accent)), 0xff7046cf);
      expect(_argb(light.color(A2uiColorToken.textDefault)), 0xff16161a);
      expect(light.radii[A2uiRadius.lg], 14);
      expect(light.radii[A2uiRadius.xl], 16);
      // Not in playgroundTheme: CopilotKit's value.
      expect(_argb(light.color(A2uiColorToken.textSuccess)), 0xff00805d);
      final dark = A2uiKitTheme.playground(Brightness.dark);
      expect(_argb(dark.color(A2uiColorToken.textSuccess)), 0xff4fd1a5);
      expect(dark.brightness, Brightness.dark);
    });

    test('the playground headings keep the surrounding type', () {
      final type = A2uiKitTheme.playground(Brightness.light).typography;
      for (final level in A2uiHeadingLevel.values) {
        expect(type.heading(level), const A2uiHeadingStyle());
      }
      expect(type.fontSize, 16);
      expect(type.lineHeight, 1.5);
      final standard = A2uiKitTheme.standard(Brightness.light).typography;
      expect(standard.heading(A2uiHeadingLevel.h2).fontSizeEm, 1.5);
      expect(standard.heading(A2uiHeadingLevel.h3).fontSizeEm, 1.25);
      expect(standard.heading(A2uiHeadingLevel.h4).fontWeight, FontWeight.w600);
    });

    test('presets are shared', () {
      expect(
        identical(
          A2uiKitTheme.playground(Brightness.light),
          A2uiKitTheme.playground(Brightness.light),
        ),
        isTrue,
      );
    });
  });

  group('token resolution', () {
    final theme = A2uiKitTheme.standard(Brightness.light);

    test('text colours: a token or a CSS colour', () {
      expect(_argb(theme.textColor('secondary')), 0xff5d5d5d);
      expect(_argb(theme.textColor('caution')), 0xff946200);
      expect(_argb(theme.textColor('#123456')), 0xff123456);
      expect(theme.textColor('surface'), isNull);
      expect(theme.textColor(null), isNull);
      expect(theme.textColor(''), isNull);
    });

    test('backgrounds: a surface, tint or solid token, or CSS', () {
      expect(_argb(theme.backgroundColor('surface-secondary')), 0xfff7f7f8);
      expect(theme.backgroundColor('info')!.a, closeTo(.08, .002));
      expect(_argb(theme.backgroundColor('danger-solid')), 0xffc1322c);
      expect(_argb(theme.backgroundColor('red')), 0xffff0000);
      expect(theme.backgroundColor('secondary'), isNull);
    });

    test('borders: a border token or CSS', () {
      expect(theme.borderColor('subtle')!.a, closeTo(.05, .002));
      expect(_argb(theme.borderColor('strong')), 0xffcdcdcd);
      expect(theme.borderColor('control'), isNull);
    });

    test('panels inside a Card: neutral is the panel, tints get lighter', () {
      expect(_argb(theme.panelBackground('surface-secondary')), 0xfffcfcfc);
      expect(_argb(theme.panelBackground('surface-soft')), 0xfffcfcfc);
      expect(theme.panelBackground('success')!.a, closeTo(.06, .002));
      expect(_argb(theme.panelBackground('success-solid')), 0xff00805d);
    });

    test('radii: a token, pixels or CSS', () {
      expect(theme.radius('md'), 8);
      expect(theme.radius('full'), 9999);
      expect(theme.radius(3), 3);
      expect(theme.radius('10px'), 10);
      expect(theme.radius('1em', fontSize: 12), 12);
      expect(theme.radius('huge'), isNull);
    });

    test('spacing steps', () {
      expect(theme.space(4), 16);
      expect(theme.copyWith(spacingStep: 5).space(4), 20);
    });
  });

  group('ThemeExtension', () {
    test('copyWith and withColors replace values', () {
      final theme = A2uiKitTheme.standard(
        Brightness.light,
      ).withColors({A2uiColorToken.accent: const Color(0xffd97706)});
      expect(_argb(theme.color(A2uiColorToken.accent)), 0xffd97706);
      expect(_argb(theme.color(A2uiColorToken.onAccent)), 0xffffffff);
      expect(theme.copyWith(), theme);
    });

    test('lerp blends colours and radii', () {
      final a = A2uiKitTheme.standard(Brightness.light);
      final b = A2uiKitTheme.playground(Brightness.light);
      final half = a.lerp(b, .5);
      expect(half.radii[A2uiRadius.lg], 13);
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1).radii, b.radii);
      expect(a.lerp(null, .5), a);
    });

    testWidgets('of reads the extension, else the look in the brightness', (
      tester,
    ) async {
      late A2uiKitTheme found;
      Widget app(ThemeData data, {A2uiKitLook look = A2uiKitLook.playground}) =>
          MaterialApp(
            theme: data,
            home: Builder(
              builder: (context) {
                found = A2uiKitTheme.of(context, look: look);
                return const SizedBox();
              },
            ),
          );
      await tester.pumpWidget(app(ThemeData(brightness: Brightness.dark)));
      expect(found, A2uiKitTheme.playground(Brightness.dark));
      // MaterialApp animates a theme change.
      await tester.pumpWidget(app(ThemeData(), look: A2uiKitLook.standard));
      await tester.pumpAndSettle();
      expect(found, A2uiKitTheme.standard(Brightness.light));
      final custom = A2uiKitTheme.standard(
        Brightness.light,
      ).copyWith(spacingStep: 6);
      await tester.pumpWidget(app(ThemeData(extensions: [custom])));
      await tester.pumpAndSettle();
      expect(found, custom);
    });
  });
}
