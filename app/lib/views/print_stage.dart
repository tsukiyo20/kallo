import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../design/mobile.dart';
import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/chart.dart';
import '../lab/clock.dart';
import '../lab/edge_print.dart';
import '../lab/export_format.dart';
import '../lab/model.dart';
import '../lab/preview_bench.dart';
import '../lab/render_mode.dart';
import '../lab/print_request.dart';
import '../lab/stock.dart';
import '../lab/strip.dart';
import '../lab/strip_develop.dart';
import '../widgets/border_tray.dart';
import '../widgets/button.dart';
import '../widgets/chip.dart';
import '../widgets/curves.dart';
import '../widgets/export_sheet.dart';
import '../widgets/inspector.dart';
import '../widgets/mobile/mobile_controls.dart';
import '../widgets/mobile/mobile_icon.dart';
import '../widgets/mobile/mobile_sheet.dart';
import '../widgets/shadow_box.dart';
import '../widgets/stepper.dart';
import '../widgets/wall.dart';

/// The third step: the negative chosen on the strip, printed as a picture.
///
/// The test strip is one exposure; this is the enlarger dialled. The timer, the
/// colour pack and the heat glass are the three things a printer actually
/// changes, so they are the three controls — and the paper underneath them is
/// the print they make, at the size a print is.
class PrintStage extends StatefulWidget {
  const PrintStage({
    super.key,
    required this.strip,
    required this.paperName,
    required this.exports,
    required this.onPrint,
    this.filmName = '',
    this.filmProcess,
    required this.onGoDevelop,
    required this.onGoRack,
    this.showInspector = true,
    this.topInset = 0,
  });

  final TestStrip strip;
  final String paperName;
  final Directory? exports;

  /// The film's own name, as its edge prints it: the stock the print came from.
  final String filmName;

  /// The chemistry the film is, which the edge's process mark names.
  final FilmProcess? filmProcess;
  final Future<void> Function(PrintRequest request) onPrint;
  final VoidCallback onGoDevelop;
  final VoidCallback onGoRack;

  /// Whether the instrument panel is open.
  final bool showInspector;

  /// The transparent chrome at the top of the window.
  final double topInset;

  @override
  State<PrintStage> createState() => _PrintStageState();
}

class _PrintStageState extends State<PrintStage> {
  late double _minutes;
  double _printEv = 0;
  int _yellow = 0;
  int _magenta = 0;
  int _cyan = 0;
  String? _glass;

  ui.Image? _preview;
  PrintCurve? _curve;
  int _curveGeneration = 0;
  bool _busy = false;
  bool _printed = false;
  String? _error;

  /// The edge printed into the print. A print without one is cropped to the
  /// frame; the templates are readings of the same film edge.
  BorderTemplate _border = BorderTemplate.none;

  /// Whether the row of edge proofs is out on the bench.
  bool _trayOpen = false;

  Timer? _timer;
  Timer? _toastTimer;
  bool _toast = false;
  int _generation = 0;
  PreviewBench? _previewBench;
  String? _benchKey;

  @override
  void initState() {
    super.initState();
    _minutes = widget.strip.latest?.minutes ?? 9;
    _openBench();
    if (widget.strip.hasPrints) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _previewNow();
        unawaited(_loadPrintCurve());
      });
    }
  }

  @override
  void didUpdateWidget(PrintStage old) {
    super.didUpdateWidget(old);
    if (old.strip != widget.strip) {
      if (!widget.strip.hasPrints) {
        _preview?.dispose();
        _preview = null;
        _previewBench?.dispose();
        _previewBench = null;
        _benchKey = null;
        return;
      }
      if (!widget.strip.prints.any((TestPrint p) => p.minutes == _minutes)) {
        _minutes = widget.strip.latest!.minutes;
      }
      if (_benchKey != _benchKeyFor(widget.strip)) {
        _generation++;
        _openBench();
      }
      _schedule();
      unawaited(_loadPrintCurve());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _toastTimer?.cancel();
    _generation++;
    _curveGeneration++;
    _preview?.dispose();
    _previewBench?.dispose();
    super.dispose();
  }

  String _benchKeyFor(TestStrip strip) =>
      '${strip.photo}|${strip.stockId}|${strip.paperId}|'
      '${strip.tempC}|${strip.spectral}|${RenderPreference.mode.name}';

  void _openBench() {
    final String key = _benchKeyFor(widget.strip);
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

  String get _filters => <String>[
    if (_yellow > 0) '${_yellow}Y',
    if (_magenta > 0) '${_magenta}M',
    if (_cyan > 0) '${_cyan}C',
  ].join('+');

  void _changed() {
    setState(() {
      _printed = false;
      _error = null;
    });
    _schedule();
    unawaited(_loadPrintCurve());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 120), _previewNow);
  }

  /// The print's three channel curves, each one density per log E.
  ///
  /// The model returns one sample per exposure with three densities; the chart
  /// wants the other way round, three curves over the one exposure axis.
  List<List<double>>? get _printSeries {
    final PrintCurve? curve = _curve;
    if (curve == null) {
      return null;
    }
    return <List<double>>[
      for (int channel = 0; channel < 3; channel++)
        <double>[
          for (final List<double> sample in curve.density) sample[channel],
        ],
    ];
  }

  /// The paper's curve under the enlarger as it is dialled now.
  ///
  /// The timer, the colour pack and the heat glass all move the balance; the
  /// curve is the paper through that balance, not a second picture of it.
  Future<void> _loadPrintCurve() async {
    if (!widget.strip.hasPrints) {
      return;
    }
    final Model model = Model.find();
    if (!model.available) {
      return;
    }
    final int generation = ++_curveGeneration;
    final double minutes = _minutes;
    final double printEv = _printEv;
    final String filters = _filters;
    final String? glass = _glass;
    try {
      final PrintCurve? curve = await model.printCurve(
        film: widget.strip.stockId,
        paper: widget.strip.paperId ?? Stocks.paper,
        minutes: minutes,
        tempC: widget.strip.tempC,
        printEv: printEv,
        filters: filters,
        heatGlass: glass,
        spectral: widget.strip.spectral,
      );
      if (!mounted || generation != _curveGeneration) {
        return;
      }
      setState(() => _curve = curve);
    } on Object catch (error) {
      Model.log('the print curve could not be read: $error');
    }
  }

  Future<void> _previewNow() async {
    if (!widget.strip.hasPrints) {
      return;
    }
    final Model model = Model.find();
    final int generation = ++_generation;
    final double minutes = _minutes;
    final double printEv = _printEv;
    final String filters = _filters;
    final String? glass = _glass;
    if (!model.available) {
      if (mounted) {
        setState(() => _error = KalloStrings.of(context).noModel);
      }
      return;
    }
    try {
      ui.Image? image;
      try {
        image = await _previewBench?.frame(
          minutes: minutes,
          printEv: printEv,
          filters: filters,
          heatGlass: glass,
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
        image = await previewFinalPrint(
          model: model,
          strip: widget.strip,
          minutes: minutes,
          printEv: printEv,
          filters: filters,
          heatGlass: glass,
        );
      }
      final ui.Image rendered = image;
      if (!mounted || generation != _generation) {
        rendered.dispose();
        return;
      }
      final ui.Image? old = _preview;
      setState(() => _preview = rendered);
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<void> _choosePrint() async {
    if (_busy || widget.exports == null || !widget.strip.hasPrints) {
      return;
    }
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
    if (options == null || !mounted) {
      return;
    }
    await _print(options);
  }

  Future<void> _print(ExportOptions options) async {
    if (_busy || widget.exports == null || !widget.strip.hasPrints) {
      return;
    }
    setState(() {
      _busy = true;
      _printed = false;
      _error = null;
      _trayOpen = false;
    });
    try {
      await widget.onPrint(
        PrintRequest(
          minutes: _minutes,
          printEv: _printEv,
          filters: _filters,
          heatGlass: _glass,
          width: options.size,
          format: options.format,
          border: _border,
        ),
      );
      if (mounted) {
        _toastTimer?.cancel();
        setState(() {
          _printed = true;
          _toast = true;
        });
        _toastTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _toast = false);
          }
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    if (!widget.strip.hasPrints) {
      return ColoredBox(
        color: colors.content,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                s.chooseFirstPrint,
                style: KalloType.body.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: KalloSpace.step4),
              KalloButton(
                label: s.goDevelop,
                onTap: widget.onGoDevelop,
                filled: true,
                height: 34,
              ),
            ],
          ),
        ),
      );
    }
    if (KalloLayout.isCompact(context)) {
      return _phone(colors, s);
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (_trayOpen)
          const SingleActivator(LogicalKeyboardKey.escape): _closeTray,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _bench(colors, s)),
            InspectorPane(
              key: const Key('print-inspector'),
              open: widget.showInspector,
              child: _panel(colors, s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phone(KalloColors colors, KalloStrings s) {
    if (!widget.strip.hasPrints) {
      return ColoredBox(
        color: colors.ground,
        child: KalloMobileEmpty(
          glyph: KalloGlyph.paper,
          title: s.noTestPrintShort,
          message: s.chooseFirstPrint,
          action: SizedBox(
            width: 240,
            child: KalloMobileButton(
              label: s.goDevelop,
              onTap: widget.onGoDevelop,
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: colors.ground,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _phoneStage(colors, s)),
              _phoneDeck(colors, s),
            ],
          ),
          if (_toast)
            Positioned(
              left: KalloMobileSpace.step4,
              right: KalloMobileSpace.step4,
              top: KalloMobileSpace.step2,
              child: _PhoneToast(
                label: s.printedToast,
                action: s.view,
                onAction: widget.onGoRack,
                onClose: () => setState(() => _toast = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _phoneStage(KalloColors colors, KalloStrings s) {
    final ui.Image? image = _preview;
    final double aspect = image == null ? 1.5 : _aspectOf(image);
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: image == null
                      ? null
                      : () => showKalloImageViewer(
                          context,
                          image: image,
                          semanticLabel: widget.strip.name ?? s.printAction,
                          caption:
                              '${darkroomClock(_minutes)} · '
                              '${_filters.isEmpty ? s.noGlass : _filters}',
                        ),
                  child: KalloShadowBox(
                    kind: KalloShadowKind.paper,
                    child: PrintSheet(
                      width: math.max(180, width),
                      aspect: aspect,
                      paper: colors.print,
                      outline: colors.hairline,
                      child: image == null
                          ? Center(
                              child: Text(
                                _busy ? s.printing : s.printNote,
                                textAlign: TextAlign.center,
                                style: KalloMobileType.footnote.copyWith(
                                  color: KalloInk.muted,
                                ),
                              ),
                            )
                          : _picture(image),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KalloMobileSpace.screen,
                KalloMobileSpace.step1,
                KalloMobileSpace.screen,
                KalloMobileSpace.step2,
              ),
              child: Text(
                '${darkroomClock(_minutes)}   ·   '
                '${_printEv >= 0 ? '+' : ''}${_printEv.toStringAsFixed(1)} EV'
                '${_filters.isEmpty ? '' : '   ·   $_filters'}'
                '${_glass == null ? '' : '   ·   ${_glass!.toUpperCase()}'}',
                textAlign: TextAlign.center,
                style: KalloMobileType.footnote.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _phoneDeck(KalloColors colors, KalloStrings s) {
    final bool printable = widget.exports != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        KalloMobileSpace.step3,
        0,
        KalloMobileSpace.step3,
        KalloMobileSpace.step2,
      ),
      padding: const EdgeInsets.all(KalloMobileSpace.step3),
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
                child: _PhoneControl(
                  label: s.time,
                  value: darkroomClock(_minutes),
                  onTap: _showTime,
                ),
              ),
              const SizedBox(width: KalloMobileSpace.step2),
              Expanded(
                child: _PhoneControl(
                  label: s.exposure,
                  value:
                      '${_printEv >= 0 ? '+' : ''}${_printEv.toStringAsFixed(1)} EV',
                  onTap: _showExposure,
                ),
              ),
            ],
          ),
          const SizedBox(height: KalloMobileSpace.step2),
          Row(
            children: <Widget>[
              Expanded(
                child: _PhoneControl(
                  label: s.balance,
                  value: 'Y$_yellow M$_magenta C$_cyan',
                  onTap: _showFilters,
                ),
              ),
              const SizedBox(width: KalloMobileSpace.step2),
              Expanded(
                child: _PhoneControl(
                  label: s.glass,
                  value: _glass?.toUpperCase() ?? s.noGlass,
                  onTap: _showGlass,
                ),
              ),
            ],
          ),
          const SizedBox(height: KalloMobileSpace.step2),
          _PhoneBorderRow(
            label: s.border,
            image: _preview,
            template: _border,
            film: widget.filmName,
            process: widget.filmProcess,
            onTap: _showBorderPhone,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: KalloMobileSpace.step2),
            Text(
              _error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KalloMobileType.footnote.copyWith(color: colors.accent),
            ),
          ],
          if (!printable) ...<Widget>[
            const SizedBox(height: KalloMobileSpace.step2),
            Text(
              s.noFolder,
              style: KalloMobileType.footnote.copyWith(color: colors.inkMuted),
            ),
          ],
          const SizedBox(height: KalloMobileSpace.step3),
          KalloMobileButton(
            key: const Key('phone-print'),
            label: _busy ? s.printing : s.printAction,
            height: 46,
            onTap: printable && !_busy ? _choosePrintPhone : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showTime() async {
    final KalloStrings s = KalloStrings.of(context);
    final String? choice = await showKalloMobileChoices(
      context,
      title: s.time,
      choices: <KalloMobileChoice>[
        for (final TestPrint print in widget.strip.prints)
          KalloMobileChoice(
            value: print.minutes.toString(),
            label: print.clock,
            subtitle: s.exposureOf(darkroomClock(print.minutes)),
            selected: print.minutes == _minutes,
          ),
      ],
    );
    if (choice == null || !mounted) {
      return;
    }
    final double? minutes = double.tryParse(choice);
    if (minutes == null || minutes == _minutes) {
      return;
    }
    setState(() => _minutes = minutes);
    _changed();
  }

  Future<void> _showExposure() async {
    final KalloStrings s = KalloStrings.of(context);
    double value = _printEv;
    final double? next = await showKalloMobileSheet<double>(
      context,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) =>
            KalloMobileSheet(
              title: s.exposure,
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
                      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} EV',
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
                          onTap: value <= -2
                              ? null
                              : () => setSheet(
                                  () => value = double.parse(
                                    (value - 0.1).toStringAsFixed(1),
                                  ),
                                ),
                          foreground: KalloScope.colorsOf(context).ink,
                          background: KalloScope.colorsOf(context).fill,
                          size: 48,
                        ),
                        const SizedBox(width: KalloMobileSpace.step5),
                        KalloIconButton(
                          glyph: KalloGlyph.plus,
                          semanticLabel: '+',
                          onTap: value >= 2
                              ? null
                              : () => setSheet(
                                  () => value = double.parse(
                                    (value + 0.1).toStringAsFixed(1),
                                  ),
                                ),
                          foreground: KalloScope.colorsOf(context).ink,
                          background: KalloScope.colorsOf(context).fill,
                          size: 48,
                        ),
                      ],
                    ),
                    const SizedBox(height: KalloMobileSpace.step5),
                    KalloMobileButton(
                      label: s.done,
                      onTap: () => Navigator.of(sheetContext).pop(value),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
    if (next == null || !mounted || next == _printEv) {
      return;
    }
    setState(() => _printEv = next);
    _changed();
  }

  Future<void> _showFilters() async {
    final KalloStrings s = KalloStrings.of(context);
    int y = _yellow;
    int m = _magenta;
    int c = _cyan;
    final bool? apply = await showKalloMobileSheet<bool>(
      context,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) =>
            KalloMobileSheet(
              title: s.balance,
              onClose: () => Navigator.of(sheetContext).pop(false),
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
                    _PhoneColour(
                      label: 'Y',
                      value: y,
                      onChanged: (int next) => setSheet(() => y = next),
                    ),
                    _PhoneColour(
                      label: 'M',
                      value: m,
                      onChanged: (int next) => setSheet(() => m = next),
                    ),
                    _PhoneColour(
                      label: 'C',
                      value: c,
                      onChanged: (int next) => setSheet(() => c = next),
                    ),
                    const SizedBox(height: KalloMobileSpace.step3),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setSheet(() {
                        y = 0;
                        m = 0;
                        c = 0;
                      }),
                      child: SizedBox(
                        height: KalloMobileSpace.touch,
                        child: Center(
                          child: Text(
                            s.reset,
                            style: KalloMobileType.footnote.copyWith(
                              color: KalloScope.colorsOf(context).inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: KalloMobileSpace.step3),
                    KalloMobileButton(
                      label: s.done,
                      onTap: () => Navigator.of(sheetContext).pop(true),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
    if (apply != true || !mounted) {
      return;
    }
    setState(() {
      _yellow = y;
      _magenta = m;
      _cyan = c;
    });
    _changed();
  }

  Future<void> _showGlass() async {
    final KalloStrings s = KalloStrings.of(context);
    final String? choice = await showKalloMobileChoices(
      context,
      title: s.glass,
      choices: <KalloMobileChoice>[
        KalloMobileChoice(
          value: '',
          label: s.noGlass,
          selected: _glass == null,
        ),
        for (final String glass in <String>['kg1', 'kg2', 'kg3', 'kg5'])
          KalloMobileChoice(
            value: glass,
            label: glass.toUpperCase(),
            selected: _glass == glass,
          ),
      ],
    );
    if (choice == null || !mounted) {
      return;
    }
    final String? next = choice.isEmpty ? null : choice;
    if (next == _glass) {
      return;
    }
    setState(() => _glass = next);
    _changed();
  }

  Future<void> _showBorderPhone() async {
    final KalloStrings s = KalloStrings.of(context);
    await showKalloMobileSheet<void>(
      context,
      builder: (BuildContext sheetContext) => KalloMobileSheet(
        child: _PhoneBorderSheet(
          image: _preview,
          selected: _border,
          film: widget.filmName,
          process: widget.filmProcess,
          labelOf: s.borderName,
          onSelect: (BorderTemplate template) {
            if (template == _border) {
              return;
            }
            setState(() => _border = template);
          },
        ),
      ),
    );
  }

  Future<void> _choosePrintPhone() async {
    if (_busy || widget.exports == null || !widget.strip.hasPrints) {
      return;
    }
    final KalloStrings s = KalloStrings.of(context);
    final ExportOptions? options = await showKalloMobileSheet<ExportOptions>(
      context,
      builder: (BuildContext sheetContext) => _PhonePrintOptions(
        title: s.printAction,
        sizes: <ExportSize>[
          ExportSize(s.originalSize, null),
          const ExportSize('6000 px', 6000),
          const ExportSize('4000 px', 4000),
        ],
        formats: const <ExportFormat>[ExportFormat.png, ExportFormat.jpeg],
      ),
    );
    if (options == null || !mounted) {
      return;
    }
    await _print(options);
  }

  /// The shape the print has on the bench: the picture's, or the picture with
  /// the chosen edge around it.
  double _aspectOf(ui.Image image) {
    final double aspect = image.width / image.height;
    if (_border == BorderTemplate.none) {
      return aspect;
    }
    return EdgePrintMetrics.fromImageWidth(
      image.width.toDouble(),
      aspect: aspect,
    ).aspect;
  }

  /// The print as it will be written: the picture, and the edge when one is
  /// chosen.
  Widget _picture(ui.Image image) {
    if (_border == BorderTemplate.none) {
      return RawImage(
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }
    return CustomPaint(
      painter: EdgePrintPainter(
        image: image,
        source: Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        film: widget.filmName,
        process: widget.filmProcess,
        template: _border,
      ),
    );
  }

  /// The bench's edge is the edge the next print carries; choosing one is a
  /// preview, not a print.
  void _selectBorder(BorderTemplate template) {
    if (template == _border) {
      return;
    }
    setState(() => _border = template);
  }

  void _toggleTray() => setState(() => _trayOpen = !_trayOpen);

  void _closeTray() {
    if (!_trayOpen) {
      return;
    }
    setState(() => _trayOpen = false);
  }

  Widget _bench(KalloColors colors, KalloStrings s) {
    final ui.Image? image = _preview;
    final double aspect = image == null ? 1.5 : _aspectOf(image);
    // The tray is a card lying on the bench: it takes its own height, the room
    // above it and its bottom margin, and the proof is sized from what is left.
    return ColoredBox(
      color: colors.content,
      child: Padding(
        // The step capsule floats over the bench; a print never starts under
        // it, even when the picture is taller than the room.
        padding: EdgeInsets.only(top: widget.topInset),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints room) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _trayOpen ? 1 : 0),
              duration: KalloMotion.settle,
              curve: KalloMotion.enter,
              builder: (BuildContext context, double open, Widget? _) {
                final double width = math.max(
                  220,
                  math.min(
                    math.max(240, room.maxWidth - 140),
                    (room.maxHeight -
                            150 -
                            (borderTrayHeightIn(
                                      room.maxWidth - 56,
                                      borderAspectOf(image),
                                    ) +
                                    44) *
                                open) /
                        PrintSheet.heightPerWidth(aspect: aspect),
                  ),
                );
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _trayOpen ? _closeTray : null,
                              child: Center(
                                child: PrintSheet(
                                  key: const Key('bench-print'),
                                  width: width,
                                  aspect: aspect,
                                  paper: colors.print,
                                  outline: colors.hairline,
                                  child: image == null
                                      ? Center(
                                          child: Text(
                                            _busy ? s.printing : s.printNote,
                                            textAlign: TextAlign.center,
                                            style: KalloType.small.copyWith(
                                              color: KalloInk.muted,
                                            ),
                                          ),
                                        )
                                      : _picture(image),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 44,
                            child: Opacity(
                              opacity: 1 - open,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    40,
                                    0,
                                    40,
                                    24,
                                  ),
                                  child: Text(
                                    '${darkroomClock(_minutes)}   ·   '
                                    '${_printEv >= 0 ? '+' : ''}'
                                    '${_printEv.toStringAsFixed(1)} EV'
                                    '${_filters.isEmpty ? '' : '   ·   $_filters'}'
                                    '${_glass == null ? '' : '   ·   ${_glass!.toUpperCase()}'}',
                                    style: KalloType.data.copyWith(
                                      color: colors.inkMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (open > 0.001)
                      Positioned(
                        left: 28,
                        right: 28,
                        bottom: 20 + (1 - open) * 24,
                        child: Opacity(
                          opacity: open,
                          child: BorderTray(
                            key: const Key('border-tray'),
                            image: image,
                            selected: _border,
                            film: widget.filmName,
                            process: widget.filmProcess,
                            labelOf: s.borderName,
                            onSelect: _selectBorder,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _panel(KalloColors colors, KalloStrings s) {
    final bool printable = widget.exports != null;
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
                  Text(
                    '${stockDisplayName(widget.strip.stockLabel)}   ·   '
                    '${widget.paperName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KalloType.small.copyWith(color: colors.inkFaint),
                  ),
                  const SizedBox(height: KalloSpace.step4),
                  Text(
                    s.time,
                    style: KalloType.caption.copyWith(
                      color: colors.inkFaint,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: KalloSpace.step2),
                  Wrap(
                    spacing: KalloSpace.step1 + 2,
                    runSpacing: KalloSpace.step1 + 2,
                    children: <Widget>[
                      for (final TestPrint print in widget.strip.prints)
                        KalloChip(
                          label: print.clock,
                          selected: (print.minutes - _minutes).abs() < 1e-9,
                          onTap: () {
                            setState(() => _minutes = print.minutes);
                            _changed();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: KalloSpace.step5),
                  Container(height: 1, color: colors.hairline),
                  const SizedBox(height: KalloSpace.step4),
                  Text(
                    '${s.printExposure}  ·  EV',
                    style: KalloType.caption.copyWith(
                      color: colors.inkFaint,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: KalloSpace.step2),
                  KalloStepper(
                    label: s.exposure,
                    value:
                        '${_printEv >= 0 ? '+' : ''}${_printEv.toStringAsFixed(1)}',
                    width: 264,
                    onMinus: _printEv <= -2
                        ? null
                        : () {
                            setState(
                              () => _printEv = double.parse(
                                (_printEv - 0.1).toStringAsFixed(1),
                              ),
                            );
                            _changed();
                          },
                    onPlus: _printEv >= 2
                        ? null
                        : () {
                            setState(
                              () => _printEv = double.parse(
                                (_printEv + 0.1).toStringAsFixed(1),
                              ),
                            );
                            _changed();
                          },
                  ),
                  const SizedBox(height: KalloSpace.step4),
                  Text(
                    '${s.filters}  ·  CC',
                    style: KalloType.caption.copyWith(
                      color: colors.inkFaint,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: KalloSpace.step2),
                  _colour('Y', _yellow, (int next) {
                    setState(() => _yellow = next);
                    _changed();
                  }),
                  _colour('M', _magenta, (int next) {
                    setState(() => _magenta = next);
                    _changed();
                  }),
                  _colour('C', _cyan, (int next) {
                    setState(() => _cyan = next);
                    _changed();
                  }),
                  const SizedBox(height: KalloSpace.step4),
                  Text(
                    s.heatGlass,
                    style: KalloType.caption.copyWith(
                      color: colors.inkFaint,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: KalloSpace.step2),
                  Wrap(
                    spacing: KalloSpace.step1 + 2,
                    runSpacing: KalloSpace.step1 + 2,
                    children: <Widget>[
                      KalloChip(
                        label: s.noGlass,
                        selected: _glass == null,
                        compact: true,
                        onTap: () {
                          setState(() => _glass = null);
                          _changed();
                        },
                      ),
                      for (final String glass in <String>[
                        'kg1',
                        'kg2',
                        'kg3',
                        'kg5',
                      ])
                        KalloChip(
                          label: glass.toUpperCase(),
                          selected: _glass == glass,
                          compact: true,
                          onTap: () {
                            setState(() => _glass = glass);
                            _changed();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: KalloSpace.step4),
                  Row(
                    children: <Widget>[
                      Text(
                        s.border,
                        style: KalloType.small.copyWith(color: colors.inkMuted),
                      ),
                      const Spacer(),
                      BorderButton(
                        key: const Key('border-button'),
                        image: _preview,
                        template: _border,
                        label: s.borderName(_border),
                        film: widget.filmName,
                        process: widget.filmProcess,
                        open: _trayOpen,
                        onTap: _toggleTray,
                      ),
                    ],
                  ),
                  const SizedBox(height: KalloSpace.step5),
                  Container(height: 1, color: colors.hairline),
                  const SizedBox(height: KalloSpace.step4),
                  Row(
                    children: <Widget>[
                      Text(
                        s.printCurve,
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
                  const SizedBox(height: 6),
                  if (_curve != null)
                    KalloCurves(
                      series: _printSeries!,
                      xs: _curve!.logE,
                      height: 62,
                    )
                  else
                    Text(
                      s.noCurve,
                      style: KalloType.small.copyWith(color: colors.inkFaint),
                    ),
                  const SizedBox(height: KalloSpace.step4),
                  Text(
                    s.printNote,
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
                if (!printable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KalloSpace.step2),
                    child: Text(
                      s.noFolder,
                      style: KalloType.small.copyWith(color: colors.inkFaint),
                    ),
                  ),
                KalloButton(
                  label: _busy ? s.printing : s.printAction,
                  onTap: printable && !_busy ? () => _choosePrint() : null,
                  filled: true,
                  height: 36,
                ),
                if (_printed) ...<Widget>[
                  const SizedBox(height: KalloSpace.step2),
                  Text(
                    s.printQueued,
                    style: KalloType.small.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: KalloSpace.step2),
                  KalloButton(
                    label: s.goRack,
                    onTap: widget.onGoRack,
                    height: 30,
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

  Widget _colour(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: KalloStepper(
        label: label,
        value: '$value',
        width: 264,
        onMinus: value <= 0 ? null : () => onChanged(value - 5),
        onPlus: value >= 100 ? null : () => onChanged(value + 5),
      ),
    );
  }
}

/// The phone's edge row in the deck: the label, the print as it will be, and
/// the way into the sheet.
class _PhoneBorderRow extends StatelessWidget {
  const _PhoneBorderRow({
    required this.label,
    required this.image,
    required this.template,
    required this.film,
    required this.process,
    required this.onTap,
  });

  final String label;
  final ui.Image? image;
  final BorderTemplate template;
  final String? film;
  final FilmProcess? process;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final double height = KalloMobileSpace.touch + 10;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: KalloMobileType.callout.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              BorderProof(
                image: image,
                template: template,
                film: film,
                process: process,
                height: height - 16,
              ),
              const SizedBox(width: 4),
              KalloGlyphView(
                KalloGlyph.chevronRight,
                size: 14,
                color: colors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sheet of edge proofs on a phone: pictures, no words, a tap to take one.
///
/// The sheet stays open after a tap — the proof above it changes — so the six
/// edges can be compared without opening and closing the sheet each time.
class _PhoneBorderSheet extends StatefulWidget {
  const _PhoneBorderSheet({
    required this.image,
    required this.selected,
    required this.film,
    required this.process,
    required this.labelOf,
    required this.onSelect,
  });

  final ui.Image? image;
  final BorderTemplate selected;
  final String? film;
  final FilmProcess? process;
  final String Function(BorderTemplate template) labelOf;
  final ValueChanged<BorderTemplate> onSelect;

  @override
  State<_PhoneBorderSheet> createState() => _PhoneBorderSheetState();
}

class _PhoneBorderSheetState extends State<_PhoneBorderSheet> {
  late BorderTemplate _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    const double proofWidth = 104;
    final double tileHeight = borderTileHeight(
      proofWidth,
      borderAspectOf(widget.image),
    );
    return Padding(
      key: const Key('phone-border'),
      padding: const EdgeInsets.fromLTRB(
        KalloMobileSpace.step3,
        KalloMobileSpace.step2,
        KalloMobileSpace.step3,
        KalloMobileSpace.step5,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          for (final BorderTemplate template in BorderTemplate.values)
            BorderTile(
              key: Key('phone-border-${template.name}'),
              image: widget.image,
              template: template,
              label: widget.labelOf(template),
              selected: _selected == template,
              film: widget.film,
              process: widget.process,
              proofWidth: proofWidth,
              tileHeight: tileHeight,
              onTap: () {
                setState(() => _selected = template);
                widget.onSelect(template);
              },
            ),
        ],
      ),
    );
  }
}

class _PhoneControl extends StatelessWidget {
  const _PhoneControl({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Semantics(
      button: true,
      label: '$label, $value',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: KalloMobileSpace.touch + 10,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KalloMobileType.micro.copyWith(
                  color: colors.inkMuted,
                  fontSize: 8.5,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KalloMobileType.callout.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  KalloGlyphView(
                    KalloGlyph.chevronRight,
                    size: 14,
                    color: colors.inkFaint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneColour extends StatelessWidget {
  const _PhoneColour({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return SizedBox(
      height: 52,
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: KalloMobileType.headline.copyWith(color: colors.ink),
          ),
          const Spacer(),
          KalloIconButton(
            glyph: KalloGlyph.minus,
            semanticLabel: '−',
            onTap: value <= 0 ? null : () => onChanged(value - 5),
            foreground: colors.ink,
            background: colors.fill,
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: KalloMobileType.data.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          KalloIconButton(
            glyph: KalloGlyph.plus,
            semanticLabel: '+',
            onTap: value >= 100 ? null : () => onChanged(value + 5),
            foreground: colors.ink,
            background: colors.fill,
          ),
        ],
      ),
    );
  }
}

class _PhoneToast extends StatelessWidget {
  const _PhoneToast({
    required this.label,
    required this.action,
    required this.onAction,
    required this.onClose,
  });

  final String label;
  final String action;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(KalloMobileRadius.card),
        border: Border.all(color: colors.hairline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: KalloMobileType.callout.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: SizedBox(
              height: KalloMobileSpace.touch,
              child: Center(
                child: Text(
                  action,
                  style: KalloMobileType.callout.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          KalloIconButton(
            glyph: KalloGlyph.close,
            semanticLabel: KalloStrings.of(context).close,
            onTap: onClose,
            size: 36,
            glyphSize: 13,
            foreground: colors.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _PhonePrintOptions extends StatefulWidget {
  const _PhonePrintOptions({
    required this.title,
    required this.sizes,
    required this.formats,
  });

  final String title;
  final List<ExportSize> sizes;
  final List<ExportFormat> formats;

  @override
  State<_PhonePrintOptions> createState() => _PhonePrintOptionsState();
}

class _PhonePrintOptionsState extends State<_PhonePrintOptions> {
  int _size = 0;
  ExportFormat _format = ExportFormat.png;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    return KalloMobileSheet(
      title: widget.title,
      onClose: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KalloMobileSpace.step5,
          0,
          KalloMobileSpace.step5,
          KalloMobileSpace.step5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              s.size,
              style: KalloMobileType.micro.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloMobileSpace.step2),
            for (int i = 0; i < widget.sizes.length; i++)
              KalloMobileRow(
                title: widget.sizes[i].label,
                chevron: false,
                minHeight: 48,
                trailing: i == _size
                    ? KalloGlyphView(
                        KalloGlyph.check,
                        size: 17,
                        color: colors.accent,
                      )
                    : null,
                onTap: () => setState(() => _size = i),
              ),
            const SizedBox(height: KalloMobileSpace.step4),
            Text(
              s.format,
              style: KalloMobileType.micro.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloMobileSpace.step2),
            Row(
              children: <Widget>[
                for (final ExportFormat format in widget.formats)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _format = format),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _format == format
                                ? colors.accentSoft
                                : colors.fill,
                            borderRadius: BorderRadius.circular(
                              KalloMobileRadius.control,
                            ),
                            border: Border.all(
                              color: _format == format
                                  ? colors.accent
                                  : const Color(0x00000000),
                            ),
                          ),
                          child: Text(
                            format.label,
                            style: KalloMobileType.callout.copyWith(
                              color: _format == format
                                  ? colors.accent
                                  : colors.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KalloMobileSpace.step2),
            Text(
              _format.lossless ? s.losslessNote : s.lossyNote,
              style: KalloMobileType.footnote.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloMobileSpace.step5),
            KalloMobileButton(
              label: s.printAction,
              onTap: () => Navigator.of(context).pop(
                ExportOptions(size: widget.sizes[_size].value, format: _format),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
