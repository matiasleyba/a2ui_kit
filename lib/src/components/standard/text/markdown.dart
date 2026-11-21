// The standard Markdown: CopilotKit renders `text` with Streamdown 1.6.11
// (react-core standard/markdown.tsx), whose default components and styles
// this file follows (streamdown@1.6.11 dist/chunk-ZKROPTWQ.js). It drives
// flutter_markdown_plus 1.0.12's builder itself, adapting its `MarkdownBody`
// (src/widget.dart:353-451, :462-505: the parse, the link recognizers, the
// code text) and its list layout (src/builder.dart:414-441, :668-704,
// :751-758); flutter_markdown_plus is BSD 3-Clause, (c) 2013 The Flutter
// Authors (NOTICE.md).

import 'dart:convert';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/inputs/controls.dart';
import 'package:a2ui_kit/src/components/standard/text/math.dart';
import 'package:a2ui_kit/src/document/props.g.dart';
import 'package:a2ui_kit/src/foundation/icons/lucide.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:a2ui_kit/src/foundation/text/inline_text.dart';
import 'package:a2ui_kit/src/foundation/text/markdown_repair.dart';
import 'package:a2ui_kit/src/theme/a2ui_kit_theme.dart';
import 'package:a2ui_kit/src/theme/tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// The standard `Markdown`: GitHub-flavoured markdown (headings, lists,
/// task lists, tables, strikethrough, autolinks, code), with `$$…$$` math
/// typeset like KaTeX, in Streamdown's default look.
///
/// While `streaming` is true, markdown that is still arriving is closed
/// first (an open fence, emphasis, a half-sent link), as Streamdown does.
/// Links open only for http, https and mailto URLs. Raw HTML shows as text,
/// code is not highlighted and mermaid diagrams show as code (see the
/// package's differences from CopilotKit).
Widget buildMarkdown(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) {
  final view = MarkdownProps(props);
  final text = view.text ?? '';
  return KitMarkdown(
    data: view.streaming ? repairIncompleteMarkdown(text) : text,
  );
}

/// Markdown in the surface's type and Streamdown's default styles.
///
/// Headings and lists reach a screen reader as Streamdown's HTML does
/// (streamdown 1.6.11 renders `<h1>` to `<h6>`, `<ul>`, `<ol>` and `<li>`):
/// a heading of its level, and a list of list items, each named by its
/// text alone (an `<li>`'s marker is no part of its text).
class KitMarkdown extends StatefulWidget {
  /// Renders [data].
  const KitMarkdown({required this.data, super.key});

  /// The markdown source.
  final String data;

  @override
  State<KitMarkdown> createState() => _KitMarkdownState();
}

/// The markdown syntaxes: GitHub's, with `$$…$$` math.
final md.ExtensionSet _extensions = md.ExtensionSet(
  [...md.ExtensionSet.gitHubFlavored.blockSyntaxes, const _MathBlockSyntax()],
  [_MathInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
);

// flutter_markdown_plus 1.0.12's `MarkdownBody` (src/widget.dart:353-451,
// :462-505), driven here so that headings and lists can carry their roles:
// its builder takes no wrapper around a heading or a list item, so a
// heading is built again on its own, inside its semantics, and a list is
// laid out here as the builder lays one out (src/builder.dart:414-441,
// :668-704, :751-758).
class _KitMarkdownState extends State<KitMarkdown>
    implements MarkdownBuilderDelegate {
  /// The answer's links, in order: Streamdown's `<a href>` (`MarkdownA`,
  /// chunk-ZKROPTWQ.js), a tab stop that Enter opens, as a Text's inline
  /// links are ([KitLinkTargets]).
  late final KitLinkTargets _links = KitLinkTargets(
    onChanged: () => setState(() => _stale = true),
  );

  /// The links' hrefs, in the answer's order.
  final List<String?> _hrefs = [];

  /// Each link element's index in [_hrefs]: a heading, list or quote is
  /// built more than once, its links each time.
  final Map<md.Element, int> _linkIndex = Map.identity();

  String? _data;
  MarkdownStyleSheet? _sheet;
  late MarkdownStyleSheet _quoteSheet;
  A2uiKitTheme? _theme;
  List<Widget> _children = const [];

  /// Whether the blocks must be built again: a link's focus changed.
  bool _stale = false;

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  /// The index of the link [element], its recognizer opening its href.
  int _link(md.Element element) => _linkIndex.putIfAbsent(element, () {
    final href = element.attributes['href'];
    final index = _hrefs.length;
    _hrefs.add(href);
    _links.recognizer(index).onTap = () => KitLinkTargets.open(context, href);
    return index;
  });

  // Not called: the `a` builder ([_LinkBuilder]) takes the links.
  @override
  GestureRecognizer createLink(String text, String? href, String title) =>
      _links.recognizer(
        _link(md.Element.text('a', text)..attributes['href'] = href ?? ''),
      );

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) => TextSpan(
    style: styleSheet.code,
    text: code.replaceAll(RegExp(r'\n$'), ''),
  );

  @override
  Widget build(BuildContext context) {
    final theme = A2uiKitScope.themeOf(context);
    // `MarkdownBody` merges its sheet over the Material one
    // (`kFallbackStyle`, src/_functions_io.dart:83-104).
    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(textScaler: MediaQuery.textScalerOf(context))
        .merge(markdownStyleSheet(context, theme));
    if (_stale || widget.data != _data || sheet != _sheet || theme != _theme) {
      _stale = false;
      _data = widget.data;
      _sheet = sheet;
      _quoteSheet = _inQuote(sheet);
      _theme = theme;
      _hrefs.clear();
      _linkIndex.clear();
      final document = md.Document(
        extensionSet: _extensions,
        encodeHtml: false,
      );
      _children = _build(
        document.parseLines(const LineSplitter().convert(widget.data)),
      );
      _links.keep(_hrefs.length);
    }
    return _links.overlay(context, _column(_children), _hrefs);
  }

  /// The sheet of a quote's content: Streamdown's `<blockquote>` is
  /// `text-muted-foreground italic` (`MarkdownBlockquote`,
  /// chunk-ZKROPTWQ.js), which its paragraphs, list items and headings
  /// inherit, a heading keeping its size and weight.
  static MarkdownStyleSheet _inQuote(MarkdownStyleSheet sheet) {
    final quote = sheet.blockquote;
    TextStyle? heading(TextStyle? style) =>
        style?.copyWith(color: quote?.color, fontStyle: quote?.fontStyle);
    return sheet.copyWith(
      p: quote,
      listBullet: sheet.listBullet?.copyWith(
        color: quote?.color,
        fontStyle: quote?.fontStyle,
      ),
      h1: heading(sheet.h1),
      h2: heading(sheet.h2),
      h3: heading(sheet.h3),
      h4: heading(sheet.h4),
      h5: heading(sheet.h5),
      h6: heading(sheet.h6),
    );
  }

  /// [children] as `MarkdownBody` stacks its blocks.
  Widget _column(List<Widget> children) => children.length == 1
      ? children.single
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );

  /// The widgets of [nodes], with every builder but the one for [without]
  /// (the tag being built again on its own), in a quote's type when
  /// [inQuote].
  ///
  /// None of the builders is a block element's ([markdownBlockBuilderTags]):
  /// flutter_markdown_plus adds the tag of each such builder to a global
  /// list on every build (src/builder.dart:13, :196-201), and this builds
  /// once per heading, list item and quote.
  // PERF(port): a heading, a list or a quote is built twice (the builder
  // builds it, then this builds it again in its semantics or type), a
  // nested one once more for each around it; a builder hook around a block
  // would build each once.
  List<Widget> _build(
    List<md.Node> nodes, {
    String? without,
    bool inQuote = false,
  }) {
    final sheet = inQuote ? _quoteSheet : _sheet!;
    final theme = _theme!;
    return MarkdownBuilder(
      delegate: this,
      selectable: false,
      styleSheet: sheet,
      imageDirectory: null,
      imageBuilder: (uri, title, alt) => _MarkdownImage(uri: uri, alt: alt),
      checkboxBuilder: (checked) => _checkbox(sheet, theme, checked: checked),
      bulletBuilder: null,
      builders: _builders(sheet, without: without, inQuote: inQuote),
      paddingBuilders: const {},
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      fitContent: true,
    ).build(nodes);
  }

  Map<String, MarkdownElementBuilder> _builders(
    MarkdownStyleSheet sheet, {
    String? without,
    bool inQuote = false,
  }) => {
    'math': _MathBuilder(sheet.p ?? const TextStyle()),
    'mathBlock': _MathBuilder(sheet.p ?? const TextStyle(), display: true),
    'a': _LinkBuilder(this),
    'blockquote': _QuoteBuilder(this),
    for (var level = 1; level <= 6; level++)
      if (without != 'h$level')
        'h$level': _HeadingBuilder(this, level, inQuote: inQuote),
    'ul': _ListBuilder(this, inQuote: inQuote),
    'ol': _ListBuilder(this, inQuote: inQuote),
  };

  /// The heading [element] of [level], built as the builder builds it, in
  /// the semantics of an `<h1>` to `<h6>`.
  Widget _heading(md.Element element, int level, {required bool inQuote}) =>
      Semantics(
        container: true,
        header: true,
        headingLevel: level,
        child: _column(_build([element], without: 'h$level', inQuote: inQuote)),
      );

  /// The quote [element]'s blocks in a quote's type ([_inQuote]); the
  /// builder draws its border and padding round them (src/builder.dart:
  /// 466-474).
  Widget _quote(md.Element element) =>
      _column(_build(element.children ?? const [], inQuote: true));

  /// The link [element]'s text, in the link's style over [parentStyle] (a
  /// strong or emphasised part of it in its own), tinted while its focus
  /// shows, opened by its tap and by its focus target ([KitLinkTargets]).
  Widget _linkText(md.Element element, TextStyle? parentStyle) {
    final index = _link(element);
    final sheet = _sheet!;
    final base = (parentStyle ?? sheet.p ?? const TextStyle()).merge(sheet.a);
    final link = base.merge(
      _links.style(context, index, base: base.decoration),
    );
    final recognizer = _links.recognizer(index);
    // One span per run of text, each in its whole style: the builder
    // merges a widget's spans into its paragraph one level deep, dropping
    // a parent's style where a child has none (src/builder.dart:802-822).
    final spans = <TextSpan>[];
    void add(md.Node node, TextStyle style) {
      if (node is md.Element) {
        final own = style.merge(sheet.styles[node.tag]);
        for (final child in node.children ?? const <md.Node>[]) {
          add(child, own);
        }
      } else {
        spans.add(
          TextSpan(
            text: node.textContent,
            style: style,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          ),
        );
      }
    }

    for (final child in element.children ?? const <md.Node>[]) {
      add(child, link);
    }
    return Text.rich(TextSpan(children: spans));
  }

  /// The list [element] (`ul` or `ol`), laid out as the builder lays out
  /// its items (src/builder.dart:414-441: the marker in a box of the list
  /// indent, the item's blocks beside it on their baseline; :668-704: `•`,
  /// or the item's number from the list's `start`; :751-758: the block
  /// spacing between items), as a list of list items. A task item's
  /// checkbox stands for its marker, as the builder's does (:418-424).
  Widget _list(md.Element element, {required bool inQuote}) {
    final sheet = inQuote ? _quoteSheet : _sheet!;
    final ordered = element.tag == 'ol';
    var number = int.tryParse(element.attributes['start'] ?? '') ?? 1;
    final bulletPadding = sheet.listBulletPadding ?? EdgeInsets.zero;
    final items = <Widget>[];
    for (final item in element.children ?? const <md.Node>[]) {
      if (item is! md.Element || item.tag != 'li') continue;
      final first = item.children?.firstOrNull;
      final Widget marker;
      if (first is md.Element && first.attributes['type'] == 'checkbox') {
        marker = _checkbox(
          sheet,
          _theme!,
          checked: first.attributes.containsKey('checked'),
        );
      } else {
        // The marker is no part of the item's text (`li.textContent`).
        marker = ExcludeSemantics(
          child: Padding(
            padding: bulletPadding,
            child: Text(
              ordered ? '$number.' : '•',
              textAlign: ordered ? TextAlign.right : TextAlign.center,
              style: sheet.listBullet,
            ),
          ),
        );
      }
      number++;
      if (items.isNotEmpty) items.add(SizedBox(height: sheet.blockSpacing));
      items.add(
        Semantics(
          container: true,
          role: SemanticsRole.listItem,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              SizedBox(
                width:
                    (sheet.listIndent ?? 0) +
                    bulletPadding.left +
                    bulletPadding.right,
                child: marker,
              ),
              Flexible(
                child: _column(
                  _build([
                    md.Element('li', item.children ?? []),
                  ], inQuote: inQuote),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      role: SemanticsRole.list,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }
}

/// A task item's checkbox: Lucide's `square-check` or `square`, a disabled
/// checkbox to a screen reader, checked or not: GFM's `<input
/// type="checkbox" disabled>`, which Streamdown keeps (remark-gfm, no
/// `input` component of its own in chunk-ZKROPTWQ.js).
Widget _checkbox(
  MarkdownStyleSheet sheet,
  A2uiKitTheme theme, {
  required bool checked,
}) => Semantics(
  container: true,
  checked: checked,
  enabled: false,
  child: Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: LucideGlyph(
      lucideIcon(
        checked ? 'square-check' : 'square',
        release: LucideRelease.reactCore,
      )!,
      size: (sheet.p?.fontSize ?? 16) * 1.1,
      color: theme.color(A2uiColorToken.textSecondary),
    ),
  ),
);

/// Builds a heading on its own, in its semantics.
class _HeadingBuilder extends MarkdownElementBuilder {
  _HeadingBuilder(this.state, this.level, {required this.inQuote});

  final _KitMarkdownState state;
  final int level;
  final bool inQuote;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => state._heading(element, level, inQuote: inQuote);
}

/// Lays out a list as a list of list items.
class _ListBuilder extends MarkdownElementBuilder {
  _ListBuilder(this.state, {required this.inQuote});

  final _KitMarkdownState state;
  final bool inQuote;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => state._list(element, inQuote: inQuote);
}

/// Builds a quote's blocks again in a quote's type.
class _QuoteBuilder extends MarkdownElementBuilder {
  _QuoteBuilder(this.state);

  final _KitMarkdownState state;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => state._quote(element);
}

/// Builds a link's text as a tab stop's ([_KitMarkdownState._linkText]).
class _LinkBuilder extends MarkdownElementBuilder {
  _LinkBuilder(this.state);

  final _KitMarkdownState state;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => state._linkText(element, parentStyle);
}

/// The tags of the Markdown component's builders that are block elements'.
/// None may be: flutter_markdown_plus 1.0.12 adds each such tag to a global
/// list on every build, and the list grows for as long as answers stream
/// (src/builder.dart:13, :196-201).
@visibleForTesting
List<String> markdownBlockBuilderTags() => [
  for (final inQuote in [false, true])
    for (final MapEntry(:key, :value)
        in _KitMarkdownState()
            ._builders(MarkdownStyleSheet(), inQuote: inQuote)
            .entries)
      if (value.isBlockElement()) key,
];

/// Streamdown's default markdown styles (Tailwind classes in its
/// components) over the surface's type: 16px between blocks; headings
/// `text-3xl` to `text-sm`, semibold; links medium, underlined, in the
/// accent; inline code `text-sm` on a muted fill; quotes with a 4px left
/// border, italic and muted; tables bordered with a muted head.
MarkdownStyleSheet markdownStyleSheet(
  BuildContext context,
  A2uiKitTheme theme,
) {
  final base = DefaultTextStyle.of(context).style;
  final fontSize = base.fontSize ?? theme.typography.fontSize;
  final muted = theme.color(A2uiColorToken.textSecondary);
  final mutedFill = theme.color(A2uiColorToken.surfaceSecondary);
  final border = theme.color(A2uiColorToken.borderDefault);
  final mono = TextStyle(
    fontFamily: theme.typography.monoFontFamily,
    fontFamilyFallback: theme.typography.monoFontFamilyFallback,
    fontSize: fontSize * .875,
  );
  // Streamdown's wrapper has no type of its own: the text keeps the colour
  // and size around it.
  final body = base.copyWith(fontSize: fontSize);
  // Tailwind's text scale: size and line height in rem.
  TextStyle heading(double size, double lineHeight) => body.copyWith(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: FontWeight.w600,
  );
  const headingPadding = EdgeInsets.only(top: 24, bottom: 8);
  return MarkdownStyleSheet(
    p: body,
    a: TextStyle(
      color: theme.color(A2uiColorToken.accent),
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: theme.color(A2uiColorToken.accent),
    ),
    strong: const TextStyle(fontWeight: FontWeight.w600),
    em: const TextStyle(fontStyle: FontStyle.italic),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    code: mono.copyWith(backgroundColor: mutedFill),
    h1: heading(30, 36),
    h2: heading(24, 32),
    h3: heading(20, 28),
    h4: heading(18, 28),
    h5: heading(16, 24),
    h6: heading(14, 20),
    h1Padding: headingPadding,
    h2Padding: headingPadding,
    h3Padding: headingPadding,
    h4Padding: headingPadding,
    h5Padding: headingPadding,
    h6Padding: headingPadding,
    blockSpacing: 16,
    listIndent: 16 + fontSize * 1.25,
    listBullet: body,
    blockquote: body.copyWith(color: muted, fontStyle: FontStyle.italic),
    blockquotePadding: const EdgeInsets.only(left: 16),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: muted.withValues(alpha: .3), width: 4),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(16),
    codeblockDecoration: BoxDecoration(
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(12),
    ),
    tableHead: body.copyWith(
      fontSize: fontSize * .875,
      fontWeight: FontWeight.w600,
    ),
    tableBody: body.copyWith(fontSize: fontSize * .875),
    tableBorder: TableBorder.all(color: border),
    tableHeadCellsDecoration: BoxDecoration(
      color: mutedFill.withValues(alpha: mutedFill.a * .8),
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    tableHeadCellsPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: border)),
    ),
  );
}

/// `$$…$$` within a line: math in the text.
class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax() : super(r'\$\$([^$\n]+?)\$\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!.trim()));
    return true;
  }
}

/// `$$` on its own line, the TeX, then `$$`: a centred formula.
class _MathBlockSyntax extends md.BlockSyntax {
  const _MathBlockSyntax();

  static final RegExp _fence = RegExp(r'^\s*\$\$\s*$');

  @override
  RegExp get pattern => _fence;

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    final lines = <String>[];
    while (!parser.isDone) {
      final line = parser.current.content;
      parser.advance();
      if (_fence.hasMatch(line)) break;
      lines.add(line);
    }
    // A paragraph holding the formula: the builder takes no block element
    // of a builder's without adding its tag to a global list on every
    // build ([markdownBlockBuilderTags]); a paragraph is a block of its own.
    return md.Element('p', [md.Element.text('mathBlock', lines.join('\n'))]);
  }
}

/// `$$…$$` math as the Math component typesets it (one mapping of KaTeX,
/// RULEBOOK section 1), a block when it stands on its own lines. A formula
/// that does not parse shows its source in the muted text colour:
/// Streamdown gives rehype-katex `errorColor: "var(--color-muted-
/// foreground)"` (chunk-ZKROPTWQ.js), where the Math component keeps
/// KaTeX's red.
class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder(this.style, {this.display = false});

  final TextStyle style;
  final bool display;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => DefaultTextStyle.merge(
    style: (parentStyle ?? style).merge(preferredStyle),
    child: KitMath(
      value: element.textContent,
      block: display,
      errorColor: A2uiKitScope.themeOf(
        context,
      ).color(A2uiColorToken.textSecondary),
    ),
  );
}

class _MarkdownImage extends StatelessWidget {
  const _MarkdownImage({required this.uri, this.alt});

  final Uri uri;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return Text(alt ?? '');
    }
    return Image.network(
      uri.toString(),
      semanticLabel: alt,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stack) => Text(
        alt ?? '',
        style: TextStyle(
          color: A2uiKitScope.themeOf(
            context,
          ).color(A2uiColorToken.textSecondary),
          fontSize: baseFontSize(context) * .875,
        ),
      ),
    );
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/markdown.tsx
