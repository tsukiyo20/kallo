import 'package:flutter/widgets.dart';

import '../../design/mobile.dart';
import '../../design/scope.dart';
import '../../design/tokens.dart';
import 'mobile_icon.dart';

/// One action on a phone page.
///
/// It is 50 points tall because a thumb is not a pointer, and it is the only
/// filled surface on the page. The compact shell never has two primaries.
class KalloMobileButton extends StatelessWidget {
  const KalloMobileButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.height = KalloMobileSize.cta,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final double height;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final bool enabled = onTap != null;
    final Color background = !enabled
        ? colors.fill
        : destructive
        ? colors.accent
        : filled
        ? colors.accent
        : colors.fill;
    final Color foreground = !enabled
        ? colors.inkFaint
        : filled || destructive
        ? colors.onAccent
        : colors.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: KalloMotion.quick,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: KalloMobileSpace.step4,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(KalloMobileRadius.action),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KalloMobileType.headline.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

/// A three- or four-way choice, sized for a thumb.
///
/// The visual track is 34 points; the row around it is 44, so the touch target
/// is the one the design asks for even though the control looks like iOS.
class KalloSegmented extends StatelessWidget {
  const KalloSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.height = 34,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return SizedBox(
      height: KalloMobileSpace.touch,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            height: height,
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: BorderRadius.circular(KalloMobileRadius.control),
            ),
          ),
          Row(
            children: <Widget>[
              for (int i = 0; i < options.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Center(
                        child: AnimatedContainer(
                          duration: KalloMotion.quick,
                          curve: KalloMotion.enter,
                          height: height - 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == selected ? colors.surface : null,
                            borderRadius: BorderRadius.circular(
                              KalloMobileRadius.control - 2,
                            ),
                            border: i == selected
                                ? Border.all(color: colors.hairline)
                                : null,
                          ),
                          child: Text(
                            options[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KalloMobileType.caption.copyWith(
                              color: i == selected
                                  ? colors.ink
                                  : colors.inkMuted,
                              fontWeight: i == selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 12.5,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A switch with a 44-point row around a 47 × 28 control.
class KalloMobileSwitch extends StatelessWidget {
  const KalloMobileSwitch({
    super.key,
    required this.on,
    required this.onTap,
    this.label,
  });

  final bool on;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Semantics(
      label: label,
      toggled: on,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: KalloMobileSpace.touch,
          child: Center(
            child: AnimatedContainer(
              duration: KalloMotion.quick,
              curve: KalloMotion.enter,
              width: 47,
              height: 28,
              decoration: BoxDecoration(
                color: on ? colors.accent : colors.fillStrong,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration: KalloMotion.quick,
                curve: KalloMotion.enter,
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: on ? colors.onAccent : colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A grouped-list row: a title, an optional subtitle, an optional trailing
/// value or chevron.
class KalloMobileRow extends StatelessWidget {
  const KalloMobileRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.value,
    this.trailing,
    this.chevron = true,
    this.onTap,
    this.minHeight = KalloMobileSpace.row,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final Widget body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KalloMobileSpace.step4,
          vertical: KalloMobileSpace.step2,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: KalloMobileSpace.step3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KalloMobileType.callout.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KalloMobileType.footnote.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: KalloMobileSpace.step2),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: KalloMobileType.footnote.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ),
              ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: KalloMobileSpace.step2),
              trailing!,
            ],
            if (chevron) ...<Widget>[
              const SizedBox(width: KalloMobileSpace.step1),
              KalloGlyphView(
                KalloGlyph.chevronRight,
                size: 16,
                color: colors.inkFaint,
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      ),
    );
  }
}

/// A section header above a grouped card.
class KalloMobileSectionHeader extends StatelessWidget {
  const KalloMobileSectionHeader(this.label, {super.key, this.padding});

  final String label;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            KalloMobileSpace.screen + 2,
            KalloMobileSpace.step6,
            KalloMobileSpace.screen + 2,
            KalloMobileSpace.step2,
          ),
      child: Text(
        label.toUpperCase(),
        style: KalloMobileType.caption.copyWith(
          color: colors.inkMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A card holding grouped rows.
class KalloMobileGroup extends StatelessWidget {
  const KalloMobileGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KalloMobileSpace.screen),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(KalloMobileRadius.card),
        border: Border.all(color: colors.hairline.withValues(alpha: 0.75)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// A hairline between rows, inset past the leading glyph.
class KalloMobileDivider extends StatelessWidget {
  const KalloMobileDivider({super.key, this.inset = KalloMobileSpace.step4});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: EdgeInsets.only(left: inset),
      color: KalloScope.colorsOf(context).hairline,
    );
  }
}

/// A page with nothing in it that still has a door.
class KalloMobileEmpty extends StatelessWidget {
  const KalloMobileEmpty({
    super.key,
    required this.glyph,
    required this.title,
    required this.message,
    this.action,
    this.footnote,
  });

  final KalloGlyph glyph;
  final String title;
  final String message;
  final Widget? action;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KalloMobileSpace.step7,
            vertical: KalloMobileSpace.step6,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: colors.fill,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: KalloGlyphView(
                      glyph,
                      size: 34,
                      color: colors.inkMuted,
                      stroke: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: KalloMobileSpace.step5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: KalloMobileType.title.copyWith(color: colors.ink),
                ),
                const SizedBox(height: KalloMobileSpace.step2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: KalloMobileType.body.copyWith(color: colors.inkMuted),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: KalloMobileSpace.step6),
                  action!,
                ],
                if (footnote != null) ...<Widget>[
                  const SizedBox(height: KalloMobileSpace.step4),
                  Text(
                    footnote!,
                    textAlign: TextAlign.center,
                    style: KalloMobileType.footnote.copyWith(
                      color: colors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
