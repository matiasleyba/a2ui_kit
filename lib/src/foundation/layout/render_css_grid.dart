import 'dart:math' as math;

import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The `grid-template-columns` of a [CssGrid].
@immutable
sealed class GridColumns {
  const GridColumns();

  /// CopilotKit's numeric `columns`: `repeat(auto-fit, minmax(min(100%,
  /// max(minTrack, (100% - (count - 1) × gap) / count)), 1fr))`. At most
  /// [count] columns, fewer when a column would be narrower than
  /// [minTrack]; columns no child reaches collapse.
  const factory GridColumns.autoFit({
    required int count,
    required double minTrack,
  }) = AutoFitColumns;

  /// `repeat(auto-fill, minmax(min(100%, minTrack), 1fr))`: as many
  /// columns of at least [minTrack] as fit, empty ones kept.
  const factory GridColumns.autoFill({required double minTrack}) =
      AutoFillColumns;

  /// Explicit tracks, each a [GridTrack].
  const factory GridColumns.tracks(List<GridTrack> tracks) = TrackColumns;

  /// The column widths for an inner width of [width] and a column gap of
  /// [gap], before empty auto-fit columns collapse.
  List<double> widths(double width, double gap);

  /// The minimum of an auto-repeated track (its `minmax(T, 1fr)`'s T) at
  /// an inner width of [width] and a column gap of [gap]; 0 for explicit
  /// tracks.
  double trackMinimum(double width, double gap) => 0;
}

/// [GridColumns.autoFit].
final class AutoFitColumns extends GridColumns {
  /// At most [count] columns of at least [minTrack] pixels.
  const AutoFitColumns({required this.count, required this.minTrack});

  /// The most columns.
  final int count;

  /// The narrowest column, in pixels, before the count drops.
  final double minTrack;

  @override
  List<double> widths(double width, double gap) {
    if (count <= 1) return [width];
    final track = trackMinimum(width, gap);
    final fit = ((width + gap) / (track + gap)).floor().clamp(1, count);
    return _equal(width, gap, fit);
  }

  @override
  double trackMinimum(double width, double gap) => count <= 1
      ? width
      : math.min(
          width,
          math.max(minTrack, (width - (count - 1) * gap) / count),
        );

  @override
  bool operator ==(Object other) =>
      other is AutoFitColumns &&
      other.count == count &&
      other.minTrack == minTrack;

  @override
  int get hashCode => Object.hash(count, minTrack);
}

/// [GridColumns.autoFill].
final class AutoFillColumns extends GridColumns {
  /// As many columns of at least [minTrack] pixels as fit.
  const AutoFillColumns({required this.minTrack});

  /// The narrowest column, in pixels.
  final double minTrack;

  @override
  double trackMinimum(double width, double gap) => math.min(width, minTrack);

  @override
  List<double> widths(double width, double gap) {
    final track = math.min(width, minTrack);
    final fit = track + gap <= 0
        ? 1
        : math.max(1, ((width + gap) / (track + gap)).floor());
    return _equal(width, gap, fit);
  }

  @override
  bool operator ==(Object other) =>
      other is AutoFillColumns && other.minTrack == minTrack;

  @override
  int get hashCode => minTrack.hashCode;
}

/// [GridColumns.tracks].
final class TrackColumns extends GridColumns {
  /// Explicit [tracks].
  const TrackColumns(this.tracks);

  /// The tracks, left to right.
  final List<GridTrack> tracks;

  /// The track sizes with no items placed: a content-sized track holds
  /// nothing, so it is 0 wide unless an `auto` track stretches.
  @override
  List<double> widths(double width, double gap) {
    if (tracks.isEmpty) return [width];
    return _sizeTracks(tracks, gap, const [], available: width);
  }

  @override
  bool operator ==(Object other) =>
      other is TrackColumns && listEquals(other.tracks, tracks);

  @override
  int get hashCode => Object.hashAll(tracks);
}

/// The content keyword that sizes a [GridTrack].
enum GridTrackContent {
  /// `auto` (`minmax(auto, auto)`): from its items' widest min-content, it
  /// grows towards their widest max-content while there is room, and
  /// shares the free space no `fr` track takes.
  auto,

  /// `min-content`: as wide as its items' widest min-content.
  minContent,

  /// `max-content`: as wide as its items' widest max-content.
  maxContent,
}

/// One explicit grid column, sized as CSS Grid Level 1 section 11 sizes a
/// track (inferred from the spec's text: no local copy).
@immutable
class GridTrack {
  /// A fixed track of [pixels] (`200px`); with a [fraction], a flexible
  /// track `minmax(<pixels>px, <fraction>fr)`: `GridTrack(fraction: 1)` is
  /// `minmax(0, 1fr)`, which is TanStack's track and CopilotKit's one-column
  /// Grid. It is not CSS's bare `1fr`, which is `minmax(auto, 1fr)`: a
  /// flexible track here never widens to its items' min-content.
  const GridTrack({this.pixels = 0, this.fraction = 0}) : content = null;

  /// CSS's `auto` track ([GridTrackContent.auto]).
  const GridTrack.auto()
    : pixels = 0,
      fraction = 0,
      content = GridTrackContent.auto;

  /// CSS's `min-content` track ([GridTrackContent.minContent]).
  const GridTrack.minContent()
    : pixels = 0,
      fraction = 0,
      content = GridTrackContent.minContent;

  /// CSS's `max-content` track ([GridTrackContent.maxContent]).
  const GridTrack.maxContent()
    : pixels = 0,
      fraction = 0,
      content = GridTrackContent.maxContent;

  /// The fixed width, or a flexible track's minimum.
  final double pixels;

  /// The `fr` flex factor; 0 for a fixed track.
  final double fraction;

  /// The keyword that sizes the track by its content; null for a fixed or
  /// flexible track.
  final GridTrackContent? content;

  /// Whether the track is CSS's `auto`.
  bool get auto => content == GridTrackContent.auto;

  /// Whether the track is flexible (an `fr` track).
  bool get flexible => content == null && fraction > 0;

  @override
  bool operator ==(Object other) =>
      other is GridTrack &&
      other.pixels == pixels &&
      other.fraction == fraction &&
      other.content == content;

  @override
  int get hashCode => Object.hash(pixels, fraction, content);
}

/// The widths of explicit [tracks] with a column [gap], after the track
/// sizing algorithm of CSS Grid Level 1, sections 11.3 to 11.8 (inferred
/// from the spec's text: no local copy), for the columns.
///
/// With [available] (the grid's inner width) the free space is definite.
/// Without it the grid is sized under a max-content constraint, or under a
/// min-content one when [minContent] is true (its intrinsic widths).
///
/// [cells] are the placed items. An item's min-content and max-content
/// contributions are its child's min and max intrinsic widths; its minimum
/// contribution (an `auto` minimum's) is taken as its min-content, as
/// Flutter children carry no CSS `min-width`.
List<double> _sizeTracks(
  List<GridTrack> tracks,
  double gap,
  List<_Cell> cells, {
  double? available,
  bool minContent = false,
}) {
  final n = tracks.length;
  final gaps = gap * (n - 1);
  // §11.4 Initialize track sizes: a fixed minimum is the base size and an
  // intrinsic one 0; a fixed maximum is the growth limit, an intrinsic or
  // flexible one infinite (null here) until set.
  final base = [for (final track in tracks) track.pixels];
  final limit = <double?>[
    for (final track in tracks)
      if (track.content != null || track.fraction > 0) null else track.pixels,
  ];
  // §11.5 step 2, size tracks to fit non-spanning items: each content-sized
  // track from the span-1 items in it. (Step 1, baselines, does not apply.)
  for (final cell in cells) {
    if (cell.span != 1) continue;
    final i = cell.column;
    final content = tracks[i].content;
    if (content == null) continue;
    final min = cell.child.getMinIntrinsicWidth(double.infinity);
    final max = cell.child.getMaxIntrinsicWidth(double.infinity);
    // An `auto` minimum takes the items' minimum contributions (their
    // limited min-content ones under an intrinsic constraint: the same
    // here); an `auto` maximum is a max-content one.
    final (atLeast, atMost) = switch (content) {
      GridTrackContent.auto => (min, max),
      GridTrackContent.minContent => (min, min),
      GridTrackContent.maxContent => (max, max),
    };
    // A content-sized track's base starts at 0, so the base size is
    // floored at zero.
    base[i] = math.max(base[i], atLeast);
    final known = limit[i];
    limit[i] = known == null ? atMost : math.max(known, atMost);
  }
  // TODO(port): items spanning several tracks don't grow the content-sized
  // tracks they cross (CSS Grid L1 §11.5 step 3, inferred); only span-1
  // items size a track. (Step 4 needs a flexible track with an intrinsic
  // minimum, which GridTrack has not.)
  // §11.5 step 5: an infinite growth limit (no item, or flexible) becomes
  // the base size; a growth limit is never below the base size.
  final grown = <double>[
    for (var i = 0; i < n; i++) math.max(base[i], limit[i] ?? base[i]),
  ];
  // §11.6 Maximize tracks: positive free space goes equally to the base
  // sizes, each track freezing at its growth limit. Under a max-content
  // constraint the free space is infinite, under a min-content one zero.
  if (available == null) {
    if (!minContent) base.setAll(0, grown);
  } else {
    var free = available - gaps - base.fold<double>(0, (a, b) => a + b);
    var growing = [
      for (var i = 0; i < n; i++)
        if (grown[i] > base[i]) i,
    ];
    while (free > 0 && growing.isNotEmpty) {
      final share = free / growing.length;
      final room = growing.map((i) => grown[i] - base[i]).reduce(math.min);
      if (share <= room) {
        for (final i in growing) {
          base[i] += share;
        }
        break;
      }
      for (final i in growing) {
        base[i] = grown[i] - base[i] <= room ? grown[i] : base[i] + room;
      }
      free -= room * growing.length;
      growing = [
        for (final i in growing)
          if (grown[i] > base[i]) i,
      ];
    }
  }
  // §11.7 Expand flexible tracks by the used flex fraction.
  final flexible = [
    for (var i = 0; i < n; i++)
      if (tracks[i].flexible) i,
  ];
  if (flexible.isNotEmpty && !(available == null && minContent)) {
    double fraction;
    if (available != null) {
      // Definite: the free space (floored at 0) is zero, or the size of an
      // fr over every track, filling the available space.
      final free = available - gaps - base.fold<double>(0, (a, b) => a + b);
      final all = [for (var i = 0; i < n; i++) i];
      fraction = free <= 0 ? 0 : _frSize(tracks, base, all, available, gap);
    } else {
      // Indefinite: each flexible track's base size per fr (divided by a
      // factor over 1), and for each item crossing a flexible track, the
      // size of an fr over its tracks that fills its max-content.
      fraction = 0;
      for (final i in flexible) {
        final factor = tracks[i].fraction;
        final perFr = factor > 1 ? base[i] / factor : base[i];
        fraction = math.max(fraction, perFr);
      }
      for (final cell in cells) {
        final crossed = [
          for (var i = cell.column; i < cell.column + cell.span; i++) i,
        ];
        if (!crossed.any((i) => tracks[i].flexible)) continue;
        final contribution = cell.child.getMaxIntrinsicWidth(double.infinity);
        final size = _frSize(tracks, base, crossed, contribution, gap);
        fraction = math.max(fraction, size);
      }
    }
    for (final i in flexible) {
      base[i] = math.max(base[i], fraction * tracks[i].fraction);
    }
  }
  // §11.8 Stretch auto tracks: positive definite free space left (none
  // when an `fr` track took it) is shared equally by the `auto` tracks.
  if (available != null) {
    final free = available - gaps - base.fold<double>(0, (a, b) => a + b);
    final autos = [
      for (var i = 0; i < n; i++)
        if (tracks[i].auto) i,
    ];
    if (free > 0 && autos.isNotEmpty) {
      for (final i in autos) {
        base[i] += free / autos.length;
      }
    }
  }
  return base;
}

/// The size of an fr (CSS Grid L1 §11.7.1, inferred) over the adjacent
/// tracks [range] of [tracks], whose base sizes are [base], filling
/// [space], the [gap]s between them included (a gutter is a fixed track):
/// the space the inflexible tracks leave, over the flex factors (a sum
/// under 1 counts as 1), found again without any flexible track that share
/// would leave under its base size.
double _frSize(
  List<GridTrack> tracks,
  List<double> base,
  List<int> range,
  double space,
  double gap,
) {
  final inflexible = {
    for (final i in range)
      if (!tracks[i].flexible) i,
  };
  final gaps = gap * (range.length - 1);
  while (true) {
    var leftover = space - gaps;
    var factors = 0.0;
    for (final i in range) {
      if (inflexible.contains(i)) {
        leftover -= base[i];
      } else {
        factors += tracks[i].fraction;
      }
    }
    final size = leftover / (factors < 1 ? 1 : factors);
    final under = [
      for (final i in range)
        if (!inflexible.contains(i) && size * tracks[i].fraction < base[i]) i,
    ];
    if (under.isEmpty) return size;
    inflexible.addAll(under);
  }
}

List<double> _equal(double width, double gap, int count) {
  final each = math.max<double>(0, (width - gap * (count - 1)) / count);
  return List.filled(count, each);
}

/// The most tracks a [CssGrid] gives a span, along each axis.
///
/// Deliberate difference (Chromium 159.0.8154.13 clamps a grid span's lines
/// to 10,000,000, third_party/blink/renderer/core/style/grid_area.h:45 and
/// :184-191, and keeps that many tracks as ranges): a span or row span past
/// 1,000 is 1,000 here (INV-340). CssGrid sizes each track as an entry of
/// its own, so ten million would take a phone's memory and many seconds of
/// layout; an implicit grid of 1,000 tracks and their gaps already runs far
/// past any screen, as Chromium's does.
// TODO(port): track ranges, as Chromium's grid keeps repeated tracks
// (core/layout/grid/ not fetched), would take the 10,000,000 lines whole.
const int cssGridMaxTracks = 1000;

/// The span that CopilotKit's `span ${value}` gives a grid item
/// (`grid-column`/`grid-row`, react-core standard/layout.tsx:517-518,
/// :528-531), or null for none (one track): no declaration for a falsy
/// value (null, 0, NaN), and one the browser drops for a number whose
/// JavaScript `String()` is no CSS integer of at least 1 (CSS Grid 1,
/// section 8.3: `span <integer>`, positive): a fraction, a negative, 1e21
/// and past it (written with an exponent) and Infinity. A span past
/// [cssGridMaxTracks] is that many.
int? cssGridSpanOf(double? value) {
  if (value == null || value.isNaN || value < 1 || value >= 1e21) return null;
  if (value != value.floorToDouble()) return null;
  return math.min(value, cssGridMaxTracks.toDouble()).toInt();
}

/// The placement of a grid child: how many columns and rows it spans.
@immutable
class GridPlacement {
  /// A placement of [span] columns and [rowSpan] rows; [fullRow] spans
  /// every column (CSS `grid-column: 1 / -1`). [hasAspectRatio] is a
  /// child with a preferred aspect ratio.
  const GridPlacement({
    this.span = 1,
    this.rowSpan = 1,
    this.fullRow = false,
    this.hasAspectRatio = false,
  });

  /// One cell.
  static const GridPlacement cell = GridPlacement();

  /// The columns spanned.
  final int span;

  /// The rows spanned.
  final int rowSpan;

  /// Whether the child spans the whole row.
  final bool fullRow;

  /// Whether the child has a preferred aspect ratio (CSS `aspect-ratio`):
  /// the grid's `normal` alignment then places it at the start of its
  /// area, at its own height, instead of stretching it (CSS Grid Level 1,
  /// section 6.2: `normal` behaves as `stretch` only for an item with no
  /// preferred aspect ratio).
  final bool hasAspectRatio;

  @override
  bool operator ==(Object other) =>
      other is GridPlacement &&
      other.span == span &&
      other.rowSpan == rowSpan &&
      other.fullRow == fullRow &&
      other.hasAspectRatio == hasAspectRatio;

  @override
  int get hashCode => Object.hash(span, rowSpan, fullRow, hasAspectRatio);
}

/// The parent data of a child of [RenderCssGrid].
class CssGridParentData extends ContainerBoxParentData<RenderBox> {
  /// Where the child goes.
  GridPlacement placement = GridPlacement.cell;
}

/// Gives a child of [CssGrid] its placement.
class CssGridItem extends ParentDataWidget<CssGridParentData> {
  /// Places [child] as [placement] says.
  const CssGridItem({required this.placement, required super.child, super.key});

  /// The spans.
  final GridPlacement placement;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as CssGridParentData;
    if (data.placement != placement) {
      data.placement = placement;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CssGrid;
}

/// The children of a CSS grid in auto-placed rows: CopilotKit's Grid and
/// Flow.
///
/// Children are placed row by row (`grid-auto-flow: row`, or `row dense`
/// with [dense]), each row as tall as its tallest child, and stretched to
/// their cell unless [align] says otherwise or a child has an aspect
/// ratio. A span wider than the columns is clamped to them, unless
/// [implicitColumns] adds the `auto` columns CSS adds for it.
class CssGrid extends MultiChildRenderObjectWidget {
  /// A grid of [children] (wrap each in a [CssGridItem] to span cells).
  const CssGrid({
    required this.columns,
    this.rowGap = 0,
    this.columnGap = 0,
    this.align,
    this.dense = false,
    this.implicitColumns = false,
    super.children,
    super.key,
  });

  /// The column template.
  final GridColumns columns;

  /// The space between rows.
  final double rowGap;

  /// The space between columns.
  final double columnGap;

  /// The vertical alignment of children in their cells; null is CSS's
  /// `normal`: it stretches every child but one with an aspect ratio.
  final A2uiAlign? align;

  /// `grid-auto-flow: row dense`: each child takes the first area that
  /// fits it, from the grid's start, so a later small child fills a hole an
  /// earlier wide one left (CSS Grid Level 1, section 8.5, "dense").
  final bool dense;

  /// Whether a child spanning more columns than the template has adds
  /// `auto` columns at the grid's end (`grid-auto-columns: auto`, CSS Grid
  /// Level 1, section 8.5, "Determine the columns in the implicit grid"),
  /// as `span N` does in CSS, instead of being clamped to the template's
  /// columns, as the Grid's `1 / -1` is.
  final bool implicitColumns;

  @override
  RenderCssGrid createRenderObject(BuildContext context) => RenderCssGrid(
    columns: columns,
    rowGap: rowGap,
    columnGap: columnGap,
    align: align,
    dense: dense,
    implicitColumns: implicitColumns,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
  );

  @override
  void updateRenderObject(BuildContext context, RenderCssGrid renderObject) {
    renderObject
      ..columns = columns
      ..rowGap = rowGap
      ..columnGap = columnGap
      ..align = align
      ..dense = dense
      ..implicitColumns = implicitColumns
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

class _Cell {
  _Cell(this.child, this.placement);

  final RenderBox child;
  final GridPlacement placement;
  int row = 0;
  int column = 0;
  int span = 1;
  int rowSpan = 1;
  double width = 0;
  Size size = Size.zero;
  BoxConstraints constraints = const BoxConstraints();
  Offset offset = Offset.zero;
}

/// The render object of [CssGrid].
class RenderCssGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CssGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CssGridParentData> {
  /// A grid.
  RenderCssGrid({
    required GridColumns columns,
    required double rowGap,
    required double columnGap,
    required A2uiAlign? align,
    required TextDirection textDirection,
    bool dense = false,
    bool implicitColumns = false,
  }) : _columns = columns,
       _rowGap = rowGap,
       _columnGap = columnGap,
       _align = align,
       _dense = dense,
       _implicitColumns = implicitColumns,
       _textDirection = textDirection;

  /// `grid-auto-flow: row dense` ([CssGrid.dense]).
  bool get dense => _dense;
  bool _dense;
  set dense(bool value) {
    if (value == _dense) return;
    _dense = value;
    markNeedsLayout();
  }

  /// Whether wide spans add `auto` columns ([CssGrid.implicitColumns]).
  bool get implicitColumns => _implicitColumns;
  bool _implicitColumns;
  set implicitColumns(bool value) {
    if (value == _implicitColumns) return;
    _implicitColumns = value;
    markNeedsLayout();
  }

  /// The column template.
  GridColumns get columns => _columns;
  GridColumns _columns;
  set columns(GridColumns value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  /// The space between rows.
  double get rowGap => _rowGap;
  double _rowGap;
  set rowGap(double value) {
    if (value == _rowGap) return;
    _rowGap = value;
    markNeedsLayout();
  }

  /// The space between columns.
  double get columnGap => _columnGap;
  double _columnGap;
  set columnGap(double value) {
    if (value == _columnGap) return;
    _columnGap = value;
    markNeedsLayout();
  }

  /// The vertical alignment of children in their cells; null stretches.
  A2uiAlign? get align => _align;
  A2uiAlign? _align;
  set align(A2uiAlign? value) {
    if (value == _align) return;
    _align = value;
    markNeedsLayout();
  }

  /// The direction columns run in.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CssGridParentData) {
      child.parentData = CssGridParentData();
    }
  }

  List<_Cell> _cells() {
    final cells = <_Cell>[];
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as CssGridParentData;
      cells.add(_Cell(child, data.placement));
      child = data.nextSibling;
    }
    return cells;
  }

  /// The number of columns the grid renders at [width], before empty
  /// auto-fit columns collapse: what CopilotKit hands to its GridItems.
  int columnCountFor(double width) => _columns.widths(width, _columnGap).length;

  /// The grid's min-content ([minimum]) or max-content width. Explicit
  /// tracks are sized under that constraint, with the items placed as
  /// layout places them (CSS Grid L1 §11.1 and §11.5-11.7, inferred: the
  /// free space is zero under a min-content constraint and infinite under a
  /// max-content one). With an indefinite width an auto-repeated template
  /// has one column: the widest child.
  double _intrinsicWidth({required bool minimum}) {
    final cells = _cells();
    final columns = _columns;
    if (columns is TrackColumns && columns.tracks.isNotEmpty) {
      final tracks = columns.tracks;
      _place(cells, tracks.length, dense: _dense);
      final widths = _sizeTracks(
        tracks,
        _columnGap,
        cells,
        minContent: minimum,
      );
      return widths.fold<double>(0, (a, b) => a + b) +
          _columnGap * (tracks.length - 1);
    }
    var widest = 0.0;
    for (final cell in cells) {
      widest = math.max(
        widest,
        minimum
            ? cell.child.getMinIntrinsicWidth(double.infinity)
            : cell.child.getMaxIntrinsicWidth(double.infinity),
      );
    }
    return widest;
  }

  /// Auto-placement into [count] columns, row by row (CSS Grid Level 1,
  /// section 8.5, step 4): each cell's row, column and spans. Sparse
  /// (`grid-auto-flow: row`), the cursor goes on from the last item placed;
  /// [dense], it starts again from the grid's start line for each item. A
  /// span wider than [count] is clamped to it.
  static void _place(List<_Cell> cells, int count, {bool dense = false}) {
    final occupied = <int, Set<int>>{};
    bool free(int row, int column, int span, int rowSpan) {
      for (var r = row; r < row + rowSpan; r++) {
        final taken = occupied[r];
        if (taken == null) continue;
        for (var c = column; c < column + span; c++) {
          if (taken.contains(c)) return false;
        }
      }
      return true;
    }

    var row = 0;
    var column = 0;
    for (final cell in cells) {
      final span = cell.placement.fullRow
          ? count
          : cell.placement.span.clamp(1, count);
      final rowSpan = math.max(1, cell.placement.rowSpan);
      if (dense) {
        row = 0;
        column = 0;
      }
      if (cell.placement.fullRow && column > 0) {
        row++;
        column = 0;
      }
      while (true) {
        if (column + span > count) {
          row++;
          column = 0;
        }
        if (free(row, column, span, rowSpan)) break;
        column++;
      }
      cell
        ..row = row
        ..column = column
        ..span = span
        ..rowSpan = rowSpan;
      for (var r = row; r < row + rowSpan; r++) {
        final taken = occupied.putIfAbsent(r, () => <int>{});
        for (var c = column; c < column + span; c++) {
          taken.add(c);
        }
      }
      column += span;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(minimum: true);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(minimum: false);

  double _intrinsicHeight(double width) {
    final w = width.isFinite ? width : _intrinsicWidth(minimum: false);
    return _run(BoxConstraints.tightFor(width: w), _intrinsicSize).height;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  static Size _intrinsicSize(RenderBox child, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.hasTightHeight
        ? constraints.maxHeight
        : child.getMaxIntrinsicHeight(width);
    return Size(width, height);
  }

  static Size _dryLayout(RenderBox child, BoxConstraints constraints) =>
      child.getDryLayout(constraints);

  static Size _layout(RenderBox child, BoxConstraints constraints) {
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  List<_Cell> _lastCells = const [];

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _run(constraints, _dryLayout);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    _run(constraints, _dryLayout);
    for (final cell in _lastCells) {
      final distance = cell.child.getDryBaseline(cell.constraints, baseline);
      if (distance != null) return distance + cell.offset.dy;
    }
    return null;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void performLayout() {
    size = _run(constraints, _layout);
    for (final cell in _lastCells) {
      (cell.child.parentData! as CssGridParentData).offset = cell.offset;
    }
  }

  Size _run(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) sizeChild,
  ) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _intrinsicWidth(minimum: false);
    final columns = _columns;
    final explicit = columns is TrackColumns && columns.tracks.isNotEmpty
        ? columns.tracks
        : null;
    var tracks = explicit == null
        ? columns.widths(width, _columnGap)
        : const <double>[];
    final templateCount = explicit?.length ?? tracks.length;
    final cells = _cells();
    // The implicit grid's columns: the template's, and as many `auto`
    // columns more as the widest span needs.
    var count = templateCount;
    if (_implicitColumns) {
      for (final cell in cells) {
        if (!cell.placement.fullRow) {
          count = math.max(count, cell.placement.span);
        }
      }
    }
    _place(cells, count, dense: _dense);
    // auto-fit: template columns no child reaches collapse, gaps included
    // (CSS Grid Level 1, section 7.2.3.2), and the others share the width.
    final used = <int>{};
    for (final cell in cells) {
      for (var c = cell.column; c < cell.column + cell.span; c++) {
        used.add(c);
      }
    }
    final kept = [
      for (var i = 0; i < count; i++)
        if (columns is! AutoFitColumns ||
            used.isEmpty ||
            used.length == count ||
            used.contains(i))
          i,
    ];
    final position = {for (var i = 0; i < kept.length; i++) kept[i]: i};
    final index = [for (var i = 0; i < count; i++) position[i] ?? 0];
    if (count > templateCount) {
      // The template's tracks (an auto-repeated one is minmax(T, 1fr)) and
      // the implicit `auto` ones, sized by the items placed in them.
      final minimum = explicit == null
          ? columns.trackMinimum(width, _columnGap)
          : 0.0;
      final definitions = [
        for (final i in kept)
          if (i >= templateCount)
            const GridTrack.auto()
          else
            explicit?[i] ?? GridTrack(pixels: minimum, fraction: 1),
      ];
      final placed = [
        for (final cell in cells)
          _Cell(cell.child, cell.placement)
            ..column = index[cell.column]
            ..span =
                index[cell.column + cell.span - 1] - index[cell.column] + 1,
      ];
      tracks = _sizeTracks(definitions, _columnGap, placed, available: width);
    } else if (explicit != null) {
      // Explicit tracks are sized by the items placed in them.
      tracks = _sizeTracks(explicit, _columnGap, cells, available: width);
    } else if (kept.length < count) {
      final each = math.max<double>(
        0,
        (width - _columnGap * (kept.length - 1)) / kept.length,
      );
      tracks = List.filled(kept.length, each);
    }
    final lefts = <double>[];
    var x = 0.0;
    for (final track in tracks) {
      lefts.add(x);
      x += track + _columnGap;
    }

    // Row heights: each row as tall as its tallest single-row child; a
    // child spanning rows spreads what it lacks over them.
    final rowCount = cells.fold(0, (n, c) => math.max(n, c.row + c.rowSpan));
    final heights = List<double>.filled(rowCount, 0);
    for (final cell in cells) {
      final first = index[cell.column];
      final last = index[cell.column + cell.span - 1];
      cell.width = lefts[last] + tracks[last] - lefts[first];
      final constraints = BoxConstraints.tightFor(width: cell.width);
      cell
        ..size = sizeChild(cell.child, constraints)
        ..constraints = constraints;
      if (cell.rowSpan == 1) {
        heights[cell.row] = math.max(heights[cell.row], cell.size.height);
      }
    }
    for (final cell in cells.where((c) => c.rowSpan > 1)) {
      var spanned = _rowGap * (cell.rowSpan - 1);
      for (var r = cell.row; r < cell.row + cell.rowSpan; r++) {
        spanned += heights[r];
      }
      final lack = cell.size.height - spanned;
      if (lack > 0) {
        for (var r = cell.row; r < cell.row + cell.rowSpan; r++) {
          heights[r] += lack / cell.rowSpan;
        }
      }
    }
    final tops = <double>[];
    var y = 0.0;
    for (final height in heights) {
      tops.add(y);
      y += height + _rowGap;
    }
    final contentHeight = rowCount == 0 ? 0.0 : y - _rowGap;

    final rtl = _textDirection == TextDirection.rtl;
    for (final cell in cells) {
      var area = _rowGap * (cell.rowSpan - 1);
      for (var r = cell.row; r < cell.row + cell.rowSpan; r++) {
        area += heights[r];
      }
      var top = tops[cell.row];
      // `normal` stretches an item unless it has a preferred aspect ratio,
      // which it then keeps, at the start of its area (CSS Grid Level 1,
      // section 6.2).
      final align =
          _align ??
          (cell.placement.hasAspectRatio ? A2uiAlign.start : A2uiAlign.stretch);
      if (align == A2uiAlign.stretch) {
        if (cell.size.height != area) {
          final constraints = BoxConstraints.tightFor(
            width: cell.width,
            height: area,
          );
          cell
            ..size = sizeChild(cell.child, constraints)
            ..constraints = constraints;
        }
      } else if (align == A2uiAlign.center) {
        top += (area - cell.size.height) / 2;
      } else if (align == A2uiAlign.end) {
        top += area - cell.size.height;
      }
      final left = lefts[index[cell.column]];
      cell.offset = Offset(rtl ? width - left - cell.size.width : left, top);
    }
    _lastCells = cells;
    return constraints.constrain(Size(width, contentHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

// PORT STATUS: confidence=medium todos=2 upstream=none (CSS Grid Layout 1; chromium@159.0.8154.13 third_party/blink/renderer/core/style/grid_area.h for the span clamp)
