import 'dart:async';

import 'package:a2ui_kit/src/foundation/interaction/focus_visible.dart';
import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_markdown.dart';
import 'package:a2ui_kit/src/foundation/text/text_styles.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The links of a run of text, each an `<a href>` (RULEBOOK section 2):
/// tapped through its span's recognizer, and, since a span cannot hold the
/// focus, reached by Tab and opened by Enter through a focus node of its
/// own in an empty widget over the text ([overlay]); the focused link whose
/// focus shows ([FocusVisibility]) is drawn with a focus tint ([style]).
///
/// The one mapping of a link inside text: a Text's inline links and a
/// Markdown answer's links use it.
class KitLinkTargets {
  /// Links whose focus changes call [onChanged], to draw the tint.
  KitLinkTargets({required this.onChanged});

  /// Called when a link's focus starts or stops showing.
  final VoidCallback onChanged;

  final List<TapGestureRecognizer> _recognizers = [];

  /// One focus node per link: as an `<a href>`, Tab reaches each link and
  /// Enter opens it.
  final List<FocusNode> _focusNodes = [];

  /// Each link's `:focus-visible`.
  final List<FocusVisibility> _visibilities = [];

  /// Whether the [index]th link's focus shows.
  bool focused(int index) =>
      index < _visibilities.length && _visibilities[index].visible;

  /// The recognizer of the [index]th link, reused across builds so that a
  /// tap in progress survives a rebuild.
  TapGestureRecognizer recognizer(int index) {
    while (_recognizers.length <= index) {
      _recognizers.add(TapGestureRecognizer());
    }
    return _recognizers[index];
  }

  FocusNode _focusNode(int index) {
    while (_focusNodes.length <= index) {
      final node = FocusNode(debugLabel: 'a2ui link ${_focusNodes.length}');
      _focusNodes.add(node);
      _visibilities.add(FocusVisibility(node)..addListener(onChanged));
    }
    return _focusNodes[index];
  }

  void _disposeLast() {
    _visibilities.removeLast()
      ..removeListener(onChanged)
      ..dispose();
    _focusNodes.removeLast().dispose();
  }

  /// Drops the links from the [count]th on, which the text no longer has.
  void keep(int count) {
    while (_recognizers.length > count) {
      _recognizers.removeLast().dispose();
    }
    while (_focusNodes.length > count) {
      _disposeLast();
    }
  }

  /// Releases every link.
  void dispose() => keep(0);

  /// The style of the [index]th link's text over [base], the text's own
  /// style: the theme's link colour, underlined as the theme says or while
  /// its focus shows, and tinted while its focus shows.
  TextStyle style(
    BuildContext context,
    int index, {
    required TextDecoration? base,
    Color? color,
    bool underline = false,
  }) {
    final theme = A2uiKitScope.themeOf(context);
    final focused = this.focused(index);
    return TextStyle(
      color: color,
      decoration: underline || focused
          ? combine(base, TextDecoration.underline)
          : null,
      backgroundColor: focused
          ? theme.color(A2uiColorToken.focus).withValues(alpha: .2)
          : null,
    );
  }

  /// [base] with [added] drawn too.
  static TextDecoration combine(TextDecoration? base, TextDecoration added) =>
      base == null || base == TextDecoration.none
      ? added
      : TextDecoration.combine([base, added]);

  /// [child] with an empty focusable widget over it for each of [hrefs] in
  /// order: Tab reaches each, Enter and Space open it.
  Widget overlay(BuildContext context, Widget child, List<String?> hrefs) {
    if (hrefs.isEmpty) return child;
    return Stack(
      children: [
        child,
        for (var i = 0; i < hrefs.length; i++)
          Positioned(
            left: 0,
            top: 0,
            child: FocusableActionDetector(
              focusNode: _focusNode(i),
              includeFocusSemantics: false,
              shortcuts: activateShortcuts,
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) => _open(context, hrefs[i]),
                ),
              },
              child: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  /// Opens [href] when it is safe.
  static void open(BuildContext context, String? href) => _open(context, href);

  static void _open(BuildContext context, String? href) {
    final safe = safeHref(href);
    if (safe != null) unawaited(openSafeUrl(context, safe));
  }
}

/// Text of inline markdown segments, with tappable links, followed by
/// [trailing] spans (a Text's inline children).
class InlineText extends StatefulWidget {
  /// Shows [segments] in [style].
  const InlineText({
    required this.segments,
    this.style,
    this.trailing = const [],
    this.textAlign,
    this.maxLines,
    this.softWrap = true,
    this.overflow,
    super.key,
  });

  /// The parsed text.
  final List<InlineSegment> segments;

  /// The style over the inherited text style.
  final TextStyle? style;

  /// Spans after the text.
  final List<InlineSpan> trailing;

  /// The alignment.
  final TextAlign? textAlign;

  /// The most lines shown; the last ends with an ellipsis.
  final int? maxLines;

  /// Whether lines wrap.
  final bool softWrap;

  /// How overflowing text ends.
  final TextOverflow? overflow;

  @override
  State<InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<InlineText> {
  late final KitLinkTargets _links = KitLinkTargets(
    onChanged: () => setState(() {}),
  );

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var links = 0;
    final hrefs = <String>[];
    final inherited = DefaultTextStyle.of(context).style.merge(widget.style);
    final theme = A2uiKitScope.themeOf(context);
    final type = theme.typography;
    final fontSize = inherited.fontSize ?? type.fontSize;
    final spans = <InlineSpan>[];
    for (final segment in widget.segments) {
      switch (segment) {
        case InlinePlain(:final text):
          spans.add(TextSpan(text: text));
        case InlineMarked(:final text, :final mark):
          spans.add(
            TextSpan(
              text: text,
              style: switch (mark) {
                InlineMark.strong => TextStyle(
                  fontWeight: bolder(inherited.fontWeight ?? FontWeight.w400),
                ),
                InlineMark.emphasis => const TextStyle(
                  fontStyle: FontStyle.italic,
                ),
                InlineMark.strike => TextStyle(
                  decoration: KitLinkTargets.combine(
                    inherited.decoration,
                    TextDecoration.lineThrough,
                  ),
                ),
                InlineMark.underline => TextStyle(
                  decoration: KitLinkTargets.combine(
                    inherited.decoration,
                    TextDecoration.underline,
                  ),
                ),
                InlineMark.code => TextStyle(
                  fontFamily: type.monoFontFamily,
                  fontFamilyFallback: type.monoFontFamilyFallback,
                  fontSize: fontSize * type.inlineCodeScale,
                ),
              },
            ),
          );
        case InlineLink(:final text, :final href):
          final index = links++;
          hrefs.add(href);
          final recognizer = _links.recognizer(index)
            ..onTap = () => openSafeUrl(context, href);
          spans.add(
            TextSpan(
              text: text,
              recognizer: recognizer,
              mouseCursor: SystemMouseCursors.click,
              // CopilotKit adds a hidden "(opens in a new tab)".
              semanticsLabel: '$text (opens in a new tab)',
              style: _links.style(
                context,
                index,
                base: inherited.decoration,
                color: type.linkColor,
                underline: type.linkUnderline,
              ),
            ),
          );
      }
    }
    _links.keep(links);
    final text = Text.rich(
      TextSpan(children: [...spans, ...widget.trailing]),
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
    );
    return _links.overlay(context, text, hrefs);
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/text.tsx
