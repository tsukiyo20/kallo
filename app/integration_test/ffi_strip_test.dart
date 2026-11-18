import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kallo/lab/ffi_model.dart';
import 'package:kallo/lab/chart.dart';
import 'package:kallo/lab/export_format.dart';
import 'package:kallo/lab/model.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/render_device.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/lab/strip_develop.dart';
import 'package:kallo/lab/tuning.dart';
import 'package:kallo/main.dart';
import 'package:kallo/views/steps.dart';
import 'package:kallo/widgets/time_slider.dart';

/// Whether two frames hold the same bytes.
bool _samePixels(ByteData a, ByteData b) {
  final Uint8List left = a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes);
  final Uint8List right = b.buffer.asUint8List(
    b.offsetInBytes,
    b.lengthInBytes,
  );
  for (int i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

/// The test strip, through the linked model.
///
/// The one thing the strip has to prove is that two prints at different
/// developments were exposed once: if each print solved its own balance, the
/// development would be hidden by the timer, and this is where that shows.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the linked model names the machine it runs on', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');

    RenderDevice.resetCache();
    final RenderDevice device = await RenderDevice.probe();
    expect(device.cores, greaterThan(0));
    expect(device.gpu, isNotNull, reason: 'the renderer\'s own adapter');
    expect(device.cpu, isNotNull, reason: 'the operating system names it');
    expect(device.platform, Platform.operatingSystem);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('a strip is one exposure, print after print', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');
    final Model model = Model.find();
    expect(model.available, isTrue);

    final File photograph = File('../../file-test/DSCF0989.JPG');
    expect(photograph.existsSync(), isTrue, reason: 'the test photograph');

    final Directory folder = await Directory.systemTemp.createTemp(
      'kallo-strip-',
    );
    addTearDown(() => folder.delete(recursive: true));

    TestStrip strip = TestStrip(
      photo: photograph.path,
      stockId: 'vision3_500t',
      stockLabel: 'VISION3 500T',
      paperId: 'portra_endura',
      paperLabel: 'PORTRA ENDURA',
      tempC: 20,
    );

    final Stopwatch watch = Stopwatch()..start();
    strip = await developTestPrint(
      model: model,
      strip: strip,
      minutes: 6,
      folder: folder,
    );
    expect(strip.balanceFrom, 6, reason: 'the first print sets the exposure');
    expect(strip.prints, hasLength(1));
    expect(strip.prints.single.image, isNotNull);
    expect(strip.prints.single.chart, isNotNull);

    final double first = await _mean(strip.prints.single.image!);
    strip = await developTestPrint(
      model: model,
      strip: strip,
      minutes: 12,
      folder: folder,
    );
    watch.stop();
    // ignore: avoid_print
    print('ffi test strip: ${watch.elapsedMilliseconds} ms');

    expect(strip.prints, hasLength(2));
    expect(strip.balanceFrom, 6, reason: 'later prints reuse the first');
    final TestPrint longer = strip.prints.last;
    expect(longer.minutes, 12);
    expect(longer.image, isNotNull);
    final double second = await _mean(longer.image!);

    // Twelve minutes makes a denser negative; printed on the six-minute
    // balance it passes less light, so the print is lighter. If the model had
    // balanced each print on its own, the two would come out alike.
    expect(
      second,
      greaterThan(first),
      reason: 'the longer development should print lighter on one exposure',
    );
    expect(
      (second - first).abs(),
      greaterThan(1),
      reason: 'the strip must not be two copies of the same print',
    );

    final Directory exports = await Directory.systemTemp.createTemp(
      'kallo-strip-print-',
    );
    addTearDown(() => exports.delete(recursive: true));
    final File printed = await printTest(
      model: model,
      strip: strip,
      minutes: 6,
      exports: exports,
      width: 800,
    );
    expect(printed.existsSync(), isTrue);
    expect(printed.lengthSync(), greaterThan(0));
    expect(
      File(printed.path.replaceFirst('.png', '.json')).existsSync(),
      isFalse,
      reason: 'the export folder holds images, not sidecars',
    );

    final File jpeg = await printTest(
      model: model,
      strip: strip,
      minutes: 6,
      exports: exports,
      format: ExportFormat.jpeg,
      width: 800,
    );
    expect(jpeg.path, endsWith('.jpg'));
    expect(
      File(jpeg.path.replaceFirst('.jpg', '.png')).existsSync(),
      isFalse,
      reason: 'the temporary PNG is removed',
    );
    final Print? jpegPrint = await Print.read(jpeg);
    expect(jpegPrint, isNotNull);
    expect(jpegPrint!.pixels?.width, 800);
    jpegPrint.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a bench session is one decode, then renders', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');
    final Model model = Model.find();
    final File photograph = File('../../file-test/DSCF0989.JPG');
    expect(photograph.existsSync(), isTrue, reason: 'the test photograph');

    PreviewSession? session;
    addTearDown(() => session?.dispose());

    final Stopwatch opening = Stopwatch()..start();
    session = await model.openPreview(
      photograph: photograph,
      stock: 'vision3_500t',
      paper: 'portra_endura',
      tempC: 20,
      width: 760,
    );
    opening.stop();
    expect(session, isNotNull, reason: 'the linked model holds a session');

    final Stopwatch firstWatch = Stopwatch()..start();
    final ui.Image first = await session!.frame(minutes: 6);
    firstWatch.stop();
    expect(first.width, 760);
    expect(first.height, greaterThan(0));
    first.dispose();

    final List<int> renders = <int>[];
    for (final double minutes in <double>[7, 8, 9, 10, 11, 12]) {
      final Stopwatch watch = Stopwatch()..start();
      final ui.Image image = await session.frame(minutes: minutes);
      watch.stop();
      renders.add(watch.elapsedMilliseconds);
      image.dispose();
    }

    final Stopwatch cachedWatch = Stopwatch()..start();
    final ui.Image cached = await session.frame(minutes: 6);
    cachedWatch.stop();
    cached.dispose();

    // ignore: avoid_print
    print(
      'ffi preview session: open ${opening.elapsedMilliseconds} ms, '
      'first render ${firstWatch.elapsedMilliseconds} ms, '
      'further $renders ms, cached ${cachedWatch.elapsedMilliseconds} ms',
    );
    expect(renders, hasLength(6));
  }, timeout: const Timeout(Duration(minutes: 5)));

  /// A recipe is a print: the session renders the same negative again, with
  /// the departures, and the frame it hands back is that sheet.
  test('a bench session prints the recipe it is told', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');
    final Model model = Model.find();
    final File photograph = File('../../file-test/DSCF0989.JPG');
    expect(photograph.existsSync(), isTrue, reason: 'the test photograph');

    PreviewSession? session;
    addTearDown(() => session?.dispose());
    session = await model.openPreview(
      photograph: photograph,
      stock: 'vision3_500t',
      paper: 'portra_endura',
      tempC: 20,
      width: 380,
    );
    expect(session, isNotNull);

    final ui.Image plain = await session!.frame(minutes: 6);
    final ByteData plainBytes = (await plain.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    plain.dispose();

    // The mask is a borrowed measurement on this stock, so it is a control a
    // recipe can move: the same negative and the same time, another sheet.
    await session.setTuning(
      tuning: Tuning.identity.copyWith(maskStrength: 1.5),
    );
    final ui.Image departed = await session.frame(minutes: 6);
    final ByteData departedBytes = (await departed.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    departed.dispose();

    expect(departedBytes.lengthInBytes, plainBytes.lengthInBytes);
    expect(
      _samePixels(plainBytes, departedBytes),
      isFalse,
      reason: 'the departures were part of the print',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the print curve is drawn under the enlarger', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');
    final Model model = Model.find();

    final PrintCurve? base = await model.printCurve(
      film: 'vision3_500t',
      paper: 'portra_endura',
      minutes: 6,
      tempC: 20,
    );
    expect(base, isNotNull);
    expect(base!.logE, isNotEmpty);
    expect(base.density, hasLength(base.logE.length));

    final PrintCurve? over = await model.printCurve(
      film: 'vision3_500t',
      paper: 'portra_endura',
      minutes: 6,
      tempC: 20,
      printEv: 1,
    );
    expect(over, isNotNull);
    expect(
      over!.shift[0],
      greaterThan(base.shift[0]),
      reason: 'a stop of timer moves the curve under the paper',
    );

    final PrintCurve? filtered = await model.printCurve(
      film: 'vision3_500t',
      paper: 'portra_endura',
      minutes: 6,
      tempC: 20,
      filters: '30M',
    );
    expect(filtered, isNotNull);
    expect(
      filtered!.shift,
      isNot(equals(base.shift)),
      reason: 'the colour pack is part of the enlarger',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('the develop step previews from the bench session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final File photograph = File('../../file-test/DSCF0989.JPG');
    await tester.pumpWidget(
      KalloApp(
        strip: TestStrip(
          photo: photograph.path,
          stockId: 'vision3_500t',
          stockLabel: 'VISION3 500T',
          paperId: 'portra_endura',
          paperLabel: 'PORTRA ENDURA',
          tempC: 20,
        ),
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        appearance: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final Finder slider = find.byType(TimeSlider);
    expect(slider, findsOneWidget);
    ui.Image? easel() {
      final Finder found = find.byType(RawImage);
      if (found.evaluate().isEmpty) {
        return null;
      }
      return tester.widget<RawImage>(found.first).image;
    }

    for (int i = 0; i < 200 && easel() == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final ui.Image first = easel()!;
    expect(first.width, 760);

    final Stopwatch watch = Stopwatch()..start();
    await tester.drag(slider, const Offset(180, 0));
    ui.Image? next;
    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      next = easel();
      if (next != null && !identical(next, first)) {
        break;
      }
    }
    watch.stop();
    expect(next, isNotNull, reason: 'the easel should show the new time');
    expect(
      identical(next, first),
      isFalse,
      reason: 'the preview should be a new frame, not the old one',
    );
    // ignore: avoid_print
    print('develop preview after a drag: ${watch.elapsedMilliseconds} ms');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 5)));
  test('a finished print reports its work as it happens', () async {
    final bool loaded = await loadLinkedModel();
    expect(loaded, isTrue, reason: 'the dynamic library should load');
    final Model model = Model.find();
    final File photograph = File('../../file-test/DSCF0989.JPG');
    expect(photograph.existsSync(), isTrue, reason: 'the test photograph');
    final Directory exports = await Directory.systemTemp.createTemp(
      'kallo-progress-',
    );
    addTearDown(() => exports.delete(recursive: true));

    final TestStrip strip = TestStrip(
      photo: photograph.path,
      stockId: 'vision3_500t',
      stockLabel: 'VISION3 500T',
      paperId: 'portra_endura',
      paperLabel: 'PORTRA ENDURA',
      tempC: 20,
    );
    final List<double> steps = <double>[];
    final File printed = await printTest(
      model: model,
      strip: strip,
      minutes: 3,
      exports: exports,
      width: 800,
      onProgress: steps.add,
    );
    expect(printed.existsSync(), isTrue);
    expect(steps, isNotEmpty);
    expect(
      steps.length,
      greaterThan(5),
      reason: 'the model reports stages, not only a start and an end: $steps',
    );
    expect(steps.first, lessThan(0.05));
    // The print leaves its last tenth to the caller: the edge and the shelf are
    // still to come when printTest returns.
    expect(steps.last, 0.9);
    for (int i = 1; i < steps.length; i++) {
      expect(
        steps[i],
        greaterThanOrEqualTo(steps[i - 1]),
        reason: 'progress goes forward: $steps',
      );
    }
    // ignore: avoid_print
    print(
      'print progress: ${steps.map((double value) => value.toStringAsFixed(2)).join(", ")}',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// The mean of the three channels, 0–255: the print's average light.
Future<double> _mean(ui.Image image) async {
  final ByteData? data = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (data == null) {
    return 0;
  }
  final Uint8List bytes = data.buffer.asUint8List();
  double sum = 0;
  int count = 0;
  for (int i = 0; i < bytes.length; i += 4) {
    sum += (bytes[i] + bytes[i + 1] + bytes[i + 2]) / 3;
    count++;
  }
  return count == 0 ? 0 : sum / count;
}
