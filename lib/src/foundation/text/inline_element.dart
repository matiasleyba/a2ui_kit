// The raw text of an inline element of CopilotKit's standard catalog
// (`<strong>`, `<em>`, `<u>`, `<s>`, react-core standard/text.tsx:257-298):
// the string as React renders a child string, no markdown, in the type it
// inherits with the element's user-agent style over it (Chromium
// 159.0.8154.13 third_party/blink/renderer/core/html/resources/html.css:
// 1658-1672, 1699-1701); and the runs such an element, or an inline
// formula, gives the line of the Text that holds it (an inline box, CSS 2.1
// section 9.2.2).

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_flex.dart';
import 'package:a2ui_kit/src/foundation/layout/render_css_grid.dart';
import 'package:flutter/widgets.dart';

/// Whether the component at [context] sits in a line of text: a child of a
/// Text that the Text draws as one box of its line (a `WidgetSpan` of its
/// paragraph), with no block container (a flex or grid box) between them.
///
/// An inline element there is one piece of the Text's line, as a `<span>`'s
/// children are; anywhere else (a Column's child) it is a flex item, which
/// CSS makes a block (CSS Flexbox 1, section 4: flex items are blockified).
/// The inline children whose runs the Text's line takes ([InlineRun]) are
/// not built as widgets there at all.
bool isInlineInText(BuildContext context) {
  var inline = false;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is RichText) {
      inline = true;
      return false;
    }
    return widget is! CssFlex && widget is! CssGrid;
  });
  return inline;
}

final RegExp _collapsible = RegExp(r'[ \t\n\r\f]+');
final RegExp _edgeSpace = RegExp(r'^ | $');

/// [text] with its white space as CSS `white-space: normal` shows it: each
/// run of spaces, tabs and line breaks is one space (CSS Text 3, section
/// 4.1.1). A [block]'s text also loses a space at its start and its end,
/// which no line keeps (section 4.1.2); an inline piece of a longer line
/// keeps them, since the text around it holds its words apart.
String collapseInlineWhitespace(String text, {required bool block}) {
  final collapsed = text.replaceAll(_collapsible, ' ');
  // Only those spaces: a no-break space (U+00A0) is not collapsible and
  // stays, where `String.trim` would drop it.
  return block ? collapsed.replaceAll(_edgeSpace, '') : collapsed;
}

/// The decoration of [inherited] with [added] drawn too: a text decoration
/// propagates to the inline boxes inside its box, so a `<u>` inside a
/// struck-through Text shows both lines (CSS Text Decoration 3, section 2).
TextDecoration combineDecoration(
  TextDecoration? inherited,
  TextDecoration added,
) => inherited == null || inherited == TextDecoration.none
    ? added
    : TextDecoration.combine([inherited, added]);

/// The text of an inline element: [text] (null or empty shows nothing, no
/// line tall) in the inherited type, with [style] (given that type) over
/// it.
///
/// White space collapses as [collapseInlineWhitespace] says, a block's
/// trimmed and an inline piece's kept ([isInlineInText]). Inside a Text the
/// element is not this widget but its runs ([InlineWords]), which break
/// with the Text's line.
class InlineElementText extends StatelessWidget {
  /// Shows [text] in the style [style] gives.
  const InlineElementText({required this.text, required this.style, super.key});

  /// The raw text, as the component's `text` prop gives it.
  final String? text;

  /// The element's style over the type it inherits.
  final TextStyle Function(TextStyle inherited) style;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final shown = collapseInlineWhitespace(
      text ?? '',
      block: !isInlineInText(context),
    );
    // An element with no text makes no line (CSS 2.1 section 9.4.2: a line
    // box with no text is treated as not existing), where an empty `Text`
    // is a line tall.
    if (shown.isEmpty) return const SizedBox.shrink();
    return Text(shown, style: style(inherited));
  }
}

/// A piece of the line of a Text given by one of its inline children
/// (RULEBOOK section 2, inline children of a Text): the Text's paragraph
/// takes the runs, so they continue its line and break with it, as an
/// inline box's do (CSS 2.1 section 9.2.2).
sealed class InlineRun {
  /// A run.
  const InlineRun();
}

/// Words of an inline element: [text] as written, in [style] over the type
/// of the line around them (a span's style, merged with its parent's).
final class InlineWords extends InlineRun {
  /// [text] in [style].
  const InlineWords(this.text, [this.style]);

  /// The text, its white space not yet collapsed.
  final String text;

  /// The style over the line's.
  final TextStyle? style;
}

/// An atomic piece of the line, [span]: a placeholder (a `WidgetSpan`) the
/// line may break before and after, never inside, which holds the white
/// space on either side of it apart.
final class InlineAtom extends InlineRun {
  /// The piece [span].
  const InlineAtom(this.span);

  /// The placeholder.
  final InlineSpan span;
}

/// A forced line break: what follows starts a new line, as a block between
/// inline content ends one (CSS 2.1 section 9.2.1.1), a formula's `\\`
/// (KaTeX's `.newline { display: block }`).
final class InlineBreak extends InlineRun {
  /// A line break.
  const InlineBreak();
}

/// The runs a Text's line takes from a child component with [props], whose
/// line has the type [inherited] (the Text's own, merged over what the Text
/// inherits); null when the child gives no runs and is drawn as one box of
/// the line instead (a display formula, KaTeX's error span).
typedef InlineRunsBuilder =
    List<InlineRun>? Function(
      BuildContext context,
      ComponentProps props,
      TextStyle inherited,
    );

/// The spans of [runs], in order, as one line holds them.
///
/// With [collapse] (`white-space: normal`) each run of spaces, tabs and
/// line breaks is one space, and a space right after another goes even
/// across a run's edge, as across an inline's edge within one line (CSS
/// Text 3, section 4.1.1); so does a space at the line's start (the runs
/// begin it when [atLineStart]) and at its end (section 4.1.2). An atom
/// holds the spaces on either side of it apart. Without [collapse]
/// (`pre-wrap`, which an inline child inherits) each run's text is kept as
/// written.
List<InlineSpan> inlineRunSpans(
  List<InlineRun> runs, {
  required bool collapse,
  bool atLineStart = true,
}) {
  final spans = <InlineSpan>[];
  var afterSpace = atLineStart;
  for (final run in runs) {
    switch (run) {
      case InlineAtom(:final span):
        spans.add(span);
        afterSpace = false;
      case InlineBreak():
        // The space before a break ends its line, and goes (CSS Text 3
        // section 4.1.2); the next line starts afresh.
        final last = spans.lastOrNull;
        if (collapse && afterSpace && last is TextSpan) {
          spans.removeLast();
          final text = last.text!.substring(0, last.text!.length - 1);
          if (text.isNotEmpty) {
            spans.add(TextSpan(text: text, style: last.style));
          }
        }
        spans.add(const TextSpan(text: '\n'));
        afterSpace = true;
      case InlineWords(:final text, :final style):
        var shown = collapse ? text.replaceAll(_collapsible, ' ') : text;
        if (collapse && afterSpace && shown.startsWith(' ')) {
          shown = shown.substring(1);
        }
        if (shown.isEmpty) continue;
        afterSpace = shown.endsWith(' ');
        spans.add(TextSpan(text: shown, style: style));
    }
  }
  final last = spans.lastOrNull;
  if (collapse && afterSpace && last is TextSpan) {
    final text = last.text!.substring(0, last.text!.length - 1);
    spans.removeLast();
    if (text.isNotEmpty) spans.add(TextSpan(text: text, style: last.style));
  }
  return spans;
}

/// How much the boxes of the Text lines holding [child] magnify it: a
/// Text's line scales the child of each box it holds (a `WidgetSpan`) by
/// the line's text scale, the child laid out without it
/// ([MediaQuery.withNoTextScaling]), so the text inside grows once.
///
/// A length in `px`, which a browser's text size leaves alone, is laid out
/// divided by [of] there, so it is drawn its own size (RULEBOOK section 2,
/// inline children inside a Text; section 6 item 3); one in `em` grows with
/// the text, as the scale gives it.
class InlineBoxScale extends InheritedWidget {
  /// Publishes [scale] to [child].
  const InlineBoxScale({required this.scale, required super.child, super.key});

  /// The product of the text scales of the lines whose boxes hold [child].
  final double scale;

  /// The scale at [context]: 1 outside any Text's line.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InlineBoxScale>()?.scale ?? 1;

  @override
  bool updateShouldNotify(InlineBoxScale oldWidget) => scale != oldWidget.scale;
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
