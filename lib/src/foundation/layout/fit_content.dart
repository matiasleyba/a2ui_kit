// A box sized to its content as CSS sizes one (`fit-content`): an
// inline-block (CSS 2.1 section 10.3.9, "shrink-to-fit"), an absolutely
// placed box, a grid item that is not stretched (CSS Box Alignment 3
// `place-items: center`).
//
// Its width is min(max-content, max(min-content, available)): no wider than
// the width offered, unless its min-content width (its widest run that may
// not break: a word where `overflow-wrap` is `normal`, CSS Text 3 section
// 5.2) is wider; then that wide, overflowing the box it was offered
// (RULEBOOK section 2, text layout: never a word broken where CSS keeps it
// whole). Flutter's `Text` breaks an over-long word by characters instead.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [child] out as CSS lays out a box sized to its content: at most the
/// width offered, or its min-content width when that is wider, overflowing
/// its box placed by [alignment] (the top left: an inline-block, which its
/// line box start-aligns when it does not fit, CSS Text 3 section 6.1; the
/// centre: a grid item that `place-items: center` centres).
///
/// Its own size is the child's, clamped to the constraints; what overflows
/// is painted, not clipped (`overflow: visible`), and takes no pointer.
class CssFitContent extends SingleChildRenderObjectWidget {
  /// Sizes [child] to its content, placed by [alignment].
  const CssFitContent({
    required Widget super.child,
    this.alignment = Alignment.topLeft,
    super.key,
  });

  /// Where the child sits in this box when their sizes differ.
  final Alignment alignment;

  @override
  RenderCssFitContent createRenderObject(BuildContext context) =>
      RenderCssFitContent(alignment);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCssFitContent renderObject,
  ) => renderObject.alignment = alignment;
}

/// The render object of [CssFitContent].
class RenderCssFitContent extends RenderShiftedBox {
  /// A box placing its child by [alignment].
  RenderCssFitContent(this._alignment) : super(null);

  Alignment _alignment;

  /// Where the child sits in this box when their sizes differ.
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(RenderBox child, BoxConstraints c) {
    final minContent = child.getMinIntrinsicWidth(double.infinity);
    return BoxConstraints(maxWidth: math.max(c.maxWidth, minContent));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(_childConstraints(child, constraints)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(child, constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
    (child.parentData! as BoxParentData).offset = _alignment.alongOffset(
      Offset(size.width - child.size.width, size.height - child.size.height),
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=none
