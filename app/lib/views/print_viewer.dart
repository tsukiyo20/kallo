import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/mobile.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/print.dart';
import '../lab/stock.dart';
import '../lab/thumbnails.dart';
import '../widgets/mobile/mobile_icon.dart';

/// Open one print whole, over the wall it was hanging on.
///
/// A phone's wall is an index: it can hang a sheet the width of the screen, and
/// a sheet is not the photograph. Tapping a print opens the print itself — one
/// tap, one picture — as a route of its own, so the wall and its chrome are
/// never rebuilt to make room, and going back finds them where they were.
///
/// The viewer is a dark room, not a second wall: the picture sits on black, the
/// whole width of the screen, and the paper's frame stays on the wall. A photo
/// viewer is read against the picture, so the chrome is one row at the top —
/// the way back, and what the file is — where the system's own bars cannot
/// take it.
Future<void> openPrintViewer(BuildContext context, Print print) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: KalloMotion.quick,
      reverseTransitionDuration: KalloMotion.instant,
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondary,
      ) => PrintViewer(print: print),
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
            Widget child,
          ) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: KalloMotion.enter,
              reverseCurve: KalloMotion.leave,
            ),
            child: child,
          ),
    ),
  );
}

/// One print filling a phone.
///
/// The picture is fitted the way a photo viewer fits one: the whole width of
/// the screen for a landscape, the whole height for a portrait, and the margin
/// that is left goes above and below, never beside. Pinch and double tap walk
/// up to the file's own pixels, one image pixel to one device pixel, and no
/// further: past that there is nothing left in the file to show.
class PrintViewer extends StatefulWidget {
  const PrintViewer({super.key, required this.print});

  final Print print;

  @override
  State<PrintViewer> createState() => _PrintViewerState();
}

class _PrintViewerState extends State<PrintViewer> {
  /// The file's own pixels, once decoded. The wall's copy stands in until
  /// then, which is what the eye was already looking at.
  ui.Image? _full;
  PrintThumbnail? _thumbnail;

  /// How far the picture is magnified over its fit, and where it is held, in
  /// points, from the centre of the screen.
  double _scale = 1;
  Offset _pan = Offset.zero;

  double _gestureScale = 1;
  Offset _gesturePan = Offset.zero;
  Offset _gestureFocal = Offset.zero;

  /// The picture's size at rest, and the magnification at which one image
  /// pixel is one device pixel. Both are the layout's, written each build so
  /// a rotation clamps the view to the new window.
  Size _displayed = Size.zero;
  double _ceiling = 1;

  @override
  void initState() {
    super.initState();
    unawaited(_loadThumbnail());
    unawaited(_loadFull());
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

  Future<void> _loadFull() async {
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
    super.dispose();
  }

  /// The image and the size it says it is: the file's, the wall copy's, or what
  /// the print was built with.
  ({ui.Image image, Size pixels})? get _pixels {
    final ui.Image? full = _full;
    if (full != null) {
      return (
        image: full,
        pixels:
            widget.print.pixels ??
            Size(full.width.toDouble(), full.height.toDouble()),
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

  /// What the print is called in the one line there is for it.
  String get _label {
    final Print print = widget.print;
    final List<String> parts = <String>[
      if (filmEdgeName(print.film).isNotEmpty) filmEdgeName(print.film),
      if (print.clock != null) print.clock!,
      if (print.paperDisplay.isNotEmpty) print.paperDisplay,
    ];
    return parts.isEmpty ? print.name : parts.join('   ·   ');
  }

  @override
  Widget build(BuildContext context) {
    final KalloStrings s = KalloStrings.of(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final Size room = MediaQuery.sizeOf(context);
    final ({ui.Image image, Size pixels})? shown = _pixels;
    final Size pixels = shown?.pixels ?? const Size(1, 1);
    final double fit = math.min(
      room.width / math.max(1, pixels.width),
      room.height / math.max(1, pixels.height),
    );
    _displayed = Size(pixels.width * fit, pixels.height * fit);
    // One image pixel on one device pixel. Width and height have the same
    // ratio, so the width is the whole story.
    _ceiling = math.max(1, pixels.width / math.max(1, _displayed.width * dpr));
    final double scale = _scale.clamp(1.0, _ceiling);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The room is dark, so the system's own bars are drawn light and the
      // navigation bar is the same black as the room.
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: KalloColors.dark.ground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: KalloColors.dark.ground,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (shown != null) _picture(shown, room, scale),
            Positioned(top: 0, left: 0, right: 0, child: _chrome(s, shown)),
          ],
        ),
      ),
    );
  }

  /// The picture, fitted and magnified, and the gestures that move it.
  Widget _picture(
    ({ui.Image image, Size pixels}) shown,
    Size room,
    double scale,
  ) {
    final Offset pan = _clampPan(_pan, scale, room);

    return GestureDetector(
      key: const Key('print-viewer-picture'),
      behavior: HitTestBehavior.opaque,
      onScaleStart: (ScaleStartDetails details) {
        _gestureScale = scale;
        _gesturePan = pan;
        _gestureFocal = details.localFocalPoint;
      },
      onScaleUpdate: (ScaleUpdateDetails details) {
        setState(() {
          _scale = (_gestureScale * details.scale).clamp(1.0, _ceiling);
          _pan = _clampPan(
            _gesturePan + (details.localFocalPoint - _gestureFocal),
            _scale,
            room,
          );
        });
      },
      onDoubleTap: () => setState(() {
        _scale = _scale > 1.01 ? 1 : _ceiling;
        _pan = Offset.zero;
      }),
      child: Center(
        child: Transform.translate(
          offset: pan,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: _displayed.width,
              height: _displayed.height,
              child: RawImage(
                key: const Key('print-viewer-image'),
                image: shown.image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How far the picture may be pushed before its edge would leave the window.
  Offset _clampPan(Offset value, double scale, Size room) {
    final double limitX = math.max(
      0,
      (_displayed.width * scale - room.width) / 2,
    );
    final double limitY = math.max(
      0,
      (_displayed.height * scale - room.height) / 2,
    );
    return Offset(
      value.dx.clamp(-limitX, limitX),
      value.dy.clamp(-limitY, limitY),
    );
  }

  /// The one row: the way back, and what the file is.
  Widget _chrome(KalloStrings s, ({ui.Image image, Size pixels})? shown) {
    final String readout = shown == null
        ? ''
        : s.magnification(
            '${shown.pixels.width.round()} × '
            '${shown.pixels.height.round()}',
            _scale >= _ceiling - 0.001 ? s.actualPixels : '${_percent()} %',
          );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xB8000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KalloMobileSpace.step2,
            KalloMobileSpace.step1,
            KalloMobileSpace.step5,
            KalloMobileSpace.step5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              KalloIconButton(
                key: const Key('print-viewer-close'),
                glyph: KalloGlyph.back,
                semanticLabel: s.back,
                onTap: () => Navigator.of(context).pop(),
                foreground: KalloColors.dark.ink,
              ),
              const SizedBox(width: KalloMobileSpace.step2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: KalloMobileSpace.step4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KalloMobileType.footnote.copyWith(
                          color: KalloColors.dark.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        readout,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KalloMobileType.caption.copyWith(
                          color: KalloColors.dark.inkMuted,
                          fontFeatures: const <FontFeature>[
                            FontFeature('tnum'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _percent() => (_scale.clamp(1.0, _ceiling) / _ceiling * 100).round();
}
