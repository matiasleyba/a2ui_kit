import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The standard `Link`: `text` (or the `href` itself) in the info colour,
/// opening `href` in a new tab. Only http, https and mailto URLs open;
/// with any other the text shows as plain text. `title` is the tooltip.
/// Screen readers also hear "opens in a new tab", as in CopilotKit.
Widget buildLink(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = LinkProps(props);
  final rawHref = view.href ?? '';
  final href = safeHref(rawHref);
  final text = view.text;
  final label = text == null || text.isEmpty ? rawHref : text;
  final title = view.title;
  final theme = A2uiKitScope.themeOf(context);
  Widget link;
  if (href == null) {
    link = Text(label);
  } else {
    final underline = theme.typography.linkUnderline;
    void open() => unawaited(openSafeUrl(context, href));
    link = Semantics(
      link: true,
      label: '$label (opens in a new tab)',
      onTap: open,
      child: ExcludeSemantics(
        // An <a href>: Tab reaches it and Enter opens it.
        child: Activatable(
          onActivate: open,
          borderRadius: BorderRadius.circular(2),
          child: Text(
            label,
            style: TextStyle(
              color: theme.color(A2uiColorToken.textInfo),
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: theme.color(A2uiColorToken.textInfo),
            ),
          ),
        ),
      ),
    );
  }
  if (title != null && title.isNotEmpty) {
    link = Tooltip(message: title, child: link);
  }
  return link;
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
