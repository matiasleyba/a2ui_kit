// Widget tests of the standard text components, after CopilotKit's
// react-core standard/__tests__/text.test.tsx.

import 'dart:ui' show CheckedState, Tristate;

import 'package:a2ui_flutter/a2ui_flutter.dart' show A2uiSurface;
import 'package:a2ui_kit/a2ui_kit.dart';
import 'package:a2ui_kit/src/components/standard/text/markdown.dart'
    show markdownBlockBuilderTags;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';
import '../helpers/parity.dart' show fakeUrlLauncher;

final _standard = A2uiKitTheme.standard(Brightness.light);
final _playground = A2uiKitTheme.playground(Brightness.light);

/// The RichText showing [text].
RichText _rich(WidgetTester tester, String text) => tester.widget<RichText>(
  find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(text),
  ),
);

/// The style of the run of [text] inside the RichText showing [whole],
/// with every ancestor span's style merged in.
TextStyle _styleOf(WidgetTester tester, String whole, String text) {
  final root = _rich(tester, whole).text;
  TextStyle? found;
  void visit(InlineSpan span, TextStyle style) {
    final merged = style.merge(span.style);
    if (span is TextSpan) {
      if (span.text == text) found = merged;
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, merged);
      }
    }
  }

  visit(root, const TextStyle());
  return found!;
}

Map<String, Object?> _root(Map<String, Object?> props) => {
  'id': 'root',
  ...props,
};

void main() {
  group('Title', () {
    testWidgets('is a header in the standard heading sizes', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b', 'c', 'd'],
        },
        {'id': 'a', 'component': 'Title', 'text': 'small', 'size': 'sm'},
        {'id': 'b', 'component': 'Title', 'text': 'default'},
        {'id': 'c', 'component': 'Title', 'text': 'large', 'size': 'lg'},
        {'id': 'd', 'component': 'Title', 'text': 'huge', 'size': '5xl'},
      ]);
      expect(rectOfText(tester, 'small').height, closeTo(16 * 1.4, .5));
      expect(rectOfText(tester, 'default').height, closeTo(20 * 1.3, .5));
      expect(rectOfText(tester, 'large').height, closeTo(20 * 1.3, .5));
      expect(rectOfText(tester, 'huge').height, closeTo(24 * 1.3, .5));
    });

    testWidgets("keeps the surrounding type in the playground's look", (
      tester,
    ) async {
      await pumpComponents(tester, theme: _playground, [
        _root({'component': 'Title', 'text': 'Breakdown', 'size': '2xl'}),
      ]);
      expect(rectOfText(tester, 'Breakdown').height, 16 * 1.5);
    });

    testWidgets('strong false is 400, fontWeight wins', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'Title', 'text': 'light', 'strong': false},
        {'id': 'b', 'component': 'Title', 'text': 'bold', 'fontWeight': 'bold'},
      ]);
      expect(_rich(tester, 'light').text.style!.fontWeight, FontWeight.w400);
      expect(_rich(tester, 'bold').text.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('typography props: color, align, italic, numbers', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        _root({
          'component': 'Title',
          'text': 'Muted 123',
          'color': 'secondary',
          'textAlign': 'center',
          'italic': true,
          'tabularNums': true,
        }),
      ]);
      final rich = _rich(tester, 'Muted');
      expect(rich.textAlign, TextAlign.center);
      final style = DefaultTextStyle.of(
        tester.element(find.text('Muted 123', findRichText: true)),
      ).style.merge(rich.text.style);
      expect(style.color, _standard.color(A2uiColorToken.textSecondary));
      expect(style.fontStyle, FontStyle.italic);
      expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
    });

    testWidgets('truncate keeps one line with an ellipsis', (tester) async {
      await pumpComponents(tester, width: 120, [
        _root({
          'component': 'Title',
          'text': 'A very long title that will not fit',
          'truncate': true,
        }),
      ]);
      final rich = _rich(tester, 'A very long');
      expect(rich.maxLines, 1);
      expect(rich.softWrap, isFalse);
      expect(rich.overflow, TextOverflow.ellipsis);
    });
  });

  group('Text', () {
    testWidgets('renders inline markdown', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Text',
          'text': r'Was ~~$39~~ now **$29**',
          'color': 'secondary',
        }),
      ]);
      const whole = r'Was $39 now $29';
      expect(
        _styleOf(tester, whole, r'$39').decoration,
        TextDecoration.lineThrough,
      );
      expect(_styleOf(tester, whole, r'$29').fontWeight, FontWeight.w700);
    });

    testWidgets('a bound text follows the data model', (tester) async {
      final surfaces = await pumpComponents(
        tester,
        [
          _root({
            'component': 'Text',
            'text': {'@path': '/price'},
          }),
        ],
        data: {'price': r'$290'},
      );
      expect(find.text(r'$290', findRichText: true), findsOneWidget);
      surfaces.setData('/price', r'$310');
      await tester.pump();
      expect(find.text(r'$310', findRichText: true), findsOneWidget);
      expect(find.text(r'$290', findRichText: true), findsNothing);
    });

    testWidgets('a bound number shows as text', (tester) async {
      await pumpComponents(
        tester,
        [
          _root({
            'component': 'Text',
            'text': {'@path': '/n'},
          }),
        ],
        data: {'n': 42.5},
      );
      expect(find.text('42.5', findRichText: true), findsOneWidget);
    });

    testWidgets('a formatString call', (tester) async {
      await pumpComponents(
        tester,
        [
          _root({
            'component': 'Text',
            'text': {
              '@call': 'formatString',
              'args': {'value': r'Hi ${/name}'},
            },
          }),
        ],
        data: {'name': 'Ada'},
      );
      expect(find.text('Hi Ada', findRichText: true), findsOneWidget);
    });

    testWidgets('inherits its size without size; sm is .875em', (tester) async {
      await pumpComponents(tester, theme: _playground, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b', 'c', 'd'],
        },
        {'id': 'a', 'component': 'Text', 'text': 'plain'},
        {'id': 'b', 'component': 'Text', 'text': 'small', 'size': 'sm'},
        {'id': 'c', 'component': 'Text', 'text': 'px', 'fontSize': 20},
        {
          'id': 'd',
          'component': 'Text',
          'text': 'tall',
          'lineHeight': 2,
          'minLines': 3,
        },
      ]);
      expect(rectOfText(tester, 'plain').height, 16 * 1.5);
      expect(rectOfText(tester, 'small').height, closeTo(14 * 1.429, .01));
      expect(_rich(tester, 'px').text.style!.fontSize, 20);
      expect(_rich(tester, 'tall').text.style!.height, 2);
      final box = tester.getRect(
        find
            .ancestor(
              of: find.text('tall', findRichText: true),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.height, 3 * 1.5 * 16);
    });

    testWidgets('renders its children inline after the text', (tester) async {
      await pumpComponents(tester, [
        _root({
          'component': 'Text',
          'text': 'Plan',
          'children': ['b'],
        }),
        {'id': 'b', 'component': 'Badge', 'label': 'Pro'},
      ]);
      final rich = _rich(tester, 'Plan');
      var widgets = 0;
      rich.text.visitChildren((span) {
        if (span is WidgetSpan) widgets++;
        return true;
      });
      expect(widgets, 1);
      expect(rich.text.toPlainText(), startsWith('Plan '));
      expect(find.text('Pro'), findsOneWidget);
    });

    testWidgets(
      'an inline child scales with the text once and takes its type',
      (tester) async {
        Future<Size> childSize(double scale) async {
          await pumpComponents(tester, textScale: scale, [
            _root({
              'component': 'Text',
              'text': 'Plan',
              'fontWeight': 'bold',
              'children': ['t'],
            }),
            {'id': 't', 'component': 'Text', 'text': 'inner'},
          ]);
          // As drawn: the paragraph scales an inline widget by a transform.
          return tester.getRect(find.text('inner', findRichText: true)).size;
        }

        final one = await childSize(1);
        final two = await childSize(2);
        expect(two.width, closeTo(one.width * 2, 1));
        expect(two.height, closeTo(one.height * 2, 1));
        // The inner Text inherits the outer one's weight.
        final inner = tester.widget<RichText>(
          find.text('inner', findRichText: true),
        );
        expect(inner.text.style!.fontWeight, FontWeight.w700);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.text('inner', findRichText: true)),
          ),
          TextScaler.noScaling,
        );
      },
    );

    testWidgets('strong, decorations and highlight', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {
          'id': 'a',
          'component': 'Text',
          'text': 'marked',
          'strong': true,
          'underline': true,
          'lineThrough': true,
          'highlight': 'green',
        },
        {
          'id': 'b',
          'component': 'Text',
          'text': 'inline',
          'inline': true,
          'highlight': true,
        },
      ]);
      final marked = _rich(tester, 'marked').text.style!;
      expect(marked.fontWeight, FontWeight.w600);
      expect(
        marked.decoration,
        TextDecoration.combine([
          TextDecoration.underline,
          TextDecoration.lineThrough,
        ]),
      );
      final band = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('marked', findRichText: true),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (band.decoration as BoxDecoration).color,
        _standard.color(A2uiColorToken.highlightGreen),
      );
      expect(
        _rich(tester, 'inline').text.style!.backgroundColor,
        _standard.color(A2uiColorToken.highlightOrange),
      );
    });

    // Review 2a regen Q3 (RR29), the rule's sweep: the highlight's box stays
    // in the tree (RULEBOOK §2), so the text is not remounted.
    testWidgets('keeps its paragraph when highlight comes and goes', (
      tester,
    ) async {
      final surfaces = await pumpComponents(
        tester,
        theme: _standard,
        [
          _root({
            'component': 'Text',
            'text': 'marked',
            'highlight': {'@path': '/mark'},
          }),
        ],
        data: {'mark': 'green'},
      );
      final paragraph = find.text('marked', findRichText: true);
      RenderObject box() => tester.renderObject(
        find.ancestor(of: paragraph, matching: find.byType(DecoratedBox)).first,
      );
      final green = _standard.color(A2uiColorToken.highlightGreen);
      final element = tester.element(paragraph);
      expect(box(), paints..rect(color: green));
      for (final mark in [false, 'green']) {
        surfaces.setData('/mark', mark);
        await tester.pump();
        expect(tester.element(paragraph), same(element));
        final band = paints..rect(color: green);
        expect(box(), mark == false ? isNot(band) : band);
      }
    });

    testWidgets('whitespace collapses unless preserved', (tester) async {
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'Text', 'text': ' one \n  two '},
        {
          'id': 'b',
          'component': 'Text',
          'text': 'three\n  four',
          'preserveWhitespace': true,
        },
      ]);
      expect(find.text('one two', findRichText: true), findsOneWidget);
      expect(find.text('three\n  four', findRichText: true), findsOneWidget);
    });

    testWidgets('a link opens through the options, for safe URLs only', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpComponents(
        tester,
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
        [
          _root({
            'component': 'Text',
            'text':
                'See [docs](https://copilotkit.ai) or [x](javascript:alert(1))',
          }),
        ],
      );
      final rich = _rich(tester, 'See docs');
      expect(
        rich.text.toPlainText(includeSemanticsLabels: false),
        'See docs or x',
      );
      TextSpan? link;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'docs') link = span;
        return true;
      });
      expect(link!.semanticsLabel, 'docs (opens in a new tab)');
      (link!.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pump();
      expect(opened, [Uri.parse('https://copilotkit.ai')]);
      var unsafe = false;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'x' && span.recognizer != null) {
          unsafe = true;
        }
        return true;
      });
      expect(unsafe, isFalse);
    });

    testWidgets("inline code and links follow the theme's marks", (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        _root({'component': 'Text', 'text': '`code` [l](https://a.b)'}),
      ]);
      final code = _styleOf(tester, 'code l', 'code');
      expect(code.fontFamily, 'monospace');
      expect(code.fontSize, 13);
      final link = _styleOf(tester, 'code l', 'l');
      expect(link.decoration, TextDecoration.underline);
      expect(link.color, const Color(0xff0000ee));
    });
  });

  group('Caption and Label', () {
    testWidgets('Caption is .875em and secondary by default', (tester) async {
      await pumpComponents(tester, theme: _standard, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['a', 'b'],
        },
        {'id': 'a', 'component': 'Caption', 'text': 'caption'},
        {
          'id': 'b',
          'component': 'Caption',
          'text': 'small **one**',
          'size': 'sm',
          'fontWeight': 'semibold',
          'color': 'danger',
        },
      ]);
      final caption = _rich(tester, 'caption').text.style!;
      expect(caption.fontSize, 14);
      expect(caption.fontWeight, FontWeight.w400);
      expect(caption.color, _standard.color(A2uiColorToken.textSecondary));
      final small = _rich(tester, 'small').text.style!;
      expect(small.fontSize, 12);
      expect(small.fontWeight, FontWeight.w600);
      expect(small.color, _standard.color(A2uiColorToken.textDanger));
      expect(_styleOf(tester, 'small one', 'one').fontWeight, FontWeight.w900);
    });

    testWidgets('Label is sm, medium and secondary; htmlFor is ignored', (
      tester,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        _root({'component': 'Label', 'text': 'Email', 'htmlFor': 'email'}),
      ]);
      final style = _rich(tester, 'Email').text.style!;
      expect(style.fontSize, 14);
      expect(style.height, 1.429);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.color, _standard.color(A2uiColorToken.textSecondary));
    });

    testWidgets('Label text is not markdown', (tester) async {
      await pumpComponents(tester, [
        _root({'component': 'Label', 'text': '**raw**'}),
      ]);
      expect(find.text('**raw**', findRichText: true), findsOneWidget);
    });
  });

  group('Badge', () {
    for (final (where, props, width) in [
      ('its maxWidth', {'maxWidth': '60px'}, 360.0),
      ('a narrow column', <String, Object?>{}, 80.0),
    ]) {
      testWidgets('a long label ends in an ellipsis within $where', (
        tester,
      ) async {
        const label = 'A very long badge label here';
        await pumpComponents(tester, width: width, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['b'],
          },
          {'id': 'b', 'component': 'Badge', 'label': label, ...props},
        ]);
        final text = tester.widget<Text>(find.text(label));
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
        final box = tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        );
        expect(tester.getRect(find.text(label)).right, lessThan(box.right));
        expect(box.width, lessThanOrEqualTo(width == 80 ? 80 : 60));
      });
    }

    Future<Container> badge(
      WidgetTester tester,
      Map<String, Object?> props,
    ) async {
      await pumpComponents(tester, theme: _standard, [
        _root({'component': 'Badge', 'label': 'New', ...props}),
      ]);
      return tester.widget<Container>(
        find
            .ancestor(of: find.text('New'), matching: find.byType(Container))
            .first,
      );
    }

    BoxDecoration decoration(Container c) => c.decoration! as BoxDecoration;

    TextStyle ink(WidgetTester tester) =>
        tester.widget<Text>(find.text('New')).style!;

    testWidgets('soft secondary by default: a 20px pill, 12px medium', (
      tester,
    ) async {
      final c = await badge(tester, {});
      expect(c.constraints!.minHeight, 20);
      expect(decoration(c).borderRadius, BorderRadius.circular(9999));
      expect(
        decoration(c).color,
        _standard.color(A2uiColorToken.badgeSecondary),
      );
      expect(ink(tester).fontSize, 12);
      expect(ink(tester).fontWeight, FontWeight.w500);
      expect(ink(tester).letterSpacing, .3);
      expect(ink(tester).color, _standard.color(A2uiColorToken.textDefault));
    });

    testWidgets('soft success: the tint and the success ink', (tester) async {
      final c = await badge(tester, {'color': 'success'});
      expect(decoration(c).color, _standard.color(A2uiColorToken.success));
      expect(ink(tester).color, _standard.color(A2uiColorToken.textSuccess));
    });

    testWidgets('solid: the solid fill and the on-accent ink', (tester) async {
      final c = await badge(tester, {'color': 'danger', 'variant': 'solid'});
      expect(decoration(c).color, _standard.color(A2uiColorToken.dangerSolid));
      expect(ink(tester).color, _standard.color(A2uiColorToken.onAccent));
      final neutral = await badge(tester, {'variant': 'solid'});
      expect(
        decoration(neutral).color,
        _standard.color(A2uiColorToken.surfaceInverted),
      );
    });

    testWidgets('outline: a 1px border in its colour', (tester) async {
      final c = await badge(tester, {'color': 'info', 'variant': 'outline'});
      expect(decoration(c).color, isNull);
      expect(
        (decoration(c).border! as Border).top.color,
        _standard.color(A2uiColorToken.borderInfo),
      );
    });

    for (final (size, height, fontSize) in [
      ('sm', 18.0, 11.0),
      ('md', 20.0, 12.0),
      ('lg', 24.0, 13.0),
    ]) {
      testWidgets('size $size', (tester) async {
        final c = await badge(tester, {'size': size});
        expect(c.constraints!.minHeight, height);
        expect(ink(tester).fontSize, fontSize);
      });
    }

    testWidgets('pill false is a 6px radius; padding and maxWidth', (
      tester,
    ) async {
      final c = await badge(tester, {
        'pill': false,
        'padding': 2,
        'maxWidth': 10,
      });
      expect(decoration(c).borderRadius, BorderRadius.circular(6));
      expect(c.padding, const EdgeInsets.all(8));
      expect(c.constraints!.maxWidth, 40);
      final text = tester.widget<Text>(find.text('New'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('keeps its width in a Row', (tester) async {
      await pumpComponents(tester, width: 200, [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['t', 'b'],
        },
        {
          'id': 't',
          'component': 'Text',
          'text': 'a long text that has to wrap around',
        },
        {'id': 'b', 'component': 'Badge', 'label': 'Beta'},
      ]);
      final badge = tester.getRect(
        find
            .ancestor(of: find.text('Beta'), matching: find.byType(Container))
            .first,
      );
      expect(badge.right, closeTo(200, 1e-6));
      expect(badge.width, greaterThan(4 * 12));
    });
  });

  group('semantics', () {
    testWidgets('a Title is a header and a link is a link', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['t', 'x'],
        },
        {'id': 't', 'component': 'Title', 'text': 'Plans'},
        {'id': 'x', 'component': 'Text', 'text': '[docs](https://a.b) tail'},
      ]);
      expect(
        tester.getSemantics(find.text('Plans', findRichText: true)),
        isSemantics(label: 'Plans', isHeader: true),
      );
      // RenderParagraph gives the link a semantics node of its own.
      final link = find.semantics.byLabel('docs (opens in a new tab)');
      expect(link, findsOne);
      expect(
        link.evaluate().single.getSemanticsData().flagsCollection.isLink,
        isTrue,
      );
      handle.dispose();
    });

    for (final look in A2uiKitLook.values) {
      testWidgets('in the ${look.name} look, an answer reads in its order, '
          'the Title alone a heading', (tester) async {
        // The browser reads the h3, the span, the formula's MathML, the
        // span and the blockquote where they are (text.tsx:108-136, :171,
        // :410, :272). The wrong order this rules out: every Text merged
        // into one node, read before the formula, and that node a heading.
        // The surface sits in a chat's list, whose item merges what has no
        // node of its own (a ListView's `IndexedSemantics`).
        final handle = tester.ensureSemantics();
        final theme = look == A2uiKitLook.standard
            ? A2uiKitTheme.standard(Brightness.light)
            : A2uiKitTheme.playground(Brightness.light);
        final surfaces = await pumpComponents(tester, theme: theme, [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['h', 'a', 'm', 'b', 'q'],
          },
          {'id': 'h', 'component': 'Title', 'text': 'Friction'},
          {
            'id': 'a',
            'component': 'Text',
            'text': 'The force of kinetic friction is',
          },
          {
            'id': 'm',
            'component': 'Math',
            'value': r'f = \mu_k N',
            'block': true,
          },
          {
            'id': 'b',
            'component': 'Text',
            'text': 'where N is the normal force.',
          },
          {
            'id': 'q',
            'component': 'Blockquote',
            'text': 'It opposes relative motion.',
          },
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: [theme]),
            home: Scaffold(
              body: ListView(
                children: [A2uiSurface(surface: surfaces.surface)],
              ),
            ),
          ),
        );
        await tester.pump();
        final read = <(String, bool)>[];
        void visit(SemanticsNode node) {
          if (node.label.isNotEmpty) {
            read.add((
              node.label,
              node.getSemanticsData().flagsCollection.isHeader,
            ));
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester
              .getSemantics(find.text('Friction', findRichText: true))
              .owner!
              .rootSemanticsNode!,
        );
        expect(read, [
          ('Friction', true),
          ('The force of kinetic friction is', false),
          (r'f = \mu_k N', false),
          ('where N is the normal force.', false),
          ('It opposes relative motion.', false),
        ]);
        handle.dispose();
      });
    }

    // Streamdown renders `<h1>`-`<h6>`, `<ol start>`, `<ul>` and `<li>`.
    testWidgets('Markdown headings have their levels, every one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, [
        _root({
          'component': 'Markdown',
          'text': '# a\n\n## b\n\n### c\n\n#### d\n\n##### e\n\n###### f',
        }),
      ]);
      for (final (label, level) in [
        ('a', 1),
        ('b', 2),
        ('c', 3),
        ('d', 4),
        ('e', 5),
        ('f', 6),
      ]) {
        final heading = find.semantics.byPredicate(
          (node) =>
              node.getSemanticsData().flagsCollection.isHeader &&
              node.label == label,
        );
        expect(heading, findsOne, reason: label);
        expect(heading.evaluate().single.headingLevel, level, reason: label);
      }
      // The heading keeps its sheet's style and padding.
      expect(rectOfText(tester, 'a').top, greaterThanOrEqualTo(24));
      handle.dispose();
    });

    testWidgets('a Markdown list is a list of items named by their text, '
        'numbered from its start, nested and checked', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponents(tester, [
        _root({
          'component': 'Markdown',
          'text':
              '3. three [link](https://a.b)\n4. four\n   - inner\n\n'
              '- [x] done\n- [ ] open',
        }),
      ]);
      // The markers are drawn, numbered from 3, before their items.
      final texts = [
        for (final rich in tester.widgetList<RichText>(find.byType(RichText)))
          rich.text.toPlainText(),
      ];
      // Each number once, before its item: 3 and 4, and no 5.
      expect(texts.where((t) => t == '3.'), hasLength(1));
      expect(texts.where((t) => t == '4.'), hasLength(1));
      expect(texts.indexOf('3.'), lessThan(texts.indexOf('three link')));
      expect(texts.indexOf('4.'), lessThan(texts.indexOf('four')));
      expect(texts.indexOf('three link'), lessThan(texts.indexOf('4.')));
      expect(texts, contains('•'));
      expect(texts, isNot(contains('5.')));
      // Each item is a list item of a list; a marker is no part of its
      // name; the nested list sits in its item.
      SemanticsNode item(String label) {
        final found = find.semantics.byPredicate(
          (node) => node.role == SemanticsRole.listItem && node.label == label,
        );
        expect(found, findsOne, reason: label);
        return found.evaluate().single;
      }

      for (final label in ['four', 'inner', 'done', 'open']) {
        expect(item(label).parent!.role, SemanticsRole.list, reason: label);
      }
      expect(item('inner').parent!.parent!.label, 'four');
      // The link inside an item still opens.
      final launcher = fakeUrlLauncher();
      await tester.tapOnText(find.textRange.ofSubstring('link'));
      await tester.pump();
      expect([for (final l in launcher.launches) l.url], ['https://a.b']);
      // The task items' checkboxes stand for their markers: a checked one
      // for [x], an empty one for [ ], each a disabled checkbox to a screen
      // reader, checked as its item is (GFM's `<input type="checkbox"
      // disabled>`).
      final glyphs = tester.widgetList<LucideGlyph>(find.byType(LucideGlyph));
      expect(glyphs.map((g) => g.icon), [
        lucideIcon('square-check', release: LucideRelease.reactCore),
        lucideIcon('square', release: LucideRelease.reactCore),
      ]);
      CheckedState checkbox(String item) {
        final node = find.semantics
            .byPredicate(
              (node) =>
                  node.parent?.role == SemanticsRole.listItem &&
                  node.parent?.label == item &&
                  node.flagsCollection.isChecked != CheckedState.none,
            )
            .evaluate()
            .single;
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
        return node.flagsCollection.isChecked;
      }

      expect(checkbox('done'), CheckedState.isTrue);
      expect(checkbox('open'), CheckedState.isFalse);
      handle.dispose();
    });

    testWidgets('a Markdown link is a tab stop that Enter opens, each once, '
        'in its order', (tester) async {
      // Streamdown's `<a href>` (MarkdownA): the wrong outcomes this rules
      // out are a link Tab never reaches, and a link in a list item (built
      // twice) reached twice.
      final opened = <Uri>[];
      await pumpComponents(
        tester,
        [
          _root({
            'component': 'Markdown',
            'text':
                '- see [the list](https://a.example.com)\n\n'
                // ignore: missing_whitespace_between_adjacent_strings (one URL)
                'Read [NCERT Ch. 4](https://ncert.nic.in/'
                'textbook.php?keph1=4-8) first.',
          }),
        ],
        catalog: a2uiKitCatalog(options: A2uiKitOptions(onOpenUrl: opened.add)),
      );
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
      expect(opened, [
        Uri.parse('https://a.example.com'),
        Uri.parse('https://ncert.nic.in/textbook.php?keph1=4-8'),
      ]);
      // The focused link is tinted; a third Tab goes round to the first
      // link, the surface's only other stop.
      TextStyle? tinted;
      tester
          .widget<RichText>(find.textContaining('NCERT', findRichText: true))
          .text
          .visitChildren((span) {
            if (span is TextSpan &&
                span.recognizer != null &&
                span.style?.backgroundColor != null) {
              tinted = span.style;
            }
            return true;
          });
      expect(tinted, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, hasLength(3));
      expect(opened.last, Uri.parse('https://a.example.com'));
    });

    testWidgets("a list and a heading in a Markdown quote take the quote's "
        'muted italic, the heading its size', (tester) async {
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        [
          _root({
            'component': 'Markdown',
            'text':
                '> ## Vectors\n> A **vector** has:\n> - a magnitude\n'
                '> - a direction',
          }),
        ],
      );
      // The style [text] is drawn in: every span's style on the way to it.
      TextStyle drawn(String text) {
        final finder = find.textContaining(text, findRichText: true).first;
        TextStyle? found;
        void visit(InlineSpan span, TextStyle style) {
          if (found != null || span is! TextSpan) return;
          final merged = style.merge(span.style);
          if (span.text?.contains(text) ?? false) {
            found = merged;
            return;
          }
          for (final child in span.children ?? const <InlineSpan>[]) {
            visit(child, merged);
          }
        }

        visit(
          tester.widget<RichText>(finder).text,
          DefaultTextStyle.of(tester.element(finder)).style,
        );
        return found!;
      }

      const muted = 0xff5d5d5d;
      for (final text in ['A ', 'a magnitude', 'a direction', 'Vectors']) {
        final style = drawn(text);
        expect(style.fontStyle, FontStyle.italic, reason: text);
        expect(style.color!.toARGB32(), muted, reason: text);
      }
      expect(drawn('Vectors').fontSize, 24);
    });

    test('no Markdown builder is a block element: flutter_markdown_plus '
        'would add its tag to a global list on every build', () {
      expect(markdownBlockBuilderTags(), isEmpty);
    });

    testWidgets("a Markdown formula that doesn't parse shows its source in "
        'the muted colour, as Streamdown sets it', (tester) async {
      await pumpComponents(
        tester,
        theme: A2uiKitTheme.standard(Brightness.light),
        [
          _root({'component': 'Markdown', 'text': r'See $$\frac{a$$ now'}),
        ],
      );
      expect(tester.takeException(), isNull);
      final error = find.text(r'\frac{a');
      expect(error, findsOneWidget);
      final style = DefaultTextStyle.of(
        tester.element(error),
      ).style.merge(tester.widget<Text>(error).style);
      expect(style.color!.toARGB32(), 0xff5d5d5d);
    });
  });
}
