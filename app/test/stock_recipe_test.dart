import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/recipe_store.dart';
import 'package:kallo/lab/settings.dart';
import 'package:kallo/lab/stock.dart';
import 'package:kallo/lab/stock_recipe.dart';
import 'package:kallo/lab/tuning.dart';

/// A stock with a placeholder grain and a measured curve: the two shapes a
/// record's fields come in.
Stock _stock({String digest = 'sha256:6c6f'}) => Stock(
  id: 'kodak_portra_400',
  short: 'PORTRA 400',
  label: 'KODAK PROFESSIONAL PORTRA 400',
  stockDigest: digest,
  measured: const <Measured>[
    Measured(
      field: 'curves',
      claim: 'measured',
      detail: 'page 4',
      state: 'measured',
      grade: 3,
      source: 'page 4',
      controls: <Control>[],
    ),
    Measured(
      field: 'grain',
      claim: 'placeholder',
      detail: 'the placeholder',
      state: 'placeholder',
      grade: 0,
      source: 'the placeholder',
      locked: false,
      controls: <Control>[
        Control(name: 'strength', value: 1, min: 0, max: 3),
        Control(name: 'size', value: 1, min: 0.5, max: 2),
      ],
    ),
  ],
);

StockRecipe _recipe({String digest = 'sha256:6c6f'}) => StockRecipe(
  stock: 'kodak_portra_400',
  stockDigest: digest,
  overrides: const <String, RecipeOverride>{
    'grain.strength': RecipeOverride(value: 0.6, against: 'placeholder'),
  },
);

void main() {
  test('a recipe round-trips through its JSON document', () async {
    final Directory folder = Directory.systemTemp.createTempSync(
      'kallo-recipes-',
    );
    addTearDown(() => folder.deleteSync(recursive: true));
    final RecipeStore store = RecipeStore(folder);
    final StockRecipe recipe = StockRecipe(
      stock: 'kodak_portra_400',
      stockDigest: 'sha256:6c6f',
      overrides: const <String, RecipeOverride>{
        'grain.strength': RecipeOverride(value: 0.6, against: 'placeholder'),
        'dyes.saturation': RecipeOverride(value: 0.0, against: 'borrowed'),
      },
      model: const <String, RecipeOverride>{
        'halation.strength': RecipeOverride(value: 0.8, against: 'placeholder'),
      },
    );

    await store.write(recipe);

    final File file = File(
      '${folder.path}${Platform.pathSeparator}kodak_portra_400.json',
    );
    expect(file.existsSync(), isTrue);
    // The document is the schema's, not a private shape: a person can open it.
    final String text = file.readAsStringSync();
    expect(text, contains('"schema": "kallo/stock-recipe/1"'));
    expect(text, contains('"grain.strength"'));

    expect(await store.read('kodak_portra_400'), recipe);
    expect((await store.readAll())['kodak_portra_400'], recipe);

    await store.delete('kodak_portra_400');
    expect(file.existsSync(), isFalse);
    expect(await store.read('kodak_portra_400'), isNull);
  });

  test('a document that is not a recipe is not read as one', () async {
    final Directory folder = Directory.systemTemp.createTempSync(
      'kallo-recipes-',
    );
    addTearDown(() => folder.deleteSync(recursive: true));
    final RecipeStore store = RecipeStore(folder);
    await store.folder.create(recursive: true);
    File(store.fileFor('kodak_portra_400').path).writeAsStringSync('{');
    expect(await store.read('kodak_portra_400'), isNull);
    File(store.fileFor('fuji_c200').path)
        .writeAsStringSync('{"schema":"other"}');
    expect(await store.read('fuji_c200'), isNull);
  });

  test(
    'a recipe written against another digest is stale and applies nothing',
    () {
      final Stock stock = _stock();
      final StockRecipe recipe = _recipe(digest: 'sha256:0000');

      final RecipeReview review = recipe.review(stock);
      expect(review.stale, isTrue);
      expect(review.tuning, Tuning.identity);
      expect(recipe.tuningFor(stock), Tuning.identity);
      // The departure and the verdict it was written against are kept, so the
      // review can say what was moved even though nothing is applied.
      expect(review.changes.single.override.value, 0.6);
      expect(review.changes.single.override.against, 'placeholder');
      expect(review.changes.single.state, 'placeholder');
    },
  );

  test('a recipe that names the current digest applies its departures', () {
    final Stock stock = _stock();
    expect(_recipe().tuningFor(stock), const Tuning(grainStrength: 0.6));
  });

  test('a departure on a field that is measured now no longer fits', () {
    final Stock measured = Stock(
      id: 'kodak_portra_400',
      short: 'PORTRA 400',
      label: 'KODAK PROFESSIONAL PORTRA 400',
      stockDigest: 'sha256:6c6f',
      measured: const <Measured>[
        Measured(
          field: 'grain',
          claim: 'measured',
          detail: 'a measurement arrived',
          state: 'measured',
          grade: 3,
          source: 'a measurement arrived',
          controls: <Control>[
            Control(name: 'strength', value: 1, min: 0, max: 3),
          ],
        ),
      ],
    );
    final RecipeReview review = _recipe().review(measured);
    expect(review.stale, isFalse);
    expect(review.changes.single.fits, isFalse);
    expect(review.changes.single.gradeChanged, isTrue);
    expect(review.noLongerFit.single.key, 'grain.strength');
    expect(review.tuning, Tuning.identity);
  });

  test(
    'a measured field needs the advanced unlock, and the departure applies',
    () {
      const Measured grain = Measured(
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
      );
      final Stock stock = Stock(
        id: 'kodak_portra_400',
        short: 'PORTRA 400',
        label: 'KODAK PROFESSIONAL PORTRA 400',
        stockDigest: 'sha256:6c6f',
        measured: const <Measured>[grain],
      );
      final StockRecipe recipe = StockRecipe(
        stock: 'kodak_portra_400',
        stockDigest: 'sha256:6c6f',
        overrides: const <String, RecipeOverride>{
          'grain.strength': RecipeOverride(value: 0.6, against: 'measured'),
        },
      );
      final RecipeReview review = recipe.review(stock);
      expect(
        review.changes.single.fits,
        isFalse,
        reason: 'the field is measured',
      );
      expect(review.changes.single.confirmedDeparture, isTrue);
      expect(recipe.tuningFor(stock), const Tuning(grainStrength: 0.6));
      // A stale recipe applies nothing, an explicit departure included.
      expect(recipe.rebind('sha256:older').tuningFor(stock), Tuning.identity);
    },
  );

  test('a departure from measured data is refused without the unlock', () {
    const Measured grain = Measured(
      field: 'grain',
      claim: 'measured',
      detail: 'a measurement',
      state: 'measured',
      grade: 3,
      source: 'a measurement',
      locked: true,
      controls: <Control>[Control(name: 'strength', value: 1, min: 0, max: 3)],
    );
    final Stock stock = Stock(
      id: 'kodak_portra_400',
      short: 'PORTRA 400',
      label: 'KODAK PROFESSIONAL PORTRA 400',
      stockDigest: 'sha256:6c6f',
      measured: const <Measured>[grain],
    );
    const StockRecipe recipe = StockRecipe(
      stock: 'kodak_portra_400',
      stockDigest: 'sha256:6c6f',
      overrides: <String, RecipeOverride>{
        'grain.strength': RecipeOverride(value: 0.6, against: 'measured'),
      },
    );
    expect(recipe.tuningFor(stock), Tuning.identity);
  });

  test('an unknown control never applies', () {
    final StockRecipe recipe = StockRecipe(
      stock: 'kodak_portra_400',
      stockDigest: 'sha256:6c6f',
      overrides: const <String, RecipeOverride>{
        'curves.slope': RecipeOverride(value: 2, against: 'measured'),
        'grain.nonsense': RecipeOverride(value: 2, against: 'placeholder'),
      },
    );
    final RecipeReview review = recipe.review(_stock());
    expect(review.noLongerFit, hasLength(2));
    expect(review.tuning, Tuning.identity);
  });

  test('the model section is reviewed against the catalogue model fields', () {
    final StockRecipe recipe = StockRecipe(
      stock: 'kodak_portra_400',
      stockDigest: 'sha256:6c6f',
      model: const <String, RecipeOverride>{
        'halation.strength': RecipeOverride(value: 0.8, against: 'placeholder'),
      },
    );
    final Measured halation = Measured(
      field: 'halation',
      claim: 'placeholder',
      detail: '',
      state: 'placeholder',
      grade: 0,
      source: '',
      locked: false,
      controls: const <Control>[
        Control(name: 'strength', value: 1, min: 0, max: 2),
      ],
    );
    expect(
      recipe.tuningFor(_stock(), model: <Measured>[halation]),
      const Tuning(halationStrength: 0.8),
    );
    expect(
      recipe
          .review(_stock(), model: <Measured>[halation])
          .changes
          .single
          .inModel,
      isTrue,
    );
  });

  test('the app remembers a recipe in the support folder', () async {
    final Directory support = Directory.systemTemp.createTempSync(
      'kallo-support-',
    );
    addTearDown(() {
      Settings.useDirectory(null);
      StockRecipes.reset();
      support.deleteSync(recursive: true);
    });
    Settings.useDirectory(support);
    StockRecipes.reset();
    await StockRecipes.ensureLoaded();

    final Stock stock = _stock();
    expect(StockRecipes.tuningFor(stock), Tuning.identity);

    await StockRecipes.save(_recipe());
    expect(
      File(
        '${support.path}${Platform.pathSeparator}recipes'
        '${Platform.pathSeparator}kodak_portra_400.json',
      ).existsSync(),
      isTrue,
    );
    expect(StockRecipes.of(stock.id), _recipe());
    expect(StockRecipes.tuningFor(stock), const Tuning(grainStrength: 0.6));

    // The catalogue moved on: the values are kept but nothing is applied.
    expect(
      StockRecipes.tuningFor(_stock(digest: 'sha256:aaaa')),
      Tuning.identity,
    );

    await StockRecipes.remove(stock.id);
    expect(StockRecipes.of(stock.id), isNull);
    expect(StockRecipes.tuningFor(stock), Tuning.identity);
  });
}
