import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'design/chrome.dart';
import 'design/scope.dart';
import 'design/strings.dart';
import 'design/tokens.dart';
import 'lab/border_bake.dart';
import 'lab/catalog.dart';
import 'lab/edge_print.dart';
import 'lab/exports.dart';
import 'lab/folder_print_library.dart';
import 'lab/ffi_model.dart';
import 'lab/image_file.dart';
import 'lab/mobile_print_library.dart';
import 'lab/model.dart';
import 'lab/path_name.dart';
import 'lab/print.dart';
import 'lab/print_library.dart';
import 'lab/open_print_library.dart';
import 'lab/print_marker.dart';
import 'lab/print_meta.dart';
import 'lab/print_request.dart';
import 'lab/recipe_store.dart';
import 'lab/render_mode.dart';
import 'lab/settings.dart';
import 'lab/stock.dart';
import 'lab/strip.dart';
import 'lab/strip_develop.dart';
import 'lab/strip_store.dart';
import 'lab/system_print_service.dart';
import 'lab/tuning.dart';
import 'views/chambers.dart';
import 'views/steps.dart';
import 'views/studio.dart';
import 'widgets/folder_move_sheet.dart';
import 'widgets/import_progress_sheet.dart';
import 'widgets/mobile/mobile_sheet.dart';
import 'widgets/window_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The model is a library the app carries; if it cannot load, the subprocess
  // path is still there and the app says so in the console.
  await loadLinkedModel();
  final bool desktop =
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  if (!desktop) {
    // The compact shell is portrait-first. The landscape workbench is a later
    // phase; until it exists, locking the phone is better than showing a
    // 390-point-tall column that cannot hold its deck.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  if (desktop) {
    await windowManager.ensureInitialized();
    // A window that is wider than the screen loses its instrument panel off
    // the right edge. 1280 by 820 is the size the design is drawn at; it is
    // capped to the display it actually opens on.
    Size size = const Size(1280, 820);
    try {
      final Display display = await screenRetriever.getPrimaryDisplay();
      final Size visible = display.visibleSize ?? display.size;
      size = Size(
        math.max(960, math.min(1280, visible.width - 64)),
        math.max(600, math.min(820, visible.height - 120)),
      );
    } on Object catch (error) {
      debugPrint('no display size: $error');
    }
    final WindowOptions options = WindowOptions(
      size: size,
      minimumSize: Size(960, 600),
      center: true,
      title: 'Kallo',
      // The Mac keeps its traffic lights and loses its bar; Windows loses its
      // bar too, but draws the frame itself in `windows/runner`, so
      // window_manager is told nothing and left out of the window's frame
      // entirely. Leaving a style unset is not a default: it is Windows'
      // frame staying away from a frame the runner already owns.
      titleBarStyle: Platform.isMacOS ? TitleBarStyle.hidden : null,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }
  runApp(
    KalloApp(
      chrome: Platform.isMacOS
          ? WindowChrome.mac
          : Platform.isWindows
          ? WindowChrome.windows
          : WindowChrome.plain,
      onDragWindow: desktop ? windowManager.startDragging : null,
      // The band stands where a title bar would be, so it takes that bar's
      // oldest gesture. Windows fills the screen and puts the window back; the
      // Mac follows its own title bar setting, because the hidden chrome no
      // longer leaves that gesture to the system.
      onToggleMaximize: Platform.isMacOS || Platform.isWindows
          ? doubleClickTitleBand
          : null,
    ),
  );
}

/// The app.
///
/// `WidgetsApp`, not `MaterialApp`: text direction, focus, overlay, semantics
/// and routing come from it, and nothing else does. Everything visible is the
/// product's own vocabulary.
class KalloApp extends StatefulWidget {
  const KalloApp({
    super.key,
    this.strip,
    this.photograph,
    this.catalogue,
    this.prints,
    this.hanging,
    this.onImport,
    this.exportsFolder,
    this.locale,
    this.appearance,
    this.spectral = false,
    this.drawerOpen = false,
    this.initialChamber = Chamber.darkroom,
    this.initialStep = DarkroomStep.develop,
    this.chrome = WindowChrome.plain,
    this.onDragWindow,
    this.onToggleMaximize,
  });

  /// What the window looks like around the app.
  final WindowChrome chrome;

  /// Moves the window, when the chrome has no title bar of its own.
  final VoidCallback? onDragWindow;

  /// What a double click on the band does, where the band stands where a title
  /// bar would have been: fill the screen and put the window back on Windows,
  /// or the Mac's own title bar gesture.
  final VoidCallback? onToggleMaximize;

  /// A strip to open directly. The tests and the goldens pass one; the app
  /// starts on an empty bench and never opens the strip of the last window.
  final TestStrip? strip;

  /// The original photograph, already decoded. The tests pass it; the app
  /// decodes the photograph the strip keeps.
  final ui.Image? photograph;

  /// Every stock the model carries. The tests pin it, so that a golden is a
  /// picture of the app rather than of the model binary on this machine; the app
  /// asks `kallo stocks --json` once, at the start.
  final Catalogue? catalogue;

  /// Prints to hang. The tests pass them; the app reads the export folder,
  /// which is empty until something has been printed.
  final List<Print>? prints;

  /// The gallery's hanging, by print id. The tests pass one; the app reads the
  /// wall from the catalog and writes it back when a sheet is moved.
  final Map<String, Offset>? hanging;

  /// Bringing pictures onto the wall. The tests pin it; the app imports through
  /// the library it has open, when there is one.
  final VoidCallback? onImport;

  /// Where prints come from. The tests pin it, so that a golden does not show
  /// the folder of whoever ran it.
  final Directory? exportsFolder;

  /// Pins the human language. Null follows the device, which is also what the
  /// drawer's first option does.
  final Locale? locale;

  /// Pins the appearance. Null follows the system.
  final Brightness? appearance;

  /// Whether a new strip is exposed through the spectral path. The drawer's
  /// colour card sets it; the settings file remembers it.
  final bool spectral;

  /// Opens the drawer on the first frame, for the golden that shows it.
  final bool drawerOpen;

  final Chamber initialChamber;
  final DarkroomStep initialStep;

  @override
  State<KalloApp> createState() => _KalloAppState();
}

class _KalloAppState extends State<KalloApp> {
  Locale? _locale;
  Brightness? _pinned;
  late bool _spectral = widget.spectral;
  RenderMode _renderMode = RenderMode.gpu;

  /// The strip on the bench.
  ///
  /// The app opens with an empty one and never takes yesterday's back: the
  /// darkroom starts on the bench, asking for a photograph, rather than on the
  /// photograph the last window happened to have open.
  late TestStrip _strip;
  ui.Image? _photograph;
  bool _ownsPhotograph = false;
  Catalogue? _catalogue;
  List<Print> _prints = const <Print>[];

  /// Whether the export folder has been read into [_prints].
  ///
  /// Entering the gallery used to read and decode every print again, which
  /// left a little more of the last set in the allocator each time. A print
  /// changes the list; walking into the room does not.
  bool _printsLoaded = false;
  PrintLibrary? _library;

  /// Where the gallery's wall hangs each print, by the print's id. Empty means
  /// nobody has hung this wall and it still arranges its own grid.
  Map<String, Offset> _hanging = const <String, Offset>{};

  /// What Android has allowed of the photo library, when the library is the
  /// system one. Null on a desktop or before the bridge has answered.
  MediaAccess? _mediaAccess;
  int _missingPrints = 0;
  int _repairablePrints = 0;
  bool _repairing = false;
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _watchDebounce;
  Settings _settings = const Settings();
  String? _exportPath;
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// A context below the Navigator and the app's scope, for dialogs opened by
  /// the state above both. The Navigator is the only one the app has.
  BuildContext get _dialogContext =>
      _navigator.currentState?.overlay?.context ?? context;

  /// A context below the Navigator that is still alive after an `await`.
  ///
  /// The permission sheets are opened from the state above `WidgetsApp`; its
  /// own context has neither the Navigator nor the strings. The overlay's
  /// context has both, and checking it is what makes the async gap safe.
  BuildContext? get _liveDialogContext {
    final NavigatorState? navigator = _navigator.currentState;
    if (navigator == null || !navigator.mounted) {
      return null;
    }
    final BuildContext? overlay = navigator.overlay?.context;
    return overlay != null && overlay.mounted ? overlay : null;
  }

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _pinned = widget.appearance;
    _strip = widget.strip ?? const TestStrip();
    _photograph = widget.photograph;
    _catalogue = widget.catalogue;
    if (_catalogue == null) {
      unawaited(_openCatalogue());
    }
    final List<Print>? prints = widget.prints;
    _hanging = widget.hanging ?? const <String, Offset>{};
    if (prints != null) {
      _prints = prints;
      _printsLoaded = true;
    } else {
      unawaited(_openExports());
    }
    if (_photograph == null && _strip.photo != null) {
      unawaited(_openPhotograph(_strip));
    }
  }

  @override
  void dispose() {
    _watchDebounce?.cancel();
    unawaited(_watch?.cancel());
    _library?.close();
    if (_ownsPhotograph) {
      _photograph?.dispose();
    }
    super.dispose();
  }

  /// What the model carries: one call, and the shelf is a shelf.
  Future<void> _openCatalogue() async {
    final Catalogue catalogue = await Catalogue.load(Model.find());
    if (mounted) {
      setState(() => _catalogue = catalogue);
    }
  }

  /// The photograph a strip was given from outside.
  ///
  /// The app chooses its own photograph and decodes it in `_choosePhoto`; a
  /// strip passed in whole — what the tests and the goldens do — arrives with
  /// a path and no image.
  Future<void> _openPhotograph(TestStrip strip) async {
    final String? path = strip.photo;
    if (path == null) {
      return;
    }
    final File file = File(path);
    if (!file.existsSync()) {
      return;
    }
    try {
      final ui.Image image = await decodePhotograph(file, width: 1600);
      if (!mounted) {
        image.dispose();
        return;
      }
      final ui.Image? old = _ownsPhotograph ? _photograph : null;
      setState(() {
        _photograph = image;
        _ownsPhotograph = true;
      });
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    } on Object catch (error) {
      Model.log('the photograph could not be read: $error');
    }
  }

  /// Say what the Android photo permission is for, then ask for it.
  ///
  /// Saving a print and the system picker both work without the permission; it
  /// buys seeing pictures another app put in the Kallo folder. The explanation
  /// is therefore a choice, not a toll gate: "Not now" still opens the picker,
  /// and the settings page is where the choice can be changed later.
  Future<void> _preparePhotoAccess() async {
    if (!Platform.isAndroid) {
      return;
    }
    final PrintLibrary? library = _library;
    if (library is! MobilePrintLibrary) {
      return;
    }
    MediaAccess access;
    try {
      access = await library.access();
    } on Object catch (error) {
      debugPrint('photo access could not be read: $error');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _mediaAccess = access);
    // Partial access is enough to choose a photograph, and enough for the
    // prints Kallo itself saved. Do not interrupt for the rest; Settings has
    // the row that can widen it.
    if (access.granted || _settings.photoPrimerSeen) {
      return;
    }
    _settings = _settings.withPhotoPrimerSeen(true);
    await _settings.write();
    if (!mounted) {
      return;
    }
    final BuildContext? dialog = _liveDialogContext;
    if (dialog == null || !dialog.mounted) {
      return;
    }
    final KalloStrings s = KalloStrings.of(dialog);
    if (!access.canAsk) {
      final bool open = await showKalloPhotoAccessSheet(
        dialog,
        title: s.photoAccessBlockedTitle,
        message: s.photoAccessBlockedNote,
        confirm: s.openSettings,
        cancel: s.photoAccessNotNow,
      );
      if (open && mounted) {
        await library.openSettings();
      }
      return;
    }
    final bool allow = await showKalloPhotoAccessSheet(
      dialog,
      title: s.photoAccessTitle,
      message: s.photoAccessNote,
      confirm: s.photoAccessAllow,
      cancel: s.photoAccessNotNow,
    );
    if (!allow || !mounted) {
      return;
    }
    await _requestPhotoAccess(library);
  }

  /// The system dialog, after the app has explained itself.
  Future<void> _requestPhotoAccess(MobilePrintLibrary library) async {
    try {
      final MediaAccess next = await library.requestAccess();
      if (!mounted) {
        return;
      }
      setState(() => _mediaAccess = next);
      if (!next.granted && !next.canAsk) {
        final BuildContext? dialog = _liveDialogContext;
        if (dialog == null || !dialog.mounted) {
          return;
        }
        final KalloStrings s = KalloStrings.of(dialog);
        final bool open = await showKalloPhotoAccessSheet(
          dialog,
          title: s.photoAccessBlockedTitle,
          message: s.photoAccessBlockedNote,
          confirm: s.openSettings,
          cancel: s.photoAccessNotNow,
        );
        if (open && mounted) {
          await library.openSettings();
        }
      }
    } on Object catch (error) {
      debugPrint('photo access could not be asked for: $error');
    }
  }

  /// The Settings row: the one place a person can change what they answered.
  Future<void> _openPhotoAccessSettings() async {
    final PrintLibrary? library = _library;
    if (library is! MobilePrintLibrary) {
      return;
    }
    MediaAccess access;
    try {
      access = await library.access();
    } on Object catch (error) {
      debugPrint('photo access could not be read: $error');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _mediaAccess = access);
    if (access.granted && access.canListAll) {
      return;
    }
    final BuildContext? dialog = _liveDialogContext;
    if (dialog == null || !dialog.mounted) {
      return;
    }
    final KalloStrings s = KalloStrings.of(dialog);
    if (!access.canAsk) {
      final bool open = await showKalloPhotoAccessSheet(
        dialog,
        title: s.photoAccessBlockedTitle,
        message: s.photoAccessBlockedNote,
        confirm: s.openSettings,
        cancel: s.photoAccessNotNow,
      );
      if (open && mounted) {
        await library.openSettings();
      }
      return;
    }
    final bool allow = await showKalloPhotoAccessSheet(
      dialog,
      title: s.photoAccessTitle,
      message: access.limited ? s.fixedFolderLimited : s.photoAccessNote,
      confirm: s.photoAccessAllow,
      cancel: s.photoAccessNotNow,
    );
    if (allow && mounted) {
      await _requestPhotoAccess(library);
    }
  }

  /// Choose a photograph: copy it into the strip's folder, decode it, and
  /// start a strip on it. A different photograph is a different strip.
  ///
  /// A phone chooses from Photos through the system picker; a desktop chooses
  /// a file. The rest of the darkroom does not know which happened.
  Future<void> _choosePhoto() async {
    await _preparePhotoAccess();
    if (!mounted) {
      return;
    }
    final File? file = await _pickPhotograph();
    if (file == null || !mounted) {
      return;
    }
    try {
      final File kept = await StripStore.keep(file);
      final TestStrip current = _strip;
      if (current.photo == kept.path) {
        return;
      }
      final ui.Image image = await decodePhotograph(kept, width: 1600);
      if (!mounted) {
        image.dispose();
        return;
      }
      final TestStrip next = current.withPhoto(kept.path);
      final ui.Image? oldPhoto = _ownsPhotograph ? _photograph : null;
      final List<TestPrint> oldPrints = current.prints;
      setState(() {
        _strip = next;
        _photograph = image;
        _ownsPhotograph = true;
      });
      for (final TestPrint print in oldPrints) {
        final ui.Image? picture = print.image;
        if (picture != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => picture.dispose(),
          );
        }
      }
      if (oldPhoto != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => oldPhoto.dispose());
      }
      await StripStore.clear();
    } on Object catch (error) {
      Model.log('the photograph could not be kept or read: $error');
    }
  }

  Future<File?> _pickPhotograph() async {
    final PrintLibrary? library = _library;
    if (library != null && library.canPickImages) {
      try {
        final List<File> picked = await library.pickImages(limit: 1);
        return picked.isEmpty ? null : picked.first;
      } on Object catch (error) {
        debugPrint('no photograph picker: $error');
        return null;
      }
    }
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'photographs',
          // What the model's readers accept: the window's formats and every
          // camera raw the decoder claims. A panel can only offer extensions,
          // so this list is the decoder's `EXTENSIONS` written the picker's
          // way; a raw added there belongs here too.
          extensions: <String>[
            'jpg',
            'jpeg',
            'png',
            'tif',
            'tiff',
            '3fr',
            'ari',
            'arw',
            'cr2',
            'cr3',
            'crw',
            'dcr',
            'dcs',
            'dng',
            'erf',
            'iiq',
            'kdc',
            'mef',
            'mos',
            'mrw',
            'nef',
            'nkd',
            'nrw',
            'orf',
            'pef',
            'qtk',
            'raf',
            'raw',
            'rw2',
            'srw',
            'tfr',
            'x3f',
          ],
        ),
      ],
    );
    return file == null ? null : File(file.path);
  }

  /// Replace the strip and forget the prints the old one had.
  Future<void> _replaceStrip(TestStrip next) async {
    final TestStrip old = _strip;
    setState(() => _strip = next);
    for (final TestPrint print in old.prints) {
      final ui.Image? picture = print.image;
      if (picture != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => picture.dispose());
      }
    }
    await StripStore.clear();
  }

  Future<void> _chooseFilm(Stock film) async {
    final Catalogue catalogue = _catalogue ?? Catalogue.carried;
    final TestStrip strip = _strip;
    final List<Stock> papers = catalogue.papersFor(film.process);
    Stock? paper;
    for (final Stock candidate in papers) {
      if (candidate.id == strip.paperId) {
        paper = candidate;
        break;
      }
    }
    paper ??= papers.isEmpty ? null : papers.first;
    await _replaceStrip(
      TestStrip(
        photo: strip.photo,
        stockId: film.id,
        stockLabel: film.label,
        paperId: paper?.id,
        paperLabel: paper?.label,
        spectral: strip.spectral,
        tempC: strip.tempC,
      ),
    );
  }

  Future<void> _choosePaper(Stock? paper) async {
    final TestStrip strip = _strip;
    await _replaceStrip(
      TestStrip(
        photo: strip.photo,
        stockId: strip.stockId,
        stockLabel: strip.stockLabel,
        paperId: paper?.id,
        paperLabel: paper?.label,
        spectral: strip.spectral,
        tempC: strip.tempC,
      ),
    );
  }

  /// Change the developer's temperature.
  ///
  /// The temperature is part of the strip's development, so changing it starts
  /// a new strip: the old prints were made at a different temperature, and
  /// keeping them would be a strip that says two things at once.
  Future<void> _setTemperature(double tempC) async {
    final TestStrip strip = _strip;
    if (strip.tempC == tempC) {
      return;
    }
    await _replaceStrip(strip.withTemperature(tempC));
  }

  /// Forget the prints and keep the photograph and the materials.
  Future<void> _clearStrip() async {
    final TestStrip strip = _strip;
    await _replaceStrip(strip.withoutPrints());
  }

  /// Develop one print and add it to the strip.
  Future<void> _develop(
    double minutes, {
    void Function(double)? onProgress,
  }) async {
    final TestStrip strip = _strip;
    if (strip.photo == null) {
      return;
    }
    await StockRecipes.ensureLoaded();
    TestPrint? replaced;
    for (final TestPrint print in strip.prints) {
      if (print.minutes == minutes) {
        replaced = print;
        break;
      }
    }
    final TestStrip next = await developTestPrint(
      model: Model.find(),
      strip: strip,
      minutes: minutes,
      tuning: _tuningFor(strip),
      onProgress: onProgress,
    );
    if (!mounted) {
      return;
    }
    setState(() => _strip = next);
    final ui.Image? picture = replaced?.image;
    if (picture != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => picture.dispose());
    }
  }

  /// Take one print off the strip.
  Future<void> _remove(double minutes) async {
    final TestStrip strip = _strip;
    TestPrint? removed;
    for (final TestPrint print in strip.prints) {
      if (print.minutes == minutes) {
        removed = print;
        break;
      }
    }
    if (removed == null) {
      return;
    }
    final TestStrip next = strip.without(minutes);
    setState(() => _strip = next);
    final File? file = removed.file;
    if (file != null && file.existsSync()) {
      await file.delete();
    }
    final ui.Image? picture = removed.image;
    if (picture != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => picture.dispose());
    }
  }

  /// Make a finished print and hang it.
  Future<void> _print(
    PrintRequest request, {
    void Function(double)? onProgress,
  }) async {
    final TestStrip strip = _strip;
    final PrintLibrary? library = _library;
    if (library == null || strip.photo == null) {
      return;
    }
    final Directory exports = library.workFolder;
    await StockRecipes.ensureLoaded();
    try {
      final String filmName =
          _catalogue?.film(strip.stockId)?.displayName ?? strip.stockLabel;
      final String paperName =
          _catalogue?.paper(strip.paperId ?? '')?.displayName ??
          strip.paperLabel ??
          Stocks.crystal.displayName;
      final File output = await printTest(
        model: Model.find(),
        strip: strip,
        minutes: request.minutes,
        exports: exports,
        width: request.width,
        format: request.format,
        printEv: request.printEv,
        filters: request.filters,
        heatGlass: request.heatGlass,
        tuning: _tuningFor(strip),
        border: request.border.name,
        onProgress: onProgress,
      );
      final DateTime now = DateTime.now().toUtc();
      final PrintMeta meta = PrintMeta(
        id: PrintMeta.newId(),
        title: _stem(output.path),
        kind: PrintKind.print,
        printed: now,
        added: now,
        updated: now,
        printNumber: 1,
        process: _catalogue?.film(strip.stockId)?.process,
        film: filmName,
        paper: paperName,
        minutes: request.minutes,
        tempC: strip.tempC,
      );
      if (request.border != BorderTemplate.none) {
        onProgress?.call(0.92);
        await _printBorder(output, request);
        onProgress?.call(0.97);
      }
      await library.addFile(output, meta);
      onProgress?.call(1.0);
      if (library.folder == null) {
        try {
          if (await output.exists()) {
            await output.delete();
          }
        } on FileSystemException {
          // The temporary folder is cleaned by the system; the print is in
          // Photos or MediaStore already.
        }
      }
      await _reloadPrints();
    } finally {
      // The print step is the one that says it is working; the wall is where
      // the paper is when it is done.
    }
  }

  /// Print the chosen edge into the finished print, in place.
  ///
  /// The edge is not a second file: a full-frame print is one sheet with the
  /// rebate printed on it. A failure here leaves the paper print it already
  /// was — the picture without an edge is still the picture — so it is logged
  /// and the darkroom carries on.
  Future<void> _printBorder(File output, PrintRequest request) async {
    final TestStrip strip = _strip;
    try {
      await bakeBorder(
        print: output,
        border: request.border,
        format: request.format,
        film: _catalogue?.film(strip.stockId)?.displayName ?? strip.stockLabel,
        process: _catalogue?.film(strip.stockId)?.process,
      );
    } on Object catch (error) {
      Model.log('the border was not printed: $error');
    }
  }

  /// The departures the chosen stock's recipe applies to the next print.
  ///
  /// A stock with no recipe, or a recipe written against another version of the
  /// file, is the model's own stock: the identity.
  Tuning _tuningFor(TestStrip strip) {
    final Catalogue catalogue = _catalogue ?? Catalogue.carried;
    return StockRecipes.tuningFor(
      catalogue.film(strip.stockId),
      model: catalogue.model,
    );
  }

  /// Read the folder the person chose, and the prints in it.
  Future<void> _openExports() async {
    final bool phone = Platform.isIOS || Platform.isAndroid;
    if (phone) {
      // The platform bridge tells Settings where the app's support folder is,
      // so the settings file is read after the library opens, not before.
      await _openLibrary();
      _settings = await Settings.read();
      _spectral = _settings.spectral;
      _renderMode = _settings.renderer;
      RenderPreference.set(_renderMode);
    } else {
      _settings = await Settings.read();
      _exportPath = _settings.exportPath;
      _spectral = _settings.spectral;
      _renderMode = _settings.renderer;
      RenderPreference.set(_renderMode);
      await _openLibrary();
    }
    // The support folder is known now — on a phone the bridge just named it —
    // so the stock recipes beside the settings file can be read.
    await StockRecipes.ensureLoaded();
    await _reloadPrints();
    _startWatching();
  }

  /// Reload when the folder changes behind the app.
  ///
  /// The marker and the catalog are the truth, so a file dropped in Finder or
  /// removed by another app should reach the wall without a relaunch. Events
  /// are debounced: a copy is many writes, and one reload is enough.
  void _startWatching() {
    _watchDebounce?.cancel();
    unawaited(_watch?.cancel());
    _watch = null;
    final Directory? folder = _library?.folder ?? _folder;
    if (folder == null || !folder.existsSync()) {
      return;
    }
    try {
      _watch = folder
          .watch(
            events:
                FileSystemEvent.create |
                FileSystemEvent.modify |
                FileSystemEvent.delete |
                FileSystemEvent.move,
          )
          .listen(
            (FileSystemEvent event) {
              _watchDebounce?.cancel();
              _watchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  unawaited(_reloadPrints());
                }
              });
            },
            onError: (Object error) {
              debugPrint('the folder could not be watched: $error');
            },
          );
    } on Object catch (error) {
      debugPrint('the folder could not be watched: $error');
    }
  }

  /// Open the catalog and let it adopt the old print store once.
  ///
  /// On Android this is also where the current permission state is read. It is
  /// a status query, not a request: the dialog comes from `_preparePhotoAccess`
  /// when a photograph is first chosen.
  Future<void> _openLibrary() async {
    final Directory? folder = _folder;
    if (folder == null && !(Platform.isIOS || Platform.isAndroid)) {
      return;
    }
    try {
      final PrintLibrary library = await openPrintLibrary(folder: folder);
      if (library is FolderPrintLibrary) {
        try {
          await library.migrateLegacy();
        } on Object {
          library.close();
          rethrow;
        }
      }
      _library = library;
      if (library is MobilePrintLibrary && Platform.isAndroid) {
        try {
          _mediaAccess = await library.access();
        } on Object catch (error) {
          debugPrint('photo access could not be read: $error');
        }
      }
    } on Object catch (error) {
      debugPrint('the catalog could not be opened: $error');
      _library?.close();
      _library = null;
    }
  }

  /// The path a new strip is exposed through. It is a new strip's setting, not
  /// a switch on the strip in the darkroom: a strip is made one way.
  Future<void> _setSpectral(bool on) async {
    setState(() => _spectral = on);
    _settings = _settings.withSpectral(on);
    await _settings.write();
  }

  /// The engine this machine may use. It outlives the strip, so it is written
  /// down and read back before any render is asked for.
  Future<void> _setRenderMode(RenderMode mode) async {
    setState(() => _renderMode = mode);
    RenderPreference.set(mode);
    _settings = _settings.withRenderer(mode);
    await _settings.write();
  }

  /// Which releases the update row follows. It outlives the window, like the
  /// renderer: a preview reader does not choose again every launch.

  /// Read the export folder only when it has not been read yet.
  ///
  /// A room asks for the prints each time it is entered; the app already has
  /// them unless this is the first ask, or a print has just changed the list.
  Future<void> _ensurePrints() async {
    if (_printsLoaded) {
      return;
    }
    await _reloadPrints();
  }

  Future<void> _reloadPrints() async {
    _printsLoaded = true;
    final PrintLibrary? library = _library;
    final List<Print> prints = library == null
        ? const <Print>[]
        : await library.read();
    if (!mounted) {
      for (final Print print in prints) {
        print.dispose();
      }
      return;
    }
    final List<Print> previous = _prints;
    final (int missing, int repairable) = _issueCounts();
    // The wall belongs to the library: a different folder is a different
    // hanging, and the catalog is where the one that is open remembers it.
    final Map<String, Offset> hanging = library == null
        ? _hanging
        : library.catalog.hangings(library.library.id);
    setState(() {
      _prints = prints;
      _hanging = hanging;
      _missingPrints = missing;
      _repairablePrints = repairable;
    });
    if (identical(previous, prints) || previous.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final Print print in previous) {
        print.dispose();
      }
    });
  }

  /// Hang a sheet where it was put.
  ///
  /// The whole hanging is written rather than one place: the first move on an
  /// untouched wall freezes the whole grid, and after that the map is the wall.
  void _hang(Map<String, Offset> places) {
    if (!mounted) {
      return;
    }
    setState(() => _hanging = places);
    final PrintLibrary? library = _library;
    if (library == null) {
      return;
    }
    try {
      library.catalog.setHangings(library.library.id, places);
    } on Object catch (error) {
      debugPrint('the hanging could not be written: $error');
    }
  }

  /// Hang the wall back in its own grid.
  void _rehang() {
    if (!mounted) {
      return;
    }
    setState(() => _hanging = const <String, Offset>{});
    final PrintLibrary? library = _library;
    if (library == null) {
      return;
    }
    try {
      library.catalog.clearHangings(library.library.id);
    } on Object catch (error) {
      debugPrint('the wall could not be hung back: $error');
    }
  }

  Future<void> _chooseExport() async {
    final String? chosen;
    try {
      chosen = await Exports.choose();
    } on Exception catch (error) {
      debugPrint('no folder panel: $error');
      return;
    }
    if (chosen == null || !mounted) {
      return;
    }
    final FolderPrintLibrary? library = _library is FolderPrintLibrary
        ? _library as FolderPrintLibrary
        : null;
    if (library != null) {
      final int count = library.catalog
          .printsInLibrary(library.library.id)
          .length;
      if (count > 0) {
        final FolderMoveChoice? choice = await showFolderMoveSheet(
          _dialogContext,
          count: count,
          destination: Exports.display(chosen),
        );
        if (!mounted || choice == null || choice == FolderMoveChoice.cancel) {
          return;
        }
        if (choice == FolderMoveChoice.useNew) {
          _library = library.switchTo(Directory(chosen));
        } else {
          try {
            _library = await library.moveTo(Directory(chosen));
          } on Object catch (error) {
            debugPrint('the prints could not be moved: $error');
            return;
          }
        }
      } else {
        _library = library.switchTo(Directory(chosen));
      }
    }
    _exportPath = chosen;
    await _remember(chosen);
    await _reloadPrints();
    _startWatching();
  }

  Future<void> _resetExport() async {
    if (!mounted) {
      return;
    }
    final FolderPrintLibrary? library = _library is FolderPrintLibrary
        ? _library as FolderPrintLibrary
        : null;
    final Directory? target = Exports.defaultDirectory;
    if (library != null && target != null) {
      try {
        _library = await library.moveTo(target);
      } on Object catch (error) {
        debugPrint('the prints could not be moved back: $error');
        return;
      }
    }
    setState(() => _exportPath = null);
    await _remember(null);
    await _reloadPrints();
    _startWatching();
  }

  /// Copy selected pictures into the library. The source files never change.
  Future<void> _importImages() async {
    final PrintLibrary? library = _library;
    if (library == null) {
      return;
    }
    await _preparePhotoAccess();
    if (!mounted) {
      return;
    }
    final List<File> files;
    try {
      if (library.canPickImages) {
        files = await library.pickImages();
      } else {
        final List<XFile> picked = await openFiles(
          acceptedTypeGroups: <XTypeGroup>[
            const XTypeGroup(
              label: 'Images',
              extensions: <String>['png', 'jpg', 'jpeg'],
            ),
          ],
          confirmButtonText: 'Import',
        );
        files = <File>[for (final XFile file in picked) File(file.path)];
      }
    } on Object catch (error) {
      debugPrint('no import panel: $error');
      return;
    }
    if (!mounted) {
      return;
    }
    final ImportProgress progress = showImportProgressSheet(
      _dialogContext,
      total: files.length,
    );
    await progress.ready;
    int done = 0;
    try {
      for (final File source in files) {
        if (progress.canceled) {
          break;
        }
        progress.current.value = _basename(source.path);
        File? target;
        try {
          final Directory? folder = library.folder;
          if (folder != null && source.parent.path == folder.path) {
            continue;
          }
          final ScannedPrint? scan = await PrintMarker.read(source);
          if (scan == null) {
            continue;
          }
          final PrintMeta? existing = scan.meta;
          if (existing != null &&
              library.catalog.printById(existing.id) != null) {
            continue;
          }
          final FileStat stat = await source.stat();
          target = File(_uniqueImportPath(library.workFolder, source.path));
          await source.copy(target.path);
          final DateTime now = DateTime.now().toUtc();
          final PrintMeta meta =
              existing ??
              PrintMeta(
                id: PrintMeta.newId(),
                title: _importTitle(source, stat),
                kind: PrintKind.import,
                printed: stat.modified.toUtc(),
                added: now,
                updated: now,
                sourceName: _basename(source.path),
              );
          await library.addFile(target, meta);
        } on Object catch (error) {
          debugPrint('the import of ${source.path} failed: $error');
        } finally {
          if (library.folder == null && target != null) {
            try {
              if (await target.exists()) {
                await target.delete();
              }
            } on FileSystemException {
              // A temporary import the system cleans up later is not a failure.
            }
          }
          if (library.canPickImages) {
            try {
              if (await source.exists()) {
                await source.delete();
              }
            } on FileSystemException {
              // The picker's own copy is a cache; losing it later is harmless.
            }
          }
        }
        progress.done.value = ++done;
      }
    } finally {
      progress.close();
    }
    await _reloadPrints();
  }

  (int, int) _issueCounts() {
    final PrintLibrary? library = _library;
    if (library == null) {
      return (0, 0);
    }
    int missing = 0;
    int repairable = 0;
    for (final CatalogPrint row in library.catalog.printsInLibrary(
      library.library.id,
      includeMissing: true,
    )) {
      if (row.missing) {
        missing++;
        continue;
      }
      if ((row.xmpState == XmpState.missing ||
              row.xmpState == XmpState.stale) &&
          File(row.locator).existsSync()) {
        repairable++;
      }
    }
    return (missing, repairable);
  }

  Future<void> _repairMarkers() async {
    final PrintLibrary? library = _library;
    if (library == null || _repairing) {
      return;
    }
    setState(() => _repairing = true);
    try {
      await library.repairMarkers();
      await _reloadPrints();
    } finally {
      if (mounted) {
        setState(() => _repairing = false);
      }
    }
  }

  Future<void> _remember(String? path) async {
    _settings = _settings.withExports(path);
    if (mounted) {
      setState(() {});
    }
    await _settings.write();
  }

  Directory? get _folder {
    if (Platform.isIOS || Platform.isAndroid) {
      return null;
    }
    return widget.exportsFolder ?? Exports.directoryFor(_exportPath);
  }

  String _uniqueImportPath(Directory folder, String sourcePath) {
    final String separator = Platform.pathSeparator;
    final String base = _basename(sourcePath);
    final String stem = _stem(sourcePath);
    final int dot = base.lastIndexOf('.');
    final String extension = dot < 0 ? '' : base.substring(dot);
    int index = 1;
    File candidate = File('${folder.path}$separator$base');
    while (candidate.existsSync()) {
      index++;
      candidate = File('${folder.path}$separator$stem-$index$extension');
    }
    return candidate.path;
  }

  static String _basename(String path) => baseName(path);

  static String _stem(String path) => stemOf(path);

  /// Android's system picker returns a media id, not the name of the file the
  /// person chose. A wall label of `1000043857` is not a title; the day the
  /// picture was taken is something a person can read.
  static String _importTitle(File source, FileStat stat) {
    final String stem = _stem(source.path);
    if (!RegExp(r'^\d+$').hasMatch(stem)) {
      return stem;
    }
    final DateTime at = stat.modified.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Kallo ${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}.${two(at.minute)}';
  }

  ExportSetting get _exportSetting {
    final PrintLibrary? library = _library;
    final bool canChoose = library?.canChooseFolder ?? Exports.canChoose;
    return ExportSetting(
      label: library?.locationLabel ?? Exports.display(_folder?.path),
      canChoose: canChoose,
      custom: canChoose && _exportPath != null,
      onChoose: canChoose ? _chooseExport : null,
      onReset: canChoose ? _resetExport : null,
      canListAll: library?.canListAll ?? true,
      photoAccess: _mediaAccess?.granted ?? true,
      onPhotoAccess: _mediaAccess == null
          ? null
          : () => unawaited(_openPhotoAccessSettings()),
      missingPrints: _missingPrints,
      repairablePrints: _repairablePrints,
      onRepair: _repairing ? null : _repairMarkers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Kallo',
      navigatorKey: _navigator,
      color: KalloColors.light.ground,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: KalloStrings.supported,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        KalloStrings.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondary,
            ) => builder(context),
          ),
      builder: (BuildContext context, Widget? child) {
        final Brightness resolved =
            _pinned ?? MediaQuery.platformBrightnessOf(context);
        final KalloColors colors = KalloColors.of(resolved);
        return KalloScope(
          colors: colors,
          pinned: _pinned,
          onPin: (Brightness? next) => setState(() => _pinned = next),
          child: DefaultTextStyle(
            style: KalloType.body.copyWith(color: colors.ink),
            child: child!,
          ),
        );
      },
      home: Studio(
        strip: _strip,
        photograph: _photograph,
        catalogue: _catalogue ?? Catalogue.carried,
        prints: _prints,
        exports: _library?.workFolder ?? _folder,
        onChoosePhoto: () => unawaited(_choosePhoto()),
        onFilm: (Stock film) => unawaited(_chooseFilm(film)),
        onPaper: (Stock? paper) => unawaited(_choosePaper(paper)),
        onTemperature: (double tempC) => unawaited(_setTemperature(tempC)),
        onDevelop: _develop,
        onRemove: _remove,
        onClearStrip: () => unawaited(_clearStrip()),
        onPrint: _print,
        onEnterExports: widget.prints == null
            ? () => unawaited(_ensurePrints())
            : null,
        export: _exportSetting,
        hanging: _hanging,
        onHang: _hang,
        onRehang: _rehang,
        onImport:
            widget.onImport ??
            (_library == null ? null : () => unawaited(_importImages())),
        locale: _locale,
        onLocale: (Locale? next) => setState(() => _locale = next),
        spectral: _spectral,
        onSpectral: _setSpectral,
        renderMode: _renderMode,
        onRenderMode: _setRenderMode,
        initiallyOpen: widget.drawerOpen,
        initialChamber: widget.initialChamber,
        initialStep: widget.initialStep,
        chrome: widget.chrome,
        onDragWindow: widget.onDragWindow,
        onToggleMaximize: widget.onToggleMaximize,
      ),
    );
  }
}
