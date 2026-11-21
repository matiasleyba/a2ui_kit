import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_kit/src/components/standard/layout/containers.dart';
import 'package:a2ui_kit/src/components/standard/layout/flex_container.dart';
import 'package:a2ui_kit/src/foundation/interaction/form_scope.dart';
import 'package:a2ui_kit/src/foundation/node_watch.dart';
import 'package:a2ui_kit/src/foundation/scope.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// The standard `Form`: a flex column of fields, 16px apart unless `gap` is
/// set (`disableAutoSpacing` does not change that, as in CopilotKit).
///
/// A submit Button inside it, or Enter in a single-line field, submits it:
/// the fields' own constraints (`required`, the `email` and `url` text
/// variants) are checked first, the first broken one is shown and focused,
/// and otherwise `onSubmit` is sent. `checks` never hold a Form back.
/// `label` names the form for screen readers; `role` is ignored, as in
/// CopilotKit.
Widget buildForm(
  BuildContext context,
  KitNode node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _FormView(node: node, props: props, buildChild: buildChild);

class _FormView extends StatefulWidget {
  const _FormView({
    required this.node,
    required this.props,
    required this.buildChild,
  });

  final KitNode node;
  final ComponentProps props;
  final ChildWidgetBuilder buildChild;

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  late final A2uiFormController _controller = A2uiFormController(
    onSubmit: () async {
      await widget.props.action('onSubmit')?.call();
    },
  )..formContext = context;

  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final css = containerCss(context, props)..direction = Axis.vertical;
    // `gap: spacing(props.gap ?? 4)` comes after the layout style.
    css.gap = css.steps(props.value('gap') ?? 4);
    final content = flexContainer(
      context,
      props: props,
      css: css,
      children: props.children('children'),
      buildChild: widget.buildChild,
      childPosition: CardScope.of(context),
      wired: false,
    );
    final label = props.string('label');
    return A2uiFormScope(
      controller: _controller,
      child: Semantics(
        container: true,
        role: SemanticsRole.form,
        label: label == null || label.isEmpty ? null : label,
        child: content,
      ),
    );
  }
}

// PORT STATUS: confidence=medium todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/inputs.tsx
