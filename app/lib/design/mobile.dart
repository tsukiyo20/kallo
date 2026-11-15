import 'dart:io';

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Which shell the window is wearing.
///
/// The desktop studio is a three-pane room. A phone is not a small one: it has
/// one column, a bottom bar and sheets, and the same model underneath. The
/// breakpoints are here so no screen invents its own.
abstract final class KalloLayout {
  /// A phone, a phone in landscape, or a narrow window.
  ///
  /// The width test keeps the old behaviour for a desktop window dragged narrow.
  /// The shortest-side test is what stops an iPhone in landscape (844 × 390)
  /// from falling back to the desktop shell. A touch tablet is compact too,
  /// because two side panes on a 768-point screen is not a layout.
  static bool isCompact(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    // `defaultTargetPlatform` is Android under `flutter test`, even on a Mac;
    // the host's own platform is the one that tells a phone from a window.
    final bool touch = Platform.isIOS || Platform.isAndroid;
    if (size.shortestSide < 600) {
      return true;
    }
    if (size.width < 700) {
      return true;
    }
    return touch && size.shortestSide < 900;
  }

  /// A phone held sideways. The compact shell is still used; only the inside
  /// of the stage changes.
  static bool isLandscapePhone(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return isCompact(context) && size.width > size.height && size.height < 600;
  }

  static double safeTop(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  static double safeBottom(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom;
}

/// The compact type ramp.
///
/// It is a closed set like the desktop one: a screen names a role, never a
/// number. The desktop keeps [`KalloType`]; this is only what a phone reads.
abstract final class KalloMobileType {
  static const String _sans = KalloType.sans;
  static const List<String> _fallback = KalloType.fallback;
  static const List<FontFeature> _tabular = <FontFeature>[FontFeature('tnum')];

  static const TextStyle largeTitle = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 32,
    height: 1.18,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 22,
    height: 1.24,
    letterSpacing: -0.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 17,
    height: 1.28,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 17,
    height: 1.42,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle callout = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    height: 1.32,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle subhead = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 14,
    height: 1.34,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle footnote = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    height: 1.38,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 1.26,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle plate = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 32,
    height: 1.08,
    letterSpacing: -0.9,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  static const TextStyle data = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w400,
    fontFeatures: _tabular,
  );

  static const TextStyle micro = TextStyle(
    fontFamily: _sans,
    fontFamilyFallback: _fallback,
    fontSize: 9.5,
    height: 1.2,
    letterSpacing: 1.0,
    fontWeight: FontWeight.w600,
  );
}

/// The compact spacing ramp. It is the desktop ramp plus a 20-point gap for
/// the instrument deck; there is no per-screen 18 or 22.
abstract final class KalloMobileSpace {
  static const double step0 = 2;
  static const double step1 = 4;
  static const double step2 = 8;
  static const double step3 = 12;
  static const double step4 = 16;
  static const double step5 = 20;
  static const double step6 = 24;
  static const double step7 = 32;

  static const double screen = 16;
  static const double row = 56;
  static const double touch = 44;
}

/// The compact corner set.
abstract final class KalloMobileRadius {
  static const double control = 10;
  static const double card = 16;
  static const double action = 14;
  static const double sheet = 28;
  static const double pill = 999;
}

/// Fixed heights a phone shell is built around.
abstract final class KalloMobileSize {
  static const double nav = 52;
  static const double tab = 49;
  static const double roomHeader = 96;
  static const double cta = 50;
  static const double control = 44;
  static const double deckRow = 54;
}
