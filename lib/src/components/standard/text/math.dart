// The standard Math: CopilotKit typesets `value` with KaTeX 0.16.27 (the
// version pnpm-lock.yaml pins for react-core, sha512 checked, in
// $A2UI_THIRDPARTY_SRC/katex@0.16.27/): `renderToString(value,
// {displayMode: block, throwOnError: false, trust: false})` (react-core
// standard/text.tsx:395-417). This file typesets it with flutter_math_fork
// 0.7.4, a Dart port of an older KaTeX, and ports what KaTeX's own source
// decides around the formula: its size and line (dist/katex.css:142-147), its
// display block (:1199-1208), its lines (`\\`) and where an inline formula
// may break (src/buildHTML.js:24-28, :106-117, :334-377), the display
// environments flutter_math_fork lacks and `\tag` (foundation/text/
// katex_source.dart), the error it shows with `throwOnError: false`
// (katex.js:88-105) and the red command name it shows for a command it does
// not know (src/Parser.js:306-332, :841-850) or does not trust
// (src/functions/href.js, html.js, includegraphics.js).

import 'dart:collection';
import 'dart:math' show max;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:a2ui_kit/src/foundation/text/katex_source.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';

/// The size of a formula in em of the surrounding text, 1.21 (`.katex {
/// font: normal 1.21em KaTeX_Main…}`, katex 0.16.27 dist/katex.css:143).
const double katexFontEm = 1.21;

/// The line height of a formula, 1.2 (`.katex { line-height: 1.2 }`,
/// dist/katex.css:144).
const double katexLineHeight = 1.2;

/// The standard `Math`: `value`, TeX, typeset as KaTeX typesets it.
///
/// Inline (the default) it is a formula in the text style, 1.21 times the
/// surrounding size, sitting on the line's baseline, and it may break after
/// a relation or a binary operator at its top level when the line is full
/// (KaTeX's `.base` pieces), never after a minus KaTeX makes ordinary (a
/// leading one, or one after a relation, an operator or an opening); `\\`
/// and `\newline` start a new line. Inside a Text its pieces continue the
/// Text's line and break with it ([mathRuns]). A piece wider than its line
/// scrolls sideways. With `block: true` it is a formula in the display
/// style, each of its lines centred on a line of its own, with a margin of
/// the surrounding size above and below (`.katex-display { margin: 1em 0;
/// text-align: center }`); a display line wider than its box scrolls
/// sideways. `align`, `align*`, `gather`, `gather*`, `gathered`, `split`,
/// `alignat`, `alignat*`, `equation` and `equation*` typeset as KaTeX
/// typesets them in display mode, the unstarred ones numbered at the right
/// edge, where `\tag{…}` puts its own tag.
///
/// A formula KaTeX cannot parse shows as its source, in the surrounding
/// type and KaTeX's error colour (`#cc0000`), with KaTeX's message as its
/// tooltip (the error span's `title`). A command neither KaTeX nor this
/// package knows, or one `trust: false` refuses (`\href`, `\url`,
/// `\includegraphics`, `\htmlClass`, `\htmlId`, `\htmlStyle`, `\htmlData`),
/// shows as its name in the error colour, the rest of the formula typeset.
///
/// Differences from CopilotKit (README, "Differences", Math;
/// port/inventory.tsv INV-100 to INV-103, INV-320):
///
/// - flutter_math_fork 0.7.4 typesets the formula, not KaTeX 0.16.27: a
///   command KaTeX has and neither flutter_math_fork nor this package does
///   shows as an unknown command, its name in KaTeX's red, and such an
///   environment (`CD`) as the whole source in red; `\smash` draws its
///   content at its own height and depth.
/// - KaTeX's fonts are flutter_math_fork's copies of them, not KaTeX
///   0.16.27's files.
/// - Screen readers hear the formula's TeX source, where KaTeX gives them
///   MathML: Flutter's semantics has no MathML.
/// - A display formula, or an inline formula's piece, wider than its line
///   scrolls sideways from its start; KaTeX's overflows its line,
///   start-aligned, into the page's scroll area, which a Flutter scroll
///   view never takes from what a child paints past its box.
/// - The equation numbers of `align`, `gather`, `alignat` and `equation`
///   start at (1) in each formula; KaTeX's count on over the whole page (a
///   CSS counter on `body`, katex.css:1171-1174).
Widget buildMath(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = MathProps(props);
  return KitMath(value: view.value ?? '', block: view.block);
}

/// A TeX formula typeset as KaTeX typesets it: see [buildMath].
class KitMath extends StatelessWidget {
  /// Typesets [value], as a display block when [block] is true.
  const KitMath({
    required this.value,
    this.block = false,
    this.errorColor,
    super.key,
  });

  /// The TeX source.
  final String value;

  /// Whether the formula is a centred display block.
  final bool block;

  /// The colour an error and an unknown command show in: KaTeX's
  /// `errorColor`, its red (`katexErrorColor`) when null.
  final Color? errorColor;

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final inherited = DefaultTextStyle.of(context).style;
    final size = inherited.fontSize ?? theme.typography.fontSize;
    final errorColor =
        this.errorColor ?? theme.color(A2uiColorToken.katexErrorColor);
    // PERF(port): parsed on every build; React memoizes renderToString on
    // (value, block) (text.tsx:401-409): a State keeping the last tree would.
    final parsed = parseKatexFormula(
      value,
      display: block,
      errorColor: errorColor,
    );

    Widget error(String message) =>
        _KatexError(source: value, message: message, color: errorColor);

    final lines = parsed.lines;
    if (lines == null) return error(parsed.error!);
    final style = _katexStyle(inherited, theme);
    final bold = MediaQuery.boldTextOf(context);
    // The formula parsed again, for a measurement of its own ([_measured]).
    KatexFormula reparse() =>
        parseKatexFormula(value, display: block, errorColor: errorColor);
    final Widget formula;
    if (block) {
      formula = _display(context, parsed, reparse, style, size, bold, error);
    } else {
      formula = _inline(lines, reparse, style, bold, error);
    }
    // KaTeX gives screen readers the formula as MathML (`output:
    // "htmlAndMathml"`, the default, src/Settings.js:114-117) and hides its
    // drawing from them (`aria-hidden`, src/buildHTML.js:387). Flutter's
    // semantics has no MathML: the TeX source is the formula's label.
    return Semantics(
      container: true,
      label: value,
      child: ExcludeSemantics(child: formula),
    );
  }

  /// The inline formula: KaTeX's `.base` pieces ([katexPieces]), each
  /// unbroken, in a line that may break between them, on the text's
  /// baseline, each of [lines] starting a line; each line at least a
  /// `.katex` line tall (1.2 of its 1.21em, the strut round each piece).
  Widget _inline(
    List<SyntaxTree> lines,
    KatexFormula Function() reparse,
    TextStyle style,
    bool bold,
    Widget Function(String) error,
  ) {
    // An empty formula holds no text: no line (CSS 2.1 section 9.4.2).
    if (lines.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, line) in lines.indexed) ...[
            if (i > 0) const TextSpan(text: '\n'),
            for (final (j, piece) in katexPieces(line).indexed)
              _pieceSpan(
                _piece(
                  piece,
                  () => katexPieces(reparse().lines![i])[j],
                  style,
                  bold,
                  error,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The display formula: `.katex-display { display: block; margin: 1em 0;
  /// text-align: center }` and its `.katex { white-space: nowrap }`
  /// (katex.css:1199-1208), the em the surrounding text's; each line a
  /// block of its own (`.newline { display: block }`, :171-173); the tags at
  /// the right edge (`.tag { position: absolute; right: 0 }`, :1213-1216).
  Widget _display(
    BuildContext context,
    KatexFormula parsed,
    KatexFormula Function() reparse,
    TextStyle style,
    double size,
    bool bold,
    Widget Function(String) error,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final margin = scaler.scale(size);
    final lines = parsed.lines!;
    // An empty display formula is only its margin: the top and bottom
    // margins of a block with no content collapse into one (CSS 2.1
    // section 8.3.1).
    if (lines.isEmpty) return SizedBox(height: margin);
    // The display formula scales with the text itself (it is no box of a
    // line), so its size is the scaled one.
    final scaled = style.copyWith(fontSize: scaler.scale(style.fontSize!));
    Widget display(SyntaxTree tree, SyntaxTree Function() fresh) =>
        _measured(tree, fresh, scaled, MathStyle.display, bold, error);
    // Centred when it fits; a line too long for its box is start-aligned
    // and overflows its end (CSS Text 3 section 6.1). The overflow grows
    // the nearest scroll container's scrollable area in a browser; a
    // Flutter scroll view's extent comes from its child's layout size, never
    // from what a child paints past it, so the line scrolls on its own.
    // KaTeX's lines are blocks (`.newline`), not a flex box.
    Widget formula = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, line) in lines.indexed)
          Center(
            heightFactor: 1,
            child: display(line, () => reparse().lines![i]),
          ),
      ],
    );
    final tag = parsed.tag;
    if (tag != null) {
      formula = _Tagged(
        children: [formula, display(tag, () => reparse().tag!)],
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: margin),
      child: formula,
    );
  }
}

/// A display formula and its tags: `.tag { position: absolute; right: 0 }`
/// (katex.css:1213-1216), on the formula's baseline (an absolute box's
/// static position on its line), at the line's right edge; the formula
/// sized and centred as if the tags were not there.
class _Tagged extends MultiChildRenderObjectWidget {
  const _Tagged({required super.children});

  @override
  _RenderTagged createRenderObject(BuildContext context) => _RenderTagged();
}

class _RenderTagged extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TaggedParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TaggedParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TaggedParentData) {
      child.parentData = _TaggedParentData();
    }
  }

  RenderBox get _formula => firstChild!;
  RenderBox get _tag => lastChild!;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _formula.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _formula.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _formula.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _formula.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _formula.getDryLayout(constraints);

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline b) =>
      _formula.getDryBaseline(constraints, b);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void performLayout() {
    final formula = _formula..layout(constraints, parentUsesSize: true);
    final tag = _tag
      ..layout(
        BoxConstraints(maxWidth: constraints.maxWidth),
        parentUsesSize: true,
      );
    final formulaBaseline =
        formula.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0;
    final tagBaseline = tag.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0;
    var tagTop = formulaBaseline - tagBaseline;
    var formulaTop = 0.0;
    if (tagTop < 0) {
      formulaTop = -tagTop;
      tagTop = 0;
    }
    (formula.parentData! as _TaggedParentData).offset = Offset(0, formulaTop);
    (tag.parentData! as _TaggedParentData).offset = Offset(
      formula.size.width - tag.size.width,
      tagTop,
    );
    size = constraints.constrain(
      Size(
        formula.size.width,
        max(formulaTop + formula.size.height, tagTop + tag.size.height),
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _TaggedParentData extends ContainerBoxParentData<RenderBox> {}

/// A formula parsed as KaTeX reads it: its `lines` (split at the top-level
/// `\\` and `\newline`, empty ones dropped), its `tag` (the column of its
/// equation numbers and `\tag`s, as tall as its rows), or the `error` KaTeX
/// shows its source with.
typedef KatexFormula = ({
  List<SyntaxTree>? lines,
  SyntaxTree? tag,
  String? error,
});

/// [value] parsed as KaTeX parses it in [display] mode with `throwOnError:
/// false` ([KatexFormula]); see [parseKatex] for a command neither has.
KatexFormula parseKatexFormula(
  String value, {
  required bool display,
  required Color errorColor,
}) {
  final source = katexSource(value, display: display);
  if (source.error != null) {
    return (lines: null, tag: null, error: source.error);
  }
  final lines = <SyntaxTree>[];
  for (final line in katexLines(source.tex)) {
    final parsed = parseKatex(line, errorColor: errorColor);
    final tree = parsed.tree;
    if (tree == null) return (lines: null, tag: null, error: parsed.error);
    if (tree.greenRoot.children.isNotEmpty) lines.add(tree);
  }
  // The tags' column: each row's tag over a phantom of the row, so each
  // sits on its row's baseline (KaTeX gives each tag its row's height and
  // depth, array.js:387-410); a tag of the formula's own on its last line.
  String? tagTex;
  if (source.tags.isNotEmpty) {
    final rows = [
      for (final (i, row) in source.rows.indexed)
        '&\\vphantom{${katexRowContent(row)}}${source.tags[i] ?? ''}',
    ];
    tagTex = '\\begin{aligned}${rows.join(r' \\ ')}\\end{aligned}';
  } else if (source.tag != null && lines.isNotEmpty) {
    final last = katexLines(source.tex).last;
    tagTex = '\\vphantom{$last}${source.tag}';
  }
  final tag = tagTex == null
      ? null
      : parseKatex(tagTex, errorColor: errorColor).tree;
  return (lines: lines, tag: tag, error: null);
}

/// The pieces an inline formula gives the line of the Text holding it: its
/// `.katex` span is inline in the Text's `<span>` (text.tsx:410-415), so
/// KaTeX's `.base` pieces continue the Text's line and break with it, each
/// unbroken, each line holding one at least a `.katex` line tall; its
/// `\\` starts a new line. Null for a display formula and for one KaTeX
/// shows as an error span: either is one box of the line ([KitMath]).
List<InlineRun>? mathRuns(
  BuildContext context,
  ComponentProps props,
  TextStyle inherited,
) {
  final view = MathProps(props);
  if (view.block) return null;
  final theme = A2uiKitScope.themeOf(context);
  final value = view.value ?? '';
  final errorColor = theme.color(A2uiColorToken.katexErrorColor);
  KatexFormula parse() =>
      parseKatexFormula(value, display: false, errorColor: errorColor);
  final lines = parse().lines;
  if (lines == null) return null;
  // An empty formula holds no text: nothing on the line.
  if (lines.isEmpty) return const [];
  final style = _katexStyle(inherited, theme);
  final bold = MediaQuery.boldTextOf(context);
  Widget error(String message) =>
      _KatexError(source: value, message: message, color: errorColor);
  final runs = <InlineRun>[];
  for (final (i, line) in lines.indexed) {
    if (i > 0) runs.add(const InlineBreak());
    for (final (j, piece) in katexPieces(line).indexed) {
      final drawn = _piece(
        piece,
        () => katexPieces(parse().lines![i])[j],
        style,
        bold,
        error,
      );
      runs.add(
        InlineAtom(_pieceSpan(_labelled(runs.isEmpty ? value : null, drawn))),
      );
    }
  }
  return runs;
}

/// [piece] as screen readers get a formula: its first piece is the
/// formula's node, labelled with its TeX ([label]), as [KitMath] is; the
/// glyphs give nothing.
Widget _labelled(String? label, Widget piece) => label == null
    ? ExcludeSemantics(child: piece)
    : Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: piece),
      );

/// The text style of a formula in the [inherited] type: `font: normal
/// 1.21em KaTeX_Main` (katex.css:143), never bold or italic for the text
/// around it, only coloured like it.
TextStyle _katexStyle(TextStyle inherited, A2uiKitTheme theme) => TextStyle(
  fontSize: (inherited.fontSize ?? theme.typography.fontSize) * katexFontEm,
  color: inherited.color ?? theme.color(A2uiColorToken.textDefault),
  fontWeight: FontWeight.normal,
  fontStyle: FontStyle.normal,
);

/// The `.katex` span's own line at [fontSize], its strut: 1.2 of the
/// font size in KaTeX_Main (katex.css:143-144), its leading split evenly
/// above and below the font's ascent and descent (CSS 2.1 section 10.8.1),
/// as the extents above and below the baseline that a line holding a piece
/// of the formula takes at least. A box round each piece gives them, so the
/// line takes the taller of these and its own on each side of the
/// baseline, as CSS does; a paragraph's `strutStyle` would not, since
/// SkParagraph lays a strut and a run with a height of its own out taller
/// than both (a 16px line of 1.4 and a 23.2px strut make 30px, observed
/// with Flutter 3.47.9).
(double, double) _katexStrutExtents(double fontSize) {
  final known = _strutExtents[fontSize];
  if (known != null) return known;
  final painter = TextPainter(
    text: TextSpan(
      text: 'x',
      style: TextStyle(
        fontFamily: 'KaTeX_Main',
        package: 'flutter_math_fork',
        fontSize: fontSize,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final metrics = painter.computeLineMetrics().first;
  painter.dispose();
  final half =
      (fontSize * katexLineHeight - metrics.ascent - metrics.descent) / 2;
  return _strutExtents[fontSize] = (
    metrics.ascent + half,
    metrics.descent + half,
  );
}

/// The struts measured so far, by font size.
final Map<double, (double, double)> _strutExtents = {};

/// [child] as a piece of a line, on its baseline.
WidgetSpan _pieceSpan(Widget child) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: child,
);

/// One piece of an inline formula, unbroken, in [style], with the `.katex`
/// strut ([_katexStrutExtents]). The line scales its pieces by the text
/// scale, so they don't scale again (textScaleFactor 1).
Widget _piece(
  SyntaxTree piece,
  SyntaxTree Function() fresh,
  TextStyle style,
  bool bold,
  Widget Function(String) error,
) => _measured(piece, fresh, style, MathStyle.text, bold, error, strut: true);

/// [tree] typeset in [mathStyle] and [style], unscaled, in a box that
/// scrolls sideways when it is wider than its line (KaTeX's `.base` is an
/// inline-block that keeps its whole width, katex.css:174-180, and a
/// display line keeps its own, :1204-1208), and that answers its size and
/// baseline without the parent laying it out ([_RenderMeasuredMath]),
/// measuring [fresh], the same formula parsed again: flutter_math_fork
/// keeps a node's last widgets, which hold GlobalKeys (syntax_tree.dart:
/// 173-175, :547) that a second tree of the same nodes would take from
/// this one.
Widget _measured(
  SyntaxTree tree,
  SyntaxTree Function() fresh,
  TextStyle style,
  MathStyle mathStyle,
  bool bold,
  Widget Function(String) error, {
  bool strut = false,
}) {
  String? key;
  try {
    key =
        '${mathStyle.name}|${style.fontSize}|$bold|'
        '${tree.greenRoot.encodeTeX()}';
  } on Object {
    key = null;
  }
  return _MeasuredMath(
    measureKey: key,
    strutSize: strut ? style.fontSize : null,
    measure: () => _measure(
      // The fallback a piece shows when it fails to build, without its
      // tooltip, which needs an overlay: the same text and size.
      DefaultTextStyle(
        style: style,
        child: Math(
          ast: fresh(),
          mathStyle: mathStyle,
          textStyle: style,
          textScaleFactor: 1,
          onErrorFallback: (e) => Text(e.message),
        ),
      ),
      bold: bold,
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _BaselineProbe(
        child: Math(
          ast: tree,
          mathStyle: mathStyle,
          textStyle: style,
          textScaleFactor: 1,
          onErrorFallback: (e) => error(e.message),
        ),
      ),
    ),
  );
}

/// The size and alphabetic baseline of a formula laid out alone, with no
/// width limit.
typedef _MathMetrics = ({Size size, double baseline});

/// The metrics measured so far, by formula, the latest last.
// PERF(port): one off-screen build and layout per formula not yet in it.
final LinkedHashMap<String, _MathMetrics> _measuredMetrics = LinkedHashMap();

/// How many formulas [_measuredMetrics] keeps.
const int _measuredLimit = 256;

/// The focus manager of the off-screen trees, which never take focus.
final FocusManager _measureFocus = FocusManager();

/// [math] laid out alone in an off-screen tree, with no width limit: its
/// size and baseline. flutter_math_fork 0.7.4's render objects can't answer
/// a parent's measuring: `RenderLine` has no dry baseline and leaves the
/// glue round relations and operators out of its intrinsic width
/// (line.dart:232-245, added only in layout at :395), a root reports none
/// (sqrt.dart:156-163), and an accent's or a `\left…\right`'s
/// `LayoutBuilder` throws on intrinsic queries (accent.dart:82, :97,
/// left_right.dart:64). A real layout gives what the browser measures.
_MathMetrics _measure(Widget math, {required bool bold}) {
  final root = _MeasureRoot();
  final pipeline = PipelineOwner()..rootNode = root;
  final owner = BuildOwner(focusManager: _measureFocus);
  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: root,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(boldText: bold),
        child: math,
      ),
    ),
  ).attachToRenderTree(owner);
  try {
    root.scheduleInitialLayout();
    pipeline.flushLayout();
    return (size: root.size, baseline: root.baseline ?? root.size.height);
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(
      container: root,
    ).attachToRenderTree(owner, element);
    owner
      ..buildScope(element)
      ..finalizeTree();
    pipeline
      ..rootNode = null
      ..dispose();
  }
}

/// The root of an off-screen tree: lays its child out with no width limit
/// and keeps its size and baseline.
class _MeasureRoot extends RenderObject
    with RenderObjectWithChildMixin<RenderBox> {
  Size size = Size.zero;
  double? baseline;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    child.layout(const BoxConstraints(), parentUsesSize: true);
    size = child.size;
    baseline = child.getDistanceToBaseline(TextBaseline.alphabetic);
  }

  @override
  void performResize() {}

  @override
  void debugAssertDoesMeetConstraints() {}

  @override
  Rect get paintBounds => Offset.zero & size;

  @override
  Rect get semanticBounds => paintBounds;
}

/// A formula's box: its size and baseline for a parent that measures it
/// (intrinsic widths, a dry layout or baseline) come from [measure], since
/// flutter_math_fork's can't answer; laid out, its child's own. With a
/// [strutSize] it is at least the `.katex` strut of that font size tall on
/// each side of its baseline ([_katexStrutExtents]).
class _MeasuredMath extends SingleChildRenderObjectWidget {
  const _MeasuredMath({
    required this.measureKey,
    required this.measure,
    required this.strutSize,
    required super.child,
  });

  /// What the measurement depends on; null when it can't be told, and
  /// then it is not kept.
  final String? measureKey;

  /// Measures the formula.
  final _MathMetrics Function() measure;

  /// The font size of the `.katex` strut round the formula, or null for
  /// none.
  final double? strutSize;

  @override
  _RenderMeasuredMath createRenderObject(BuildContext context) =>
      _RenderMeasuredMath(measureKey, measure, strutSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredMath renderObject,
  ) => renderObject.update(measureKey, measure, strutSize);
}

class _RenderMeasuredMath extends RenderShiftedBox
    with RelayoutWhenSystemFontsChangeMixin {
  _RenderMeasuredMath(this._key, this._measure, this._strutSize) : super(null);

  String? _key;
  _MathMetrics Function() _measure;
  _MathMetrics? _metrics;
  double? _strutSize;

  void update(String? key, _MathMetrics Function() measure, double? strutSize) {
    _measure = measure;
    if (strutSize != _strutSize) {
      _strutSize = strutSize;
      markNeedsLayout();
    }
    if (key == _key && key != null) return;
    _key = key;
    _metrics = null;
    markNeedsLayout();
  }

  /// The strut's extents above and below the baseline, or none.
  (double, double) get _strut {
    final size = _strutSize;
    return size == null ? (0, 0) : _katexStrutExtents(size);
  }

  /// The box of a formula [size] tall with its baseline at [baseline],
  /// with the strut round it: its height, its baseline, and the formula's
  /// top.
  ({double height, double baseline, double top}) _withStrut(
    double height,
    double baseline,
  ) {
    final (above, below) = _strut;
    final top = above > baseline ? above - baseline : 0.0;
    final bottom = below > height - baseline
        ? below - (height - baseline)
        : 0.0;
    return (height: top + height + bottom, baseline: top + baseline, top: top);
  }

  _MathMetrics get _strutted {
    final measured = _measured;
    final box = _withStrut(measured.size.height, measured.baseline);
    return (
      size: Size(measured.size.width, box.height),
      baseline: box.baseline,
    );
  }

  /// The formula's own baseline, laid out: the scroll view between gives
  /// none, so the probe inside it keeps the formula's, the scroll view's
  /// top being the formula's.
  double _childBaseline() =>
      _probeIn(child)?.lastBaseline ?? _measured.baseline;

  double? _baseline;

  @override
  void performLayout() {
    final child = this.child!
      ..layout(constraints.loosen(), parentUsesSize: true);
    final box = _withStrut(child.size.height, _childBaseline());
    (child.parentData! as BoxParentData).offset = Offset(0, box.top);
    _baseline = box.baseline;
    size = constraints.constrain(Size(child.size.width, box.height));
  }

  _MathMetrics get _measured {
    final known = _metrics;
    if (known != null) return known;
    final key = _key;
    if (key != null) {
      final cached = _measuredMetrics.remove(key);
      if (cached != null) {
        _measuredMetrics[key] = cached;
        return _metrics = cached;
      }
    }
    final measured = _measure();
    if (key != null) {
      _measuredMetrics[key] = measured;
      while (_measuredMetrics.length > _measuredLimit) {
        _measuredMetrics.remove(_measuredMetrics.keys.first);
      }
    }
    return _metrics = measured;
  }

  @override
  void systemFontsDidChange() {
    // A font that arrives late changes every measured formula and strut.
    _measuredMetrics.clear();
    _strutExtents.clear();
    _metrics = null;
    super.systemFontsDidChange();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _strutted.size.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _strutted.size.width;

  @override
  double computeMinIntrinsicHeight(double width) => _strutted.size.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _strutted.size.height;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_strutted.size);

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline _) =>
      _strutted.baseline;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  static _RenderBaselineProbe? _probeIn(RenderObject? object) {
    _RenderBaselineProbe? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is _RenderBaselineProbe) {
        found = child;
      } else {
        child.visitChildren(visit);
      }
    }

    if (object != null) visit(object);
    return found;
  }
}

/// Keeps its child's baseline from its last layout.
class _BaselineProbe extends SingleChildRenderObjectWidget {
  const _BaselineProbe({required super.child});

  @override
  _RenderBaselineProbe createRenderObject(BuildContext context) =>
      _RenderBaselineProbe();
}

class _RenderBaselineProbe extends RenderProxyBox {
  double? lastBaseline;

  @override
  void performLayout() {
    super.performLayout();
    lastBaseline = child?.getDistanceToBaseline(
      TextBaseline.alphabetic,
      onlyReal: true,
    );
  }
}

/// The class KaTeX gives an atom for its bin cancellation
/// (buildHTML.js:24-28): [AtomType.bin] stays a bin only between atoms
/// that leave it one.
const Set<AtomType> _binLeftCancellers = {
  AtomType.bin,
  AtomType.open,
  AtomType.rel,
  AtomType.op,
  AtomType.punct,
};

const Set<AtomType> _binRightCancellers = {
  AtomType.rel,
  AtomType.close,
  AtomType.punct,
};

/// KaTeX's `.base` pieces of an inline formula's line [tree]: one after
/// each top-level relation, binary operator or `\allowbreak`, with the
/// glue after it, unless that glue holds a `\nobreak`
/// (src/buildHTML.js:334-377). A binary operator KaTeX makes ordinary
/// first, at the line's start or after a relation, an opening, an
/// operator, punctuation or another binary operator, or before a relation,
/// a closing or punctuation (bin cancellation, buildHTML.js:24-28,
/// :106-117), is no place to break: `-1.6` keeps its minus.
///
/// KaTeX spaces the whole formula, then splits it, each piece keeping the
/// glue after its operator (buildHTML.js:334-363). A piece typeset alone
/// ends with its operator, so it would lose that glue, and a binary
/// operator at a list's end turns ordinary, losing the space before it too
/// (buildHTML.js:27-28, :106-117). An empty group after the operator, an
/// ordinary atom of no width, gives the piece both spaces, as the atom
/// after it in the whole formula does.
List<SyntaxTree> katexPieces(SyntaxTree tree) {
  final row = tree.greenRoot;
  final children = row.flattenedChildList;
  // Which of them may end a piece: not those inside a font group
  // (`\mathrm{…}`, `\text{…}`), which KaTeX builds as one atom
  // (src/functions/font.js, text.js: `buildGroup` of the body), where a
  // style or colour switch (`\displaystyle`, `\color`) leaves its atoms on
  // the top level (styling.js, color.js: `buildExpression`). The order is
  // `flattenedChildList`'s.
  final breakable = <bool>[];
  void walk(List<GreenNode?> nodes, {required bool inFont}) {
    for (final node in nodes) {
      if (node == null) continue;
      if (node is TransparentNode) {
        final font =
            node is StyleNode &&
            (node.optionsDiff.mathFontOptions != null ||
                node.optionsDiff.textFontOptions != null);
        walk(node.children, inFont: inFont || font);
      } else {
        breakable.add(!inFont);
      }
    }
  }

  walk(row.children, inFont: false);
  assert(breakable.length == children.length, 'one flag per atom');
  // Bin cancellation over the atoms, spaces skipped.
  final cancelled = List.filled(children.length, false);
  AtomType? previous; // null: the leftmost edge
  var previousIndex = -1;
  for (var i = 0; i <= children.length; i++) {
    if (i < children.length && children[i] is SpaceNode) continue;
    final type = i == children.length ? null : children[i].leftType;
    final previousIsBin = previousIndex >= 0 && previous == AtomType.bin;
    if (previousIsBin && (type == null || _binRightCancellers.contains(type))) {
      cancelled[previousIndex] = true;
    } else if (type == AtomType.bin &&
        (previous == null || _binLeftCancellers.contains(previous))) {
      cancelled[i] = true;
    }
    if (i == children.length) break;
    previous = cancelled[i] ? AtomType.ord : children[i].rightType;
    previousIndex = i;
  }
  final breaks = <int>[];
  for (var i = 0; i < children.length; i++) {
    final child = children[i];
    if (!breakable[i]) continue;
    final breaksAfter = switch (child) {
      SpaceNode(:final breakPenalty?) => breakPenalty < 10000,
      SpaceNode() => false,
      _ =>
        (child.rightType == AtomType.bin && !cancelled[i]) ||
            child.rightType == AtomType.rel,
    };
    if (!breaksAfter) continue;
    // The glue after it stays with it; a `\nobreak` in it keeps the line
    // whole there.
    var end = i;
    var nobreak = false;
    while (end + 1 < children.length && children[end + 1] is SpaceNode) {
      end += 1;
      final penalty = (children[end] as SpaceNode).breakPenalty;
      if (penalty != null && penalty >= 10000) nobreak = true;
    }
    if (!nobreak && end + 1 < children.length) breaks.add(end);
    i = end;
  }
  final caret = row.caretPositions;
  final parts = <EquationRowNode>[];
  var position = caret.first;
  for (final at in breaks) {
    final end = caret[at + 1];
    parts.add(row.clipChildrenBetween(position, end).wrapWithEquationRow());
    position = end;
  }
  parts.add(
    row.clipChildrenBetween(position, caret.last).wrapWithEquationRow(),
  );
  return [
    for (var i = 0; i < parts.length; i++)
      SyntaxTree(
        greenRoot: i + 1 == parts.length
            ? parts[i]
            : EquationRowNode(
                children: [...parts[i].children, EquationRowNode.empty()],
              ),
      ),
  ];
}

/// KaTeX's error span (`katex.js:88-105`): the source as text, in the
/// surrounding type and [color], white space collapsed, with KaTeX's message
/// as its `title`.
class _KatexError extends StatelessWidget {
  const _KatexError({
    required this.source,
    required this.message,
    required this.color,
  });

  final String source;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    // `error.toString()` of a ParseError: its name, then KaTeX's message
    // (src/ParseError.js:28, :70-71), which flutter_math_fork's parser
    // writes the same way.
    message: 'ParseError: KaTeX parse error: $message',
    child: Text(
      collapseInlineWhitespace(source, block: !isInlineInText(context)),
      style: TextStyle(color: color),
    ),
  );
}

/// The commands KaTeX 0.16.27 defines and flutter_math_fork 0.7.4 lacks
/// that a tutor's formulas use, as KaTeX defines them: `\AA` is `\r A`
/// (src/macros.js:239), a ring over A, upright in text; `\degree` a degree
/// sign in math mode too (src/symbols.js:738-740); `\emph` italic text
/// (src/functions/text.js:33-50); `\smash` its content (src/functions/
/// smash.js), here at its own height and depth.
final Map<String, MacroDefinition> katexMacros = {
  r'\AA': MacroDefinition.fromCtxString(
    (context) => context.mode == Mode.math ? r'\mathring{A}' : 'Å',
  ),
  r'\degree': MacroDefinition.fromCtxString(
    (context) => context.mode == Mode.math ? r'\text{°}' : '°',
  ),
  r'\emph': MacroDefinition.fromString(r'\textit{#1}'),
  r'\smash': MacroDefinition.fromCtxString((context) {
    // The optional `[t]` or `[b]`.
    context.consumeSpaces();
    if (context.future().text == '[') {
      while (context.popToken().text != ']') {
        if (context.future().text == 'EOF') break;
      }
    }
    return '{#1}';
  }),
};

/// The commands KaTeX refuses with `trust: false`, with their optional and
/// required argument counts: KaTeX parses their arguments, then shows only
/// the command's name in the error colour (`formatUnsupportedCmd`;
/// src/functions/href.js:12-26, :52-65; html.js:12-77;
/// includegraphics.js:36-92).
const Map<String, (int, int)> katexUntrustedCommands = {
  r'\href': (0, 2),
  r'\url': (0, 1),
  r'\includegraphics': (1, 1),
  r'\htmlClass': (0, 2),
  r'\htmlId': (0, 2),
  r'\htmlStyle': (0, 2),
  r'\htmlData': (0, 2),
};

/// How many commands [parseKatex] stands in for before it gives up.
const int _maxStandIns = 64;

/// [value] parsed as KaTeX parses it with `throwOnError: false`: the tree to
/// typeset, or the error message KaTeX shows the source with.
///
/// A command the parser does not know (`Undefined control sequence`) or
/// one KaTeX does not trust ([katexUntrustedCommands], with its arguments)
/// is replaced by its name in [errorColor] (`\textcolor{…}{\text{…}}`, one
/// atom), as KaTeX's `formatUnsupportedCmd` makes a color node of a text
/// node of the name's characters (src/Parser.js:306-332). One found inside
/// a macro's expansion, which is not the source, fails the whole formula.
/// The commands of [katexMacros] are KaTeX's.
({SyntaxTree? tree, String? error}) parseKatex(
  String value, {
  required Color errorColor,
}) {
  var tex = _standInUntrusted(value, errorColor);
  final settings = TexParserSettings(macros: katexMacros);
  for (var i = 0; i <= _maxStandIns; i++) {
    try {
      return (
        tree: SyntaxTree(greenRoot: TexParser(tex, settings).parse()),
        error: null,
      );
    } on ParseException catch (e) {
      final next = _standInUndefined(tex, e, errorColor);
      if (next == null) return (tree: null, error: e.message);
      tex = next;
    } on Object catch (e) {
      // KaTeX throws only its ParseError here; anything else is
      // flutter_math_fork's own failure, shown as an invalid formula.
      return (tree: null, error: '$e');
    }
  }
  return (tree: null, error: 'Too many unsupported commands');
}

/// The TeX that typesets [name] as KaTeX's `formatUnsupportedCmd` does: one
/// atom, so it may stand where an argument goes (`x^\foo`).
String _standIn(String name, Color color) {
  final rgb = (color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0');
  return '{\\textcolor{#$rgb}{\\text{\\textbackslash{}${name.substring(1)}}}}';
}

final RegExp _controlWord = RegExp(r'^\\[A-Za-z@]+$');

/// [tex] with the undefined command [error] names replaced, or null when
/// the error is another one or not at a command of the source.
String? _standInUndefined(String tex, ParseException error, Color color) {
  const undefined = 'Undefined control sequence: ';
  if (!error.message.startsWith(undefined)) return null;
  final start = error.position;
  final name = error.token?.text;
  if (start == null || name == null || !_controlWord.hasMatch(name)) {
    return null;
  }
  if (!tex.startsWith(name, start)) return null;
  return tex.replaceRange(start, start + name.length, _standIn(name, color));
}

/// [tex] with each command of [katexUntrustedCommands] and its arguments
/// replaced by the command's name in [color]. A command whose arguments do
/// not close is left for the parser to fail on.
String _standInUntrusted(String tex, Color color) {
  if (!tex.contains(r'\')) return tex;
  final out = StringBuffer();
  var i = 0;
  while (i < tex.length) {
    if (tex[i] != r'\') {
      out.write(tex[i]);
      i += 1;
      continue;
    }
    final word = RegExp(r'\\(?:[A-Za-z@]+|.)').matchAsPrefix(tex, i);
    final name = word?.group(0) ?? r'\';
    final arguments = katexUntrustedCommands[name];
    final end = arguments == null
        ? null
        : _skipArguments(tex, i + name.length, arguments.$1, arguments.$2);
    if (end == null) {
      out.write(name);
      i += name.length;
      continue;
    }
    out.write(_standIn(name, color));
    i = end;
  }
  return out.toString();
}

/// The index after [optional] bracketed and [required] arguments read from
/// [start] of [tex], or null when one does not close.
int? _skipArguments(String tex, int start, int optional, int required) {
  var i = start;
  int skipSpaces(int at) {
    var j = at;
    while (j < tex.length && ' \t\n\r'.contains(tex[j])) {
      j += 1;
    }
    return j;
  }

  for (var n = 0; n < optional; n++) {
    final at = skipSpaces(i);
    if (at < tex.length && tex[at] == '[') {
      final close = _closing(tex, at, '[', ']');
      if (close == null) return null;
      i = close + 1;
    }
  }
  for (var n = 0; n < required; n++) {
    final at = skipSpaces(i);
    if (at >= tex.length) return null;
    if (tex[at] == '{') {
      final close = _closing(tex, at, '{', '}');
      if (close == null) return null;
      i = close + 1;
    } else {
      final word = RegExp(r'\\(?:[A-Za-z@]+|.)').matchAsPrefix(tex, at);
      i = at + (word?.group(0)?.length ?? 1);
    }
  }
  return i;
}

/// The index of the [close] matching the [open] at [at], skipping escaped
/// characters and nested pairs; null when there is none.
int? _closing(String tex, int at, String open, String close) {
  var depth = 0;
  for (var i = at; i < tex.length; i++) {
    final c = tex[i];
    if (c == r'\') {
      i += 1;
    } else if (c == open) {
      depth += 1;
    } else if (c == close) {
      depth -= 1;
      if (depth == 0) return i;
    }
  }
  return null;
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
