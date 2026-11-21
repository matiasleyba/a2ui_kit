// The Lucide foundation: the table of lucide-react's icon nodes at both
// releases CopilotKit draws (0.525.0 and 1.57.0), the lookup by name
// (react-core's media.tsx), and each element stroked as lucide-react's
// `<svg>` strokes it, checked by its draw calls and its pixels.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart'
    show RenderLucideGlyph, lucidePascalName;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_parsing/path_parsing.dart';

const LucideRelease _reactCore = LucideRelease.reactCore;
const LucideRelease _playground = LucideRelease.playground;

/// The node [name] has in [release]'s `icons`.
LucideIconNode _icon(String name, [LucideRelease release = _reactCore]) =>
    lucideIcon(name, release: release)!;

/// The commands path_parsing reads from path data, for a strict parse.
class _Commands extends PathProxy {
  final List<String> commands = [];

  @override
  void close() => commands.add('Z');

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => commands.add('C');

  @override
  void lineTo(double x, double y) => commands.add('L $x $y');

  @override
  void moveTo(double x, double y) => commands.add('M $x $y');
}

/// A draw call's paint is a round-capped, round-joined stroke of [width] in
/// [color].
PaintPatternPredicate _roundStroke(
  Symbol method, {
  required double width,
  Color? color,
}) => (call, args) {
  if (call != method) return false;
  final paint = args.last;
  return paint is Paint &&
      paint.style == PaintingStyle.stroke &&
      paint.strokeWidth == width &&
      paint.strokeCap == StrokeCap.round &&
      paint.strokeJoin == StrokeJoin.round &&
      (color == null || paint.color.toARGB32() == color.toARGB32());
};

/// The RGBA pixels of [glyph], drawn alone on a transparent ground.
Future<(ByteData, int)> _pixels(WidgetTester tester, Widget glyph) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(key: key, child: glyph),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(boundary.toImage))!;
  final data = (await tester.runAsync(image.toByteData))!;
  final width = image.width;
  image.dispose();
  return (data, width);
}

int _alpha((ByteData, int) pixels, int x, int y) {
  final (data, width) = pixels;
  return data.getUint8((y * width + x) * 4 + 3);
}

const _black = Color(0xff000000);

void main() {
  group('the table, at both releases', () {
    test('holds each release whole, at its version', () {
      expect(_reactCore.version, '0.525.0');
      expect(_playground.version, '1.57.0');
      // The exports of each package's dist/esm/icons/index, and the other
      // names its lucide-react.js exports them by.
      expect(_reactCore.iconNames, hasLength(1611));
      expect(_playground.iconNames, hasLength(1890));
      expect(_reactCore.aliases, hasLength(211));
      expect(_playground.aliases, hasLength(260));
    });

    test('every name is its own kebabToPascal, so `?? icons[name]` never '
        'finds more', () {
      for (final release in LucideRelease.values) {
        for (final name in release.iconNames) {
          expect(lucidePascalName(name), name, reason: name);
          final node = lucideIcon(name, release: release)!;
          expect(node.name, name);
          expect(node.release, release);
          expect(node.elements, isNotEmpty);
        }
      }
    });

    test('every alias names an icon, and is not itself in `icons`', () {
      for (final release in LucideRelease.values) {
        for (final MapEntry(key: alias, value: name)
            in release.aliases.entries) {
          expect(release.iconNames, isNot(contains(alias)));
          expect(lucideImport(alias, release), _icon(name, release));
        }
      }
    });

    test('every path parses whole, and every number is finite', () {
      for (final release in LucideRelease.values) {
        for (final name in release.iconNames) {
          for (final element in _icon(name, release).elements) {
            final numbers = switch (element) {
              LucidePath(:final d) => () {
                final commands = _Commands();
                writeSvgPathDataToPath(d, commands);
                expect(commands.commands.first, startsWith('M'), reason: d);
                return const <double>[];
              }(),
              LucideCircle(:final cx, :final cy, :final r) => [cx, cy, r],
              LucideEllipse(:final cx, :final cy, :final rx, :final ry) => [
                cx,
                cy,
                rx,
                ry,
              ],
              LucideRect(:final x, :final y, :final width, :final height) => [
                x,
                y,
                width,
                height,
              ],
              LucideLine(:final x1, :final y1, :final x2, :final y2) => [
                x1,
                y1,
                x2,
                y2,
              ],
              LucidePolyline(:final points) ||
              LucidePolygon(:final points) => points,
            };
            expect(numbers.every((n) => n.isFinite), isTrue, reason: name);
          }
        }
      }
    });

    test('a node both releases draw the same is one node', () {
      expect(
        identical(
          _icon('arrow-right').elements,
          _icon('arrow-right', _playground).elements,
        ),
        isTrue,
      );
      expect(_icon('arrow-right'), _icon('arrow-right', _playground));
      // 1.0 redrew the heart.
      expect(_icon('heart'), isNot(_icon('heart', _playground)));
    });

    test("lucide-react's own nodes: arrow-right, circle-alert, tag", () {
      expect(_icon('arrow-right').elements, const [
        LucidePath('M5 12h14'),
        LucidePath('m12 5 7 7-7 7'),
      ]);
      expect(_icon('circle-alert').elements, const [
        LucideCircle(12, 12, 10),
        LucideLine(12, 8, 12, 12),
        LucideLine(12, 16, 12.01, 16),
      ]);
      expect(
        _icon('tag').elements.last,
        const LucideCircle(7.5, 7.5, .5, filled: true),
      );
      expect(_icon('square').elements, const [LucideRect(3, 3, 18, 18, rx: 2)]);
      expect(_icon('play').elements, const [
        LucidePolygon([6, 3, 20, 12, 6, 21, 6, 3]),
      ]);
      expect(
        _icon('database').elements.first,
        const LucideEllipse(12, 5, 9, 3),
      );
      expect(
        _icon('inbox').elements.first,
        const LucidePolyline([
          22, 12, 16, 12, 14, 15, 10, 15, 8, 12, 2, 12, //
        ]),
      );
    });
  });

  group('lookup by name', () {
    test('reads kebab, Pascal, snake, camel and spaced names as '
        'kebabToPascal does', () {
      for (final release in LucideRelease.values) {
        for (final name in [
          'arrow-right',
          'ArrowRight',
          'arrow_right',
          'arrowRight',
          'arrow right',
        ]) {
          expect(
            lucideIcon(name, release: release)?.name,
            'ArrowRight',
            reason: name,
          );
        }
        expect(
          lucideIcon('arrow-down-0-1', release: release)?.name,
          'ArrowDown01',
        );
      }
      expect(lucidePascalName('arrow-down-0-1'), 'ArrowDown01');
      expect(lucidePascalName('--a__b  c-'), 'ABC');
    });

    test('an empty, null or unknown name draws nothing', () {
      for (final release in LucideRelease.values) {
        expect(lucideIcon(null, release: release), isNull);
        expect(lucideIcon('', release: release), isNull);
        expect(lucideIcon('no-such-icon', release: release), isNull);
      }
    });

    test('each release knows its own names', () {
      // A2UI's `delete` is trash-2, which 0.525.0 has and 1.57.0 folded
      // into trash; `ad` is new in 1.57.0.
      expect(lucideIcon('trash-2', release: _reactCore)?.name, 'Trash2');
      expect(lucideIcon('trash-2', release: _playground), isNull);
      expect(lucideIcon('ad', release: _reactCore), isNull);
      expect(lucideIcon('ad', release: _playground)?.name, 'Ad');
    });

    test('an alias is no name to look up, but a renderer may import it', () {
      // `icons` holds no alias (CopilotKit's `icons[...]` misses it) ...
      expect(lucideIcon('alert-circle', release: _reactCore), isNull);
      expect(lucideIcon('AlertTriangle', release: _playground), isNull);
      // ... while `import { AlertTriangle } from "lucide-react"` draws
      // TriangleAlert.
      for (final (alias, release) in [
        ('AlertCircle', _reactCore),
        ('AlertTriangle', _playground),
        ('Trash2', _playground),
      ]) {
        expect(() => lucideImport(alias, release), returnsNormally);
      }
      expect(lucideImport('AlertCircle', _reactCore), _icon('circle-alert'));
      expect(
        lucideImport('AlertTriangle', _playground),
        _icon('triangle-alert', _playground),
      );
      expect(lucideImport('Trash2', _playground), _icon('trash', _playground));
      expect(lucideImport('Info', _playground), _icon('info', _playground));
      expect(
        () => lucideImport('NoSuchIcon', _playground),
        throwsArgumentError,
      );
    });

    test('A2UI names map only when asked (the Icon component)', () {
      expect(a2uiIconNames, hasLength(59));
      expect(
        lucideIcon('arrowBack', release: _reactCore, a2uiNames: true),
        _icon('arrow-left'),
      );
      expect(
        lucideIcon('close', release: _reactCore, a2uiNames: true),
        _icon('x'),
      );
      expect(lucideIcon('close', release: _reactCore), isNull);
      // Every A2UI name draws in react-core's release, the Icon's.
      for (final MapEntry(key: name, value: lucide) in a2uiIconNames.entries) {
        expect(
          lucideIcon(name, release: _reactCore, a2uiNames: true),
          _icon(lucide),
          reason: name,
        );
      }
    });
  });

  group('LucideRect corners', () {
    test("an `auto` radius takes the other's; each is at most half a side", () {
      expect(const LucideRect(0, 0, 10, 10, rx: 2).radii, (2, 2));
      expect(const LucideRect(0, 0, 10, 10, ry: 3).radii, (3, 3));
      expect(const LucideRect(0, 0, 10, 10, rx: 2, ry: 3).radii, (2, 3));
      expect(const LucideRect(0, 0, 10, 10).radii, (0, 0));
      // Half the width stays; more is cut to it.
      expect(const LucideRect(0, 0, 4, 10, rx: 2).radii, (2, 2));
      expect(const LucideRect(0, 0, 4, 10, rx: 3).radii, (2, 3));
      expect(const LucideRect(0, 0, 10, 2, rx: 3).radii, (3, 1));
    });

    testWidgets('a rounded rect is an rrect; a square one a rect', (
      tester,
    ) async {
      await tester.pumpWidget(
        Center(child: LucideGlyph(_icon('square'), size: 24, color: _black)),
      );
      expect(
        find.byType(LucideGlyph),
        paints..rrect(
          rrect: RRect.fromRectXY(const Rect.fromLTWH(3, 3, 18, 18), 2, 2),
          style: PaintingStyle.stroke,
        ),
      );
    });
  });

  group('drawing', () {
    Future<void> pump(
      WidgetTester tester,
      LucideIconNode icon, {
      double size = 24,
      Color? color = _black,
      Color? stroke,
      double strokeWidth = 2,
    }) => tester.pumpWidget(
      Center(
        child: LucideGlyph(
          icon,
          size: size,
          color: color,
          stroke: stroke,
          strokeWidth: strokeWidth,
        ),
      ),
    );

    testWidgets('each element is stroked, round-capped and round-joined, on '
        'the 24 grid', (tester) async {
      await pump(tester, _icon('circle-alert'));
      expect(
        find.byType(LucideGlyph),
        paints
          ..clipRect(rect: const Rect.fromLTWH(0, 0, 24, 24))
          ..circle(x: 12, y: 12, radius: 10, strokeWidth: 2, color: _black)
          ..line(p1: const Offset(12, 8), p2: const Offset(12, 12))
          ..line(p1: const Offset(12, 16), p2: const Offset(12.01, 16)),
      );
      expect(
        find.byType(LucideGlyph),
        paints
          ..something(_roundStroke(#drawCircle, width: 2, color: _black))
          ..something(_roundStroke(#drawLine, width: 2, color: _black)),
      );
      await pump(tester, _icon('inbox'));
      expect(
        find.byType(LucideGlyph),
        paints..something(_roundStroke(#drawPath, width: 2)),
      );
      await pump(tester, _icon('database'));
      expect(
        find.byType(LucideGlyph),
        paints..something(
          (method, args) =>
              method == #drawOval &&
              args.first ==
                  Rect.fromCenter(
                    center: const Offset(12, 5),
                    width: 18,
                    height: 6,
                  ) &&
              (args.last as Paint).style == PaintingStyle.stroke,
        ),
      );
    });

    test('a polygon is closed, a polyline open, through every point', () {
      // A triangle whose last point is not its first: closing adds an edge.
      final polygon = const LucidePolygon([
        2,
        2,
        22,
        2,
        12,
        20,
      ]).path.computeMetrics().toList();
      final polyline = const LucidePolyline([
        2,
        2,
        22,
        2,
        12,
        20,
      ]).path.computeMetrics().toList();
      final side = math.sqrt(10 * 10 + 18 * 18);
      expect(polygon.single.isClosed, isTrue);
      // Path metrics are single precision.
      expect(
        polygon.single.length,
        moreOrLessEquals(20 + 2 * side, epsilon: 1e-4),
      );
      expect(polyline.single.isClosed, isFalse);
      expect(
        polyline.single.length,
        moreOrLessEquals(20 + side, epsilon: 1e-4),
      );
      final end = polyline.single.getTangentForOffset(20 + side)!.position;
      expect(end.dx, moreOrLessEquals(12, epsilon: 1e-4));
      expect(end.dy, moreOrLessEquals(20, epsilon: 1e-4));
    });

    testWidgets("a polygon closes; a path's data is drawn as parsed", (
      tester,
    ) async {
      await pump(tester, _icon('play'));
      expect(
        find.byType(LucideGlyph),
        paints..path(
          includes: const [Offset(10, 12)],
          excludes: const [Offset(4, 12), Offset(21, 12)],
          style: PaintingStyle.stroke,
        ),
      );
      final path = (_icon('arrow-right').elements.first as LucidePath).path;
      await pump(tester, _icon('arrow-right'));
      expect(
        find.byType(LucideGlyph),
        paints..something(
          (method, args) => method == #drawPath && identical(args.first, path),
        ),
      );
    });

    testWidgets('a filled dot is filled in currentColor, then stroked', (
      tester,
    ) async {
      const text = Color(0xff112233);
      const stroke = Color(0xff445566);
      await pump(tester, _icon('tag'), color: text, stroke: stroke);
      expect(
        find.byType(LucideGlyph),
        paints
          ..path(color: stroke, style: PaintingStyle.stroke)
          ..circle(
            x: 7.5,
            y: 7.5,
            radius: .5,
            color: text,
            style: PaintingStyle.fill,
          )
          ..circle(
            x: 7.5,
            y: 7.5,
            radius: .5,
            color: stroke,
            style: PaintingStyle.stroke,
          ),
      );
    });

    testWidgets('the stroke and fill take the text colour when unset', (
      tester,
    ) async {
      const text = Color(0xff0a0b0c);
      await tester.pumpWidget(
        Center(
          child: DefaultTextStyle(
            style: const TextStyle(color: text),
            child: LucideGlyph(_icon('tag'), size: 24),
          ),
        ),
      );
      expect(
        find.byType(LucideGlyph),
        paints
          ..path(color: text, style: PaintingStyle.stroke)
          ..circle(color: text, style: PaintingStyle.fill),
      );
    });

    testWidgets('a stroke width of 0 paints no stroke', (tester) async {
      await pump(tester, _icon('arrow-right'), strokeWidth: 0);
      expect(find.byType(LucideGlyph), isNot(paints..path()));
    });

    testWidgets('a box that is not square fits the grid and centres it', (
      tester,
    ) async {
      await tester.pumpWidget(
        Center(
          child: SizedBox(
            width: 48,
            height: 24,
            child: LucideGlyph(_icon('arrow-right'), size: 24, color: _black),
          ),
        ),
      );
      expect(
        find.byType(LucideGlyph),
        paints
          ..clipRect(rect: const Rect.fromLTWH(0, 0, 48, 24))
          ..translate(x: 12, y: 0),
      );
    });

    testWidgets('pixels: the line, the round cap, and nothing beside', (
      tester,
    ) async {
      final pixels = await _pixels(
        tester,
        LucideGlyph(_icon('arrow-right'), size: 24, color: _black),
      );
      // "M5 12h14", 2 wide: rows 11 and 12 are covered.
      expect(_alpha(pixels, 12, 11), 255);
      expect(_alpha(pixels, 12, 12), 255);
      expect(_alpha(pixels, 12, 10), 0);
      // The round cap at (5, 12) covers a quarter disc of the pixel at
      // (4, 12): about 200 (a butt cap leaves it empty, a square one full).
      expect(_alpha(pixels, 4, 12), inInclusiveRange(150, 230));
      // Far from both strokes.
      expect(_alpha(pixels, 12, 9), 0);
      expect(_alpha(pixels, 2, 2), 0);
    });

    testWidgets('pixels: a wider stroke covers more', (tester) async {
      final pixels = await _pixels(
        tester,
        LucideGlyph(
          _icon('arrow-right'),
          size: 24,
          color: _black,
          strokeWidth: 3,
        ),
      );
      // 3 wide: 10.5 to 13.5, so half of row 10.
      expect(_alpha(pixels, 12, 10), inInclusiveRange(100, 160));
      expect(_alpha(pixels, 12, 11), 255);
    });

    testWidgets('pixels: the stroke scales with the icon', (tester) async {
      final pixels = await _pixels(
        tester,
        LucideGlyph(_icon('arrow-right'), size: 48, color: _black),
      );
      // At 48px the line is 4px wide: rows 22 to 25.
      expect(_alpha(pixels, 24, 22), 255);
      expect(_alpha(pixels, 24, 25), 255);
      expect(_alpha(pixels, 24, 21), 0);
      expect(_alpha(pixels, 24, 26), 0);
    });

    testWidgets('the baseline is the one given, else the bottom edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        Center(child: LucideGlyph(_icon('check'), size: 16, baseline: 14)),
      );
      RenderBox glyph() => tester.renderObject<RenderLucideGlyph>(
        find.descendant(
          of: find.byType(LucideGlyph),
          matching: find.byWidgetPredicate(
            (widget) => widget is LeafRenderObjectWidget,
          ),
        ),
      );
      double? baselineOf(RenderBox box) =>
          box.getDryBaseline(box.constraints, TextBaseline.alphabetic);
      expect(baselineOf(glyph()), 14);
      // What a parent reads, through the semantics wrapper.
      expect(
        baselineOf(tester.renderObject<RenderBox>(find.byType(LucideGlyph))),
        14,
      );
      await tester.pumpWidget(
        Center(child: LucideGlyph(_icon('check'), size: 16)),
      );
      expect(baselineOf(glyph()), 16);
      // A parent that asks the dry baseline through the semantics wrapper
      // (a baseline-aligned row) gets it too, with no assertion.
      await tester.pumpWidget(
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                LucideGlyph(_icon('check'), size: 16),
                LucideGlyph(_icon('x'), size: 24),
              ],
            ),
          ),
        ),
      );
      final row = tester.renderObject<RenderBox>(find.byType(Row));
      expect(row.getDryLayout(const BoxConstraints(maxWidth: 200)).height, 24);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(LucideGlyph).first).bottom,
        tester.getRect(find.byType(LucideGlyph).last).bottom,
      );
    });

    testWidgets('hidden from screen readers unless labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Column(
            children: [
              LucideGlyph(_icon('check')),
              LucideGlyph(_icon('x'), label: 'Close', description: 'Shut'),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Close')),
        isSemantics(label: 'Close', hint: 'Shut', isImage: true),
      );
      expect(find.semantics.byFlag(SemanticsFlag.isImage), findsOne);
      semantics.dispose();
    });
  });
}
