import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:kallo/src/rust/api/thumbnail.dart' as thumbnail_api;

/// Decode an image file at no more than a width.
///
/// The width is asked for at decode time rather than scaled afterwards,
/// because the bench holds a 26 megapixel photograph to show 1200 points and
/// the difference is a hundred megabytes thrown away.
Future<ui.Image> decode(File file, {int width = 1200}) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec(
      targetWidth: descriptor.width > width ? width : null,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    // The frame owns its pixels. The decoder's buffer and codec are scratch:
    // release them now so a slider drag does not leave a trail of decoders
    // waiting for the next GC.
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// Decode a photograph, from whatever format the camera wrote.
///
/// The engine reads the formats a window reads: JPEG, PNG, WebP. A camera raw
/// is none of those — it is a sensor mosaic with its own metadata — and the
/// model carries the only decoder in the program that knows it. So a raw is
/// developed by the model into a small PNG, and the engine reads that. The
/// small copy is the bench's size, not the sensor's: the darkroom shows 1600
/// points and has no use for 26 megapixels.
///
/// A file the engine can read is decoded there, once, as it always was; the
/// model is asked whether the file is a raw first, and nothing else about an
/// ordinary photograph changes.
///
/// The question is asked before the file is read on purpose: a camera raw can
/// be several hundred megabytes, and handing that to a decoder that cannot read
/// it is a worse way to learn the answer than asking.
Future<ui.Image> decodePhotograph(File file, {int width = 1600}) async {
  if (!await _isCameraRaw(file)) {
    return decode(file, width: width);
  }
  final Directory scratch = await Directory.systemTemp.createTemp(
    'kallo-photograph-',
  );
  try {
    final File preview = File(
      '${scratch.path}${Platform.pathSeparator}photograph.png',
    );
    await thumbnail_api.makeThumbnail(
      input: file.path,
      output: preview.path,
      width: width,
    );
    return await decode(preview, width: width);
  } finally {
    try {
      await scratch.delete(recursive: true);
    } on Object catch (error) {
      // The picture has been decoded; a scratch folder the system will not let
      // go of is the system's business and not a reason to fail the darkroom.
      debugPrint('the photograph scratch folder could not be removed: $error');
    }
  }
}

/// Whether the model says this file is a camera raw.
///
/// When the model is not loaded — a test, or a build whose native asset did not
/// come through — the answer is no, and the engine tries the file itself. That
/// is exactly what the app did before it could read raws, and it keeps an
/// ordinary photograph working on a bench where the model is missing.
Future<bool> _isCameraRaw(File file) async {
  try {
    return await thumbnail_api.isCameraRaw(path: file.path);
  } on Object catch (error) {
    debugPrint('the model could not say whether ${file.path} is a raw: $error');
    return false;
  }
}
