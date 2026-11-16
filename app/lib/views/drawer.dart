import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../design/scope.dart';
import '../design/strings.dart';
import '../design/tokens.dart';
import '../lab/exports.dart';
import '../lab/render_device.dart';
import '../lab/render_mode.dart';
import '../lab/updates.dart';
import '../widgets/button.dart';
import '../widgets/segments.dart';

/// Settings, as a drawer in the bench.
///
/// A place you open, not a page you go to. One sheet, six pages: the first
/// says what the app is, the other five set something. The film's own words do
/// not change when the language does. Nothing here advertises a renderer the
/// app cannot switch or a sound it does not make.
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({
    super.key,
    required this.locale,
    required this.onLocale,
    required this.spectral,
    required this.onSpectral,
    required this.renderMode,
    required this.onRenderMode,
    required this.export,
    required this.onClose,
    this.updates,
  });

  /// What the user pinned, or null to follow the device.
  final Locale? locale;
  final ValueChanged<Locale?> onLocale;

  /// The path a new roll is developed through, and the way to change it.
  final bool spectral;
  final ValueChanged<bool> onSpectral;

  /// The engine renders may use, and the way to change it.
  final RenderMode renderMode;
  final ValueChanged<RenderMode> onRenderMode;

  /// Where prints come from, and whether this platform lets a person say.
  final ExportSetting export;

  final VoidCallback onClose;

  /// The update row's state, when the app owns it. A test injects one; the
  /// drawer makes its own otherwise, and never asks it for anything until a
  /// person does.
  final UpdateController? updates;

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  static const int _aboutTab = 0;

  List<String> _tabs(KalloStrings s) => <String>[
    s.tabAbout,
    s.tabLanguage,
    s.tabAppearance,
    s.tabPrints,
    s.tabColour,
    s.tabRenderer,
  ];

  int _tab = _aboutTab;

  /// What the machine says it has. Null until the model answers.
  RenderDevice? _device;

  /// The update row's state, and whether this page is the one that disposes it.
  late final UpdateController _updates;
  late final bool _ownsUpdates;

  @override
  void initState() {
    super.initState();
    final UpdateController? injected = widget.updates;
    _updates = injected ?? UpdateController();
    _ownsUpdates = injected == null;
    unawaited(_probeDevice());
  }

  @override
  void dispose() {
    if (_ownsUpdates) {
      _updates.dispose();
    }
    super.dispose();
  }

  Future<void> _probeDevice() async {
    final RenderDevice device = await RenderDevice.probe();
    if (mounted) {
      setState(() => _device = device);
    }
  }

  double _fieldWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width - 56).clamp(240.0, 460.0);

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final bool compact = MediaQuery.sizeOf(context).width < 700;
    return Container(
      decoration: BoxDecoration(color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 52,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KalloSpace.step4,
                ),
                child: GestureDetector(
                  onTap: widget.onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(KalloSpace.step2),
                    child: Text(
                      s.close,
                      style: KalloType.caption.copyWith(color: colors.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _railCompact(colors),
                      Expanded(child: _pageScroll(s, colors)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: 196, child: _rail(colors)),
                      Expanded(child: _pageScroll(s, colors)),
                    ],
                  ),
          ),
          if (_tab != _aboutTab)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KalloSpace.step4,
                vertical: KalloSpace.step2 + 2,
              ),
              child: Text(
                s.applyAtOnce,
                style: KalloType.data.copyWith(
                  fontSize: 10,
                  color: colors.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pageScroll(KalloStrings s, KalloColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        KalloSpace.step4 - 4,
        KalloSpace.step4 - 6,
        KalloSpace.step4,
        KalloSpace.step4,
      ),
      // A drawer opened on a 27-inch display should still read as a page, not
      // as two columns a metre apart.
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _page(s, colors),
        ),
      ),
    );
  }

  Widget _railCompact(KalloColors colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        KalloSpace.step3,
        KalloSpace.step2,
        KalloSpace.step3,
        0,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _tabs(KalloStrings.of(context)).length; i++)
            Padding(
              padding: const EdgeInsets.only(right: KalloSpace.step2),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KalloSpace.step3,
                    vertical: KalloSpace.step2,
                  ),
                  decoration: BoxDecoration(
                    color: i == _tab ? colors.accentSoft : null,
                    borderRadius: BorderRadius.circular(KalloRadius.control),
                  ),
                  child: Text(
                    _tabs(KalloStrings.of(context))[i],
                    style: KalloType.caption.copyWith(
                      color: i == _tab ? colors.accent : colors.inkFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rail(KalloColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KalloSpace.step3,
        KalloSpace.step2,
        KalloSpace.step3,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < _tabs(KalloStrings.of(context)).length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: KalloMotion.quick,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KalloSpace.step3 + 4,
                    vertical: KalloSpace.step2 + 3,
                  ),
                  decoration: BoxDecoration(
                    color: i == _tab ? colors.accentSoft : null,
                    borderRadius: BorderRadius.circular(KalloRadius.control),
                  ),
                  child: Text(
                    _tabs(KalloStrings.of(context))[i],
                    style: KalloType.caption.copyWith(
                      color: i == _tab ? colors.accent : colors.inkFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _page(KalloStrings s, KalloColors colors) {
    switch (_tab) {
      case 0:
        return _about(s, colors);
      case 1:
        return _language(s, colors);
      case 2:
        return _appearance(s, colors);
      case 3:
        return _prints(s, colors);
      case 4:
        return _colour(s, colors);
      default:
        return _renderer(s, colors);
    }
  }

  void _openRepository() {
    unawaited(_open(KalloInfo.repository));
  }

  void _openReleases() {
    unawaited(_open(KalloInfo.releases));
  }

  /// Opens one address in the system's browser. A failure is the browser's
  /// business, not a dialog's: the page simply does not open.
  Future<void> _open(String address) async {
    final Uri uri = Uri.parse(address);
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        debugPrint('could not open $uri');
      }
    } on Object catch (error) {
      debugPrint('could not open $uri: $error');
    }
  }

  Widget _about(KalloStrings s, KalloColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/kallo-icon.png',
                width: 80,
                height: 80,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: KalloSpace.step5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  KalloInfo.name,
                  style: KalloType.title.copyWith(
                    fontSize: 24,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: KalloSpace.step1 + 2),
                Text(
                  s.appVersion(KalloInfo.version),
                  style: KalloType.data.copyWith(color: colors.inkFaint),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: KalloSpace.step5),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            s.openSourceNote,
            style: KalloType.body.copyWith(color: colors.inkMuted),
          ),
        ),
        const SizedBox(height: KalloSpace.step5),
        _AboutLink(
          key: const Key('about-repository'),
          onTap: _openRepository,
          label: s.openRepository,
          title: 'GitHub',
          subtitle: 'github.com/tsukiyo20/kallo',
          icon: 'assets/github-mark.png',
          colors: colors,
        ),
        const SizedBox(height: KalloSpace.step3),
        _AboutLink(
          key: const Key('about-changelog'),
          onTap: _openReleases,
          label: s.changelog,
          title: s.changelog,
          // The page's own title, the one GitHub prints at the top of it.
          subtitle: s.releasesPage,
          colors: colors,
          height: 56,
        ),
        const SizedBox(height: KalloSpace.step5),
        _updateBlock(s, colors),
      ],
    );
  }

  /// The update row.
  ///
  /// The update is a thing a person asks for, so the row starts as a check and
  /// nothing here runs until it is tapped. There is one answer — GitHub's
  /// latest release — not a channel to choose between.
  Widget _updateBlock(KalloStrings s, KalloColors colors) {
    final UpdateController updates = _updates;
    return ListenableBuilder(
      listenable: updates,
      builder: (BuildContext context, Widget? child) {
        final ({String label, VoidCallback? onTap, bool action}) action =
            _updateAction(s, updates);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _UpdateRow(
              key: const Key('about-update'),
              label: s.updates,
              action: action.label,
              onTap: action.onTap,
              actionable: action.action,
              width: _fieldWidth(context),
              colors: colors,
            ),
            if (updates.problem == UpdateProblem.location) ...<Widget>[
              const SizedBox(height: KalloSpace.step2),
              SizedBox(
                width: _fieldWidth(context),
                child: Text(
                  Platform.isWindows
                      ? s.updateNeedsWritable
                      : s.updateNeedsApplications,
                  style: KalloType.small.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// What the update row says, and what tapping it does, for the state it is
  /// in. A row that is busy is not a button; a row that failed is a retry.
  /// `action` marks the states that are something to do, not a report: those
  /// are the only ones the accent colours, because the accent is an action.
  ({String label, VoidCallback? onTap, bool action}) _updateAction(
    KalloStrings s,
    UpdateController updates,
  ) {
    switch (updates.stage) {
      case UpdateStage.idle:
        return (
          label: s.checkForUpdates,
          onTap: () => unawaited(updates.check()),
          action: true,
        );
      case UpdateStage.checking:
        return (label: s.checkingForUpdates, onTap: null, action: false);
      case UpdateStage.upToDate:
        // Checking again is how a window that has been open for a while finds
        // the release published while it was open.
        return (
          label: s.upToDate,
          onTap: () => unawaited(updates.check()),
          action: false,
        );
      case UpdateStage.available:
        if (!updates.canInstall) {
          return (label: s.openReleases, onTap: _openReleases, action: true);
        }
        return (
          label: s.updateTo(updates.release!.label),
          onTap: () => unawaited(updates.install()),
          action: true,
        );
      case UpdateStage.downloading:
        return (
          label: s.downloading((updates.progress * 100).round()),
          onTap: null,
          action: false,
        );
      case UpdateStage.restarting:
        return (label: s.restarting, onTap: null, action: false);
      case UpdateStage.failed:
        if (updates.release != null) {
          if (updates.canInstall) {
            return (
              label: s.updateFailedRetry,
              onTap: () => unawaited(updates.install()),
              action: true,
            );
          }
          return (label: s.openReleases, onTap: _openReleases, action: true);
        }
        return (
          label: s.checkFailedRetry,
          onTap: () => unawaited(updates.check()),
          action: true,
        );
    }
  }

  Widget _colour(KalloStrings s, KalloColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.colour,
          style: KalloType.title.copyWith(fontSize: 22, color: colors.ink),
        ),
        const SizedBox(height: KalloSpace.step2),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            s.colourNote,
            style: KalloType.body.copyWith(color: colors.inkMuted),
          ),
        ),
        const SizedBox(height: KalloSpace.step5),
        _Label(s.path, colors),
        const SizedBox(height: KalloSpace.step2),
        KalloSegments(
          options: <String>[s.scalarPath, s.spectralPath],
          selected: widget.spectral ? 1 : 0,
          onSelect: (int i) => widget.onSpectral(i == 1),
        ),
        const SizedBox(height: KalloSpace.step3),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            s.spectralNote,
            style: KalloType.small.copyWith(color: colors.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _renderer(KalloStrings s, KalloColors colors) {
    final RenderDevice? device = _device;
    final bool gpu = widget.renderMode.isGpu;
    final String graphics = device == null
        ? s.detecting
        : (device.gpu ?? s.noGpu);
    final String processor = device == null
        ? s.detecting
        : s.processorValue(device.cpu, device.cores);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.rendering,
          style: KalloType.title.copyWith(fontSize: 22, color: colors.ink),
        ),
        const SizedBox(height: KalloSpace.step2),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            gpu ? s.rendererGpuNote : s.rendererCpuNote,
            style: KalloType.body.copyWith(color: colors.inkMuted),
          ),
        ),
        const SizedBox(height: KalloSpace.step5),
        _Label(s.graphics, colors),
        const SizedBox(height: KalloSpace.step2),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            graphics,
            style: KalloType.data.copyWith(
              color: device == null || device.hasGpu
                  ? colors.ink
                  : colors.inkFaint,
            ),
          ),
        ),
        if (device != null && !device.hasGpu) ...<Widget>[
          const SizedBox(height: KalloSpace.step1 + 2),
          SizedBox(
            width: _fieldWidth(context),
            child: Text(
              s.noGpuNote,
              style: KalloType.small.copyWith(color: colors.inkFaint),
            ),
          ),
        ],
        const SizedBox(height: KalloSpace.step4),
        _Label(s.processor, colors),
        const SizedBox(height: KalloSpace.step2),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            processor,
            style: KalloType.data.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: KalloSpace.step5),
        _Label(s.engine, colors),
        const SizedBox(height: KalloSpace.step2),
        KalloSegments(
          options: <String>[s.rendererGpu, s.rendererCpu],
          selected: gpu ? 0 : 1,
          onSelect: (int i) =>
              widget.onRenderMode(i == 0 ? RenderMode.gpu : RenderMode.cpu),
        ),
      ],
    );
  }

  Widget _appearance(KalloStrings s, KalloColors colors) {
    final KalloScope scope = KalloScope.of(context);
    final String system =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark
        ? s.dark
        : s.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.appearance,
          style: KalloType.title.copyWith(fontSize: 22, color: colors.ink),
        ),
        const SizedBox(height: KalloSpace.step5),
        _Label(s.appearanceLabel, colors),
        const SizedBox(height: KalloSpace.step2),
        KalloSegments(
          options: <String>[s.system, s.light, s.dark],
          selected: switch (scope.pinned) {
            null => 0,
            Brightness.light => 1,
            Brightness.dark => 2,
          },
          onSelect: (int i) => scope.onPin(switch (i) {
            1 => Brightness.light,
            2 => Brightness.dark,
            _ => null,
          }),
        ),
        const SizedBox(height: KalloSpace.step2 + 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            s.systemLine(system),
            style: KalloType.data.copyWith(
              fontSize: 10,
              color: colors.inkFaint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _prints(KalloStrings s, KalloColors colors) {
    final ExportSetting export = widget.export;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.prints,
          style: KalloType.title.copyWith(fontSize: 22, color: colors.ink),
        ),
        const SizedBox(height: KalloSpace.step2),
        SizedBox(
          width: _fieldWidth(context),
          child: Text(
            s.printsNote,
            style: KalloType.body.copyWith(color: colors.inkMuted),
          ),
        ),
        const SizedBox(height: KalloSpace.step5),
        _Label(s.folder, colors),
        const SizedBox(height: KalloSpace.step2),
        Container(
          constraints: const BoxConstraints(maxWidth: 460),
          height: 34,
          padding: const EdgeInsets.only(left: KalloSpace.step3, right: 3),
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(KalloRadius.control),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  export.label.isEmpty ? s.noFolder : export.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KalloType.data.copyWith(
                    color: export.label.isEmpty ? colors.inkFaint : colors.ink,
                  ),
                ),
              ),
              if (export.canChoose)
                KalloButton(label: s.choose, onTap: export.onChoose),
            ],
          ),
        ),
        if (export.missingPrints > 0 ||
            export.repairablePrints > 0) ...<Widget>[
          const SizedBox(height: KalloSpace.step3),
          Text(
            s.catalogIssues(export.missingPrints, export.repairablePrints),
            style: KalloType.small.copyWith(color: colors.inkMuted),
          ),
          if (export.onRepair != null &&
              export.repairablePrints > 0) ...<Widget>[
            const SizedBox(height: KalloSpace.step2),
            Align(
              alignment: Alignment.centerRight,
              child: KalloButton(
                label: s.repairMarkers,
                onTap: export.onRepair,
              ),
            ),
          ],
        ],
        if (export.custom && export.onReset != null) ...<Widget>[
          const SizedBox(height: KalloSpace.step2),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: _fieldWidth(context),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: export.onReset,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    s.useDefault,
                    style: KalloType.small.copyWith(color: colors.inkMuted),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (!export.canChoose) ...<Widget>[
          const SizedBox(height: KalloSpace.step4),
          SizedBox(
            width: _fieldWidth(context),
            child: Text(
              export.canListAll ? s.fixedFolder : s.fixedFolderLimited,
              style: KalloType.small.copyWith(color: colors.inkFaint),
            ),
          ),
        ],
      ],
    );
  }

  Widget _language(KalloStrings s, KalloColors colors) {
    final String device = WidgetsBinding.instance.platformDispatcher.locale
        .toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.language,
          style: KalloType.title.copyWith(fontSize: 22, color: colors.ink),
        ),
        const SizedBox(height: KalloSpace.step2),
        Text(
          s.followsDevice,
          style: KalloType.body.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: KalloSpace.step4),
        _Label(s.interfaceLanguage, colors),
        const SizedBox(height: KalloSpace.step2),
        KalloSegments(
          options: <String>[s.system, '中文', 'English'],
          selected: widget.locale == null
              ? 0
              : (widget.locale!.languageCode == 'zh' ? 1 : 2),
          onSelect: (int i) => widget.onLocale(switch (i) {
            1 => const Locale('zh'),
            2 => const Locale('en'),
            _ => null,
          }),
        ),
        const SizedBox(height: KalloSpace.step2 + 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            s.deviceLine(device),
            style: KalloType.data.copyWith(
              fontSize: 10,
              color: colors.inkFaint,
            ),
          ),
        ),
        const SizedBox(height: KalloSpace.step4),
      ],
    );
  }
}

/// A link out of the app: a title, the address it goes to, and an arrow that
/// says the click leaves the window.
///
/// The repository and the changelog are the same page at two addresses, so
/// they are one row rather than two that look almost alike. The mark is
/// optional because the changelog is a page of text, not a place with an icon.
class _AboutLink extends StatefulWidget {
  const _AboutLink({
    super.key,
    required this.onTap,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.icon,
    this.height = 62,
  });

  final VoidCallback onTap;

  /// What a screen reader says the click does.
  final String label;

  final String title;
  final String subtitle;
  final KalloColors colors;

  /// The mark to draw before the title, when there is one.
  final String? icon;

  final double height;

  @override
  State<_AboutLink> createState() => _AboutLinkState();
}

class _AboutLinkState extends State<_AboutLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = widget.colors;
    final String? icon = widget.icon;
    final Color ink = _hover ? colors.ink : colors.inkMuted;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            width: (MediaQuery.sizeOf(context).width - 56).clamp(240.0, 460.0),
            height: widget.height,
            padding: const EdgeInsets.symmetric(
              horizontal: KalloSpace.step4,
              vertical: KalloSpace.step2,
            ),
            decoration: BoxDecoration(
              color: _hover ? colors.fillStrong : colors.fill,
              borderRadius: BorderRadius.circular(KalloRadius.card),
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Image.asset(
                    icon,
                    width: 20,
                    height: 20,
                    color: ink,
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: KalloSpace.step3),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: KalloType.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KalloType.data.copyWith(
                          fontSize: 11,
                          color: colors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KalloSpace.step3),
                CustomPaint(
                  size: const Size(12, 12),
                  painter: _OutboundMark(ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The update itself: a label on the left, what the row is doing on the
/// right, and a fill that is the same as the links under it.
///
/// The action is text rather than a button because it is the row's whole
/// state, not one more control on a page of controls.
class _UpdateRow extends StatefulWidget {
  const _UpdateRow({
    super.key,
    required this.label,
    required this.action,
    required this.onTap,
    required this.actionable,
    required this.width,
    required this.colors,
  });

  final String label;
  final String action;
  final VoidCallback? onTap;

  /// Whether the action text is something to do rather than a state to read.
  final bool actionable;

  final double width;
  final KalloColors colors;

  @override
  State<_UpdateRow> createState() => _UpdateRowState();
}

class _UpdateRowState extends State<_UpdateRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = widget.colors;
    final bool tappable = widget.onTap != null;
    final Color action = widget.actionable ? colors.accent : colors.inkFaint;
    return Semantics(
      button: tappable,
      child: MouseRegion(
        cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: KalloMotion.instant,
            width: widget.width,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: KalloSpace.step4),
            decoration: BoxDecoration(
              color: _hover && tappable ? colors.fillStrong : colors.fill,
              borderRadius: BorderRadius.circular(KalloRadius.card),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.label,
                    style: KalloType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: KalloSpace.step3),
                Flexible(
                  child: Text(
                    widget.action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: KalloType.small.copyWith(
                      fontWeight: FontWeight.w500,
                      color: action,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutboundMark extends CustomPainter {
  const _OutboundMark(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(2.5, 9.5), const Offset(9.5, 2.5), stroke);
    canvas.drawLine(const Offset(4.5, 2.5), const Offset(9.5, 2.5), stroke);
    canvas.drawLine(const Offset(9.5, 2.5), const Offset(9.5, 7.5), stroke);
  }

  @override
  bool shouldRepaint(_OutboundMark old) => old.colour != colour;
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.colors);

  final String text;
  final KalloColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: KalloType.caption.copyWith(color: colors.inkFaint),
    );
  }
}
