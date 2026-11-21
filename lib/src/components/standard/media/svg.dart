import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_color.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/svg/svg_drawing.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:flutter/widgets.dart';

/// The standard `Svg`: a drawing of primitive shapes, `rects`, `circles`,
/// `paths`, `lines` and `texts`, painted in that order (media.tsx:516-569).
///
/// The box is `width ?? size ?? "100%"` wide and `height ?? size` tall: a
/// number is pixels, a string a CSS length (a unitless one is pixels, as
/// in an SVG attribute). An auto height follows the `viewBox`'s ratio, and
/// is 150px without one, as a browser sizes an `<svg>`. The `viewBox` maps
/// user units onto the box by `preserveAspectRatio` (`xMidYMid meet` by
/// default); what leaves the box is clipped.
///
/// Colours take text colour tokens (`danger`) or CSS colours, `none` and
/// `currentColor`; `currentColor` is `color` (the `prose` token by
/// default). Every shape fills with the drawing's `fill` (`currentColor`
/// by default) and strokes with its `stroke` (none by default) unless it
/// sets its own; a line strokes in `currentColor` unless it sets one; a
/// text is filled and never stroked. `strokeWidth` (1 by default),
/// `strokeLinecap` and `strokeLinejoin` apply to every shape; a path may
/// set its own `strokeWidth`. A text's `size` is in user units, the
/// surrounding text's size when unset, and its `anchor` places its start,
/// middle or end at `x`, its baseline on `y`. A colour CSS cannot read is
/// ignored, as a browser ignores an invalid attribute: the shape inherits
/// the drawing's paint.
///
/// With a `label` (the envelope's label over it) the drawing is an image
/// with that name for screen readers, else it is decorative and hidden
/// (media.tsx:484-494).
Widget buildSvg(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = SvgProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final inherited = DefaultTextStyle.of(context).style;
  final envelope = KitEnvelope.of(props);
  final current =
      theme.textColor(view.color) ?? inherited.color ?? const Color(0xff000000);
  final drawing = svgDrawingOf(props, theme: theme, current: current);
  final canvas = SvgCanvas(
    drawing: drawing,
    textStyle: inherited,
    textScaler: MediaQuery.textScalerOf(context),
  );
  final propLabel = view.label;
  final label =
      envelope.label ??
      (propLabel == null || propLabel.isEmpty ? null : propLabel);
  if (label == null) return ExcludeSemantics(child: canvas);
  // a2ui_flutter's NodeView already holds the envelope's name in a node of
  // its own; the drawing makes that node its image (one image, as the one
  // <svg role="img"> upstream names).
  if (envelope.wrapped) {
    return Semantics(
      image: true,
      label: envelope.label == null ? label : null,
      child: ExcludeSemantics(child: canvas),
    );
  }
  return Semantics(
    container: true,
    image: true,
    label: label,
    child: ExcludeSemantics(child: canvas),
  );
}

/// The paint of a colour prop: inherited (null, empty or unreadable: a
/// browser drops an invalid attribute), none, `currentColor`, or a colour.
sealed class _SvgPaint {
  const _SvgPaint();
}

final class _Inherit extends _SvgPaint {
  const _Inherit();
}

final class _Paint extends _SvgPaint {
  const _Paint(this.color);

  /// The colour, or null for `none`.
  final Color? color;
}

_SvgPaint _paintOf(Object? raw, A2uiKitTheme theme, Color current) {
  final value = ComponentProps.asString(raw);
  if (value == null || value.isEmpty) return const _Inherit();
  final token = theme.textColor(value);
  if (token != null) return _Paint(token);
  return switch (value.trim().toLowerCase()) {
    'none' => const _Paint(null),
    'currentcolor' => _Paint(current),
    final css => switch (parseCssColor(css)) {
      final Color color => _Paint(color),
      null => const _Inherit(),
    },
  };
}

Color? _over(_SvgPaint paint, Color? inherited) => switch (paint) {
  _Inherit() => inherited,
  _Paint(:final color) => color,
};

/// The drawing of an Svg's [props]: its sizes, mapping and shapes, each
/// paint resolved against the drawing's own (`fill`, then black, its
/// initial value; `stroke`, none) in [theme], `currentColor` being
/// [current].
SvgDrawing svgDrawingOf(
  ComponentProps props, {
  required A2uiKitTheme theme,
  required Color current,
}) {
  final view = SvgProps(props);
  // `fill={textColor(props.fill) ?? "currentColor"}`: an empty fill is the
  // default; one CSS cannot read leaves the initial black.
  final rootFill = _over(
    _paintOf(view.fill.isEmpty ? 'currentColor' : view.fill, theme, current),
    const Color(0xff000000),
  );
  final rootStroke = _over(_paintOf(view.stroke, theme, current), null);
  final width = view.strokeWidth;
  // A negative width is invalid (the initial 1 stays); 0 strokes nothing.
  final rootWidth = width != null && width.isFinite && width >= 0 ? width : 1.0;
  List<Map<Object?, Object?>> entries(List<Object?> list) => [
    for (final raw in list)
      switch (ComponentProps.unwrap(raw)) {
        final Map<Object?, Object?> map => map,
        _ => const {},
      },
  ];
  // A missing coordinate is the attribute's initial 0; a missing size, 0,
  // renders nothing.
  double number(Map<Object?, Object?> map, String key) {
    final value = ComponentProps.asNumber(map[key]);
    return value != null && value.isFinite ? value : 0;
  }

  Color? fill(Map<Object?, Object?> map) =>
      _over(_paintOf(map['fill'], theme, current), rootFill);
  Color? stroke(Map<Object?, Object?> map) =>
      _over(_paintOf(map['stroke'], theme, current), rootStroke);

  final shapes = <SvgShape>[
    for (final rect in entries(view.rects))
      SvgGeometry(
        kind: 'rect',
        values: [
          number(rect, 'x'),
          number(rect, 'y'),
          number(rect, 'width'),
          number(rect, 'height'),
          number(rect, 'rx'),
        ],
        fill: fill(rect),
        stroke: stroke(rect),
        strokeWidth: rootWidth,
      ),
    for (final circle in entries(view.circles))
      SvgGeometry(
        kind: 'circle',
        values: [
          number(circle, 'cx'),
          number(circle, 'cy'),
          number(circle, 'r'),
        ],
        fill: fill(circle),
        stroke: stroke(circle),
        strokeWidth: rootWidth,
      ),
    for (final path in entries(view.paths))
      SvgGeometry(
        kind: 'path',
        path: ComponentProps.asString(path['d']),
        fill: fill(path),
        stroke: stroke(path),
        strokeWidth: switch (ComponentProps.asNumber(path['strokeWidth'])) {
          final double own when own.isFinite && own >= 0 => own,
          _ => rootWidth,
        },
      ),
    for (final line in entries(view.lines))
      SvgGeometry(
        kind: 'line',
        values: [
          number(line, 'x1'),
          number(line, 'y1'),
          number(line, 'x2'),
          number(line, 'y2'),
        ],
        // `stroke={textColor(line.stroke) ?? "currentColor"}`: no stroke of
        // its own is currentColor; an unreadable one inherits the drawing's.
        stroke: (ComponentProps.asString(line['stroke']) ?? '').isEmpty
            ? current
            : stroke(line),
        strokeWidth: rootWidth,
      ),
    for (final text in entries(view.texts))
      SvgText(
        x: number(text, 'x'),
        y: number(text, 'y'),
        text: ComponentProps.asString(text['text']) ?? '',
        // A negative size is invalid: the inherited size stays.
        fontSize: switch (ComponentProps.asNumber(text['size'])) {
          final double size when size.isFinite && size >= 0 => size,
          _ => null,
        },
        fill: fill(text),
        anchor: switch (text['anchor']) {
          'middle' => .5,
          'end' => 1,
          _ => 0,
        },
      ),
  ];
  return SvgDrawing(
    shapes: shapes,
    width: svgLengthOf(view.width ?? view.size ?? '100%'),
    height: svgLengthOf(view.height ?? view.size),
    viewBox: svgViewBoxOf(view.viewBox),
    aspect: SvgAspect.parse(view.preserveAspectRatio),
    cap: switch (view.strokeLinecap) {
      SvgStrokeLinecap.round => StrokeCap.round,
      SvgStrokeLinecap.square => StrokeCap.square,
      _ => StrokeCap.butt,
    },
    join: switch (view.strokeLinejoin) {
      SvgStrokeLinejoin.round => StrokeJoin.round,
      SvgStrokeLinejoin.bevel => StrokeJoin.bevel,
      _ => StrokeJoin.miter,
    },
  );
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/media.tsx
