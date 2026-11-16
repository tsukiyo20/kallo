/// Who the app is.
///
/// The version is repeated from `pubspec.yaml` because Flutter does not expose
/// the package's version to the Dart runtime. `app_info_test.dart` reads the
/// pubspec and fails when the two disagree.
abstract final class KalloInfo {
  static const String name = 'Kallo';
  static const String version = '0.2.1';
  static const String repository = 'https://github.com/tsukiyo20/kallo';

  /// The releases page: GitHub's human page for the same repository.
  ///
  /// The changelog row and the update row's fallback both point here, so the
  /// address lives beside the version it describes rather than in a widget.
  static const String releases = 'https://github.com/tsukiyo20/kallo/releases';

  /// The API root the updater reads releases from.
  ///
  /// GitHub's API is a different host from the page a person opens; both are
  /// derived from the same two names, and neither is allowed to drift.
  static const String api = 'https://api.github.com/repos/tsukiyo20/kallo';
}
