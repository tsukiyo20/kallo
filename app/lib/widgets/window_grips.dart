import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// The eight grips that resize a window whose frame the app draws.
///
/// With a system frame, Windows answers for the edges itself. With none, the
/// whole window is the Flutter view, and the view is what the mouse hits — the
/// window underneath never gets a chance to say "this is a border". So the
/// border is drawn here as eight thin targets, and each one hands the drag to
/// the platform's own resize loop rather than resizing the window itself.
///
/// They are six points wide and sit over the content's edge, which is where a
/// person reaches for them anyway.
class WindowGrips extends StatelessWidget {
  const WindowGrips({super.key, this.thickness = 6});

  final double thickness;

  static const Map<ResizeEdge, MouseCursor> _cursors = <ResizeEdge, MouseCursor>{
    ResizeEdge.top: SystemMouseCursors.resizeUp,
    ResizeEdge.bottom: SystemMouseCursors.resizeDown,
    ResizeEdge.left: SystemMouseCursors.resizeLeft,
    ResizeEdge.right: SystemMouseCursors.resizeRight,
    ResizeEdge.topLeft: SystemMouseCursors.resizeUpLeft,
    ResizeEdge.topRight: SystemMouseCursors.resizeUpRight,
    ResizeEdge.bottomLeft: SystemMouseCursors.resizeDownLeft,
    ResizeEdge.bottomRight: SystemMouseCursors.resizeDownRight,
  };

  @override
  Widget build(BuildContext context) {
    final double t = thickness;
    return Stack(
      children: <Widget>[
        _grip(ResizeEdge.top, left: 0, right: 0, top: 0, height: t),
        _grip(ResizeEdge.bottom, left: 0, right: 0, bottom: 0, height: t),
        _grip(ResizeEdge.left, left: 0, top: 0, bottom: 0, width: t),
        _grip(ResizeEdge.right, right: 0, top: 0, bottom: 0, width: t),
        // The corners come last: at the corner the diagonal wins, which is
        // what a window's corner does everywhere else.
        _grip(ResizeEdge.topLeft, left: 0, top: 0, width: t, height: t),
        _grip(ResizeEdge.topRight, right: 0, top: 0, width: t, height: t),
        _grip(ResizeEdge.bottomLeft, left: 0, bottom: 0, width: t, height: t),
        _grip(ResizeEdge.bottomRight, right: 0, bottom: 0, width: t, height: t),
      ],
    );
  }

  Widget _grip(
    ResizeEdge edge, {
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: _cursors[edge] ?? MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (_) async {
            try {
              await windowManager.startResizing(edge);
            } on Object catch (_) {
              // No window behind the widget; nothing to resize.
            }
          },
        ),
      ),
    );
  }
}
