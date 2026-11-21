// Vectors from CopilotKit's `renderInlineMarkdown` tests
// (react-core standard/__tests__/text.test.tsx, MIT).

import 'package:a2ui_kit/src/foundation/text/inline_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bold, italic, strikethrough, code and links', () {
    expect(parseInlineMarkdown('a **b** *c* ~~d~~ `e` [f](https://x.y)'), [
      const InlinePlain('a '),
      const InlineMarked('b', InlineMark.strong),
      const InlinePlain(' '),
      const InlineMarked('c', InlineMark.emphasis),
      const InlinePlain(' '),
      const InlineMarked('d', InlineMark.strike),
      const InlinePlain(' '),
      const InlineMarked('e', InlineMark.code),
      const InlinePlain(' '),
      const InlineLink('f', 'https://x.y'),
    ]);
  });

  test('plain text stays one run', () {
    expect(parseInlineMarkdown('1 < 2 & 3'), [const InlinePlain('1 < 2 & 3')]);
    expect(parseInlineMarkdown(''), isEmpty);
  });

  test('a javascript: URL is no link: only its label shows', () {
    expect(parseInlineMarkdown('[x](javascript:alert(1))'), [
      const InlinePlain('x'),
    ]);
  });

  test('underscore italics and ++underline++', () {
    expect(parseInlineMarkdown('_i_ and ++u++'), [
      const InlineMarked('i', InlineMark.emphasis),
      const InlinePlain(' and '),
      const InlineMarked('u', InlineMark.underline),
    ]);
  });

  test('underscores inside a word stay', () {
    expect(parseInlineMarkdown('use snake_case_name'), [
      const InlinePlain('use snake_case_name'),
    ]);
  });

  test('code spans stay literal', () {
    expect(parseInlineMarkdown('`**x**`'), [
      const InlineMarked('**x**', InlineMark.code),
    ]);
  });

  test('unmatched markers stay literal', () {
    expect(parseInlineMarkdown('2 * 3 = 6 and a ** b'), [
      const InlinePlain('2 * 3 = 6 and a ** b'),
    ]);
  });

  test('mailto links, trimmed', () {
    expect(parseInlineMarkdown('[m]( mailto:a@b.c )'), [
      const InlineLink('m', 'mailto:a@b.c'),
    ]);
  });

  test('one level of parentheses in a URL', () {
    expect(parseInlineMarkdown('[w](https://x.y/a_(b)) end'), [
      const InlineLink('w', 'https://x.y/a_(b)'),
      const InlinePlain(' end'),
    ]);
  });

  test('marks do not nest', () {
    expect(parseInlineMarkdown('**a *b* c**'), [
      const InlineMarked('a *b* c', InlineMark.strong),
    ]);
  });

  test('the example of the standard-all fixture', () {
    expect(
      parseInlineMarkdown(
        'Body with **bold**, *italic* and `code` [link](https://copilotkit.ai)',
      ),
      [
        const InlinePlain('Body with '),
        const InlineMarked('bold', InlineMark.strong),
        const InlinePlain(', '),
        const InlineMarked('italic', InlineMark.emphasis),
        const InlinePlain(' and '),
        const InlineMarked('code', InlineMark.code),
        const InlinePlain(' '),
        const InlineLink('link', 'https://copilotkit.ai'),
      ],
    );
  });

  group('collapseCssWhitespace', () {
    test('folds runs, line breaks included, and trims the ends', () {
      expect(
        collapseCssWhitespace(parseInlineMarkdown('  a \n\t b  **c**  ')),
        [const InlinePlain('a b '), const InlineMarked('c', InlineMark.strong)],
      );
    });

    test('folds across runs', () {
      expect(
        collapseCssWhitespace(const [
          InlinePlain('a '),
          InlineMarked(' b', InlineMark.code),
        ]),
        [const InlinePlain('a '), const InlineMarked('b', InlineMark.code)],
      );
    });
  });
}
