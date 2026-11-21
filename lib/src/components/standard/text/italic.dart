import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:flutter/widgets.dart';

/// The standard `Italic`: `text` as written (no markdown) in an `<em>`,
/// italic (Chromium 159.0.8154.13 html.css:1670-1672; react-core
/// standard/text.tsx:257-259). Size, weight, colour and line height are the
/// surrounding text's: inside a Text its words continue the Text's line and
/// break with it ([italicRuns]), elsewhere it is a block of its own.
Widget buildItalic(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => InlineElementText(text: ItalicProps(props).text, style: (_) => _italic);

/// The words an Italic gives the line of the Text holding it.
List<InlineRun> italicRuns(
  BuildContext context,
  ComponentProps props,
  TextStyle inherited,
) => [InlineWords(ItalicProps(props).text ?? '', _italic)];

const TextStyle _italic = TextStyle(fontStyle: FontStyle.italic);

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
