import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/mobile.dart';
import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/chart.dart';
import '../lab/clock.dart';
import '../lab/model.dart';
import '../lab/preview_bench.dart';
import '../lab/render_mode.dart';
import '../lab/stock.dart';
import '../lab/strip.dart';
import '../lab/strip_develop.dart';
import '../widgets/button.dart';
import '../widgets/curves.dart';
import '../widgets/inspector.dart';
import '../widgets/materials_card.dart';
import '../widgets/mobile/mobile_controls.dart';
import '../widgets/mobile/mobile_icon.dart';
import '../widgets/mobile/mobile_sheet.dart';
import '../widgets/shadow_box.dart';
import '../widgets/stepper.dart';
import '../widgets/time_slider.dart';
import '../widgets/wall.dart';
import 'mobile/mobile_picker.dart';

/// The first step: the bench, the photograph, and the print it becomes.
///
/// The materials are on the bench, not on a page before it: a film or a paper
/// is chosen by looking at the print it makes, so the shelf lies under the
/// easel and the print answers every tap. The time in hand is the ruler; a
/// print is only added when the button is pressed. The print can be read
/// against the original with a wipe — the one comparison the bench makes.
class DevelopStage extends StatefulWidget {
  const DevelopStage({
    super.key,
    required this.strip,
    required this.catalogue,
    required this.onChoosePhoto,
    required this.onFilm,
    required this.onPaper,
    required this.onTemperature,
    required this.onDevelop,
    required this.onRemove,
    this.photograph,
    this.onClearStrip,
    this.showInspector = true,
    this.topInset = 0,
  });

  final TestStrip strip;

  /// What the model carries. The shelf is the model's, not the app's: the card
  /// cannot show a film the model does not have.
  final Catalogue catalogue;

  /// Bring another photograph into the darkroom. A different photograph is a
  /// different strip.
  final VoidCallback onChoosePhoto;

  /// Take another box off the shelf. A strip is one material, so a new choice
  /// starts a new strip; the stage asks before it loses prints.
  final ValueChanged<Stock> onFilm;
  final ValueChanged<Stock?> onPaper;

  /// Change the developer's temperature. A strip is one development, so the
  /// app starts a new strip when it changes.
  final ValueChanged<double> onTemperature;

  /// Develop one print at a time and add it to the strip.
  final Future<void> Function(double minutes) onDevelop;

  /// Take one print off the strip.
  final Future<void> Function(double minutes) onRemove;

  /// The original photograph, when the caller has it. The phone shows it on
  /// the easel before the first test print exists, and the wipe reads the
  /// print against it.
  final ui.Image? photograph;

  /// Forget every print and keep the photograph and materials. The stage asks
  /// before this runs when there is anything to lose.
  final VoidCallback? onClearStrip;

  /// Whether the instrument panel is open.
  final bool showInspector;

  /// The transparent chrome at the top of the window.
  final double topInset;

  @override
  State<DevelopStage> createState() => _DevelopStageState();
}

class _DevelopStageState extends State<DevelopStage> {
  static const List<double> _ladder = <double>[3, 6, 9, 12, 15];
  static const double _tempLow = 15;
  static const double _tempHigh = 30;
  static const double _tempStep = 0.5;

  late double _minutes;
  ui.Image? _preview;
  bool _ownsPreview = false;
  FilmChart? _chart;
  final Map<double, FilmCurve> _curves = <double, FilmCurve>{};
  final Map<double, FilmChart> _chartCache = <double, FilmChart>{};
  PaperCurve? _paper;

  bool _busy = false;
  String? _error;

  /// Whether the shelf is lying on the bench, and which half of it is open.
  bool _cardOpen = false;
  MaterialsKind _cardKind = MaterialsKind.film;

  /// Whether the print is read against the original, and where the wipe is.
  /// The wipe is the bench's own tool: not a setting, and not kept.
  bool _compareOn = false;
  double _compareAt = 0.5;

  Timer? _timer;
  int _generation = 0;
  PreviewBench? _previewBench;
  String? _benchKey;
  final Map<double, GlobalKey> _stripKeys = <double, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _minutes = widget.strip.latest?.minutes ?? 9;
    _showPrint(_minutes);
    _openBench();
    if (_preview == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _previewNow());
    }
    _loadPaper();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFilmCurves();
      _revealSelected();
    });
  }

  @override
  void didUpdateWidget(DevelopStage old) {
    super.didUpdateWidget(old);
    final TestPrint? print = _printAt(_minutes);
    if (print != null) {
      if (!identical(print.image, _preview)) {
        final ui.Image? oldImage = _preview;
        final bool owned = _ownsPreview;
        setState(() {
          _preview = print.image;
          _ownsPreview = false;
          _chart = print.chart ?? _chart;
        });
        if (owned) {
          _disposeAfterFrame(oldImage);
        }
      }
    } else if (!_ownsPreview &&
        _preview != null &&
        !widget.strip.prints.any(
          (TestPrint p) => identical(p.image, _preview),
        )) {
      // The print that was on the easel was removed: the image belonged to the
      // strip, and the strip no longer holds it.
      setState(() {
        _preview = null;
        _chart = null;
      });
      _schedule();
    }
    if (old.strip.paperId != widget.strip.paperId) {
      _loadPaper();
    }
    final String session = _sessionKeyFor(widget.strip);
    if (_benchKey != session) {
      // Another photograph, or another engine: another session, and the time
      // in hand belonged to the last one.
      _generation++;
      final ui.Image? oldImage = _preview;
      final bool owned = _ownsPreview;
      _preview = null;
      _ownsPreview = false;
      _chart = null;
      _curves.clear();
      _chartCache.clear();
      _compareOn = false;
      _minutes = widget.strip.latest?.minutes ?? 9;
      _showPrint(_minutes);
      _openBench();
      _schedule();
      if (owned) {
        _disposeAfterFrame(oldImage);
      }
    } else if (_materialsKeyFor(old.strip) != _materialsKeyFor(widget.strip)) {
      // Another box on the same photograph: the session keeps the negative and
      // only the print changes. The time in hand stays where it was, so two
      // boxes are compared at the same development.
      _generation++;
      _chart = null;
      _curves.clear();
      _chartCache.clear();
      final Future<void>? materials = _previewBench?.setMaterials(
        film: widget.strip.stockId,
        paper: widget.strip.paperId ?? Stocks.paper,
        tempC: widget.strip.tempC,
      );
      if (materials != null) {
        unawaited(materials);
      }
      _schedule();
    } else if (old.strip.balanceFrom != widget.strip.balanceFrom &&
        _printAt(_minutes) == null) {
      // The first print fixed the enlarger's exposure; a preview that was
      // already on the easel was metered on the old balance.
      _schedule();
    }
    unawaited(_loadFilmCurves());
  }
  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    if (_ownsPreview) {
      _preview?.dispose();
    }
    _previewBench?.dispose();
    super.dispose();
  }

  String _sessionKeyFor(TestStrip strip) =>
      '${strip.photo}|${strip.spectral}|${RenderPreference.mode.name}';

  String _materialsKeyFor(TestStrip strip) =>
      '${strip.stockId}|${strip.paperId}|${strip.tempC}';

  /// The session is the strip's, not the time's: changing the ruler does not
  /// touch it. A material or a temperature is the same session with another
  /// print; a photograph, or the engine, is another session.
  void _openBench() {
    final String key = _sessionKeyFor(widget.strip);
    if (_benchKey == key) {
      return;
    }
    _benchKey = key;
    _previewBench?.dispose();
    final TestStrip strip = widget.strip;
    _previewBench = PreviewBench(open: () => _openPreview(strip));
    _previewBench!.warm();
  }

  Future<PreviewSession?> _openPreview(TestStrip strip) async {
    final String? photo = strip.photo;
    final Model model = Model.find();
    if (photo == null || !model.available) {
      return null;
    }
    try {
      return await model.openPreview(
        photograph: File(photo),
        stock: strip.stockId,
        paper: strip.paperId ?? Stocks.paper,
        tempC: strip.tempC,
        width: 760,
        spectral: strip.spectral,
      );
    } on Object catch (error) {
      Model.log('the preview session could not be opened: $error');
      return null;
    }
  }

  TestPrint? _printAt(double minutes) {
    for (final TestPrint print in widget.strip.prints) {
      if ((print.minutes - minutes).abs() < 1e-9) {
        return print;
      }
    }
    return null;
  }

  void _showPrint(double minutes) {
    final TestPrint? print = _printAt(minutes);
    if (print == null) {
      return;
    }
    final ui.Image? old = _preview;
    final bool owned = _ownsPreview;
    _preview = print.image;
    _ownsPreview = false;
    _chart = print.chart ?? _chart;
    if (owned) {
      _disposeAfterFrame(old);
    }
  }

  void _disposeAfterFrame(ui.Image? image) {
    if (image == null) {
      return;
    }
    // The picture on screen has to be replaced by the next one before its
    // texture is freed.
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  GlobalKey _stripKey(double minutes) =>
      _stripKeys.putIfAbsent(minutes, () => GlobalKey());

  /// Put the selected print in the middle of the strip, so a strip longer than
  /// the window does not hide the print the time is showing.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? context = _stripKeys[_minutes]?.currentContext;
      if (context == null) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: KalloMotion.settle,
        curve: KalloMotion.enter,
      );
    });
  }

  /// Whether a new strip may replace this one, asking when there are prints.
  Future<bool> _mayReplace(String question) async {
    if (!widget.strip.hasPrints) {
      return true;
    }
    final KalloStrings s = KalloStrings.of(context);
    return showKalloConfirm(
      context,
      title: question,
      message: s.clearsPrints(widget.strip.prints.length),
      confirm: s.changeAction,
    );
  }

  Future<void> _chooseFilm(Stock film) async {
    if (film.id == widget.strip.stockId) {
      return;
    }
    if (!await _mayReplace(KalloStrings.of(context).changeFilmQuestion) ||
        !mounted) {
      return;
    }
    widget.onFilm(film);
  }

  Future<void> _choosePaper(Stock? paper) async {
    if (paper != null && paper.id == widget.strip.paperId) {
      return;
    }
    if (!await _mayReplace(KalloStrings.of(context).changePaperQuestion) ||
        !mounted) {
      return;
    }
    widget.onPaper(paper);
  }

  Future<void> _changePhoto() async {
    if (!await _mayReplace(KalloStrings.of(context).changePhotoQuestion) ||
        !mounted) {
      return;
    }
    widget.onChoosePhoto();
  }

  Future<void> _changeTemperature(double delta) async {
    final double next = _nextTemp(delta);
    if (next == widget.strip.tempC) {
      return;
    }
    if (!await _mayReplace(KalloStrings.of(context).changeTemperatureQuestion) ||
        !mounted) {
      return;
    }
    widget.onTemperature(next);
  }

  /// Lay the shelf on the bench with one half open. Asking for the half that
  /// is already open puts the shelf away, which is what the handle that opened
  /// it should do when pressed again.
  void _openCard(MaterialsKind kind) {
    setState(() {
      if (_cardOpen && _cardKind == kind) {
        _cardOpen = false;
      } else {
        _cardOpen = true;
        _cardKind = kind;
      }
    });
  }

  void _closeCard() {
    if (!_cardOpen) {
      return;
    }
    setState(() => _cardOpen = false);
  }

  void _toggleCompare() {
    if (_preview == null) {
      return;
    }
    setState(() {
      _compareOn = !_compareOn;
      if (_compareOn) {
        _compareAt = 0.5;
      }
    });
  }

  /// The wipe follows the pointer (or the finger) inside the picture, and the
  /// seam is the only mark it leaves: there is no divider to grab.
  void _setCompareAt(double fraction) {
    if (!(_compareOn && _preview != null)) {
      return;
    }
    final double next = fraction.clamp(0.04, 0.96).toDouble();
    if ((next - _compareAt).abs() < 0.001) {
      return;
    }
    setState(() => _compareAt = next);
  }

  Future<void> _openMaterialsPhone() async {
    final KalloStrings s = KalloStrings.of(context);
    final Stock? film = widget.catalogue.film(widget.strip.stockId);
    final Stock? paper = widget.catalogue.paper(widget.strip.paperId ?? '');
    final _MaterialsAction? action =
        await showKalloMobileSheet<_MaterialsAction>(
          context,
          builder: (BuildContext sheetContext) => _PhoneMaterialsSheet(
            film: film?.productName ?? stockDisplayName(widget.strip.stockLabel),
            filmNote: film == null
                ? ''
                : '${film.maker} · ${s.processName(film.process ?? FilmProcess.negative)}',
            paper: paper?.productName ??
                stockDisplayName(widget.strip.paperLabel ?? ''),
            paperNote: paper == null
                ? ''
                : '${paper.maker} · '
                      '${(paper.emulsion ?? PaperEmulsion.colour) == PaperEmulsion.silver ? s.silverPaper : s.colourPaper}',
            photo: widget.strip.name ?? s.noPhotograph,
            onFilm: () => Navigator.of(sheetContext).pop(_MaterialsAction.film),
            onPaper: () => Navigator.of(sheetContext).pop(_MaterialsAction.paper),
            onPhoto: () => Navigator.of(sheetContext).pop(_MaterialsAction.photo),
          ),
        );
    if (action == null || !mounted) {
      return;
    }
    if (action == _MaterialsAction.film) {
      final Stock? choice = await showKalloFilmPicker(
        context,
        catalogue: widget.catalogue,
        selectedId: widget.strip.stockId,
      );
      if (choice != null) {
        await _chooseFilm(choice);
      }
    } else if (action == _MaterialsAction.paper) {
      final List<Stock> papers = widget.catalogue.papersFor(
        widget.catalogue.film(widget.strip.stockId)?.process,
      );
      final Stock? choice = await showKalloPaperPicker(
        context,
        papers: papers,
        selectedId: widget.strip.paperId,
      );
      if (choice != null) {
        await _choosePaper(choice);
      }
    } else {
      await _changePhoto();
    }
  }

  void _setPreview(ui.Image image, {required bool owned}) {
    final ui.Image? old = _preview;
    final bool wasOwned = _ownsPreview;
    setState(() {
      _preview = image;
      _ownsPreview = owned;
    });
    if (wasOwned && !identical(old, image)) {
      _disposeAfterFrame(old);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 110), _previewNow);
  }

  Future<void> _loadPaper() async {
    final Model model = Model.find();
    if (!model.available) {
      return;
    }
    try {
      final PaperCurve? curve = await model.paperCurve(
        paper: widget.strip.paperId ?? Stocks.paper,
      );
      if (mounted && curve != null) {
        setState(() => _paper = curve);
      }
    } on Object catch (error) {
      Model.log('the paper curve could not be read: $error');
    }
  }

  /// The full developed curves of the strip's times, and of the time in hand.
  ///
  /// The time in hand is not on the strip yet, so it is fetched too; the other
  /// times are pruned as the ruler moves, because a curve the person dragged
  /// past is not a print.
  Future<void> _loadFilmCurves() async {
    final Model model = Model.find();
    if (!model.available) {
      return;
    }
    final Set<double> wanted = <double>{
      _minutes,
      for (final TestPrint print in widget.strip.prints) print.minutes,
    };
    _curves.removeWhere((double time, FilmCurve _) => !wanted.contains(time));
    for (final double time in wanted) {
      if (_curves.containsKey(time)) {
        continue;
      }
      try {
        final FilmCurve? curve = await model.filmCurve(
          film: widget.strip.stockId,
          minutes: time,
          tempC: widget.strip.tempC,
        );
        if (!mounted) {
          return;
        }
        if (curve != null) {
          setState(() => _curves[time] = curve);
        }
      } on Object catch (error) {
        Model.log('the film curve could not be read: $error');
      }
    }
  }

  Future<FilmChart?> _readChart(double minutes) async {
    final FilmChart? cached = _chartCache[minutes];
    if (cached != null) {
      return cached;
    }
    try {
      final List<FilmChart>? charts = await Model.find().chart(
        stock: widget.strip.stockId,
        times: <double>[minutes],
        tempC: widget.strip.tempC,
      );
      final FilmChart? chart = charts == null || charts.isEmpty
          ? null
          : charts.first;
      if (chart != null) {
        _chartCache[minutes] = chart;
      }
      return chart;
    } on Object catch (error) {
      Model.log('the strip could not be charted: $error');
      return null;
    }
  }

  Future<void> _previewNow() async {
    final TestPrint? print = _printAt(_minutes);
    if (print != null) {
      if (mounted) {
        setState(() {
          _showPrint(_minutes);
        });
        _revealSelected();
      }
      return;
    }
    final Model model = Model.find();
    final int generation = ++_generation;
    final double minutes = _minutes;
    if (!model.available) {
      if (mounted) {
        setState(() => _error = KalloStrings.of(context).noModel);
      }
      return;
    }
    try {
      // The session is the whole point: the photograph is already decoded, so
      // this is a render and not a read. A model without a session falls back
      // to the subprocess's one render per preview.
      ui.Image? image;
      try {
        image = await _previewBench?.frame(
          minutes: minutes,
          balanceFrom: widget.strip.balanceFrom,
        );
      } on Object catch (error) {
        // A preview session is the fast path; if its device buffer is rejected
        // the one-shot CPU render below is still the same photograph.
        Model.log(
          'the preview session failed; rendering once on the cpu: $error',
        );
      }
      if (image == null) {
        if (!mounted || generation != _generation) {
          return;
        }
        image = await previewTestPrint(
          model: model,
          strip: widget.strip,
          minutes: minutes,
        );
      }
      final ui.Image rendered = image;
      if (!mounted || generation != _generation) {
        rendered.dispose();
        return;
      }
      _setPreview(rendered, owned: true);
      // The picture is on the easel before the densitometer answers: the chart
      // is about the development, not about waiting for it.
      final FilmChart? chart = await _readChart(minutes);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _chart = chart ?? _chart;
        _error = null;
      });
      unawaited(_loadFilmCurves());
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    }
  }

  void _changed(double minutes) {
    setState(() => _minutes = minutes);
    final TestPrint? print = _printAt(minutes);
    if (print != null) {
      _timer?.cancel();
      _generation++;
      setState(() => _showPrint(minutes));
      _revealSelected();
      return;
    }
    _schedule();
  }

  void _settled(double minutes) {
    _timer?.cancel();
    if (_printAt(minutes) == null) {
      _previewNow();
    }
  }

  Future<void> _develop() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDevelop(_minutes);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onRemove(_minutes);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  List<FilmChart> get _charts => <FilmChart>[
    for (final TestPrint print in widget.strip.prints)
      if (print.chart != null) print.chart!,
    if (_chart != null &&
        !widget.strip.prints.any(
          (TestPrint p) => p.chart?.minutes == _chart!.minutes,
        ))
      _chart!,
  ];

  List<double> get _curveTimes => _curves.keys.toList()..sort();

  List<List<double>> get _series {
    if (_curves.isNotEmpty) {
      return <List<double>>[
        for (final double time in _curveTimes) _curves[time]!.tone,
      ];
    }
    return <List<double>>[for (final FilmChart chart in _charts) _tone(chart)];
  }

  List<double>? get _xs {
    if (_curves.isNotEmpty) {
      return _curves[_curveTimes.first]!.logE;
    }
    final List<FilmChart> charts = _charts;
    if (charts.isEmpty) {
      return null;
    }
    FilmChart? selected;
    for (final FilmChart chart in charts) {
      if (chart.minutes == _minutes) {
        selected = chart;
        break;
      }
    }
    return (selected ?? charts.last).logE;
  }

  int? get _selectedCurve {
    if (_curves.isNotEmpty) {
      final int index = _curveTimes.indexWhere(
        (double time) => time == _minutes,
      );
      return index < 0 ? null : index;
    }
    final List<FilmChart> charts = _charts;
    final int index = charts.indexWhere(
      (FilmChart chart) => chart.minutes == _minutes,
    );
    return index < 0 ? null : index;
  }

  static List<double> _tone(FilmChart chart) => <double>[
    for (final List<double> patch in chart.patches)
      (patch[0] + patch[1] + patch[2]) / 3,
  ];

  FilmCurve? get _currentCurve => _curves[_minutes];

  FilmChart? get _currentChart {
    for (final FilmChart chart in _charts) {
      if (chart.minutes == _minutes) {
        return chart;
      }
    }
    return _chart;
  }

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    if (KalloLayout.isCompact(context)) {
      return _phone(colors, s);
    }
    if (widget.strip.photo == null) {
      return _benchEmpty(colors, s);
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (_cardOpen)
          const SingleActivator(LogicalKeyboardKey.escape): _closeCard,
        if (!_cardOpen && _compareOn)
          const SingleActivator(LogicalKeyboardKey.escape): _toggleCompare,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _bench(colors, s)),
            InspectorPane(
              key: const Key('develop-inspector'),
              open: widget.showInspector,
              child: _panel(colors, s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phone(KalloColors colors, KalloStrings s) {
    if (widget.strip.photo == null) {
      return ColoredBox(
        color: colors.ground,
        child: KalloMobileEmpty(
          glyph: KalloGlyph.photo,
          title: s.startWithPhoto,
          message: s.choosePhotoNote,
          action: SizedBox(
            width: 240,
            child: KalloMobileButton(
              label: s.choosePhoto,
              onTap: widget.onChoosePhoto,
            ),
          ),
          footnote: s.originalNote,
        ),
      );
    }
    return ColoredBox(
      color: colors.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: _phoneStage(colors, s)),
          _phoneDeck(colors, s),
        ],
      ),
    );
  }

  Widget _phoneStage(KalloColors colors, KalloStrings s) {
    final ui.Image? image = _preview ?? widget.photograph;
    final bool developed = _preview != null;
    final double aspect = image == null ? 1.5 : image.width / image.height;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints room) {
        final double width = math.min(
          room.maxWidth - 48,
          (room.maxHeight - 46) / PrintSheet.heightPerWidth(aspect: aspect),
        );
        return Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: image == null
                          ? null
                          : () {
                              if (_compareOn) {
                                _toggleCompare();
                                return;
                              }
                              showKalloImageViewer(
                                context,
                                image: image,
                                semanticLabel:
                                    widget.strip.name ?? s.testPrint,
                                caption:
                                    '${s.testPrint} · ${darkroomClock(_minutes)}',
                              );
                            },
                      child: KalloShadowBox(
                        kind: KalloShadowKind.paper,
                        child: PrintSheet(
                          width: math.max(180, width),
                          aspect: aspect,
                          paper: colors.print,
                          outline: colors.hairline,
                          footnote: _compareOn
                              ? _compareFooter(s, compact: true)
                              : null,
                          child: image == null
                              ? Center(
                                  child: Text(
                                    _busy ? s.developing : s.noTestPrintShort,
                                    textAlign: TextAlign.center,
                                    style: KalloMobileType.footnote.copyWith(
                                      color: KalloInk.muted,
                                    ),
                                  ),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    _picture(image),
                                    if (!developed)
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Container(
                                          height: 24,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          alignment: Alignment.center,
                                          color: const Color(0x991D1D1F),
                                          child: Text(
                                            s.noTestPrintShort,
                                            style: KalloMobileType.micro
                                                .copyWith(
                                                  color: const Color(
                                                    0xFFF5F5F7,
                                                  ),
                                                  fontSize: 8,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    if (developed && widget.photograph != null)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _ComparePill(
                          key: const Key('phone-compare'),
                          on: _compareOn,
                          onTap: _toggleCompare,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KalloMobileSpace.screen,
                0,
                KalloMobileSpace.screen,
                KalloMobileSpace.step1,
              ),
              child: GestureDetector(
                key: const Key('phone-materials-row'),
                behavior: HitTestBehavior.opaque,
                onTap: _openMaterialsPhone,
                child: SizedBox(
                  height: KalloMobileSpace.touch,
                  child: Row(
                    children: <Widget>[
                    Expanded(
                      child: Text(
                        '${stockDisplayName(widget.strip.stockLabel)}  ·  '
                        '${stockDisplayName(widget.strip.paperLabel ?? '')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KalloMobileType.footnote.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    KalloGlyphView(
                      KalloGlyph.chevronRight,
                      size: 9,
                      color: colors.inkMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s.testPrint,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkFaint,
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _phoneDeck(KalloColors colors, KalloStrings s) {
    final List<TestPrint> prints = widget.strip.prints;
    final TestPrint? exact = _printAt(_minutes);
    final bool hasPrints = prints.isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        KalloMobileSpace.step3,
        0,
        KalloMobileSpace.step3,
        KalloMobileSpace.step2,
      ),
      padding: const EdgeInsets.fromLTRB(
        KalloMobileSpace.step3,
        KalloMobileSpace.step3,
        KalloMobileSpace.step3,
        KalloMobileSpace.step3,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(KalloMobileRadius.card),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hasPrints
                      ? '${s.testStrip}   ${s.stripCount(prints.length)}'
                      : s.testStrip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KalloMobileType.caption.copyWith(
                    color: colors.inkMuted,
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              KalloIconButton(
                glyph: KalloGlyph.info,
                semanticLabel: s.details,
                onTap: _showDetails,
                size: 40,
                glyphSize: 18,
                foreground: colors.inkMuted,
              ),
              if (hasPrints && widget.onClearStrip != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _newStrip,
                  child: SizedBox(
                    height: KalloMobileSpace.touch,
                    child: Center(
                      child: Text(
                        s.newStrip,
                        style: KalloMobileType.footnote.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (hasPrints)
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 2),
                itemCount: prints.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: KalloMobileSpace.step2),
                itemBuilder: (BuildContext context, int index) {
                  final TestPrint print = prints[index];
                  return _Pegged(
                    key: _stripKey(print.minutes),
                    print: print,
                    selected: (print.minutes - _minutes).abs() < 1e-9,
                    compact: true,
                    onTap: () => _changed(print.minutes),
                    onLongPress: () => _removeAt(print.minutes),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: KalloMobileSpace.step1),
              child: Text(
                s.testStripHint,
                style: KalloMobileType.footnote.copyWith(
                  color: colors.inkFaint,
                ),
              ),
            ),
          const SizedBox(height: KalloMobileSpace.step2),
          Row(
            children: <Widget>[
              Text(
                darkroomClock(_minutes),
                style: KalloMobileType.plate.copyWith(color: colors.ink),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showTemperature,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.fill,
                    borderRadius: BorderRadius.circular(KalloMobileRadius.pill),
                  ),
                  child: Text(
                    '${widget.strip.tempC.toStringAsFixed(1)} °C',
                    style: KalloMobileType.footnote.copyWith(
                      color: colors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          TimeSlider(
            value: _minutes,
            ticks: _ladder,
            onChanged: _changed,
            onSettled: _settled,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: KalloMobileSpace.step1),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KalloMobileType.footnote.copyWith(color: colors.accent),
            ),
          ],
          KalloMobileButton(
            key: const Key('phone-develop'),
            label: _busy
                ? s.developing
                : '${exact == null ? s.developStep : s.redevelop} '
                      '${darkroomClock(_minutes)}',
            height: 46,
            onTap: _busy ? null : _develop,
          ),
        ],
      ),
    );
  }

  /// Start again on the same photograph and materials.
  Future<void> _newStrip() async {
    if (widget.onClearStrip == null || widget.strip.prints.isEmpty) {
      return;
    }
    final KalloStrings s = KalloStrings.of(context);
    final bool go = await showKalloConfirm(
      context,
      title: s.newStripQuestion,
      message: s.clearsPrints(widget.strip.prints.length),
      confirm: s.newStripAction,
    );
    if (go && mounted) {
      widget.onClearStrip!();
    }
  }

  Future<void> _removeAt(double minutes) async {
    if (_busy) {
      return;
    }
    setState(() => _minutes = minutes);
    await _remove();
  }

  Future<void> _showTemperature() async {
    final KalloStrings s = KalloStrings.of(context);
    double value = widget.strip.tempC;
    final double? next = await showKalloMobileSheet<double>(
      context,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) {
          return KalloMobileSheet(
            title: s.temperature,
            onClose: () => Navigator.of(sheetContext).pop(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                KalloMobileSpace.step5,
                0,
                KalloMobileSpace.step5,
                KalloMobileSpace.step5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${value.toStringAsFixed(1)} °C',
                    style: KalloMobileType.plate.copyWith(
                      color: KalloScope.colorsOf(context).ink,
                    ),
                  ),
                  const SizedBox(height: KalloMobileSpace.step4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      KalloIconButton(
                        glyph: KalloGlyph.minus,
                        semanticLabel: '−',
                        onTap: value <= _tempLow
                            ? null
                            : () =>
                                  setSheet(() => value = _nextTemp(-_tempStep)),
                        foreground: KalloScope.colorsOf(context).ink,
                        background: KalloScope.colorsOf(context).fill,
                        size: 48,
                      ),
                      const SizedBox(width: KalloMobileSpace.step5),
                      KalloIconButton(
                        glyph: KalloGlyph.plus,
                        semanticLabel: '+',
                        onTap: value >= _tempHigh
                            ? null
                            : () =>
                                  setSheet(() => value = _nextTemp(_tempStep)),
                        foreground: KalloScope.colorsOf(context).ink,
                        background: KalloScope.colorsOf(context).fill,
                        size: 48,
                      ),
                    ],
                  ),
                  const SizedBox(height: KalloMobileSpace.step4),
                  Text(
                    s.temperatureNote,
                    textAlign: TextAlign.center,
                    style: KalloMobileType.footnote.copyWith(
                      color: KalloScope.colorsOf(context).inkMuted,
                    ),
                  ),
                  const SizedBox(height: KalloMobileSpace.step5),
                  KalloMobileButton(
                    label: s.done,
                    onTap: () => Navigator.of(sheetContext).pop(value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (next == null || next == widget.strip.tempC || !mounted) {
      return;
    }
    if (widget.strip.hasPrints) {
      final bool go = await showKalloConfirm(
        context,
        title: s.changeTemperatureQuestion,
        message: s.clearsPrints(widget.strip.prints.length),
        confirm: s.changeAction,
      );
      if (!go) {
        return;
      }
    }
    widget.onTemperature(next);
  }

  Future<void> _showDetails() async {
    final KalloStrings s = KalloStrings.of(context);
    final FilmCurve? curve = _currentCurve;
    final FilmChart? chart = _currentChart;
    final List<double>? xs = _xs;
    await showKalloMobileSheet<void>(
      context,
      builder: (BuildContext sheetContext) => KalloMobileSheet(
        title: s.details,
        onClose: () => Navigator.of(sheetContext).pop(),
        height: MediaQuery.sizeOf(sheetContext).height * 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KalloMobileSpace.step5,
            0,
            KalloMobileSpace.step5,
            KalloMobileSpace.step5,
          ),
          children: <Widget>[
            Text(
              '${stockDisplayName(widget.strip.stockLabel)}   ·   '
              '${stockDisplayName(widget.strip.paperLabel ?? '')}',
              style: KalloMobileType.footnote.copyWith(
                color: KalloScope.colorsOf(context).inkMuted,
              ),
            ),
            const SizedBox(height: KalloMobileSpace.step4),
            Text(
              s.filmCurve,
              style: KalloMobileType.micro.copyWith(
                color: KalloScope.colorsOf(context).inkMuted,
              ),
            ),
            const SizedBox(height: KalloMobileSpace.step2),
            if (_series.isEmpty)
              Text(
                s.noCurve,
                style: KalloMobileType.footnote.copyWith(
                  color: KalloScope.colorsOf(context).inkMuted,
                ),
              )
            else
              KalloCurves(
                series: _series,
                selected: _selectedCurve,
                xs: xs,
                height: 170,
              ),
            if (curve != null) ...<Widget>[
              const SizedBox(height: KalloMobileSpace.step3),
              _Fact(label: s.gamma, value: _triple(curve.gamma)),
              _Fact(label: s.dMax, value: _triple(curve.dMax)),
            ] else if (chart != null) ...<Widget>[
              const SizedBox(height: KalloMobileSpace.step3),
              _Fact(label: s.gamma, value: _triple(chart.gamma)),
              _Fact(label: s.dMax, value: _triple(chart.dMax)),
            ],
            if (_paper != null) ...<Widget>[
              const SizedBox(height: KalloMobileSpace.step5),
              Text(
                s.paperCurve,
                style: KalloMobileType.micro.copyWith(
                  color: KalloScope.colorsOf(context).inkMuted,
                ),
              ),
              const SizedBox(height: KalloMobileSpace.step2),
              KalloCurves(
                series: <List<double>>[_paper!.density],
                xs: _paper!.logE,
                height: 96,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _benchEmpty(KalloColors colors, KalloStrings s) {
    return ColoredBox(
      color: colors.content,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: KalloSpace.step4),
            Text(
              s.choosePhotoNote,
              textAlign: TextAlign.center,
              style: KalloType.body.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloSpace.step5),
            SizedBox(
              width: 240,
              child: KalloButton(
                label: s.choosePhoto,
                onTap: widget.onChoosePhoto,
                filled: true,
                height: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bench(KalloColors colors, KalloStrings s) {
    final ui.Image? image = _preview;
    final double aspect = image == null ? 1.5 : image.width / image.height;
    final TestStrip strip = widget.strip;
    return ColoredBox(
      color: colors.content,
      child: Padding(
        // The step capsule floats over the bench; the work starts below it.
        padding: EdgeInsets.only(top: widget.topInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 18, 32, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _originalRow(colors, s),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints room) {
                    final double width = math.max(
                      160,
                      math.min(
                        room.maxWidth,
                        (room.maxHeight - 8) /
                            PrintSheet.heightPerWidth(aspect: aspect),
                      ),
                    );
                    return Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _cardOpen ? _closeCard : null,
                        child: PrintSheet(
                          key: const Key('bench-print'),
                          width: width,
                          aspect: aspect,
                          paper: colors.print,
                          outline: colors.hairline,
                          footnote: _compareOn
                              ? _compareFooter(s, compact: false)
                              : null,
                          child: image == null
                              ? Center(
                                  child: Text(
                                    _busy ? s.developing : s.noTestPrints,
                                    textAlign: TextAlign.center,
                                    style: KalloType.small.copyWith(
                                      color: KalloInk.muted,
                                    ),
                                  ),
                                )
                              : _picture(image),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              _materialsLine(colors, s),
              if (_cardOpen) ...<Widget>[
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints room) {
                    return MaterialsCard(
                      key: const Key('materials-card'),
                      catalogue: widget.catalogue,
                      filmId: strip.stockId,
                      paperId: strip.paperId,
                      time: darkroomClock(_minutes),
                      kind: _cardKind,
                      onKind: (MaterialsKind kind) =>
                          setState(() => _cardKind = kind),
                      height: math.min(
                        MaterialsCard.maxHeight,
                        math.max(200, room.maxHeight * 0.58),
                      ),
                      onFilm: (Stock film) => unawaited(_chooseFilm(film)),
                      onPaper: (Stock? paper) => unawaited(_choosePaper(paper)),
                    );
                  },
                ),
              ] else ...<Widget>[
                const SizedBox(height: 8),
                _clockRow(colors, s),
                const SizedBox(height: 10),
                _strip(colors, s),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _originalRow(KalloColors colors, KalloStrings s) {
    final bool canCompare = _preview != null && widget.photograph != null;
    return SizedBox(
      height: 24,
      child: Row(
        children: <Widget>[
          Text(
            s.theOriginal,
            style: KalloType.caption.copyWith(
              color: colors.inkFaint,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(width: KalloSpace.step3),
          Expanded(
            child: Text(
              widget.strip.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KalloType.small.copyWith(color: colors.inkMuted),
            ),
          ),
          if (canCompare) ...<Widget>[
            _Quiet(
              label: s.compare,
              onTap: _toggleCompare,
              accent: _compareOn,
            ),
            const SizedBox(width: KalloSpace.step5),
          ],
          _Quiet(
            label: s.changePhoto,
            onTap: () => unawaited(_changePhoto()),
            accent: true,
          ),
        ],
      ),
    );
  }

  /// The materials under the print are the print's caption and the shelf's two
  /// handles. Each handle lays the shelf on the bench with its own half open —
  /// the thing you want to change is the thing you click — and the same handle
  /// puts it away again.
  Widget _materialsLine(KalloColors colors, KalloStrings s) {
    final Color colour = _cardOpen ? colors.inkMuted : colors.inkFaint;
    final String film = stockDisplayName(widget.strip.stockLabel);
    final String paper = stockDisplayName(widget.strip.paperLabel ?? '');
    return SizedBox(
      height: 22,
      child: Row(
        key: const Key('materials-line'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: _MaterialHandle(
              key: const Key('materials-film'),
              label: s.film,
              value: film,
              open: _cardOpen && _cardKind == MaterialsKind.film,
              quiet: colour,
              onTap: () => _openCard(MaterialsKind.film),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KalloSpace.step2),
            child: Text(
              '·',
              style: KalloType.small.copyWith(color: colors.inkFaint),
            ),
          ),
          Flexible(
            child: _MaterialHandle(
              key: const Key('materials-paper'),
              label: s.paper,
              value: paper.isEmpty ? s.noMaterial : paper,
              open: _cardOpen && _cardKind == MaterialsKind.paper,
              quiet: colour,
              onTap: () => _openCard(MaterialsKind.paper),
            ),
          ),
          const SizedBox(width: 6),
          IgnorePointer(
            child: AnimatedRotation(
              turns: _cardOpen ? 0.25 : 0,
              duration: KalloMotion.quick,
              curve: KalloMotion.enter,
              child: KalloGlyphView(
                KalloGlyph.chevronRight,
                size: 9,
                color: colour,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clockRow(KalloColors colors, KalloStrings s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(darkroomClock(_minutes), style: KalloType.plate.copyWith(color: colors.ink)),
              Text(
                '${widget.strip.tempC.toStringAsFixed(1)} °C',
                style: KalloType.small.copyWith(color: colors.inkFaint),
              ),
            ],
          ),
        ),
        const SizedBox(width: KalloSpace.step3),
        Expanded(
          child: TimeSlider(
            value: _minutes,
            ticks: _ladder,
            onChanged: _changed,
            onSettled: _settled,
          ),
        ),
      ],
    );
  }

  /// The wipe's two sides, named in the paper's bottom margin. The picture
  /// itself is not written on: the margin is where a print is held.
  Widget _compareFooter(KalloStrings s, {required bool compact}) {
    final TextStyle style = (compact
            ? KalloMobileType.caption
            : KalloType.caption)
        .copyWith(
          fontSize: 8.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
          color: KalloInk.faint,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(s.theOriginal, style: style),
        Text(s.testPrint, style: style),
      ],
    );
  }

  /// The picture in the paper, with the original behind the wipe when the
  /// bench is reading the two against each other.
  Widget _picture(ui.Image image) {
    final ui.Image? original = widget.photograph;
    if (!_compareOn || original == null) {
      return RawImage(
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }
    final Widget wiped = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RawImage(
          image: image,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
        ClipRect(
          clipper: _WipeClipper(_compareAt),
          child: RawImage(
            image: original,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        if (box.maxWidth <= 0) {
          return wiped;
        }
        if (KalloLayout.isCompact(context)) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (DragStartDetails details) =>
                _setCompareAt(details.localPosition.dx / box.maxWidth),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                _setCompareAt(details.localPosition.dx / box.maxWidth),
            child: wiped,
          );
        }
        return MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          onHover: (PointerHoverEvent event) =>
              _setCompareAt(event.localPosition.dx / box.maxWidth),
          child: wiped,
        );
      },
    );
  }

  Widget _strip(KalloColors colors, KalloStrings s) {
    final List<TestPrint> prints = widget.strip.prints;
    return SizedBox(
      height: prints.isEmpty ? 84 : 122,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 98,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    s.testStrip,
                    style: KalloType.caption.copyWith(
                      color: colors.inkFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.stripCount(prints.length),
                    style: KalloType.small.copyWith(color: colors.inkMuted),
                  ),
                  if (prints.isEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      s.noTestPrints,
                      style: KalloType.small.copyWith(color: colors.inkFaint),
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 12),
                    _Quiet(
                      label: s.newStrip,
                      onTap: () => unawaited(_newStrip()),
                      accent: true,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final TestPrint print in prints)
                      _Pegged(
                        key: _stripKey(print.minutes),
                        print: print,
                        selected: (print.minutes - _minutes).abs() < 1e-9,
                        onTap: () => _changed(print.minutes),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(KalloColors colors, KalloStrings s) {
    final FilmChart? chart = _currentChart;
    final FilmCurve? curve = _currentCurve;
    final TestPrint? exact = _printAt(_minutes);
    final double? first = widget.strip.balanceFrom;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              // Stacked under the bench on a phone, the panel no longer sits
              // under the floating capsule; its text starts at its own edge.
              padding: EdgeInsets.fromLTRB(
                20,
                (MediaQuery.sizeOf(context).width < 700 ? 0 : widget.topInset) +
                    18,
                20,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  KalloStepper(
                    label: '${s.temperature}  ·  °C',
                    value: widget.strip.tempC.toStringAsFixed(1),
                    width: 264,
                    onMinus: _busy || widget.strip.tempC <= _tempLow
                        ? null
                        : () => unawaited(_changeTemperature(-_tempStep)),
                    onPlus: _busy || widget.strip.tempC >= _tempHigh
                        ? null
                        : () => unawaited(_changeTemperature(_tempStep)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.temperatureNote,
                    style: KalloType.small.copyWith(color: colors.inkFaint),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: colors.hairline),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Text(
                        s.filmCurve,
                        style: KalloType.caption.copyWith(
                          color: colors.inkFaint,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'log E →',
                        style: KalloType.folio.copyWith(color: colors.inkFaint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_series.isEmpty)
                    Text(
                      s.noCurve,
                      style: KalloType.small.copyWith(color: colors.inkFaint),
                    )
                  else
                    KalloCurves(
                      series: _series,
                      selected: _selectedCurve,
                      xs: _xs,
                      height: 104,
                    ),
                  if (curve != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _Fact(label: s.gamma, value: _triple(curve.gamma)),
                    _Fact(label: s.dMax, value: _triple(curve.dMax)),
                  ] else if (chart != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _Fact(label: s.gamma, value: _triple(chart.gamma)),
                    _Fact(label: s.dMax, value: _triple(chart.dMax)),
                  ],
                  const SizedBox(height: 18),
                  Container(height: 1, color: colors.hairline),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Text(
                        s.paperCurve,
                        style: KalloType.caption.copyWith(
                          color: colors.inkFaint,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(width: KalloSpace.step2),
                      Expanded(
                        child: Text(
                          stockDisplayName(
                            _paper?.short ?? widget.strip.paperLabel,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: KalloType.folio.copyWith(
                            color: colors.inkFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_paper != null)
                    KalloCurves(
                      series: <List<double>>[_paper!.density],
                      xs: _paper!.logE,
                      height: 54,
                    )
                  else
                    Text(
                      s.noCurve,
                      style: KalloType.small.copyWith(color: colors.inkFaint),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  first == null
                      ? s.testStripNote
                      : s.exposureOf(darkroomClock(first)),
                  style: KalloType.small.copyWith(color: colors.inkFaint),
                ),
                const SizedBox(height: KalloSpace.step2),
                KalloButton(
                  label: _busy
                      ? s.developing
                      : '${exact == null ? s.developStep : s.redevelop}  '
                            '${darkroomClock(_minutes)}',
                  onTap: _busy ? null : _develop,
                  filled: true,
                  height: 36,
                ),
                if (exact != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.center,
                    child: _Quiet(
                      label: s.removePrint,
                      onTap: _busy ? null : _remove,
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: KalloSpace.step2),
                  Text(
                    _error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: KalloType.small.copyWith(color: colors.accent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _nextTemp(double delta) =>
      (widget.strip.tempC + delta).clamp(_tempLow, _tempHigh).toDouble();

  static String _triple(List<double> values) =>
      values.map((double v) => v.toStringAsFixed(2)).join('  ');
}

/// One print on the test strip.
class _Pegged extends StatelessWidget {
  const _Pegged({
    super.key,
    required this.print,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final TestPrint print;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final ui.Image? image = print.image;
    final double aspect = image == null ? 1.5 : image.width / image.height;
    // The strip has one height, not one width: a portrait print narrows and a
    // landscape print widens, and every print stays whole on the paper. The
    // card includes its padding and its border, which is thicker when chosen.
    final double imageHeight = compact ? 36 : 88;
    final double imageWidth = (imageHeight * aspect).clamp(
      compact ? 28.0 : 44.0,
      compact ? 54.0 : 160.0,
    );
    final double border = selected ? 1.5 : 1;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: imageWidth + (compact ? 10 : 6) + border * 2,
          margin: EdgeInsets.only(
            right: compact ? KalloMobileSpace.step2 : KalloSpace.step3,
          ),
          padding: EdgeInsets.all(compact ? 2 : 3),
          decoration: BoxDecoration(
            color: colors.print,
            border: Border.all(
              color: selected ? colors.accent : colors.hairline,
              width: border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: imageHeight,
                width: imageWidth,
                child: image == null
                    ? const SizedBox.shrink()
                    : RawImage(
                        image: image,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
              SizedBox(height: compact ? 2 : 5),
              Text(
                print.clock,
                maxLines: 1,
                style: (compact ? KalloMobileType.caption : KalloType.folio)
                    .copyWith(
                      color: selected ? KalloInk.ink : KalloInk.muted,
                      fontSize: compact ? 8.5 : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: <Widget>[
          Text(label, style: KalloType.small.copyWith(color: colors.inkFaint)),
          const Spacer(),
          Text(value, style: KalloType.data.copyWith(color: colors.inkMuted)),
        ],
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.label, this.onTap, this.accent = false});

  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          style: KalloType.small.copyWith(
            color: onTap == null
                ? colors.inkFaint
                : accent
                ? colors.accent
                : colors.inkMuted,
            fontWeight: accent && onTap != null ? FontWeight.w500 : null,
          ),
        ),
      ),
    );
  }
}

/// One handle on the materials line: the slot's name and what is in it.
///
/// It is not a button: it is the caption under the print, made clickable. The
/// pointer closes the ink and the shelf comes up under it, which is the whole
/// of the affordance.
class _MaterialHandle extends StatefulWidget {
  const _MaterialHandle({
    super.key,
    required this.label,
    required this.value,
    required this.open,
    required this.quiet,
    required this.onTap,
  });

  final String label;
  final String value;

  /// Whether this slot is the half the shelf has open.
  final bool open;

  /// The caption's colour when nothing is happening.
  final Color quiet;

  final VoidCallback onTap;

  @override
  State<_MaterialHandle> createState() => _MaterialHandleState();
}

class _MaterialHandleState extends State<_MaterialHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final Color value = widget.open || _hover ? colors.ink : widget.quiet;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.label,
              style: KalloType.caption.copyWith(
                color: widget.quiet,
                fontSize: 9.5,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KalloType.small.copyWith(color: value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the phone's materials sheet was asked for.
enum _MaterialsAction { film, paper, photo }

/// The three things a strip is made of, on a phone.
///
/// The deck is full of the strip's instruments, so the materials are one row
/// under the paper that opens this sheet: the film, the paper, and the
/// photograph the strip is of.
class _PhoneMaterialsSheet extends StatelessWidget {
  const _PhoneMaterialsSheet({
    required this.film,
    required this.filmNote,
    required this.paper,
    required this.paperNote,
    required this.photo,
    required this.onFilm,
    required this.onPaper,
    required this.onPhoto,
  });

  final String film;
  final String filmNote;
  final String paper;
  final String paperNote;
  final String photo;

  final VoidCallback onFilm;
  final VoidCallback onPaper;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    return KalloMobileSheet(
      title: s.materials,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KalloMobileRow(
            title: film,
            subtitle: filmNote.isEmpty ? s.film : filmNote,
            minHeight: 64,
            leading: const _SheetGlyph(glyph: KalloGlyph.film),
            onTap: onFilm,
          ),
          const KalloMobileDivider(inset: 64),
          KalloMobileRow(
            title: paper,
            subtitle: paperNote.isEmpty ? s.paper : paperNote,
            minHeight: 64,
            leading: const _SheetGlyph(glyph: KalloGlyph.paper, accent: true),
            onTap: onPaper,
          ),
          const KalloMobileDivider(inset: 64),
          KalloMobileRow(
            title: photo,
            subtitle: s.theOriginal,
            minHeight: 64,
            leading: const _SheetGlyph(glyph: KalloGlyph.photo),
            onTap: onPhoto,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Text(
              s.materialsNote,
              style: KalloMobileType.footnote.copyWith(color: colors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetGlyph extends StatelessWidget {
  const _SheetGlyph({required this.glyph, this.accent = false});

  final KalloGlyph glyph;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent ? colors.accentSoft : colors.fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: KalloGlyphView(
          glyph,
          size: 18,
          color: accent ? colors.accent : colors.inkMuted,
          stroke: 1.5,
        ),
      ),
    );
  }
}

/// The bench's compare switch, on the print.
class _ComparePill extends StatelessWidget {
  const _ComparePill({super.key, required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? colors.accent : const Color(0x8A121214),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            KalloStrings.of(context).compare,
            style: KalloMobileType.micro.copyWith(
              color: on ? colors.onAccent : const Color(0xFFF5F5F7),
              fontSize: 9,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// The wipe: the original fills the left of the picture, the print the right,
/// and the seam between them is the only line and the whole control.
class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_WipeClipper old) => old.fraction != fraction;
}
