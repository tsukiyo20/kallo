import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/strings.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/main.dart';
import 'package:kallo/views/chambers.dart';
import 'package:kallo/views/drawer.dart';
import 'package:kallo/views/gallery.dart';
import 'package:kallo/widgets/glass_print.dart';
import 'package:kallo/widgets/print_image.dart';
import 'package:kallo/widgets/switch.dart';
import 'package:kallo/widgets/wall.dart';

/// The wall alone, in the room's scope: the window is not what is being
/// tested when work arrives.
class _WallHarness extends StatefulWidget {
  const _WallHarness({required this.first});

  final Print first;

  @override
  State<_WallHarness> createState() => _WallHarnessState();
}

class _WallHarnessState extends State<_WallHarness> {
  late List<Print> _prints = <Print>[widget.first];

  void add(Print print) => setState(() => _prints = <Print>[print, ..._prints]);

  @override
  Widget build(BuildContext context) => Gallery(
    prints: _prints,
    hanging: const <String, Offset>{},
  );
}

Widget _bare(Widget child) => Localizations(
  locale: const Locale('zh'),
  delegates: const <LocalizationsDelegate<Object>>[
    KalloStrings.delegate,
    DefaultWidgetsLocalizations.delegate,
  ],
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1048, 820)),
      child: KalloScope(
        colors: KalloColors.of(Brightness.dark),
        pinned: Brightness.dark,
        onPin: (Brightness? _) {},
        child: DefaultTextStyle(
          style: KalloType.body.copyWith(
            color: KalloColors.of(Brightness.dark).ink,
          ),
          child: child,
        ),
      ),
    ),
  ),
);

/// Three prints for the wall, made of one card.
List<Print> _prints(ui.Image card) => <Print>[
  for (int i = 0; i < 3; i++)
    Print(
      image: card,
      name: 'print-0$i',
      pixels: const Size(1200, 800),
      printNumber: 1,
      process: FilmProcess.negative,
      film: 'ULTRA MAX 400',
      paper: 'PORTRA ENDURA',
      minutes: <double>[6, 9, 12][i],
      tempC: 20,
    ),
];

Widget _app({
  required List<Print> prints,
  Map<String, Offset> hanging = const <String, Offset>{},
  VoidCallback? onImport,
  bool drawerOpen = false,
}) => KalloApp(
  catalogue: Catalogue.carried,
  strip: const TestStrip(photo: '/photographs/uji.jpg'),
  photograph: null,
  prints: prints,
  hanging: hanging,
  onImport: onImport,
  initialChamber: Chamber.gallery,
  locale: const Locale('zh'),
  appearance: Brightness.dark,
  drawerOpen: drawerOpen,
);

/// A drag, in several moves, so that a gesture arena has time to resolve the
/// way a real pointer gives it time.
Future<void> _walk(
  WidgetTester tester,
  Offset from,
  Offset by, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final TestGesture gesture = await tester.startGesture(from, kind: kind);
  const int steps = 8;
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(by / steps.toDouble());
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

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

    // The lamp switch is gone: the wall is lit, and the chrome says nothing
    // about a light that cannot be changed.
    expect(find.byKey(const Key('light')), findsNothing);

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

  testWidgets('the wall is walked, and comes back home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ui.Image card = (await tester.runAsync(_card))!;
    addTearDown(card.dispose);

    await tester.pumpWidget(_app(prints: _prints(card)));
    await tester.pumpAndSettle();
    final Offset before = tester.getTopLeft(find.byType(PrintSheet).first);

    // The wall is longer than the window: a drag on it is a walk.
    await _walk(tester, const Offset(520, 660), const Offset(-140, -90));
    final Offset walked = tester.getTopLeft(find.byType(PrintSheet).first);
    expect(walked.dx, lessThan(before.dx - 80));
    expect(walked.dy, lessThan(before.dy - 50));

    // A wall that has been walked offers its way back.
    final Finder home = find.byKey(const Key('wall-home'));
    expect(home, findsOneWidget);
    await tester.tap(home);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(PrintSheet).first), before);

    // A click still walks up to the print.
    expect(find.byType(PrintSheet), findsNWidgets(3));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a sheet is hung where it is put, and hung back', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ui.Image card = (await tester.runAsync(_card))!;
    addTearDown(card.dispose);

    await tester.pumpWidget(_app(prints: _prints(card)));
    await tester.pumpAndSettle();

    List<Offset> tops() => <Offset>[
      for (int i = 0; i < 3; i++)
        tester.getTopLeft(find.byType(PrintSheet).at(i)),
    ];

    final List<Offset> before = tops();
    final Offset centre = tester.getCenter(find.byType(PrintSheet).first);
    const Offset move = Offset(230, 130);

    // Dragging a sheet hangs it where it is let go; the wall does not move.
    await _walk(tester, centre, move, kind: PointerDeviceKind.mouse);
    final List<Offset> after = tops();
    int moved = 0;
    int stayed = 0;
    for (final Offset top in after) {
      if (before.any((Offset one) => (one - top).distance < 2)) {
        stayed++;
      } else if ((top - (before[0] + move)).distance < 60) {
        moved++;
      }
    }
    expect(moved, 1, reason: 'one sheet follows the pointer');
    expect(
      stayed,
      2,
      reason: 'the wall hangs the other sheets where they were',
    );
    expect(find.byKey(const Key('wall-rehang')), findsOneWidget);

    // The wall can be hung back in its own grid.
    await tester.tap(find.byKey(const Key('wall-rehang')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wall-rehang')), findsNothing);
    final List<Offset> grid = tops();
    for (final Offset top in grid) {
      expect(before.any((Offset one) => (one - top).distance < 2), isTrue);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('work brought in is shown, not left off the wall', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1048, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ui.Image card = (await tester.runAsync(_card))!;
    addTearDown(card.dispose);

    final Print first = _prints(card).first;
    final Print arrival = Print(
      image: card,
      name: 'arrival',
      pixels: const Size(1200, 800),
      process: FilmProcess.monochrome,
      film: 'T-MAX 400',
      paper: 'POLYMAX II RC',
      minutes: 9,
      tempC: 20,
    );

    await tester.pumpWidget(_bare(_WallHarness(first: first)));
    await tester.pumpAndSettle();
    expect(find.byType(PrintSheet), findsOneWidget);

    // Walk the wall away from its beginning, then bring a picture in.
    await _walk(tester, const Offset(700, 700), const Offset(-420, 0));
    tester.state<_WallHarnessState>(find.byType(_WallHarness)).add(arrival);
    await tester.pumpAndSettle();

    expect(find.byType(PrintSheet), findsNWidgets(2));
    bool shown = false;
    for (int i = 0; i < 2; i++) {
      final Offset centre = tester.getCenter(find.byType(PrintSheet).at(i));
      if ((centre - const Offset(1048 / 2, 820 / 2)).distance < 120) {
        shown = true;
      }
    }
    expect(shown, isTrue, reason: 'the picture arrives where it can be seen');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('the wall carries the import action', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ui.Image card = (await tester.runAsync(_card))!;
    addTearDown(card.dispose);

    int imports = 0;
    await tester.pumpWidget(
      _app(prints: _prints(card), onImport: () => imports++),
    );
    await tester.pumpAndSettle();
    final Finder action = find.byKey(const Key('import-pictures'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(imports, 1);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('the settings keep the folder and lose the import', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ui.Image card = (await tester.runAsync(_card))!;
    addTearDown(card.dispose);

    await tester.pumpWidget(_app(prints: _prints(card), drawerOpen: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('印相'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SettingsDrawer),
        matching: find.text('导入图片…'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SettingsDrawer),
        matching: find.text('文件夹'),
      ),
      findsOneWidget,
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
