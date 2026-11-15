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
import 'print_viewer.dart';
import 'wall_places.dart';

/// The gallery: the last place. One wall, every print.
///
/// A print is not a picture, it is a sheet of paper reflecting whatever light
/// falls on it. So the room is built the way that physics is built: every
/// surface is a reflectance, the room's light is a single number, and the number
/// is multiplied into each of them.
///
/// The wall is the window's: a gallery is white in daylight and dark after
/// hours. Its light is the room's — there is no switch in the chrome — but the
/// number stays a number, because that is how a wall is drawn: the paper and the
/// labels are reflections, and a print you can find in a room that has gone dark
/// is a print at a tenth.
///
/// The work on this wall is paper. A print is cropped to the frame's image
/// area — the enlarger's carrier masks the rebate — so what comes out of the
/// tray is the picture and the margin the sheet gives it, and there is no
/// sprocket hole anywhere on it. The film's own edge is a different print: a
/// full-frame print is asked for when the print is made, and it is not the
/// thing that hangs here.
///
/// The wall is longer than the window. It used to be a grid inside one window,
/// as if the room ended at the edge of the screen, and the arrangement was the
/// app's: a grid says nothing about the pictures, and five developments of one
/// negative are five equal things. It still says that until a person touches
/// it. The wall hangs the work in that same grid, and the first sheet a person
/// moves freezes the whole hanging; after that the wall is theirs. It can be
/// walked — dragged, pinched, scrolled — a sheet can be hung anywhere on it,
/// and work that arrives later is hung in a fresh line beneath what is already
/// there. Hanging the wall back in its own grid is one quiet word at the bottom
/// of it.
class Gallery extends StatefulWidget {
  const Gallery({
    super.key,
    required this.prints,
    required this.hanging,
    this.onHang,
    this.onRehang,
    this.light = 1,
    this.loupe = false,
    this.onNear,
    this.topInset = 0,
    this.onOpenDarkroom,
  });

  /// Everything exported, newest first: the print just made is the one worth
  /// seeing.
  final List<Print> prints;

  /// Where the wall hangs each print, by the print's id.
  ///
  /// Empty means nobody has hung this wall: the gallery arranges its own grid.
  final Map<String, Offset> hanging;

  /// Called with the whole hanging when a sheet has been hung somewhere, and
  /// when the wall is hung back in its grid.
  final ValueChanged<Map<String, Offset>>? onHang;
  final VoidCallback? onRehang;

  /// The light on the wall, from off to all of it. It is the room's — the
  /// chrome does not switch it — and it is multiplied into the wall, the labels
  /// and the paper. It exists because the wall is drawn as a surface, not
  /// because there is a switch anywhere.
  final double light;

  /// Whether the loupe is out. It is a tool on the wall, not a cursor: off,
  /// the wall is only paper; on, the print under the pointer is read through
  /// glass.
  final bool loupe;

  /// Called when the wall is left for one print, and when it is returned to.
  /// The loupe switch belongs to the wall, so the chrome can leave it behind
  /// while a print fills the window.
  final ValueChanged<bool>? onNear;

  /// The transparent chrome over the wall: the wall is opened below it.
  final double topInset;

  /// The one way out of an empty phone wall. Null on the desktop, where the
  /// sidebar is the way out.
  final VoidCallback? onOpenDarkroom;

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> with SingleTickerProviderStateMixin {
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

  /// The hanging as the wall shows it. It is the widget's, except while a
  /// sheet is being dragged and until the room has written the move down.
  late Map<String, Offset> _hanging = widget.hanging;

  /// Where the wall is looked at from: a translation and one scale.
  final TransformationController _view = TransformationController();

  /// The glide between one view of the wall and another: home, or work that
  /// has just arrived.
  late final AnimationController _glide;
  Matrix4Tween? _glideTween;
  int _glideRun = 0;

  /// Whether the app is moving the view rather than the person.
  bool _quiet = false;

  /// Whether a person has walked the wall, zoomed it, or hung a sheet. Until
  /// they have, the wall keeps putting the work where it belongs.
  bool _touched = false;

  /// The window the wall is looked through, and whether it has been opened
  /// once. The wall opens at its beginning; it is not re-centred on every
  /// frame.
  Size _viewport = Size.zero;
  bool _opened = false;

  /// The sheet in hand: which one, where it was picked up, and where the
  /// pointer was at that moment.
  String? _dragKey;
  Print? _dragPrint;
  Offset _dragFrom = Offset.zero;
  Offset _dragPointer = Offset.zero;
  Offset? _dragAt;

  /// The print hung last, which lies on top of the others.
  String? _topKey;

  /// The wall's coordinate space, in wall points. The stack that holds the
  /// sheets starts at zero, so wall coordinates are shifted by half of it.
  static const double _extent = WallPlaces.reach;
  static const double _world = WallPlaces.reach * 2;

  @override
  void initState() {
    super.initState();
    _view.addListener(_viewChanged);
    _glide = AnimationController(vsync: this, duration: KalloMotion.slow)
      ..addListener(_glideTick);
  }

  @override
  void dispose() {
    _lensTimer?.cancel();
    _lens?.dispose();
    _glide.dispose();
    _view.dispose();
    super.dispose();
  }

  void _viewChanged() {
    if (!_quiet) {
      _touched = true;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _glideTick() {
    final Matrix4Tween? tween = _glideTween;
    if (tween == null) {
      return;
    }
    _quiet = true;
    _view.value = tween.lerp(KalloMotion.enter.transform(_glide.value));
    _quiet = false;
  }

  /// Stop walking the wall under a person who has taken hold of it.
  void _stopGlide() {
    if (!_glide.isAnimating) {
      return;
    }
    _glide.stop();
  }

  void _glideTo(Matrix4 target) {
    if (_viewport.isEmpty) {
      _quiet = true;
      _view.value = target;
      _quiet = false;
      return;
    }
    final int run = ++_glideRun;
    _glideTween = Matrix4Tween(begin: _view.value.clone(), end: target);
    _quiet = true;
    _glide.forward(from: 0).whenCompleteOrCancel(() {
      if (run != _glideRun || !mounted) {
        return;
      }
      _quiet = false;
      _glideTween = null;
    });
  }

  /// The wall's zoom: the length of the first basis vector of its transform.
  ///
  /// The transform is a translation and one scale, so this is the whole story.
  /// `getMaxScaleOnAxis` is not: it also weighs the w axis, which is 1 for an
  /// affine transform and would answer 1 at every zoom.
  static double _zoomOf(Matrix4 view) => view.storage[0];

  /// The room the wall is looked through: the window, less its chrome.
  Rect _usable(Size size) {
    final bool compact = KalloLayout.isCompact(context);
    final double margin = compact ? 16 : 40;
    final double top = compact
        ? KalloMobileSpace.step3
        : widget.topInset + margin;
    final double floor = compact ? KalloMobileSpace.step5 : 96;
    return Rect.fromLTRB(
      margin,
      top,
      math.max(margin + 1, size.width - margin),
      math.max(top + 1, size.height - floor),
    );
  }

  /// The view the wall opens on: its beginning when the whole hanging fits,
  /// and the newest work when it does not.
  Matrix4 _homeMatrix({WallPlaces? hanging}) {
    final WallPlaces wall = hanging ?? WallPlaces(_hanging);
    final Rect usable = _usable(_viewport);
    final Offset origin = const Offset(_extent, _extent);
    if (widget.prints.isEmpty) {
      final Offset spot = usable.center - origin;
      return Matrix4.identity()..translateByDouble(spot.dx, spot.dy, 0, 1);
    }
    final Map<String, Offset> places = wall.resolve(widget.prints);
    final Rect content = wall.bounds(widget.prints, places);
    final double fit = math.min(
      usable.width / math.max(1, content.width),
      usable.height / math.max(1, content.height),
    );
    final double step = KalloLayout.isCompact(context) ? 0.5 : 0.25;
    final double scale = fit.clamp(step, 1.0);
    final Offset spot;
    if (fit < step) {
      // Bigger than the window at the furthest step back: show the wall's
      // beginning, where the newest print hangs.
      spot = usable.topLeft - (content.topLeft + origin) * scale;
    } else {
      spot = usable.center - (content.center + origin) * scale;
    }
    return Matrix4.identity()
      ..translateByDouble(spot.dx, spot.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _goHome({bool animate = true, WallPlaces? hanging}) {
    if (_viewport.isEmpty) {
      return;
    }
    final Matrix4 target = _homeMatrix(hanging: hanging);
    if (!animate) {
      _quiet = true;
      _view.value = target;
      _quiet = false;
      return;
    }
    _glideTo(target);
  }

  /// Open the wall once the window it is looked through has a size.
  void _open(Size size) {
    _viewport = size;
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _goHome(animate: false);
      }
    });
  }

  /// Glide to work that has just arrived, so a person sees what they brought
  /// in.
  void _reveal(List<Print> added) {
    if (_viewport.isEmpty) {
      _goHome();
      return;
    }
    final WallPlaces wall = WallPlaces(_hanging);
    final Map<String, Offset> places = wall.resolve(widget.prints);
    final Rect usable = _usable(_viewport);
    final Offset origin = const Offset(_extent, _extent);
    final Set<Print> fresh = Set<Print>.identity()..addAll(added);
    Rect? rect;
    for (int i = 0; i < widget.prints.length; i++) {
      final Print print = widget.prints[i];
      if (!fresh.contains(print)) {
        continue;
      }
      final Offset? at = places[WallPlaces.keyOf(print, i)];
      if (at == null) {
        continue;
      }
      final Rect one = WallPlaces.rectOf(print, at);
      rect = rect == null ? one : rect.expandToInclude(one);
    }
    if (rect == null) {
      _goHome();
      return;
    }
    final double fit = math.min(
      usable.width / math.max(1, rect.width),
      usable.height / math.max(1, rect.height),
    );
    final double scale = (fit * 0.9).clamp(0.5, 1.0);
    final Offset spot = usable.center - (rect.center + origin) * scale;
    _glideTo(
      Matrix4.identity()
        ..translateByDouble(spot.dx, spot.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1),
    );
  }

  /// Where every print is, with the sheet in hand at the pointer.
  Map<String, Offset> _places() {
    final Map<String, Offset> places = WallPlaces(_hanging)
        .resolve(widget.prints);
    final Offset? at = _dragAt;
    final String? key = _dragKey;
    if (at != null && key != null) {
      places[key] = at;
    }
    return places;
  }

  Offset _clampPlace(Print print, Offset at) {
    final Size paper = WallPlaces.sizeOf(print);
    const double edge = 40;
    return Offset(
      at.dx.clamp(-_extent + edge, _extent - paper.width - edge),
      at.dy.clamp(
        -_extent + edge,
        _extent - paper.height - WallPlaces.labelSpace - edge,
      ),
    );
  }

  void _pickUp(Print print, String key, Offset place, Offset pointer) {
    setState(() {
      _dragKey = key;
      _dragPrint = print;
      _dragFrom = place;
      _dragPointer = pointer;
      _dragAt = place;
      _topKey = key;
    });
  }

  void _dragTo(Offset pointer) {
    final Print? print = _dragPrint;
    if (print == null) {
      return;
    }
    final double scale = _zoomOf(_view.value);
    if (scale <= 0) {
      return;
    }
    final Offset next = _dragFrom + (pointer - _dragPointer) / scale;
    setState(() => _dragAt = _clampPlace(print, next));
  }

  void _hangUp() {
    final String? key = _dragKey;
    final Offset? at = _dragAt;
    if (key == null || at == null) {
      _cancelDrag();
      return;
    }
    final Map<String, Offset> next = WallPlaces(_hanging)
        .moved(widget.prints, key, at)
        .byId;
    setState(() {
      _hanging = next;
      _dragKey = null;
      _dragPrint = null;
      _dragAt = null;
      _topKey = key;
    });
    widget.onHang?.call(next);
  }

  void _cancelDrag() {
    setState(() {
      _dragKey = null;
      _dragPrint = null;
      _dragAt = null;
    });
  }

  /// Put the hanging back in the wall's own grid.
  void _rehang() {
    setState(() {
      _hanging = const <String, Offset>{};
      _dragKey = null;
      _dragPrint = null;
      _dragAt = null;
    });
    widget.onRehang?.call();
    _goHome(hanging: const WallPlaces());
  }

  void _lookAt(Print print, Offset local, double paperWidth, Offset global) {
    if (!widget.loupe) {
      return;
    }
    final RenderBox? box =
        _field.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final double scale = _zoomOf(_view.value);
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
      _lensPoint = local * scale;
      _lensWidth = paperWidth * scale;
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
  ///
  /// A phone does not have the room for the paper's own close view: the wall
  /// is the index, and a tap opens the picture on a page of its own. The
  /// desktop keeps the print whole, because there the paper has the room to
  /// be paper.
  void _walkUp(Print print) {
    if (KalloLayout.isCompact(context)) {
      unawaited(openPrintViewer(context, print));
      return;
    }
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
  void didUpdateWidget(Gallery old) {
    super.didUpdateWidget(old);
    if (!identical(old.hanging, widget.hanging)) {
      _hanging = widget.hanging;
    }
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
    // Work that arrived while the wall was being looked at: a picture brought
    // in is worth seeing, and a wall nobody has walked is put right.
    final Set<String> before = <String>{
      for (int i = 0; i < old.prints.length; i++)
        WallPlaces.keyOf(old.prints[i], i),
    };
    final Set<String> after = <String>{
      for (int i = 0; i < widget.prints.length; i++)
        WallPlaces.keyOf(widget.prints[i], i),
    };
    if (before.length == after.length && before.containsAll(after)) {
      return;
    }
    final List<Print> added = <Print>[
      for (int i = 0; i < widget.prints.length; i++)
        if (!before.contains(WallPlaces.keyOf(widget.prints[i], i)))
          widget.prints[i],
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (added.isNotEmpty && _touched) {
        _reveal(added);
      } else if (!_touched) {
        _goHome(animate: false);
      }
    });
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
        final Size size = Size(room.maxWidth, room.maxHeight);
        _open(size);

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

        final double margin = compact ? 16 : 40;
        final double floor = compact ? KalloMobileSpace.step5 : 96;
        final Map<String, Offset> places = _places();
        final Matrix4 view = _view.value;
        final double scale = _zoomOf(view);
        final double tx = view.getTranslation().x;
        final double ty = view.getTranslation().y;
        final Rect drawn = Rect.fromLTWH(
          -tx / scale,
          -ty / scale,
          size.width / scale,
          size.height / scale,
        ).inflate(240);

        final List<({Print print, String key, Offset at, Size paper})> sheets =
            <({Print print, String key, Offset at, Size paper})>[];
        for (int i = 0; i < prints.length; i++) {
          final Print print = prints[i];
          final String key = WallPlaces.keyOf(print, i);
          final Offset? at = places[key];
          if (at == null) {
            continue;
          }
          final Size paper = WallPlaces.sizeOf(print);
          final Rect rect = WallPlaces.rectOf(
            print,
            at,
          ).shift(const Offset(_extent, _extent));
          if (key != _dragKey && !rect.overlaps(drawn)) {
            continue;
          }
          sheets.add((print: print, key: key, at: at, paper: paper));
        }

        final List<Widget> hung = <Widget>[];
        for (final ({Print print, String key, Offset at, Size paper}) sheet
            in sheets) {
          if (sheet.key == _dragKey || sheet.key == _topKey) {
            continue;
          }
          hung.add(
            _sheet(
              sheet.print,
              sheet.key,
              sheet.at,
              sheet.paper,
              wall,
              light,
              printed,
              compact,
              scale,
            ),
          );
        }
        for (final ({Print print, String key, Offset at, Size paper}) sheet
            in sheets) {
          if (sheet.key != _topKey || sheet.key == _dragKey) {
            continue;
          }
          hung.add(
            _sheet(
              sheet.print,
              sheet.key,
              sheet.at,
              sheet.paper,
              wall,
              light,
              printed,
              compact,
              scale,
            ),
          );
        }
        for (final ({Print print, String key, Offset at, Size paper}) sheet
            in sheets) {
          if (sheet.key != _dragKey) {
            continue;
          }
          hung.add(
            _sheet(
              sheet.print,
              sheet.key,
              sheet.at,
              sheet.paper,
              wall,
              light,
              printed,
              compact,
              scale,
            ),
          );
        }

        final WallPlaces hanging = WallPlaces(_hanging);

        return Stack(
          key: _field,
          fit: StackFit.expand,
          children: <Widget>[
            Wall(wall: wall, light: light),
            InteractiveViewer(
              transformationController: _view,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.15,
              maxScale: 1.6,
              onInteractionStart: (_) => _stopGlide(),
              child: SizedBox(
                width: _world,
                height: _world,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: MouseRegion(
                        cursor: _dragKey == null
                            ? SystemMouseCursors.grab
                            : SystemMouseCursors.grabbing,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    ...hung,
                  ],
                ),
              ),
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
            if (prints.isNotEmpty && (_touched || hanging.isHung))
              Positioned(
                left: margin,
                bottom: compact ? KalloMobileSpace.step4 : 28,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_touched)
                      _Pill(
                        key: const Key('wall-home'),
                        label: s.wallHome,
                        control: wall.controlAt(light),
                        onTap: () => _goHome(),
                      ),
                    if (_touched && hanging.isHung)
                      const SizedBox(width: KalloSpace.step2),
                    if (hanging.isHung)
                      _Pill(
                        key: const Key('wall-rehang'),
                        label: s.rehang,
                        control: wall.controlAt(light),
                        onTap: _rehang,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// One sheet on the wall: the paper, its label, and what a pointer does to
  /// it — a click walks up to the print, a drag hangs it somewhere else.
  Widget _sheet(
    Print print,
    String key,
    Offset at,
    Size paper,
    KalloWall wall,
    double light,
    double printed,
    bool compact,
    double scale,
  ) {
    final bool held = key == _dragKey;
    final MouseCursor cursor = widget.loupe
        ? (held ? SystemMouseCursors.grabbing : SystemMouseCursors.none)
        : (held ? SystemMouseCursors.grabbing : SystemMouseCursors.grab);
    return Positioned(
      left: at.dx + _extent,
      top: at.dy + _extent,
      width: paper.width,
      child: MouseRegion(
        cursor: cursor,
        onHover: widget.loupe
            ? (PointerHoverEvent event) => _lookAt(
                print,
                event.localPosition,
                paper.width,
                event.position,
              )
            : null,
        onExit: widget.loupe ? (_) => _leaveLens() : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _walkUp(print),
          onPanStart: (DragStartDetails details) =>
              _pickUp(print, key, at, details.globalPosition),
          onPanUpdate: (DragUpdateDetails details) =>
              _dragTo(details.globalPosition),
          onPanEnd: (_) => _hangUp(),
          onPanCancel: _cancelDrag,
          child: _Hung(
            print: print,
            wall: wall,
            width: paper.width,
            light: light,
            printed: printed,
            showLabel: !compact,
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
    required this.wall,
    required this.width,
    required this.light,
    required this.printed,
    this.showLabel = true,
  });

  final Print print;

  /// Which wall: the light one in a light appearance, the dark one after dark.
  final KalloWall wall;

  /// The sheet's width on the wall: the picture and the paper around it.
  final double width;

  /// The light on the wall, which the label is on.
  final double light;

  /// The light on the print, which holds a little longer.
  final double printed;

  /// A phone wall is only the paper. The label would be four points tall at
  /// this width; the viewer carries it instead.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final String stock = filmEdgeName(print.film);
    final String number = print.printNumber.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: stock.isEmpty ? '${print.name} · $number' : '$stock · $number',
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

  /// The light on the print: the paper is the one surface that keeps a little
  /// more of the room's light than the wall does, which is why it stays paper
  /// in a room that has gone dark.
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
