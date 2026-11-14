import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';

/// The way out of a window whose frame the app has hidden.
///
/// On the Mac the traffic lights are the system's and this is never built. On
/// Windows the bar is gone, so the three controls are drawn here, in the same
/// furniture as the pane switches they sit beside: a 34-point glass button with
/// a hairline and one hairline mark. They are the window's, not the room's, so
/// they do not follow the accent — closing a window is not a primary action.
///
/// The marks are drawn, not taken from a font: the product has no icon font,
/// and three glyphs are cheaper than one.
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  /// The width the row takes, so the bar can keep its own controls clear of it.
  static const double width = 34 * 3 + KalloSpace.step1 * 2;

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    // A window opened maximized starts with the restore mark. The call is
    // allowed to fail: a test builds this widget without a platform behind it.
    windowManager.addListener(this);
    _read();
  }

  Future<void> _read() async {
    try {
      final bool maximized = await windowManager.isMaximized();
      if (mounted && maximized != _maximized) {
        setState(() => _maximized = maximized);
      }
    } on Object catch (_) {
      // No window behind the widget; the normal mark is the right one.
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  Future<void> _toggle() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } on Object catch (_) {
      // Nothing to maximize.
    }
  }

  @override
  Widget build(BuildContext context) {
    final KalloStrings s = KalloStrings.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        WindowButton(
          mark: WindowMark.minimize,
          label: s.minimizeWindow,
          onTap: () async {
            try {
              await windowManager.minimize();
            } on Object catch (_) {
              // Nothing to minimize.
            }
          },
        ),
        const SizedBox(width: KalloSpace.step1),
        WindowButton(
          key: const Key('window-maximize'),
          mark: _maximized ? WindowMark.restore : WindowMark.maximize,
          label: _maximized ? s.restoreWindow : s.maximizeWindow,
          onTap: _toggle,
        ),
        const SizedBox(width: KalloSpace.step1),
        WindowButton(
          mark: WindowMark.close,
          label: s.closeWindow,
          onTap: () async {
            try {
              await windowManager.close();
            } on Object catch (_) {
              // Nothing to close.
            }
          },
        ),
      ],
    );
  }
}

/// The three marks a window's controls carry.
enum WindowMark { minimize, maximize, restore, close }

/// One of them: the glass button the pane switches use, with a mark instead of
/// a pane.
class WindowButton extends StatefulWidget {
  const WindowButton({
    super.key,
    required this.mark,
    required this.label,
    required this.onTap,
  });

  final WindowMark mark;
  final String label;
  final VoidCallback onTap;

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hover
                  ? colors.fillStrong.withValues(alpha: 0.92)
                  : colors.fill.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(KalloRadius.pill),
              border: Border.all(
                color: colors.hairline.withValues(alpha: _hover ? 0.9 : 0.55),
              ),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(18, 18),
                painter: _WindowMarkPainter(
                  mark: widget.mark,
                  ink: _hover ? colors.ink : colors.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowMarkPainter extends CustomPainter {
  const _WindowMarkPainter({required this.mark, required this.ink});

  final WindowMark mark;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = ink;
    const double near = 4.5;
    const double far = 13.5;
    switch (mark) {
      case WindowMark.minimize:
        canvas.drawLine(const Offset(near, 9), const Offset(far, 9), stroke);
      case WindowMark.maximize:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4.5, 4.5, 13.5, 13.5),
            const Radius.circular(1.6),
          ),
          stroke,
        );
      case WindowMark.restore:
        // The window behind the one in front of it: two rectangles, the near
        // one lower and to the left, so the mark reads before it is read.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3.5, 6.5, 11.5, 14.5),
            const Radius.circular(1.6),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 6.5)
            ..lineTo(6.5, 3.5)
            ..lineTo(14.5, 3.5)
            ..lineTo(14.5, 11.5)
            ..lineTo(11.5, 11.5),
          stroke,
        );
      case WindowMark.close:
        canvas.drawLine(const Offset(5, 5), const Offset(13, 13), stroke);
        canvas.drawLine(const Offset(13, 5), const Offset(5, 13), stroke);
    }
  }

  @override
  bool shouldRepaint(_WindowMarkPainter old) =>
      old.mark != mark || old.ink != ink;
}
