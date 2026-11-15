import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kallo/lab/ffi_model.dart';
import 'package:kallo/lab/image_file.dart';

/// The darkroom's photograph, from a camera raw.
///
/// The engine's decoder reads what a window reads — JPEG, PNG, WebP — and a
/// camera raw is none of them. The model carries the only decoder that knows
/// the mosaic, so this test is the one that proves the app's photograph path
/// works with a raw in the app it ships in: the model develops the file to a
/// small PNG and the window reads that.
///
/// A unit test cannot prove it for the same reason it cannot prove the roll:
/// the linked model's code asset is bundled by the platform build.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('a camera raw becomes the photograph on the bench', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');

    final File raw = File('../../file-test/DSC03315.ARW');
    expect(raw.existsSync(), isTrue, reason: 'the raw test photograph');

    final Stopwatch watch = Stopwatch()..start();
    final ui.Image image = await decodePhotograph(raw, width: 1600);
    watch.stop();
    addTearDown(image.dispose);

    // The sensor's mosaic is wider than the bench asks for, and the small copy
    // must be no wider than asked; the height proves the shape came through
    // with the pixels instead of a one-pixel thumbnail.
    expect(image.width, lessThanOrEqualTo(1600));
    expect(image.height, greaterThan(image.width ~/ 2));
    // ignore: avoid_print
    print(
      'raw photograph: ${image.width}x${image.height} '
      'in ${watch.elapsedMilliseconds} ms',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('an ordinary photograph still goes through the engine', () async {
    final File photograph = File('../../file-test/DSCF0989.JPG');
    expect(photograph.existsSync(), isTrue, reason: 'the test photograph');

    final ui.Image image = await decodePhotograph(photograph, width: 1600);
    addTearDown(image.dispose);
    expect(image.width, lessThanOrEqualTo(1600));
    expect(image.height, greaterThan(0));
  });
}
