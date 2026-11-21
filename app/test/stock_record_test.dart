import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/strings.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/stock_recipe.dart';
import 'package:kallo/widgets/materials_card.dart';
import 'package:kallo/widgets/stock_record.dart';

/// A window with the app's scope and strings around the sheet.
Widget _window(Widget home) => WidgetsApp(
  color: const Color(0xFF000000),
  locale: const Locale('en'),
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
    colors: KalloColors.light,
    pinned: Brightness.light,
    onPin: (Brightness? _) {},
    child: DefaultTextStyle(
      style: KalloType.body.copyWith(color: KalloColors.light.ink),
      child: child!,
    ),
  ),
  home: home,
);

/// A stock with one measured field, one placeholder field with two controls,
/// and where its numbers came from.
Stock _stock() => Stock(
  id: 'kodak_portra_400',
  short: 'PORTRA 400',
  label: 'KODAK PROFESSIONAL PORTRA 400',
  note: 'Measured: the characteristic curves.',
  stockDigest: 'sha256:6c6f',
  provenance: const Provenance(
    publication: 'E-4050',
    page: '4',
    retrieved: '2026-11-08',
  ),
  measured: const <Measured>[
    Measured(
      field: 'curves',
      claim: 'measured',
      detail: 'page 4, three curves',
      state: 'measured',
      grade: 3,
      source: 'page 4, three curves',
      controls: <Control>[],
    ),
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

/// A colour paper: everything it carries is measured, and the print's two
/// controls are the model's placeholders.
Stock _paper() => const Stock(
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
    Measured(
      field: 'dyes',
      claim: 'measured',
      detail: 'E-4070 page 5',
      state: 'measured',
      grade: 3,
      source: 'E-4070 page 5',
    ),
  ],
);

/// The model's print controls, which belong to the paper's half of the shelf.
const List<Measured> _paperModel = <Measured>[
  Measured(
    field: 'print',
    claim: 'placeholder',
    detail: 'the darkroom\'s choices over a measured curve',
    state: 'placeholder',
    grade: 0,
    source: 'the darkroom\'s choices over a measured curve',
    locked: false,
    appliesTo: 'paper',
    controls: <Control>[
      Control(name: 'contrast', value: 1, min: 0.5, max: 2),
      Control(name: 'black', value: 1, min: 0.5, max: 1.5),
    ],
  ),
];

/// The catalogue's own placeholders for a film.
const List<Measured> _model = <Measured>[
  Measured(
    field: 'halation',
    claim: 'placeholder',
    detail: 'typical',
    state: 'placeholder',
    grade: 0,
    source: 'a modern colour negative in general',
    locked: false,
    controls: <Control>[Control(name: 'strength', value: 1, min: 0, max: 2)],
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 1280,
  double height = 820,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_window(child));
  await tester.pumpAndSettle();
}

String _readout(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key('record-value-$key'))).data!;

Finder _inControl(String key, Finder matching) => find.descendant(
  of: find.byKey(Key('record-control-$key')),
  matching: matching,
);

void main() {
  testWidgets(
    'a placeholder field shows its slider with the catalogue bounds',
    (WidgetTester tester) async {
      await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

      expect(
        find.byKey(const Key('record-slider-grain.strength')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('record-slider-grain.size')), findsOneWidget);
      // Both ends of the interval are the file's, not the app's.
      expect(_inControl('grain.strength', find.text('0.0')), findsOneWidget);
      expect(_inControl('grain.strength', find.text('3.0')), findsOneWidget);
      expect(_inControl('grain.size', find.text('0.5')), findsOneWidget);
      expect(_inControl('grain.size', find.text('2.0')), findsOneWidget);
      // The current value and the file's own sit beside the control.
      expect(_readout(tester, 'grain.strength'), '×1.0');
      expect(
        _inControl('grain.strength', find.text('file ×1.0')),
        findsOneWidget,
      );
    },
  );

  testWidgets('dragging a slider moves the value and writes a recipe', (
    WidgetTester tester,
  ) async {
    StockRecipe? saved;
    await _pump(
      tester,
      StockRecordSheet(
        stock: _stock(),
        model: _model,
        onRecipe: (StockRecipe? recipe) async => saved = recipe,
      ),
    );

    expect(_readout(tester, 'grain.strength'), '×1.0');
    await tester.drag(
      find.byKey(const Key('record-slider-grain.strength')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    final String moved = _readout(tester, 'grain.strength');
    expect(moved, isNot('×1.0'));
    expect(saved, isNotNull);
    expect(saved!.stock, 'kodak_portra_400');
    expect(saved!.stockDigest, 'sha256:6c6f');
    final RecipeOverride? departure = saved!.overrides['grain.strength'];
    expect(departure, isNotNull);
    expect(departure!.value, greaterThan(1));
    expect(departure.against, 'placeholder');
  });

  testWidgets('reset puts the control back to the file\'s value', (
    WidgetTester tester,
  ) async {
    final List<StockRecipe?> saved = <StockRecipe?>[];
    await _pump(
      tester,
      StockRecordSheet(
        stock: _stock(),
        model: _model,
        onRecipe: (StockRecipe? recipe) async => saved.add(recipe),
      ),
    );

    await tester.drag(
      find.byKey(const Key('record-slider-grain.strength')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(_readout(tester, 'grain.strength'), isNot('×1.0'));

    await tester.tap(find.byKey(const Key('record-reset-grain.strength')));
    await tester.pumpAndSettle();

    expect(_readout(tester, 'grain.strength'), '×1.0');
    expect(saved.last, isNull, reason: 'the recipe is gone');
  });

  testWidgets('a measured field is held, with no control and its word', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

    final Finder measured = find.byKey(const Key('record-locked-curves'));
    expect(measured, findsOneWidget);
    expect(
      find.descendant(of: measured, matching: find.text('manufacturer')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: measured,
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'record-control-',
              ),
        ),
      ),
      findsNothing,
    );
    // The placeholder field beside it is still adjustable.
    expect(
      find.byKey(const Key('record-slider-grain.strength')),
      findsOneWidget,
    );
  });

  testWidgets('the model placeholders join the adjustable list', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

    expect(
      find.byKey(const Key('record-field-model-halation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('record-slider-halation.strength')),
      findsOneWidget,
    );
    // One list of what may move, not two sections with their own vocabularies.
    expect(find.text('MODEL DEFAULTS'), findsNothing);
  });

  testWidgets('a paper opens the print controls and holds its measurements', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      StockRecordSheet(stock: _paper(), model: _paperModel),
    );

    expect(
      find.byKey(const Key('record-slider-print.contrast')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('record-slider-print.black')), findsOneWidget);
    expect(find.byKey(const Key('record-locked-curve')), findsOneWidget);
    expect(find.byKey(const Key('record-locked-dyes')), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
  });

  testWidgets('a stale recipe is a review and applies nothing', (
    WidgetTester tester,
  ) async {
    StockRecipe? saved;
    final StockRecipe stale = StockRecipe(
      stock: 'kodak_portra_400',
      stockDigest: 'sha256:older',
      overrides: const <String, RecipeOverride>{
        'grain.strength': RecipeOverride(value: 0.6, against: 'placeholder'),
      },
    );
    await _pump(
      tester,
      StockRecordSheet(
        stock: _stock(),
        model: _model,
        recipe: stale,
        onRecipe: (StockRecipe? recipe) async => saved = recipe,
      ),
    );

    expect(find.byKey(const Key('record-stale')), findsOneWidget);
    expect(find.text('Recipe is stale'), findsOneWidget);
    // The stale review keeps the values for reading, and no slider applies one.
    expect(find.byKey(const Key('record-slider-grain.strength')), findsNothing);
    expect(
      find.byKey(const Key('record-stale-grain.strength')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('record-remove')));
    await tester.pumpAndSettle();
    expect(saved, isNull);
  });

  testWidgets('a stale recipe can keep the values that still fit', (
    WidgetTester tester,
  ) async {
    StockRecipe? saved;
    final StockRecipe stale = StockRecipe(
      stock: 'kodak_portra_400',
      stockDigest: 'sha256:older',
      overrides: const <String, RecipeOverride>{
        'grain.strength': RecipeOverride(value: 0.6, against: 'placeholder'),
      },
    );
    await _pump(
      tester,
      StockRecordSheet(
        stock: _stock(),
        model: _model,
        recipe: stale,
        onRecipe: (StockRecipe? recipe) async => saved = recipe,
      ),
    );

    await tester.tap(find.byKey(const Key('record-keep-fits')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.stockDigest, 'sha256:6c6f');
    expect(saved!.overrides['grain.strength']?.value, 0.6);
    // The review is gone: the file on disk is the file the recipe names again.
    expect(find.byKey(const Key('record-stale')), findsNothing);
    expect(_readout(tester, 'grain.strength'), '×0.6');
  });

  testWidgets('a measured field offers no unlock', (
    WidgetTester tester,
  ) async {
    final Stock stock = Stock(
      id: 'kodak_portra_400',
      short: 'PORTRA 400',
      label: 'KODAK PROFESSIONAL PORTRA 400',
      stockDigest: 'sha256:6c6f',
      measured: const <Measured>[
        Measured(
          field: 'grain',
          claim: 'measured',
          detail: 'a measurement',
          state: 'measured',
          grade: 3,
          source: 'a measurement',
          locked: true,
          advancedUnlock: true,
          controls: <Control>[
            Control(name: 'strength', value: 1, min: 0, max: 3),
          ],
        ),
      ],
    );
    await _pump(tester, StockRecordSheet(stock: stock));

    // The lock is the data's: a measured number is not a slider with a
    // confirmation in front of it.
    expect(find.byKey(const Key('record-slider-grain.strength')), findsNothing);
    expect(find.text('Unlock'), findsNothing);
    expect(find.byKey(const Key('record-locked-grain')), findsOneWidget);
  });

  testWidgets('the record leaves the data sheet out of the page', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

    // The stock's note and provenance are the file's, not the page's: what a
    // person opens here is the controls.
    expect(find.text('Measured: the characteristic curves.'), findsNothing);
    expect(
      find.textContaining('Publication E-4050'),
      findsNothing,
    );
    expect(find.text('DATA AND SOURCES'), findsNothing);
  });

  testWidgets('the chosen stock row carries the record handle', (
    WidgetTester tester,
  ) async {
    Stock? opened;
    final Catalogue catalogue = Catalogue(
      films: <Stock>[_stock()],
      papers: const <Stock>[],
    );
    await _pump(
      tester,
      MaterialsCard(
        catalogue: catalogue,
        filmId: 'kodak_portra_400',
        paperId: null,
        time: '6:00',
        kind: MaterialsKind.film,
        onKind: (MaterialsKind _) {},
        onFilm: (Stock _) {},
        onPaper: (Stock? _) {},
        onRecord: (Stock stock) => opened = stock,
      ),
    );

    // The handle answers the pointer, so the shelf's default picture is the
    // picture it was before the record existed.
    expect(find.text('Parameters'), findsNothing);
    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(
      tester.getCenter(find.byKey(const Key('film-kodak_portra_400'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Parameters'), findsOneWidget);

    await tester.tap(find.text('Parameters'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'kodak_portra_400');
  });

  testWidgets('the sheet closes on its own action', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));
    expect(find.byKey(const Key('record-done')), findsOneWidget);
  });

  test('the record names the evidence in its own words', () {
    const KalloStrings zh = KalloStrings(true);
    // The catalogue's four words, as the record says them: the sheet's own
    // vocabulary, not a sentence about borrowing and measuring.
    expect(zh.claim('measured'), '原厂数据');
    expect(zh.claim('estimate'), '估算值');
    expect(zh.claim('borrowed'), '参照值');
    expect(zh.claim('placeholder'), '默认值');
    expect(zh.claim('none'), '无');
    expect(zh.adjustable, '可调参数');
    expect(zh.lockedParameters, '已锁定');
    expect(zh.filmParameters, '胶片参数');
    expect(zh.paperParameters, '相纸参数');
    expect(zh.controlName('contrast'), '对比度');
    expect(zh.controlName('black'), '黑位');
    expect(zh.field('print'), '冲印');
    expect(zh.departedMeasured, '偏离原厂数据');
  });

  testWidgets('the panel page reports a move before it commits it', (
    WidgetTester tester,
  ) async {
    final List<StockRecipe?> moving = <StockRecipe?>[];
    final List<StockRecipe?> committed = <StockRecipe?>[];
    await _pump(
      tester,
      StockRecordBody(
        stock: _stock(),
        model: _model,
        onChanged: moving.add,
        onRecipe: (StockRecipe? recipe) async => committed.add(recipe),
      ),
    );

    await tester.drag(
      find.byKey(const Key('record-slider-grain.strength')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(moving, isNotEmpty, reason: 'the bench draws the move in hand');
    expect(committed, isNotEmpty, reason: 'the document is written at the end');
    expect(moving.last!.overrides['grain.strength']?.value, greaterThan(1));
    expect(committed.last, moving.last);
  });

  testWidgets('the panel page has no Done of its own', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      StockRecordBody(
        stock: _stock(),
        model: _model,
        recipe: StockRecipe(
          stock: 'kodak_portra_400',
          stockDigest: 'sha256:6c6f',
          overrides: <String, RecipeOverride>{
            'grain.strength': const RecipeOverride(value: 2),
          },
        ),
        showDone: false,
      ),
    );
    expect(find.byKey(const Key('record-done')), findsNothing);
    expect(find.byKey(const Key('record-reset-all')), findsOneWidget);
  });
}
