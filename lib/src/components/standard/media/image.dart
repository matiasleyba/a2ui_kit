import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/components/standard/layout/container_css.dart';
import 'package:a2ui_kit/src/components/standard/media/html_image_size.dart'
    if (dart.library.js_interop) 'package:a2ui_kit/src/components/standard/media/html_image_size_web.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/css/css_length.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/interaction/envelope.dart';
import 'package:a2ui_kit/src/foundation/interaction/lightbox.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:a2ui_kit/src/foundation/layout/replaced_box.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The standard `Image`.
///
/// `variant` sizes it (`icon` 24px, `avatar` 40px round, `smallFeature` up
/// to 160px wide, `mediumFeature` its natural size, `largeFeature` the full
/// width, `header` the full width at 3:1); `width`, `height`, their limits
/// (4px steps) and `aspectRatio` override that. `fit` and `position` place
/// the picture in its box (CSS `object-fit` and `object-position`). A click
/// opens it full-screen unless `lightbox` is false.
///
/// If it fails to load, `hideOnFailure` hides it, `fallback` shows that
/// text in a grey box, and otherwise its `description` shows in its place
/// (a browser draws a broken-image sign). `actionOverlay` adds a pill
/// button over the bottom-right corner that opens its `href` or sends
/// `onOverlayClick`; `hoverZoom` zooms it 3% under the mouse.
Widget buildImage(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final url = ImageProps(props).url;
  if (url == null || url.isEmpty) return const SizedBox.shrink();
  return _ImageView(url: url, props: props);
}

/// The natural size of a loaded image [info] in logical pixels; [info] is
/// disposed (the stream hands each listener its own clone).
///
/// On the web, an image served without CORS headers falls back to an
/// `<img>` element, which gives no pixels: the element's own
/// `naturalWidth` and `naturalHeight` are read instead, and CSS's default
/// object size (300×150) stands in only when even that fails.
@visibleForTesting
Size naturalSizeOf(ImageInfo info) {
  try {
    return Size(info.image.width / info.scale, info.image.height / info.scale);
  } on Object {
    return htmlImageSize(info) ?? const Size(300, 150);
  } finally {
    info.dispose();
  }
}

class _ImageView extends StatefulWidget {
  const _ImageView({required this.url, required this.props});

  final String url;
  final ComponentProps props;

  @override
  State<_ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<_ImageView> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    onError: _onError,
  );
  Size? _natural;
  bool _failed = false;
  bool _hovered = false;

  // On the web, an image without CORS headers falls back to an <img>.
  ImageProvider get _provider => NetworkImage(
    widget.url,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_ImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _natural = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final natural = naturalSizeOf(info);
    if (!mounted) return;
    setState(() => _natural = natural);
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() => _failed = true);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final view = ImageProps(props);
    if (_failed && view.hideOnFailure) return const SizedBox.shrink();
    final theme = A2uiKitScope.themeOf(context);
    final fontSize = baseFontSize(context);
    final css = ContainerCss.layout(
      const ComponentProps({}),
      theme: theme,
      fontSize: fontSize,
    );
    final variant = view.variant;
    A2uiLength? steps(Object? value) => css.steps(value);
    final aspect = cssAspectRatio(props.value('aspectRatio'));
    final variantWidth = switch (variant) {
      ImageVariant.icon => const A2uiLength.px(24),
      ImageVariant.avatar => const A2uiLength.px(40),
      ImageVariant.smallFeature ||
      ImageVariant.largeFeature ||
      ImageVariant.header => const A2uiLength.percent(1),
      ImageVariant.mediumFeature => null,
    };
    final sizing = ReplacedSizing(
      width:
          steps(props.value('width')) ??
          (aspect != null ? const A2uiLength.percent(1) : variantWidth),
      height:
          steps(props.value('height')) ??
          switch (variant) {
            ImageVariant.icon => const A2uiLength.px(24),
            ImageVariant.avatar => const A2uiLength.px(40),
            _ => null,
          },
      minWidth: steps(props.value('minWidth')),
      minHeight: steps(props.value('minHeight')),
      maxWidth:
          steps(props.value('maxWidth')) ??
          (variant == ImageVariant.smallFeature
              ? const A2uiLength.px(160)
              : const A2uiLength.percent(1)),
      maxHeight: steps(props.value('maxHeight')),
      aspectRatio: aspect ?? (variant == ImageVariant.header ? 3 : null),
      fontSize: fontSize,
    );
    final radius =
        css.radiusOf(
          props.value('radius') ??
              switch (variant) {
                ImageVariant.icon => 'xs',
                ImageVariant.avatar => 'full',
                _ => null,
              },
        ) ??
        BorderRadius.zero;
    final alt = view.description ?? '';
    final fallback = view.fallback;
    // The `<img>` (or the fallback's `role="img"`) takes the envelope's
    // ARIA (media.tsx:194, :222, :248): it sits in NodeView's node while it
    // puts one there ([KitEnvelope.wrapped]), named by the envelope's label
    // over its alt text.
    final envelope = KitEnvelope.of(props);
    // Presentational (no image at all) for an empty alt with no envelope
    // name; the same widget either way (one tree shape, RULEBOOK §2).
    Widget asImage(String name, Widget child) {
      final isImage = name.isNotEmpty || envelope.names;
      return Semantics(
        image: isImage,
        container: isImage && !envelope.wrapped,
        label: envelope.label != null || name.isEmpty ? null : name,
        child: child,
      );
    }

    if (_failed && fallback != null && fallback.isNotEmpty) {
      final minHeight =
          steps(props.value('minHeight')) ?? const A2uiLength.px(64);
      return asImage(
        alt.isNotEmpty ? alt : fallback,
        ReplacedBox(
          sizing: ReplacedSizing(
            width: sizing.width ?? const A2uiLength.percent(1),
            height: sizing.height,
            minWidth: sizing.minWidth,
            minHeight: minHeight,
            maxWidth: sizing.maxWidth,
            maxHeight: sizing.maxHeight,
            aspectRatio: sizing.aspectRatio,
            fontSize: fontSize,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.backgroundColor(
                view.background ?? 'surface-secondary',
              ),
              borderRadius: radius,
            ),
            child: ExcludeSemantics(
              child: Text(
                fallback,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize * .875,
                  color: theme.color(A2uiColorToken.textSecondary),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_failed) {
      // Without a fallback the failed `<img alt>` stays (media.tsx:247-266),
      // an image named by its alt text: a browser draws a broken-image sign
      // and the description, which stands in for it here. An empty alt
      // makes it presentational, so nothing shows.
      if (alt.isEmpty && !envelope.names) return const SizedBox.shrink();
      return asImage(
        alt,
        ExcludeSemantics(
          child: Text(
            alt,
            style: TextStyle(color: theme.color(A2uiColorToken.textSecondary)),
          ),
        ),
      );
    }

    final showsLightbox = view.lightbox;
    // The Image's own semantics are the `<img>`'s, given above it
    // ([asImage]); its semantic label stays the alt text it is read by.
    Widget image = Image(
      image: _provider,
      fit: _boxFit(view.fit),
      alignment: objectPosition(view.position),
      semanticLabel: alt.isEmpty ? null : alt,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
    image = asImage(alt, image);
    final background = theme.backgroundColor(view.background);
    final frame = view.frame ?? false;
    if (background != null) {
      image = DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: radius),
        child: image,
      );
    }
    if (view.hoverZoom ?? false) {
      image = AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.ease,
        child: image,
      );
    }
    image = ClipRRect(borderRadius: radius, child: image);
    if (frame) {
      image = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: theme.color(A2uiColorToken.borderDefault)),
          borderRadius: radius,
        ),
        child: image,
      );
    }
    image = ReplacedBox(sizing: sizing, naturalSize: _natural, child: image);
    if (showsLightbox) {
      image = MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: GestureDetector(
          onTap: () => unawaited(
            showLightbox(
              context,
              [LightboxImage(url: widget.url, alt: alt)],
              hidden: envelope.hidden,
              live: envelope.live,
            ),
          ),
          child: image,
        ),
      );
    }
    final overlay = view.actionOverlay;
    final hoverZoom = view.hoverZoom ?? false;
    if (overlay == null && !hoverZoom) return image;
    image = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: image,
    );
    if (overlay == null) return image;
    // The wrapper's overflow shows unless `hoverZoom` hides it
    // (media.tsx:268-277), so the absolutely placed button stays drawn
    // where it overflows a small picture.
    final children = <Widget>[
      image,
      Positioned(
        right: 8,
        bottom: 8,
        child: _OverlayButton(
          label: ComponentProps.asString(overlay['label']) ?? '',
          icon: ComponentProps.asString(overlay['icon']),
          onTap: () {
            final href = ComponentProps.asString(overlay['href']);
            if (href != null && href.isNotEmpty) {
              unawaited(openSafeUrl(context, href));
            } else {
              unawaited(props.action('onOverlayClick')?.call());
            }
          },
        ),
      ),
    ];
    // TODO(port): where the button overflows, the browser hit-tests it too;
    // a Flutter box takes no hit outside its own size, and every box between
    // the Column and this Stack (NodeView's Semantics among them) has the
    // picture's, so a tap there is refused (queued in
    // data_media_parity_test.dart, INV-262).
    return Stack(
      clipBehavior: hoverZoom ? Clip.hardEdge : Clip.none,
      children: children,
    );
  }
}

/// CSS `object-fit` as a [BoxFit].
BoxFit _boxFit(ImageFit fit) => switch (fit) {
  ImageFit.cover => BoxFit.cover,
  ImageFit.contain => BoxFit.contain,
  ImageFit.fill => BoxFit.fill,
  ImageFit.none => BoxFit.none,
  ImageFit.scaleDown => BoxFit.scaleDown,
};

/// CSS `object-position` (keywords and percentages: `top`, `left bottom`,
/// `50% 20%`) as an [Alignment]; the centre for anything else.
Alignment objectPosition(String? position) {
  if (position == null) return Alignment.center;
  final parts = position.trim().toLowerCase().split(RegExp(r'\s+'));
  double? x;
  double? y;
  double? percent(String part) {
    final match = RegExp(r'^(-?\d*\.?\d+)%$').firstMatch(part);
    return match == null ? null : double.parse(match[1]!) / 50 - 1;
  }

  for (var i = 0; i < parts.length && i < 2; i++) {
    final part = parts[i];
    switch (part) {
      case 'left':
        x = -1;
      case 'right':
        x = 1;
      case 'top':
        y = -1;
      case 'bottom':
        y = 1;
      case 'center':
        if (i == 0 && parts.length == 1) {
          x = 0;
          y = 0;
        }
      default:
        final value = percent(part);
        if (value == null) return Alignment.center;
        if (i == 0) {
          x = value;
        } else {
          y = value;
        }
    }
  }
  return Alignment(x ?? 0, y ?? 0);
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.label, required this.onTap, this.icon});

  final String label;
  final String? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    final onAccent = theme.color(A2uiColorToken.onAccent);
    final iconData = lucideIcon(icon, release: LucideRelease.reactCore);
    return Semantics(
      // A `<button>` of its own beside the `<img>` (media.tsx:286-318).
      container: true,
      button: true,
      // A <button>: Tab reaches it and Enter presses it.
      child: Activatable(
        onActivate: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.color(A2uiColorToken.overlay),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (iconData != null)
                LucideGlyph(iconData, size: 14, color: onAccent),
              Text(
                label,
                style: TextStyle(
                  color: onAccent,
                  fontSize: baseFontSize(context) * .8125,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=medium todos=1 upstream=packages/react-core/src/v2/generative-ui/standard/media.tsx
