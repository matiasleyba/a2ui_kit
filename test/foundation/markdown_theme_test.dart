// Unit tests of the phase 1b foundation: the streaming markdown repair, the
// playground number format and the Material theme. (The Lucide lookup is in
// lucide_test.dart.)

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/foundation/text/markdown_repair.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('repairIncompleteMarkdown', () {
    test('closes open emphasis, code and strike', () {
      expect(repairIncompleteMarkdown('a **bold'), 'a **bold**');
      expect(repairIncompleteMarkdown('a `code'), 'a `code`');
      expect(repairIncompleteMarkdown('a ~~old'), 'a ~~old~~');
      expect(repairIncompleteMarkdown('an *em'), 'an *em*');
      expect(repairIncompleteMarkdown('done **here**'), 'done **here**');
    });

    test('a list marker is not emphasis', () {
      expect(repairIncompleteMarkdown('* one\n* two'), '* one\n* two');
    });

    test('closes the innermost marker first', () {
      expect(repairIncompleteMarkdown('**bold *it'), '**bold *it***');
      expect(repairIncompleteMarkdown('*it **bold'), '*it **bold***');
      expect(repairIncompleteMarkdown('~~old **new'), '~~old **new**~~');
      expect(repairIncompleteMarkdown('**a `b'), '**a `b`**');
      expect(repairIncompleteMarkdown('`a **b'), '`a **b`');
    });

    test('a * with whitespace on both sides opens nothing', () {
      expect(repairIncompleteMarkdown('2 * 3 is 6'), '2 * 3 is 6');
      expect(repairIncompleteMarkdown('a * b *c'), 'a * b *c*');
      expect(repairIncompleteMarkdown('end *'), 'end *');
    });

    test('closes an open fence or math block', () {
      expect(
        repairIncompleteMarkdown('```dart\nvoid main'),
        '```dart\nvoid main\n```',
      );
      expect(repairIncompleteMarkdown('\$\$\nx^2'), '\$\$\nx^2\n\$\$');
    });

    test('a half-sent link shows its text; a half-sent image nothing', () {
      expect(repairIncompleteMarkdown('see [docs](https://exa'), 'see docs');
      expect(repairIncompleteMarkdown('see [do'), 'see do');
      expect(repairIncompleteMarkdown('pic ![alt](https://x'), 'pic ');
      expect(
        repairIncompleteMarkdown('[a](https://a.b) done'),
        '[a](https://a.b) done',
      );
    });
  });

  group('formatPlaygroundNumber', () {
    test('en-US grouping and at most two decimals', () {
      expect(formatPlaygroundNumber(1234567), '1,234,567');
      expect(formatPlaygroundNumber(1234.5), '1,234.5');
      expect(formatPlaygroundNumber(2.345), '2.35');
      expect(formatPlaygroundNumber(-1000), '-1,000');
      expect(formatPlaygroundNumber(0.004), '0');
      expect(formatPlaygroundNumber(12), '12');
    });

    test('rounds the shortest decimal half up, as Intl does', () {
      expect(formatPlaygroundNumber(1.005), '1.01');
      expect(formatPlaygroundNumber(-1.005), '-1.01');
      expect(formatPlaygroundNumber(0.125), '0.13');
      expect(formatPlaygroundNumber(9.995), '10');
      expect(formatPlaygroundNumber(999.999), '1,000');
      expect(formatPlaygroundNumber(1.5e-7), '0');
      expect(formatPlaygroundNumber(-0.001), '-0');
    });

    test('writes 1e21 and above in full', () {
      expect(formatPlaygroundNumber(1e21), '1,000,000,000,000,000,000,000');
      expect(formatPlaygroundNumber(1.5e22), '15,000,000,000,000,000,000,000');
      expect(
        formatPlaygroundNumber(123456789012345680000.0),
        '123,456,789,012,345,680,000',
      );
    });
  });

  group('A2uiKitTheme.fromColorScheme', () {
    for (final brightness in Brightness.values) {
      test('maps the Material roles in ${brightness.name}', () {
        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xff0b57d0),
          brightness: brightness,
        );
        final theme = A2uiKitTheme.fromColorScheme(scheme);
        expect(theme.brightness, brightness);
        expect(theme.color(A2uiColorToken.textDefault), scheme.onSurface);
        expect(
          theme.color(A2uiColorToken.textSecondary),
          scheme.onSurfaceVariant,
        );
        expect(theme.color(A2uiColorToken.surface), scheme.surfaceContainer);
        expect(theme.color(A2uiColorToken.accent), scheme.primary);
        expect(theme.color(A2uiColorToken.onAccent), scheme.onPrimary);
        expect(theme.color(A2uiColorToken.textDanger), scheme.error);
        expect(theme.color(A2uiColorToken.dangerSolid), scheme.error);
        expect(
          theme.color(A2uiColorToken.danger),
          scheme.error.withValues(
            alpha: brightness == Brightness.dark ? .12 : .08,
          ),
        );
        expect(
          theme.color(A2uiColorToken.borderDefault),
          scheme.outlineVariant,
        );
        expect(
          theme.color(A2uiColorToken.borderInfo),
          brightness == Brightness.dark
              ? scheme.primaryContainer
              : scheme.inversePrimary,
        );
        expect(theme.radius('md'), 12);
        expect(theme.radius('lg'), 16);
        expect(theme.radius('2xl'), 28);
        expect(theme.playground.radius, 12);
        expect(theme.playground.line, scheme.outlineVariant);
        expect(theme.playground.cardShadow, isEmpty);
        // It lerps with the other looks.
        final halfway = theme.lerp(A2uiKitTheme.playground(brightness), .5);
        expect(halfway.playground.alerts, hasLength(4));
      });
    }
  });

  group('A2uiPlaygroundTokens', () {
    test('Alert and Callout colours in both modes, and toneColor', () {
      final light = A2uiKitTheme.playground(Brightness.light).playground;
      final dark = A2uiKitTheme.playground(Brightness.dark).playground;
      expect(light.alerts.keys, AlertTone.values);
      expect(light.alerts[AlertTone.info], isNot(dark.alerts[AlertTone.info]));
      expect(light.callout.backgroundEnd, isNotNull);
      expect(light.toneColor(A2uiTone.default_), light.mutedForeground);
      expect(light.toneColor(A2uiTone.accent), light.tones[A2uiTone.accent]);
      expect(
        light.copyWith(secondary: const Color(0xff000000)).secondary,
        const Color(0xff000000),
      );
      expect(light, A2uiKitTheme.playground(Brightness.light).playground);
    });
  });
}
