import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Calls [onVisible] once, the first time [child] is on screen: CopilotKit's
/// `onVisible` (an `IntersectionObserver` that fires once).
///
/// "On screen" means some of the child's area is inside the view and inside
/// every scrollable around it. The check runs after the first frame and
/// after each scroll of an enclosing scrollable, until it fires.
class VisibleOnce extends StatefulWidget {
  /// Watches [child] and calls [onVisible] the first time it shows.
  const VisibleOnce({required this.onVisible, required this.child, super.key});

  /// Called once.
  final VoidCallback onVisible;

  /// The watched widget.
  final Widget child;

  @override
  State<VisibleOnce> createState() => _VisibleOnceState();
}

class _VisibleOnceState extends State<VisibleOnce> {
  bool _fired = false;
  bool _scheduled = false;
  final List<ScrollableState> _scrollables = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  void _listen() {
    _unlisten();
    if (_fired) return;
    var scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      scrollable.position.addListener(_schedule);
      _scrollables.add(scrollable);
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
  }

  void _unlisten() {
    for (final scrollable in _scrollables) {
      scrollable.position.removeListener(_schedule);
    }
    _scrollables.clear();
  }

  void _schedule() {
    if (_fired || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _check();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _check() {
    if (_fired || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    var visible = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final view = View.maybeOf(context);
    if (view != null) {
      visible = visible.intersect(
        Offset.zero & (view.physicalSize / view.devicePixelRatio),
      );
    }
    for (final scrollable in _scrollables) {
      final area = scrollable.context.findRenderObject();
      if (area is RenderBox && area.attached && area.hasSize) {
        visible = visible.intersect(
          MatrixUtils.transformRect(
            area.getTransformTo(null),
            Offset.zero & area.size,
          ),
        );
      }
    }
    final touches = visible.width >= 0 && visible.height >= 0;
    final overlaps = visible.width > 0 && visible.height > 0;
    if (overlaps || (touches && box.size.isEmpty)) {
      _fired = true;
      _unlisten();
      widget.onVisible();
    }
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return widget.child;
  }
}

// PORT STATUS: confidence=high todos=0 upstream=packages/react-core/src/v2/generative-ui/standard/layout.tsx (useVisibleOnce)
