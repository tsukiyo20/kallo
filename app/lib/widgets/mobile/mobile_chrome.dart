import 'package:flutter/widgets.dart';

import '../../design/mobile.dart';
import '../../design/scope.dart';
import '../../design/strings.dart';
import '../../design/tokens.dart';
import '../../views/chambers.dart';
import '../../views/steps.dart';
import 'mobile_controls.dart';
import 'mobile_icon.dart';

/// The compact darkroom header: the three steps, and the one way out to
/// settings.
class KalloMobileDarkroomBar extends StatelessWidget {
  const KalloMobileDarkroomBar({
    super.key,
    required this.current,
    required this.onStep,
    required this.onSettings,
  });

  final DarkroomStep current;
  final ValueChanged<DarkroomStep> onStep;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    return Container(
      height: KalloMobileSize.nav,
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool showBrand = constraints.maxWidth >= 356;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (showBrand)
                Positioned(
                  left: KalloMobileSpace.step4,
                  child: Text(
                    'KALLO',
                    style: KalloMobileType.micro.copyWith(
                      color: colors.inkMuted,
                      letterSpacing: 1.7,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              SizedBox(
                width: constraints.maxWidth >= 356 ? 196 : 172,
                child: KalloSegmented(
                  options: <String>[s.developStep, s.printStep],
                  selected: current.index,
                  onSelect: (int index) => onStep(DarkroomStep.values[index]),
                ),
              ),
              Positioned(
                right: KalloMobileSpace.step2,
                child: KalloIconButton(
                  key: const Key('mobile-settings'),
                  glyph: KalloGlyph.gear,
                  semanticLabel: s.settings,
                  onTap: onSettings,
                  glyphSize: 20,
                  foreground: colors.ink,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A room's large title, with the same gear in the same corner.
class KalloMobileRoomHeader extends StatelessWidget {
  const KalloMobileRoomHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSettings,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSettings;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    return SizedBox(
      height: KalloMobileSize.roomHeader,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KalloMobileSpace.screen,
          KalloMobileSpace.step4,
          KalloMobileSpace.step2,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KalloMobileType.largeTitle.copyWith(
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KalloMobileType.footnote.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            KalloIconButton(
              key: const Key('mobile-settings'),
              glyph: KalloGlyph.gear,
              semanticLabel: s.settings,
              onTap: onSettings,
              glyphSize: 20,
              foreground: colors.ink,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two places, never three. Settings is a gear, not a room.
class KalloMobileTabBar extends StatelessWidget {
  const KalloMobileTabBar({
    super.key,
    required this.current,
    required this.onChamber,
  });

  final Chamber current;
  final ValueChanged<Chamber> onChamber;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final KalloStrings s = KalloStrings.of(context);
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SizedBox(
        height: KalloMobileSize.tab,
        child: Row(
          children: <Widget>[
            _Tab(
              key: const Key('mobile-tab-darkroom'),
              glyph: KalloGlyph.darkroom,
              label: s.darkroom,
              selected: current == Chamber.darkroom,
              onTap: () => onChamber(Chamber.darkroom),
            ),
            _Tab(
              key: const Key('mobile-tab-gallery'),
              glyph: KalloGlyph.gallery,
              label: s.galleryTab,
              selected: current == Chamber.gallery,
              onTap: () => onChamber(Chamber.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final KalloGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final Color tint = selected ? colors.accent : colors.inkFaint;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              KalloGlyphView(glyph, size: 24, color: tint, stroke: 1.6),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KalloMobileType.caption.copyWith(
                  color: tint,
                  fontSize: 10,
                  letterSpacing: 0.05,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
