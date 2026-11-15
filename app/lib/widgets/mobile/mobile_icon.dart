import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../design/mobile.dart';
import '../../design/scope.dart';
import '../../design/tokens.dart';

/// The marks the compact shell draws.
///
/// The app still has no Material icon font. These are the same line vocabulary
/// as the desktop's hand-drawn room marks: a 24-point grid, 1.6-point strokes,
/// round caps. A system glyph is a drawing here, not an asset from another
/// design language.
enum KalloGlyph {
  darkroom,
  gallery,
  gear,
  chevronRight,
  chevronLeft,
  close,
  search,
  sun,
  plus,
  minus,
  check,
  info,
  more,
  share,
  photo,
  film,
  paper,
  back,
  importPictures,
}

class KalloGlyphView extends StatelessWidget {
  const KalloGlyphView(
    this.glyph, {
    super.key,
    this.size = 22,
    this.color,
    this.stroke = 1.6,
  });

  final KalloGlyph glyph;
  final double size;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(
        glyph: glyph,
        color: color ?? KalloScope.colorsOf(context).ink,
        stroke: stroke,
      ),
    );
  }
}

class KalloIconButton extends StatefulWidget {
  const KalloIconButton({
    super.key,
    required this.glyph,
    required this.semanticLabel,
    this.onTap,
    this.size = KalloMobileSpace.touch,
    this.glyphSize = 21,
    this.foreground,
    this.background,
    this.stroke = 1.6,
  });

  final KalloGlyph glyph;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;
  final double glyphSize;
  final Color? foreground;
  final Color? background;
  final double stroke;

  @override
  State<KalloIconButton> createState() => _KalloIconButtonState();
}

class _KalloIconButtonState extends State<KalloIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final bool live = widget.onTap != null;
    final Color foreground = widget.foreground ?? colors.ink;
    final Color? background = widget.background;
    return Semantics(
      button: true,
      enabled: live,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: live ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ?? (_hover && live ? colors.fill : null),
              shape: BoxShape.circle,
            ),
            child: KalloGlyphView(
              widget.glyph,
              size: widget.glyphSize,
              color: live ? foreground : foreground.withValues(alpha: 0.38),
              stroke: widget.stroke,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.stroke,
  });

  final KalloGlyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    switch (glyph) {
      case KalloGlyph.darkroom:
        final Path shade = Path()
          ..moveTo(7, 4)
          ..lineTo(17, 4)
          ..lineTo(19.2, 11)
          ..lineTo(4.8, 11)
          ..close();
        canvas.drawPath(shade, paint);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 14), paint);
        canvas.drawCircle(const Offset(12, 17.2), 2.1, paint);
        canvas.drawLine(const Offset(4.5, 21), const Offset(8.5, 21), paint);
        canvas.drawLine(const Offset(15.5, 21), const Offset(19.5, 21), paint);
      case KalloGlyph.gallery:
        final Path wire = Path()
          ..moveTo(5, 9)
          ..lineTo(12, 3.8)
          ..lineTo(19, 9);
        canvas.drawPath(wire, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.5, 9.2, 15, 11.2),
            const Radius.circular(1.5),
          ),
          paint,
        );
        canvas.drawCircle(const Offset(12, 14.8), 2.2, paint);
      case KalloGlyph.gear:
        final Path cog = Path();
        for (int i = 0; i < 16; i++) {
          final double angle = -math.pi / 2 + i * math.pi / 8;
          final double radius = i.isEven ? 8.2 : 6.2;
          final double x = 12 + math.cos(angle) * radius;
          final double y = 12 + math.sin(angle) * radius;
          if (i == 0) {
            cog.moveTo(x, y);
          } else {
            cog.lineTo(x, y);
          }
        }
        cog.close();
        canvas.drawPath(cog, paint);
        canvas.drawCircle(const Offset(12, 12), 2.8, paint);
      case KalloGlyph.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9, 5)
            ..lineTo(16, 12)
            ..lineTo(9, 19),
          paint,
        );
      case KalloGlyph.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          paint,
        );
      case KalloGlyph.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), paint);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), paint);
      case KalloGlyph.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6, paint);
        canvas.drawLine(const Offset(15, 15), const Offset(20, 20), paint);
      case KalloGlyph.sun:
        canvas.drawCircle(const Offset(12, 12), 3.4, paint);
        for (int i = 0; i < 8; i++) {
          final double angle = i * math.pi / 4;
          canvas.drawLine(
            Offset(12 + math.cos(angle) * 6, 12 + math.sin(angle) * 6),
            Offset(12 + math.cos(angle) * 8.4, 12 + math.sin(angle) * 8.4),
            paint,
          );
        }
      case KalloGlyph.plus:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), paint);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);
      case KalloGlyph.minus:
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);
      case KalloGlyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12.5)
            ..lineTo(10, 17.5)
            ..lineTo(19, 7),
          paint,
        );
      case KalloGlyph.info:
        canvas.drawCircle(const Offset(12, 12), 8.2, paint);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 16), paint);
        canvas.drawCircle(const Offset(12, 7.8), 0.9, Paint()..color = color);
      case KalloGlyph.more:
        for (final double x in <double>[6, 12, 18]) {
          canvas.drawCircle(Offset(x, 12), 1.4, Paint()..color = color);
        }
      case KalloGlyph.share:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 10, 14, 10),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawLine(const Offset(12, 16), const Offset(12, 4), paint);
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 7.5)
            ..lineTo(12, 4)
            ..lineTo(15.5, 7.5),
          paint,
        );
      case KalloGlyph.photo:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 5.5, 18, 14),
            const Radius.circular(2.4),
          ),
          paint,
        );
        canvas.drawCircle(const Offset(8.4, 10.2), 1.3, paint);
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 18)
            ..lineTo(10.5, 12.5)
            ..lineTo(15.5, 17)
            ..lineTo(18, 14.5)
            ..lineTo(21, 18),
          paint,
        );
      case KalloGlyph.film:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 3, 16, 18),
            const Radius.circular(2.4),
          ),
          paint,
        );
        for (final double y in <double>[6.5, 10, 13.5, 17]) {
          canvas.drawRect(
            Rect.fromLTWH(6.2, y, 1.8, 1.8),
            Paint()..color = color,
          );
          canvas.drawRect(
            Rect.fromLTWH(16, y, 1.8, 1.8),
            Paint()..color = color,
          );
        }
      case KalloGlyph.paper:
        canvas.drawPath(
          Path()
            ..moveTo(6, 3)
            ..lineTo(14, 3)
            ..lineTo(18, 7)
            ..lineTo(18, 21)
            ..lineTo(6, 21)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(14, 3)
            ..lineTo(14, 7)
            ..lineTo(18, 7),
          paint,
        );
        canvas.drawLine(const Offset(9, 12), const Offset(15, 12), paint);
        canvas.drawLine(const Offset(9, 16), const Offset(13, 16), paint);
      case KalloGlyph.importPictures:
        // A tray with an arrow coming down into it: pictures are put on the
        // wall, not taken off it.
        canvas.drawPath(
          Path()
            ..moveTo(4, 14)
            ..lineTo(4, 19.5)
            ..lineTo(20, 19.5)
            ..lineTo(20, 14),
          paint,
        );
        canvas.drawLine(const Offset(12, 3.5), const Offset(12, 14.5), paint);
        canvas.drawPath(
          Path()
            ..moveTo(8.2, 10.8)
            ..lineTo(12, 14.5)
            ..lineTo(15.8, 10.8),
          paint,
        );
      case KalloGlyph.back:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          paint,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}
