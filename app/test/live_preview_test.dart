import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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

    // The shelf lies on the bench, and the chosen stock's record opens.
    await tester.tap(find.byKey(const Key('materials-film')));
    await tester.pumpAndSettle();
    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(
      tester.getCenter(find.byKey(const Key('film-vision3_500t'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();

    // Moving a control writes the recipe; closing the record is what puts the
    // new print on the easel.
    await tester.drag(
      find.byKey(const Key('record-slider-grain.strength')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-done')));
    await tester.pumpAndSettle();
    // The bench waits a moment before rendering the next frame.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      model.opened,
      hasLength(1),
      reason: 'the photograph was not read again for a departure',
    );
    final Tuning applied = model.session!.tunings.last;
    expect(
      applied.grainStrength,
      greaterThan(0.5),
      reason: 'the easel printed the departure the record wrote',
    );
  });
}
