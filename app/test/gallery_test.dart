import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/main.dart';
import 'package:kallo/views/chambers.dart';
import 'package:kallo/widgets/glass_print.dart';
import 'package:kallo/widgets/print_image.dart';
import 'package:kallo/widgets/switch.dart';
import 'package:kallo/widgets/wall.dart';

Future<ui.Image> _card({int width = 1600, int height = 1067}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Rect full = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  canvas.drawRect(full, Paint()..color = const Color(0xFFD8D2C4));
  canvas.drawRect(
    Rect.fromLTWH(0, height * 0.55, width.toDouble(), height * 0.45),
    Paint()..color = const Color(0xFF4E6B63),
  );
  canvas.drawRect(
    Rect.fromLTWH(width * 0.12, height * 0.18, width * 0.3, height * 0.6),
    Paint()..color = const Color(0xFF8C6A4A),
  );
  canvas.drawRect(
    Rect.fromLTWH(width * 0.62, height * 0.24, width * 0.24, height * 0.5),
    Paint()..color = const Color(0xFF1E1B18),
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the loupe switch is glass on paper, and the paper is flat', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Print shot;
    late ui.Image card;
    final Directory folder = (await tester.runAsync(() async {
      final Directory folder = await Directory.systemTemp.createTemp(
        'kallo-gallery-',
      );
      final ui.Image card = await _card();
      final File file = File('${folder.path}/print-01.png');
      final ByteData? png = await card.toByteData(
        format: ui.ImageByteFormat.png,
      );
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
      // A wall hangs the print's paper, not the film: the record is what the
      // label has to say, and the file is what the loupe decodes.
      shot = Print(
        image: card,
        name: 'print-01',
        path: file.path,
        pixels: const Size(1600, 1067),
        printNumber: 1,
        process: FilmProcess.negative,
        film: 'ULTRA MAX 400',
        paper: 'PORTRA ENDURA',
        minutes: 9,
        tempC: 20,
        printed: DateTime(2026, 11, 13, 21, 30),
      );
      return folder;
    }))!;
    card = shot.image!;
    addTearDown(() => folder.delete(recursive: true));
    addTearDown(card.dispose);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: <Print>[shot],
        initialChamber: Chamber.gallery,
        locale: const Locale('zh'),
        appearance: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    final Finder loupe = find.byKey(const Key('loupe'));
    expect(loupe, findsOneWidget);
    expect(tester.widget<KalloSwitch>(loupe).on, isFalse);

    // The wall hangs one print as one sheet of paper: the picture, the paper's
    // margin and the label. There is no film frame anywhere on it.
    expect(find.byType(PrintSheet), findsOneWidget);
    expect(find.byType(PrintImage), findsOneWidget);
    expect(find.textContaining('ULTRA MAX 400'), findsOneWidget);

    final Offset wallCentre = tester.getCenter(find.byType(PrintSheet).first);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(wallCentre);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('lens')),
      findsNothing,
      reason: 'a loupe is taken up, not followed by the pointer',
    );

    await tester.tap(loupe);
    await tester.pumpAndSettle();
    expect(tester.widget<KalloSwitch>(loupe).on, isTrue);
    await mouse.moveTo(wallCentre);
    await tester.pumpAndSettle();
    final Finder lens = find.byKey(const Key('lens'));
    expect(lens, findsOneWidget);
    expect(
      find.descendant(of: lens, matching: find.byType(PrintSheet)),
      findsOneWidget,
      reason: 'the glass magnifies the picture; the paper stays paper',
    );
    final GlassPrint glass = tester.widget<GlassPrint>(
      find.descendant(of: lens, matching: find.byType(GlassPrint)),
    );
    expect(
      glass.barrel,
      greaterThan(0),
      reason: 'the glass is the one place the picture bends',
    );

    await tester.tap(loupe);
    await tester.pumpAndSettle();
    expect(tester.widget<KalloSwitch>(loupe).on, isFalse);
    await mouse.moveTo(wallCentre);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lens')), findsNothing);

    await tester.tap(find.byType(PrintSheet).first);
    await tester.pumpAndSettle();
    expect(find.byType(PrintSheet), findsOneWidget);
    expect(
      find.byKey(const Key('loupe')),
      findsNothing,
      reason: 'the glass belongs to the wall, not to the print in hand',
    );
    expect(find.byKey(const Key('lens')), findsNothing);
    expect(
      find.byKey(const Key('export')),
      findsNothing,
      reason:
          'the print was written when it was made, not when it is looked at',
    );
    expect(tester.widget<GlassPrint>(find.byType(GlassPrint)).barrel, 0);
    expect(
      find.textContaining('ULTRA MAX 400'),
      findsOneWidget,
      reason: 'the label follows the print it names',
    );

    final String before = tester.widget<Text>(find.textContaining('像素')).data!;
    expect(before, contains('1600 × 1067'));

    final Offset centre = tester.getCenter(find.byType(GlassPrint));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: centre,
        scrollDelta: const Offset(0, -300),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
    final String after = tester.widget<Text>(find.textContaining('像素')).data!;
    expect(
      after,
      isNot(before),
      reason: 'the readout says how far it was walked',
    );
    expect(
      tester.widget<GlassPrint>(find.byType(GlassPrint)).barrel,
      0,
      reason: 'walking up to a print does not bend the paper',
    );

    // Escape is the way back: it closes the print, not the room.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('back')), findsNothing);
    expect(find.byKey(const Key('loupe')), findsOneWidget);
    expect(find.textContaining('像素'), findsNothing);

    await tester.tap(find.byType(PrintSheet).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('back')), findsNothing);
    expect(find.byKey(const Key('loupe')), findsOneWidget);
    expect(find.byType(PrintSheet), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
