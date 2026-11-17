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

/// The catalogue's own placeholders, once, in their own section.
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

  testWidgets('a measured field has no control and says why', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

    final Finder measured = find.byKey(const Key('record-field-stock-curves'));
    expect(measured, findsOneWidget);
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
    expect(
      find.descendant(
        of: measured,
        matching: find.text('locked · the file calls this measured'),
      ),
      findsOneWidget,
    );
    // The placeholder field beside it is still adjustable.
    expect(
      find.byKey(const Key('record-slider-grain.strength')),
      findsOneWidget,
    );
  });

  testWidgets('the model placeholders render once, as their own section', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

    expect(find.byKey(const Key('record-model')), findsOneWidget);
    expect(find.text("THE MODEL'S PLACEHOLDERS"), findsOneWidget);
    expect(
      find.byKey(const Key('record-field-model-halation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('record-slider-halation.strength')),
      findsOneWidget,
    );
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

  testWidgets('an advanced unlock asks before a measured field moves', (
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

    // Locked: no slider until the departure is confirmed.
    expect(find.byKey(const Key('record-slider-grain.strength')), findsNothing);
    await tester.tap(find.byKey(const Key('record-unlock-stock-grain')));
    await tester.pumpAndSettle();
    expect(find.text('Depart from measured data?'), findsOneWidget);

    await tester.tap(find.text('Adjust anyway'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('record-slider-grain.strength')),
      findsOneWidget,
    );
  });

  testWidgets('an advanced unlock is remembered by the recipe', (
    WidgetTester tester,
  ) async {
    const Stock measured = Stock(
      id: 'kodak_portra_400',
      short: 'PORTRA 400',
      label: 'KODAK PROFESSIONAL PORTRA 400',
      stockDigest: 'sha256:6c6f',
      measured: <Measured>[
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
    StockRecipe? saved;
    await _pump(
      tester,
      StockRecordSheet(
        stock: measured,
        onRecipe: (StockRecipe? recipe) async => saved = recipe,
      ),
    );
    await tester.tap(find.byKey(const Key('record-unlock-stock-grain')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjust anyway'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('record-slider-grain.strength')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.overrides['grain.strength']?.against, 'measured');

    // Reopen the record with the recipe it wrote: the departure it was
    // confirmed for is still a control, at the value that was chosen.
    await tester.pumpWidget(
      _window(StockRecordSheet(stock: measured, recipe: saved)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('record-slider-grain.strength')),
      findsOneWidget,
    );
    expect(_readout(tester, 'grain.strength'), isNot('×1.0'));
  });

  testWidgets('the record shows the label, the note and its provenance', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));

    expect(find.text('KODAK PROFESSIONAL PORTRA 400'), findsOneWidget);
    expect(find.text('Measured: the characteristic curves.'), findsOneWidget);
    expect(
      find.text('Publication E-4050   ·   page 4   ·   read 2026-11-08'),
      findsOneWidget,
    );
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
    expect(find.text('Record'), findsNothing);
    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(
      tester.getCenter(find.byKey(const Key('film-kodak_portra_400'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Record'), findsOneWidget);

    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'kodak_portra_400');
  });

  testWidgets('the sheet closes on its own action', (
    WidgetTester tester,
  ) async {
    await _pump(tester, StockRecordSheet(stock: _stock(), model: _model));
    expect(find.byKey(const Key('record-done')), findsOneWidget);
  });
}
