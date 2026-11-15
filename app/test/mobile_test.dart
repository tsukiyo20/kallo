import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/chart.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/main.dart';
import 'package:kallo/views/chambers.dart';
import 'package:kallo/views/steps.dart';

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
  DarkroomStep step = DarkroomStep.select,
  Chamber chamber = Chamber.darkroom,
  TestStrip? strip,
  List<Print> prints = const <Print>[],
  Catalogue? catalogue,
}) => KalloApp(
  catalogue: catalogue ?? Catalogue.carried,
  strip: strip ?? const TestStrip(photo: '/photographs/uji.jpg'),
  photograph: card,
  prints: prints,
  initialStep: step,
  initialChamber: chamber,
  locale: const Locale('en'),
);

void main() {
  late ui.Image card;

  setUpAll(() async {
    card = await _card();
  });

  testWidgets('the compact shell is three places and a gear', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-tab-darkroom')), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-rack')), findsOneWidget);
    expect(find.byKey(const Key('mobile-tab-gallery')), findsOneWidget);
    expect(find.byKey(const Key('mobile-settings')), findsOneWidget);
    expect(find.byKey(const Key('phone-film-row')), findsOneWidget);
    expect(find.byKey(const Key('phone-paper-row')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final Size filmRow = tester.getSize(
      find.byKey(const Key('phone-film-row')),
    );
    expect(filmRow.height, greaterThanOrEqualTo(56));
    final Size gear = tester.getSize(find.byKey(const Key('mobile-settings')));
    expect(gear.shortestSide, greaterThanOrEqualTo(44));
  });

  testWidgets('the phone opens the material picker', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('phone-film-row')));
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

  testWidgets('the phone shows two columns in both rooms', (
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
      _app(card: card, chamber: Chamber.rack, prints: prints),
    );
    await tester.pumpAndSettle();
    expect(find.text('Drying rack'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app(card: card, chamber: Chamber.gallery, prints: prints),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('4 prints'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('phone-film-row')));
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

  testWidgets('the print step shows four values', (WidgetTester tester) async {
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('the system back walks the darkroom backwards', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final TestStrip strip =
        const TestStrip(photo: '/photographs/uji.jpg').withPrint(
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

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-film-row')), findsOneWidget);
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

  testWidgets('the smallest phone does not overflow', (
    WidgetTester tester,
  ) async {
    _phone(tester, width: 375, height: 667);
    await tester.pumpWidget(_app(card: card));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_app(card: card, step: DarkroomStep.select));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
