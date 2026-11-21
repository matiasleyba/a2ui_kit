import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/components/standard/layout/focusable_scroll_box.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The font size of a Code block in em of the surrounding text: `.8125em`
/// (react-core standard/text.tsx:387).
const double codeFontEm = .8125;

/// The standard `Code`: `text` as a block of code in a monospace font, as
/// written (spaces, tabs and line breaks kept, no wrapping, no
/// highlighting), on the secondary surface with 12px (three spacing steps)
/// of padding and the `md` corners, scrolling sideways when a line is wider
/// than the block (react-core standard/text.tsx:374-393).
///
/// It takes the keyboard focus (CopilotKit's `<pre tabIndex={0}>`, "so a
/// keyboard user must be able to focus it"): Tab reaches it, the arrow keys
/// scroll it, and a 2px focus ring shows 2px outside it while its focus is
/// visible ([FocusableScrollBox]).
///
/// The text is `.8125em` of the surrounding size in the theme's mono font,
/// times the theme's `inlineCodeScale`: in the standard look a browser
/// draws a `monospace` element whose size is relative to a default-sized
/// page at 13/16 of it (Chromium 159.0.8154.13 core/css/resolver/
/// style_builder_converter.cc:963-972 keeps an `em` size relative;
/// font_builder.cc:329-363 scales a relative size by the fixed font's
/// 13px over the 16px default when the family turns monospace), and in the
/// playground look Tailwind's preflight sets the family to a list, which
/// Chromium does not count as monospace (platform/fonts/
/// font_description.h:257-260: the generic `monospace` alone).
///
/// `language` is read and shown nowhere: CopilotKit writes it only into
/// the `<code>`'s `data-language` attribute.
///
/// Difference from CopilotKit (README, "Differences", Code's font on the
/// web; port/inventory.tsv INV-321): on Flutter web, where only the app's
/// own fonts exist, code draws in flutter_math_fork's KaTeX_Typewriter, the
/// last of the theme's mono fallbacks, unless the app sets
/// `A2uiKitTypography.monoFontFamily`.
Widget buildCode(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = CodeProps(props);
  final theme = A2uiKitScope.themeOf(context);
  final type = theme.typography;
  final radius = BorderRadius.circular(theme.radius('md') ?? 8);
  final text = view.text ?? '';
  final shown = preformattedText(text);
  return _BottomBaseline(
    // The scrolling content is clipped to the box's padding box: its
    // corners, the box having no border (RULEBOOK section 2, the overflow
    // row).
    child: FocusableScrollBox(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.color(A2uiColorToken.surfaceSecondary),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: FocusableScrollBox.scrollView(
            axis: Axis.horizontal,
            child: Padding(
              padding: EdgeInsets.all(theme.space(3)),
              // An empty `<pre>` holds no line: it is its padding tall.
              child: text.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      shown,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: type.monoFontFamily,
                        fontFamilyFallback: type.monoFontFamilyFallback,
                        fontSize:
                            baseFontSize(context) *
                            codeFontEm *
                            type.inlineCodeScale,
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The `<pre>`'s baseline on a line: its bottom edge, as a box whose
/// `overflow` is not `visible` has its bottom margin edge for its baseline
/// (CSS 2.1 section 10.8.1, `vertical-align: baseline`); measured or laid
/// out alike, where the scroll view inside answers no dry baseline and
/// would throw in a parent's measuring (a Text's line in a Row or a table
/// cell).
class _BottomBaseline extends SingleChildRenderObjectWidget {
  const _BottomBaseline({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBottomBaseline();
}

class _RenderBottomBaseline extends RenderProxyBox {
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => size.height;

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline _) =>
      getDryLayout(constraints).height;
}

/// The tab stops of a `<pre>`: every 8 spaces (`tab-size`'s initial value,
/// CSS Text 3 section 4.2).
const int cssTabSize = 8;

/// [text] laid out by lines as `white-space: pre` lays it out, for a
/// Flutter `Text` (which replaces a tab by one space and lays out a line
/// after a final line break):
///
/// - a tab moves the next character to the next tab stop (CSS Text 3,
///   sections 4.1.3 and 4.2: multiples of 8 space advances from the line's
///   start, which in a monospace font are character columns);
/// - one final line break is dropped: the empty line after it holds
///   nothing and does not end in a line break, so it does not exist (CSS
///   2.1 section 9.4.2). A text that is only a line break keeps its one
///   (empty) line.
String preformattedText(String text) {
  var out = text;
  if (out.endsWith('\n')) out = out.substring(0, out.length - 1);
  if (!out.contains('\t')) return out;
  final buffer = StringBuffer();
  var column = 0;
  for (final rune in out.runes) {
    if (rune == 0x09) {
      final next = (column ~/ cssTabSize + 1) * cssTabSize;
      buffer.write(' ' * (next - column));
      column = next;
    } else if (rune == 0x0a) {
      buffer.writeCharCode(rune);
      column = 0;
    } else {
      buffer.writeCharCode(rune);
      column += 1;
    }
  }
  return buffer.toString();
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
