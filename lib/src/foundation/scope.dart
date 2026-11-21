import 'package:a2ui_kit/src/catalog_options.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/widgets.dart';

/// Where a component sits relative to the nearest Card: CopilotKit's
/// `CardNestingContext` and `CardDistanceContext`.
///
/// A surface has one bordered level, the outer Card. Inside it, containers
/// flatten into borderless columns or the one inner panel, and their
/// default gap follows the distance from the Card: 16px directly inside it,
/// 8px deeper.
@immutable
class CardPosition {
  /// A position [distance] containers below a Card ([nested]), or outside
  /// any Card.
  const CardPosition({required this.nested, required this.distance});

  /// Outside every Card.
  static const CardPosition outside = CardPosition(
    nested: false,
    distance: null,
  );

  /// Whether a Card is above.
  final bool nested;

  /// The count of containers from the nearest Card (0 directly in it), or
  /// null outside a Card.
  final int? distance;

  /// The position of a container's children: one container deeper.
  CardPosition get child => CardPosition(
    nested: nested,
    distance: distance == null ? null : distance! + 1,
  );

  /// The default gap of a container here, in spacing steps: 4 (16px) at the
  /// top level and directly in a Card, 2 (8px) deeper.
  int get defaultGapSteps => distance == null || distance == 0 ? 4 : 2;

  @override
  bool operator ==(Object other) =>
      other is CardPosition &&
      other.nested == nested &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(nested, distance);
}

/// Publishes a [CardPosition] to a subtree.
class CardScope extends InheritedWidget {
  /// Publishes [position] to [child].
  const CardScope({required this.position, required super.child, super.key});

  /// The position of the subtree.
  final CardPosition position;

  /// The position at [context], [CardPosition.outside] without a scope.
  static CardPosition of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardScope>()?.position ??
      CardPosition.outside;

  @override
  bool updateShouldNotify(CardScope oldWidget) =>
      position != oldWidget.position;
}

/// The options and theme every a2ui_kit component of a surface reads.
///
/// The first a2ui_kit component of a surface installs it, with the base
/// text style of the theme, so a surface needs no wrapper widget.
class A2uiKitScope extends InheritedWidget {
  /// Publishes [options] and [theme] to [child].
  const A2uiKitScope({
    required this.options,
    required this.theme,
    required super.child,
    super.key,
  });

  /// The catalog's options.
  final A2uiKitOptions options;

  /// The resolved theme.
  final A2uiKitTheme theme;

  /// The scope above [context], or null.
  static A2uiKitScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<A2uiKitScope>();

  /// The theme at [context]: the scope's, or else [A2uiKitTheme.of].
  static A2uiKitTheme themeOf(BuildContext context) =>
      maybeOf(context)?.theme ?? A2uiKitTheme.of(context);

  @override
  bool updateShouldNotify(A2uiKitScope oldWidget) =>
      options != oldWidget.options || theme != oldWidget.theme;
}

/// Wraps [child] in the surface's [A2uiKitScope] and base text style,
/// unless an a2ui_kit component above has done so.
///
/// The base text style: in a look that inherits the host's type
/// (`A2uiKitTypography.inheritsHostType`, the standard look's
/// `.a2ui-surface{font:inherit;color:inherit}`), the app's own
/// `DefaultTextStyle` around the surface, the theme's size and text colour
/// standing in where it gives none; else the page a CopilotKit surface
/// inherits its type from: the theme's font size, line height and family,
/// in the default text colour.
///
/// When the root is a [block] container (a Column, a Card, a Markdown
/// answer), each piece inside it is a node of its own for screen readers,
/// in the surface's order, as a browser reads the page's text and elements
/// where they are: a Text merged into the node above it would be read
/// before every formula, table and code block beside it. A button, a link
/// or a table cell still takes the text inside it as its name (their nodes
/// are their own); a root that takes its name from its content (a Button)
/// keeps it.
Widget wrapKitRoot(
  BuildContext context,
  A2uiKitOptions options,
  Widget child, {
  bool block = false,
}) {
  if (context.getInheritedWidgetOfExactType<A2uiKitScope>() != null) {
    return child;
  }
  final theme = A2uiKitTheme.of(context, look: options.look);
  final type = theme.typography;
  final host = DefaultTextStyle.of(context).style;
  return A2uiKitScope(
    options: options,
    theme: theme,
    child: Semantics(
      explicitChildNodes: block,
      child: DefaultTextStyle.merge(
        style: type.inheritsHostType
            ? TextStyle(
                color: host.color == null
                    ? theme.color(A2uiColorToken.textDefault)
                    : null,
                fontSize: host.fontSize == null ? type.fontSize : null,
                decoration: TextDecoration.none,
              )
            : TextStyle(
                color: theme.color(A2uiColorToken.textDefault),
                fontSize: type.fontSize,
                height: type.lineHeight,
                fontFamily: type.fontFamily,
                fontFamilyFallback: type.fontFamilyFallback,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
        child: child,
      ),
    ),
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx (CardNestingContext, CardDistanceContext)
