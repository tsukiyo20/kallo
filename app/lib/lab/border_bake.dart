import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import 'edge_print.dart';
import 'export_format.dart';
import 'model.dart';
import 'stock.dart';

/// Print the film's edge into [print], in place, and write it back in [format].
///
/// The border is a printing choice, so it is baked into the print rather than
/// kept as a second file: a full-frame print is one sheet of paper with the
/// rebate printed on it, and a reversal read on a light box is one picture with
/// its film around it. Nothing here knows about folders — the caller writes the
/// print where prints go and this makes that print the bordered one.
Future<void> bakeBorder({
  required File print,
  required BorderTemplate border,
  required ExportFormat format,
  String? film,
  FilmProcess? process,
  int printNumber = 1,
}) async {
  if (border == BorderTemplate.none) {
    return;
  }
  try {
    final Uint8List bytes = await print.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    try {
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
        template: border,
      ).paint(canvas, Size(width.toDouble(), height.toDouble()));
      final ui.Picture picture = recorder.endRecording();
      final ui.Image framed = await picture.toImage(width, height);
      picture.dispose();
      final ByteData? raw = await framed.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      framed.dispose();
      if (raw == null) {
        throw FileSystemException(
          'the print with its edge could not be read',
          print.path,
        );
      }
      final Uint8List rgba = raw.buffer.asUint8List(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      final Uint8List encoded = await Isolate.run(() {
        final img.Image picture = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: rgba.buffer,
          bytesOffset: rgba.offsetInBytes,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        return switch (format) {
          ExportFormat.jpeg => img.encodeJpg(
            picture,
            quality: 92,
            chroma: img.JpegChroma.yuv420,
          ),
          ExportFormat.png => img.encodePng(picture),
          ExportFormat.tiff => img.encodeTiff(picture),
        };
      });
      await print.writeAsBytes(encoded, flush: true);
    } finally {
      image.dispose();
      codec.dispose();
    }
  } on FileSystemException {
    rethrow;
  } on Object catch (error) {
    Model.log('the border was not printed into ${print.path}: $error');
    rethrow;
  }
}
