import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/border_bake.dart';
import 'package:kallo/lab/edge_print.dart';
import 'package:kallo/lab/export_codec.dart';
import 'package:kallo/lab/export_format.dart';
import 'package:kallo/lab/exports.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/stock.dart';

Future<ui.Image> _card({int width = 300, int height = 200}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF8C6A4A),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, height * 0.6, width.toDouble(), height * 0.4),
    Paint()..color = const Color(0xFF4E6B63),
  );
  return recorder.endRecording().toImage(width, height);
}

/// A read-back canvas of raw pixels, with the metrics that painted it.
class _Painted {
  _Painted(this.rgba, this.width, this.height, this.metrics);

  final Uint8List rgba;
  final int width;
  final int height;
  final EdgePrintMetrics metrics;

  Color at(Offset point) {
    final int x = point.dx.round().clamp(0, width - 1);
    final int y = point.dy.round().clamp(0, height - 1);
    final int index = (y * width + x) * 4;
    return Color.fromARGB(
      rgba[index + 3],
      rgba[index],
      rgba[index + 1],
      rgba[index + 2],
    );
  }

  /// The rows between the perforations and the frame, which is where a film's
  /// edge printing sits. The holes are above them, so a light probe here is
  /// about the letters and nothing else.
  Iterable<int> _typeRows() sync* {
    final int top = (metrics.outer.top + metrics.band * 0.72).round().clamp(
      0,
      height - 1,
    );
    final int bottom = metrics.aperture.top.round().clamp(0, height);
    for (int y = top; y < bottom; y++) {
      yield y;
    }
  }

  /// Whether any lettering in the top rebate is warm like amber.
  bool hasWarmInk() {
    for (final int y in _typeRows()) {
      for (int x = 0; x < width; x++) {
        final int index = (y * width + x) * 4;
        final int r = rgba[index];
        final int b = rgba[index + 2];
        // Amber is warm and far from neutral: a lot of red, little blue.
        if (r > 140 && b < 150 && r - b > 40) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether any lettering in the top rebate is light: paper white or the
  /// white of a reversal's clear film.
  bool hasLightInk() {
    for (final int y in _typeRows()) {
      for (int x = 0; x < width; x++) {
        final int index = (y * width + x) * 4;
        final int r = rgba[index];
        final int g = rgba[index + 1];
        final int b = rgba[index + 2];
        if (r > 200 && g > 195 && b > 180) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Paints a template over [image] and reads the result back.
Future<_Painted> _paint(
  ui.Image image,
  BorderTemplate template, {
  FilmProcess? process = FilmProcess.negative,
  String? film = 'KODAK ULTRA MAX 400',
  int printNumber = 1,
}) async {
  final double aspect = image.width / image.height;
  final EdgePrintMetrics metrics = EdgePrintMetrics.fromImageWidth(
    image.width.toDouble(),
    aspect: aspect,
  );
  final int width = metrics.outer.width.round();
  final int height = metrics.outer.height.round();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  EdgePrintPainter(
    image: image,
    source: Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    ),
    film: film,
    printNumber: printNumber,
    process: process,
    template: template,
  ).paint(canvas, Size(width.toDouble(), height.toDouble()));
  final ui.Picture picture = recorder.endRecording();
  final ui.Image painted = await picture.toImage(width, height);
  picture.dispose();
  final ByteData rgba = (await painted.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  painted.dispose();
  return _Painted(
    rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
    width,
    height,
    metrics,
  );
}

/// A point of the top rebate with no lettering and no perforation on it.
Offset _bandPoint(EdgePrintMetrics metrics) {
  final double pitch = metrics.aperture.width / metrics.sprockets;
  return Offset(
    metrics.aperture.left + 0.02 * pitch,
    metrics.outer.top + 0.5 * metrics.band,
  );
}

/// The centre of the first perforation on the top rebate.
Offset _holePoint(EdgePrintMetrics metrics) {
  final double pitch = metrics.aperture.width / metrics.sprockets;
  return Offset(
    metrics.aperture.left + 0.5 * pitch,
    metrics.outer.top + 0.5 * metrics.band,
  );
}

/// How many light pixels a hole covers along one axis, through [centre].
int _lightRun(_Painted painted, Offset centre, {required bool horizontal}) {
  bool light(int x, int y) {
    final Color c = painted.at(Offset(x.toDouble(), y.toDouble()));
    return c.r > 0.75 && c.g > 0.75 && c.b > 0.75;
  }

  final int cx = centre.dx.round();
  final int cy = centre.dy.round();
  int count = 0;
  for (final int direction in <int>[-1, 1]) {
    for (int i = direction == -1 ? 0 : 1; i < 400; i++) {
      final int x = horizontal ? cx + direction * i : cx;
      final int y = horizontal ? cy : cy + direction * i;
      if (x < 0 || y < 0 || x >= painted.width || y >= painted.height) {
        break;
      }
      if (!light(x, y)) {
        break;
      }
      count++;
    }
  }
  return count;
}

/// A decoded image with a picture's own width, for reading a written file back.
class _Written {
  _Written(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;

  Color at(int x, int y) {
    final int index = (y * width + x) * 4;
    return Color.fromARGB(
      rgba[index + 3],
      rgba[index],
      rgba[index + 1],
      rgba[index + 2],
    );
  }

  static Future<_Written> of(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    final ByteData data = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final _Written written = _Written(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
    image.dispose();
    codec.dispose();
    return written;
  }
}

/// The RGBA of a colour at a point of the edge, after its band has lifted or
/// not. The band is solid, so a sample is enough.
Future<void> _writeCard(File file, ui.Image card) async {
  final ByteData? png = await card.toByteData(format: ui.ImageByteFormat.png);
  await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the edge carries the maker and the name a printer says', () {
    expect(
      filmEdgeName('KODAK PROFESSIONAL T-MAX 400, D-76 8 min 20 °C'),
      'KODAK T-MAX 400',
    );
    expect(filmEdgeName('KODAK ULTRA MAX 400'), 'KODAK ULTRA MAX 400');
    expect(filmEdgeName('FUJIFILM 200'), 'FUJIFILM 200');
    expect(
      filmEdgeName('ILFORD DELTA 400 PROFESSIONAL, ID-11'),
      'ILFORD DELTA 400',
    );
    expect(filmEdgeName(null), '');
    expect(filmEdgeName('GOLD 200'), 'KODAK GOLD 200');
    expect(filmEdgeName('PROVIA 100F'), 'FUJIFILM PROVIA 100F');
    expect(
      stockDisplayName('ENDURA PREMIER METALLIC'),
      'KODAK ENDURA PREMIER METALLIC',
    );
    expect(
      stockDisplayName('CRYSTAL ARCHIVE PEARL'),
      'FUJIFILM CRYSTAL ARCHIVE PEARL',
    );
    expect(stockDisplayName('KODAK GOLD 200'), 'KODAK GOLD 200');
    expect(
      filmProcessFromName('KODAK PROFESSIONAL T-MAX 400, D-76 8 min 20 °C'),
      FilmProcess.monochrome,
    );
    expect(filmProcessFromName('KODAK ULTRA MAX 400'), FilmProcess.negative);
    expect(
      filmProcessFromName('FUJICHROME PROVIA 100F (RDP III), E-6'),
      FilmProcess.reversal,
    );
    expect(filmProcessFromName(null), isNull);
  });

  test('a landscape print keeps the film\'s own rebate', () {
    final EdgePrintMetrics metrics = EdgePrintMetrics.fromImageWidth(
      6000,
      aspect: 1.5,
    );
    expect(metrics.horizontal, isTrue);
    expect(metrics.aperture.width, 6000);
    expect(metrics.aperture.height, closeTo(4000, 0.001));
    // 5.5 mm of rebate beside a 36 mm frame: a sixth of the long edge.
    expect(metrics.band, closeTo(6000 * 5.5 / 36, 0.001));
    // The gap to the next frame is the film's: about 1 mm.
    expect(metrics.side, closeTo(6000 / 36, 0.001));
    expect(metrics.outer.width, closeTo(6000 + 2 * 6000 / 36, 0.001));
    expect(metrics.outer.height, closeTo(4000 + 2 * 6000 * 5.5 / 36, 0.001));
    // Eight perforations fit a frame of 36 mm on a 4.75 mm pitch.
    expect(metrics.sprockets, 8);
  });

  test('a portrait print turns the strip and keeps the rebate', () {
    final EdgePrintMetrics metrics = EdgePrintMetrics.fromImageWidth(
      3000,
      aspect: 2 / 3,
    );
    expect(metrics.horizontal, isFalse);
    expect(metrics.aperture.width, 3000);
    expect(metrics.aperture.height, closeTo(4500, 0.001));
    // The long edge is the height now, and the rebate follows it.
    expect(metrics.band, closeTo(4500 * 5.5 / 36, 0.001));
    expect(metrics.side, closeTo(4500 / 36, 0.001));
    expect(metrics.outer.height, greaterThan(metrics.aperture.height));
    expect(metrics.aspect, lessThan(1));
  });

  test('the outer size is the picture plus the edge, both ways round', () {
    final EdgePrintMetrics fromPicture = EdgePrintMetrics.fromImageWidth(
      4000,
      aspect: 1.5,
    );
    final EdgePrintMetrics fromWidth = EdgePrintMetrics.fromWidth(
      fromPicture.outer.width,
      aspect: 1.5,
    );
    expect(fromWidth.aperture.width, closeTo(4000, 0.5));
    expect(fromWidth.outer.width, closeTo(fromPicture.outer.width, 0.5));
    expect(
      EdgePrintMetrics.sizeForImageWidth(4000, aspect: 1.5).width,
      closeTo(fromPicture.outer.width, 0.5),
    );
  });

  test('a warm edge keeps the orange mask: brown band, black holes, amber '
      'letters', () async {
    final ui.Image card = await _card(width: 1200, height: 800);
    addTearDown(card.dispose);
    final _Painted painted = await _paint(card, BorderTemplate.warm);
    final EdgePrintMetrics metrics = painted.metrics;

    // The rebate and the letters lift with the mask: a brown band.
    final Color band = painted.at(_bandPoint(metrics));
    expect(band.r, greaterThan(0.1));
    expect(band.r, greaterThan(band.b));
    expect(band.b, greaterThan(0.0));

    // A hole has no film in it, so no mask: it stays black under the lifted
    // band, and comes back as a shape.
    final Color hole = painted.at(_holePoint(metrics));
    expect(hole.r, lessThan(0.05));
    expect(hole.r, lessThan(band.r * 0.6));

    // The letters are the mask's amber.
    expect(painted.hasWarmInk(), isTrue);
  });

  test('a neutral print has a black band, no perforation mark and paper-white '
      'letters', () async {
    final ui.Image card = await _card(width: 1200, height: 800);
    addTearDown(card.dispose);
    final _Painted painted = await _paint(card, BorderTemplate.neutral);
    final EdgePrintMetrics metrics = painted.metrics;

    final Color band = painted.at(_bandPoint(metrics));
    expect(band.r, lessThan(0.05));
    expect(band.b, lessThan(0.05));

    // The enlarger's light passes a hole exactly as it passes the rebate, so a
    // black hole in a black band is not a mark.
    final Color hole = painted.at(_holePoint(metrics));
    expect((hole.r - band.r).abs(), lessThan(0.02));
    expect((hole.b - band.b).abs(), lessThan(0.02));

    expect(painted.hasLightInk(), isTrue);
    expect(
      painted.hasWarmInk(),
      isFalse,
      reason: 'a neutral print has no mask to warm its letters',
    );
  });

  test('a reversal reads on a light box: black band, white holes and white '
      'letters', () async {
    final ui.Image card = await _card(width: 1200, height: 800);
    addTearDown(card.dispose);
    final _Painted painted = await _paint(
      card,
      BorderTemplate.white,
      process: FilmProcess.reversal,
      film: 'FUJIFILM PROVIA 100F',
    );
    final EdgePrintMetrics metrics = painted.metrics;

    final Color band = painted.at(_bandPoint(metrics));
    expect(band.r, lessThan(0.05));
    expect(band.b, lessThan(0.05));

    // A hole is clear film, and the lamp behind it comes through.
    final Color hole = painted.at(_holePoint(metrics));
    expect(hole.r, greaterThan(0.75));
    expect(hole.g, greaterThan(0.75));
    expect(hole.b, greaterThan(0.75));

    expect(painted.hasLightInk(), isTrue);
    expect(painted.hasWarmInk(), isFalse);
  });

  test('a white-hole edge can keep the mask\'s amber printing', () async {
    final ui.Image card = await _card(width: 1200, height: 800);
    addTearDown(card.dispose);
    final _Painted painted = await _paint(card, BorderTemplate.whiteAmber);
    final EdgePrintMetrics metrics = painted.metrics;

    // The rebate is the light box's black dye.
    final Color band = painted.at(_bandPoint(metrics));
    expect(band.r, lessThan(0.05));

    // The holes are clear film, and the lamp behind them comes through.
    final Color hole = painted.at(_holePoint(metrics));
    expect(hole.r, greaterThan(0.75));

    // The printing is the mask's amber, not the light.
    expect(painted.hasWarmInk(), isTrue);
    expect(painted.hasLightInk(), isFalse);
  });

  test('a white-hole edge can carry no printing at all', () async {
    final ui.Image card = await _card(width: 1200, height: 800);
    addTearDown(card.dispose);
    final _Painted painted = await _paint(card, BorderTemplate.whiteBlank);
    final EdgePrintMetrics metrics = painted.metrics;

    // The holes are still the film's: clear film on black dye.
    final Color hole = painted.at(_holePoint(metrics));
    expect(hole.r, greaterThan(0.75));

    // And nothing is written between them and the frame.
    expect(painted.hasWarmInk(), isFalse);
    expect(painted.hasLightInk(), isFalse);
  });

  test('the perforation lies along the film, wider than it is tall', () async {
    final ui.Image card = await _card(width: 1200, height: 800);
    addTearDown(card.dispose);
    final _Painted painted = await _paint(
      card,
      BorderTemplate.white,
      process: FilmProcess.reversal,
      film: 'FUJIFILM PROVIA 100F',
    );
    final Offset hole = _holePoint(painted.metrics);
    final double across = _lightRun(painted, hole, horizontal: true).toDouble();
    final double down = _lightRun(painted, hole, horizontal: false).toDouble();
    expect(down, greaterThan(0));
    // A 35 mm hole is 2.79 mm along the film and 1.98 mm across it.
    expect(across / down, closeTo(2.79 / 1.98, 0.15));
  });

  test(
    'the template is the reading: the same picture with each edge',
    () async {
      final ui.Image card = await _card(width: 600, height: 400);
      addTearDown(card.dispose);
      final List<Color> bands = <Color>[];
      for (final BorderTemplate template in <BorderTemplate>[
        BorderTemplate.warm,
        BorderTemplate.neutral,
        BorderTemplate.white,
      ]) {
        final _Painted painted = await _paint(card, template);
        bands.add(painted.at(_bandPoint(painted.metrics)));
      }
      // The three readings share a geometry but not a band: warm is brown, the
      // two that are not lifted are black.
      expect(bands[0].r, greaterThan(bands[1].r + 0.05));
      expect(bands[0].r, greaterThan(bands[2].r + 0.05));
      expect(bands[1].r, closeTo(bands[2].r, 0.02));
    },
  );

  test('a print without a record is print 01, not its folder place', () async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-order-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final ui.Image card = await _card();
    addTearDown(card.dispose);
    final Uint8List png = (await card.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    await File('${folder.path}/print-01.png').writeAsBytes(png);
    await File('${folder.path}/print-02.png').writeAsBytes(png);

    final List<Print> prints = await Exports.read(folder: folder);
    addTearDown(() {
      for (final Print print in prints) {
        print.dispose();
      }
    });
    expect(prints, hasLength(2));
    expect(prints[0].printNumber, 1);
    expect(prints[1].printNumber, 1);
  });

  test('a batch record carries its print number and chemistry', () async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-batch-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final ui.Image card = await _card();
    addTearDown(card.dispose);
    final File file = File('${folder.path}/print-02.png');
    final Uint8List png = (await card.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    await file.writeAsBytes(png);
    await File('${folder.path}/print-02.json').writeAsString(
      '{"print": 2, "process": "monochrome", "film": "T-MAX 400", '
      '"minutes": 9}',
    );

    final Print? print = await Print.read(file);
    addTearDown(() => print?.dispose());
    expect(print, isNotNull);
    expect(print!.printNumber, 2);
    expect(print.process, FilmProcess.monochrome);
    expect(print.folio, startsWith('02'));
  });

  test('a PNG becomes JPEG or TIFF, and a JPEG print reads back', () async {
    final ui.Image card = await _card();
    addTearDown(card.dispose);
    final Uint8List png = (await card.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();

    final Uint8List jpeg = await encodePngAs(png, ExportFormat.jpeg);
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
    final Uint8List tiff = await encodePngAs(png, ExportFormat.tiff);
    expect(tiff[0], anyOf(0x49, 0x4D));

    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-jpeg-print-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final File file = File('${folder.path}/print-01.jpg');
    await file.writeAsBytes(jpeg);
    final Print? print = await Print.read(file);
    addTearDown(() => print?.dispose());
    expect(print, isNotNull);
    expect(print!.pixels, const Size(300, 200));
    expect(print.printNumber, 1);
  });

  test('baking an edge writes it into the print, in the print\'s own folder', () async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-bake-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final ui.Image card = await _card();
    addTearDown(card.dispose);
    final File file = File('${folder.path}/print-01.png');
    await _writeCard(file, card);
    final int plain = file.lengthSync();

    await bakeBorder(
      print: file,
      border: BorderTemplate.warm,
      format: ExportFormat.png,
      film: 'KODAK ULTRA MAX 400',
      process: FilmProcess.negative,
    );

    // One print, one file: the edge is printed into it, not written beside it.
    expect(file.existsSync(), isTrue);
    expect(folder.listSync(), hasLength(1));
    expect(
      Directory('${folder.path}${Platform.pathSeparator}Frames').existsSync(),
      isFalse,
    );
    expect(file.lengthSync(), greaterThan(plain));

    final _Written written = await _Written.of(await file.readAsBytes());
    expect(written.width, greaterThan(300));
    expect(written.height, greaterThan(200));
    // The band is there: the top of the file is the film's rebate, and this
    // template keeps the orange mask. Mid-band, away from holes and letters.
    final EdgePrintMetrics metrics = EdgePrintMetrics.fromWidth(
      written.width.toDouble(),
      aspect: 1.5,
    );
    final Offset band = _bandPoint(metrics);
    expect(written.at(band.dx.round(), band.dy.round()).r, greaterThan(0.1));
  });

  test('baking none leaves the print untouched, and does not decode it', () async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-bake-none-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final File file = File('${folder.path}/print-01.png');
    // Not an image at all: `none` must return before opening the file, so this
    // is the cheapest proof that nothing is redrawn.
    final Uint8List junk = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    await file.writeAsBytes(junk);

    await bakeBorder(
      print: file,
      border: BorderTemplate.none,
      format: ExportFormat.png,
      film: 'KODAK ULTRA MAX 400',
      process: FilmProcess.negative,
    );

    expect(await file.readAsBytes(), junk);
    expect(folder.listSync(), hasLength(1));
  });

  test('a JPEG print bakes back to a JPEG', () async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-bake-jpeg-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final ui.Image card = await _card();
    addTearDown(card.dispose);
    final Uint8List png = (await card.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final Uint8List jpeg = await encodePngAs(png, ExportFormat.jpeg);
    final File file = File('${folder.path}/print-01.jpg');
    await file.writeAsBytes(jpeg, flush: true);
    final int plain = file.lengthSync();

    await bakeBorder(
      print: file,
      border: BorderTemplate.neutral,
      format: ExportFormat.jpeg,
      film: 'KODAK ULTRA MAX 400',
      process: FilmProcess.negative,
    );

    final Uint8List baked = await file.readAsBytes();
    expect(baked.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(baked.length, greaterThan(plain));
    final _Written written = await _Written.of(baked);
    expect(written.width, greaterThan(300));
    expect(written.height, greaterThan(200));
  });

  test('a reversal baked white keeps its lit perforations', () async {
    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-bake-white-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final ui.Image card = await _card(width: 600, height: 400);
    addTearDown(card.dispose);
    final File file = File('${folder.path}/print-01.png');
    await _writeCard(file, card);

    await bakeBorder(
      print: file,
      border: BorderTemplate.white,
      format: ExportFormat.png,
      film: 'FUJIFILM PROVIA 100F',
      process: FilmProcess.reversal,
      printNumber: 2,
    );

    final _Written written = await _Written.of(await file.readAsBytes());
    final EdgePrintMetrics metrics = EdgePrintMetrics.fromWidth(
      written.width.toDouble(),
      aspect: 1.5,
    );
    final Offset holeAt = _holePoint(metrics);
    final Color hole = written.at(holeAt.dx.round(), holeAt.dy.round());
    expect(hole.r, greaterThan(0.75));
    expect(hole.b, greaterThan(0.75));
  });
}
