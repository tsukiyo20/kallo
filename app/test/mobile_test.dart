import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/chart.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/render_mode.dart';
import 'package:kallo/lab/settings.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/edge_print.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/main.dart';
import 'package:kallo/widgets/wall.dart';
import 'package:kallo/views/chambers.dart';
import 'package:kallo/views/steps.dart';
import 'package:kallo/widgets/border_tray.dart';

Future<ui.Image> _card({int width = 1200, int height = 800}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double w = width.toDouble();
  final double h = height.toDouble();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFFD8D2C4),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, h * 0.65, w, h * 0.35),
    Paint()..color = const Color(0xFF4E6B63),
  );
  canvas.drawRect(
    Rect.fromLTWH(w * 0.15, h * 0.25, w * 0.3, h * 0.5),
    Paint()..color = const Color(0xFF8C6A4A),
  );
  return recorder.endRecording().toImage(width, height);
}

FilmChart _chart(double minutes) => FilmChart(
  minutes: minutes,
  tempC: 20,
  gamma: <double>[0.55, 0.57, 0.60],
  dMin: <double>[0.06, 0.06, 0.06],
  dMax: <double>[2.1, 2.3, 2.6],
  patches: <List<double>>[
    for (int i = 0; i < 9; i++) <double>[0.15 * i, 0.16 * i, 0.18 * i],
  ],
  logE: <double>[for (int i = 0; i < 9; i++) -2.0 + i * 0.35],
);

Print _print(ui.Image card, int number) => Print(
  image: card,
  name: 'print-0$number',
  pixels: const Size(1200, 800),
  printNumber: number,
  film: 'KODAK ULTRA MAX 400',
  paper: 'FUJIFILM CRYSTAL ARCHIVE PEARL',
  minutes: 12,
  tempC: 20,
);

void _phone(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app({
  required ui.Image card,
  DarkroomStep step = DarkroomStep.develop,
  Chamber chamber = Chamber.darkroom,
  TestStrip? strip,
  List<Print> prints = const <Print>[],
  Catalogue? catalogue,
  VoidCallback? onImport,
}) => KalloApp(
  catalogue: catalogue ?? Catalogue.carried,
  strip: strip ?? const TestStrip(photo: '/photographs/uji.jpg'),
  photograph: card,
  prints: prints,
  onImport: onImport,
  initialStep: step,
  initialChamber: chamber,
  locale: const Locale('en'),
);

void main() {
  late ui.Image card;
  late Directory settingsFolder;

  setUpAll(() async {
    card = await _card();
  });

  setUp(() {
    // A settings write in a test must not land in the person's config folder.
    settingsFolder = Directory.systemTemp.createTempSync('kallo-mobile-');
    Settings.useDirectory(settingsFolder);
    RenderPreference.set(RenderMode.gpu);
  });

  tearDown(() {
    Settings.useDirectory(null);
    RenderPreference.set(RenderMode.gpu);
    settingsFolder.deleteSync(recursive: true);
  });

  testWidgets('the compact shell is two places and a gear', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-tab-darkroom')), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-gallery')), findsOneWidget);
    expect(find.byKey(const Key('mobile-settings')), findsOneWidget);
    expect(find.byKey(const Key('phone-materials-row')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final Size materials = tester.getSize(
      find.byKey(const Key('phone-materials-row')),
    );
    expect(materials.height, greaterThanOrEqualTo(44));
    final Size gear = tester.getSize(find.byKey(const Key('mobile-settings')));
    expect(gear.shortestSide, greaterThanOrEqualTo(44));
  });

  testWidgets('the phone opens the material picker', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('phone-materials-row')));
    await tester.pumpAndSettle();
    expect(find.text('MATERIALS'), findsOneWidget);
    expect(find.text('VISION3 500T'), findsOneWidget);

    await tester.tap(find.text('VISION3 500T'));
    await tester.pumpAndSettle();
    expect(find.text('FILM'), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.text('VISION3 500T'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone shows the deck and a test print', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final TestStrip strip = const TestStrip(photo: '/photographs/uji.jpg')
        .withPrint(
          TestPrint(minutes: 12, tempC: 20, image: card, chart: _chart(12)),
        );
    await tester.pumpWidget(
      _app(card: card, step: DarkroomStep.develop, strip: strip),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phone-develop')), findsOneWidget);
    expect(find.textContaining('TEST STRIP'), findsOneWidget);
    expect(find.text('12:00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone wall is a wall, not a list', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final List<Print> prints = <Print>[
      _print(card, 1),
      _print(card, 2),
      _print(card, 3),
      _print(card, 4),
    ];
    await tester.pumpWidget(
      _app(card: card, chamber: Chamber.gallery, prints: prints),
    );
    await tester.pumpAndSettle();
    // The room's name is the header's and the tab bar's; both are the same
    // place.
    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('4 prints'), findsOneWidget);
    expect(find.byType(PrintSheet), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap on the phone wall opens the print, not the wall', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final List<Print> prints = <Print>[
      _print(card, 1),
      _print(card, 2),
      _print(card, 3),
    ];
    await tester.pumpWidget(
      _app(card: card, chamber: Chamber.gallery, prints: prints),
    );
    await tester.pumpAndSettle();

    // The wall has its chrome: the room's name, the count, the two places.
    expect(find.text('3 prints'), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-gallery')), findsOneWidget);

    // One tap, and the print is the page. There is no fullscreen wall in
    // between, and the wall is not rebuilt to make room.
    await tester.tap(find.byType(PrintSheet).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('print-viewer-image')), findsOneWidget);
    expect(find.byKey(const Key('print-viewer-close')), findsOneWidget);

    // The picture takes the width of the screen and keeps its shape: the
    // margin that is left goes above and below, never beside.
    final Size picture = tester.getSize(
      find.byKey(const Key('print-viewer-image')),
    );
    expect(picture.width, moreOrLessEquals(390));
    expect(picture.height, moreOrLessEquals(390 * 800 / 1200));

    // Back puts the wall back exactly as it was: the chrome is the shell's,
    // not the picture's.
    await tester.tap(find.byKey(const Key('print-viewer-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('print-viewer-image')), findsNothing);
    expect(find.byKey(const Key('mobile-tab-gallery')), findsOneWidget);
    expect(find.text('3 prints'), findsOneWidget);
    expect(find.byType(PrintSheet), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back leaves the print, then the wall', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final List<Print> prints = <Print>[_print(card, 1), _print(card, 2)];
    await tester.pumpWidget(
      _app(card: card, chamber: Chamber.gallery, prints: prints),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PrintSheet).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('print-viewer-image')), findsOneWidget);

    // One back closes the picture and nothing else. A second one is the
    // shell's own walk: the gallery goes to the darkroom, not out of the app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('print-viewer-image')), findsNothing);
    expect(find.byKey(const Key('mobile-tab-gallery')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-materials-row')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a material change asks before it clears the strip', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final Catalogue catalogue = Catalogue(
      films: <Stock>[
        Stocks.vision,
        const Stock(
          id: 'kodak_portra_400',
          short: 'PORTRA 400',
          label: 'KODAK PROFESSIONAL PORTRA 400',
          process: FilmProcess.negative,
        ),
      ],
      papers: <Stock>[Stocks.crystal],
    );
    final TestStrip strip = const TestStrip(photo: '/photographs/uji.jpg')
        .withPrint(
          TestPrint(minutes: 9, tempC: 20, image: card, chart: _chart(9)),
        );
    await tester.pumpWidget(
      _app(card: card, strip: strip, catalogue: catalogue),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('phone-materials-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VISION3 500T'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-kodak_portra_400')));
    await tester.pumpAndSettle();
    expect(find.text('Change the film?'), findsOneWidget);
    expect(find.textContaining('will be cleared'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Change the film?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone names the two sides of the wipe', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final TestStrip strip = const TestStrip(photo: '/photographs/uji.jpg')
        .withPrint(
          TestPrint(minutes: 12, tempC: 20, image: card, chart: _chart(12)),
        );
    await tester.pumpWidget(
      _app(card: card, step: DarkroomStep.develop, strip: strip),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORIGINAL'), findsNothing);
    await tester.tap(find.byKey(const Key('phone-compare')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The paper's bottom margin names the two sides; the deck's caption still
    // names the print, so "Test print" is twice.
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('Test print'), findsNWidgets(2));
  });

  testWidgets('the print step shows its values and the edge control', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final TestStrip strip = const TestStrip(photo: '/photographs/uji.jpg')
        .withPrint(
          TestPrint(minutes: 9, tempC: 20, image: card, chart: _chart(9)),
        );
    await tester.pumpWidget(
      _app(card: card, step: DarkroomStep.print, strip: strip),
    );
    await tester.pumpAndSettle();

    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('EXPOSURE'), findsOneWidget);
    expect(find.text('BALANCE'), findsOneWidget);
    expect(find.text('HEAT GLASS'), findsOneWidget);
    expect(find.byKey(const Key('phone-print')), findsOneWidget);

    // The exposure sheet says which way the dial goes: it is the enlarger's
    // timer, so more light is a darker print.
    await tester.tap(find.text('EXPOSURE'));
    await tester.pumpAndSettle();
    expect(find.text('More light is a darker print'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // The border is a printing choice on the phone too: one row in the deck
    // that opens the edges as pictures, with no words on them.
    expect(find.text('BORDER'), findsOneWidget);
    await tester.tap(find.text('BORDER'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-border')), findsOneWidget);
    expect(find.text('Edge · warm'), findsNothing);
    for (final BorderTemplate template in BorderTemplate.values) {
      expect(find.byKey(Key('phone-border-${template.name}')), findsOneWidget);
    }

    // A tap takes the edge; the sheet stays so the next one can be compared.
    await tester.tap(find.byKey(const Key('phone-border-warm')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BorderTile>(find.byKey(const Key('phone-border-warm')))
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('phone-border')), findsOneWidget);

    // The phone's back closes the sheet.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-border')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back walks the darkroom backwards', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final TestStrip strip = const TestStrip(photo: '/photographs/uji.jpg')
        .withPrint(
          TestPrint(minutes: 9, tempC: 20, image: card, chart: _chart(9)),
        );
    await tester.pumpWidget(
      _app(card: card, step: DarkroomStep.print, strip: strip),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-print')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-develop')), findsOneWidget);

    // The bench is the first page of the darkroom now: one step back from the
    // strip is the bench, and the next back leaves the room.
    expect(find.byKey(const Key('phone-materials-row')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone wall imports, and the settings do not', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    int imports = 0;
    final List<Print> prints = <Print>[_print(card, 1), _print(card, 2)];
    await tester.pumpWidget(
      _app(
        card: card,
        chamber: Chamber.gallery,
        prints: prints,
        onImport: () => imports++,
      ),
    );
    await tester.pumpAndSettle();

    // The wall carries its own import action, at the top right of the room.
    final Finder action = find.byKey(const Key('mobile-import-pictures'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(imports, 1);

    // The settings still say where the pictures go, and no longer bring them
    // in: the wall is the place that hangs them.
    await tester.tap(find.byKey(const Key('mobile-settings')));
    await tester.pumpAndSettle();
    final Finder page = find.byKey(const Key('mobile-settings-page'));
    for (int i = 0; i < 6 && find.text('Folder').evaluate().isEmpty; i++) {
      await tester.drag(page, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Import images…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('About says what the app is, and where to say something', (
    WidgetTester tester,
  ) async {
    _phone(tester, height: 1600);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-settings')));
    await tester.pumpAndSettle();
    final Finder page = find.byKey(const Key('mobile-settings-page'));
    for (
      int i = 0;
      i < 8 && find.textContaining('entirely open source').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(page, const Offset(0, -420));
      await tester.pumpAndSettle();
    }
    expect(
      find.textContaining('entirely open source and free'),
      findsOneWidget,
    );
    expect(find.textContaining('issues and pull requests'), findsOneWidget);
    expect(find.text('Open the project on GitHub'), findsOneWidget);
    // The changelog is the one more row the phone's About has: the app is not
    // installed from a release on a phone, so there is no update row to match.
    for (int i = 0; i < 6 && find.text('Changelog').evaluate().isEmpty; i++) {
      await tester.drag(page, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.text('Changelog'), findsOneWidget);
    expect(find.text('GitHub Releases'), findsOneWidget);
    expect(find.text('Updates'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings is a whole page, not a drawer', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-settings-page')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-settings-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the renderer is a setting on the phone, and the gpu is default',
    (WidgetTester tester) async {
      _phone(tester, height: 1600);
      await tester.pumpWidget(_app(card: card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mobile-settings')));
      await tester.pumpAndSettle();

      expect(find.text('RENDERING'), findsOneWidget);
      expect(find.text('GPU'), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
      // No linked model in a widget test: the page still names the fallback.
      expect(find.textContaining('cores'), findsWidgets);

      await tester.tap(find.text('CPU'));
      await tester.pumpAndSettle();

      expect(RenderPreference.gpu, isFalse);
      // The file is the settings tests' business; here the switch is the point.
    },
  );

  testWidgets('the smallest phone does not overflow', (
    WidgetTester tester,
  ) async {
    _phone(tester, width: 375, height: 667);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(card: card, step: DarkroomStep.develop));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
