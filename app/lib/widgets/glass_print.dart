import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A print's picture seen through glass.
///
/// The paper it sits on is flat and stays flat: a sheet of paper does not bend
/// because somebody is holding a loupe over it. What bends is the picture, and
/// only at the edge of the glass — a lens is not a window. So this widget draws
/// one `ui.Image` into its own box, held in by the paper around it, and bows
/// the picture as the radius leaves the centre.
///
/// The mesh is the lens: every vertex is pushed out by the radius it sits at,
/// and the texture coordinate stays where the pixel came from. A grid of
/// triangles is enough at this size, and it costs no shader asset and no
/// second decode. A barrel of zero is the flat picture — the walked-up view
/// magnifies the same image and never bends it.
class GlassPrint extends StatelessWidget {
  const GlassPrint({
    super.key,
    required this.image,
    this.source,
    this.barrel = 0,
  });

  /// The picture.
  final ui.Image image;

  /// The part of the picture to draw, in image pixels. Null is all of it.
  ///
  /// This is what the walked-up view moves: the glass holds still and the
  /// picture moves under it.
  final Rect? source;

  /// The lens's distortion: zero is flat, and a small positive number bows the
  /// picture out at its edge.
  final double barrel;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: GlassPrintPainter(
      image: image,
      source:
          source ??
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      barrel: barrel,
    ),
  );
}

/// Paints [GlassPrint]: one image, its `source` rect, into the box it is given.
class GlassPrintPainter extends CustomPainter {
  const GlassPrintPainter({
    required this.image,
    required this.source,
    this.barrel = 0,
  });

  final ui.Image image;

  /// The part of [image] to draw, in image pixels.
  final Rect source;

  final double barrel;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect destination = Offset.zero & size;
    if (destination.isEmpty || source.isEmpty) {
      return;
    }
    if (barrel <= 0.001) {
      canvas.drawImageRect(
        image,
        source,
        destination,
        Paint()..filterQuality = FilterQuality.high,
      );
      return;
    }

    final int columns = (destination.width / 22).ceil().clamp(12, 64);
    final int rows = (destination.height / 22).ceil().clamp(12, 64);
    final List<Offset> positions = <Offset>[];
    final List<Offset> texture = <Offset>[];
    for (int row = 0; row <= rows; row++) {
      final double v = row / rows;
      for (int column = 0; column <= columns; column++) {
        final double u = column / columns;
        final double x = u * 2 - 1;
        final double y = v * 2 - 1;
        final double radius = x * x + y * y;
        final double bend = 1 + barrel * radius;
        // The centre stays put; the edge of the glass sees a little more of
        // the picture.
        final double sx = ((x * bend) + 1) / 2;
        final double sy = ((y * bend) + 1) / 2;
        positions.add(
          Offset(
            destination.left + u * destination.width,
            destination.top + v * destination.height,
          ),
        );
        texture.add(
          Offset(
            source.left + sx * source.width,
            source.top + sy * source.height,
          ),
        );
      }
    }

    final List<int> indices = <int>[];
    final int stride = columns + 1;
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final int a = row * stride + column;
        final int b = a + 1;
        final int c = a + stride;
        final int d = c + 1;
        indices.addAll(<int>[a, b, c, b, d, c]);
      }
    }

    final ui.Vertices vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      indices: indices,
    );
    final Paint paint = Paint()
      ..shader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.high,
      );
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }

  @override
  bool shouldRepaint(GlassPrintPainter old) =>
      old.image != image || old.source != source || old.barrel != barrel;
}
