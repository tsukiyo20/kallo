import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/chrome.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/strings.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/lab/chart.dart';
import 'package:kallo/lab/print.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/main.dart';
import 'package:kallo/views/chambers.dart';
import 'package:kallo/views/develop_stage.dart';
import 'package:kallo/views/rack.dart';
import 'package:kallo/views/steps.dart';
import 'package:kallo/widgets/chip.dart';
import 'package:kallo/widgets/stage_tabs.dart';
import 'package:kallo/widgets/stepper.dart';
import 'package:kallo/widgets/print_image.dart';
import 'package:kallo/widgets/print_viewer.dart';
import 'package:kallo/widgets/studio_sidebar.dart';
import 'package:kallo/widgets/studio_top_bar.dart';
import 'package:kallo/widgets/wall.dart';
import 'package:kallo/widgets/window_controls.dart';

Future<ui.Image> _card({int width = 600, int height = 400}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
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

void main() {
  late ui.Image card;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    card = await _card();
  });

  testWidgets('the darkroom opens on the photograph', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioSidebar), findsOneWidget);
    expect(find.text('KALLO'), findsOneWidget);
    expect(find.byType(StageTabs), findsOneWidget);
    expect(find.byType(DevelopStage), findsOneWidget);
    expect(find.text('暗房'), findsOneWidget);
    expect(find.text('晾片架'), findsOneWidget);
    expect(find.text('观景台'), findsOneWidget);
    expect(find.text('原片'), findsOneWidget);
    expect(find.text('换一张'), findsOneWidget);
  });

  testWidgets('a double click on the band fills the screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int asked = 0;
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        chrome: WindowChrome.windows,
        onToggleMaximize: () => asked++,
      ),
    );
    await tester.pumpAndSettle();

    // The band is this window's caption. The sidebar holds its left end and
    // the step capsule its middle, so the stretch between them is where a
    // person grabs a title bar and where they double click one.
    const Offset band = Offset(320, 28);
    await tester.tapAt(band);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(band);
    await tester.pumpAndSettle();

    expect(asked, 1);
  });

  testWidgets('a double click still fills the screen where the band drags', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int asked = 0;
    int dragged = 0;
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        chrome: WindowChrome.windows,
        onDragWindow: () => dragged++,
        onToggleMaximize: () => asked++,
      ),
    );
    await tester.pumpAndSettle();

    // A band that only knows how to drag starts one on the press itself: the
    // double click would be swallowed and the window would move instead.
    const Offset band = Offset(320, 28);
    await tester.tapAt(band);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(band);
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(dragged, 0);
  });

  testWidgets('a press on the band is not a drag until it moves', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int dragged = 0;
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        chrome: WindowChrome.windows,
        onDragWindow: () => dragged++,
      ),
    );
    await tester.pumpAndSettle();

    final TestGesture press = await tester.startGesture(const Offset(320, 28));
    await tester.pump(const Duration(milliseconds: 100));
    expect(dragged, 0);

    await press.up();
    await tester.pumpAndSettle();
    expect(dragged, 0);
  });

  testWidgets('a control in the band answers on the click, not on a timer', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int inspector = 0;
    await tester.pumpWidget(
      KalloScope(
        colors: KalloColors.dark,
        pinned: Brightness.dark,
        onPin: (Brightness? _) {},
        child: Localizations(
          locale: const Locale('zh'),
          delegates: const <LocalizationsDelegate<Object>>[
            KalloStrings.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 1280,
                child: StudioTopBar(
                  sidebarOpen: false,
                  onSidebar: () {},
                  chrome: WindowChrome.windows,
                  inspectorOpen: true,
                  onInspector: () => inspector++,
                  onDragWindow: () {},
                  onToggleMaximize: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The window's caption is the band behind the controls, not the controls
    // themselves: a tap on the inspector switch is the app's, and must not
    // wait out the double click that fills the screen.
    await tester.tap(find.byKey(const Key('inspector-toggle')));
    await tester.pump();
    expect(inspector, 1);
  });

  testWidgets('a single click on the band does not fill the screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int asked = 0;
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        chrome: WindowChrome.windows,
        onToggleMaximize: () => asked++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(320, 28));
    await tester.pumpAndSettle();

    expect(asked, 0);
  });

  testWidgets('a double click on the mac band asks its title bar setting', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int asked = 0;
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        chrome: WindowChrome.mac,
        onToggleMaximize: () => asked++,
      ),
    );
    await tester.pumpAndSettle();

    // The Mac hides its title bar but keeps the traffic lights over the
    // sidebar, so the band over the work is the caption that is left.
    const Offset band = Offset(320, 28);
    await tester.tapAt(band);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(band);
    await tester.pumpAndSettle();

    expect(asked, 1);
  });

  testWidgets('a double click over the sidebar is the caption too', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int asked = 0;
    int dragged = 0;
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        chrome: WindowChrome.mac,
        onDragWindow: () => dragged++,
        onToggleMaximize: () => asked++,
      ),
    );
    await tester.pumpAndSettle();

    // Where the traffic lights sit is title bar on the Mac even with the
    // sidebar open, so the strip that drags there takes the double click too.
    const Offset strip = Offset(100, 20);
    await tester.tapAt(strip);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(strip);
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(dragged, 0);
  });

  testWidgets('the band is not a caption where the system draws one', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    // No hidden frame, so no band to fill the screen from: the system's title
    // bar is two rows above this one and has the gesture already.
    expect(find.byType(WindowControls), findsNothing);
  });

  testWidgets('a phone gets one column and a bottom bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(StudioSidebar), findsNothing);
    expect(find.byType(StageTabs), findsNothing);
    expect(find.byType(DevelopStage), findsOneWidget);
    expect(find.text('暗房'), findsOneWidget);
    expect(find.text('晾片'), findsOneWidget);
    expect(find.text('观景'), findsOneWidget);
    expect(find.byKey(const Key('phone-materials-row')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-settings')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('mobile-settings-page')), findsOneWidget);
  });

  testWidgets('the develop step shows the strip and its curves', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final TestStrip strip =
        const TestStrip(
          photo: '/photographs/uji.jpg',
          stockId: 'vision3_500t',
          stockLabel: 'VISION3 500T',
        ).withPrint(
          TestPrint(minutes: 9, tempC: 20, image: card, chart: _chart(9)),
        );

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: strip,
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DevelopStage), findsOneWidget);
    expect(find.text('试片条'), findsWidgets);
    expect(find.text('9:00'), findsWidgets);
    expect(find.text('同曝光 · 9:00'), findsOneWidget);
  });

  testWidgets('the strip holds prints of different shapes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(960, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ui.Image portrait = await _card(width: 450, height: 800);
    final TestStrip strip =
        const TestStrip(
              photo: '/photographs/uji.jpg',
              stockId: 'vision3_500t',
              stockLabel: 'VISION3 500T',
              paperId: 'portra_endura',
              paperLabel: 'PORTRA ENDURA',
            )
            .withPrint(
              TestPrint(minutes: 6, tempC: 20, image: card, chart: _chart(6)),
            )
            .withPrint(
              TestPrint(
                minutes: 9,
                tempC: 20,
                image: portrait,
                chart: _chart(9),
              ),
            );

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: strip,
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The step capsule floats over the room, so the work starts below it.
    expect(
      tester.getTopLeft(find.byType(PrintSheet)).dy,
      greaterThanOrEqualTo(56),
    );
    expect(find.text('6:00'), findsWidgets);
    expect(find.text('9:00'), findsWidgets);
  });

  testWidgets('the shelf lies on the bench', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const Catalogue catalogue = Catalogue(
      films: <Stock>[
        Stocks.vision,
        Stock(
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
          TestPrint(minutes: 12, tempC: 20, image: card, chart: _chart(12)),
        );
    await tester.pumpWidget(
      KalloApp(
        catalogue: catalogue,
        strip: strip,
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('materials-card')), findsNothing);
    await tester.tap(find.byKey(const Key('materials-line')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('materials-card')), findsOneWidget);
    expect(find.text('PORTRA 400'), findsOneWidget);

    // A strip with a print on it asks before another box clears it.
    await tester.tap(find.text('PORTRA 400'));
    await tester.pumpAndSettle();
    expect(find.text('换胶片？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('materials-card')), findsOneWidget);
    expect(
      tester
          .widget<KalloChip>(
            find.widgetWithText(KalloChip, 'VISION3 500T'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('the print can be read against the original', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ui.Image original = await _card();
    final TestStrip strip = const TestStrip(photo: '/photographs/uji.jpg')
        .withPrint(
          TestPrint(minutes: 12, tempC: 20, image: card, chart: _chart(12)),
        );
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: strip,
        photograph: original,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('对比'), findsOneWidget);
    expect(find.text('试片'), findsNothing);
    final int before = find.byType(RawImage).evaluate().length;
    await tester.tap(find.text('对比'));
    await tester.pumpAndSettle();
    expect(
      find.byType(RawImage).evaluate().length,
      before + 1,
      reason: 'the original is laid behind the wipe',
    );
    // The wipe names its two sides in the paper's bottom margin.
    expect(find.text('试片'), findsOneWidget);
    expect(find.text('原片'), findsNWidgets(2));

    // The wipe follows the pointer inside the picture, with no divider to grab.
    final Offset centre = tester.getCenter(find.byKey(const Key('bench-print')));
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('对比'));
    await tester.pumpAndSettle();
    expect(find.byType(RawImage).evaluate().length, before);
    expect(find.text('试片'), findsNothing);
  });

  testWidgets('the temperature dial asks for the next step', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    double? chosen;
    const TestStrip strip = TestStrip(photo: '/photographs/uji.jpg', tempC: 20);
    await tester.pumpWidget(
      KalloScope(
        colors: KalloColors.dark,
        pinned: Brightness.dark,
        onPin: (Brightness? _) {},
        child: Localizations(
          locale: const Locale('zh'),
          delegates: const <LocalizationsDelegate<Object>>[
            KalloStrings.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DevelopStage(
              strip: strip,
              catalogue: Catalogue.carried,
              photograph: card,
              onChoosePhoto: () {},
              onFilm: (_) {},
              onPaper: (_) {},
              onTemperature: (double value) => chosen = value,
              onDevelop: (_) async {},
              onRemove: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder stepper = find.byType(KalloStepper);
    expect(stepper, findsOneWidget);
    await tester.tap(find.descendant(of: stepper, matching: find.text('+')));
    expect(chosen, 20.5);
  });

  testWidgets('the window holds at its smallest size', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(960, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('stage-tabs')), findsOneWidget);
  });

  testWidgets('the sides of the window can be put away', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('studio-sidebar')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('studio-sidebar')),
        matching: find.byKey(const Key('sidebar-toggle')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.byKey(const Key('sidebar-toggle'))).dy,
      tester.getCenter(find.byKey(const Key('inspector-toggle'))).dy,
    );
    expect(find.byKey(const Key('develop-inspector')), findsOneWidget);
    expect(find.text('温度  ·  °C'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studio-sidebar')), findsNothing);
    expect(find.byType(StudioSidebar), findsNothing);
    expect(find.byType(DevelopStage), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('studio-sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('inspector-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('温度  ·  °C'), findsNothing);
    expect(find.byType(DevelopStage), findsOneWidget);

    await tester.tap(find.byKey(const Key('inspector-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('温度  ·  °C'), findsOneWidget);
  });

  testWidgets('settings opens on About, without a drawer title', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: const <Print>[],
        initialStep: DarkroomStep.develop,
        locale: const Locale('zh'),
        drawerOpen: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('抽屉'), findsNothing);
    expect(find.text('DRAWER'), findsNothing);
    expect(find.text('Kallo'), findsOneWidget);
    expect(find.text('版本 0.1.0'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('github.com/tsukiyo20/kallo'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('关于')).dy,
      lessThan(tester.getTopLeft(find.text('语言')).dy),
    );

    // The machine's engines are a page of their own: what was detected, and
    // the switch that decides which one a render may use.
    await tester.tap(find.text('渲染'));
    await tester.pumpAndSettle();
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('不可用'), findsOneWidget);
    expect(find.textContaining('核'), findsWidgets);
  });

  testWidgets('the rack opens a print in the room, not over the window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<Print> prints = <Print>[
      for (int i = 0; i < 6; i++)
        Print(
          image: card,
          name: 'uji-$i',
          printNumber: 1,
          film: 'ULTRA MAX 400',
          paper: 'PORTRA ENDURA',
          minutes: 6 + i.toDouble(),
          tempC: 20,
        ),
    ];
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: prints,
        initialChamber: Chamber.rack,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    final Scrollable scroll = tester.widget<Scrollable>(
      find.descendant(
        of: find.byKey(const Key('rack-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scroll.axisDirection, AxisDirection.down);
    expect(find.byKey(const ValueKey<String>('rack-line-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('rack-line-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('rack-print-0')));
    await tester.pumpAndSettle();
    expect(find.byType(PrintViewer), findsOneWidget);
    expect(find.byKey(const Key('print-viewer-close')), findsOneWidget);
    expect(find.byType(StudioSidebar), findsOneWidget);

    // The sidebar's switch still owns the sidebar while a print is open. The
    // viewer is inside the room and must not make that decision for it.
    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(StudioSidebar), findsNothing);
    expect(find.byType(PrintViewer), findsOneWidget);

    await tester.tap(find.byKey(const Key('print-viewer-close')));
    await tester.pumpAndSettle();
    expect(find.byType(PrintViewer), findsNothing);
  });

  testWidgets('the rack is beside the darkroom', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Print print = Print(
      image: card,
      name: 'uji',
      printNumber: 1,
      film: 'ULTRA MAX 400',
      paper: 'PORTRA ENDURA',
      minutes: 9,
      tempC: 20,
    );
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: <Print>[print],
        initialChamber: Chamber.rack,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioSidebar), findsOneWidget);
    expect(find.byType(Rack), findsOneWidget);
    expect(find.byType(StageTabs), findsNothing);
    expect(find.text('晾片架'), findsNWidgets(2));
    expect(find.text('01   ·   9:00'), findsOneWidget);
  });

  testWidgets('the gallery is the other room, and it hangs paper', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Print print = Print(
      image: card,
      name: 'uji',
      printNumber: 1,
      film: 'ULTRA MAX 400',
      paper: 'PORTRA ENDURA',
      minutes: 9,
      tempC: 20,
    );
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: <Print>[print],
        initialChamber: Chamber.gallery,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioSidebar), findsOneWidget);
    expect(find.byType(StageTabs), findsNothing);
    expect(find.byType(PrintSheet), findsOneWidget);
    expect(find.byType(PrintImage), findsOneWidget);
    expect(find.text('放大镜'), findsOneWidget);
    expect(find.text('灯'), findsOneWidget);
  });

  testWidgets('a thousand prints do not build a thousand cards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<Print> prints = <Print>[
      for (int i = 0; i < 1000; i++)
        Print(
          image: card,
          name: 'uji-$i',
          pixels: const Size(1200, 800),
          printNumber: 1,
          film: 'ULTRA MAX 400',
          paper: 'PORTRA ENDURA',
          minutes: 9,
          tempC: 20,
        ),
    ];
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: prints,
        initialChamber: Chamber.rack,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    final int built = find.byType(PrintImage).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(100));
    expect(find.byKey(const ValueKey<String>('rack-line-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('rack-line-40')), findsNothing);
  });

  testWidgets('a thousand prints do not build a thousand sheets', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<Print> prints = <Print>[
      for (int i = 0; i < 1000; i++)
        Print(
          image: card,
          name: 'uji-$i',
          pixels: const Size(1200, 800),
          printNumber: 1,
          film: 'ULTRA MAX 400',
          paper: 'PORTRA ENDURA',
          minutes: 9,
          tempC: 20,
        ),
    ];
    await tester.pumpWidget(
      KalloApp(
        catalogue: Catalogue.carried,
        strip: const TestStrip(photo: '/photographs/uji.jpg'),
        photograph: card,
        prints: prints,
        initialChamber: Chamber.gallery,
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    // The wall's cards are paper: the sheet is what a print hangs as.
    final int built = find.byType(PrintSheet).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(100));
  });
}
