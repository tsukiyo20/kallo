import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/strings.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/lab/model.dart';
import 'package:kallo/lab/recipe_store.dart';
import 'package:kallo/lab/settings.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/stock_recipe.dart';
import 'package:kallo/lab/strip.dart';
import 'package:kallo/lab/tuning.dart';
import 'package:kallo/views/develop_stage.dart';

/// A window with a route and the app's scope, so the record can be opened.
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

/// The film the strip is one of, with one placeholder field that exposes the
/// grain controls a recipe can move.
Stock _film() => const Stock(
  id: 'vision3_500t',
  short: 'VISION3 500T',
  label: 'KODAK VISION3 500T 5219/7219, ECN-2',
  process: FilmProcess.negative,
  stockDigest: 'sha256:1234',
  measured: <Measured>[
    Measured(
      field: 'grain',
      claim: 'placeholder',
      detail: 'a compiled placeholder',
      state: 'placeholder',
      grade: 0,
      source: 'a compiled placeholder',
      locked: false,
      controls: <Control>[
        Control(name: 'strength', value: 1, min: 0, max: 3),
        Control(name: 'size', value: 1, min: 0.5, max: 2),
      ],
    ),
  ],
);

/// The paper the strip is printed on, all of whose measurements are locked.
const Stock _paper = Stock(
  id: 'endura_premier',
  short: 'ENDURA PREMIER',
  label: 'KODAK PROFESSIONAL ENDURA Premier Paper, RA-4',
  emulsion: PaperEmulsion.colour,
  stockDigest: 'sha256:70d4',
  measured: <Measured>[
    Measured(
      field: 'curve',
      claim: 'measured',
      detail: 'E-4070 page 4',
      state: 'measured',
      grade: 3,
      source: 'E-4070 page 4',
    ),
  ],
);

/// The model's print controls, which open on the paper's record.
const Measured _print = Measured(
  field: 'print',
  claim: 'placeholder',
  detail: 'the darkroom\'s choices',
  state: 'placeholder',
  grade: 0,
  source: 'the darkroom\'s choices',
  locked: false,
  appliesTo: 'paper',
  controls: <Control>[
    Control(name: 'contrast', value: 1, min: 0.5, max: 2),
    Control(name: 'black', value: 1, min: 0.5, max: 1.5),
  ],
);

final Catalogue _catalogue = Catalogue(films: <Stock>[_film()]);

/// A one-pixel picture; the test is about which recipe is asked for, not about
/// the pixels the model would make.
Future<ui.Image> _card() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 64, 44),
    ui.Paint()..color = const ui.Color(0xFFB9B2A4),
  );
  return recorder.endRecording().toImage(64, 44);
}

/// A preview session that remembers every recipe it was pointed at.
class _Session implements PreviewSession {
  _Session(this.picture);

  final ui.Image picture;
  final List<Tuning> tunings = <Tuning>[];

  @override
  Future<ui.Image> frame({
    required double minutes,
    double? balanceFrom,
    double printEv = 0,
    String filters = '',
    String? heatGlass,
  }) async => picture.clone();

  @override
  Future<void> setMaterials({
    required String film,
    required String paper,
    required double tempC,
  }) async {}

  @override
  Future<void> setTuning({required Tuning tuning}) async => tunings.add(tuning);

  @override
  void dispose() {}
}

/// The linked model, with a session that holds a picture instead of rendering.
class _Model extends ProcessModel {
  _Model(this.picture) : super('');

  final ui.Image picture;
  final List<Tuning> opened = <Tuning>[];
  _Session? session;

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
    Tuning tuning = Tuning.identity,
  }) async {
    opened.add(tuning);
    return session = _Session(picture);
  }
}

StockRecipe _recipe({required double grainStrength}) => StockRecipe(
  stock: 'vision3_500t',
  stockDigest: 'sha256:1234',
  overrides: <String, RecipeOverride>{
    'grain.strength': RecipeOverride(
      value: grainStrength,
      against: 'placeholder',
    ),
  },
);

/// Pump the bench until the easel holds a preview, or say that it never came.
Future<void> _settlePreview(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    if (find.byType(RawImage).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  fail('the easel never held a preview');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  late ui.Image card;

  // File I/O and the picture belong outside the fake clock `testWidgets` runs:
  // the recipe is on disk before the bench opens, as it is in the app.
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('kallo-recipes-');
    Settings.useDirectory(folder);
    StockRecipes.reset();
    await StockRecipes.save(_recipe(grainStrength: 0.5));
    await StockRecipes.ensureLoaded();
    card = await _card();
  });

  tearDown(() async {
    Settings.useDirectory(null);
    StockRecipes.reset();
    await folder.delete(recursive: true);
  });

  testWidgets('the easel previews the recipe the stock holds', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final _Model model = _Model(card);
    Model.useLinked(model);

    await tester.pumpWidget(
      _window(
        DevelopStage(
          strip: const TestStrip(photo: '/photographs/uji.jpg'),
          catalogue: _catalogue,
          onChoosePhoto: () {},
          onFilm: (Stock _) {},
          onPaper: (Stock? _) {},
          onTemperature: (double _) {},
          onDevelop: (_, {onProgress}) async {},
          onRemove: (_) async {},
        ),
      ),
    );
    await _settlePreview(tester);

    expect(model.opened, hasLength(1));
    expect(
      model.opened.single.grainStrength,
      0.5,
      reason: 'the session opens on the recipe, not on the file',
    );
    expect(model.session!.tunings.last.grainStrength, 0.5);
  });

  testWidgets('a departure written on the record is on the easel', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final _Model model = _Model(card);
    Model.useLinked(model);

    await tester.pumpWidget(
      _window(
        DevelopStage(
          strip: const TestStrip(photo: '/photographs/uji.jpg'),
          catalogue: _catalogue,
          onChoosePhoto: () {},
          onFilm: (Stock _) {},
          onPaper: (Stock? _) {},
          onTemperature: (double _) {},
          onDevelop: (_, {onProgress}) async {},
          onRemove: (_) async {},
        ),
      ),
    );
    await _settlePreview(tester);
    expect(model.session!.tunings.last.grainStrength, 0.5);

    // The record has a page in the instrument panel, one tap from the bench.
    expect(find.byKey(const Key('film-record-entry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('film-record-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-panel-body')), findsOneWidget);

    // The easel stays beside the controls: moving one prints again without
    // closing the record.
    final int before = model.session!.tunings.length;
    await tester.drag(
      find.byKey(const Key('record-slider-grain.strength')),
      const Offset(120, 0),
    );
    // The bench waits a moment before rendering the next frame.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      model.opened,
      hasLength(1),
      reason: 'the photograph was not read again for a departure',
    );
    expect(
      model.session!.tunings.length,
      greaterThan(before),
      reason: 'the easel printed while the control was still moving',
    );
    final Tuning applied = model.session!.tunings.last;
    expect(
      applied.grainStrength,
      greaterThan(0.5),
      reason: 'the easel printed the departure the record wrote',
    );
    // The panel closes from its own header, and the page the record replaced
    // comes back.
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-panel-body')), findsNothing);
    expect(find.byKey(const Key('film-record-entry')), findsOneWidget);
  });

  testWidgets('the paper\'s controls reach the easel beside the film\'s', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Catalogue catalogue = Catalogue(
      films: <Stock>[_film()],
      papers: const <Stock>[_paper],
      model: const <Measured>[_print],
    );
    final _Model model = _Model(card);
    Model.useLinked(model);

    await tester.pumpWidget(
      _window(
        DevelopStage(
          strip: const TestStrip(
            photo: '/photographs/uji.jpg',
            paperId: 'endura_premier',
          ),
          catalogue: catalogue,
          onChoosePhoto: () {},
          onFilm: (Stock _) {},
          onPaper: (Stock? _) {},
          onTemperature: (double _) {},
          onDevelop: (_, {onProgress}) async {},
          onRemove: (_) async {},
        ),
      ),
    );
    await _settlePreview(tester);
    // The film's recipe was written before the bench opened; the paper has none.
    expect(model.session!.tunings.last.grainStrength, 0.5);
    expect(model.session!.tunings.last.printContrast, 1.0);

    // The panel offers the paper's record beside the film's.
    expect(find.byKey(const Key('paper-record-entry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paper-record-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-panel-body')), findsOneWidget);
    expect(find.text('相纸参数'), findsOneWidget);

    // The paper's measured curve is held; the print's contrast is a control.
    expect(find.byKey(const Key('record-locked-curve')), findsOneWidget);
    expect(
      find.byKey(const Key('record-slider-print.contrast')),
      findsOneWidget,
    );
    final int before = model.session!.tunings.length;
    await tester.drag(
      find.byKey(const Key('record-slider-print.contrast')),
      const Offset(120, 0),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(model.opened, hasLength(1));
    expect(model.session!.tunings.length, greaterThan(before));
    expect(model.session!.tunings.last.printContrast, greaterThan(1));
    // The two documents are one print: the film's departure did not go away.
    expect(model.session!.tunings.last.grainStrength, 0.5);
  });
}
