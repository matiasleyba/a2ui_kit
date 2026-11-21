import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_markdown.dart';
import 'package:a2ui_kit/src/foundation/text/inline_text.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/widgets.dart';

/// The width of a Blockquote's line, 3px (`borderLeft: 3px solid`,
/// react-core standard/text.tsx:277).
const double blockquoteRuleWidth = 3;

/// The standard `Blockquote`: a block quotation, `text` with inline
/// markdown (`**bold**`, `*italic*`, `~~strike~~`, `++underline++`,
/// `` `code` ``, `[link](url)`) in the secondary text colour, with a 3px
/// line in the strong border colour on its left and 12px (three spacing
/// steps) between the line and the text, no margin (react-core
/// standard/text.tsx:269-284). Its size and line height are the
/// surrounding text's; white space collapses as in any paragraph.
Widget buildBlockquote(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = BlockquoteProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final text = view.text ?? '';
  // renderInlineMarkdown(props.text), as Text renders its own text: the
  // foundation's port (parseInlineMarkdown, InlineText).
  final segments = collapseCssWhitespace(parseInlineMarkdown(text));
  return Container(
    // margin: 0; padding-left: spacing(3); border-left: 3px solid
    // borderColor("strong"). Left, not start: the physical side, in a
    // right-to-left page too.
    padding: EdgeInsets.only(left: theme.space(3)),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: theme.color(A2uiColorToken.borderStrong),
          width: blockquoteRuleWidth,
        ),
      ),
    ),
    // No text, no line: the quote is as tall as its padding, 0 (CSS 2.1
    // section 9.4.2), where an empty paragraph is a line tall.
    child: segments.isEmpty
        ? const SizedBox.shrink()
        : InlineText(
            segments: segments,
            style: TextStyle(color: theme.color(A2uiColorToken.textSecondary)),
          ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
