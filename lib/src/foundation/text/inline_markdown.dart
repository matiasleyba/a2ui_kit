import 'package:a2ui_kit/src/foundation/interaction/links.dart';
import 'package:flutter/foundation.dart';

/// A mark of inline markdown.
enum InlineMark {
  /// `**bold**`.
  strong,

  /// `~~strike~~`.
  strike,

  /// `++underline++`.
  underline,

  /// `` `code` ``.
  code,

  /// `*italic*` or `_italic_`.
  emphasis,
}

/// One run of parsed inline markdown.
@immutable
sealed class InlineSegment {
  const InlineSegment(this.text);

  /// The text shown.
  final String text;
}

/// Plain text.
final class InlinePlain extends InlineSegment {
  /// Plain [text].
  const InlinePlain(super.text);

  @override
  bool operator ==(Object other) => other is InlinePlain && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'InlinePlain($text)';
}

/// Text with one mark (marks do not nest).
final class InlineMarked extends InlineSegment {
  /// [text] with [mark].
  const InlineMarked(super.text, this.mark);

  /// The mark.
  final InlineMark mark;

  @override
  bool operator ==(Object other) =>
      other is InlineMarked && other.text == text && other.mark == mark;

  @override
  int get hashCode => Object.hash(text, mark);

  @override
  String toString() => 'InlineMarked(${mark.name}: $text)';
}

/// A link to a safe URL (http, https or mailto).
final class InlineLink extends InlineSegment {
  /// A link labelled [text] to [href].
  const InlineLink(super.text, this.href);

  /// The trimmed, safe URL.
  final String href;

  @override
  bool operator ==(Object other) =>
      other is InlineLink && other.text == text && other.href == href;

  @override
  int get hashCode => Object.hash(text, href);

  @override
  String toString() => 'InlineLink($text -> $href)';
}

const List<(String, InlineMark)> _delimiters = [
  ('**', InlineMark.strong),
  ('~~', InlineMark.strike),
  ('++', InlineMark.underline),
  ('`', InlineMark.code),
  ('*', InlineMark.emphasis),
  ('_', InlineMark.emphasis),
];

final RegExp _word = RegExp(r'\w');

/// The link that starts at [start] (`[label](url)`), or null.
({String label, String url, int next})? _matchLink(String text, int start) {
  if (text[start] != '[') return null;
  final close = text.indexOf('](', start + 1);
  if (close < 0) return null;
  final end = text.indexOf(')', close + 2);
  if (end < 0) return null;
  // One level of balanced parentheses can be in the URL, e.g. "alert(1)".
  var urlEnd = end;
  final inner = text.substring(close + 2, end);
  if (inner.contains('(')) {
    final next = text.indexOf(')', end + 1);
    if (next < 0) return null;
    urlEnd = next;
  }
  return (
    label: text.substring(start + 1, close),
    url: text.substring(close + 2, urlEnd),
    next: urlEnd + 1,
  );
}

/// Parses the inline markdown of CopilotKit's Text, Caption and Blockquote:
/// `**bold**`, `*italic*` and `_italic_`, `~~strike~~`, `++underline++`,
/// `` `code` `` and `[label](url)`.
///
/// A port of `renderInlineMarkdown` (react-core `standard/markdown.tsx`):
///
/// - a marker without a closing partner stays literal text;
/// - emphasis must touch its content (`a * b * c` stays literal);
/// - an underscore inside a word (`snake_case`) is not emphasis;
/// - a link is a link only for http, https and mailto URLs; for others,
///   only the label shows;
/// - marks do not nest.
List<InlineSegment> parseInlineMarkdown(String text) {
  final out = <InlineSegment>[];
  if (text.isEmpty) return out;
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isNotEmpty) out.add(InlinePlain(buffer.toString()));
    buffer.clear();
  }

  var index = 0;
  while (index < text.length) {
    final link = _matchLink(text, index);
    if (link != null) {
      flush();
      final href = safeHref(link.url);
      out.add(
        href == null ? InlinePlain(link.label) : InlineLink(link.label, href),
      );
      index = link.next;
      continue;
    }

    (String, InlineMark)? delimiter;
    for (final candidate in _delimiters) {
      if (text.startsWith(candidate.$1, index)) {
        delimiter = candidate;
        break;
      }
    }
    final isIntraWordUnderscore =
        delimiter?.$1 == '_' && index > 0 && _word.hasMatch(text[index - 1]);
    if (delimiter != null && !isIntraWordUnderscore) {
      final (open, mark) = delimiter;
      final start = index + open.length;
      final end = text.indexOf(open, start);
      final inner = end > start ? text.substring(start, end) : '';
      final isMark =
          inner.isNotEmpty &&
          (mark == InlineMark.code || inner.trim() == inner);
      if (isMark) {
        flush();
        out.add(InlineMarked(inner, mark));
        index = end + open.length;
        continue;
      }
      buffer.write(open);
      index = start;
      continue;
    }

    buffer.write(text[index]);
    index += 1;
  }
  flush();
  return _mergePlain(out);
}

/// Adjacent plain runs (a label of an unsafe link next to text) as one.
List<InlineSegment> _mergePlain(List<InlineSegment> segments) {
  final merged = <InlineSegment>[];
  for (final segment in segments) {
    if (segment is InlinePlain &&
        merged.isNotEmpty &&
        merged.last is InlinePlain) {
      merged.last = InlinePlain('${merged.last.text}${segment.text}');
    } else {
      merged.add(segment);
    }
  }
  return merged;
}

final RegExp _collapsible = RegExp(r'[ \t\n\r\f]+');

/// [segments] with whitespace as CSS `white-space: normal` shows it: each
/// run of spaces, tabs and line breaks is one space, and none leads or
/// trails the text.
List<InlineSegment> collapseCssWhitespace(List<InlineSegment> segments) {
  final out = <InlineSegment>[];
  var afterSpace = true;
  for (final segment in segments) {
    var text = segment.text.replaceAll(_collapsible, ' ');
    if (afterSpace && text.startsWith(' ')) text = text.substring(1);
    if (text.isEmpty) continue;
    afterSpace = text.endsWith(' ');
    out.add(switch (segment) {
      InlinePlain() => InlinePlain(text),
      InlineMarked(:final mark) => InlineMarked(text, mark),
      InlineLink(:final href) => InlineLink(text, href),
    });
  }
  if (out.isNotEmpty && out.last.text.endsWith(' ')) {
    final last = out.removeLast();
    final text = last.text.substring(0, last.text.length - 1);
    if (text.isNotEmpty) {
      out.add(switch (last) {
        InlinePlain() => InlinePlain(text),
        InlineMarked(:final mark) => InlineMarked(text, mark),
        InlineLink(:final href) => InlineLink(text, href),
      });
    }
  }
  return out;
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/markdown.tsx (renderInlineMarkdown)
