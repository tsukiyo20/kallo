import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import 'stock.dart';

/// A print with the film's edge kept: what a full-frame print is.
///
/// A normal print is cropped to the frame's image area. The enlarger's carrier
/// masks the rebate, so what comes out of the tray is the picture and nothing
/// around it — that is the print the wall hangs. A **full-frame print** is the
/// other carrier: the gate is opened to the 35 mm, and the rebate travels with
/// the picture.
///
/// The edge is not decoration, and it is not the same reading for every
/// chemistry. A [BorderTemplate] says which one to draw:
///
/// * A **print** of a negative has a black rebate, its edge printing in paper
///   white, and no visible perforations: the holes pass the enlarger's light
///   exactly as the rebate does, and one black is not a mark on another.
/// * A colour negative **kept with its orange mask** warms into brown. The
///   rebate and the letters lift, and the perforations do not — there is no
///   film in a hole to carry the mask — so they come back as the black shapes
///   they are, against the brown band.
/// * A **reversal** is not printed. The developed film is the picture, and a
///   person reads it on a light box: the unexposed rebate is black dye, the
///   edge printing is clear film, and the perforations are holes the light
///   comes through — the only white in the edge.
///
/// The light box has two more readings, kept because an edge is also a mood.
/// Its edge printing can be given the mask's amber ([whiteAmber]), so the type
/// is warm while the holes stay lit; or it can be left off altogether
/// ([whiteBlank]), which is the clean edge a film border is often wanted for.
/// Amber ink needs the mask and white holes need it gone, so `whiteAmber` is
/// the one template that is not one strip of film — a reading, not a chemistry.
///
/// The proportions are the film's, not a graphic's: a 35 mm frame is 36 mm
/// along the film and 24 mm across it, the film is 35 mm wide, so the rebate is
/// 5.5 mm on each long edge; the frames sit about 1 mm apart on the short ones.
/// A perforation is 2.79 mm **along** the film and 1.98 mm **across** it, on a
/// 4.75 mm pitch, centred in the rebate — wider than it is tall, which is where
/// they are drawn.
/// Which edge a print is given, when it is given one.
///
/// These are readings of the same film edge, not filters: the five film
/// templates differ in what happened to the edge, and a person chooses which
/// one the print carries. [neutral] is the paper print a standard carrier makes;
/// [warm] is the same negative scanned with its orange mask left in; [white] is
/// a reversal read on a light box; [whiteAmber] is that light box with the
/// mask's amber ink for the edge printing; [whiteBlank] is the reversal's edge
/// with no edge printing at all.
///
/// The order is the picker's: a print, the two paper prints, then the three
/// light-box readings, which are adjacent because they differ only in ink.
enum BorderTemplate {
  none,
  warm,
  neutral,
  whiteAmber,
  white,
  whiteBlank;

  /// The rebate's ink, before the room's lamp: black for a print and a
  /// reversal, brown where the orange mask was kept.
  Color get band => switch (this) {
    BorderTemplate.warm => KalloFilm.rebateMasked,
    BorderTemplate.none ||
    BorderTemplate.neutral ||
    BorderTemplate.whiteAmber ||
    BorderTemplate.white ||
    BorderTemplate.whiteBlank => KalloFilm.rebate,
  };

  /// What a perforation is drawn in — a hole is black on a lifted warm band and
  /// white on a light box, and not a mark at all on a neutral print.
  Color? get hole => switch (this) {
    BorderTemplate.warm => KalloFilm.rebate,
    BorderTemplate.whiteAmber ||
    BorderTemplate.white ||
    BorderTemplate.whiteBlank => KalloFilm.clear,
    BorderTemplate.none || BorderTemplate.neutral => null,
  };

  /// The edge printing's ink, or null where the edge carries no printing.
  ///
  /// On a light box the printing is clear film, so it is the light itself:
  /// white on [white]. [whiteAmber] keeps the mask's amber instead, and
  /// [whiteBlank] has none of it.
  Color? get ink => switch (this) {
    BorderTemplate.warm || BorderTemplate.whiteAmber => KalloFilm.edgeMasked,
    BorderTemplate.white => KalloFilm.edgeReversal,
    BorderTemplate.neutral => KalloFilm.edgePrint,
    BorderTemplate.none || BorderTemplate.whiteBlank => null,
  };
}

@immutable
class EdgePrintMetrics {
  const EdgePrintMetrics._({
    required this.outer,
    required this.aperture,
    required this.band,
    required this.side,
    required this.horizontal,
    required this.sprockets,
  });

  /// The whole piece of film, with its rebate.
  final Rect outer;

  /// The picture: the frame's image area.
  final Rect aperture;

  /// The rebate on the long edges, where the sprocket holes live.
  final double band;

  /// The film between this frame and the next, on the short edges.
  final double side;

  /// Whether the film runs across the picture rather than down it.
  final bool horizontal;

  /// How many holes fit along one long edge.
  final int sprockets;

  /// The ratio of the outer frame, width over height.
  double get aspect => outer.width / outer.height;

  /// The length of the long edge of the aperture.
  double get longEdge => horizontal ? aperture.width : aperture.height;

  /// The rebate's thickness, as a fraction of that long edge: 5.5 mm of a
  /// 36 mm frame.
  static const double bandRatio = 5.5 / 36;

  /// The gap to the next frame, as a fraction of the long edge.
  static const double sideRatio = 1.0 / 36;

  /// A full-frame print of a picture [imageWidth] pixels wide.
  factory EdgePrintMetrics.fromImageWidth(
    double imageWidth, {
    required double aspect,
  }) {
    final bool horizontal = aspect >= 1;
    final double imageHeight = imageWidth / aspect;
    final double long = horizontal ? imageWidth : imageHeight;
    final double band = long * bandRatio;
    final double side = long * sideRatio;
    final double outerWidth = imageWidth + (horizontal ? 2 * side : 2 * band);
    final double outerHeight = imageHeight + (horizontal ? 2 * band : 2 * side);
    final double left = horizontal ? side : band;
    final double top = horizontal ? band : side;
    // One perforation every 4.75 mm of a 36 mm frame, so eight on a frame.
    final int holes = (long / (horizontal ? imageHeight : imageWidth) * 5)
        .round()
        .clamp(6, 10);
    return EdgePrintMetrics._(
      outer: Rect.fromLTWH(0, 0, outerWidth, outerHeight),
      aperture: Rect.fromLTWH(left, top, imageWidth, imageHeight),
      band: band,
      side: side,
      horizontal: horizontal,
      sprockets: holes,
    );
  }

  /// A print [outerWidth] wide around a picture of [aspect].
  factory EdgePrintMetrics.fromWidth(
    double outerWidth, {
    required double aspect,
  }) {
    final bool horizontal = aspect >= 1;
    final double imageWidth = horizontal
        ? outerWidth / (1 + 2 * sideRatio)
        : outerWidth / (1 + 2 * bandRatio / aspect);
    return EdgePrintMetrics.fromImageWidth(imageWidth, aspect: aspect);
  }

  /// The outer size a print of [imageWidth] has.
  static Size sizeForImageWidth(double imageWidth, {required double aspect}) {
    final EdgePrintMetrics metrics = EdgePrintMetrics.fromImageWidth(
      imageWidth,
      aspect: aspect,
    );
    return metrics.outer.size;
  }
}

/// Paints a print with its edge, at the picture's own pixels.
class EdgePrintPainter extends CustomPainter {
  const EdgePrintPainter({
    required this.image,
    required this.source,
    this.film,
    this.printNumber = 1,
    this.process,
    this.light = 1,
    this.template = BorderTemplate.neutral,
  });

  final ui.Image image;

  /// The part of [image] in the frame, in image pixels.
  final Rect source;

  /// The film's own name: the edge does not translate.
  final String? film;

  /// The print's number in its batch: `01`, `02`, `03`.
  final int printNumber;

  /// The chemistry the edge is read by.
  final FilmProcess? process;

  /// The light on the print, from nothing to all of it.
  final double light;

  /// How the film's edge is read. [BorderTemplate.none] is not painted: a
  /// print without a border keeps the picture and nothing else.
  final BorderTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    if (template == BorderTemplate.none) {
      // A print with no edge is the picture, and there is no rebate to paint.
      _image(canvas, Offset.zero & size);
      return;
    }
    final EdgePrintMetrics metrics = EdgePrintMetrics.fromWidth(
      size.width,
      aspect: image.width / image.height,
    );
    _paint(canvas, metrics);
  }

  void _paint(Canvas canvas, EdgePrintMetrics m) {
    canvas.drawRect(m.outer, Paint()..color = _lit(template.band));
    final Color? holeColour = template.hole;
    if (holeColour != null) {
      // A reversal's holes are lit from behind; a warm negative's are the one
      // place with no film, so no mask, and they stay black under the lifted
      // band. A neutral print has no mark to draw: a black hole in a black band
      // is not a shape.
      final Paint hole = Paint()..color = _lit(holeColour);
      for (final RRect sprocket in _sprockets(m)) {
        canvas.drawRRect(sprocket, hole);
      }
    }

    canvas.save();
    canvas.clipRect(m.aperture);
    _image(canvas, m.aperture);
    canvas.restore();

    final Color? inkColour = template.ink;
    if (inkColour != null) {
      _edgeInk(canvas, m, _lit(inkColour));
    }
  }

  /// The picture, flat. The edge print is a print: a lens is how you look, not
  /// what the negative is, so no glass is baked into the file.
  void _image(Canvas canvas, Rect destination) {
    final ColorFilter? filter = light >= 1
        ? null
        : ColorFilter.matrix(<double>[
            light,
            0,
            0,
            0,
            0,
            0,
            light,
            0,
            0,
            0,
            0,
            0,
            light,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]);
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = filter,
    );
  }

  /// The perforations, centred in each long rebate: 2.79 mm along the film and
  /// 1.98 mm across it, on a 4.75 mm pitch, which is the pitch a 36 mm frame
  /// fits eight of. The hole is wider than it is tall — the long side runs
  /// along the film — and that is how it is drawn.
  Iterable<RRect> _sprockets(EdgePrintMetrics m) sync* {
    final double pitch = m.longEdge / m.sprockets;
    final double length = m.band * (2.79 / 5.5);
    final double thickness = m.band * (1.98 / 5.5);
    final Radius radius = Radius.circular(thickness * 0.22);
    final double across = m.band * 0.5;
    if (m.horizontal) {
      final double top = m.aperture.top - across;
      final double bottom = m.aperture.bottom + across;
      for (int i = 0; i < m.sprockets; i++) {
        final double x = m.aperture.left + (i + 0.5) * pitch;
        yield RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, top),
            width: length,
            height: thickness,
          ),
          radius,
        );
        yield RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, bottom),
            width: length,
            height: thickness,
          ),
          radius,
        );
      }
      return;
    }
    final double left = m.aperture.left - across;
    final double right = m.aperture.right + across;
    for (int i = 0; i < m.sprockets; i++) {
      final double y = m.aperture.top + (i + 0.5) * pitch;
      yield RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(left, y),
          width: thickness,
          height: length,
        ),
        radius,
      );
      yield RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(right, y),
          width: thickness,
          height: length,
        ),
        radius,
      );
    }
  }

  /// The edge printing: the stock and the print number on one edge, the
  /// process and the format on the other. It is the film's own vocabulary and
  /// does not translate.
  ///
  /// The letters sit where a film's edge code sits: in the gap between the
  /// perforations and the frame, which is 1.35 mm of a 5.5 mm rebate. So the
  /// line is set against the picture, not against the film's outer edge — on a
  /// reversal the perforations are beside it, not through it.
  void _edgeInk(Canvas canvas, EdgePrintMetrics m, Color colour) {
    final double size = math.max(6.0, m.band * 0.17);
    final TextStyle style = KalloType.folio.copyWith(
      fontSize: size,
      letterSpacing: size * 0.14,
      color: colour,
      fontFeatures: const <FontFeature>[FontFeature('tnum')],
    );
    final double pad = math.max(2.0, size * 0.36);
    final String stock = filmEdgeName(film);
    final String number = printNumber.toString().padLeft(2, '0');
    final String chemical = _processLabel();
    final String format = '135';
    final double half = math.max(
      1,
      (m.horizontal ? m.aperture.width : m.aperture.height) / 2 - pad * 2,
    );

    TextPainter ink(String text) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: half);

    if (m.horizontal) {
      final double top = m.aperture.top - m.band * 0.135;
      final double bottom = m.aperture.bottom + m.band * 0.135;
      _left(canvas, ink(stock), m.aperture.left + pad, top);
      _right(canvas, ink(number), m.aperture.right - pad, top);
      _left(canvas, ink(chemical), m.aperture.left + pad, bottom);
      _right(canvas, ink(format), m.aperture.right - pad, bottom);
      return;
    }

    final double left = m.aperture.left - m.band * 0.135;
    final double right = m.aperture.right + m.band * 0.135;
    final double top = m.aperture.top + pad;
    final double middle = m.aperture.top + m.aperture.height / 2;
    _down(canvas, ink(stock), left, top);
    _down(canvas, ink(number), left, middle);
    _down(canvas, ink(chemical), right, top);
    _down(canvas, ink(format), right, middle);
  }

  void _left(Canvas canvas, TextPainter text, double x, double centre) =>
      text.paint(canvas, Offset(x, centre - text.height / 2));

  void _right(Canvas canvas, TextPainter text, double x, double centre) =>
      text.paint(canvas, Offset(x - text.width, centre - text.height / 2));

  /// Text running down a vertical print. The translation is the text's right
  /// edge, because a quarter turn sends its height to the left.
  void _down(Canvas canvas, TextPainter text, double x, double y) {
    canvas.save();
    canvas.translate(x + text.height / 2, y);
    canvas.rotate(math.pi / 2);
    text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// The process mark. Motion-picture negative is ECN-2, not C-41; the name is
  /// the only place the app has to tell them apart.
  String _processLabel() {
    if (process == null) {
      return '';
    }
    final String name = (film ?? '').toUpperCase();
    return switch (process) {
      FilmProcess.monochrome => 'B&W',
      FilmProcess.reversal => 'E-6',
      FilmProcess.negative => name.contains('VISION3') ? 'ECN-2' : 'C-41',
      null => '',
    };
  }

  Color _lit(Color colour) => KalloColors.under(colour, light);

  @override
  bool shouldRepaint(EdgePrintPainter old) =>
      old.image != image ||
      old.source != source ||
      old.film != film ||
      old.printNumber != printNumber ||
      old.process != process ||
      old.light != light ||
      old.template != template;
}
