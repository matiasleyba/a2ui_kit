import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:flutter/widgets.dart';

/// The pixels of an Icon `size`: `sm` 16, `md` 20, `lg` 24, `xl` 32, or a
/// number of pixels (`ICON_PX`, `media.tsx:50-55`).
double iconPixels(Object? size) => switch (size) {
  final num n when n.isFinite && n >= 0 => n.toDouble(),
  'sm' => 16,
  'lg' => 24,
  'xl' => 32,
  _ => 20,
};

/// The stroke width of a `strokeWeight` on lucide-react's 24px grid
/// (`ICON_STROKE`, `media.tsx:56-61`); lucide-react's own 2 when none is set
/// (`strokeWidth = 2`, lucide-react 0.525.0's `dist/esm/Icon.js:16`).
double iconStrokeWidth(A2uiFontWeight? weight) => switch (weight) {
  null || A2uiFontWeight.normal => 2,
  A2uiFontWeight.medium => 2.25,
  A2uiFontWeight.semibold => 2.5,
  A2uiFontWeight.bold => 3,
};

/// The standard `Icon`: a Lucide icon by name (kebab-case, PascalCase or an
/// A2UI basic catalog name such as `arrowBack`), drawn from lucide-react
/// 0.525.0's node, as react-core draws it in either look; or `{"svgPath"}`,
/// a filled path on a 24px grid.
///
/// `size` is `md` (20px) by default; `inline` makes it 1em and sets its
/// bottom 0.125em below the text's baseline. A size in pixels stays that
/// size at any text scale, inside a Text's line too; 1em grows with the
/// text. `color` is a text colour token
/// or a CSS colour for the stroke, the surrounding text colour by default
/// (the dots some icons fill keep the text colour, `currentColor`).
/// `strokeWeight` is the stroke width: 2, 2.25, 2.5 or 3 on the 24px grid.
/// With a `label` it is an image for screen readers, else hidden. A name
/// lucide-react 0.525.0's `icons` map lacks draws nothing.
///
/// Where CopilotKit has lucide-react's icons map, loaded on first use
/// (media.tsx:76-103): an Icon draws nothing until it arrives, here
/// lucide-react 0.525.0's and 1.57.0's own icon nodes, compiled in: an Icon
/// draws on the first frame (INV-006).
Widget buildIcon(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = IconProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final inherited = DefaultTextStyle.of(context).style;
  final inline = view.inline;
  final size = props.value('size');
  final textScaler = MediaQuery.textScalerOf(context);
  final fontSize = inherited.fontSize ?? theme.typography.fontSize;
  // `width: "1em"` with `inline` and no number (`media.tsx:138`, `:407`):
  // the em grows with the text scale; pixels do not, even in a box of a
  // Text's line, which scales what it holds ([InlineBoxScale]).
  final boxScale = InlineBoxScale.of(context);
  final pixels = size is! num && inline
      ? textScaler.scale(fontSize)
      : iconPixels(size) / (boxScale > 0 ? boxScale : 1);
  // `verticalAlign: "-0.125em"` with `inline` (`media.tsx:155`, `:428`): an
  // inline-block `<svg>` has its baseline at its bottom edge, set 0.125em
  // below the line's.
  final baseline = inline ? pixels - textScaler.scale(0.125 * fontSize) : null;
  // The envelope names the icon like `label` does (media.tsx:401-402): an
  // image in NodeView's node while it puts one there
  // ([KitEnvelope.wrapped]); the glyph then gives no semantics of its own.
  final envelope = KitEnvelope.of(props);
  final label = envelope.wrapped ? null : view.label;
  Widget named(Widget glyph) {
    if (!envelope.wrapped) return glyph;
    final own = view.label;
    final hasOwn = own != null && own.isNotEmpty;
    return Semantics(
      image: envelope.label != null || hasOwn,
      label: envelope.label == null && hasOwn ? own : null,
      child: glyph,
    );
  }

  final name = view.name;
  if (name is Map) {
    final path = ComponentProps.asString(name['svgPath']);
    if (path == null) return const SizedBox.shrink();
    final glyph = SvgPathGlyph(
      pathData: path,
      size: pixels,
      color:
          theme.textColor(view.color) ??
          inherited.color ??
          const Color(0xff000000),
      baseline: baseline,
    );
    if (label == null || label.isEmpty) {
      return named(ExcludeSemantics(child: glyph));
    }
    return Semantics(label: label, image: true, container: true, child: glyph);
  }
  final icon = lucideIcon(
    ComponentProps.asString(name),
    release: LucideRelease.reactCore,
    a2uiNames: true,
  );
  if (icon == null) return const SizedBox.shrink();
  return named(
    LucideGlyph(
      icon,
      size: pixels,
      // lucide-react's `color` prop is the `<svg>`'s `stroke`
      // (`media.tsx:149`); `currentColor` stays the text colour around it.
      stroke: theme.textColor(view.color),
      strokeWidth: iconStrokeWidth(view.strokeWeight),
      baseline: baseline,
      label: label == null || label.isEmpty ? null : label,
    ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/media.tsx
