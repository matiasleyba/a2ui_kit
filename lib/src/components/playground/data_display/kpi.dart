import 'dart:math' as math;

import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The pop-in of a KPI's glyphs: 500ms each, 70ms apart, rising 8px with
/// an overshoot (transitions.dev's number pop-in).
const Duration kpiGlyphDuration = Duration(milliseconds: 500);

/// The delay between two glyphs of the pop-in.
const Duration kpiGlyphStagger = Duration(milliseconds: 70);

const Cubic _popCurve = Cubic(.34, 1.45, .64, 1);

/// The text of a KPI value: a number in en-US with grouping and at most two
/// decimals, else the value as text.
String kpiText(Object? value) =>
    value is num ? formatPlaygroundNumber(value) : playgroundString(value);

/// Whether [text] is a phrase (a model putting words in a KPI): it has a
/// space and more than 14 characters. A phrase wraps at spaces, is at most
/// 18px and does not pop in.
bool isKpiPhrase(String text) => text.contains(' ') && text.length > 14;

/// The playground's `KpiValue`: a semibold value whose size follows the
/// width of its container, between 14px and [maxFontSize]
/// (`clamp(14px, fit cqi, max)`, where `fit` keeps the value on one line),
/// and whose glyphs pop in one after another when it changes.
///
/// The container's width is the widest its parent lets it be. The text
/// scale raises the floor and the ceiling; where the raised floor would
/// push the value out of its container, the value shrinks below it to fit
/// (a phrase, to fit its longest word). Under reduced motion nothing
/// moves.
class KpiValue extends StatefulWidget {
  /// The KPI [value].
  const KpiValue({
    required this.value,
    required this.maxFontSize,
    this.color,
    super.key,
  });

  /// The value: a number or text.
  final Object? value;

  /// The largest size, in pixels: 26 in a Stat, 22 in a StatGroup.
  final double maxFontSize;

  /// The colour, the text colour around it when null.
  final Color? color;

  @override
  State<KpiValue> createState() => _KpiValueState();
}

class _KpiValueState extends State<KpiValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this);
  String? _text;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KpiValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final text = kpiText(widget.value);
    if (text == _text) return;
    _text = text;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced || isKpiPhrase(text) || text.isEmpty) {
      _pop.value = 1;
      return;
    }
    final glyphs = text.runes.length;
    _pop
      ..duration = kpiGlyphDuration + kpiGlyphStagger * (glyphs - 1)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text ?? '';
    final inherited = DefaultTextStyle.of(context).style;
    return Semantics(
      label: text,
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, _) => _KpiText(
          text: text,
          maxFontSize: widget.maxFontSize,
          style: TextStyle(
            fontFamily: inherited.fontFamily,
            fontFamilyFallback: inherited.fontFamilyFallback,
            color: widget.color ?? inherited.color,
          ),
          textScaler: MediaQuery.textScalerOf(context),
          elapsed: _pop.isCompleted
              ? null
              : (_pop.duration ?? Duration.zero) * _pop.value,
        ),
      ),
    );
  }
}

class _KpiText extends LeafRenderObjectWidget {
  const _KpiText({
    required this.text,
    required this.maxFontSize,
    required this.style,
    required this.textScaler,
    required this.elapsed,
  });

  final String text;
  final double maxFontSize;
  final TextStyle style;
  final TextScaler textScaler;
  final Duration? elapsed;

  @override
  RenderKpiText createRenderObject(BuildContext context) => RenderKpiText(
    text: text,
    maxFontSize: maxFontSize,
    style: style,
    textScaler: textScaler,
    elapsed: elapsed,
  );

  @override
  void updateRenderObject(BuildContext context, RenderKpiText renderObject) {
    renderObject
      ..text = text
      ..maxFontSize = maxFontSize
      ..style = style
      ..textScaler = textScaler
      ..elapsed = elapsed;
  }
}

/// The render object of [KpiValue]: the text at the size its container's
/// width gives, one glyph box per character as CopilotKit's spans are.
///
/// It measures text, so a font that loads later (a web font) clears its
/// measure and lays it out again (RULEBOOK §2, review 2a A2).
class RenderKpiText extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  /// Lays out [text].
  RenderKpiText({
    required String text,
    required double maxFontSize,
    required TextStyle style,
    required TextScaler textScaler,
    Duration? elapsed,
  }) : _text = text,
       _maxFontSize = maxFontSize,
       _style = style,
       _textScaler = textScaler,
       _elapsed = elapsed;

  String _text;

  /// The text.
  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _widthPerPixel = null;
    markNeedsLayout();
  }

  double _maxFontSize;

  /// The largest size in pixels.
  double get maxFontSize => _maxFontSize;
  set maxFontSize(double value) {
    if (value == _maxFontSize) return;
    _maxFontSize = value;
    markNeedsLayout();
  }

  TextStyle _style;

  /// The family and colour.
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _widthPerPixel = null;
    markNeedsLayout();
  }

  TextScaler _textScaler;

  /// The text scale.
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    markNeedsLayout();
  }

  Duration? _elapsed;

  /// The time into the pop-in, or null when it is over.
  Duration? get elapsed => _elapsed;
  set elapsed(Duration? value) {
    if (value == _elapsed) return;
    _elapsed = value;
    markNeedsPaint();
  }

  bool get _phrase => isKpiPhrase(_text);

  /// The font size in a container [width] pixels wide (null: unbounded):
  /// `clamp(14px, fit, max)`, the floor and the ceiling raised by the text
  /// scale. Where the floor would push the value (or a phrase's longest
  /// word) past [width], the value shrinks to fit instead, so it never
  /// leaves its container.
  double fontSizeFor(double? width) {
    final words = _text.split(RegExp(r'\s+'));
    final longest = math.max(1, words.map((w) => w.length).fold(0, math.max));
    final count = math.max(_phrase ? longest + 2 : _text.length, 4);
    final low = _textScaler.scale(14);
    final high = _textScaler.scale(
      _phrase ? math.min(_maxFontSize, 18) : _maxFontSize,
    );
    if (width == null || !width.isFinite) return high;
    final size = math.max(low, math.min(width / (.62 * count), high));
    // The width of text is linear in its size (the tracking is in em too),
    // so one measure gives the size at which the value just fits.
    final perPixel = _widthPerPixel ??= _widestRun(_measureSize) / _measureSize;
    if (width > 0 && perPixel * size > width) return width / perPixel;
    return size;
  }

  /// The font size the value is measured at once.
  static const double _measureSize = 100;

  /// The width of the value (or of a phrase's widest word) per pixel of
  /// font size, measured once for the text, the style and the fonts.
  double? _widthPerPixel;

  @override
  void systemFontsDidChange() {
    _widthPerPixel = null;
    super.systemFontsDidChange();
  }

  /// How many times the value's glyphs were measured to size it.
  @visibleForTesting
  int debugSizeMeasures = 0;

  /// The width of the value at [fontSize] (its glyphs side by side), or of
  /// a phrase's widest word, which must not break.
  double _widestRun(double fontSize) {
    debugSizeMeasures++;
    final style = _styleAt(fontSize);
    double widthOf(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    if (_phrase) {
      return _text.split(RegExp(r'\s+')).map(widthOf).fold(0, math.max);
    }
    var sum = 0.0;
    for (final rune in _text.runes) {
      sum += widthOf(rune == 0x20 ? ' ' : String.fromCharCode(rune));
    }
    return sum;
  }

  /// The width the laid-out value takes: never more than its box's.
  @visibleForTesting
  double get contentWidth => _phrasePainter?.width ?? _glyphsWidth;

  TextStyle _styleAt(double fontSize) => _style.copyWith(
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -.025 * fontSize,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  List<TextPainter> _glyphs = const [];
  TextPainter? _phrasePainter;
  double _glyphsWidth = 0;

  void _disposePainters() {
    for (final painter in _glyphs) {
      painter.dispose();
    }
    _glyphs = const [];
    _phrasePainter?.dispose();
    _phrasePainter = null;
  }

  /// Lays the text out for a container [width] pixels wide; the phrase
  /// wraps within [maxWidth].
  Size _layoutText(double? width, double maxWidth) {
    _disposePainters();
    final style = _styleAt(fontSizeFor(width));
    if (_phrase) {
      final painter = TextPainter(
        text: TextSpan(text: _text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity);
      _phrasePainter = painter;
      return painter.size;
    }
    _glyphs = [
      for (final rune in _text.runes)
        TextPainter(
          text: TextSpan(
            text: rune == 0x20 ? ' ' : String.fromCharCode(rune),
            style: style,
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    _glyphsWidth = _glyphs.fold(0, (sum, g) => sum + g.width);
    final height = _glyphs.isEmpty
        ? (style.fontSize ?? 14) * 1.1
        : _glyphs.map((g) => g.height).reduce(math.max);
    return Size(_glyphsWidth, height);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (!_phrase) return computeMaxIntrinsicWidth(height);
    final painter = TextPainter(
      text: TextSpan(text: _text, style: _styleAt(fontSizeFor(null))),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.minIntrinsicWidth;
    painter.dispose();
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final painter = TextPainter(
      text: TextSpan(text: _text, style: _styleAt(fontSizeFor(null))),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _dryHeight(width.isFinite ? width : null);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _dryHeight(width.isFinite ? width : null);

  double _dryHeight(double? width) {
    final painter = TextPainter(
      text: TextSpan(text: _text, style: _styleAt(fontSizeFor(width))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _phrase && width != null ? width : double.infinity);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    final painter = TextPainter(
      text: TextSpan(text: _text, style: _styleAt(fontSizeFor(width))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _phrase && width != null ? width : double.infinity);
    final size = painter.size;
    painter.dispose();
    return constraints.constrain(size);
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    if (_text.isEmpty) return null;
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    final painter = TextPainter(
      // Every glyph box has the same line: the first one's baseline is the
      // line's.
      text: TextSpan(
        text: _phrase ? _text : String.fromCharCode(_text.runes.first),
        style: _styleAt(fontSizeFor(width)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _phrase && width != null ? width : double.infinity);
    final value = painter.computeDistanceToActualBaseline(baseline);
    painter.dispose();
    return value;
  }

  @override
  void performLayout() {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    size = constraints.constrain(_layoutText(width, constraints.maxWidth));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final phrase = _phrasePainter;
    if (phrase != null) {
      return phrase.computeDistanceToActualBaseline(baseline);
    }
    if (_glyphs.isEmpty) return null;
    return _glyphs.first.computeDistanceToActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final phrase = _phrasePainter;
    if (phrase != null) {
      phrase.paint(context.canvas, offset);
      return;
    }
    final canvas = context.canvas;
    final elapsed = _elapsed;
    var x = 0.0;
    for (var i = 0; i < _glyphs.length; i++) {
      final glyph = _glyphs[i];
      var dy = 0.0;
      var opacity = 1.0;
      if (elapsed != null) {
        final local =
            ((elapsed - kpiGlyphStagger * i).inMicroseconds /
                    kpiGlyphDuration.inMicroseconds)
                .clamp(0.0, 1.0);
        final eased = _popCurve.transform(local);
        dy = 8 * (1 - eased);
        opacity = eased.clamp(0.0, 1.0);
      }
      final at = offset + Offset(x, dy);
      if (opacity >= 1) {
        glyph.paint(canvas, at);
      } else if (opacity > 0) {
        canvas.saveLayer(
          at & glyph.size,
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
        glyph.paint(canvas, at);
        canvas.restore();
      }
      x += glyph.width;
    }
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }
}

/// The trend of a delta: `trend`, else down for a `-` delta, else up.
A2uiTrend? trendOf(String? delta, A2uiTrend? trend) {
  if (trend != null) return trend;
  if (delta == null || delta.isEmpty) return null;
  return delta.trim().startsWith('-') ? A2uiTrend.down : A2uiTrend.up;
}

/// The playground's `Delta`: an arrow (up-right, down-right, or a minus
/// for flat) and the delta, 12px medium, positive green, negative red,
/// flat muted. Nothing without a delta.
class KpiDelta extends StatelessWidget {
  /// A delta.
  const KpiDelta({this.delta, this.trend, super.key});

  /// The text, such as `+4.2%`.
  final String? delta;

  /// The direction; from the sign when null.
  final A2uiTrend? trend;

  @override
  Widget build(BuildContext context) {
    final delta = this.delta;
    if (delta == null || delta.isEmpty) return const SizedBox.shrink();
    final tokens = playgroundTokens(context);
    final t = trendOf(delta, trend);
    final color = switch (t) {
      A2uiTrend.down => tokens.toneColor(A2uiTone.negative),
      A2uiTrend.flat => tokens.mutedForeground,
      _ => tokens.toneColor(A2uiTone.positive),
    };
    // `t === "down" ? ArrowDownRight : t === "flat" ? Minus : ArrowUpRight`
    // (`renderers/data.tsx:325-326`), lucide-react 1.57.0's imports.
    final icon = lucideImport(switch (t) {
      A2uiTrend.down => 'ArrowDownRight',
      A2uiTrend.flat => 'Minus',
      _ => 'ArrowUpRight',
    }, LucideRelease.playground);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: LucideGlyph(icon, size: 14, color: color),
        ),
        Flexible(
          child: Text(
            delta,
            style: playgroundText(
              12,
              color: color,
              weight: FontWeight.w500,
              height: 1.25,
              tabular: true,
            ),
          ),
        ),
      ],
    );
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/data.tsx
