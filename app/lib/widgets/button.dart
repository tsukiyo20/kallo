import 'package:flutter/widgets.dart';

import '../design/scope.dart';
import '../design/tokens.dart';

/// A button.
///
/// Two of them, and they are the same shape: one action on a page, filled with
/// the safelight; everything else, filled with the window's own grey. No
/// outline, no ripple: a mac button changes its fill under the pointer.
class KalloButton extends StatelessWidget {
  const KalloButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.height = 30,
    this.progress,
  });

  final String label;
  final VoidCallback? onTap;

  /// Filled is the one action on a screen; quiet is everything else.
  final bool filled;

  final double height;

  /// How much of a running action is done, 0..1. Non-null turns the filled
  /// button into the action's progress: the accent is what the finished button
  /// will be, and the window's grey is the work still to do. The action is not
  /// tappable while it runs, so [onTap] is ignored.
  ///
  /// The bar is time-based, not a report from the model: see [WorkClock] in
  /// the stages. The fill starts grey and ends as the orange the button always
  /// was, so the last frame of the bar is the button itself.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final bool enabled = onTap != null;
    return _ButtonBody(
      label: label,
      onTap: onTap,
      filled: filled,
      height: height,
      enabled: enabled,
      colors: colors,
      progress: progress,
    );
  }
}

class _ButtonBody extends StatefulWidget {
  const _ButtonBody({
    required this.label,
    required this.onTap,
    required this.filled,
    required this.height,
    required this.enabled,
    required this.colors,
    this.progress,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final double height;
  final bool enabled;
  final KalloColors colors;
  final double? progress;

  @override
  State<_ButtonBody> createState() => _ButtonBodyState();
}

class _ButtonBodyState extends State<_ButtonBody> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = widget.colors;
    final double? progress = widget.progress;
    if (progress != null) {
      return _ProgressFill(
        label: widget.label,
        progress: progress,
        height: widget.height,
        colors: colors,
      );
    }
    final Color background = !widget.enabled
        ? (widget.filled ? colors.fill : colors.fill.withValues(alpha: 0.55))
        : widget.filled
        ? colors.accent
        : _hover
        ? colors.fillStrong
        : colors.fill;
    final Color foreground = !widget.enabled
        ? colors.inkFaint
        : widget.filled
        ? colors.onAccent
        : colors.ink;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: KalloMotion.instant,
          height: widget.height,
          padding: EdgeInsets.symmetric(
            horizontal: widget.filled ? KalloSpace.step5 : KalloSpace.step4,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(KalloRadius.control),
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KalloType.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}


/// A filled button doing its work: the accent is the fill, the window's grey
/// is what is left, and the label is drawn twice — dark over the accent, light
/// over the grey — so the part of the word the bar has reached is readable.
class _ProgressFill extends StatelessWidget {
  const _ProgressFill({
    required this.label,
    required this.progress,
    required this.height,
    required this.colors,
  });

  final String label;
  final double progress;
  final double height;
  final KalloColors colors;

  @override
  Widget build(BuildContext context) {
    final double fraction = progress.clamp(0.0, 1.0);
    final TextStyle style = KalloType.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(KalloRadius.control),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: colors.fill),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: ColoredBox(color: colors.accent),
            ),
            // The track's side of the label: everything the bar has not
            // reached yet.
            ClipRect(
              clipper: _ProgressClip(fraction, fromLeft: false),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: colors.ink),
                ),
              ),
            ),
            // The fill's side: the label as the finished button will show it.
            ClipRect(
              clipper: _ProgressClip(fraction, fromLeft: true),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: colors.onAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressClip extends CustomClipper<Rect> {
  const _ProgressClip(this.fraction, {required this.fromLeft});

  final double fraction;
  final bool fromLeft;

  @override
  Rect getClip(Size size) => fromLeft
      ? Rect.fromLTWH(0, 0, size.width * fraction, size.height)
      : Rect.fromLTWH(size.width * fraction, 0, size.width, size.height);

  @override
  bool shouldReclip(covariant _ProgressClip oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.fromLeft != fromLeft;
}
