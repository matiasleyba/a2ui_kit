import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/layout/box_style.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/painting.dart';

/// The CSS of a container, property by property, as CopilotKit's React
/// renderer builds its inline style: [ContainerCss.layout] is
/// `layoutStyle(props)`, and each component then overrides properties the
/// way its own style function does.
class ContainerCss {
  /// The CSS of the shared layout props of [props] (`layoutStyle`): an
  /// unset prop gives no CSS.
  ContainerCss.layout(
    ComponentProps props, {
    required this.theme,
    required this.fontSize,
  }) {
    inline = props.boolean('inline') ?? false;
    align = A2uiAlign.fromWire(props.value('align'));
    justify = A2uiJustify.fromWire(props.value('justify'));
    wrap = A2uiWrap.fromWire(props.value('wrap')) ?? A2uiWrap.nowrap;
    final disableAutoSpacing = props.boolean('disableAutoSpacing') ?? false;
    gap =
        steps(props.value('gap')) ??
        (disableAutoSpacing ? A2uiLength.zero : null);
    rowGap = steps(props.value('rowGap'));
    columnGap = steps(props.value('columnGap'));
    hasGap =
        props.value('gap') != null ||
        props.value('rowGap') != null ||
        props.value('columnGap') != null ||
        disableAutoSpacing;
    padding = (props.boolean('flush') ?? false)
        ? EdgeInsets.zero
        : insets(props.value('padding'));
    background = theme.backgroundColor(props.string('background'));
    if (props.boolean('border') ?? false) {
      borderColor = theme.borderColor(props.string('borderColor') ?? 'default');
    }
    radius = radiusOf(props.value('radius'));
    width = steps(props.value('width'));
    height = steps(props.value('height'));
    minWidth =
        steps(props.value('minWidth') ?? props.value('minSize')) ??
        A2uiLength.zero;
    maxWidth =
        steps(props.value('maxWidth') ?? props.value('maxSize')) ??
        const A2uiLength.percent(1);
    minHeight = steps(props.value('minHeight') ?? props.value('minSize'));
    maxHeight = steps(props.value('maxHeight') ?? props.value('maxSize'));
    aspectRatio = cssAspectRatio(props.value('aspectRatio'));
    scroll = props.boolean('scrollable') ?? false;
    clip = !scroll && (props.boolean('clip') ?? false);
    if (props.boolean('shadow') ?? false) {
      shadow = theme.shadow(A2uiShadowToken.sm);
    }
  }

  /// The theme the colours and radii come from.
  final A2uiKitTheme theme;

  /// The font size `em` lengths resolve against.
  final double fontSize;

  /// `flex-direction`; CSS's default is `row`.
  Axis direction = Axis.horizontal;

  /// `display: inline-flex`.
  bool inline = false;

  /// `align-items`.
  A2uiAlign? align;

  /// `justify-content`.
  A2uiJustify? justify;

  /// `flex-wrap`.
  A2uiWrap wrap = A2uiWrap.nowrap;

  /// Whether any gap prop is set: then no default gap applies.
  bool hasGap = false;

  /// The `gap` shorthand, or null for `normal` (0 in a flex container).
  A2uiLength? gap;

  /// `row-gap`, over [gap].
  A2uiLength? rowGap;

  /// `column-gap`, over [gap].
  A2uiLength? columnGap;

  /// `padding`.
  EdgeInsets padding = EdgeInsets.zero;

  /// `background`.
  Color? background;

  /// The colour of a 1px solid `border`, or null for none.
  Color? borderColor;

  /// `border-radius`.
  BorderRadiusGeometry? radius;

  /// `box-shadow`.
  List<BoxShadow>? shadow;

  /// `width`.
  A2uiLength? width;

  /// `height`.
  A2uiLength? height;

  /// `min-width` (0 unless set).
  A2uiLength? minWidth;

  /// `max-width` (100% unless set).
  A2uiLength? maxWidth;

  /// `min-height`.
  A2uiLength? minHeight;

  /// `max-height`.
  A2uiLength? maxHeight;

  /// `aspect-ratio`.
  double? aspectRatio;

  /// `overflow: auto`.
  bool scroll = false;

  /// `overflow: hidden`.
  bool clip = false;

  /// A layout length of [value]: a number is spacing steps.
  A2uiLength? steps(Object? value) =>
      _em(A2uiLength.steps(value, step: theme.spacingStep));

  A2uiLength? _em(A2uiLength? length) => length is A2uiEm
      ? A2uiLength.px(length.resolve(fontSize: fontSize))
      : length;

  /// The padding of [value]: a number is spacing steps; CSS otherwise.
  EdgeInsets insets(Object? value) =>
      cssInsets(value, step: theme.spacingStep, fontSize: fontSize) ??
      EdgeInsets.zero;

  /// The radius of a `radius` prop: one radius, or one per corner
  /// (CopilotKit's `radiusStyle`, layout.tsx:96-108). A string that is no
  /// token passes through as CSS (`radius`, tokens.ts:175-183): the
  /// `border-radius` shorthand, or a corner's longhand.
  BorderRadiusGeometry? radiusOf(Object? value) {
    if (value is Map) {
      Radius corner(Object? raw) {
        final unwrapped = ComponentProps.unwrap(raw);
        final pixels = theme.radius(unwrapped, fontSize: fontSize);
        if (pixels != null) return Radius.circular(pixels);
        return unwrapped is String
            ? cssCornerRadius(unwrapped, fontSize: fontSize) ?? Radius.zero
            : Radius.zero;
      }

      return BorderRadius.only(
        topLeft: corner(value['topLeft']),
        topRight: corner(value['topRight']),
        bottomLeft: corner(value['bottomLeft']),
        bottomRight: corner(value['bottomRight']),
      );
    }
    final pixels = theme.radius(value, fontSize: fontSize);
    if (pixels != null) return BorderRadius.circular(pixels);
    return value is String ? cssBorderRadius(value, fontSize: fontSize) : null;
  }

  /// Drops the border and the shadow, as a flattened Card and the inner
  /// panel do.
  void removeBox() {
    borderColor = null;
    shadow = null;
  }

  /// The container's box.
  A2uiBoxStyle toBox() {
    final hasDecoration =
        background != null ||
        borderColor != null ||
        shadow != null ||
        (clip && radius != null);
    return A2uiBoxStyle(
      padding: padding,
      borderWidth: borderColor == null ? 0 : 1,
      decoration: hasDecoration
          ? BoxDecoration(
              color: background,
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!),
              borderRadius: radius,
              boxShadow: shadow,
            )
          : null,
      width: width,
      height: height,
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      aspectRatio: aspectRatio,
      fill: !inline,
      clip: clip,
    );
  }

  /// The container's flex layout.
  A2uiFlexStyle toFlex() => A2uiFlexStyle(
    direction: direction,
    wrap: wrap,
    justify: justify,
    align: align,
    rowGap: (rowGap ?? gap)?.resolve(fontSize: fontSize) ?? 0,
    columnGap: (columnGap ?? gap)?.resolve(fontSize: fontSize) ?? 0,
  );
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx
