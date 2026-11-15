import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'chart.dart';
import 'export_codec.dart';
import 'export_format.dart';
import 'image_file.dart';
import 'model.dart';
import 'short_hash.dart';
import 'stock.dart';
import 'strip.dart';
import 'strip_store.dart';

/// The width a print on the strip is rendered at.
///
/// The strip is a bench instrument, and the model's grain belongs to the
/// sampling: a print rendered here is a print at this size, not a larger one
/// scaled down. A final print is rendered again from the photograph.
const int stripWidth = 1200;

/// Develop one print onto the strip.
///
/// The first print fixes the strip's enlarger balance; every later print reuses
/// it, so what changes between the prints is the development and not the timer.
/// The chart is read from the same stock and time — it is a fact about the
/// film, not about this photograph.
Future<TestStrip> developTestPrint({
  required Model model,
  required TestStrip strip,
  required double minutes,
  Directory? folder,
  int width = stripWidth,
  void Function(double)? onProgress,
}) async {
  final String? photo = strip.photo;
  if (photo == null) {
    throw const FileSystemException('a test strip needs a photograph');
  }
  final File photograph = File(photo);
  if (!photograph.existsSync()) {
    throw FileSystemException('the photograph is gone', photo);
  }
  if (!(minutes.isFinite && minutes > 0)) {
    throw ArgumentError.value(minutes, 'minutes', 'a development is positive');
  }
  final Directory target = folder ?? StripStore.folderOrThrow;
  await target.create(recursive: true);
  final File output = StripStore.printFile(target, minutes);

  await model.develop(
    photograph: photograph,
    stock: strip.stockId,
    paper: strip.paperId ?? Stocks.paper,
    minutes: minutes,
    tempC: strip.tempC,
    width: width,
    output: output,
    spectral: strip.spectral,
    balanceFrom: strip.balanceFrom,
    onProgress: onProgress == null
        ? null
        : (double value) => onProgress(value * 0.95),
  );

  FilmChart? chart;
  try {
    final List<FilmChart>? charts = await model.chart(
      stock: strip.stockId,
      times: <double>[minutes],
      tempC: strip.tempC,
    );
    chart = charts == null || charts.isEmpty ? null : charts.first;
  } on Object catch (error) {
    // A print without its chart is still a print; the panel says so.
    Model.log('the strip could not be charted: $error');
  }

  final TestStrip next = strip.withPrint(
    TestPrint(
      minutes: minutes,
      tempC: strip.tempC,
      image: await decode(output, width: width),
      chart: chart,
      file: output,
    ),
  );
  await StripStore.save(next, folder: target);
  onProgress?.call(1.0);
  return next;
}

/// The print a test strip would make at this development, at bench size.
///
/// It is the strip's exposure, not the print's: the preview and the print that
/// will replace it at the same time are made the same way. The file is a
/// preview and overwrites itself; it is not part of the strip.
Future<ui.Image> previewTestPrint({
  required Model model,
  required TestStrip strip,
  required double minutes,
  Directory? folder,
  int width = 760,
}) async {
  final String? photo = strip.photo;
  if (photo == null) {
    throw const FileSystemException('a test strip needs a photograph');
  }
  final Directory target = folder ?? StripStore.folderOrThrow;
  await target.create(recursive: true);
  final File output = File(
    '${target.path}${Platform.pathSeparator}strip-preview.png',
  );
  await model.develop(
    photograph: File(photo),
    stock: strip.stockId,
    paper: strip.paperId ?? Stocks.paper,
    minutes: minutes,
    tempC: strip.tempC,
    width: width,
    output: output,
    spectral: strip.spectral,
    balanceFrom: strip.balanceFrom,
  );
  return decode(output, width: width);
}

/// The finished print a darkroom would make at this development, at bench
/// size. Balanced for this negative, with the filters and the glass.
Future<ui.Image> previewFinalPrint({
  required Model model,
  required TestStrip strip,
  required double minutes,
  double printEv = 0,
  String filters = '',
  String? heatGlass,
  Directory? folder,
  int width = 760,
}) async {
  final String? photo = strip.photo;
  if (photo == null) {
    throw const FileSystemException('a print needs a photograph');
  }
  final Directory target = folder ?? StripStore.folderOrThrow;
  await target.create(recursive: true);
  final File output = File(
    '${target.path}${Platform.pathSeparator}strip-print-preview.png',
  );
  await model.develop(
    photograph: File(photo),
    stock: strip.stockId,
    paper: strip.paperId ?? Stocks.paper,
    minutes: minutes,
    tempC: strip.tempC,
    width: width,
    output: output,
    spectral: strip.spectral,
    printEv: printEv,
    filters: filters,
    heatGlass: heatGlass,
  );
  return decode(output, width: width);
}

/// Print the chosen development as a finished print, balanced on its own.
///
/// A test strip is one exposure; a finished print is the enlarger dialled for
/// this negative. That is why it is rendered again, at the size the photograph
/// has, and why it is not a copy of the strip's print.
Future<File> printTest({
  required Model model,
  required TestStrip strip,
  required double minutes,
  required Directory exports,
  double printEv = 0,
  String filters = '',
  String? heatGlass,
  int? width,
  ExportFormat format = ExportFormat.png,

  /// The edge this print carries, as its own name. A print of the same
  /// development with another edge is another sheet, and its file must not
  /// replace the first one.
  String border = 'none',

  /// How much of the print is done, 0..1: the model's stages, then the file's
  /// own re-encoding. The darkroom's edge and the gallery's shelf are still to
  /// come, so a caller with those to do keeps the last tenth for them.
  void Function(double)? onProgress,
}) async {
  final String? photo = strip.photo;
  if (photo == null) {
    throw const FileSystemException('a print needs a photograph');
  }
  final File photograph = File(photo);
  if (!photograph.existsSync()) {
    throw FileSystemException('the photograph is gone', photo);
  }
  await exports.create(recursive: true);
  // Zero means the photograph's own size. The model's resize only ever shrinks,
  // so an asked-for width is a ceiling and not an upscale — and a camera raw,
  // whose pixels this window cannot read to measure, needs no measuring at all.
  final int asked = width != null && width > 0 ? width : 0;
  // The photograph's name and a fingerprint of everything that makes this
  // print this print. Two edges of one negative are two sheets in the folder,
  // and the same print asked for twice still replaces itself.
  final String stem = printFileName(
    photograph: photograph.path,
    recipe: <Object?>[
      photograph.path,
      strip.stockId,
      strip.paperId,
      strip.tempC,
      strip.spectral,
      minutes,
      printEv,
      filters,
      heatGlass,
      border,
      asked,
    ].join('|'),
  );
  final File output = File('${exports.path}${Platform.pathSeparator}$stem.png');
  await model.develop(
    photograph: photograph,
    stock: strip.stockId,
    paper: strip.paperId ?? Stocks.paper,
    minutes: minutes,
    tempC: strip.tempC,
    width: asked,
    output: output,
    spectral: strip.spectral,
    printEv: printEv,
    filters: filters,
    heatGlass: heatGlass,
    onProgress: onProgress == null
        ? null
        : (double value) => onProgress(value * 0.85),
  );
  if (format == ExportFormat.png) {
    await _dropOtherFormats(exports, stem, format);
    onProgress?.call(0.9);
    return output;
  }
  final Uint8List png = await output.readAsBytes();
  final Uint8List encoded = await encodePngAs(png, format);
  final File finalFile = File(
    '${exports.path}${Platform.pathSeparator}$stem.${format.extension}',
  );
  await finalFile.writeAsBytes(encoded, flush: true);
  await output.delete();
  await _dropOtherFormats(exports, stem, format);
  onProgress?.call(0.9);
  return finalFile;
}

/// A print at one development is one file: changing its format must not leave
/// yesterday's PNG next to today's JPEG in the folder.
Future<void> _dropOtherFormats(
  Directory exports,
  String stem,
  ExportFormat keep,
) async {
  for (final String extension in <String>['png', 'jpg', 'jpeg', 'tiff']) {
    if (extension == keep.extension) {
      continue;
    }
    final File old = File(
      '${exports.path}${Platform.pathSeparator}$stem.$extension',
    );
    if (old.existsSync()) {
      try {
        await old.delete();
      } on FileSystemException {
        // A file in use is not a reason to lose the print.
      }
    }
  }
}
