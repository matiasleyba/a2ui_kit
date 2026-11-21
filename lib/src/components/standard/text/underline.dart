import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:flutter/widgets.dart';

/// The standard `Underline`: `text` as written (no markdown) in a `<u>`,
/// underlined (Chromium 159.0.8154.13 html.css:1658-1660; react-core
/// standard/text.tsx:261-263), with a decoration it inherits (a
/// struck-through Text's line) drawn too. Size, weight, colour and line
/// height are the surrounding text's: inside a Text its words continue the
/// Text's line and break with it ([underlineRuns]), elsewhere it is a block
/// of its own.
Widget buildUnderline(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => InlineElementText(text: UnderlineProps(props).text, style: _underlined);

/// The words an Underline gives the line of the Text holding it.
List<InlineRun> underlineRuns(
  BuildContext context,
  ComponentProps props,
  TextStyle inherited,
) => [InlineWords(UnderlineProps(props).text ?? '', _underlined(inherited))];

TextStyle _underlined(TextStyle inherited) => TextStyle(
  decoration: combineDecoration(inherited.decoration, TextDecoration.underline),
);

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
