// What KaTeX 0.16.27 decides from a formula's TeX source before it
// typesets, ported for the parts flutter_math_fork 0.7.4 lacks (RULEBOOK
// section 1, maths typesetting): the top-level line breaks `\\` and
// `\newline` (src/functions/cr.js:20-31, src/macros.js:618; dist/katex.css:
// 171-173), the display environments and their equation numbers
// (src/environments/array.js:56-74, :137-157, :1008-1087) and `\tag`
// (src/macros.js:583-590, src/parseTree.js:32-45). KaTeX is MIT, (c) Khan
// Academy and other contributors (NOTICE.md); read from
// $A2UI_THIRDPARTY_SRC/katex@0.16.27/.

/// One token of TeX source: a control word (`\frac`), a control symbol
/// (`\\`, `\{`), or one character; `start` and `end` are its offsets.
typedef TexToken = ({int start, int end, String text});

final RegExp _controlWord = RegExp('[A-Za-z@]+');

/// The tokens of [tex], as KaTeX's lexer reads a control sequence: `\`
/// and the letters after it, or `\` and one character (src/Lexer.js).
List<TexToken> texTokens(String tex) {
  final tokens = <TexToken>[];
  var i = 0;
  while (i < tex.length) {
    if (tex[i] == r'\' && i + 1 < tex.length) {
      final word = _controlWord.matchAsPrefix(tex, i + 1);
      final end = word == null ? i + 2 : word.end;
      tokens.add((start: i, end: end, text: tex.substring(i, end)));
      i = end;
    } else {
      tokens.add((start: i, end: i + 1, text: tex[i]));
      i += 1;
    }
  }
  return tokens;
}

/// The depth of each of [tokens]: the groups, environments and
/// `\left`…`\right` pairs open around it. A group's own braces, an
/// environment's `\begin` and `\end` and a delimiter pair's `\left` and
/// `\right` count at the depth outside them.
List<int> texDepths(List<TexToken> tokens) {
  final depths = <int>[];
  var depth = 0;
  for (final token in tokens) {
    switch (token.text) {
      case '{' || r'\begin' || r'\left':
        depths.add(depth);
        depth += 1;
      case '}' || r'\end' || r'\right':
        depth = depth > 0 ? depth - 1 : 0;
        depths.add(depth);
      default:
        depths.add(depth);
    }
  }
  return depths;
}

/// The index after the group that opens at [tokens][[at]] (a `{`), or
/// null when it never closes.
int? _groupEnd(List<TexToken> tokens, int at) {
  var depth = 0;
  for (var i = at; i < tokens.length; i++) {
    if (tokens[i].text == '{') depth += 1;
    if (tokens[i].text == '}') {
      depth -= 1;
      if (depth == 0) return i + 1;
    }
  }
  return null;
}

/// The index of the next token after [at] that is not white space.
int _skipSpaces(List<TexToken> tokens, int at) {
  var i = at;
  while (i < tokens.length && tokens[i].text.trim().isEmpty) {
    i += 1;
  }
  return i;
}

/// The lines of [tex]: KaTeX breaks a formula's top level at `\\` and
/// `\newline` in either mode (`newLine`, cr.js:20-31, true in display mode
/// too under `strict: "warn"`), each break a block between the `.base`
/// pieces (katex.css:171-173). A break inside a group or an environment is
/// not the formula's. The size after `\\` (`\\[2pt]`) is dropped.
List<String> katexLines(String tex) {
  final tokens = texTokens(tex);
  final depths = texDepths(tokens);
  final lines = <String>[];
  var start = 0;
  var i = 0;
  while (i < tokens.length) {
    final text = tokens[i].text;
    if (depths[i] == 0 && (text == r'\\' || text == r'\newline')) {
      lines.add(tex.substring(start, tokens[i].start));
      var next = i + 1;
      if (text == r'\\') {
        final at = _skipSpaces(tokens, next);
        if (at < tokens.length && tokens[at].text == '[') {
          final close = tokens.indexWhere((t) => t.text == ']', at);
          if (close != -1) next = close + 1;
        }
      }
      start = next < tokens.length ? tokens[next].start : tex.length;
      i = next;
      continue;
    }
    i += 1;
  }
  lines.add(tex.substring(start));
  return lines;
}

/// The environments KaTeX typesets that flutter_math_fork 0.7.4 lacks, by
/// name, and the one each is typeset as here: `align`, `align*` and `split`
/// share `aligned`'s handler (array.js:1008-1024); `gathered`, `gather` and
/// `gather*` are one centred column with `\jot` between the rows
/// (:1026-1055), which `aligned`'s rows without `&` are; `alignat` and
/// `alignat*` share `alignedat`'s (:1056-1066); `equation` and `equation*`
/// are their body alone, in the display style (:1068-1087). Null keeps the
/// body alone.
const Map<String, String?> katexEnvironmentStandIns = {
  'align': 'aligned',
  'align*': 'aligned',
  'split': 'aligned',
  'gathered': 'aligned',
  'gather': 'aligned',
  'gather*': 'aligned',
  'alignat': 'alignedat',
  'alignat*': 'alignedat',
  'equation': null,
  'equation*': null,
};

/// The environments KaTeX accepts only in display mode
/// (`validateAmsEnvironmentContext`, array.js:56-62).
const Set<String> katexDisplayOnlyEnvironments = {
  'align',
  'align*',
  'split',
  'gather',
  'gather*',
  'alignat',
  'alignat*',
  'equation',
  'equation*',
  'CD',
};

/// Whether an environment numbers its rows: `getAutoTag` (array.js:64-74),
/// true for a name with neither "ed" nor "*"; `split` has no tags at all
/// (:694).
bool? katexAutoTag(String name) {
  if (name == 'split') return null;
  if (!name.contains('ed')) return !name.contains('*');
  return null;
}

/// A formula's TeX as this package typesets it: `tex`, with the
/// environments of [katexEnvironmentStandIns] rewritten and every `\tag`,
/// `\nonumber` and `\notag` taken out; `tags`, when the formula is an
/// environment with numbered or tagged rows, each row's tag as TeX
/// (`\text{(1)}`) or null, and `rows`, the TeX of each of those rows; `tag`,
/// the formula's own `\tag` outside such an environment; `error`, KaTeX's
/// message when it refuses the source for one of these.
typedef KatexSource = ({
  String tex,
  List<String?> tags,
  List<String> rows,
  String? tag,
  String? error,
});

/// [tex] made ready for flutter_math_fork as KaTeX reads it in [display]
/// mode ([KatexSource]).
///
/// The equation numbers start at (1) in each formula: KaTeX's come from a
/// CSS counter on the whole page (`.eqn-num::before`, katex.css:1171-1174).
KatexSource katexSource(String tex, {required bool display}) {
  final tokens = texTokens(tex);
  final depths = texDepths(tokens);
  final out = StringBuffer();
  final tags = <String?>[];
  final rows = <String>[];
  String? tag;
  var number = 0;
  var numbered = false;

  // The argument of the `\tag` at [at]: its TeX as KaTeX's `\tag@paren` or
  // `\tag@literal` writes it, and the index after it.
  (String, int)? tagAt(int at) {
    var i = at + 1;
    final star = i < tokens.length && tokens[i].text == '*';
    if (star) i += 1;
    i = _skipSpaces(tokens, i);
    if (i >= tokens.length) return null;
    final int end;
    final String body;
    if (tokens[i].text == '{') {
      final close = _groupEnd(tokens, i);
      if (close == null) return null;
      end = close;
      body = tex.substring(tokens[i].end, tokens[close - 1].start);
    } else {
      end = i + 1;
      body = tokens[i].text;
    }
    return (star ? '\\text{$body}' : '\\text{({$body})}', end);
  }

  var i = 0;
  // An environment's name at the `\begin` or `\end` at [at], and the index
  // after it.
  (String, int)? nameAt(int at) {
    final open = _skipSpaces(tokens, at + 1);
    if (open >= tokens.length || tokens[open].text != '{') return null;
    final close = _groupEnd(tokens, open);
    if (close == null) return null;
    return (tex.substring(tokens[open].end, tokens[close - 1].start), close);
  }

  while (i < tokens.length) {
    final token = tokens[i];
    final text = token.text;
    if (text == r'\begin' || text == r'\end') {
      final named = nameAt(i);
      if (named != null) {
        final (name, after) = named;
        if (!display && katexDisplayOnlyEnvironments.contains(name)) {
          return (
            tex: tex,
            tags: const [],
            rows: const [],
            tag: null,
            error: '{$name} can be used only in display mode.',
          );
        }
        if (katexEnvironmentStandIns.containsKey(name)) {
          final standIn = katexEnvironmentStandIns[name];
          if (standIn != null) out.write('$text{$standIn}');
          // A top-level environment that numbers or tags its rows: each
          // row's tag kept apart. The column count `alignat` takes is
          // `alignedat`'s too; the rows start after it.
          if (text == r'\begin' &&
              depths[i] == 0 &&
              katexAutoTag(name) != null) {
            numbered = katexAutoTag(name)!;
            final body = _bodyRows(
              tokens,
              depths,
              after,
              tex,
              argument: name.startsWith('alignat'),
            );
            if (body != null) {
              final (bodyRows, end, start) = body;
              out.write(tex.substring(tokens[after - 1].end, start));
              final kept = <String>[];
              for (final row in bodyRows) {
                final cleaned = _withoutTags(row);
                final rowTag =
                    cleaned.tag ??
                    (numbered && !cleaned.nonumber
                        ? '\\text{(${++number})}'
                        : null);
                kept.add(cleaned.tex);
                if (standIn == null) {
                  // `equation`'s one row is the formula's line: its tag
                  // is the formula's.
                  tag ??= rowTag;
                } else {
                  rows.add(cleaned.tex);
                  tags.add(rowTag);
                }
              }
              out.write(kept.join(r' \\ '));
              // `\end{…}`.
              final named = nameAt(end);
              if (named != null) {
                final standInEnd = katexEnvironmentStandIns[named.$1];
                if (standInEnd != null) out.write('\\end{$standInEnd}');
                i = named.$2;
                continue;
              }
              i = end;
              continue;
            }
          }
          i = after;
          continue;
        }
        out.write(tex.substring(token.start, tokens[after - 1].end));
        i = after;
        continue;
      }
    }
    if (text == r'\tag') {
      final found = tagAt(i);
      if (found != null) {
        if (!display) {
          return (
            tex: tex,
            tags: const [],
            rows: const [],
            tag: null,
            error: r'\tag works only in display equations',
          );
        }
        tag ??= found.$1;
        i = found.$2;
        continue;
      }
    }
    if (text == r'\nonumber' || text == r'\notag') {
      i += 1;
      continue;
    }
    out.write(tex.substring(token.start, token.end));
    i += 1;
  }
  if (tags.every((t) => t == null)) {
    tags.clear();
    rows.clear();
  }
  return (tex: out.toString(), tags: tags, rows: rows, tag: tag, error: null);
}

/// The rows of the environment body starting at [at] (after `\begin{…}`
/// and, for `alignat`, its column count), the index of its `\end`, and
/// where the body's rows start in [tex]; null when it never ends. A last
/// row that is empty (a trailing `\\`) is no row.
(List<String>, int, int)? _bodyRows(
  List<TexToken> tokens,
  List<int> depths,
  int at,
  String tex, {
  required bool argument,
}) {
  final level = at < depths.length ? depths[at] : 0;
  var i = at;
  // `alignat{2}`'s argument.
  if (argument) {
    final first = _skipSpaces(tokens, i);
    if (first < tokens.length && tokens[first].text == '{') {
      final close = _groupEnd(tokens, first);
      if (close != null) i = close;
    }
  }
  final start = i < tokens.length ? tokens[i].start : tex.length;
  final rows = <String>[];
  var rowStart = start;
  for (; i < tokens.length; i++) {
    final text = tokens[i].text;
    if (depths[i] == level - 1 && text == r'\end') {
      final last = tex.substring(rowStart, tokens[i].start);
      if (rows.isEmpty || last.trim().isNotEmpty) rows.add(last);
      return (rows, i, start);
    }
    if (depths[i] < level) return null;
    if (depths[i] == level && text == r'\\') {
      rows.add(tex.substring(rowStart, tokens[i].start));
      rowStart = tokens[i].end;
    }
  }
  return null;
}

/// [row] without its `\tag`, `\nonumber` and `\notag`, with its tag's TeX
/// and whether it was unnumbered.
({String tex, String? tag, bool nonumber}) _withoutTags(String row) {
  final inner = katexSource(row, display: true);
  final nonumber = row.contains(r'\nonumber') || row.contains(r'\notag');
  return (tex: inner.tex, tag: inner.tag, nonumber: nonumber);
}

/// [row] with the `&` of its own level taken out: the row's content in one
/// group, for a `\vphantom` as tall as the row.
String katexRowContent(String row) {
  final tokens = texTokens(row);
  final depths = texDepths(tokens);
  final out = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].text == '&' && depths[i] == 0) continue;
    out.write(tokens[i].text);
  }
  return out.toString();
}

// PORT STATUS: confidence=medium todos=0 upstream=katex@0.16.27 src/functions/cr.js, src/environments/array.js, src/macros.js, src/parseTree.js
