import 'stock.dart';
import 'tuning.dart';

/// One control a stock recipe moved, and the verdict its field carried when it
/// was moved.
///
/// A user edit is not a stock file: the `.kalofilm` and `.kalopaper` files stay
/// read-only data, and this is the departure written beside them. `against` is
/// the word the catalogue gave the field at the time, so a later review can say
/// *this was a placeholder when you moved it; it is measured now*.
class RecipeOverride {
  const RecipeOverride({required this.value, this.against = ''});

  /// The scalar the control was moved to.
  final double value;

  /// The verdict the field carried when the departure was written.
  final String against;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'value': value,
    if (against.isNotEmpty) 'against': against,
  };

  static RecipeOverride? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final Object? value = json['value'];
    if (value is! num) {
      return null;
    }
    return RecipeOverride(
      value: value.toDouble(),
      against: json['against'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeOverride &&
          other.value == value &&
          other.against == against;

  @override
  int get hashCode => Object.hash(value, against);

  @override
  String toString() => 'RecipeOverride($value, against: $against)';
}

/// The module a record field is named by in a control key.
///
/// The catalogue calls a film's modulation-transfer field `mtf`; the model's
/// control for it is `blur.sharpness`, because the scalar belongs to the blur
/// module. This is the one rename between the catalogue's field names and the
/// model's control keys; every other module keeps its field's name. It is the
/// same mapping `kallo-core`'s recipe reader makes, and it is a vocabulary,
/// not a rule about what may move.
String moduleOf(String field) => field == 'mtf' ? 'blur' : field;

/// The catalogue's control key for one field's control: `<module>.<control>`.
String controlKey(Measured field, Control control) =>
    '${moduleOf(field.field)}.${control.name}';

/// The field a control key names, when the record has it.
///
/// A field may appear more than once — a mixed line keeps its parts on their
/// own rows — so the row that actually carries this control is preferred.
Measured? fieldForKey(List<Measured> fields, String key) {
  final int dot = key.indexOf('.');
  if (dot <= 0 || dot == key.length - 1) {
    return null;
  }
  final String module = key.substring(0, dot) == 'blur'
      ? 'mtf'
      : key.substring(0, dot);
  final String name = key.substring(dot + 1);
  Measured? fallback;
  for (final Measured field in fields) {
    if (field.field != module) {
      continue;
    }
    if (field.controls.any((Control control) => control.name == name)) {
      return field;
    }
    fallback ??= field;
  }
  return fallback;
}

/// The control a key names, when the record has it.
Control? controlForKey(List<Measured> fields, String key) {
  final int dot = key.indexOf('.');
  if (dot <= 0 || dot == key.length - 1) {
    return null;
  }
  final String module = key.substring(0, dot) == 'blur'
      ? 'mtf'
      : key.substring(0, dot);
  final String name = key.substring(dot + 1);
  for (final Measured field in fields) {
    if (field.field != module) {
      continue;
    }
    for (final Control control in field.controls) {
      if (control.name == name) {
        return control;
      }
    }
  }
  return null;
}

/// The departures a person asked for on one stock, written beside it.
///
/// A recipe is a JSON document — `kallo/stock-recipe/1` — naming the stock and
/// the packed file's digest it was written against:
///
/// ```json
/// {
///   "schema": "kallo/stock-recipe/1",
///   "stock": "kodak_portra_400",
///   "stock_digest": "sha256:…",
///   "overrides": {
///     "grain.strength": { "value": 0.6, "against": "placeholder" }
///   }
/// }
/// ```
///
/// The catalogue says which fields have controls and what interval each may
/// take; this document records only the controls that were moved. A recipe
/// whose digest no longer matches the stock file is stale: the values are kept
/// so a person can review them, and none of them is applied to a render.
class StockRecipe {
  const StockRecipe({
    required this.stock,
    required this.stockDigest,
    this.overrides = const <String, RecipeOverride>{},
    this.model = const <String, RecipeOverride>{},
  });

  static const String schema = 'kallo/stock-recipe/1';

  /// The stock id the recipe belongs to.
  final String stock;

  /// The digest of the packed stock file the recipe was written against.
  final String stockDigest;

  /// The stock's own fields that were moved, keyed `<module>.<control>`.
  final Map<String, RecipeOverride> overrides;

  /// The model's placeholders that were moved, keyed the same way.
  ///
  /// Halation, the couplers and the interimage strength are not any stock's
  /// data; they belong to the catalogue's `model` section, and a recipe writes
  /// them under their own key.
  final Map<String, RecipeOverride> model;

  bool get isEmpty => overrides.isEmpty && model.isEmpty;

  /// Whether this recipe was written against another version of the file.
  ///
  /// A digest the app cannot read fails closed: an unknown version is not the
  /// same version. A recipe for another stock is stale too — the file name is
  /// per stock, but the document names its own stock and that name counts.
  bool isStaleFor(Stock stock) {
    if (stock.id != this.stock) {
      return true;
    }
    if (stockDigest.isEmpty || stock.stockDigest.isEmpty) {
      return true;
    }
    return stockDigest != stock.stockDigest;
  }

  /// The recipe with one control moved. An existing departure is replaced.
  StockRecipe withOverride(
    String key,
    RecipeOverride departure, {
    bool inModel = false,
  }) {
    final Map<String, RecipeOverride> next = <String, RecipeOverride>{
      ...(inModel ? model : overrides),
      key: departure,
    };
    return inModel
        ? StockRecipe(
            stock: stock,
            stockDigest: stockDigest,
            overrides: overrides,
            model: next,
          )
        : StockRecipe(
            stock: stock,
            stockDigest: stockDigest,
            overrides: next,
            model: model,
          );
  }

  /// The recipe with one control back at the file's value.
  StockRecipe withoutOverride(String key, {bool inModel = false}) {
    final Map<String, RecipeOverride> next = <String, RecipeOverride>{
      ...(inModel ? model : overrides),
    }..remove(key);
    return inModel
        ? StockRecipe(
            stock: stock,
            stockDigest: stockDigest,
            overrides: overrides,
            model: next,
          )
        : StockRecipe(
            stock: stock,
            stockDigest: stockDigest,
            overrides: next,
            model: model,
          );
  }

  /// The same departures, bound to a digest the file actually has now.
  StockRecipe rebind(String digest) => StockRecipe(
    stock: stock,
    stockDigest: digest,
    overrides: overrides,
    model: model,
  );

  /// The recipe with every departure removed, still naming its stock.
  StockRecipe cleared() => StockRecipe(stock: stock, stockDigest: stockDigest);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema': schema,
    'stock': stock,
    'stock_digest': stockDigest,
    'overrides': <String, Object?>{
      for (final MapEntry<String, RecipeOverride> entry in overrides.entries)
        entry.key: entry.value.toJson(),
    },
    if (model.isNotEmpty)
      'model': <String, Object?>{
        for (final MapEntry<String, RecipeOverride> entry in model.entries)
          entry.key: entry.value.toJson(),
      },
  };

  /// Read a recipe, or null when the document is not one.
  static StockRecipe? fromJson(Map<String, dynamic> json) {
    if (json['schema'] != schema) {
      return null;
    }
    final Object? stock = json['stock'];
    if (stock is! String || stock.isEmpty) {
      return null;
    }
    return StockRecipe(
      stock: stock,
      stockDigest: json['stock_digest'] as String? ?? '',
      overrides: _readOverrides(json['overrides']),
      model: _readOverrides(json['model']),
    );
  }

  static Map<String, RecipeOverride> _readOverrides(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const <String, RecipeOverride>{};
    }
    return <String, RecipeOverride>{
      for (final MapEntry<String, dynamic> entry in json.entries)
        if (RecipeOverride.fromJson(entry.value)
            case final RecipeOverride value)
          entry.key: value,
    };
  }

  /// The recipe read against the catalogue as it is now.
  RecipeReview review(
    Stock stock, {
    List<Measured> model = const <Measured>[],
  }) {
    final bool stale = isStaleFor(stock);
    final List<RecipeChange> changes = <RecipeChange>[
      for (final MapEntry<String, RecipeOverride> entry in overrides.entries)
        _review(entry.key, entry.value, stock.measured, inModel: false),
      for (final MapEntry<String, RecipeOverride> entry in this.model.entries)
        _review(entry.key, entry.value, model, inModel: true),
    ];
    return RecipeReview(recipe: this, stale: stale, changes: changes);
  }

  RecipeChange _review(
    String key,
    RecipeOverride departure,
    List<Measured> fields, {
    required bool inModel,
  }) {
    final Measured? field = fieldForKey(fields, key);
    final Control? control = controlForKey(fields, key);
    final String state = field?.verdict ?? '';
    final bool locked = field?.locked ?? true;
    final bool inRange =
        control != null &&
        departure.value >= control.min &&
        departure.value <= control.max;
    // A measured field with an advanced unlock may be moved, but only by an
    // explicit departure: the recipe says the person unlocked the field and
    // chose the value, and the catalogue says the field offers that choice.
    // The confirmation is therefore the departure itself, recorded `against`
    // the measurement — no silent move, and no departure from a field that
    // does not offer the unlock.
    final bool confirmed =
        control != null &&
        state == 'measured' &&
        (field?.advancedUnlock ?? false) &&
        departure.against == 'measured';
    return RecipeChange(
      key: key,
      override: departure,
      inModel: inModel,
      state: state,
      control: control,
      locked: locked,
      inRange: inRange,
      confirmedDeparture: confirmed,
      fits: control != null && !locked && inRange,
      applies: control != null && inRange && (!locked || confirmed),
      gradeChanged:
          departure.against.isNotEmpty &&
          state.isNotEmpty &&
          departure.against != state,
    );
  }

  /// The tuning these departures describe, when they are the file's to move.
  ///
  /// A stale recipe applies nothing: the defaults are used and the person gets
  /// a review. A departure that no longer fits — a measured field, a control
  /// that is gone, a value outside the interval — is dropped the same way.
  Tuning tuningFor(Stock stock, {List<Measured> model = const <Measured>[]}) =>
      review(stock, model: model).tuning;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! StockRecipe ||
        other.stock != stock ||
        other.stockDigest != stockDigest ||
        other.overrides.length != overrides.length ||
        other.model.length != model.length) {
      return false;
    }
    for (final MapEntry<String, RecipeOverride> entry in overrides.entries) {
      if (other.overrides[entry.key] != entry.value) {
        return false;
      }
    }
    for (final MapEntry<String, RecipeOverride> entry in model.entries) {
      if (other.model[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    stock,
    stockDigest,
    Object.hashAllUnordered(
      overrides.entries.map(
        (MapEntry<String, RecipeOverride> e) => Object.hash(e.key, e.value),
      ),
    ),
    Object.hashAllUnordered(
      model.entries.map(
        (MapEntry<String, RecipeOverride> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() =>
      'StockRecipe($stock @ $stockDigest, overrides: ${overrides.length}, model: ${model.length})';
}

/// One departure, read against the catalogue as it is now.
class RecipeChange {
  const RecipeChange({
    required this.key,
    required this.override,
    required this.inModel,
    required this.state,
    required this.control,
    required this.locked,
    required this.inRange,
    required this.confirmedDeparture,
    required this.fits,
    required this.applies,
    required this.gradeChanged,
  });

  /// The control key, `<module>.<control>`.
  final String key;

  /// The value the recipe recorded.
  final RecipeOverride override;

  /// Whether this departure is on the catalogue's model section.
  final bool inModel;

  /// The verdict the field carries today; empty when the field is gone.
  final String state;

  /// The control the field exposes today, when it still has one.
  final Control? control;

  /// Whether the field is held at the file's value today.
  final bool locked;

  /// Whether the recorded value is inside the control's interval today.
  final bool inRange;

  /// Whether this is a deliberate move of measured data: the field offers the
  /// advanced unlock and the departure records the measurement it left.
  final bool confirmedDeparture;

  /// Whether the departure can still be applied as it was written.
  final bool fits;

  /// Whether a render may use the departure: either it still fits, or it is an
  /// explicit departure from measured data that the field offers.
  final bool applies;

  /// Whether the verdict changed since the departure was written.
  final bool gradeChanged;
}

/// A recipe read against the catalogue: whether it is stale, and each departure
/// with the verdict it was written against beside the one the file gives now.
class RecipeReview {
  const RecipeReview({
    required this.recipe,
    required this.stale,
    required this.changes,
  });

  final StockRecipe recipe;

  /// Whether the recipe was written against another version of the stock file.
  final bool stale;

  /// Every departure, in the order the recipe wrote them.
  final List<RecipeChange> changes;

  /// The departures that no longer fit, which is what the review has to name.
  List<RecipeChange> get noLongerFit => <RecipeChange>[
    for (final RecipeChange change in changes)
      if (!change.fits) change,
  ];

  /// Whether any departure still fits the file as it is now.
  bool get hasSomethingToKeep =>
      changes.any((RecipeChange change) => change.fits);

  /// What a render should apply: nothing while stale, and nothing that no
  /// longer fits, so the model never silently applies a departure the file
  /// stopped admitting to.
  Tuning get tuning {
    if (stale) {
      return Tuning.identity;
    }
    Tuning next = Tuning.identity;
    for (final RecipeChange change in changes) {
      if (change.applies) {
        next = next.withValue(change.key, change.override.value);
      }
    }
    return next;
  }

  /// The departure for one control key, when the recipe has one.
  RecipeChange? changeFor(String key) {
    for (final RecipeChange change in changes) {
      if (change.key == key) {
        return change;
      }
    }
    return null;
  }
}
