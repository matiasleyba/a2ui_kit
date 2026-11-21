import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:flutter/widgets.dart';

/// The standard `Strikethrough`: `text` as written (no markdown) in an
/// `<s>`, with a line through it (Chromium 159.0.8154.13 html.css:1699-1701;
/// react-core standard/text.tsx:265-267), with a decoration it inherits (an
/// underlined Text's line) drawn too. Size, weight, colour and line height
/// are the surrounding text's: inside a Text its words continue the Text's
/// line and break with it ([strikethroughRuns]), elsewhere it is a block of
/// its own.
Widget buildStrikethrough(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => InlineElementText(text: StrikethroughProps(props).text, style: _struck);

/// The words a Strikethrough gives the line of the Text holding it.
List<InlineRun> strikethroughRuns(
  BuildContext context,
  ComponentProps props,
  TextStyle inherited,
) => [InlineWords(StrikethroughProps(props).text ?? '', _struck(inherited))];

TextStyle _struck(TextStyle inherited) => TextStyle(
  decoration: combineDecoration(
    inherited.decoration,
    TextDecoration.lineThrough,
  ),
);

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
