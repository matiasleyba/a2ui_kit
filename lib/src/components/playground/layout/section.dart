import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/playground/common.dart';
import 'package:a2ui_kit/src/components/playground/content/heading.dart';
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/components/standard/layout/flex_container.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/widgets.dart';

/// The playground `Section`: a borderless group with a title (15px,
/// semibold), an `eyebrow` after it on the same line, a `description`
/// (12.5px, muted) and its `children` in a column, 12px apart.
Widget buildSection(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = SectionProps(props);
  final tokens = playgroundTokens(context);
  final theme = A2uiKitScope.themeOf(context);
  final eyebrow = view.eyebrow;
  final description = view.description;
  final css =
      ContainerCss.layout(
          const ComponentProps({}),
          theme: theme,
          fontSize:
              DefaultTextStyle.of(context).style.fontSize ??
              theme.typography.fontSize,
        )
        ..direction = Axis.vertical
        ..gap = const A2uiLength.px(12);
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          TitleLine(
            title: Semantics(
              header: true,
              child: Text(
                view.title ?? '',
                style: playgroundText(
                  15,
                  weight: FontWeight.w600,
                  trackingEm: -.025,
                  color: tokens.foreground,
                ),
              ),
            ),
            eyebrow: eyebrow == null || eyebrow.isEmpty
                ? null
                : Text(eyebrow, style: playgroundLabelStyle(tokens)),
          ),
          if (description != null && description.isNotEmpty)
            Text(
              description,
              style: playgroundText(
                12.5,
                height: 1.625,
                color: tokens.mutedForeground,
              ),
            ),
        ],
      ),
      flexContainer(
        context,
        props: props,
        css: css,
        children: view.children,
        buildChild: buildChild,
        childPosition: CardScope.of(context),
        wired: false,
      ),
    ],
  );
}

// PORT STATUS: confidence=high todos=0 upstream=examples/showcases/a2ui-playground/src/a2ui/catalog/renderers/layout.tsx
