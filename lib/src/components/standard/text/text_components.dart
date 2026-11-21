import 'package:a2ui_core/a2ui_core.dart' show NodeProps;
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/node_guard.dart'
    show isDrawnChild, nodeProblemOf;
import 'package:a2ui_kit/src/components/standard/layout/flex_container.dart';
import 'package:a2ui_kit/src/components/standard/text/bold.dart';
import 'package:a2ui_kit/src/components/standard/text/italic.dart';
import 'package:a2ui_kit/src/components/standard/text/math.dart';
import 'package:a2ui_kit/src/components/standard/text/strikethrough.dart';
import 'package:a2ui_kit/src/components/standard/text/underline.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:a2ui_kit/src/foundation/text/inline_markdown.dart';
import 'package:a2ui_kit/src/foundation/text/inline_text.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:a2ui_kit/src/theme/typography.dart';
import 'package:flutter/widgets.dart';

/// The inline children whose runs a Text's line takes, by component name
/// (RULEBOOK section 2, inline children of a Text): their words and a
/// formula's pieces continue the line and break with it, never one box
/// each (CSS 2.1 section 9.2.2).
const Map<String, InlineRunsBuilder> _inlineRuns = {
  'Bold': boldRuns,
  'Italic': italicRuns,
  'Underline': underlineRuns,
  'Strikethrough': strikethroughRuns,
  'Math': mathRuns,
};

/// The inherited font size at [context].
double _baseFontSize(BuildContext context, A2uiKitTheme theme) =>
    DefaultTextStyle.of(context).style.fontSize ?? theme.typography.fontSize;

/// The pixels of a typography `width` (4px steps, or CSS), or null when it
/// is unset or relative to the container (the container resolves those).
double? _width(Object? value, A2uiKitTheme theme, double fontSize) {
  final length = A2uiLength.steps(value, step: theme.spacingStep);
  if (length == null || length is A2uiPercent) return null;
  return length.resolve(fontSize: fontSize);
}

/// The clamp of the shared typography props: `truncate` is one line with an
/// ellipsis, `maxLines` that many lines with an ellipsis.
({int? maxLines, bool softWrap, TextOverflow? overflow}) _clamp(
  ComponentProps props,
) {
  if (props.boolean('truncate') ?? false) {
    return (maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);
  }
  final lines = props.number('maxLines');
  if (lines != null && lines >= 1) {
    return (
      maxLines: lines.floor(),
      softWrap: true,
      overflow: TextOverflow.ellipsis,
    );
  }
  return (maxLines: null, softWrap: true, overflow: null);
}

/// The segments of a `text` prop: inline markdown, or one plain run when
/// [markdown] is false.
List<InlineSegment> _segments(String? text, {bool markdown = true}) {
  if (text == null || text.isEmpty) return const [];
  return markdown ? parseInlineMarkdown(text) : [InlinePlain(text)];
}

Widget _sized(Widget child, double? width) =>
    width == null ? child : SizedBox(width: width, child: child);

/// The heading level CopilotKit renders a Title of [size] as.
A2uiHeadingLevel headingLevelOf(TitleSize size) => switch (size) {
  TitleSize.sm => A2uiHeadingLevel.h4,
  TitleSize.md || TitleSize.lg => A2uiHeadingLevel.h3,
  _ => A2uiHeadingLevel.h2,
};

/// The standard `Title`: a heading whose type comes from the theme's
/// heading style for its level (h4 for `sm`, h3 for `md` and `lg`, h2 from
/// `xl`); `strong: false` makes it 400. The text is plain, not markdown.
Widget buildTitle(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = TitleProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final base = _baseFontSize(context, theme);
  final heading = theme.typography.heading(headingLevelOf(view.size));
  final weight = view.fontWeight;
  final clamp = _clamp(props);
  final fontSize = heading.fontSizeEm == null
      ? null
      : base * heading.fontSizeEm!;
  // text.tsx:108-117 (`TITLE_TAG`), :131: the Title is an `<h4>`, `<h3>`
  // or `<h2>` by size, a heading of that level to a screen reader: a node
  // of its own, so the heading is the Title's alone and read in its place.
  return Semantics(
    container: true,
    header: true,
    headingLevel: switch (headingLevelOf(view.size)) {
      A2uiHeadingLevel.h2 => 2,
      A2uiHeadingLevel.h3 => 3,
      A2uiHeadingLevel.h4 => 4,
    },
    child: _sized(
      InlineText(
        segments: collapseCssWhitespace(_segments(view.text, markdown: false)),
        style: TextStyle(
          fontSize: fontSize,
          height: heading.lineHeight,
          fontWeight: weight != null
              ? fontWeightOf(weight)
              : props.boolean('strong') == false
              ? FontWeight.w400
              : heading.fontWeight,
          color: theme.textColor(view.color),
          fontStyle: (view.italic ?? false) ? FontStyle.italic : null,
          fontFeatures: (view.tabularNums ?? false)
              ? const [FontFeature.tabularFigures()]
              : null,
        ),
        textAlign: view.textAlign == null ? null : textAlignOf(view.textAlign!),
        maxLines: clamp.maxLines,
        softWrap: clamp.softWrap,
        overflow: clamp.overflow,
      ),
      _width(props.value('width'), theme, fontSize ?? base),
    ),
  );
}

/// The standard `Text`: body text with inline markdown, its `children`
/// inline after it: the words of a Bold, Italic, Underline or
/// Strikethrough and the pieces of an inline Math continue the Text's line
/// and break with it, their white space collapsing with the line's; any
/// other child is one box of the line.
///
/// Without `size` it keeps the inherited size and line height; `fontSize`
/// (pixels) wins over `size`. `minLines` reserves lines of 1.5em. A block
/// `highlight` fills the whole text box, as a block `span`'s background
/// does; an `inline` one only the text.
Widget buildText(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = TextProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final base = _baseFontSize(context, theme);
  final size = A2uiTextSize.fromWire(props.value('size'));
  var fontSize = base;
  double? height;
  if (size != null) {
    final (em, lineHeight) = textScale(size);
    fontSize = base * em;
    height = lineHeight;
  }
  final fontSizeProp = A2uiLength.pixels(props.value('fontSize'));
  if (fontSizeProp != null) {
    fontSize =
        fontSizeProp.resolve(percentBase: base, fontSize: base) ?? fontSize;
  }
  final lineHeight = props.value('lineHeight');
  if (lineHeight != null) height = lineHeightOf(lineHeight, fontSize);

  final weight = view.fontWeight;
  final inline = props.boolean('inline') ?? false;
  final highlight = switch (props.value('highlight')) {
    true => theme.color(A2uiColorToken.highlightOrange),
    'green' => theme.color(A2uiColorToken.highlightGreen),
    'orange' => theme.color(A2uiColorToken.highlightOrange),
    'pink' => theme.color(A2uiColorToken.highlightPink),
    _ => null,
  };
  final decorations = [
    if (view.underline ?? false) TextDecoration.underline,
    if (view.lineThrough ?? false) TextDecoration.lineThrough,
  ];
  final clamp = _clamp(props);
  final align = view.textAlign != null
      ? textAlignOf(view.textAlign!)
      : RowEndText.of(context)
      ? TextAlign.right
      : null;

  final preserve = props.boolean('preserveWhitespace') ?? false;
  var segments = _segments(view.text);
  if (!preserve) segments = collapseCssWhitespace(segments);
  // What the Text's inline children inherit; a background is not inherited.
  final inherited = TextStyle(
    fontSize: fontSize,
    height: height,
    fontWeight: weight != null
        ? fontWeightOf(weight)
        : (view.strong ? FontWeight.w600 : null),
    color: theme.textColor(view.color),
    fontStyle: (view.italic ?? false) ? FontStyle.italic : null,
    fontFeatures: (view.tabularNums ?? false)
        ? const [FontFeature.tabularFigures()]
        : null,
    decoration: decorations.isEmpty
        ? null
        : TextDecoration.combine(decorations),
  );
  final style = inherited.copyWith(backgroundColor: inline ? highlight : null);
  final children = props.children('children').where(isDrawnChild).toList();
  final overrides =
      A2uiKitScope.maybeOf(context)?.options.overrides ?? const {};
  // The children whose runs the line takes, unless their props fail the
  // render check: watched, since their props change without the Text's.
  // An app's own builder for one is drawn as a box.
  final hosted = {
    for (final child in children)
      if (!child.isPlaceholder &&
          _inlineRuns.containsKey(child.type) &&
          !overrides.containsKey(child.type))
        child,
  };
  // The line scales the child of each box by its text scale
  // (`WidgetSpan`), the child laid out without it.
  final lineScale = fontSize == 0
      ? 1.0
      : MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
  final boxScale = InlineBoxScale.of(context) * lineScale;

  // A child as one box of the line, in the Text's type, as a child element
  // inherits its parent's font, its text scaled once, by the line.
  InlineRun box(KitNode child) => InlineAtom(
    WidgetSpan(
      alignment: child.type == 'Badge'
          ? PlaceholderAlignment.middle
          : PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: KeyedSubtree(
        key: NodeKey(child.instanceId),
        child: MediaQuery.withNoTextScaling(
          child: InlineBoxScale(
            scale: boxScale,
            child: DefaultTextStyle.merge(
              style: inherited,
              child: buildChild(child),
            ),
          ),
        ),
      ),
    ),
  );

  List<InlineRun> runsOf(BuildContext context, KitNode child) {
    if (hosted.contains(child)) {
      final childProps = ComponentProps(child.props.peek());
      // Props that fail the check show the fallback in a box, as the node
      // guard builds it, and report there.
      if (nodeProblemOf(child, childProps) == null) {
        final runs = _inlineRuns[child.type]!(
          context,
          childProps,
          DefaultTextStyle.of(context).style.merge(inherited),
        );
        if (runs != null) return runs;
      }
    }
    return [box(child)];
  }

  Widget text = ChildPropsBuilder<NodeProps>(
    children: hosted.toList(),
    derive: (child) => child.props.peek(),
    builder: (context, _) => InlineText(
      segments: segments,
      // `{props.text ? " " : null}{props.children}` (text.tsx:199-205), the
      // white space collapsing across the children's edges as within one
      // line; `white-space` is inherited (text.tsx:193-195), so `pre-wrap`
      // keeps theirs too.
      trailing: inlineRunSpans(
        [
          if (children.isNotEmpty && segments.isNotEmpty)
            const InlineWords(' '),
          for (final child in children) ...runsOf(context, child),
        ],
        collapse: !preserve,
        atLineStart: segments.isEmpty,
      ),
      style: style,
      textAlign: align,
      maxLines: clamp.maxLines,
      softWrap: clamp.softWrap,
      overflow: clamp.overflow,
    ),
  );
  final minLines = view.minLines;
  if (minLines != null && minLines > 0) {
    text = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minLines * 1.5 * fontSize),
      child: text,
    );
  }
  // The highlight's box stays when there is none (one tree shape, RULEBOOK
  // §2), so the text and its inline children keep their state when
  // `highlight` comes and goes.
  if (!inline) {
    text = DecoratedBox(
      decoration: BoxDecoration(color: highlight),
      child: text,
    );
  }
  return _sized(text, _width(props.value('width'), theme, fontSize));
}

/// The size of a Caption in em: `sm` .75, `md` .8125, `lg` .875 (14px at a
/// 16px base).
double captionEm(A2uiSize size) => switch (size) {
  A2uiSize.sm => .75,
  A2uiSize.md => .8125,
  A2uiSize.lg => .875,
};

/// The standard `Caption`: small secondary text with inline markdown.
Widget buildCaption(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = CaptionProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final base = _baseFontSize(context, theme);
  final clamp = _clamp(props);
  return InlineText(
    segments: collapseCssWhitespace(_segments(view.text)),
    style: TextStyle(
      fontSize: base * captionEm(view.size),
      fontWeight: fontWeightOf(view.fontWeight),
      color:
          theme.textColor(view.color) ??
          theme.color(A2uiColorToken.textSecondary),
    ),
    textAlign: view.textAlign == null ? null : textAlignOf(view.textAlign!),
    maxLines: clamp.maxLines,
    softWrap: clamp.softWrap,
    overflow: clamp.overflow,
  );
}

/// The standard `Label`: the label of a form field, in the `sm` text size,
/// secondary and medium by default. `htmlFor` is accepted and ignored: in
/// React it cannot reach the standard inputs either (their ids are
/// generated).
Widget buildLabel(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = LabelProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final base = _baseFontSize(context, theme);
  final (em, lineHeight) = textScale(view.size);
  final clamp = _clamp(props);
  return _sized(
    InlineText(
      segments: collapseCssWhitespace(_segments(view.text, markdown: false)),
      style: TextStyle(
        fontSize: base * em,
        height: lineHeight,
        fontWeight: fontWeightOf(view.fontWeight),
        color:
            theme.textColor(view.color) ??
            theme.color(A2uiColorToken.textSecondary),
      ),
      textAlign: view.textAlign == null ? null : textAlignOf(view.textAlign!),
      maxLines: clamp.maxLines,
      softWrap: clamp.softWrap,
      overflow: clamp.overflow,
    ),
    _width(props.value('width'), theme, base * em),
  );
}

/// The minimum height of a Badge by size: 18, 20 or 24px.
double _badgeHeight(A2uiSize size) => switch (size) {
  A2uiSize.sm => 18,
  A2uiSize.md => 20,
  A2uiSize.lg => 24,
};

/// The font size of a Badge by size, in em: .6875, .75 or .8125.
double _badgeEm(A2uiSize size) => switch (size) {
  A2uiSize.sm => .6875,
  A2uiSize.md => .75,
  A2uiSize.lg => .8125,
};

/// The padding of a Badge by size: `0 5px`, `0 6.65px` or `2px 8px`.
EdgeInsets _badgePadding(A2uiSize size) => switch (size) {
  A2uiSize.sm => const EdgeInsets.symmetric(horizontal: 5),
  A2uiSize.md => const EdgeInsets.symmetric(horizontal: 6.65),
  A2uiSize.lg => const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
};

/// The standard `Badge`: a small status pill on one line. `soft` tints it
/// with its colour, `solid` fills it, `outline` draws a 1px border; the
/// neutral `secondary` uses the surface colours.
Widget buildBadge(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = BadgeProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final base = _baseFontSize(context, theme);
  final color = view.color.wire;
  final neutral = view.color == A2uiBadgeColor.secondary;
  final ink = theme.textColor(neutral ? 'default' : color);
  final variant = view.variant;
  final fill = switch (variant) {
    BadgeVariant.solid => theme.backgroundColor(
      neutral ? 'surface-inverted' : '$color-solid',
    ),
    BadgeVariant.outline => null,
    BadgeVariant.soft =>
      neutral
          ? theme.color(A2uiColorToken.badgeSecondary)
          : theme.backgroundColor(color),
  };
  final fontSize = base * _badgeEm(view.size);
  final maxWidth = _width(props.value('maxWidth'), theme, fontSize);
  final padding = props.value('padding') == null
      ? _badgePadding(view.size)
      : cssInsets(
              props.value('padding'),
              step: theme.spacingStep,
              fontSize: fontSize,
            ) ??
            _badgePadding(view.size);
  return Container(
    constraints: BoxConstraints(
      minHeight: _badgeHeight(view.size),
      maxWidth: maxWidth ?? double.infinity,
    ),
    padding: padding,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(
        view.pill ? 9999 : theme.radius('sm') ?? 6,
      ),
      border: variant == BadgeVariant.outline
          ? Border.all(
              color:
                  theme.borderColor(neutral ? 'default' : color) ??
                  const Color(0x00000000),
            )
          : null,
    ),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        view.label ?? '',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          height: 16 / fontSize,
          letterSpacing: .3,
          fontWeight: fontWeightOf(view.fontWeight),
          color: variant == BadgeVariant.solid
              ? theme.color(A2uiColorToken.onAccent)
              : ink,
        ),
      ),
    ),
  );
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
