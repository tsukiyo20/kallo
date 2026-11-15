import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../design/mobile.dart';
import '../../design/scope.dart';
import '../../design/strings.dart';
import '../../design/tokens.dart';
import 'mobile_controls.dart';
import 'mobile_icon.dart';

/// A sheet from the bottom of a phone.
///
/// It is a route over the room, not a Material bottom sheet: the barrier is the
/// room's own scrim, the card is the surface plane with a hairline, and the
/// drag handle is a five-point rectangle rather than an affordance borrowed
/// from another design system.
Future<T?> showKalloMobileSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  String? barrierLabel,
}) {
  final KalloColors colors = KalloScope.colorsOf(context);
  final KalloStrings s = KalloStrings.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: barrierLabel ?? s.cancel,
    barrierColor: colors.scrim,
    transitionDuration: KalloMotion.settle,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondary,
        ) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.92,
                  ),
                  child: Builder(builder: builder),
                ),
              ),
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) => SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: KalloMotion.enter),
              ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: KalloMotion.enter,
            ),
            child: child,
          ),
        ),
  );
}

/// The card every mobile sheet is drawn on.
class KalloMobileSheet extends StatelessWidget {
  const KalloMobileSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.height,
    this.scrollable = false,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onClose;
  final double? height;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final KalloColors colors = KalloScope.colorsOf(context);
    final Widget body = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: KalloMobileSpace.step5),
            child: child,
          )
        : child;
    return Container(
      width: double.infinity,
      height: height,
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KalloMobileRadius.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: KalloMobileSpace.step2),
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (title != null)
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Text(
                    title!,
                    style: KalloMobileType.headline.copyWith(color: colors.ink),
                  ),
                  if (onClose != null)
                    Positioned(
                      right: KalloMobileSpace.step3,
                      child: KalloIconButton(
                        glyph: KalloGlyph.close,
                        semanticLabel: KalloStrings.of(context).close,
                        onTap: onClose,
                        size: KalloMobileSpace.touch,
                        glyphSize: 16,
                        foreground: colors.inkMuted,
                        background: colors.fill,
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: KalloMobileSpace.step2),
          Flexible(child: body),
        ],
      ),
    );
  }
}

/// A destructive question with two real answers.
Future<bool> showKalloConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String? cancel,
}) async {
  final KalloStrings s = KalloStrings.of(context);
  final KalloColors colors = KalloScope.colorsOf(context);
  final bool? answer = await showKalloMobileSheet<bool>(
    context,
    builder: (BuildContext sheetContext) => KalloMobileSheet(
      title: title,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              message,
              style: KalloMobileType.body.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloMobileSpace.step5),
            KalloMobileButton(
              label: confirm,
              destructive: true,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: KalloMobileSpace.step2),
            KalloMobileButton(
              label: cancel ?? s.cancel,
              filled: false,
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return answer ?? false;
}

/// The app's own explanation before a system permission dialog.
///
/// Android's dialog cannot say why Kallo wants the library, and showing it at
/// launch asks before the person has done anything. This is the sentence the
/// dialog cannot carry; the system dialog follows only if the answer is yes.
Future<bool> showKalloPhotoAccessSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  required String cancel,
}) async {
  final KalloStrings s = KalloStrings.of(context);
  final KalloColors colors = KalloScope.colorsOf(context);
  final bool? answer = await showKalloMobileSheet<bool>(
    context,
    builder: (BuildContext sheetContext) => KalloMobileSheet(
      title: title,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              message,
              style: KalloMobileType.body.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: KalloMobileSpace.step5),
            KalloMobileButton(
              label: confirm,
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: KalloMobileSpace.step2),
            KalloMobileButton(
              label: cancel.isEmpty ? s.cancel : cancel,
              filled: false,
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return answer ?? false;
}

/// One choice in a compact action list.
class KalloMobileChoice {
  const KalloMobileChoice({
    required this.value,
    required this.label,
    this.subtitle,
    this.selected = false,
  });

  final String value;
  final String label;
  final String? subtitle;
  final bool selected;
}

/// A list of choices in a sheet; the value comes back, the sheet closes.
Future<String?> showKalloMobileChoices(
  BuildContext context, {
  required String title,
  required List<KalloMobileChoice> choices,
}) {
  final KalloColors colors = KalloScope.colorsOf(context);
  return showKalloMobileSheet<String>(
    context,
    builder: (BuildContext sheetContext) => KalloMobileSheet(
      title: title,
      onClose: () => Navigator.of(sheetContext).pop(),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: KalloMobileSpace.step5),
        itemCount: choices.length,
        separatorBuilder: (_, _) =>
            const KalloMobileDivider(inset: KalloMobileSpace.step5),
        itemBuilder: (BuildContext context, int index) {
          final KalloMobileChoice choice = choices[index];
          return KalloMobileRow(
            title: choice.label,
            subtitle: choice.subtitle,
            chevron: false,
            trailing: choice.selected
                ? KalloGlyphView(
                    KalloGlyph.check,
                    size: 17,
                    color: colors.accent,
                  )
                : null,
            minHeight: 52,
            onTap: () => Navigator.of(sheetContext).pop(choice.value),
          );
        },
      ),
    ),
  );
}

/// A picture, full screen, on the phone's own black.
Future<void> showKalloImageViewer(
  BuildContext context, {
  required ui.Image image,
  required String semanticLabel,
  String? caption,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: semanticLabel,
    barrierColor: const Color(0xFF000000),
    transitionDuration: KalloMotion.quick,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondary,
        ) {
          final KalloStrings s = KalloStrings.of(dialogContext);
          return ColoredBox(
            color: const Color(0xFF000000),
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Semantics(
                        image: true,
                        label: semanticLabel,
                        child: RawImage(
                          image: image,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: KalloMobileSpace.step2,
                    right: KalloMobileSpace.step2,
                    child: KalloIconButton(
                      glyph: KalloGlyph.close,
                      semanticLabel: s.close,
                      onTap: () => Navigator.of(dialogContext).pop(),
                      foreground: const Color(0xFFF5F5F7),
                      background: const Color(0x66000000),
                    ),
                  ),
                  if (caption != null)
                    Positioned(
                      left: KalloMobileSpace.step4,
                      right: KalloMobileSpace.step4,
                      bottom: KalloMobileSpace.step4,
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: KalloMobileType.footnote.copyWith(
                          color: const Color(0xFFAEAEB2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: KalloMotion.enter),
          child: child,
        ),
  );
}
