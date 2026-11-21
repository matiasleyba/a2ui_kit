import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// One image of a [showLightbox] view.
@immutable
class LightboxImage {
  /// The image at [url], described by [alt].
  const LightboxImage({required this.url, this.alt});

  /// The image URL.
  final String url;

  /// What the image shows.
  final String? alt;
}

/// Opens CopilotKit's full-screen image view over the app: the image
/// centred on the backdrop (at most 92% of the screen, 1400px wide), with
/// a close button; with several images, arrows, the arrow keys and an
/// "n / count" counter move between them. A click, Escape or the close
/// button closes it.
///
/// It is a route of the nearest root [Navigator], so Escape closes the
/// newest overlay first. To a screen reader it is a modal dialog named by
/// the image's description (`role="dialog"`, lightbox.tsx:93-99); being a
/// portal, it takes the opening component's envelope [hidden] state and
/// [live] region itself (`wrapperAria`, lightbox.tsx:45-47, :97).
Future<void> showLightbox(
  BuildContext context,
  List<LightboxImage> images, {
  int index = 0,
  bool hidden = false,
  bool live = false,
}) {
  final theme = A2uiKitScope.themeOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: theme.color(A2uiColorToken.backdrop),
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => _Lightbox(
      images: images,
      index: index,
      theme: theme,
      hidden: hidden,
      live: live,
    ),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({
    required this.images,
    required this.index,
    required this.theme,
    required this.hidden,
    required this.live,
  });

  final List<LightboxImage> images;
  final int index;
  final A2uiKitTheme theme;
  final bool hidden;
  final bool live;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _current = widget.index.clamp(0, widget.images.length - 1);

  void _step(int delta) {
    final count = widget.images.length;
    if (count < 2) return;
    setState(() => _current = (_current + delta + count) % count);
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final count = widget.images.length;
    if (count == 0) return const SizedBox.shrink();
    final image = widget.images[_current];
    final onAccent = theme.color(A2uiColorToken.onAccent);
    final screen = MediaQuery.sizeOf(context);
    Widget button({
      required String label,
      required String glyph,
      required double size,
      required double fontSize,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x26ffffff),
            shape: BoxShape.circle,
          ),
          child: ExcludeSemantics(
            child: Text(
              glyph,
              style: TextStyle(color: onAccent, fontSize: fontSize, height: 1),
            ),
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
      },
      child: Focus(
        autofocus: true,
        // A route's semantics scope holds its content as nodes of their
        // own (Flutter asserts `explicitChildNodes` with `scopesRoute`).
        child: ExcludeSemantics(
          excluding: widget.hidden,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            role: SemanticsRole.dialog,
            liveRegion: widget.live ? true : null,
            label: (image.alt?.isNotEmpty ?? false) ? image.alt : 'Image',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: MouseRegion(
                cursor: SystemMouseCursors.zoomOut,
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: theme.typography.fontFamily,
                    fontFamilyFallback: theme.typography.fontFamilyFallback,
                    fontWeight: FontWeight.w400,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: (screen.width * .92).clamp(0, 1400),
                                maxHeight: screen.height * .92,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    theme.radius('md') ?? 8,
                                  ),
                                  boxShadow: theme.shadow(A2uiShadowToken.md),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    theme.radius('md') ?? 8,
                                  ),
                                  child: Image.network(
                                    image.url,
                                    key: ValueKey(image.url),
                                    fit: BoxFit.contain,
                                    semanticLabel: image.alt,
                                    webHtmlElementStrategy:
                                        WebHtmlElementStrategy.fallback,
                                    errorBuilder: (context, error, stack) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (count > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Opacity(
                              opacity: .8,
                              child: Text(
                                '${_current + 1} / $count',
                                style: TextStyle(color: onAccent, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      if (count > 1) ...[
                        Positioned(
                          left: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: button(
                              label: 'Previous image',
                              glyph: '‹',
                              size: 44,
                              fontSize: 28,
                              onTap: () => _step(-1),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: button(
                              label: 'Next image',
                              glyph: '›',
                              size: 44,
                              fontSize: 28,
                              onTap: () => _step(1),
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        top: 16,
                        right: 16,
                        child: button(
                          label: 'Close',
                          glyph: '×',
                          size: 36,
                          fontSize: 20,
                          onTap: _close,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/lightbox.tsx
