import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_info.dart';
import 'settings.dart';

/// Kallo updating itself, from the GitHub Releases page it is published on.
///
/// A desktop app installed from a zip has no store behind it, so the two
/// things a store would do are here: ask GitHub what the newest release is,
/// and, on macOS, replace the running bundle with it. Nothing in this file
/// touches a widget; the drawer reads it through [UpdateController].
///
/// The whole flow is one-directional — check, download, restart — because a
/// half-updated app is the one outcome worth designing against. The bundle is
/// only touched by a detached shell script, after this process has exited.

/// The file name release.yml attaches for an Apple-silicon Mac.
const String kUpdateAssetArm = 'kallo-desktop-macos-aarch64.zip';

/// The file name release.yml attaches for an Intel Mac.
const String kUpdateAssetIntel = 'kallo-desktop-macos-x86_64.zip';

/// The file name release.yml attaches when one build carries both slices.
const String kUpdateAssetUniversal = 'kallo-desktop-macos-universal.zip';

/// What went wrong, in the few kinds the interface has words for.
enum UpdateProblem {
  /// The request did not finish, or GitHub refused it.
  network,

  /// The answer was not the release document expected.
  malformed,

  /// This build is not one that can replace itself.
  unsupported,

  /// The release has no file for this machine.
  noAsset,

  /// The bundle is not somewhere it can be replaced from.
  location,

  /// The asset was not fetched.
  download,

  /// The asset was fetched, but not at the length the release said.
  size,

  /// The archive held no application this updater could find.
  extraction,

  /// The installer script could not be started.
  launch,
}

/// A failure the row can report, with the kind the interface names.
class UpdateInstallException implements Exception {
  const UpdateInstallException(this.problem, this.message);

  final UpdateProblem problem;

  /// The technical detail, for the log. The interface translates the kind.
  final String message;

  @override
  String toString() => 'update install failed (${problem.name}): $message';
}

/// One file attached to a release.
class UpdateAsset {
  const UpdateAsset({required this.name, required this.url, this.size});

  final String name;
  final Uri url;

  /// The length GitHub reports, or null when it did not say.
  final int? size;
}

/// One published release, as the updater reads it.
class UpdateRelease {
  const UpdateRelease({
    required this.tag,
    required this.version,
    required this.notes,
    required this.page,
    this.publishedAt,
    this.asset,
    this.isPreview = false,
  });

  /// The tag as GitHub writes it: `v0.2.0`, `app-v0.2.0`, …
  final String tag;

  /// The version without its tag prefix: `0.2.0`, `0.2.0-preview.1`.
  final String version;

  /// The release body. Not rendered in this version of the interface; kept
  /// because a release whose notes are not read is a release nobody writes.
  final String notes;

  /// The page a person can read, for when there is nothing to install.
  final Uri page;

  final DateTime? publishedAt;

  /// The one file this machine can install, or null when the release has none.
  final UpdateAsset? asset;

  /// Whether GitHub calls the release a prerelease.
  final bool isPreview;

  /// The version as the interface names it: `v0.2.0`.
  String get label => 'v$version';
}

/// What a check found.
sealed class UpdateCheck {
  const UpdateCheck();
}

/// The installed version is the newest the channel offers.
final class UpdateUpToDate extends UpdateCheck {
  const UpdateUpToDate();
}

/// There is a newer release than the one running.
final class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable(this.release);

  final UpdateRelease release;
}

/// The check could not answer, and the row offers a retry.
final class UpdateFailed extends UpdateCheck {
  const UpdateFailed({required this.problem, required this.message});

  final UpdateProblem problem;

  /// The technical detail, for the log.
  final String message;
}

/// A version, semver-shaped, as a release tag carries one.
///
/// The app's versions are two numbers and sometimes a preview: the comparison
/// only needs to be right about `0.2.0` being newer than `0.1.0`, and about
/// `0.2.0-preview.3` being older than `0.2.0`.
class UpdateVersion {
  const UpdateVersion(
    this.major,
    this.minor,
    this.patch, [
    this.prerelease = const <String>[],
  ]);

  final int major;
  final int minor;
  final int patch;

  /// The dot-separated identifiers after the hyphen, e.g. `preview`, `3`.
  final List<String> prerelease;

  /// The tag prefix release.yml writes: `v0.2.0` or `app-v0.2.0`.
  static final RegExp _prefix = RegExp(
    r'^(?:app-)?v(?=\d)',
    caseSensitive: false,
  );

  static final RegExp _shape = RegExp(
    r'^(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*))?'
    r'(?:\+[0-9A-Za-z.-]+)?$',
  );

  /// Reads a tag, or returns null when it is not a version this app can order.
  ///
  /// The `v` is tolerated and dropped: `KalloInfo.version` has none, and the
  /// comparison must not depend on which side of the tag a person is reading.
  static UpdateVersion? parse(String tag) {
    final String text = tag.trim().replaceFirst(_prefix, '');
    final RegExpMatch? match = _shape.firstMatch(text);
    if (match == null) {
      return null;
    }
    final String? prerelease = match[4];
    return UpdateVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3] ?? '0'),
      prerelease == null
          ? const <String>[]
          : List<String>.unmodifiable(prerelease.split('.')),
    );
  }

  /// Semver precedence: the numbers first, then the prerelease, where a
  /// released version outranks its own previews.
  static int compare(UpdateVersion a, UpdateVersion b) {
    if (a.major != b.major) {
      return a.major.compareTo(b.major);
    }
    if (a.minor != b.minor) {
      return a.minor.compareTo(b.minor);
    }
    if (a.patch != b.patch) {
      return a.patch.compareTo(b.patch);
    }
    return _comparePrerelease(a.prerelease, b.prerelease);
  }

  static int _comparePrerelease(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) {
      return 0;
    }
    // No prerelease is the release itself: newer than every preview of it.
    if (a.isEmpty) {
      return 1;
    }
    if (b.isEmpty) {
      return -1;
    }
    final int shared = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < shared; i++) {
      final int order = _compareIdentifier(a[i], b[i]);
      if (order != 0) {
        return order;
      }
    }
    return a.length.compareTo(b.length);
  }

  static int _compareIdentifier(String a, String b) {
    final int? first = int.tryParse(a);
    final int? second = int.tryParse(b);
    if (first != null && second != null) {
      return first.compareTo(second);
    }
    // A numeric identifier ranks below an alphanumeric one, as semver says.
    if (first != null) {
      return -1;
    }
    if (second != null) {
      return 1;
    }
    return a.compareTo(b);
  }

  /// The version without its tag prefix: `0.2.0`, `0.2.0-preview.1`.
  @override
  String toString() => prerelease.isEmpty
      ? '$major.$minor.$patch'
      : '$major.$minor.$patch-${prerelease.join('.')}';
}

/// Reads a small JSON document from GitHub. Injected by tests.
typedef UpdateFetcher = Future<String> Function(Uri url);

/// Opens a release asset's bytes. Injected by tests.
typedef UpdateDownloadOpener = Future<Stream<List<int>>> Function(Uri url);

/// A non-200 answer from GitHub, so the service can tell "no releases yet"
/// from "the network is down".
class UpdateRequestException implements Exception {
  const UpdateRequestException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Asks GitHub Releases what the newest Kallo is, and installs it on macOS.
///
/// The fetcher and the download opener are injectable so the decision logic —
/// what a tag means, which asset fits, what a failure reads as — is tested
/// without a network, and so a test on another platform can still exercise the
/// macOS paths.
class UpdateService {
  UpdateService({
    this.fetcher,
    this.openDownload,
    this.abi,
    this.macos,
    this.timeout = const Duration(seconds: 10),
    this.bundlePath,
    this.launchInstaller,
  });

  /// The two injectable edges of the network: the JSON read and the bytes of
  /// an asset. Both default to GitHub over [HttpClient].
  final UpdateFetcher? fetcher;
  final UpdateDownloadOpener? openDownload;

  /// The architecture an asset is chosen for; null asks the running process.
  final Abi? abi;

  /// Whether the platform can replace its own bundle; null asks the system.
  final bool? macos;

  /// How long any one step may take. The row must never hang on a check.
  final Duration timeout;

  /// Injected by tests: the bundle to replace, and the way to start the
  /// script. The real installer derives the first and exits from the second.
  final String? bundlePath;
  final Future<void> Function(String script)? launchInstaller;

  /// Whether this machine's Kallo can replace itself. Only macOS for now: it
  /// is the only build published as a self-contained bundle.
  bool get canInstall => macos ?? Platform.isMacOS;

  Abi get _currentAbi => abi ?? Abi.current();

  /// What the channel offers now. Never throws: a check that cannot answer is
  /// a failure the row can show and retry.
  Future<UpdateCheck> check(UpdateChannel channel) async {
    try {
      final bool listing = channel == UpdateChannel.preview;
      final Uri url = Uri.parse(
        listing
            ? '${KalloInfo.api}/releases?per_page=10'
            : '${KalloInfo.api}/releases/latest',
      );
      final String body = await _fetch(url).timeout(timeout);
      final Object? json = jsonDecode(body);
      final UpdateRelease? release = listing
          ? _newestRelease(json)
          : _singleRelease(json);
      if (release == null) {
        return const UpdateUpToDate();
      }
      final UpdateVersion? offered = UpdateVersion.parse(release.tag);
      final UpdateVersion? installed = UpdateVersion.parse(KalloInfo.version);
      if (offered == null ||
          installed == null ||
          UpdateVersion.compare(offered, installed) <= 0) {
        return const UpdateUpToDate();
      }
      return UpdateAvailable(release);
    } on TimeoutException {
      return const UpdateFailed(
        problem: UpdateProblem.network,
        message: 'the update check timed out',
      );
    } on UpdateRequestException catch (error) {
      // A repository with no published release answers 404 on `latest`; that
      // is "nothing to install yet", not a broken check.
      if (error.statusCode == HttpStatus.notFound) {
        return const UpdateUpToDate();
      }
      return UpdateFailed(
        problem: UpdateProblem.network,
        message: error.message,
      );
    } on FormatException catch (error) {
      return UpdateFailed(
        problem: UpdateProblem.malformed,
        message: 'the release document was not JSON: ${error.message}',
      );
    } on Object catch (error) {
      return UpdateFailed(problem: UpdateProblem.network, message: '$error');
    }
  }

  /// Downloads and starts the installer for [release] on macOS.
  ///
  /// The returned future in a real run never completes: the detached script
  /// waits for this process to exit, so this process exits (see
  /// [_launchAndExit]). A test injects a launcher that returns instead.
  Future<void> install(
    UpdateRelease release, {
    required ValueChanged<double> onProgress,
    VoidCallback? onRestarting,
  }) async {
    if (!canInstall) {
      throw const UpdateInstallException(
        UpdateProblem.unsupported,
        'this platform cannot replace its own bundle',
      );
    }
    final UpdateAsset? asset = release.asset;
    if (asset == null) {
      throw const UpdateInstallException(
        UpdateProblem.noAsset,
        'the release has no file for this machine',
      );
    }
    final String? bundle =
        bundlePath ?? bundleFromExecutable(Platform.resolvedExecutable);
    if (bundle == null) {
      throw const UpdateInstallException(
        UpdateProblem.location,
        'the app is not running from a .app bundle',
      );
    }
    if (bundle.contains('/Volumes/') || bundle.contains('AppTranslocation')) {
      throw UpdateInstallException(
        UpdateProblem.location,
        'the bundle is read-only or translocated: $bundle',
      );
    }

    final Directory temporary = await Directory.systemTemp.createTemp(
      'kallo-update-',
    );
    bool handedOff = false;
    try {
      final File archive = File('${temporary.path}/update.zip');
      final int received = await _download(asset, archive, onProgress);
      final int? expected = asset.size;
      if (expected != null && received != expected) {
        throw UpdateInstallException(
          UpdateProblem.size,
          'expected $expected bytes, received $received',
        );
      }
      onProgress(1);

      final Directory unpacked = Directory('${temporary.path}/unpacked');
      await unpacked.create();
      await _unzip(archive, unpacked);
      final Directory? app = _findApp(unpacked);
      if (app == null) {
        throw const UpdateInstallException(
          UpdateProblem.extraction,
          'the archive held no .app',
        );
      }

      final File script = File('${temporary.path}/install.sh');
      await script.writeAsString(
        installerScript(
          pid: pid,
          bundle: bundle,
          replacement: app.path,
          temporary: temporary.path,
        ),
      );
      // The row says it is restarting before the process that would draw it is
      // gone; a person sees the last state the old app can show.
      onRestarting?.call();
      handedOff = true;
      await _startInstaller(script.path);
    } finally {
      if (!handedOff) {
        // The next launch can start from a fresh folder; a half-downloaded
        // archive is not worth keeping.
        try {
          await temporary.delete(recursive: true);
        } on FileSystemException {
          // The system will clean its own temporary folder.
        }
      }
    }
  }

  Future<void> _startInstaller(String script) async {
    try {
      await (launchInstaller ?? _launchAndExit)(script);
    } on Object catch (error) {
      throw UpdateInstallException(UpdateProblem.launch, '$error');
    }
  }

  /// Starts the script detached and exits, so the script can outlive the app
  /// it is replacing.
  static Future<void> _launchAndExit(String script) async {
    await Process.start('/bin/sh', <String>[
      script,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<int> _download(
    UpdateAsset asset,
    File into,
    ValueChanged<double> onProgress,
  ) async {
    final int? expected = asset.size;
    final IOSink sink = into.openWrite();
    int received = 0;
    onProgress(0);
    try {
      final Stream<List<int>> bytes = await _openDownload(asset.url)
          .timeout(timeout);
      await for (final List<int> chunk in bytes.timeout(timeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (expected != null && expected > 0) {
          onProgress((received / expected).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } on Object catch (error) {
      throw UpdateInstallException(UpdateProblem.download, '$error');
    } finally {
      await sink.close();
    }
    return received;
  }

  Future<void> _unzip(File archive, Directory into) async {
    final ProcessResult result;
    try {
      result = await Process.run('/usr/bin/ditto', <String>[
        '-x',
        '-k',
        archive.path,
        into.path,
      ]).timeout(timeout);
    } on Object catch (error) {
      throw UpdateInstallException(UpdateProblem.extraction, '$error');
    }
    if (result.exitCode != 0) {
      throw UpdateInstallException(
        UpdateProblem.extraction,
        'ditto exited ${result.exitCode}: ${result.stderr}',
      );
    }
  }

  /// The one `.app` at the archive's root, or null when there is not one.
  Directory? _findApp(Directory root) {
    final List<Directory> apps = root
        .listSync(followLinks: false)
        .whereType<Directory>()
        .where((Directory entry) => entry.path.endsWith('.app'))
        .toList(growable: false);
    if (apps.length == 1) {
      return apps.single;
    }
    if (apps.length > 1) {
      throw UpdateInstallException(
        UpdateProblem.extraction,
        'the archive held ${apps.length} applications',
      );
    }
    return null;
  }

  /// The newest release in a list, prereleases included and drafts ignored.
  UpdateRelease? _newestRelease(Object? json) {
    if (json is! List) {
      throw const FormatException('the release list was not a list');
    }
    final List<UpdateRelease> releases = <UpdateRelease>[];
    for (final Object? entry in json) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      if (entry['draft'] == true) {
        continue;
      }
      final Object? tag = entry['tag_name'];
      if (tag is! String || UpdateVersion.parse(tag) == null) {
        // A tag this updater cannot order is skipped rather than guessed at.
        continue;
      }
      final UpdateRelease? release = _parseRelease(entry);
      if (release != null) {
        releases.add(release);
      }
    }
    if (releases.isEmpty) {
      return null;
    }
    releases.sort((UpdateRelease a, UpdateRelease b) {
      final DateTime? first = a.publishedAt;
      final DateTime? second = b.publishedAt;
      if (first == null && second == null) {
        return 0;
      }
      if (first == null) {
        return 1;
      }
      if (second == null) {
        return -1;
      }
      return second.compareTo(first);
    });
    return releases.first;
  }

  /// The single release `latest` answers with.
  UpdateRelease? _singleRelease(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('the release was not an object');
    }
    final Object? tag = json['tag_name'];
    if (tag is! String || UpdateVersion.parse(tag) == null) {
      throw const FormatException('the release had no usable tag');
    }
    return _parseRelease(json);
  }

  UpdateRelease? _parseRelease(Map<String, dynamic> json) {
    final Object? tag = json['tag_name'];
    if (tag is! String) {
      throw const FormatException('the release had no tag');
    }
    final UpdateVersion? version = UpdateVersion.parse(tag);
    if (version == null) {
      throw FormatException('the tag was not a version: $tag');
    }
    if (json['draft'] == true) {
      return null;
    }
    final Object? page = json['html_url'];
    final Uri pageUrl = page is String
        ? (Uri.tryParse(page) ?? Uri.parse(KalloInfo.releases))
        : Uri.parse(KalloInfo.releases);
    final Object? body = json['body'];
    final Object? published = json['published_at'];
    return UpdateRelease(
      tag: tag,
      version: version.toString(),
      notes: body is String ? body : '',
      page: pageUrl,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      asset: _selectAsset(_assets(json['assets'])),
      isPreview: json['prerelease'] == true,
    );
  }

  static List<UpdateAsset> _assets(Object? json) {
    if (json is! List) {
      return const <UpdateAsset>[];
    }
    final List<UpdateAsset> assets = <UpdateAsset>[];
    for (final Object? entry in json) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final Object? name = entry['name'];
      final Object? url = entry['browser_download_url'];
      if (name is! String || url is! String) {
        continue;
      }
      final Uri? parsed = Uri.tryParse(url);
      if (parsed == null) {
        continue;
      }
      final Object? size = entry['size'];
      assets.add(
        UpdateAsset(name: name, url: parsed, size: size is int ? size : null),
      );
    }
    return assets;
  }

  /// The file for this machine's architecture, or the universal one.
  UpdateAsset? _selectAsset(List<UpdateAsset> assets) {
    final String? preferred = switch (_currentAbi) {
      Abi.macosArm64 => kUpdateAssetArm,
      Abi.macosX64 => kUpdateAssetIntel,
      _ => null,
    };
    if (preferred == null) {
      return null;
    }
    for (final UpdateAsset asset in assets) {
      if (asset.name == preferred) {
        return asset;
      }
    }
    for (final UpdateAsset asset in assets) {
      if (asset.name == kUpdateAssetUniversal) {
        return asset;
      }
    }
    return null;
  }

  Future<String> _fetch(Uri url) => (fetcher ?? _fetchFromGitHub)(url);

  Future<String> _fetchFromGitHub(Uri url) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client.getUrl(url);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Kallo/${KalloInfo.version}',
      );
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateRequestException(
          response.statusCode,
          'GitHub answered ${response.statusCode}.',
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<Stream<List<int>>> _openDownload(Uri url) =>
      (openDownload ?? _openFromGitHub)(url);

  Future<Stream<List<int>>> _openFromGitHub(Uri url) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .getUrl(url)
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Kallo/${KalloInfo.version}',
      );
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateRequestException(
          response.statusCode,
          'the release asset answered ${response.statusCode}',
        );
      }
      // The response is the download; closing the client when it is done is
      // how the connection goes away on both success and failure.
      return _relay(response, client);
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }

  /// Hands the response's bytes on, and closes the client when the stream is
  /// finished or the listener lets go of it.
  static Stream<List<int>> _relay(
    HttpClientResponse response,
    HttpClient client,
  ) async* {
    try {
      yield* response;
    } finally {
      client.close(force: true);
    }
  }
}

/// The `.app` bundle an executable lives in, or null when it is not in one.
///
/// `Platform.resolvedExecutable` is `<bundle>/Contents/MacOS/<exe>`; the first
/// `.app` segment from the root is the bundle to replace, not any helper a
/// framework carries inside it.
String? bundleFromExecutable(String executable) {
  final List<String> segments = executable.split('/');
  final int end = segments.indexWhere(
    (String segment) => segment.endsWith('.app'),
  );
  if (end < 0) {
    return null;
  }
  return segments.sublist(0, end + 1).join('/');
}

/// Quotes one path for `/bin/sh`, apostrophes and all.
String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

/// The script that replaces the bundle once this process is gone.
///
/// It is written out rather than built inline in [install] so a test can read
/// the shell a person would have to debug, and check it parses.
String installerScript({
  required int pid,
  required String bundle,
  required String replacement,
  required String temporary,
}) {
  final String old = _shellQuote(bundle);
  final String next = _shellQuote(replacement);
  final String temp = _shellQuote(temporary);
  return '''#!/bin/sh
# Kallo replaces its own bundle. This runs detached, after the app has exited:
# a bundle cannot be moved while the process the old one spawned is alive.
set -eu
old=$old
new=$next
backup="\$old.kallo-old"
# Wait for the app this script belongs to. The process is gone when kill -0
# says so; nothing here touches the old bundle before that.
while kill -0 $pid 2>/dev/null; do
  /bin/sleep 0.2
done
rm -rf "\$backup"
mv "\$old" "\$backup"
if ! /usr/bin/ditto "\$new" "\$old"; then
  # Put the old app back rather than leave a half-copied one behind.
  rm -rf "\$old"
  mv "\$backup" "\$old"
  exit 1
fi
/usr/bin/xattr -dr com.apple.quarantine "\$old" 2>/dev/null || true
/usr/bin/open "\$old"
rm -rf "\$backup"
rm -rf $temp
''';
}

/// What the update row is doing.
enum UpdateStage {
  /// Nothing has been asked yet. The row offers the first check.
  idle,
  checking,
  upToDate,
  available,
  downloading,
  restarting,
  failed,
}

/// The update row's state, in one place, held by the drawer.
///
/// It is a [ChangeNotifier] so an injected one can drive a test, and so the
/// row never reads a variable it did not see change. It never checks by
/// itself: an update is something a person asks for.
class UpdateController extends ChangeNotifier {
  UpdateController({
    UpdateService? service,
    UpdateChannel initialChannel = UpdateChannel.stable,
    this.onChannelChanged,
  }) : _service = service ?? UpdateService(),
       _channel = initialChannel;

  final UpdateService _service;

  /// Called when a person moves the switch, so the choice can be remembered
  /// beyond the window. The drawer's own controller has no callback: the
  /// settings file is loaded and saved by the app, not by this row.
  final ValueChanged<UpdateChannel>? onChannelChanged;

  UpdateChannel _channel;
  UpdateStage _stage = UpdateStage.idle;
  UpdateRelease? _release;
  UpdateProblem? _problem;
  double _progress = 0;
  int _checks = 0;
  bool _disposed = false;

  UpdateChannel get channel => _channel;
  bool get preview => _channel == UpdateChannel.preview;
  UpdateStage get stage => _stage;

  /// The release the row is about, while there is one.
  UpdateRelease? get release => _release;

  /// Why the last failure happened; null when the row has no failure.
  UpdateProblem? get problem => _problem;

  /// The fraction of the download that is done, 0..1.
  double get progress => _progress;

  /// Whether the machine can install this release without leaving the app.
  bool get canInstall => _service.canInstall && _release?.asset != null;

  /// Whether the row is in the middle of something, and so is not a button.
  bool get busy =>
      _stage == UpdateStage.checking ||
      _stage == UpdateStage.downloading ||
      _stage == UpdateStage.restarting;

  /// Switches channel and forgets the old answer: a preview and a stable
  /// release are different facts, so the row starts again.
  void setChannel(UpdateChannel next) {
    if (next == _channel || busy) {
      return;
    }
    _channel = next;
    _checks++;
    _stage = UpdateStage.idle;
    _release = null;
    _problem = null;
    _progress = 0;
    _notify();
    onChannelChanged?.call(next);
  }

  /// Asks GitHub what the channel offers, and shows the answer.
  Future<void> check() async {
    if (busy) {
      return;
    }
    final int token = ++_checks;
    _stage = UpdateStage.checking;
    _release = null;
    _problem = null;
    _progress = 0;
    _notify();
    UpdateCheck result;
    try {
      result = await _service.check(_channel);
    } on Object catch (error) {
      // The service answers its own failures; this is the last guard, so a row
      // can never be left waiting on a future that threw.
      result = UpdateFailed(problem: UpdateProblem.network, message: '$error');
    }
    if (token != _checks) {
      // The channel changed, or another check began, while this one was out.
      return;
    }
    switch (result) {
      case UpdateUpToDate():
        _stage = UpdateStage.upToDate;
      case UpdateAvailable(:final UpdateRelease release):
        _stage = UpdateStage.available;
        _release = release;
      case UpdateFailed(:final UpdateProblem problem, :final String message):
        _stage = UpdateStage.failed;
        _problem = problem;
        debugPrint('kallo: update check failed (${problem.name}): $message');
    }
    _notify();
  }

  /// Downloads the release and hands the bundle to the installer.
  Future<void> install() async {
    final UpdateRelease? release = _release;
    if (busy || release == null || !canInstall) {
      return;
    }
    _stage = UpdateStage.downloading;
    _problem = null;
    _progress = 0;
    _notify();
    try {
      await _service.install(
        release,
        onProgress: (double value) {
          if (_stage != UpdateStage.downloading) {
            return;
          }
          _progress = value.clamp(0.0, 1.0);
          _notify();
        },
        onRestarting: _restarting,
      );
      // The real installer exits this process and never returns; a test's
      // launcher can, and the row should still be in its last state.
      _restarting();
    } on UpdateInstallException catch (error) {
      debugPrint(
        'kallo: update install failed (${error.problem.name}): ${error.message}',
      );
      _fail(error.problem);
    } on Object catch (error) {
      debugPrint('kallo: update install failed: $error');
      _fail(UpdateProblem.download);
    }
  }

  void _fail(UpdateProblem problem) {
    _stage = UpdateStage.failed;
    _problem = problem;
    _progress = 0;
    _notify();
  }

  void _restarting() {
    if (_stage == UpdateStage.restarting) {
      return;
    }
    _stage = UpdateStage.restarting;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
