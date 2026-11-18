import 'dart:convert';
import 'dart:io';

import 'model.dart';
import 'settings.dart';
import 'stock.dart';
import 'stock_recipe.dart';
import 'tuning.dart';

/// The recipes on disk: one JSON document per stock, in the app's support
/// folder.
///
/// A recipe is not a setting and not a print record; it is a user document
/// written beside its stock, so the app can lose it without losing anything
/// else and a person can delete it in a file browser. The support folder is the
/// one the settings file and `library.sqlite` already live in:
/// `recipes/<stock-id>.json`.
class RecipeStore {
  const RecipeStore(this.folder);

  final Directory folder;

  /// The store in the app's support folder, or null where the platform has not
  /// given the app one yet.
  static RecipeStore? get support {
    final Directory? directory = Settings.directory;
    if (directory == null) {
      return null;
    }
    return RecipeStore(
      Directory('${directory.path}${Platform.pathSeparator}recipes'),
    );
  }

  File fileFor(String stockId) =>
      File('${folder.path}${Platform.pathSeparator}$stockId.json');

  /// Every recipe on disk, keyed by the stock each document names.
  Future<Map<String, StockRecipe>> readAll() async {
    if (!folder.existsSync()) {
      return const <String, StockRecipe>{};
    }
    final Map<String, StockRecipe> recipes = <String, StockRecipe>{};
    for (final FileSystemEntity entity in folder.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      final StockRecipe? recipe = await _readFile(entity);
      if (recipe != null) {
        recipes[recipe.stock] = recipe;
      }
    }
    return recipes;
  }

  /// One stock's recipe, or null when there is none or it cannot be read.
  ///
  /// A file that is not a `kallo/stock-recipe/1` document is not a recipe; it
  /// is ignored rather than half-applied, because a departure the app cannot
  /// read is not one it can claim the stock admits to.
  Future<StockRecipe?> read(String stockId) => _readFile(fileFor(stockId));

  Future<StockRecipe?> _readFile(File file) async {
    if (!file.existsSync()) {
      return null;
    }
    try {
      final Object? json = jsonDecode(await file.readAsString());
      if (json is Map<String, dynamic>) {
        return StockRecipe.fromJson(json);
      }
      return null;
    } on FormatException catch (error) {
      Model.log('the recipe ${file.path} is not JSON: $error');
      return null;
    } on FileSystemException catch (error) {
      Model.log('the recipe ${file.path} could not be read: $error');
      return null;
    }
  }

  Future<void> write(StockRecipe recipe) async {
    await folder.create(recursive: true);
    await fileFor(recipe.stock).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(recipe.toJson())}\n',
    );
  }

  Future<void> delete(String stockId) async {
    final File file = fileFor(stockId);
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException catch (error) {
      Model.log('the recipe ${file.path} could not be removed: $error');
    }
  }
}

/// The recipes the app knows, in memory and on disk.
///
/// The bench asks for a stock's tuning while it is drawing, so the documents are
/// read once and kept here; [ensureLoaded] is called when the app's support
/// folder is known, and a person moving a control writes through [save]. A
/// stock with no recipe has no entry, and the identity is the default
/// everywhere.
abstract final class StockRecipes {
  static final Map<String, StockRecipe> _recipes = <String, StockRecipe>{};
  static bool _loaded = false;

  /// Read the recipes on disk once. A folder that cannot be read is a console
  /// line, not a dialog: the app renders the file's own numbers either way.
  static Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final RecipeStore? store = RecipeStore.support;
    if (store == null) {
      return;
    }
    try {
      _recipes.addAll(await store.readAll());
    } on Object catch (error) {
      Model.log('the stock recipes could not be read: $error');
    }
  }

  static StockRecipe? of(String stockId) => _recipes[stockId];

  /// Remember a recipe in memory only, for a bench that is drawing while a
  /// control is still in hand. [save] is what makes it a document on disk.
  static void stage(StockRecipe? recipe, {required String stockId}) {
    if (recipe == null || recipe.isEmpty) {
      _recipes.remove(stockId);
    } else {
      _recipes[recipe.stock] = recipe;
    }
  }

  /// Remember a recipe and write it beside the stock it belongs to.
  static Future<void> save(StockRecipe recipe) async {
    _recipes[recipe.stock] = recipe;
    try {
      await RecipeStore.support?.write(recipe);
    } on Object catch (error) {
      Model.log('the recipe for ${recipe.stock} could not be saved: $error');
    }
  }

  /// Remove a stock's recipe, on disk too.
  static Future<void> remove(String stockId) async {
    _recipes.remove(stockId);
    try {
      await RecipeStore.support?.delete(stockId);
    } on Object catch (error) {
      Model.log('the recipe for $stockId could not be removed: $error');
    }
  }

  /// The tuning a stock's recipe applies, if it has one that still fits.
  ///
  /// A stale recipe applies nothing: the identity is the file's own rendering.
  static Tuning tuningFor(
    Stock? stock, {
    List<Measured> model = const <Measured>[],
  }) {
    if (stock == null) {
      return Tuning.identity;
    }
    final StockRecipe? recipe = _recipes[stock.id];
    if (recipe == null) {
      return Tuning.identity;
    }
    return recipe.tuningFor(stock, model: model);
  }

  /// Forget what was read, so another folder or another test starts clean.
  static void reset() {
    _recipes.clear();
    _loaded = false;
  }
}
