import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/strings.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/lab/edge_print.dart';
import 'package:kallo/lab/export_format.dart';
import 'package:kallo/lab/model.dart';
import 'package:kallo/lab/print_request.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/views/print_stage.dart';
import 'package:kallo/widgets/button.dart';
import 'package:kallo/widgets/chip.dart';
import 'package:kallo/widgets/export_sheet.dart';
import 'package:kallo/widgets/wall.dart';

/// A window with the app's scope and strings around it, and one route in it.
///
/// The sheet is a route over the window, so it needs what the window gives it:
/// a `Navigator`, the localizations and the colours. `WidgetsApp` is what makes
/// that, and it is the same one the app itself uses.
Widget _window(Widget home) => WidgetsApp(
  color: const Color(0xFF000000),
  locale: const Locale('zh'),
  supportedLocales: KalloStrings.supported,
  localizationsDelegates: const <LocalizationsDelegate<Object>>[
    KalloStrings.delegate,
    DefaultWidgetsLocalizations.delegate,
  ],
  pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
      PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
        ) => builder(context),
      ),
  builder: (BuildContext context, Widget? child) => KalloScope(
    colors: KalloColors.dark,
    pinned: Brightness.dark,
    onPin: (Brightness? _) {},
    child: DefaultTextStyle(
      style: KalloType.body.copyWith(color: KalloColors.dark.ink),
      child: child!,
    ),
  ),
  home: home,
);

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A picture for the bench, drawn instead of rendered: the print's preview is
/// the model's business, and this test is about the controls around it.
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
  return recorder.endRecording().toImage(width, height);
}

/// A model that hands the bench the card instead of rendering: the test is
/// about the edge the print is given, not about the model's pixels.
class _CardModel extends ProcessModel {
  _CardModel(this.card) : super('');

  final ui.Image card;

  @override
  bool get available => true;

  @override
  Future<PreviewSession?> openPreview({
    required File photograph,
    required String stock,
    required String paper,
    required double tempC,
    required int width,
    bool spectral = false,
  }) async => _CardPreview(card);
}

class _CardPreview implements PreviewSession {
  _CardPreview(this._image);

  final ui.Image _image;

  @override
  Future<ui.Image> frame({
    required double minutes,
    double? balanceFrom,
    double printEv = 0,
    String filters = '',
    String? heatGlass,
  }) async => _image.clone();

  @override
  void dispose() {}
}

/// Opens the export sheet the way the print stage does, and keeps what it
/// returned.
class _SheetHost extends StatefulWidget {
  const _SheetHost();

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  ExportOptions? result;
  bool cancelled = false;

  Future<void> _open() async {
    final KalloStrings s = KalloStrings.of(context);
    final ExportOptions? options = await showExportSheet(
      context,
      title: s.printAction,
      confirm: s.printAction,
      sizes: <ExportSize>[
        ExportSize(s.originalSize, null),
        const ExportSize('6000 px', 6000),
        const ExportSize('4000 px', 4000),
      ],
      formats: const <ExportFormat>[ExportFormat.png, ExportFormat.jpeg],
      initialFormat: ExportFormat.png,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      result = options;
      cancelled = options == null;
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('open-sheet'),
    behavior: HitTestBehavior.opaque,
    onTap: _open,
    child: const ColoredBox(color: Color(0xFF111111)),
  );
}

Future<_SheetHostState> _openSheet(WidgetTester tester) async {
  _size(tester);
  await tester.pumpWidget(_window(const _SheetHost()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-sheet')));
  await tester.pumpAndSettle();
  return tester.state<_SheetHostState>(find.byType(_SheetHost));
}

/// A strip with one test print, which is what makes the print button live.
TestStrip _strip() => const TestStrip(
  photo: '/photographs/uji.jpg',
  stockId: 'vision3_500t',
  stockLabel: 'VISION3 500T',
  paperId: 'portra_endura',
  paperLabel: 'PORTRA ENDURA',
).withPrint(const TestPrint(minutes: 9, tempC: 20));

/// The bench's edge painter, when the print carries one.
final Finder _edgePainter = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CustomPaint && widget.painter is EdgePrintPainter,
);

EdgePrintPainter _paintedEdge(WidgetTester tester) =>
    tester.widget<CustomPaint>(_edgePainter).painter! as EdgePrintPainter;

/// Pumps the bench until its preview has been drawn from the model.
Future<void> _settlePreview(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    if (find.byType(RawImage).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  fail('the bench never drew a preview');
}

/// The print stage on the desktop bench, with the model answering with a card.
Future<Directory> _pumpBench(
  WidgetTester tester, {
  required Future<void> Function(PrintRequest request) onPrint,
}) async {
  _size(tester);
  final Directory folder = Directory.systemTemp.createTempSync('kallo-print-');
  addTearDown(() => folder.deleteSync(recursive: true));
  await tester.pumpWidget(
    _window(
      PrintStage(
        strip: _strip(),
        paperName: 'PORTRA ENDURA',
        exports: folder,
        filmName: 'KODAK ULTRA MAX 400',
        filmProcess: FilmProcess.negative,
        onPrint: onPrint,
        onGoDevelop: () {},
        onGoRack: () {},
      ),
    ),
  );
  await tester.pump();
  await _settlePreview(tester);
  return folder;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image card;

  setUpAll(() async {
    card = await _card();
    Model.useLinked(_CardModel(card));
  });

  tearDownAll(() {
    card.dispose();
  });

  testWidgets('the sheet asks for a size and a format, and nothing else', (
    WidgetTester tester,
  ) async {
    final _SheetHostState host = await _openSheet(tester);

    expect(find.byKey(const Key('export-confirm')), findsOneWidget);
    expect(find.text('尺寸'), findsOneWidget);
    expect(find.text('原尺寸'), findsOneWidget);
    expect(find.text('6000 px'), findsOneWidget);
    expect(find.text('4000 px'), findsOneWidget);
    expect(find.text('格式'), findsOneWidget);
    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('JPEG'), findsOneWidget);

    // The edge is a printing choice made on the bench, not a switch in the
    // sheet: the sheet only says how the file is written.
    expect(find.text('边框'), findsNothing);
    expect(find.text('保留片边'), findsNothing);

    await tester.tap(find.byKey(const Key('export-confirm')));
    await tester.pumpAndSettle();
    expect(host.result, isNotNull);
    expect(host.result!.size, isNull);
    expect(host.result!.format, ExportFormat.png);
  });

  testWidgets('choosing a size and a format returns them', (
    WidgetTester tester,
  ) async {
    final _SheetHostState host = await _openSheet(tester);

    await tester.tap(find.text('6000 px'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPEG'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-confirm')));
    await tester.pumpAndSettle();

    expect(host.result, isNotNull);
    expect(host.result!.size, 6000);
    expect(host.result!.format, ExportFormat.jpeg);
  });

  testWidgets('cancelling the sheet keeps no print at all', (
    WidgetTester tester,
  ) async {
    final _SheetHostState host = await _openSheet(tester);

    await tester.tap(find.byKey(const Key('export-cancel')));
    await tester.pumpAndSettle();
    expect(host.cancelled, isTrue);
    expect(host.result, isNull);
    expect(find.byKey(const Key('export-confirm')), findsNothing);
  });

  testWidgets('the bench offers four edges, and none is the default', (
    WidgetTester tester,
  ) async {
    await _pumpBench(tester, onPrint: (_) async {});

    // The panel says what the print can carry, in the film's own vocabulary.
    expect(find.text('边框'), findsOneWidget);
    for (final BorderTemplate template in BorderTemplate.values) {
      expect(find.byKey(Key('border-${template.name}')), findsOneWidget);
    }
    expect(
      tester.widget<KalloChip>(find.byKey(const Key('border-none'))).selected,
      isTrue,
    );
    for (final BorderTemplate template in <BorderTemplate>[
      BorderTemplate.warm,
      BorderTemplate.neutral,
      BorderTemplate.white,
    ]) {
      expect(
        tester
            .widget<KalloChip>(find.byKey(Key('border-${template.name}')))
            .selected,
        isFalse,
      );
    }

    // With no edge chosen the bench shows the picture on its paper, not a
    // bordered print.
    expect(_edgePainter, findsNothing);
  });

  testWidgets('choosing an edge paints it on the bench and prints it in', (
    WidgetTester tester,
  ) async {
    PrintRequest? asked;
    await _pumpBench(
      tester,
      onPrint: (PrintRequest request) async {
        asked = request;
      },
    );

    // Each template changes the picture's shape and the painter under it.
    for (final BorderTemplate template in <BorderTemplate>[
      BorderTemplate.warm,
      BorderTemplate.neutral,
      BorderTemplate.white,
    ]) {
      await tester.tap(find.byKey(Key('border-${template.name}')));
      await tester.pump();
      expect(
        tester
            .widget<KalloChip>(find.byKey(Key('border-${template.name}')))
            .selected,
        isTrue,
      );
      expect(_edgePainter, findsOneWidget);
      expect(_paintedEdge(tester).template, template);
    }

    // Back to none: the picture without an edge.
    await tester.tap(find.byKey(const Key('border-none')));
    await tester.pump();
    expect(_edgePainter, findsNothing);

    // Chosen again, and printed: the request carries the template.
    await tester.tap(find.byKey(const Key('border-warm')));
    await tester.pump();
    await tester.tap(find.widgetWithText(KalloButton, '印相'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-confirm')));
    await tester.pumpAndSettle();

    expect(asked, isNotNull);
    expect(asked!.border, BorderTemplate.warm);

    // The printed toast owns a timer; let it pass before the tree goes.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the bench keeps the print\'s paper shape for every edge', (
    WidgetTester tester,
  ) async {
    await _pumpBench(tester, onPrint: (_) async {});
    final Size plain = tester.getSize(find.byType(PrintSheet));

    await tester.tap(find.byKey(const Key('border-warm')));
    await tester.pump();

    // A bordered print is the picture plus its rebate: the sheet does not get
    // narrower in proportion, it gets taller for the same paper.
    final Size bordered = tester.getSize(find.byType(PrintSheet));
    expect(
      bordered.width / bordered.height,
      lessThan(plain.width / plain.height),
    );
  });
}
