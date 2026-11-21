import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A child node of the component being built.
typedef KitNode = ComponentNode<ComponentImplementation>;

/// Subscribes to [signal] and calls [onChange] with each later value; the
/// current one is skipped. Returns the unsubscribe function.
void Function() listenAfterFirst<T>(
  ReadonlySignal<T> signal,
  void Function(T value) onChange,
) {
  var primed = false;
  final unsubscribe = signal.subscribe((value) {
    if (primed) onChange(value);
  });
  primed = true;
  return unsubscribe;
}

/// Builds from a value derived from each child node's props, again when one
/// of those values changes.
///
/// A container lays out its children by their own props (a child's
/// `weight`, `flex` or `span`), which the container's props do not carry:
/// a child's props can change without the container's.
class ChildPropsBuilder<T> extends StatefulWidget {
  /// Derives a value from each of [children] with [derive] and builds with
  /// [builder].
  const ChildPropsBuilder({
    required this.children,
    required this.derive,
    required this.builder,
    super.key,
  });

  /// The child nodes.
  final List<KitNode> children;

  /// The value of one child that the layout needs.
  final T Function(KitNode child) derive;

  /// Builds with the value of each child, in order.
  final Widget Function(BuildContext context, List<T> values) builder;

  @override
  State<ChildPropsBuilder<T>> createState() => _ChildPropsBuilderState<T>();
}

class _ChildPropsBuilderState<T> extends State<ChildPropsBuilder<T>> {
  List<void Function()> _unsubscribes = const [];
  List<T> _values = const [];

  List<T> _derive() => [
    for (final child in widget.children) widget.derive(child),
  ];

  void _subscribe() {
    _values = _derive();
    _unsubscribes = [
      for (final child in widget.children)
        listenAfterFirst(child.props, (_) {
          final next = _derive();
          if (!listEquals(next, _values)) {
            _values = next;
            _rebuild();
          }
        }),
    ];
  }

  void _unsubscribe() {
    for (final unsubscribe in _unsubscribes) {
      unsubscribe();
    }
    _unsubscribes = const [];
  }

  void _rebuild() {
    if (!mounted) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ChildPropsBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unsubscribe();
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _values);
}

// PORT STATUS: confidence=high todos=0 upstream=none
