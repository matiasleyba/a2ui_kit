import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/components/standard/layout/flex_container.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/widgets.dart';

/// The CSS of a container's layout props at [context].
ContainerCss containerCss(BuildContext context, ComponentProps props) {
  final theme = A2uiKitScope.themeOf(context);
  return ContainerCss.layout(
    props,
    theme: theme,
    fontSize:
        DefaultTextStyle.of(context).style.fontSize ??
        theme.typography.fontSize,
  );
}

/// CopilotKit's `container()`: the default gap of the container's depth in
/// a Card, and inside a Card a background in the lighter panel palette.
void containerDefaults(
  ContainerCss css,
  ComponentProps props,
  CardPosition position,
) {
  if (!css.hasGap) css.gap = css.steps(position.defaultGapSteps);
  final background = props.string('background');
  if (position.nested && background != null) {
    css.background = css.theme.panelBackground(background);
  }
}

/// CopilotKit's `innerPanelStyle`: 12px padding, an 8px radius, the panel
/// fill, no border and no shadow.
void _innerPanel(ContainerCss css, ComponentProps props, String? background) {
  final theme = css.theme;
  css
    ..padding = css.insets(props.value('padding') ?? 3)
    ..radius = BorderRadius.circular(theme.radius('md') ?? 8)
    ..background =
        theme.panelBackground(background) ?? theme.color(A2uiColorToken.panel)
    ..removeBox();
}

/// The standard `Box`: a flex column, or a row with `direction: "row"`.
/// Inside a Card, a bordered Box becomes the Card's inner panel.
Widget buildBox(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final position = CardScope.of(context);
  final css = containerCss(context, props);
  containerDefaults(css, props, position);
  css.direction = BoxProps(props).direction == BoxDirection.row
      ? Axis.horizontal
      : Axis.vertical;
  if (position.nested && (props.boolean('border') ?? false)) {
    _innerPanel(css, props, props.string('background'));
  }
  return flexContainer(
    context,
    props: props,
    css: css,
    children: props.children('children'),
    buildChild: buildChild,
    childPosition: position.child,
  );
}

/// The standard `Column`: a vertical flex container.
Widget buildColumn(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final position = CardScope.of(context);
  final css = containerCss(context, props);
  containerDefaults(css, props, position);
  css.direction = Axis.vertical;
  return flexContainer(
    context,
    props: props,
    css: css,
    children: props.children('children'),
    buildChild: buildChild,
    childPosition: position.child,
  );
}

/// The standard `Row`: a horizontal flex container whose children are
/// centred on the cross axis and 8px apart. In a `spaceBetween` Row the
/// last Text sits flush right.
Widget buildRow(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final position = CardScope.of(context);
  final css = containerCss(context, props);
  containerDefaults(css, props, position);
  css
    ..direction = Axis.horizontal
    ..align = css.align ?? A2uiAlign.center;
  if (!css.hasGap) css.gap = css.steps(2);
  return flexContainer(
    context,
    props: props,
    css: css,
    children: props.children('children'),
    buildChild: buildChild,
    childPosition: position.child,
    isRow: true,
  );
}

/// The padding of a Card by size, in 4px steps: 8, 16 or 24px.
int _cardPadding(A2uiSize size) => switch (size) {
  A2uiSize.sm => 2,
  A2uiSize.md => 4,
  A2uiSize.lg => 6,
};

/// The standard `Card`: a bordered panel at the top level, flattened inside
/// another Card unless its variant is `outline`; `section` draws no box.
/// Its single `child` comes before its `children`.
Widget buildCard(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = CardProps(props);
  final position = CardScope.of(context);
  final nested = position.nested;
  final css = containerCss(context, props)..direction = Axis.vertical;
  final theme = css.theme;
  final variant = view.variant;
  final background = props.string('background');

  if (variant == CardVariant.section) {
    // A section is a heading and its content: no box, no fill, no padding.
    if (!css.hasGap) css.gap = css.steps(4);
    css
      ..padding = props.value('padding') != null
          ? css.insets(props.value('padding'))
          : EdgeInsets.zero
      ..removeBox()
      ..radius = BorderRadius.zero
      ..background = background != null && background.isNotEmpty
          ? theme.backgroundColor(background)
          : null;
  } else {
    final ownBackground =
        background ??
        (variant == CardVariant.soft ? 'surface-secondary' : null);
    final flattened = nested && variant != CardVariant.outline;
    if (flattened) {
      if (!css.hasGap) css.gap = css.steps(3);
      css.removeBox();
      if (ownBackground != null && ownBackground != 'transparent') {
        _innerPanel(css, props, ownBackground);
      } else {
        css
          ..padding = EdgeInsets.zero
          ..background = null
          ..radius = BorderRadius.zero;
      }
    } else {
      if (!css.hasGap) css.gap = css.steps(4);
      final flush = props.boolean('flush') ?? false;
      css.padding = flush
          ? EdgeInsets.zero
          : css.insets(props.value('padding') ?? _cardPadding(view.size));
      final radius = props.value('radius');
      if (radius is! Map) css.radius = css.radiusOf(radius ?? 'xl');
      css.borderColor = variant == CardVariant.transparent
          ? null
          : theme.borderColor(props.string('borderColor') ?? 'default');
      if (ownBackground != null) {
        css.background = theme.backgroundColor(ownBackground);
      } else if (variant == CardVariant.transparent) {
        css.background = null;
      }
      switch (view.shadowStyle) {
        case CardShadowStyle.md:
          css.shadow = theme.shadow(A2uiShadowToken.md);
        case CardShadowStyle.sm:
          css.shadow = theme.shadow(A2uiShadowToken.sm);
        case CardShadowStyle.none:
          css.shadow = null;
        case null:
          if (variant == CardVariant.elevated) {
            css.shadow = theme.shadow(A2uiShadowToken.soft);
          }
      }
    }
  }

  final single = props.child('child');
  return flexContainer(
    context,
    props: props,
    css: css,
    children: [?single, ...props.children('children')],
    buildChild: buildChild,
    childPosition: CardPosition(
      nested: !(variant == CardVariant.section) || nested,
      distance: 0,
    ),
  );
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
