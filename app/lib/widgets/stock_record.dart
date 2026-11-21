import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/stock.dart';
import '../lab/stock_recipe.dart';
import 'button.dart';
import 'shadow_box.dart';

/// Open one stock's parameters: the controls it exposes, and the fields it
/// holds.
///
/// It is a route over the window, not a Material dialog: the barrier is the
/// window's own ink at a low alpha, and the card is the surface plane with a
/// hairline. Moving a control does not touch the stock file; it writes a
/// departure, and the departure is committed back through [onRecipe] so the
/// next print can use it.
Future<void> showStockRecordSheet(
  BuildContext context, {
  required Stock stock,
  required List<Measured> model,
  required StockRecipe? recipe,
  required Future<void> Function(StockRecipe? recipe) onRecipe,
}) {
  final KalloStrings s = KalloStrings.of(context);
  final KalloColors colors = KalloScope.colorsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: s.close,
    barrierColor: colors.scrim,
    transitionDuration: KalloMotion.settle,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondary,
        ) => StockRecordSheet(
          stock: stock,
          model: model,
          recipe: recipe,
          onRecipe: onRecipe,
        ),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: KalloMotion.enter),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(
              CurvedAnimation(parent: animation, curve: KalloMotion.enter),
            ),
            child: child,
          ),
        ),
  );
}

/// The record of one stock, as a sheet over the window.
///
/// The sheet is the same body the inspector shows, in a card: a phone has no
/// side panel, so the record comes over the bench there. The panel is the
/// desktop's way in and reads the body directly.
class StockRecordSheet extends StatelessWidget {
  const StockRecordSheet({
    super.key,
    required this.stock,
    this.model = const <Measured>[],
    this.recipe,
    this.onRecipe,
  });

  final Stock stock;

  /// The catalogue's placeholders that belong to this stock's half of the
  /// shelf, already filtered by the caller.
  final List<Measured> model;

  /// The departures already written beside this stock, when there are any.
  final StockRecipe? recipe;

  /// Called when the recipe changes, with the document to keep. Null means the
  /// stock is back at the file's values and its recipe should be removed.
  final Future<void> Function(StockRecipe? recipe)? onRecipe;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KalloSpace.step5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
            child: KalloShadowBox(
              kind: KalloShadowKind.sheet,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(KalloRadius.sheet),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(context, colors, s),
                    Container(height: 1, color: colors.hairline),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          KalloSpace.step5 + 2,
                          KalloSpace.step4,
                          KalloSpace.step5 + 2,
                          KalloSpace.step5,
                        ),
                        child: StockRecordBody(
                          stock: stock,
                          model: model,
                          recipe: recipe,
                          onRecipe: onRecipe,
                          onDone: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, KalloColors colors, KalloStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KalloSpace.step5 + 2,
        KalloSpace.step4,
        KalloSpace.step4,
        KalloSpace.step4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              stock.displayName,
              style: KalloType.display.copyWith(color: colors.ink),
            ),
          ),
          GestureDetector(
            key: const Key('record-close'),
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(KalloSpace.step2),
              child: Text(
                s.close,
                style: KalloType.caption.copyWith(
                  color: colors.inkMuted,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The body of a stock's record: the controls it exposes, and the fields it
/// holds at the file's value.
///
/// The controls are the file's, not the app's: every interval and every default
/// comes from the catalogue. The identity is the file's own rendering, which is
/// why a control at its default changes nothing; a departure is kept in a stock
/// recipe beside the file and is applied only while the file it was written
/// against is still the file on disk.
///
/// The page is two lists: what may move, and what is measured and therefore
/// held. The data behind a number is not a paragraph here — the file's own sheet
/// already says what it measured, and a person opening the record came to move
/// a print, not to read a bibliography.
///
/// The same body is a sheet over the window and the instrument panel's own
/// page: the sheet commits every change as it happens, and the panel also
/// reports a move while the slider is still in hand, so the bench beside it can
/// draw the print the move would make.
class StockRecordBody extends StatefulWidget {
  const StockRecordBody({
    super.key,
    required this.stock,
    this.model = const <Measured>[],
    this.recipe,
    this.onChanged,
    this.onRecipe,
    this.showDone = true,
    this.onDone,
  });

  final Stock stock;

  /// The catalogue's own placeholders that belong to this stock's half of the
  /// shelf: halation and the couplers for a film, the print's contrast and
  /// black level for a paper.
  final List<Measured> model;

  /// The departures already written beside this stock, when there are any.
  final StockRecipe? recipe;

  /// Called on every move, before the move is committed: the bench draws with
  /// the recipe as it stands. Null where there is no bench beside the record.
  final void Function(StockRecipe? recipe)? onChanged;

  /// Called when the recipe is final, with the document to keep. Null means
  /// the stock is back at the file's values and its recipe should be removed.
  final Future<void> Function(StockRecipe? recipe)? onRecipe;

  /// Whether the body ends with its own Done action. A sheet does; the
  /// inspector closes the page from its own header.
  final bool showDone;

  /// What the Done action does.
  final VoidCallback? onDone;

  @override
  State<StockRecordBody> createState() => _StockRecordBodyState();
}

class _StockRecordBodyState extends State<StockRecordBody> {
  StockRecipe? _recipe;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  KalloStrings get _s => KalloStrings.of(context);

  bool get _stale => _recipe?.isStaleFor(widget.stock) ?? false;

  RecipeReview? get _review =>
      _recipe?.review(widget.stock, model: widget.model);

  StockRecipe _base() =>
      _recipe ??
      StockRecipe(
        stock: widget.stock.id,
        stockDigest: widget.stock.stockDigest,
      );

  /// A field offers a control that can be moved now.
  bool _controllable(Measured field) =>
      field.controls.isNotEmpty && !field.locked;

  List<Measured> get _movable => <Measured>[
    if (!_stale)
      for (final Measured field in widget.stock.measured)
        if (_controllable(field)) field,
  ];

  List<Measured> get _movableModel => <Measured>[
    if (!_stale)
      for (final Measured field in widget.model)
        if (_controllable(field)) field,
  ];

  /// The fields the file measured, and therefore holds at its own value.
  List<Measured> get _held => <Measured>[
    for (final Measured field in widget.stock.measured)
      if (field.locked && field.verdict != 'none') field,
  ];

  double _valueOf(Measured field, Control control, {required bool inModel}) {
    if (_stale) {
      return control.value;
    }
    final RecipeOverride? departure = inModel
        ? _recipe?.model[controlKey(field, control)]
        : _recipe?.overrides[controlKey(field, control)];
    return departure?.value ?? control.value;
  }

  bool _isMoved(Measured field, Control control, {required bool inModel}) {
    if (_stale || _recipe == null) {
      return false;
    }
    final String key = controlKey(field, control);
    return (inModel ? _recipe!.model : _recipe!.overrides).containsKey(key);
  }

  void _remember(StockRecipe recipe) => _keep(recipe, commit: true);

  void _move(
    Measured field,
    Control control,
    double value, {
    required bool inModel,
  }) {
    final StockRecipe next = _base().withOverride(
      controlKey(field, control),
      RecipeOverride(value: value, against: field.verdict),
      inModel: inModel,
    );
    _keep(next, commit: false);
  }

  /// Keep a change. A slider still in hand is reported but not written: the
  /// bench beside the record draws with it, and the document waits for the
  /// move to end.
  void _keep(StockRecipe recipe, {required bool commit}) {
    final StockRecipe? next = recipe.isEmpty ? null : recipe;
    setState(() => _recipe = next);
    widget.onChanged?.call(next);
    if (commit) {
      unawaited(widget.onRecipe?.call(next) ?? Future<void>.value());
    }
  }

  void _commit() =>
      unawaited(widget.onRecipe?.call(_recipe) ?? Future<void>.value());

  void _reset(Measured field, Control control, {required bool inModel}) {
    final StockRecipe? recipe = _recipe;
    if (recipe == null) {
      return;
    }
    final String key = controlKey(field, control);
    _remember(recipe.withoutOverride(key, inModel: inModel));
  }

  void _resetAll() {
    if (_recipe == null) {
      return;
    }
    _remember(_base().cleared());
  }

  /// Keep the departures that still fit the file, and bind them to the digest
  /// the file has now. The rest are dropped, not silently: they were shown.
  void _keepFitting() {
    final RecipeReview? review = _review;
    if (review == null) {
      return;
    }
    final Map<String, RecipeOverride> overrides = <String, RecipeOverride>{
      for (final RecipeChange change in review.changes)
        if (!change.inModel && change.fits) change.key: change.override,
    };
    final Map<String, RecipeOverride> model = <String, RecipeOverride>{
      for (final RecipeChange change in review.changes)
        if (change.inModel && change.fits) change.key: change.override,
    };
    _remember(
      StockRecipe(
        stock: widget.stock.id,
        stockDigest: widget.stock.stockDigest,
        overrides: overrides,
        model: model,
      ),
    );
  }

  void _removeRecipe() {
    if (_recipe == null) {
      return;
    }
    _remember(_base().cleared());
  }

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = _s;
    final List<Measured> movable = _movable;
    final List<Measured> model = _movableModel;
    final List<Measured> held = _held;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // A stale recipe is a decision to make before anything can move, so
        // it is the one thing that comes before the controls.
        if (_stale) ...<Widget>[
          _staleReview(colors, s),
          const SizedBox(height: KalloSpace.step5),
        ] else ...<Widget>[
          _sectionLabel(colors, s.adjustable),
          if (movable.isEmpty && model.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KalloSpace.step3),
              child: Text(
                s.noAdjustable,
                style: KalloType.small.copyWith(color: colors.inkFaint),
              ),
            )
          else ...<Widget>[
            for (final Measured field in movable)
              _controlField(colors, s, field, inModel: false),
            for (final Measured field in model)
              _controlField(colors, s, field, inModel: true),
          ],
          if (held.isNotEmpty) ...<Widget>[
            const SizedBox(height: KalloSpace.step5),
            Container(height: 1, color: colors.hairline),
            const SizedBox(height: KalloSpace.step4),
            _sectionLabel(colors, s.lockedParameters),
            const SizedBox(height: KalloSpace.step1),
            for (final Measured field in held) _heldRow(colors, s, field),
          ],
        ],
        const SizedBox(height: KalloSpace.step5),
        _footer(colors, s),
      ],
    );
  }

  Widget _sectionLabel(KalloColors colors, String label) => Text(
    label,
    style: KalloType.caption.copyWith(
      color: colors.inkFaint,
      letterSpacing: 1.4,
    ),
  );

  /// The stale review: every departure with the verdict it was written against
  /// and the one the file gives now. Nothing in it is applied.
  Widget _staleReview(KalloColors colors, KalloStrings s) {
    final RecipeReview review = _review!;
    return Container(
      key: const Key('record-stale'),
      padding: const EdgeInsets.all(KalloSpace.step3),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(KalloRadius.control),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            s.recipeStale,
            style: KalloType.title.copyWith(color: colors.ink),
          ),
          const SizedBox(height: KalloSpace.step1),
          Text(
            s.recipeStaleNote,
            style: KalloType.small.copyWith(color: colors.inkMuted),
          ),
          for (final RecipeChange change in review.changes) ...<Widget>[
            const SizedBox(height: KalloSpace.step3),
            _staleRow(colors, s, change),
          ],
          const SizedBox(height: KalloSpace.step3),
          Wrap(
            spacing: KalloSpace.step2,
            runSpacing: KalloSpace.step2,
            children: <Widget>[
              if (review.hasSomethingToKeep)
                KalloButton(
                  key: const Key('record-keep-fits'),
                  label: s.keepFitting,
                  onTap: _keepFitting,
                  height: 30,
                ),
              KalloButton(
                key: const Key('record-remove'),
                label: s.removeRecipe,
                onTap: _removeRecipe,
                height: 30,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staleRow(KalloColors colors, KalloStrings s, RecipeChange change) {
    final String recorded = s.claim(change.override.against);
    final String now = s.claim(change.state);
    return Row(
      key: Key('record-stale-${change.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    _controlLabel(s, change.key),
                    style: KalloType.small.copyWith(color: colors.ink),
                  ),
                  if (!change.fits) ...<Widget>[
                    const SizedBox(width: KalloSpace.step2),
                    Text(
                      s.noLongerFits,
                      style: KalloType.caption.copyWith(
                        color: colors.inkFaint,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                <String>[
                  if (recorded.isNotEmpty) s.recordedAgainst(recorded),
                  if (now.isNotEmpty) s.fileNow(now),
                ].join('   ·   '),
                style: KalloType.data.copyWith(color: colors.inkFaint),
              ),
            ],
          ),
        ),
        GestureDetector(
          key: Key('record-stale-reset-${change.key}'),
          onTap: () => _resetKey(change),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KalloSpace.step2),
            child: Text(
              s.recordReset,
              style: KalloType.small.copyWith(color: colors.accent),
            ),
          ),
        ),
      ],
    );
  }

  void _resetKey(RecipeChange change) {
    final StockRecipe? recipe = _recipe;
    if (recipe == null) {
      return;
    }
    _remember(recipe.withoutOverride(change.key, inModel: change.inModel));
  }

  /// One field whose value may move: the controls, and nothing else.
  Widget _controlField(
    KalloColors colors,
    KalloStrings s,
    Measured field, {
    required bool inModel,
  }) {
    // No rule between two controls: the fields are separated by the space the
    // page already keeps, and a line would draw a table where the page is a
    // list of things a person may move.
    return Container(
      key: Key('record-field-${inModel ? 'model' : 'stock'}-${field.field}'),
      padding: const EdgeInsets.symmetric(vertical: KalloSpace.step3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            s.field(field.field),
            style: KalloType.title.copyWith(color: colors.ink),
          ),
          for (final Control control in field.controls) ...<Widget>[
            const SizedBox(height: KalloSpace.step2),
            _control(colors, s, field, control, inModel: inModel),
          ],
        ],
      ),
    );
  }

  /// One field the file measured: the name, and the word for what it is.
  ///
  /// It carries no control, because the lock is the data's and not a disabled
  /// slider: a value the sheet measured is not a suggestion.
  Widget _heldRow(KalloColors colors, KalloStrings s, Measured field) {
    final String verdict = s.claim(field.verdict);
    return Container(
      key: Key('record-locked-${field.field}'),
      padding: const EdgeInsets.symmetric(vertical: KalloSpace.step2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              s.field(field.field),
              style: KalloType.small.copyWith(color: colors.inkMuted),
            ),
          ),
          if (verdict.isNotEmpty)
            Text(
              verdict,
              style: KalloType.caption.copyWith(
                color: colors.inkFaint,
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }

  Widget _control(
    KalloColors colors,
    KalloStrings s,
    Measured field,
    Control control, {
    required bool inModel,
  }) {
    final String key = controlKey(field, control);
    final double value = _valueOf(field, control, inModel: inModel);
    final bool moved = _isMoved(field, control, inModel: inModel);
    final String readout = _readout(value);
    return Column(
      key: Key('record-control-$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              s.controlName(control.name),
              style: KalloType.small.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(width: KalloSpace.step2),
            Text(
              s.currentValue(readout),
              key: Key('record-value-$key'),
              style: KalloType.data.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              s.fileValue(_readout(control.value)),
              style: KalloType.data.copyWith(color: colors.inkFaint),
            ),
            if (moved) ...<Widget>[
              const SizedBox(width: KalloSpace.step2),
              GestureDetector(
                key: Key('record-reset-$key'),
                onTap: () => _reset(field, control, inModel: inModel),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  s.recordReset,
                  style: KalloType.small.copyWith(color: colors.accent),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: KalloSpace.step1),
        _RecipeSlider(
          key: Key('record-slider-$key'),
          value: value,
          min: control.min,
          max: control.max,
          onChanged: (double next) =>
              _move(field, control, next, inModel: inModel),
          onChangeEnd: _commit,
        ),
        Row(
          children: <Widget>[
            Text(
              _readout(control.min),
              style: KalloType.data.copyWith(color: colors.inkFaint),
            ),
            const Spacer(),
            Text(
              _readout(control.max),
              style: KalloType.data.copyWith(color: colors.inkFaint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _footer(KalloColors colors, KalloStrings s) {
    final bool departed =
        _recipe?.overrides.values.any(
          (RecipeOverride departure) => departure.against == 'measured',
        ) ??
        false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (_recipe != null)
              KalloButton(
                key: const Key('record-reset-all'),
                label: s.recordResetAll,
                onTap: _resetAll,
                height: 30,
              ),
            const Spacer(),
            if (widget.showDone)
              KalloButton(
                key: const Key('record-done'),
                label: s.done,
                onTap: widget.onDone,
                filled: true,
                height: 30,
              ),
          ],
        ),
        if (departed) ...<Widget>[
          const SizedBox(height: KalloSpace.step2),
          Text(
            s.departedMeasured,
            textAlign: TextAlign.right,
            style: KalloType.caption.copyWith(
              color: colors.inkFaint,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }

  static String _readout(double value) {
    if (value == value.roundToDouble() && value.abs() < 1000) {
      return value.toStringAsFixed(1);
    }
    final String text = value.toStringAsFixed(2);
    return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
  }

  static String _controlLabel(KalloStrings s, String key) {
    final int dot = key.indexOf('.');
    if (dot <= 0 || dot == key.length - 1) {
      return key;
    }
    final String module = key.substring(0, dot) == 'blur'
        ? 'mtf'
        : key.substring(0, dot);
    return '${s.field(module)} · ${s.controlName(key.substring(dot + 1))}';
  }
}

/// One scalar within the interval the file gives.
///
/// A slider and not a stepper: the module's bounds are the file's, the value is
/// continuous inside them, and the picture is what a person is looking at. The
/// handle is the safelight's colour, as the ruler's is: a control being moved
/// is the one lit thing.
class _RecipeSlider extends StatefulWidget {
  const _RecipeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<_RecipeSlider> createState() => _RecipeSliderState();
}

class _RecipeSliderState extends State<_RecipeSlider> {
  bool _hover = false;

  double _valueAt(double dx, double width) {
    if (widget.max <= widget.min) {
      return widget.min;
    }
    final double t = width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);
    return widget.min + t * (widget.max - widget.min);
  }

  double _fraction() {
    if (widget.max <= widget.min) {
      return 0;
    }
    return ((widget.value - widget.min) / (widget.max - widget.min)).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.max(1, constraints.maxWidth);
        return Semantics(
          slider: true,
          value: widget.value.toStringAsFixed(2),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails details) {
                widget.onChanged(_valueAt(details.localPosition.dx, width));
                widget.onChangeEnd();
              },
              onHorizontalDragStart: (DragStartDetails details) =>
                  widget.onChanged(_valueAt(details.localPosition.dx, width)),
              onHorizontalDragUpdate: (DragUpdateDetails details) =>
                  widget.onChanged(_valueAt(details.localPosition.dx, width)),
              onHorizontalDragEnd: (DragEndDetails details) =>
                  widget.onChangeEnd(),
              child: SizedBox(
                height: 26,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: _hover ? colors.fillStrong : colors.fill,
                            borderRadius: BorderRadius.circular(
                              KalloRadius.pill,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (_fraction() * (width - 14)).clamp(0.0, width - 14),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
