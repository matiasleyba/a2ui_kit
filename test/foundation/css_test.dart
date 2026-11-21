import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// [color] as 0xAARRGGBB, rounded per channel.
int _argb(Color color) => color.toARGB32();

void main() {
  group('A2uiLength', () {
    test('a number is spacing steps of 4px', () {
      expect(A2uiLength.steps(4), const A2uiLength.px(16));
      expect(A2uiLength.steps(16), const A2uiLength.px(64));
      expect(A2uiLength.steps(0.5), const A2uiLength.px(2));
      expect(A2uiLength.steps(3, step: 5), const A2uiLength.px(15));
    });

    test('a pixel prop takes a number as pixels', () {
      expect(A2uiLength.pixels(12), const A2uiLength.px(12));
    });

    test('a string is CSS', () {
      expect(A2uiLength.steps('12px'), const A2uiLength.px(12));
      expect(A2uiLength.steps('1.5rem'), const A2uiLength.px(24));
      expect(A2uiLength.steps('2em'), const A2uiLength.em(2));
      expect(A2uiLength.steps('50%'), const A2uiLength.percent(.5));
      expect(A2uiLength.steps('0'), A2uiLength.zero);
      expect(A2uiLength.steps(' 8PX '), const A2uiLength.px(8));
    });

    test('a unitless number other than 0, or a negative one, is no CSS', () {
      expect(A2uiLength.parse('12'), isNull);
      expect(A2uiLength.parse('1.5'), isNull);
      expect(A2uiLength.parse('0'), A2uiLength.zero);
      expect(A2uiLength.parse('0.0'), A2uiLength.zero);
      expect(A2uiLength.steps('-4px'), isNull);
      expect(A2uiLength.steps(-2), isNull);
      expect(A2uiLength.pixels(-12), isNull);
      expect(A2uiLength.parse('-10%'), isNull);
      expect(cssInsets(-3), EdgeInsets.zero);
      expect(cssInsets('-4px 8px'), isNull);
    });

    test('anything else is ignored, never thrown', () {
      for (final value in [
        'auto',
        'calc(100% - 8px)',
        '12vw',
        '',
        'px',
        true,
        null,
        const <String, Object?>{},
        double.nan,
        double.infinity,
      ]) {
        expect(A2uiLength.steps(value), isNull, reason: '$value');
      }
    });

    test('resolves percentages against a base and em against a size', () {
      expect(const A2uiLength.percent(.5).resolve(percentBase: 300), 150);
      expect(const A2uiLength.percent(.5).resolve(), isNull);
      expect(
        const A2uiLength.percent(.5).resolve(percentBase: double.infinity),
        isNull,
      );
      expect(const A2uiLength.em(1.5).resolve(fontSize: 14), 21);
    });

    test('padding takes one to four lengths', () {
      expect(cssInsets(3), const EdgeInsets.all(12));
      expect(cssInsets('8px'), const EdgeInsets.all(8));
      expect(
        cssInsets('8px 16px'),
        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      );
      expect(cssInsets('1px 2px 3px'), const EdgeInsets.fromLTRB(2, 1, 2, 3));
      expect(
        cssInsets('1px 2px 3px 4px'),
        const EdgeInsets.fromLTRB(4, 1, 2, 3),
      );
      expect(cssInsets('1em', fontSize: 10), const EdgeInsets.all(10));
      expect(cssInsets('10%'), isNull);
      expect(cssInsets('1px 2px 3px 4px 5px'), isNull);
    });

    // CSS Backgrounds 3, section 5.1: the `border-radius` shorthand.
    test('border-radius takes one to four radii, then a slash and four', () {
      const r = Radius.circular;
      BorderRadius corners(Radius tl, Radius tr, Radius br, Radius bl) =>
          BorderRadius.only(
            topLeft: tl,
            topRight: tr,
            bottomRight: br,
            bottomLeft: bl,
          );
      expect(cssBorderRadius('6px'), BorderRadius.circular(6));
      // Two: top left and bottom right, then top right and bottom left.
      expect(cssBorderRadius('3px 4px'), corners(r(3), r(4), r(3), r(4)));
      // Three: the bottom left is the top right.
      expect(cssBorderRadius('1px 2px 3px'), corners(r(1), r(2), r(3), r(2)));
      expect(
        cssBorderRadius('1px 2px 3px 4px'),
        corners(r(1), r(2), r(3), r(4)),
      );
      // After the slash, the vertical radii: elliptical corners.
      expect(
        cssBorderRadius('8px / 4px 2px'),
        corners(
          const Radius.elliptical(8, 4),
          const Radius.elliptical(8, 2),
          const Radius.elliptical(8, 4),
          const Radius.elliptical(8, 2),
        ),
      );
      expect(
        cssBorderRadius('1em 2px', fontSize: 10),
        corners(r(10), r(2), r(10), r(2)),
      );
      // One bad length spoils the declaration, as in CSS.
      expect(cssBorderRadius('3px -4px'), isNull);
      expect(cssBorderRadius('3px wide'), isNull);
      expect(cssBorderRadius('1px 2px 3px 4px 5px'), isNull);
      expect(cssBorderRadius('1px / 2px / 3px'), isNull);
      expect(cssBorderRadius('50%'), isNull);
      // A corner's longhand: one radius, or horizontal then vertical.
      expect(cssCornerRadius('5px'), r(5));
      expect(cssCornerRadius('5px 2px'), const Radius.elliptical(5, 2));
      expect(cssCornerRadius('5px 2px 1px'), isNull);
    });

    test('aspect ratio reads "w / h" and a number', () {
      expect(cssAspectRatio('16 / 9'), 16 / 9);
      expect(cssAspectRatio('2'), 2);
      expect(cssAspectRatio(1.5), 1.5);
      expect(cssAspectRatio('1 / 0'), isNull);
      expect(cssAspectRatio('wide'), isNull);
    });
  });

  group('parseCssColor', () {
    test('reads hex in its four lengths', () {
      expect(_argb(parseCssColor('#fff')!), 0xffffffff);
      expect(_argb(parseCssColor('#0d0d0d')!), 0xff0d0d0d);
      expect(_argb(parseCssColor('#f008')!), 0x88ff0000);
      expect(_argb(parseCssColor('#11223344')!), 0x44112233);
    });

    test('reads rgb() and rgba() in comma and space forms', () {
      expect(_argb(parseCssColor('rgb(0, 104, 188)')!), 0xff0068bc);
      expect(_argb(parseCssColor('rgba(0, 0, 0, 0.1)')!), 0x1a000000);
      expect(_argb(parseCssColor('rgb(0 0 0 / 50%)')!), 0x80000000);
      expect(_argb(parseCssColor('rgb(100%, 0%, 0%)')!), 0xffff0000);
    });

    test('reads hsl()', () {
      expect(_argb(parseCssColor('hsl(0, 100%, 50%)')!), 0xffff0000);
      expect(_argb(parseCssColor('hsla(120deg 100% 25% / .5)')!), 0x80008000);
    });

    test('reads oklch() as sRGB', () {
      expect(_argb(parseCssColor('oklch(1 0 0)')!), 0xffffffff);
      expect(_argb(parseCssColor('oklch(0 0 0)')!), 0xff000000);
      // Expected values from the OKLab matrices, computed apart.
      expect(_argb(parseCssColor('oklch(0.2 0.008 285)')!), 0xff16161a);
      expect(_argb(parseCssColor('oklch(0.52 0.2 292)')!), 0xff7046cf);
      expect(_argb(oklch(.97, .003, 285)), 0xfff5f5f7);
      // Out of sRGB: the channels are clipped.
      expect(_argb(oklch(.72, .17, 292)), 0xffa88dff);
      expect(
        parseCssColor('oklch(0.21 0.012 285 / 9%)')!.a,
        closeTo(.09, .001),
      );
      expect(parseCssColor('oklch(52% 0.2 292)'), isNotNull);
    });

    test('reads named colours and transparent', () {
      expect(_argb(parseCssColor('rebeccapurple')!), 0xff663399);
      expect(_argb(parseCssColor('Transparent')!), 0x00000000);
      expect(cssNamedColors, hasLength(149));
    });

    test('ignores anything else', () {
      for (final value in [
        null,
        '',
        'currentColor',
        'var(--x)',
        '#ggg',
        '#12345',
        'rgb(1, 2)',
        'notacolor',
        'oklch(a b c)',
      ]) {
        expect(parseCssColor(value), isNull, reason: '$value');
      }
    });
  });
}
