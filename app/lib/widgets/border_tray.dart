import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../design/scope.dart';
import '../design/tokens.dart';
import '../lab/edge_print.dart';
import '../lab/stock.dart';
import 'mobile/mobile_icon.dart';
import 'wall.dart';

/// The border, as a picture.
///
/// The edge a print carries is chosen by looking at it, not by reading its
/// name, so the picker is a row of small prints and the panel's control is one
/// of them. Every proof here is drawn by the same painter the print is baked
/// with — the bench's own picture and stock, the process, the print's number —
/// at a smaller paper size. There are no files and no words in the row: what it
/// shows is what the print will be.

/// How wide a proof is in the tray.
const double borderProofWidth = 124;

/// The room between a proof and its selection ring, and the ring itself.
const double _ringPad = 6;
const double _ring = 1.5;

/// The padding inside the tray's card, and the gap between two proofs.
const double _cardPad = 16;
const double _gap = 8;

/// The height of a bordered proof [width] wide, on its paper.
double borderProofHeight(double width, double aspect) {
  final double outer = EdgePrintMetrics.fromImageWidth(
    1000,
    aspect: aspect,
  ).aspect;
  return width * PrintSheet.heightPerWidth(aspect: outer);
}

/// The height of a tray tile, ring included, for a picture of [aspect].
double borderTileHeight(double proofWidth, double aspect) =>
    borderProofHeight(proofWidth, aspect) + 2 * _ringPad + 2 * _ring;

/// What a tile adds to its proof: the ring and the room around it.
const double _tileChrome = 2 * _ringPad + 2 * _ring;

/// The proof width that fits every template in a tray [trayWidth] wide.
///
/// The row is meant to show all of them, so the proofs give up width before the
/// row gives up any: a bench too wide for six at full size still shows six small
/// ones. Below [minProofWidth] they stop shrinking and the row scrolls instead.
double borderProofWidthIn(double trayWidth) {
  final int count = BorderTemplate.values.length;
  final double inner = trayWidth - 2 * _cardPad - (count - 1) * _gap;
  return (inner / count - _tileChrome).clamp(72.0, borderProofWidth);
}

/// The height the tray's card takes in a tray [trayWidth] wide, for a picture
/// of [aspect]. The bench reserves this much room above the tray.
double borderTrayHeightIn(double trayWidth, double aspect) =>
    borderTileHeight(borderProofWidthIn(trayWidth), aspect) + 2 * _cardPad;

/// The picture aspect a proof should be drawn at: the image's own, or the frame
/// the bench draws while it waits for one.
double borderAspectOf(ui.Image? image) =>
    image == null ? 1.5 : image.width / image.height;

/// One print, with the edge it was given, on its paper.
///
/// A print with no edge is the picture on paper — the same sheet, without the
/// film around it — so the control that shows the current edge shows the print
/// as it will come out of the tray.
class BorderProof extends StatelessWidget {
  const BorderProof({
    super.key,
    required this.image,
    required this.template,
    this.film,
    this.process,
    this.printNumber = 1,
    this.width,
    this.height,
  }) : assert(width != null || height != null);

  final ui.Image? image;
  final BorderTemplate template;
  final String? film;
  final FilmProcess? process;
  final int printNumber;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final ui.Image? picture = image;
    final double aspect = borderAspectOf(picture);
    final double outer = template == BorderTemplate.none
        ? aspect
        : EdgePrintMetrics.fromImageWidth(1000, aspect: aspect).aspect;
    final double w =
        width ?? height! / PrintSheet.heightPerWidth(aspect: outer);
    // A print with no picture yet is the paper it will be printed on.
    if (picture == null) {
      return SizedBox(
        width: w,
        height: w * PrintSheet.heightPerWidth(aspect: outer),
        child: ColoredBox(color: colors.print),
      );
    }
    return PrintSheet(
      width: w,
      aspect: outer,
      paper: colors.print,
      outline: colors.hairline,
      child: template == BorderTemplate.none
          ? RawImage(
              image: picture,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            )
          : CustomPaint(
              painter: EdgePrintPainter(
                image: picture,
                source: Rect.fromLTWH(
                  0,
                  0,
                  picture.width.toDouble(),
                  picture.height.toDouble(),
                ),
                film: film,
                process: process,
                printNumber: printNumber,
                template: template,
              ),
            ),
    );
  }
}

/// One edge in the picker: the proof, the ring around the chosen one, a hover.
class BorderTile extends StatefulWidget {
  const BorderTile({
    super.key,
    required this.image,
    required this.template,
    required this.label,
    required this.selected,
    required this.onTap,
    this.film,
    this.process,
    this.printNumber = 1,
    this.proofWidth = borderProofWidth,
    this.tileHeight,
  });

  final ui.Image? image;
  final BorderTemplate template;

  /// What a screen reader says. The tile itself draws no words.
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? film;
  final FilmProcess? process;
  final int printNumber;
  final double proofWidth;

  /// The tile's own height, so a row of them shares one baseline. Defaults to
  /// the height of a bordered proof at [proofWidth].
  final double? tileHeight;

  @override
  State<BorderTile> createState() => _BorderTileState();
}

class _BorderTileState extends State<BorderTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final double height =
        widget.tileHeight ??
        borderTileHeight(widget.proofWidth, borderAspectOf(widget.image));
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            width: widget.proofWidth + 2 * _ringPad + 2 * _ring,
            height: height,
            padding: const EdgeInsets.all(_ringPad),
            decoration: BoxDecoration(
              color: _hover ? colors.fill : const Color(0x00000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected
                    ? colors.accent
                    : const Color(0x00000000),
                width: _ring,
              ),
            ),
            child: Center(
              child: BorderProof(
                image: widget.image,
                template: widget.template,
                film: widget.film,
                process: widget.process,
                printNumber: widget.printNumber,
                width: widget.proofWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The current edge, as the inspector's control: a small print and a chevron.
class BorderButton extends StatefulWidget {
  const BorderButton({
    super.key,
    required this.image,
    required this.template,
    required this.label,
    required this.open,
    required this.onTap,
    this.film,
    this.process,
    this.printNumber = 1,
    this.proofHeight = 48,
  });

  final ui.Image? image;
  final BorderTemplate template;
  final String label;
  final bool open;
  final VoidCallback onTap;
  final String? film;
  final FilmProcess? process;
  final int printNumber;
  final double proofHeight;

  @override
  State<BorderButton> createState() => _BorderButtonState();
}

class _BorderButtonState extends State<BorderButton> {
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
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
            decoration: BoxDecoration(
              color: _hover ? colors.fillStrong : colors.fill,
              borderRadius: BorderRadius.circular(KalloRadius.control),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BorderProof(
                  image: widget.image,
                  template: widget.template,
                  film: widget.film,
                  process: widget.process,
                  printNumber: widget.printNumber,
                  height: widget.proofHeight,
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: widget.open ? 0.25 : 0,
                  duration: KalloMotion.quick,
                  child: KalloGlyphView(
                    KalloGlyph.chevronRight,
                    size: 14,
                    color: colors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of proofs laid on the bench, for choosing the edge a print carries.
///
/// The row is one strip; when there are more edges than the bench has room for,
/// it scrolls sideways. A mouse wheel over the tray scrolls it sideways too —
/// a wheel only turns one way and so does the strip, and moving the hand off
/// the tray keeps the wheel doing what it does everywhere else.
class BorderTray extends StatelessWidget {
  const BorderTray({
    super.key,
    required this.image,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
    this.film,
    this.process,
    this.printNumber = 1,
  });

  final ui.Image? image;
  final BorderTemplate selected;
  final String Function(BorderTemplate template) labelOf;
  final ValueChanged<BorderTemplate> onSelect;
  final String? film;
  final FilmProcess? process;
  final int printNumber;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints room) {
        final double proofWidth = borderProofWidthIn(room.maxWidth);
        final double tileHeight = borderTileHeight(
          proofWidth,
          borderAspectOf(image),
        );
        return Container(
          height: tileHeight + 2 * _cardPad,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(KalloRadius.card),
            border: Border.all(color: colors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: _WheelStrip(
            children: <Widget>[
              for (final BorderTemplate template in BorderTemplate.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                  child: BorderTile(
                    key: Key('border-${template.name}'),
                    image: image,
                    template: template,
                    label: labelOf(template),
                    selected: template == selected,
                    onTap: () => onSelect(template),
                    film: film,
                    process: process,
                    printNumber: printNumber,
                    proofWidth: proofWidth,
                    tileHeight: tileHeight,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A horizontal row that a vertical wheel can turn, when it overflows.
class _WheelStrip extends StatefulWidget {
  const _WheelStrip({required this.children});

  final List<Widget> children;

  @override
  State<_WheelStrip> createState() => _WheelStripState();
}

class _WheelStripState extends State<_WheelStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A wheel over the strip scrolls it across; a trackpad's own sideways
  /// gesture is left as it is. The event is only claimed when the strip can
  /// actually move, so the rest of the window keeps its wheel.
  void _onScrollSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    if (!_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    if (position.maxScrollExtent <= 0) {
      return;
    }
    final double delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) {
      return;
    }
    final double target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onScrollSignal,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
