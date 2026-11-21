// Widget tests of the standard Svg (react-core standard/media.tsx:484-569):
// its box, its viewBox mapping, its paints and their inheritance, its
// texts, its semantics, both looks and both brightnesses, and its fit at
// 320px and text scale 2.0.

import 'dart:ui' as ui;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_drawing.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_path.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';
import '../helpers/paint_calls.dart';
import '../helpers/parity.dart';

/// An Svg [props] in a Column, then a Text "end".
Future<ParitySurface> _svg(
  WidgetTester tester,
  Map<String, Object?> props, {
  double width = 360,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => renderStandard(
  tester,
  [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['s', 'end'],
    },
    {'id': 's', 'component': 'Svg', ...props},
    {'id': 'end', 'component': 'Text', 'text': 'end'},
  ],
  width: width,
  textScale: textScale,
  brightness: brightness,
);

RenderSvgCanvas _canvas(WidgetTester tester) =>
    tester.renderObject<RenderSvgCanvas>(find.byType(SvgCanvas));

/// Where user point [point] lands in the drawing's box.
Offset _mapped(WidgetTester tester, Offset point) =>
    MatrixUtils.transformPoint(_canvas(tester).userTransform, point);

final Color _prose = standardLightColors[A2uiColorToken.textProse]!;
final Color _danger = standardLightColors[A2uiColorToken.textDanger]!;
final Color _info = standardLightColors[A2uiColorToken.textInfo]!;

void main() {
  group('box', () {
    testWidgets('is 100% wide, and 150px tall with no viewBox', (tester) async {
      await _svg(tester, {
        'rects': [
          {'x': 0, 'y': 0, 'width': 4, 'height': 4},
        ],
      });
      // `width ?? size ?? "100%"`, and no ratio for an auto height: the
      // CSS default object height.
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(360, 150));
    });

    testWidgets('takes its height from the viewBox ratio', (tester) async {
      await _svg(tester, {'viewBox': '0 0 20 10', 'width': 200});
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(200, 100));
      // Not stretched to the Column: it sits at its start.
      expect(tester.getTopLeft(find.byType(SvgCanvas)).dx, 0);
    });

    testWidgets('`size` sets both sides, in pixels, unless width or height '
        'is given', (tester) async {
      await _svg(tester, {'viewBox': '0 0 20 20', 'size': 8});
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(8, 8));
    });

    testWidgets('`size` yields to `width`', (tester) async {
      await _svg(tester, {'viewBox': '0 0 20 20', 'size': 8, 'width': 40});
      // width 40, height `height ?? size` = 8.
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(40, 8));
    });

    testWidgets('reads a CSS length string and a unitless string as pixels', (
      tester,
    ) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': '50%',
        'height': '30',
      });
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(180, 30));
    });

    testWidgets('ignores a width it cannot read: the default 100% does '
        'not apply, the ratio fills the width', (tester) async {
      await _svg(tester, {'viewBox': '0 0 10 5', 'width': 'wide'});
      // An invalid attribute leaves `width: auto`; with a ratio and no
      // size of its own, the svg fills the width offered.
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(360, 180));
    });

    testWidgets('fits at 320px and text scale 2.0', (tester) async {
      await _svg(
        tester,
        {
          'viewBox': '0 0 100 50',
          'texts': [
            {'x': 50, 'y': 25, 'text': 'A long label ' * 8, 'anchor': 'middle'},
          ],
        },
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SvgCanvas)), const Size(320, 160));
    });

    testWidgets('clips what leaves its box', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'circles': [
          {'cx': 20, 'cy': 5, 'r': 4},
        ],
      });
      expect(
        _canvas(tester),
        paints..clipRect(rect: const Rect.fromLTWH(0, 0, 100, 100)),
      );
    });
  });

  group('viewBox and preserveAspectRatio', () {
    testWidgets('centres the viewBox by default (xMidYMid meet)', (
      tester,
    ) async {
      await _svg(tester, {'viewBox': '0 0 10 10', 'width': 200, 'height': 100});
      // Scale 10 (the smaller), 50px left over on each side.
      expect(_mapped(tester, Offset.zero), const Offset(50, 0));
      expect(_mapped(tester, const Offset(10, 10)), const Offset(150, 100));
    });

    testWidgets('aligns xMinYMin and xMaxYMax', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 200,
        'height': 100,
        'preserveAspectRatio': 'xMaxYMax',
      });
      expect(_mapped(tester, Offset.zero), const Offset(100, 0));
    });

    testWidgets('slices to cover', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 200,
        'height': 100,
        'preserveAspectRatio': 'xMidYMin slice',
      });
      // Scale 20 (the larger); y from the top.
      expect(_mapped(tester, const Offset(10, 10)), const Offset(200, 200));
      expect(_mapped(tester, Offset.zero), Offset.zero);
    });

    testWidgets('offsets a viewBox that does not start at 0', (tester) async {
      await _svg(tester, {
        'viewBox': '-5 -5 10 10',
        'width': 100,
        'height': 100,
      });
      expect(_mapped(tester, Offset.zero), const Offset(50, 50));
    });

    testWidgets('an invalid viewBox maps nothing: user units are pixels', (
      tester,
    ) async {
      await _svg(tester, {'viewBox': '0 0 -1 10', 'width': 100, 'height': 50});
      expect(_mapped(tester, const Offset(3, 4)), const Offset(3, 4));
    });

    test('parses viewBox and preserveAspectRatio as SVG 2 does', () {
      expect(svgViewBoxOf('0,0 , 4 2'), const Rect.fromLTWH(0, 0, 4, 2));
      expect(svgViewBoxOf('0 0 4'), isNull);
      expect(svgViewBoxOf('0 0 0 2'), isNull);
      expect(SvgAspect.parse('none'), const SvgAspect.none());
      expect(SvgAspect.parse('xMinYMax'), const SvgAspect(x: 0, y: 1));
      expect(SvgAspect.parse('xMidYMid slices'), SvgAspect.initial);
      expect(SvgAspect.parse('bogus'), SvgAspect.initial);
    });
  });

  group('paints', () {
    testWidgets('fills in currentColor (the prose token) by default, '
        'strokes nothing', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'rects': [
          {'x': 1, 'y': 1, 'width': 4, 'height': 4},
        ],
      });
      final canvas = _canvas(tester);
      expect(
        canvas,
        paints..something(
          paintedPath(
            style: PaintingStyle.fill,
            color: _prose,
            bounds: const Rect.fromLTWH(1, 1, 4, 4),
          ),
        ),
      );
      expect(
        canvas,
        isNot(paints..something(paintedPath(style: PaintingStyle.stroke))),
      );
    });

    testWidgets('`color` sets currentColor; a shape inherits the drawing '
        'fill and stroke unless it sets its own', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'color': 'danger',
        'stroke': 'info',
        'strokeWidth': 2,
        'rects': [
          {'x': 0, 'y': 0, 'width': 4, 'height': 4},
        ],
        'circles': [
          {'cx': 5, 'cy': 5, 'r': 2, 'fill': '#00ff00', 'stroke': 'none'},
        ],
      });
      final canvas = _canvas(tester);
      expect(
        canvas,
        paints
          ..something(
            paintedPath(
              style: PaintingStyle.fill,
              color: _danger,
              bounds: const Rect.fromLTWH(0, 0, 4, 4),
            ),
          )
          ..something(
            paintedPath(
              style: PaintingStyle.stroke,
              color: _info,
              strokeWidth: 2,
              bounds: const Rect.fromLTWH(0, 0, 4, 4),
            ),
          )
          ..something(
            paintedPath(
              style: PaintingStyle.fill,
              color: const Color(0xff00ff00),
              bounds: const Rect.fromLTRB(3, 3, 7, 7),
            ),
          ),
      );
      // stroke "none": the circle has no stroke.
      expect(
        canvas,
        isNot(
          paints..something(
            paintedPath(
              style: PaintingStyle.stroke,
              bounds: const Rect.fromLTRB(3, 3, 7, 7),
            ),
          ),
        ),
      );
    });

    testWidgets('`fill: "none"` fills nothing', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'fill': 'none',
        'stroke': 'currentColor',
        'paths': [
          {'d': 'M1 1H9V9H1Z'},
        ],
      });
      final canvas = _canvas(tester);
      expect(
        canvas,
        isNot(paints..something(paintedPath(style: PaintingStyle.fill))),
      );
      expect(
        canvas,
        paints
          ..something(paintedPath(style: PaintingStyle.stroke, color: _prose)),
      );
    });

    testWidgets('a colour CSS cannot read is ignored: the shape inherits', (
      tester,
    ) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'fill': 'info',
        'rects': [
          {'x': 0, 'y': 0, 'width': 4, 'height': 4, 'fill': 'notacolor'},
        ],
      });
      expect(
        _canvas(tester),
        paints..something(paintedPath(style: PaintingStyle.fill, color: _info)),
      );
    });

    testWidgets('a drawing fill CSS cannot read is black, its initial value', (
      tester,
    ) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'fill': 'notacolor',
        'rects': [
          {'x': 0, 'y': 0, 'width': 4, 'height': 4},
        ],
      });
      expect(
        _canvas(tester),
        paints..something(
          paintedPath(
            style: PaintingStyle.fill,
            color: const Color(0xff000000),
          ),
        ),
      );
    });

    testWidgets('a line strokes in currentColor unless it sets a stroke, '
        'with the drawing cap and join', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'color': 'danger',
        'strokeLinecap': 'round',
        'strokeLinejoin': 'bevel',
        'lines': [
          {'x1': 0, 'y1': 0, 'x2': 10, 'y2': 0},
          {'x1': 0, 'y1': 5, 'x2': 10, 'y2': 5, 'stroke': 'info'},
        ],
      });
      bool strokeIs(Paint paint, Color color) =>
          paint.style == PaintingStyle.stroke &&
          paint.color.toARGB32() == color.toARGB32() &&
          paint.strokeCap == StrokeCap.round &&
          paint.strokeJoin == StrokeJoin.bevel;
      expect(
        _canvas(tester),
        paints
          ..something(
            (method, args) =>
                method == #drawPath && strokeIs(args[1]! as Paint, _danger),
          )
          ..something(
            (method, args) =>
                method == #drawPath && strokeIs(args[1]! as Paint, _info),
          ),
      );
      // A line has no interior: nothing is filled.
      expect(
        _canvas(tester),
        isNot(paints..something(paintedPath(style: PaintingStyle.fill))),
      );
    });

    testWidgets('a path sets its own stroke width; 0 strokes nothing', (
      tester,
    ) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'fill': 'none',
        'stroke': 'danger',
        'strokeWidth': 3,
        'paths': [
          {'d': 'M0 0L10 10', 'strokeWidth': 0.5},
          {'d': 'M0 10L10 0', 'strokeWidth': 0},
          {'d': 'M5 0V10'},
        ],
      });
      final canvas = _canvas(tester);
      expect(
        canvas,
        paints
          ..something(paintedPath(strokeWidth: 0.5))
          ..something(
            paintedPath(
              strokeWidth: 3,
              bounds: const Rect.fromLTRB(5, 0, 5, 10),
            ),
          ),
      );
      expect(
        canvas,
        isNot(
          paints..something(
            paintedPath(
              style: PaintingStyle.stroke,
              bounds: const Rect.fromLTRB(0, 0, 10, 10),
              strokeWidth: 0,
            ),
          ),
        ),
      );
    });

    testWidgets('a rect rounds its corners by rx, at most half a side; a '
        'circle of radius 0 draws nothing', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'rects': [
          {'x': 0, 'y': 0, 'width': 4, 'height': 2, 'rx': 3},
        ],
        'circles': [
          {'cx': 5, 'cy': 5, 'r': 0},
        ],
      });
      final rect = const SvgGeometry(
        kind: 'rect',
        values: [0, 0, 4, 2, 3],
      ).outline()!;
      // rx 3 is clamped to 2 (half the width), ry (auto) to 1.
      expect(rect.contains(const Offset(0.2, 0.2)), isFalse);
      expect(rect.contains(const Offset(2, 1)), isTrue);
      expect(
        const SvgGeometry(kind: 'circle', values: [5, 5, 0]).outline(),
        isNull,
      );
      expect(
        _canvas(tester),
        paints..something(paintedPath(bounds: const Rect.fromLTWH(0, 0, 4, 2))),
      );
    });

    testWidgets('draws path data up to its first error', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'width': 100,
        'fill': 'none',
        'stroke': 'danger',
        'paths': [
          {'d': 'M0 0L10 10 Q 4'},
        ],
      });
      expect(
        svgPathOf('M0 0L10 10 Q 4').getBounds(),
        const Rect.fromLTRB(0, 0, 10, 10),
      );
      expect(
        _canvas(tester),
        paints..something(
          paintedPath(
            style: PaintingStyle.stroke,
            bounds: const Rect.fromLTRB(0, 0, 10, 10),
          ),
        ),
      );
    });
  });

  group('texts', () {
    testWidgets('places a text by its baseline and its anchor, in user '
        'units', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 100 50',
        'width': 200,
        'texts': [
          {'x': 50, 'y': 20, 'text': 'mg', 'size': 10, 'anchor': 'middle'},
          {'x': 90, 'y': 40, 'text': 'N', 'size': 10, 'anchor': 'end'},
        ],
      });
      final style = DefaultTextStyle.of(
        tester.element(find.byType(SvgCanvas)),
      ).style;
      TextPainter measure(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: 10, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final mg = measure('mg');
      final n = measure('N');
      addTearDown(mg.dispose);
      addTearDown(n.dispose);
      final mgBaseline = mg.computeDistanceToActualBaseline(
        ui.TextBaseline.alphabetic,
      );
      final nBaseline = n.computeDistanceToActualBaseline(
        ui.TextBaseline.alphabetic,
      );
      expect(
        _canvas(tester),
        paints
          ..paragraph(offset: Offset(50 - mg.width / 2, 20 - mgBaseline))
          ..paragraph(offset: Offset(90 - n.width, 40 - nBaseline)),
      );
    });

    testWidgets('a text with no size takes the surrounding size; a text '
        'with fill "none" draws nothing', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 100 50',
        'width': 200,
        'texts': [
          {'x': 0, 'y': 20, 'text': 'kept'},
          {'x': 0, 'y': 40, 'text': 'gone', 'fill': 'none'},
        ],
      });
      final canvas = _canvas(tester);
      final kept = canvas.drawing.shapes.whereType<SvgText>().first;
      expect(kept.fontSize, isNull);
      expect(canvas.textStyle.fontSize, 16);
      // One paragraph: "gone" paints nothing.
      expect(canvas, paints..paragraph());
      expect(
        canvas,
        isNot(
          paints
            ..paragraph()
            ..paragraph(),
        ),
      );
    });
  });

  group('semantics', () {
    testWidgets('hides a drawing without a label', (tester) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'circles': [
          {'cx': 5, 'cy': 5, 'r': 4},
        ],
      });
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsNothing);
    });

    testWidgets('names a drawing by the envelope label: one image node', (
      tester,
    ) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'label': 'Own',
        'circles': [
          {'cx': 5, 'cy': 5, 'r': 4},
        ],
        'accessibility': {'label': 'Dot', 'description': 'A dot'},
      });
      // `aria["aria-label"] ?? props.label`: the envelope's wins.
      final images = find.semantics
          .byFlag(SemanticsFlag.isImage)
          .evaluate()
          .toList();
      expect(images, hasLength(1));
      expect(images.single.label, 'Dot');
      expect(images.single.hint, 'A dot');
      expect(find.semantics.byLabel('Dot'), findsOne);
    });

    testWidgets('an envelope that only describes keeps the label prop', (
      tester,
    ) async {
      await _svg(tester, {
        'viewBox': '0 0 10 10',
        'label': 'Floor plan',
        'accessibility': {'description': 'The ground floor'},
      });
      final images = find.semantics.byFlag(SemanticsFlag.isImage).evaluate();
      expect(images, hasLength(1));
      expect(images.single.label, 'Floor plan');
      expect(images.single.hint, 'The ground floor');
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testWidgets('the prose token in the standard look, ${brightness.name}', (
        tester,
      ) async {
        await _svg(tester, {
          'viewBox': '0 0 10 10',
          'width': 100,
          'rects': [
            {'x': 0, 'y': 0, 'width': 4, 'height': 4},
          ],
        }, brightness: brightness);
        final prose = (brightness == Brightness.dark
            ? standardDarkColors
            : standardLightColors)[A2uiColorToken.textProse]!;
        expect(
          _canvas(tester),
          paints
            ..something(paintedPath(style: PaintingStyle.fill, color: prose)),
        );
      });

      testWidgets('the prose token in the playground look, '
          '${brightness.name}', (tester) async {
        await pumpComponents(
          tester,
          [
            {
              'id': 'root',
              'component': 'Svg',
              'viewBox': '0 0 10 10',
              'width': 100,
              'rects': [
                {'x': 0, 'y': 0, 'width': 4, 'height': 4},
              ],
            },
          ],
          brightness: brightness,
          theme: A2uiKitTheme.playground(brightness),
        );
        final prose = A2uiKitTheme.playground(
          brightness,
        ).color(A2uiColorToken.textProse);
        expect(
          _canvas(tester),
          paints
            ..something(paintedPath(style: PaintingStyle.fill, color: prose)),
        );
      });
    }
  });
}
