import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../design/mobile.dart';
import '../../design/scope.dart';
import '../../design/strings.dart';
import '../../design/tokens.dart';
import '../../lab/exports.dart';
import '../../widgets/mobile/mobile_controls.dart';
import '../../widgets/mobile/mobile_icon.dart';

/// Settings on a phone: one grouped page, closed with Done.
///
/// It is not a drawer over the bench. Appearance, language, the library and
/// the colour path are rows in the same list; About is a row at the bottom, not
/// the first tab of a rail.
class KalloMobileSettings extends StatelessWidget {
  const KalloMobileSettings({
    super.key,
    required this.locale,
    required this.onLocale,
    required this.spectral,
    required this.onSpectral,
    required this.export,
    required this.onClose,
  });

  final Locale? locale;
  final ValueChanged<Locale?> onLocale;
  final bool spectral;
  final ValueChanged<bool> onSpectral;
  final ExportSetting export;
  final VoidCallback onClose;

  Future<void> _openRepository() async {
    try {
      await launchUrl(
        Uri.parse(KalloInfo.repository),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      // The system is the one that knows whether a browser exists.
    }
  }

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final KalloScope scope = KalloScope.of(context);
    final int appearance = scope.pinned == null
        ? 0
        : (scope.pinned == Brightness.light ? 1 : 2);
    return ColoredBox(
      color: colors.ground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Text(
                    s.settings,
                    style: KalloMobileType.headline.copyWith(color: colors.ink),
                  ),
                  Positioned(
                    right: KalloMobileSpace.step4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClose,
                      child: SizedBox(
                        height: KalloMobileSpace.touch,
                        child: Center(
                          child: Text(
                            s.done,
                            style: KalloMobileType.headline.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('mobile-settings-page'),
                padding: const EdgeInsets.only(bottom: KalloMobileSpace.step7),
                children: <Widget>[
                  KalloMobileSectionHeader(s.tabAppearance),
                  KalloMobileGroup(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KalloMobileSpace.step4,
                        KalloMobileSpace.step2,
                        KalloMobileSpace.step4,
                        KalloMobileSpace.step3,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              s.interface,
                              style: KalloMobileType.callout.copyWith(
                                color: colors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 196,
                            child: KalloSegmented(
                              options: <String>[s.system, s.light, s.dark],
                              selected: appearance,
                              onSelect: (int index) =>
                                  scope.onPin(switch (index) {
                                    1 => Brightness.light,
                                    2 => Brightness.dark,
                                    _ => null,
                                  }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KalloMobileSpace.screen + 2,
                      KalloMobileSpace.step2,
                      KalloMobileSpace.screen + 2,
                      0,
                    ),
                    child: Text(
                      s.followsDevice,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                  KalloMobileSectionHeader(s.tabLanguage),
                  KalloMobileGroup(
                    child: Column(
                      children: <Widget>[
                        _LanguageRow(
                          label: s.system,
                          selected: locale == null,
                          onTap: () => onLocale(null),
                        ),
                        const KalloMobileDivider(),
                        _LanguageRow(
                          label: 'English',
                          selected: locale?.languageCode == 'en',
                          onTap: () => onLocale(const Locale('en')),
                        ),
                        const KalloMobileDivider(),
                        _LanguageRow(
                          label: '中文',
                          selected: locale?.languageCode == 'zh',
                          onTap: () => onLocale(const Locale('zh')),
                        ),
                      ],
                    ),
                  ),
                  KalloMobileSectionHeader(s.tabPrints),
                  KalloMobileGroup(
                    child: Column(
                      children: <Widget>[
                        KalloMobileRow(
                          title: s.folder,
                          subtitle: export.label.isEmpty ? s.noFolder : null,
                          value: export.label.isEmpty ? null : export.label,
                          chevron: export.canChoose && export.onChoose != null,
                          onTap: export.canChoose ? export.onChoose : null,
                        ),
                        if (export.onPhotoAccess != null) ...<Widget>[
                          const KalloMobileDivider(),
                          KalloMobileRow(
                            title: s.photoAccess,
                            value: !export.photoAccess
                                ? s.photoAccessDenied
                                : (export.canListAll
                                      ? s.photoAccessAllowed
                                      : s.photoAccessLimited),
                            chevron: !export.photoAccess || !export.canListAll,
                            onTap: !export.photoAccess || !export.canListAll
                                ? export.onPhotoAccess
                                : null,
                          ),
                        ],
                        if (export.onImport != null) ...<Widget>[
                          const KalloMobileDivider(),
                          KalloMobileRow(
                            title: s.importImages,
                            chevron: true,
                            onTap: export.onImport,
                          ),
                        ],
                        if (export.missingPrints > 0 ||
                            export.repairablePrints > 0) ...<Widget>[
                          const KalloMobileDivider(),
                          KalloMobileRow(
                            title: s.repairMarkers,
                            subtitle: s.catalogIssues(
                              export.missingPrints,
                              export.repairablePrints,
                            ),
                            chevron: false,
                            onTap:
                                export.repairablePrints > 0 &&
                                    export.onRepair != null
                                ? export.onRepair
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KalloMobileSpace.screen + 2,
                      KalloMobileSpace.step2,
                      KalloMobileSpace.screen + 2,
                      0,
                    ),
                    child: Text(
                      export.canListAll ? s.fixedFolder : s.fixedFolderLimited,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                  KalloMobileSectionHeader(s.tabColour),
                  KalloMobileGroup(
                    child: KalloMobileRow(
                      title: s.spectralPath,
                      subtitle: s.path,
                      chevron: false,
                      trailing: KalloMobileSwitch(
                        on: spectral,
                        onTap: () => onSpectral(!spectral),
                        label: s.spectralPath,
                      ),
                      onTap: () => onSpectral(!spectral),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KalloMobileSpace.screen + 2,
                      KalloMobileSpace.step2,
                      KalloMobileSpace.screen + 2,
                      0,
                    ),
                    child: Text(
                      s.spectralNote,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                  KalloMobileSectionHeader(s.tabAbout),
                  KalloMobileGroup(
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(KalloMobileSpace.step3),
                          child: Row(
                            children: <Widget>[
                              Image.asset(
                                'assets/kallo-icon.png',
                                width: 38,
                                height: 38,
                              ),
                              const SizedBox(width: KalloMobileSpace.step3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      KalloInfo.name,
                                      style: KalloMobileType.callout.copyWith(
                                        color: colors.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      s.appVersion(KalloInfo.version),
                                      style: KalloMobileType.footnote.copyWith(
                                        color: colors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const KalloMobileDivider(),
                        KalloMobileRow(
                          title: s.openRepository,
                          chevron: true,
                          onTap: _openRepository,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KalloMobileSpace.screen + 2,
                      KalloMobileSpace.step4,
                      KalloMobileSpace.screen + 2,
                      0,
                    ),
                    child: Text(
                      s.applyAtOnce,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return KalloMobileRow(
      title: label,
      chevron: false,
      trailing: selected
          ? KalloGlyphView(KalloGlyph.check, size: 18, color: colors.accent)
          : null,
      onTap: onTap,
    );
  }
}
