import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/text/inline_element.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:flutter/widgets.dart';

/// The standard `Bold`: `text` as written (no markdown) in a `<strong>`.
///
/// Without `fontWeight` it is `font-weight: bolder` over the weight it
/// inherits (700 over a Text's 400, 900 over a strong Text's 600: the
/// user-agent rule, Chromium 159.0.8154.13 html.css:1666-1668); `fontWeight`
/// (`normal`, `medium`, `semibold`, `bold`) sets the weight instead
/// (react-core standard/text.tsx:286-298). Size, colour and line height are
/// the surrounding text's: inside a Text its words continue the Text's line
/// and break with it ([boldRuns]), elsewhere it is a block of its own.
Widget buildBold(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => InlineElementText(
  text: BoldProps(props).text,
  style: (inherited) => _boldStyle(props, inherited),
);

/// The words a Bold gives the line of the Text holding it.
List<InlineRun> boldRuns(
  BuildContext context,
  ComponentProps props,
  TextStyle inherited,
) => [InlineWords(BoldProps(props).text ?? '', _boldStyle(props, inherited))];

TextStyle _boldStyle(ComponentProps props, TextStyle inherited) {
  final weight = BoldProps(props).fontWeight;
  return TextStyle(
    fontWeight: weight != null
        ? fontWeightOf(weight)
        : bolder(inherited.fontWeight ?? FontWeight.w400),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
