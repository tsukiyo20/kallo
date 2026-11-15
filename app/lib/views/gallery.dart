import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/mobile.dart';
import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/print.dart';
import '../lab/stock.dart';
import '../lab/thumbnails.dart';
import '../widgets/glass_print.dart';
import '../widgets/lens.dart';
import '../widgets/mobile/mobile_controls.dart';
import '../widgets/mobile/mobile_icon.dart';
import '../widgets/print_image.dart';
import '../widgets/shadow_box.dart';
import '../widgets/wall.dart';

/// The gallery: the last place. One wall, every print, one lamp.
///
/// A print is not a picture, it is a sheet of paper reflecting whatever light
/// falls on it. So the room is built the way that physics is built: every
/// surface is a reflectance, the lamp is a single number, and the number is
/// multiplied into each of them.
///
/// The wall is the window's: a gallery is white in daylight and dark after
/// hours. The lamp is the gallery's: turn it off and the wall goes black, the
/// labels go with it — and the prints do not go out, they stay at a tenth. What
/// does not move is the window around them. Turning a lamp off is not the same
/// event as the system changing its theme, and a person who turned the light
/// off to look at a print still has to be able to find the way back.
///
/// The work on this wall is paper. A print is cropped to the frame's image
/// area — the enlarger's carrier masks the rebate — so what comes out of the
/// tray is the picture and the margin the sheet gives it, and there is no
/// sprocket hole anywhere on it. The film's own edge is a different print: a
/// full-frame print is asked for when the print is made, and it is not the
/// thing that hangs here.
///
/// The wall is arranged in a grid and not hung like a salon, because a grid is
/// the only arrangement that says nothing about the pictures: five developments
/// of one negative are five equal things, and the wall should not pretend to
/// prefer one.
class Gallery extends StatefulWidget {
  const Gallery({
    super.key,
    required this.prints,
    required this.light,
    this.loupe = false,
    this.onNear,
    this.topInset = 0,
    this.onOpenDarkroom,
  });

  /// Everything exported, oldest first.
  final List<Print> prints;

  /// The lamp on the wall, from off to all of it. It is the room's, and it
  /// takes the wall and the work with it — not the window around them.
  final double light;

  /// Whether the loupe is out. It is a tool on the wall, not a cursor: off,
  /// the wall is only paper; on, the print under the pointer is read through
  /// glass.
  final bool loupe;

  /// Called when the wall is left for one print, and when it is returned to.
  /// The loupe switch belongs to the wall, so the chrome can leave it behind
  /// while a print fills the window.
  final ValueChanged<bool>? onNear;

  /// The transparent chrome over the wall: the grid starts below it.
  final double topInset;

  /// The one way out of an empty phone wall. Null on the desktop, where the
  /// sidebar is the way out.
  final VoidCallback? onOpenDarkroom;

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  /// The print being looked at closely, if one is.
  Print? _near;

  /// The print under the lens, and where the lens is.
  ///
  /// The lens is a loupe held over the print, not a picture viewer: it shows
  /// the paper at three times the wall, from a decode wide enough that the
  /// glass has something to show. It goes away when the pointer does or the
  /// loupe is put away, and clicking still walks up to the whole print.
  Print? _lensFor;
  ui.Image? _lens;
  Timer? _lensTimer;
  Offset _lensAt = Offset.zero;
  Offset _lensPoint = Offset.zero;
  double _lensWidth = 0;

  /// The wall's box, which is where the lens is placed.
  final GlobalKey _field = GlobalKey(debugLabel: 'wall');

  void _lookAt(Print print, Offset local, double width, Offset global) {
    if (!widget.loupe) {
      return;
    }
    final RenderBox? box =
        _field.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    if (!identical(print, _lensFor)) {
      _lensFor = print;
      _dropLens();
      // A sweep across a wall must not decode one file per print. The glass
      // waits until the pointer rests, then asks for the print under it.
      _lensTimer?.cancel();
      _lensTimer = Timer(
        const Duration(milliseconds: 90),
        () => unawaited(_loadLens(print)),
      );
    }
    setState(() {
      _lensAt = box.globalToLocal(global);
      _lensPoint = local;
      _lensWidth = width;
    });
  }

  void _leaveLens() {
    if (_lensFor == null) {
      return;
    }
    _lensTimer?.cancel();
    setState(() {
      _lensFor = null;
      _dropLens();
    });
  }

  /// Walk up to one print, and leave the wall's tools behind.
  void _walkUp(Print print) {
    setState(() => _near = print);
    widget.onNear?.call(true);
  }

  void _backToWall() {
    setState(() => _near = null);
    widget.onNear?.call(false);
  }

  /// Free the magnified copy, but only after the frame that drew it: a texture
  /// disposed while it is on screen is a texture that draws as nothing.
  void _dropLens() {
    final ui.Image? old = _lens;
    _lens = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  Future<void> _loadLens(Print print) async {
    final ui.Image? image = await print.magnified();
    if (!mounted || !identical(print, _lensFor)) {
      image?.dispose();
      return;
    }
    setState(() => _lens = image);
  }

  @override
  void dispose() {
    _lensTimer?.cancel();
    _lens?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Gallery old) {
    super.didUpdateWidget(old);
    // Prints are re-read when the folder changes, and the one in hand is about
    // to be disposed: a loupe cannot look at a texture that no longer exists.
    final Print? near = _near;
    if (near != null && !widget.prints.any((Print p) => identical(p, near))) {
      _near = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onNear?.call(false);
        }
      });
    }
    final Print? lens = _lensFor;
    if (!widget.loupe ||
        (lens != null && !widget.prints.any((Print p) => identical(p, lens)))) {
      _lensTimer?.cancel();
      _lensFor = null;
      _dropLens();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The wall is the appearance's: a gallery is white in daylight and dark
    // after hours, and the lamp goes out in both.
    final KalloWall wall = KalloWall.of(
      KalloScope.colorsOf(context).brightness,
    );
    final double light = widget.light;
    final Print? near = _near;
    // The print holds its light better than the room does, for the same reason
    // everything else does not: the eye is the instrument here, not the lamp.
    final double printed =
        KalloWall.darkAdaptation + (1 - KalloWall.darkAdaptation) * light;
    final List<Print> prints = widget.prints;
    final KalloStrings s = KalloStrings.of(context);

    if (near != null) {
      return _Loupe(
        print: near,
        wall: wall,
        light: light,
        printed: printed,
        onClose: _backToWall,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints room) {
        final bool compact = KalloLayout.isCompact(context);
        if (compact && prints.isEmpty) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Wall(wall: wall, light: light),
              KalloMobileEmpty(
                glyph: KalloGlyph.gallery,
                title: s.emptyGalleryTitle,
                message: s.emptyGalleryNote,
                action: widget.onOpenDarkroom == null
                    ? null
                    : SizedBox(
                        width: 220,
                        child: KalloMobileButton(
                          label: s.makePrint,
                          onTap: widget.onOpenDarkroom,
                        ),
                      ),
              ),
            ],
          );
        }
        final double gap = compact ? 12 : 28;
        final double margin = compact ? 16 : 40;
        // The wall fades into the floor, and the grid stops above it.
        final double floor = compact ? 24 : 96;
        final double available = math.max(200, room.maxWidth - margin * 2);
        // Three prints across a 1280 window, four across a wide one, and never
        // fewer columns than there are prints to put in them.
        final int fitting = math.max(
          1,
          math.min(
            compact ? 2 : 5,
            ((available + gap) / (compact ? 180 : 328)).floor(),
          ),
        );
        final int columns = math.max(1, math.min(prints.length, fitting));
        // A wall hangs one sheet, and a sheet is a picture plus the margin the
        // paper gives it, so a portrait print and a landscape one cannot be
        // both the same width and the same amount of paper: a portrait sheet
        // would be nearly twice the area of a landscape one. They are given the
        // same **area** instead, and `sheet` is the width a landscape 3:2 sheet
        // of that area would have.
        final double perWidth = prints.isEmpty
            ? PrintSheet.heightPerWidth(aspect: 1.5)
            : prints
                  .map(
                    (Print print) =>
                        PrintSheet.heightPerWidth(aspect: print.aspect),
                  )
                  .fold(PrintSheet.heightPerWidth(aspect: 1.5), math.max);
        final double sheet = math.min(
          math.min(
            (available - gap * (columns - 1)) / columns,
            (room.maxHeight - floor - (compact ? 8 : 40)) / perWidth,
          ),
          compact ? 240 : KalloWall.largest,
        );
        // A landscape 3:2 sheet gets the full `sheet` width; a portrait gets
        // the same area, so it is the same paper turned.
        final double area = sheet * PrintSheet.heightOf(sheet, aspect: 1.5);
        double widthOf(Print print) =>
            math.sqrt(area / PrintSheet.heightPerWidth(aspect: print.aspect));
        double heightOf(Print print) =>
            PrintSheet.heightOf(widthOf(print), aspect: print.aspect);
        final int rows = (prints.length / columns).ceil();
        final double tallest = prints.isEmpty
            ? 0.0
            : prints.map(heightOf).reduce(math.max);
        final double height =
            math.max(sheet * PrintSheet.heightPerWidth(aspect: 1.5), tallest) +
            (compact ? 0 : 48);
        final double content = rows * height + math.max(0, rows - 1) * gap;
        final double top = compact
            ? KalloMobileSpace.step2
            : math.max(
                margin + widget.topInset,
                (room.maxHeight - content) / 2,
              );

        final List<List<Print>> lines = <List<Print>>[
          for (int i = 0; i < prints.length; i += columns)
            prints.sublist(i, math.min(i + columns, prints.length)),
        ];

        return Stack(
          key: _field,
          fit: StackFit.expand,
          children: <Widget>[
            Wall(wall: wall, light: light),
            if (prints.isNotEmpty)
              ListView.builder(
                key: const PageStorageKey<String>('gallery-wall'),
                padding: EdgeInsets.fromLTRB(margin, top, margin, floor),
                itemCount: lines.length,
                itemBuilder: (BuildContext context, int row) {
                  final List<Print> line = lines[row];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: row == lines.length - 1 ? 0 : gap,
                    ),
                    child: SizedBox(
                      height: height,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int i = 0; i < line.length; i++) ...<Widget>[
                            if (i > 0) SizedBox(width: gap),
                            _Hung(
                              print: line[i],
                              printNumber: line[i].printNumber,
                              wall: wall,
                              width: widthOf(line[i]),
                              showLabel: !compact,
                              light: light,
                              printed: printed,
                              cursor: widget.loupe && _lensFor != null
                                  ? SystemMouseCursors.none
                                  : SystemMouseCursors.click,
                              onHover: widget.loupe
                                  ? (Offset local, Offset global) => _lookAt(
                                      line[i],
                                      local,
                                      widthOf(line[i]),
                                      global,
                                    )
                                  : null,
                              onLeave: widget.loupe ? _leaveLens : null,
                              onTap: () => _walkUp(line[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (widget.loupe &&
                _lensFor != null &&
                (_lens ?? _lensFor!.image) != null)
              _Lens(
                key: const Key('lens'),
                at: _lensAt,
                width: _lensWidth,
                point: _lensPoint,
                image: (_lens ?? _lensFor!.image)!,
                light: printed,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: floor,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        KalloColors.under(
                          wall.base,
                          light,
                        ).withValues(alpha: 0),
                        KalloColors.under(wall.base, light),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The print, looked at closely.
///
/// The wall hangs a sheet 660 points wide because that is what a wall is; the
/// file the model wrote is 6000, and the difference is the whole point of
/// walking up to it. The paper does not grow — this is not a picture viewer,
/// it is a loupe on a print — so the sheet keeps its size and shape, its margin
/// holds still, and the picture is magnified *inside* it, inside the picture's
/// own rectangle. What you never see is a photograph floating on a background:
/// you see paper, and a corner of the print enlarged.
///
/// The scale readout is absolute: it says how big one of the file's pixels is
/// on this display, so `1:1` means one image pixel per device pixel and is as
/// far as the loupe goes. Past that there is nothing left in the file to show.
///
/// Walking up to a print is flat: the picture moves inside the paper, and the
/// paper stays paper. Glass belongs to the loupe on the wall, not to this view
/// — a lens is how you look, not what the print is.
class _Loupe extends StatefulWidget {
  const _Loupe({
    required this.print,
    required this.wall,
    required this.light,
    required this.printed,
    required this.onClose,
  });

  final Print print;

  /// Which wall: the one the print was hanging on.
  final KalloWall wall;

  /// The room's light: the wall and its label are under it.
  final double light;

  /// The light on the print, which holds a little after the wall has gone out.
  final double printed;

  final VoidCallback onClose;

  @override
  State<_Loupe> createState() => _LoupeState();
}

class _LoupeState extends State<_Loupe> {
  /// The file's own pixels, once they have been decoded. The thumbnail stands
  /// in until then, which is what the eye was already looking at.
  ui.Image? _full;
  PrintThumbnail? _thumbnail;

  /// Magnification over the fit: 1 is the whole picture, and the ceiling is
  /// the scale at which one image pixel is one device pixel.
  double _mag = 1;

  /// Where the picture is held, in points, from the centre of its box.
  Offset _pan = Offset.zero;
  double _gestureMag = 1;
  Offset _gesturePan = Offset.zero;

  /// The loupe takes the keyboard while it is open, so that escape closes it
  /// rather than anything behind it. The room already has a focus node and
  /// autofocus on this one would not take it away from a node that has it.
  final FocusNode _keys = FocusNode(debugLabel: 'loupe');

  @override
  void initState() {
    super.initState();
    unawaited(_loadThumbnail());
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keys.requestFocus();
      }
    });
  }

  Future<void> _loadThumbnail() async {
    final PrintThumbnail? thumbnail = await PrintThumbnailCache.instance
        .acquire(widget.print);
    if (!mounted || _full != null) {
      thumbnail?.release();
      return;
    }
    setState(() => _thumbnail = thumbnail);
  }

  Future<void> _load() async {
    final ui.Image? full = await widget.print.full();
    if (!mounted) {
      full?.dispose();
      return;
    }
    setState(() => _full = full);
  }

  @override
  void dispose() {
    _full?.dispose();
    _thumbnail?.release();
    _keys.dispose();
    super.dispose();
  }

  /// The image and the size it says it is: the file's, the thumbnail's, or the
  /// wall's copy when the print had no file behind it.
  ({ui.Image image, Size pixels})? get _pixels {
    final ui.Image? full = _full;
    if (full != null) {
      final Size? declared = widget.print.pixels;
      return (
        image: full,
        pixels: declared ?? Size(full.width.toDouble(), full.height.toDouble()),
      );
    }
    final ui.Image? image = _thumbnail?.image ?? widget.print.image;
    if (image == null) {
      return null;
    }
    return (
      image: image,
      pixels:
          widget.print.pixels ??
          Size(image.width.toDouble(), image.height.toDouble()),
    );
  }

  Widget _waiting(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        focusNode: _keys,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Wall(wall: widget.wall, light: widget.light),
            Center(
              child: Text(
                widget.print.folio,
                style: KalloType.title.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One image pixel per device pixel, as a magnification over the fit.
  double _ceiling(double fit) => fit >= 1 ? 1 : 1 / fit;

  @override
  Widget build(BuildContext context) {
    final KalloStrings s = KalloStrings.of(context);
    final KalloColors colors = KalloScope.colorsOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double light = widget.light;
    final ({ui.Image image, Size pixels})? shown = _pixels;
    if (shown == null) {
      return _waiting(context);
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        focusNode: _keys,
        child: PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, void result) {
            if (!didPop) {
              widget.onClose();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Wall(wall: widget.wall, light: light),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints room) {
                  final Size pixels = shown.pixels;
                  final double aspect = pixels.width / pixels.height;
                  final double perWidth = PrintSheet.heightPerWidth(
                    aspect: aspect,
                  );
                  final double freeWidth = math.max(240, room.maxWidth - 80);
                  final double freeHeight = math.max(200, room.maxHeight - 150);
                  final double sheetWidth = math.min(
                    freeWidth,
                    freeHeight / perWidth,
                  );
                  final double sheetHeight = PrintSheet.heightOf(
                    sheetWidth,
                    aspect: aspect,
                  );
                  final Rect picture = PrintSheet.pictureOf(
                    sheetWidth,
                    aspect: aspect,
                  );
                  final double fit = math.min(
                    1,
                    dpr * picture.width / pixels.width,
                  );
                  final double ceiling = _ceiling(fit);
                  final double mag = _mag.clamp(1.0, ceiling);
                  final double percent = fit * mag * 100;
                  final double limitX =
                      math.max(0, picture.width * mag - picture.width) / 2;
                  final double limitY =
                      math.max(0, picture.height * mag - picture.height) / 2;
                  final Offset pan = _clamp(_pan, Size(limitX, limitY));
                  final double sourceWidth = pixels.width / mag;
                  final double sourceHeight = pixels.height / mag;
                  final Offset centre = Offset(
                    pixels.width / 2 - pan.dx * sourceWidth / picture.width,
                    pixels.height / 2 - pan.dy * sourceHeight / picture.height,
                  );
                  final Rect source = Rect.fromLTWH(
                    (centre.dx - sourceWidth / 2).clamp(
                      0,
                      math.max(0, pixels.width - sourceWidth),
                    ),
                    (centre.dy - sourceHeight / 2).clamp(
                      0,
                      math.max(0, pixels.height - sourceHeight),
                    ),
                    sourceWidth,
                    sourceHeight,
                  );

                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Align(
                        alignment: const Alignment(0, -0.12),
                        child: SizedBox(
                          width: sheetWidth,
                          height: sheetHeight,
                          child: Stack(
                            children: <Widget>[
                              PrintSheet(
                                width: sheetWidth,
                                aspect: aspect,
                                paper: colors.print,
                                outline: colors.hairline.withValues(
                                  alpha: 0.35,
                                ),
                                light: widget.printed,
                                child: GlassPrint(
                                  image: shown.image,
                                  source: source,
                                ),
                              ),
                              Positioned.fromRect(
                                rect: picture,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.zoomIn,
                                  child: Listener(
                                    onPointerSignal:
                                        (PointerSignalEvent event) {
                                          if (event is PointerScrollEvent) {
                                            _zoom(event, picture.size, ceiling);
                                          }
                                        },
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onScaleStart: (ScaleStartDetails d) {
                                        _gestureMag = _mag;
                                        _gesturePan = _pan;
                                      },
                                      onScaleUpdate: (ScaleUpdateDetails d) {
                                        setState(() {
                                          _mag = (_gestureMag * d.scale).clamp(
                                            1.0,
                                            ceiling,
                                          );
                                          _pan = _clamp(
                                            _gesturePan + d.focalPointDelta,
                                            Size(limitX, limitY),
                                          );
                                        });
                                      },
                                      onDoubleTap: () => setState(() {
                                        _mag = _mag >= ceiling - 0.001
                                            ? 1
                                            : ceiling;
                                        _pan = Offset.zero;
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 40,
                        right: 40,
                        bottom: 28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text.rich(
                                    TextSpan(
                                      children: wallLabel(
                                        light: light,
                                        wall: widget.wall,
                                        film: filmEdgeName(widget.print.film),
                                        clock: widget.print.clock,
                                        paper: widget.print.paperDisplay,
                                        fallback: widget.print.name,
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KalloType.small.copyWith(
                                      letterSpacing: 0.2,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.magnification(
                                      '${pixels.width.round()} × '
                                      '${pixels.height.round()}',
                                      percent >= 99.5
                                          ? s.actualPixels
                                          : '${percent.round()} %',
                                    ),
                                    style: KalloType.data.copyWith(
                                      color: KalloColors.under(
                                        widget.wall.label,
                                        light,
                                      ).withValues(alpha: 0.60),
                                      fontFeatures: const <FontFeature>[
                                        FontFeature('tnum'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: KalloSpace.step3),
                            _Pill(
                              key: const Key('back'),
                              label: s.back,
                              control: widget.wall.controlAt(light),
                              onTap: widget.onClose,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zoom about the pointer, so that what is under it stays under it.
  void _zoom(PointerScrollEvent event, Size picture, double ceiling) {
    final double current = _mag;
    final double next = (current * math.exp(-event.scrollDelta.dy / 420)).clamp(
      1.0,
      ceiling,
    );
    if ((next - current).abs() < 0.001) {
      return;
    }
    final Offset centre = Offset(picture.width / 2, picture.height / 2);
    final Offset held = event.localPosition - centre;
    setState(() {
      _pan = _clamp(
        _pan * (next / current) + held * (1 - next / current),
        Size(
          math.max(0, picture.width * next - picture.width) / 2,
          math.max(0, picture.height * next - picture.height) / 2,
        ),
      );
      _mag = next;
    });
  }

  static Offset _clamp(Offset value, Size limit) => Offset(
    value.dx.clamp(-limit.width, limit.width),
    value.dy.clamp(-limit.height, limit.height),
  );
}

/// A control on the wall, lit by itself: a pill you can still find in the dark.
class _Pill extends StatefulWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.control,
    required this.onTap,
  });

  final String label;

  /// The wall's own light: a pale control on a dark wall, ink on a light one.
  final Color control;

  final VoidCallback onTap;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color control = widget.control;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: KalloSpace.step3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: control.withValues(alpha: _hover ? 0.10 : 0.04),
            borderRadius: BorderRadius.circular(KalloRadius.control),
            border: Border.all(
              color: control.withValues(alpha: _hover ? 0.28 : 0.16),
            ),
          ),
          child: Text(
            widget.label,
            style: KalloType.small.copyWith(
              color: control.withValues(alpha: _hover ? 0.92 : 0.70),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// One print on the wall: a sheet of paper, with the label under it.
class _Hung extends StatelessWidget {
  const _Hung({
    required this.print,
    required this.printNumber,
    required this.wall,
    required this.width,
    required this.light,
    required this.printed,
    required this.cursor,
    this.showLabel = true,
    required this.onHover,
    required this.onLeave,
    required this.onTap,
  });

  final Print print;
  final int printNumber;

  /// Which wall: the light one in a light appearance, the dark one after dark.
  final KalloWall wall;

  /// The sheet's width on the wall: the picture and the paper around it.
  final double width;

  /// The light on the wall, which the label is on.
  final double light;

  /// The light on the print, which holds a little longer.
  final double printed;

  /// What the pointer is over the print: a hand until the loupe is up, and
  /// then nothing — the glass is where the pointer is, and a hand inside it is
  /// a hand on the picture.
  final MouseCursor cursor;

  /// A phone wall is only the paper. The label would be four points tall at
  /// this width; the viewer carries it instead.
  final bool showLabel;

  /// The lens: the pointer over the print, its place on the sheet, and where
  /// it is on the wall. Null when the loupe is put away.
  final void Function(Offset local, Offset global)? onHover;
  final VoidCallback? onLeave;

  /// Walking up to the print: the loupe.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final String stock = filmEdgeName(print.film);
    final String number = printNumber.toString().padLeft(2, '0');
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MouseRegion(
            cursor: cursor,
            onHover: onHover == null
                ? null
                : (PointerHoverEvent event) =>
                      onHover!(event.localPosition, event.position),
            onExit: onLeave == null ? null : (_) => onLeave!(),
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                label: stock.isEmpty
                    ? '${print.name} · $number'
                    : '$stock · $number',
                child: KalloShadowBox(
                  kind: KalloShadowKind.paper,
                  child: PrintSheet(
                    width: width,
                    aspect: print.aspect,
                    paper: colors.print,
                    outline: colors.hairline.withValues(alpha: 0.35),
                    light: printed,
                    child: PrintImage(print: print),
                  ),
                ),
              ),
            ),
          ),
          if (showLabel) ...<Widget>[
            const SizedBox(height: KalloSpace.step3 - 2),
            Text.rich(
              TextSpan(
                children: wallLabel(
                  light: light,
                  wall: wall,
                  film: filmEdgeName(print.film),
                  clock: print.clock,
                  paper: print.paperDisplay,
                  fallback: print.name,
                ),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KalloType.small.copyWith(
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A loupe held over the wall.
///
/// It is the print at three times the wall, from a decode wide enough that the
/// glass has something to show: magnifying the wall's own copy would only
/// magnify a screen image. The glass is a real object — a bezel and a
/// reflection — because a loupe is held, and a circle of nothing is not held.
///
/// The paper and its margin stay flat under the glass; the picture is what
/// bows at the edge, because a lens is not a window and paper does not bend.
class _Lens extends StatelessWidget {
  const _Lens({
    super.key,
    required this.at,
    required this.width,
    required this.point,
    required this.image,
    required this.light,
  });

  /// Where the lens is, in the wall's coordinates.
  final Offset at;

  /// The sheet's width on the wall.
  final double width;

  /// Where the pointer is on the print.
  final Offset point;

  /// The print's picture, at the best size there is.
  final ui.Image image;

  /// The light on the print.
  final double light;

  static const double radius = 90;

  /// Three times the wall is enough to read a grain without making the glass
  /// a window. The bow is deliberately small: a real loupe is corrected, and
  /// the eye should notice the glass at the edge rather than watch the picture
  /// bend all the way across.
  static const double _magnification = 3;
  static const double _barrel = 0.05;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final double aspect = image.width / image.height;
    final double sheetWidth = width * _magnification;
    return KalloLens(
      at: at,
      radius: radius,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: radius - point.dx * _magnification,
            top: radius - point.dy * _magnification,
            child: PrintSheet(
              width: sheetWidth,
              aspect: aspect,
              paper: colors.print,
              outline: colors.hairline.withValues(alpha: 0.35),
              light: light,
              child: GlassPrint(image: image, barrel: _barrel),
            ),
          ),
        ],
      ),
    );
  }
}
