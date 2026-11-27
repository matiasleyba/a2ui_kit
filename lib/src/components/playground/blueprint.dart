// The playground's `Blueprint` (renderers/blueprint.tsx, globals.css
// `.wb-floor .a2-blueprint`, motion.css): the dotted generation frame a
// surface shows for a component whose id has arrived and whose props are
// still streaming. The agent emits it; the catalog prompt never lists it.

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The props schema of `Blueprint`: `of` (the type, or `#id` while only
/// the id is known), `h` (a height in pixels), `state`, and `hideName`
/// (draw the frame without the component's name).
final Schema blueprintSchema = Schema.fromMap(const {
  'type': 'object',
  'properties': {
    'component': {'const': 'Blueprint'},
    'of': {'type': 'string'},
    'h': {'type': 'number'},
    'state': {'type': 'string'},
    'hideName': {'type': 'boolean'},
  },
  'required': ['component'],
});

/// Typical slot heights, in pixels, so a frame already sits where the
/// component will (`SLOT` in blueprint.tsx). An unknown type, and an id
/// (`#chart`), is 72.
const Map<String, double> blueprintSlotHeights = {
  'Heading': 64,
  'Text': 22,
  'Markdown': 72,
  'Badge': 24,
  'Kbd': 24,
  'Divider': 12,
  'Button': 36,
  'Avatar': 44,
  'Stat': 104,
  'StatGroup': 96,
  'Progress': 44,
  'RadialProgress': 96,
  'Rating': 36,
  'TagList': 32,
  'KeyValueList': 168,
  'Timeline': 220,
  'Agenda': 240,
  'DataTable': 240,
  'ComparisonTable': 240,
  'List': 200,
  'LineChart': 260,
  'AreaChart': 260,
  'BarChart': 260,
  'PieChart': 240,
  'ScatterChart': 260,
  'Heatmap': 240,
  'Sparkline': 72,
  'RadarChart': 280,
  'CandlestickChart': 280,
  'Treemap': 260,
  'SankeyChart': 300,
  'Gauge': 160,
  'MapView': 320,
  'RouteMap': 360,
  'LocationCard': 260,
  'PlaceList': 420,
  'TextField': 62,
  'Textarea': 110,
  'Select': 62,
  'Combobox': 62,
  'CheckBox': 24,
  'Switch': 64,
  'RadioGroup': 120,
  'Slider': 56,
  'DatePicker': 62,
  'ButtonGroup': 62,
  'ChipSelect': 62,
  'Alert': 64,
  'Callout': 72,
  'EmptyState': 160,
  'Skeleton': 80,
  'WeatherCard': 420,
  'FlightCard': 170,
  'ProductCard': 200,
  'ProfileCard': 320,
  'ReceiptCard': 320,
  'EventCard': 300,
  'StockTicker': 220,
  'RecipeCard': 420,
  'Image': 220,
  'ImageGallery': 260,
  'VideoEmbed': 300,
  'CodeBlock': 140,
  'Quote': 96,
  'Card': 120,
  'Section': 120,
  'Grid': 104,
  'Row': 104,
  'Column': 120,
  'Tabs': 160,
  'Accordion': 150,
  'Carousel': 200,
};

/// The height of a frame for [of], before the 28px minimum.
double blueprintSlotHeight(String? of) => blueprintSlotHeights[of] ?? 72;

/// The playground `Blueprint`.
///
/// A full-width frame, `h` pixels tall or the slot of `of` (72 when `of`
/// is missing or an id), and at least 28px. Its caption is the name the
/// model has written so far: `of`, with one leading `#` removed.
/// `hideName` draws the frame with no caption. Hidden from screen readers,
/// as the playground's `aria-hidden` frame is.
Widget buildBlueprint(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final of = props.string('of');
  final specified = props.number('h');
  final slot = specified != null && specified.isFinite && specified >= 0
      ? specified
      : blueprintSlotHeight(of);
  final named = of == null || of.isEmpty
      ? null
      : (of.startsWith('#') ? of.substring(1) : of);
  final hideName = props.boolean('hideName') ?? false;
  final caption = hideName || named == null || named.isEmpty ? null : named;
  return _BlueprintFrame(
    height: math.max(slot, 28),
    caption: caption == null || caption.isEmpty ? null : caption,
  );
}

/// The outline traced in from the top, both ways, over 770ms
/// (`--gen-trace-dur`, `cubic-bezier(0.16, 1, 0.3, 1)`).
const Cubic _traceEase = Cubic(0.16, 1, 0.3, 1);

/// The field fading in over 400ms (`--duration-slow`,
/// `cubic-bezier(0.22, 1, 0.36, 1)`).
const Cubic _fieldEase = Cubic(0.22, 1, 0.36, 1);

/// One generation frame.
class _BlueprintFrame extends StatefulWidget {
  const _BlueprintFrame({required this.height, required this.caption});

  final double height;
  final String? caption;

  @override
  State<_BlueprintFrame> createState() => _BlueprintFrameState();
}

class _BlueprintFrameState extends State<_BlueprintFrame>
    with TickerProviderStateMixin {
  AnimationController? _trace;
  AnimationController? _flow;
  AnimationController? _field;
  CurvedAnimation? _traceCurve;
  CurvedAnimation? _fieldCurve;
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    _stop();
    if (reduced) return;
    _trace = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 770),
    )..forward();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat();
    _field = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _traceCurve = CurvedAnimation(parent: _trace!, curve: _traceEase);
    _fieldCurve = CurvedAnimation(parent: _field!, curve: _fieldEase);
  }

  void _stop() {
    _traceCurve?.dispose();
    _fieldCurve?.dispose();
    _traceCurve = null;
    _fieldCurve = null;
    _trace?.dispose();
    _flow?.dispose();
    _field?.dispose();
    _trace = null;
    _flow = null;
    _field = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    if (flow == null) return _box(1, 0, 1);
    return AnimatedBuilder(
      animation: Listenable.merge([_traceCurve, flow, _fieldCurve]),
      builder: (context, _) =>
          _box(_traceCurve!.value, flow.value, _fieldCurve!.value),
    );
  }

  /// [trace] is 0 at the top centre and 1 when both sides have met.
  /// [flow] is the phase of one 4.8px dot step. [fade] is the field's
  /// opacity. Reduced motion draws the frame still and whole.
  Widget _box(double trace, double flow, double fade) {
    final dark = A2uiKitScope.themeOf(context).brightness == Brightness.dark;
    final line = dark ? const Color(0xff6f6f6f) : const Color(0xff9a9a9a);
    final ground = dark ? oklch(0.145, 0.004, 285) : oklch(0.985, 0.002, 285);
    final field = dark
        ? const Color.fromRGBO(245, 245, 245, 0.15)
        : const Color.fromRGBO(13, 13, 13, 0.16);
    final type = A2uiKitScope.themeOf(context).typography;
    final caption = widget.caption;
    return ExcludeSemantics(
      child: _Slot(
        height: widget.height,
        child: Opacity(
          opacity: fade,
          child: CustomPaint(
            willChange: _flow != null,
            painter: _FramePainter(
              ground: ground,
              field: field,
              line: line,
              trace: trace,
              flow: flow,
            ),
            child: caption == null
                ? const SizedBox.expand()
                : Stack(
                    children: [
                      const SizedBox.expand(),
                      Positioned(
                        top: 8,
                        left: 11,
                        child: MediaQuery.withNoTextScaling(
                          child: Text(
                            caption,
                            style: TextStyle(
                              fontFamily: type.monoFontFamily,
                              fontFamilyFallback: type.monoFontFamilyFallback,
                              fontSize: 10,
                              height: 1,
                              letterSpacing: 0.2,
                              color: line,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Fills the width it is given (`width: 100%`) and keeps [height], with a
/// minimum width of 0 so a row can shrink it.
class _Slot extends SingleChildRenderObjectWidget {
  const _Slot({required this.height, required super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSlot(height);

  @override
  void updateRenderObject(BuildContext context, _RenderSlot renderObject) {
    renderObject.height = height;
  }
}

class _RenderSlot extends RenderProxyBox {
  _RenderSlot(this._height);

  double _height;

  /// The frame's height, in pixels.
  double get height => _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  /// A stand-in for `width: 100%`: wide enough that a row shrinks it to
  /// its share, and a column clamps it to the width the column was given.
  static const double _full = 1000000;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _full;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _size(constraints);

  @override
  void performLayout() {
    size = _size(constraints);
    child?.layout(BoxConstraints.tight(size));
  }

  Size _size(BoxConstraints constraints) {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    return constraints.constrain(Size(width, _height));
  }
}

/// The dot field and the flowing outline (motion.css `.gen-outline`).
class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.ground,
    required this.field,
    required this.line,
    required this.trace,
    required this.flow,
  });

  final Color ground;
  final Color field;
  final Color line;

  /// 0 hides the outline; 1 has traced both sides down to the bottom.
  final double trace;

  /// 0 to 1, one 4.8px step of the dots along the outline.
  final double flow;

  static const double _pitch = 15;
  static const double _gap = 4.8;
  static const double _dotRadius = 1.05;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(box, const Radius.circular(12)))
      ..drawRect(box, Paint()..color = ground);
    final dots = Paint()..color = field;
    for (var y = _pitch / 2; y < size.height; y += _pitch) {
      for (var x = _pitch / 2; x < size.width; x += _pitch) {
        canvas.drawCircle(Offset(x, y), 1.1, dots);
      }
    }
    canvas.restore();
    if (trace <= 0 || size.width <= 2 || size.height <= 2) return;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(11)));
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    _dots(canvas, metrics.first, rect.center);
  }

  void _dots(Canvas canvas, PathMetric metric, Offset center) {
    final length = metric.length;
    if (length <= 0) return;
    final wedge = trace * math.pi;
    final paint = Paint()..color = line;
    for (var distance = flow * _gap; distance < length; distance += _gap) {
      final pos = metric.getTangentForOffset(distance)?.position;
      if (pos == null) continue;
      final delta = pos - center;
      var angle = math.atan2(delta.dx, -delta.dy);
      if (angle < 0) angle += math.pi * 2;
      if (math.min(angle, math.pi * 2 - angle) > wedge) continue;
      canvas.drawCircle(pos, _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.ground != ground ||
      oldDelegate.field != field ||
      oldDelegate.line != line ||
      oldDelegate.trace != trace ||
      oldDelegate.flow != flow;
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/blueprint.tsx
