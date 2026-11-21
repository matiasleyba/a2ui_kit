/// Closes the markdown that a stream has not finished yet, so a half-sent
/// message renders as it will look once complete: a subset of `remend`,
/// which Streamdown runs while `streaming` is set.
///
/// - an open code fence (```` ``` ````) or math block (`$$` on its own line)
///   is closed;
/// - outside code, an odd `**`, `__`, `~~`, `` ` `` or `*` gets its
///   closing partner at the end;
/// - a link or image whose URL is still arriving shows its text only
///   (`[label](https://exa` becomes `label`; an image is dropped).
String repairIncompleteMarkdown(String source) {
  if (source.isEmpty) return source;
  final lines = source.split('\n');
  var inFence = false;
  var inMath = false;
  final prose = StringBuffer();
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (!inMath && trimmed.startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (!inFence && trimmed.startsWith(r'$$') && trimmed.trim() == r'$$') {
      inMath = !inMath;
      continue;
    }
    if (!inFence && !inMath) prose.writeln(line);
  }
  var out = source;
  if (inFence) return '$out\n```';
  if (inMath) return '$out\n\$\$';

  // The last paragraph is the one still arriving.
  final tail = prose.toString().split('\n\n').last;
  out = _repairLinks(out);
  return '$out${_closers(tail)}';
}

/// The closers of the markers [text] leaves open, innermost first: an
/// inline code span (`` ` ``), `**`, `__`, `~~` and `*`. Nothing counts
/// inside code. A `*` with whitespace (or a line's edge) on both sides,
/// such as a list item's marker, neither opens nor closes.
String _closers(String text) {
  final open = <String>[];
  void toggle(String marker) {
    final at = open.lastIndexOf(marker);
    if (at < 0) {
      open.add(marker);
    } else {
      open.removeAt(at);
    }
  }

  bool isSpace(int index) =>
      index < 0 || index >= text.length || text[index].trim().isEmpty;

  var i = 0;
  while (i < text.length) {
    final char = text[i];
    if (char == '`') {
      toggle('`');
      i++;
      continue;
    }
    if (open.isNotEmpty && open.last == '`') {
      i++;
      continue;
    }
    final pair = i + 1 < text.length ? text.substring(i, i + 2) : '';
    if (pair == '**' || pair == '__' || pair == '~~') {
      toggle(pair);
      i += 2;
      continue;
    }
    if (char == '*' && !(isSpace(i - 1) && isSpace(i + 1))) toggle('*');
    i++;
  }
  return open.reversed.join();
}

String _repairLinks(String text) {
  final image = RegExp(r'!\[[^\]\n]*\](\([^)\n]*)?$');
  if (image.hasMatch(text)) return text.replaceFirst(image, '');
  final partialUrl = RegExp(r'\[([^\]\n]*)\]\([^)\n]*$');
  if (partialUrl.hasMatch(text)) {
    return text.replaceFirstMapped(partialUrl, (m) => m[1]!);
  }
  final partialLabel = RegExp(r'\[([^\]\n]*)$');
  return text.replaceFirstMapped(partialLabel, (m) => m[1]!);
}

// PORT STATUS: confidence=medium todos=0 upstream=streamdown@1.6.11 (remend)
