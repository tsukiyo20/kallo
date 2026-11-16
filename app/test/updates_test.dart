import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/strings.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/lab/exports.dart';
import 'package:kallo/lab/render_mode.dart';
import 'package:kallo/lab/updates.dart';
import 'package:kallo/views/drawer.dart';

/// One release as GitHub's API writes it, with the fields the updater reads.
Map<String, Object?> _release({
  String tag = 'v0.2.0',
  bool draft = false,
  bool prerelease = false,
  String? published = '2026-01-02T00:00:00Z',
  String? body = 'the notes',
  String? html,
  List<Map<String, Object?>> assets = const <Map<String, Object?>>[],
}) => <String, Object?>{
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'published_at': published,
  'body': body,
  'html_url': html ?? '$kReleases/tag/$tag',
  'assets': assets,
};

Map<String, Object?> _asset(String name, {int size = 4096, String? url}) =>
    <String, Object?>{
      'name': name,
      'browser_download_url': url ?? 'https://example.test/$name',
      'size': size,
    };

String _json(Object? value) => jsonEncode(value);

const String kReleases = 'https://github.com/tsukiyo20/kallo/releases';

/// A service whose network is one canned body. [requests] records the URL.
UpdateService _service(
  String body, {
  Abi abi = Abi.macosArm64,
  bool macos = true,
  bool windows = false,
  List<Uri>? requests,
}) => UpdateService(
  abi: abi,
  macos: macos,
  windows: windows,
  fetcher: (Uri url) async {
    requests?.add(url);
    return body;
  },
);

UpdateRelease _releaseModel({String? assetName = kUpdateAssetArm}) =>
    UpdateRelease(
      tag: 'v0.2.0',
      version: '0.2.0',
      notes: '',
      page: Uri.parse(kReleases),
      asset: assetName == null
          ? null
          : UpdateAsset(
              name: assetName,
              url: Uri.parse('https://example.test/$assetName'),
              size: 16,
            ),
    );

/// An opener that serves [bytes] without a network.
UpdateDownloadOpener _bytes(List<int> bytes) =>
    (Uri url) async => Stream<List<int>>.value(bytes);

/// A service with a fake download, for the install paths that get that far.
UpdateService _installService({
  required UpdateDownloadOpener download,
  String bundlePath = '/Applications/Kallo.app',
  Future<void> Function(String script)? launchInstaller,
  bool macos = true,
  bool windows = false,
  String? executablePath,
  Future<void> Function(File archive, Directory into)? unpack,
  List<String>? launches,
}) => UpdateService(
  macos: macos,
  windows: windows,
  abi: windows ? Abi.windowsX64 : Abi.macosArm64,
  bundlePath: macos ? bundlePath : null,
  executablePath: executablePath,
  unpack: unpack,
  fetcher: (Uri url) async => '{}',
  openDownload: download,
  launchInstaller:
      launchInstaller ??
      (String script) async {
        launches?.add(script);
      },
);

void main() {
  group('versions', () {
    test('tags are read with and without their prefix', () {
      expect(UpdateVersion.parse('v0.2.0')!.toString(), '0.2.0');
      expect(UpdateVersion.parse('app-v0.2.0')!.toString(), '0.2.0');
      expect(UpdateVersion.parse('0.2.0')!.toString(), '0.2.0');
      expect(
        UpdateVersion.parse('app-v0.2.0-preview.10')!.toString(),
        '0.2.0-preview.10',
      );
      expect(UpdateVersion.parse('v0.2')!.toString(), '0.2.0');
      expect(UpdateVersion.parse('v1.2.3+build.4')!.toString(), '1.2.3');
      expect(UpdateVersion.parse('nightly'), isNull);
      expect(UpdateVersion.parse('v0.2.0.1'), isNull);
      expect(UpdateVersion.parse(''), isNull);
    });

    test('versions order the way semver says', () {
      int order(String a, String b) => UpdateVersion.compare(
        UpdateVersion.parse(a)!,
        UpdateVersion.parse(b)!,
      );

      expect(order('0.2.0', '0.1.9'), greaterThan(0));
      expect(order('0.1.1', '0.2.0'), lessThan(0));
      expect(order('0.2.0', '0.2.0'), 0);
      expect(order('v1.0.0', '0.9.9'), greaterThan(0));
      // A preview is older than the release it previews.
      expect(order('0.2.0-preview.1', '0.2.0'), lessThan(0));
      expect(order('0.2.0', '0.2.0-preview.1'), greaterThan(0));
      // Numeric identifiers compare as numbers, not strings.
      expect(order('0.2.0-preview.2', '0.2.0-preview.10'), lessThan(0));
      expect(order('0.2.0-preview.10', '0.2.0-preview.2'), greaterThan(0));
      // Words compare lexically; numbers rank below words.
      expect(order('0.2.0-alpha', '0.2.0-preview'), lessThan(0));
      expect(order('0.2.0-preview.1', '0.2.0-preview.beta'), lessThan(0));
      // A prefix of the identifiers is the older version.
      expect(order('0.2.0-preview', '0.2.0-preview.1'), lessThan(0));
      expect(order('0.2.0-preview.1', '0.2.0-preview'), greaterThan(0));
    });
  });

  group('checking', () {
    test('latest reads the release GitHub answers', () async {
      final List<Uri> requests = <Uri>[];
      final UpdateService service = _service(
        _json(
          _release(
            assets: <Map<String, Object?>>[
              _asset(kUpdateAssetUniversal),
              _asset(kUpdateAssetArm),
            ],
          ),
        ),
        requests: requests,
      );

      final UpdateCheck check = await service.check();

      expect(requests.single.path, '/repos/tsukiyo20/kallo/releases/latest');
      expect(requests.single.host, 'api.github.com');
      expect(check, isA<UpdateAvailable>());
      final UpdateRelease release = (check as UpdateAvailable).release;
      expect(release.version, '0.2.0');
      expect(release.label, 'v0.2.0');
      expect(release.notes, 'the notes');
      expect(release.page.toString(), '$kReleases/tag/v0.2.0');
      expect(release.publishedAt, DateTime.utc(2026, 1, 2));
      // The arm build is the exact fit even when a universal one is present.
      expect(release.asset?.name, kUpdateAssetArm);
      expect(release.asset?.size, 4096);
    });

    test('the installed version and anything older are up to date', () async {
      for (final String tag in <String>[
        'v0.1.0',
        'v0.0.9',
        'v0.1.0-preview.2',
      ]) {
        final UpdateCheck check = await _service(_json(_release(tag: tag)))
            .check();
        expect(check, isA<UpdateUpToDate>(), reason: tag);
      }
    });

    test('a draft is never offered', () async {
      final UpdateCheck check = await _service(
        _json(_release(tag: 'v0.3.0', draft: true)),
      ).check();
      expect(check, isA<UpdateUpToDate>());
    });

    test('latest with a tag it cannot order is a malformed answer', () async {
      final UpdateCheck check = await _service(_json(_release(tag: 'nightly')))
          .check();
      expect(check, isA<UpdateFailed>());
      expect((check as UpdateFailed).problem, UpdateProblem.malformed);
    });

    test(
      'a release page without an html_url falls back to the releases page',
      () async {
        final Map<String, Object?> raw = _release();
        raw.remove('html_url');
        final UpdateCheck check = await _service(_json(raw)).check();
        expect((check as UpdateAvailable).release.page.toString(), kReleases);
      },
    );

    test('malformed answers are failures, not exceptions', () async {
      for (final String body in <String>[
        'not json',
        '[]',
        '{"tag_name": 7}',
        '{"tag_name": "nightly"}',
      ]) {
        final UpdateCheck check = await _service(body).check();
        expect(check, isA<UpdateFailed>(), reason: body);
        expect((check as UpdateFailed).problem, UpdateProblem.malformed);
      }
    });

    test('an HTTP failure is a retryable failure', () async {
      final UpdateService denied = UpdateService(
        abi: Abi.macosArm64,
        macos: true,
        fetcher: (Uri url) async {
          throw const UpdateRequestException(500, 'GitHub answered 500.');
        },
      );
      final UpdateCheck check = await denied.check();
      expect(check, isA<UpdateFailed>());
      expect((check as UpdateFailed).problem, UpdateProblem.network);

      final UpdateService down = UpdateService(
        abi: Abi.macosArm64,
        macos: true,
        fetcher: (Uri url) async => throw const SocketException('down'),
      );
      expect(await down.check(), isA<UpdateFailed>());

      final UpdateService slow = UpdateService(
        abi: Abi.macosArm64,
        macos: true,
        timeout: const Duration(milliseconds: 10),
        fetcher: (Uri url) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return '{}';
        },
      );
      final UpdateCheck timedOut = await slow.check();
      expect(timedOut, isA<UpdateFailed>());
      expect((timedOut as UpdateFailed).problem, UpdateProblem.network);
    });

    test('a repository with no releases yet is up to date', () async {
      final UpdateService service = UpdateService(
        abi: Abi.macosArm64,
        macos: true,
        fetcher: (Uri url) async {
          throw const UpdateRequestException(404, 'no release');
        },
      );
      expect(await service.check(), isA<UpdateUpToDate>());
    });
  });

  group('assets', () {
    Future<UpdateRelease> releaseFor(Abi abi, List<String> names) async {
      final UpdateCheck check = await _service(
        _json(
          _release(
            assets: <Map<String, Object?>>[
              for (final String name in names) _asset(name),
            ],
          ),
        ),
        abi: abi,
      ).check();
      return (check as UpdateAvailable).release;
    }

    test('an Apple-silicon Mac takes aarch64, then universal', () async {
      expect(
        (await releaseFor(Abi.macosArm64, <String>[
          kUpdateAssetIntel,
          kUpdateAssetUniversal,
          kUpdateAssetArm,
        ])).asset?.name,
        kUpdateAssetArm,
      );
      expect(
        (await releaseFor(Abi.macosArm64, <String>[
          kUpdateAssetIntel,
          kUpdateAssetUniversal,
        ])).asset?.name,
        kUpdateAssetUniversal,
      );
    });

    test('an Intel Mac takes x86_64, then universal', () async {
      expect(
        (await releaseFor(Abi.macosX64, <String>[
          kUpdateAssetArm,
          kUpdateAssetUniversal,
          kUpdateAssetIntel,
        ])).asset?.name,
        kUpdateAssetIntel,
      );
      expect(
        (await releaseFor(Abi.macosX64, <String>[
          kUpdateAssetArm,
          kUpdateAssetUniversal,
        ])).asset?.name,
        kUpdateAssetUniversal,
      );
    });

    test('a Windows PC takes the Windows archive', () async {
      final UpdateService service = _service(
        _json(
          _release(
            assets: <Map<String, Object?>>[
              _asset(kUpdateAssetWindows),
              _asset(kUpdateAssetArm),
            ],
          ),
        ),
        abi: Abi.windowsX64,
        macos: false,
        windows: true,
      );
      final UpdateCheck check = await service.check();
      expect(
        (check as UpdateAvailable).release.asset?.name,
        kUpdateAssetWindows,
      );
    });

    test('a release with no matching file is offered without an asset', () async {
      expect(
        (await releaseFor(Abi.macosArm64, <String>[kUpdateAssetIntel])).asset,
        isNull,
      );
      // A non-Mac machine has no macOS asset to pick, even if one is attached.
      expect(
        (await releaseFor(Abi.linuxX64, <String>[
          kUpdateAssetArm,
          kUpdateAssetUniversal,
        ])).asset,
        isNull,
      );
    });
  });

  group('installer', () {
    test('the bundle is the .app an executable lives in', () {
      expect(
        bundleFromExecutable('/Applications/Kallo.app/Contents/MacOS/Kallo'),
        '/Applications/Kallo.app',
      );
      expect(
        bundleFromExecutable(
          '/private/var/folders/x/y/T/AppTranslocation/ABC/d/Kallo.app'
          '/Contents/MacOS/Kallo',
        ),
        '/private/var/folders/x/y/T/AppTranslocation/ABC/d/Kallo.app',
      );
      expect(bundleFromExecutable('/usr/local/bin/kallo'), isNull);
    });

    test('the script quotes paths and waits for the old process', () {
      final String script = installerScript(
        pid: 4242,
        bundle: "/Applications/Kallo's.app",
        replacement: '/tmp/kallo-update-1/unpacked/Kallo.app',
        temporary: '/tmp/kallo-update-1',
      );
      expect(script, contains('set -eu'));
      expect(script, contains('kill -0 4242'));
      expect(script, contains('ditto'));
      expect(script, contains('com.apple.quarantine'));
      expect(script, contains('/usr/bin/open'));
      // The apostrophe is closed and reopened, so the path stays one argument.
      expect(script, contains("'/Applications/Kallo'\\''s.app'"));

      final Directory folder = Directory.systemTemp.createTempSync('kallo-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final File file = File('${folder.path}/install.sh')
        ..writeAsStringSync(script);
      final ProcessResult parsed = Process.runSync('/bin/sh', <String>[
        '-n',
        file.path,
      ]);
      expect(parsed.exitCode, 0, reason: parsed.stderr.toString());
    });

    test('installing is refused away from macOS', () async {
      final UpdateService service = _installService(
        download: _bytes(<int>[0]),
        bundlePath: '/Applications/Kallo.app',
        macos: false,
      );
      await expectLater(
        service.install(_releaseModel(), onProgress: (double _) {}),
        throwsA(
          isA<UpdateInstallException>().having(
            (UpdateInstallException error) => error.problem,
            'problem',
            UpdateProblem.unsupported,
          ),
        ),
      );
    });

    test(
      'a translocated or read-only bundle is refused before downloading',
      () async {
        for (final String bundle in <String>[
          '/private/var/folders/x/y/T/AppTranslocation/ABC/d/Kallo.app',
          '/Volumes/Kallo/Kallo.app',
        ]) {
          bool downloaded = false;
          final UpdateService service = _installService(
            download: (Uri url) async {
              downloaded = true;
              return Stream<List<int>>.value(<int>[0]);
            },
            bundlePath: bundle,
          );
          await expectLater(
            service.install(_releaseModel(), onProgress: (double _) {}),
            throwsA(
              isA<UpdateInstallException>().having(
                (UpdateInstallException error) => error.problem,
                'problem',
                UpdateProblem.location,
              ),
            ),
          );
          expect(downloaded, isFalse, reason: bundle);
        }
      },
    );

    test('a release with no asset cannot be installed', () async {
      final UpdateService service = _installService(
        download: _bytes(<int>[0]),
        bundlePath: '/Applications/Kallo.app',
      );
      await expectLater(
        service.install(
          _releaseModel(assetName: null),
          onProgress: (double _) {},
        ),
        throwsA(
          isA<UpdateInstallException>().having(
            (UpdateInstallException error) => error.problem,
            'problem',
            UpdateProblem.noAsset,
          ),
        ),
      );
    });

    test('a short download fails on the release size', () async {
      final Directory folder = Directory.systemTemp.createTempSync('kallo-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final Directory bundle = Directory('${folder.path}/Kallo.app')
        ..createSync();
      final List<String> launches = <String>[];
      final UpdateService service = _installService(
        download: _bytes(<int>[1, 2, 3]),
        bundlePath: bundle.path,
        launches: launches,
      );
      await expectLater(
        service.install(_releaseModel(), onProgress: (double _) {}),
        throwsA(
          isA<UpdateInstallException>().having(
            (UpdateInstallException error) => error.problem,
            'problem',
            UpdateProblem.size,
          ),
        ),
      );
      expect(launches, isEmpty);
    });

    test('a download that fails is reported, not thrown at the row', () async {
      final UpdateService service = _installService(
        download: (Uri url) async => throw const SocketException('down'),
        bundlePath: '/Applications/Kallo.app',
      );
      await expectLater(
        service.install(_releaseModel(), onProgress: (double _) {}),
        throwsA(
          isA<UpdateInstallException>().having(
            (UpdateInstallException error) => error.problem,
            'problem',
            UpdateProblem.download,
          ),
        ),
      );
    });

    test('an archive that is not an app fails at extraction', () async {
      final List<int> garbage = List<int>.filled(16, 0);
      final Directory folder = Directory.systemTemp.createTempSync('kallo-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final Directory bundle = Directory('${folder.path}/Kallo.app')
        ..createSync();
      final UpdateService service = _installService(
        download: _bytes(garbage),
        bundlePath: bundle.path,
      );
      await expectLater(
        service.install(_releaseModel(), onProgress: (double _) {}),
        throwsA(
          isA<UpdateInstallException>().having(
            (UpdateInstallException error) => error.problem,
            'problem',
            UpdateProblem.extraction,
          ),
        ),
      );
    }, skip: Platform.isMacOS ? false : 'ditto is the installer');

    test(
      'the install hands a script to the launcher after unpacking',
      () async {
        final Directory folder = Directory.systemTemp.createTempSync('kallo-');
        addTearDown(() => folder.deleteSync(recursive: true));
        final Directory oldBundle = Directory(
          '${folder.path}/Applications/Kallo.app',
        )..createSync(recursive: true);
        File('${oldBundle.path}/Contents/MacOS/Kallo')
          ..createSync(recursive: true)
          ..writeAsStringSync('old');

        final Directory source = Directory('${folder.path}/build')
          ..createSync();
        final Directory newApp = Directory('${source.path}/Kallo.app')
          ..createSync();
        File('${newApp.path}/Contents/MacOS/Kallo')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('new');
        final File archive = File('${folder.path}/update.zip');
        final ProcessResult zipped = Process.runSync('/usr/bin/ditto', <String>[
          '-c',
          '-k',
          '--keepParent',
          newApp.path,
          archive.path,
        ]);
        expect(zipped.exitCode, 0, reason: zipped.stderr.toString());
        final List<int> bytes = archive.readAsBytesSync();

        final List<double> progress = <double>[];
        final List<String> launches = <String>[];
        final List<String> events = <String>[];
        final UpdateService service = _installService(
          download: _bytes(bytes),
          bundlePath: oldBundle.path,
          launchInstaller: (String script) async {
            events.add('launch');
            launches.add(script);
          },
        );
        final UpdateRelease release = UpdateRelease(
          tag: 'v0.2.0',
          version: '0.2.0',
          notes: '',
          page: Uri.parse(kReleases),
          asset: UpdateAsset(
            name: kUpdateAssetArm,
            url: Uri.parse('https://example.test/$kUpdateAssetArm'),
            size: bytes.length,
          ),
        );

        await service.install(
          release,
          onProgress: (double value) {
            progress.add(value);
            events.add('progress');
          },
          onRestarting: () => events.add('restarting'),
        );

        expect(launches, hasLength(1));
        expect(events.last, 'launch');
        expect(events[events.length - 2], 'restarting');
        expect(progress.first, 0);
        expect(progress.last, 1);

        final File script = File(launches.single);
        expect(script.existsSync(), isTrue);
        final String text = script.readAsStringSync();
        expect(text, contains(oldBundle.path));
        expect(text, contains('unpacked/Kallo.app'));
        expect(
          script.parent.listSync().whereType<Directory>().map(
            (Directory entry) => entry.path,
          ),
          contains('${script.parent.path}/unpacked'),
        );
        // The old bundle is untouched: only the script moves it, after exit.
        expect(
          File('${oldBundle.path}/Contents/MacOS/Kallo').readAsStringSync(),
          'old',
        );
      },
      skip: Platform.isMacOS ? false : 'ditto is the installer',
    );
  });

  test('the Windows script quotes paths and waits for the old process', () {
    final String script = windowsInstallerScript(
      pid: 4242,
      folder: r"C:\Program Files\Kallo's",
      replacement: r'C:\Temp\kallo-update-1\unpacked',
      temporary: r'C:\Temp\kallo-update-1',
      executable: 'kallo.exe',
    );
    expect(script, contains(r"Get-Process -Id 4242"));
    expect(script, contains(r'Remove-Item -LiteralPath'));
    expect(script, contains(r'Start-Process'));
    // An apostrophe is doubled, so the folder stays one argument.
    expect(script, contains(r"'C:\Program Files\Kallo''s'"));
    expect(script, contains("'kallo.exe'"));
  });

  test('a Windows install hands PowerShell a swap script', () async {
    final Directory folder = Directory.systemTemp.createTempSync('kallo-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final Directory install = Directory('${folder.path}/Kallo')..createSync();
    final File oldExe = File('${install.path}/kallo.exe')
      ..writeAsStringSync('old');

    final List<String> launches = <String>[];
    final UpdateService service = _installService(
      download: _bytes(List<int>.filled(16, 1)),
      macos: false,
      windows: true,
      executablePath: oldExe.path,
      unpack: (File archive, Directory into) async {
        File('${into.path}/kallo.exe').writeAsStringSync('new');
        Directory('${into.path}/data').createSync();
      },
      launchInstaller: (String script) async => launches.add(script),
    );
    final UpdateRelease release = UpdateRelease(
      tag: 'v0.2.0',
      version: '0.2.0',
      notes: '',
      page: Uri.parse(kReleases),
      asset: UpdateAsset(
        name: kUpdateAssetWindows,
        url: Uri.parse('https://example.test/$kUpdateAssetWindows'),
        size: 16,
      ),
    );

    await service.install(release, onProgress: (double _) {});
    expect(launches, hasLength(1));
    final String script = File(launches.single).readAsStringSync();
    expect(script, contains(install.path));
    expect(script, contains('unpacked'));
    expect(script, contains('kallo.exe'));
    // The running folder is untouched: only the script moves it, after exit.
    expect(oldExe.readAsStringSync(), 'old');
  });

  test('a Windows install away from a writable folder is refused', () async {
    final Directory folder = Directory.systemTemp.createTempSync('kallo-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final UpdateService service = _installService(
      download: _bytes(List<int>.filled(16, 1)),
      macos: false,
      windows: true,
      executablePath: '${folder.path}/gone/kallo.exe',
    );
    await expectLater(
      service.install(_releaseModel(), onProgress: (double _) {}),
      throwsA(
        isA<UpdateInstallException>().having(
          (UpdateInstallException error) => error.problem,
          'problem',
          UpdateProblem.location,
        ),
      ),
    );
  });

  group('controller', () {
    test('a check moves through checking to available or failed', () async {
      final _FakeService service = _FakeService();
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      expect(controller.stage, UpdateStage.idle);

      service.next = UpdateAvailable(_releaseModel());
      await controller.check();
      expect(controller.stage, UpdateStage.available);
      expect(controller.canInstall, isTrue);

      service.next = const UpdateFailed(
        problem: UpdateProblem.network,
        message: 'no',
      );
      await controller.check();
      expect(controller.stage, UpdateStage.failed);
      expect(controller.release, isNull);
    });

    test('another check while one is out does not race it', () async {
      final _FakeService service = _FakeService()..gate = Completer<void>();
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      final Future<void> first = controller.check();
      expect(controller.stage, UpdateStage.checking);
      await controller.check();
      expect(service.checks, 1);
      service.gate!.complete();
      await first;
    });

    test('an install failure keeps the release for a retry', () async {
      final _FakeService service = _FakeService()
        ..next = UpdateAvailable(_releaseModel())
        ..installError = const UpdateInstallException(
          UpdateProblem.location,
          'translocated',
        );
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      await controller.check();
      await controller.install();
      expect(controller.stage, UpdateStage.failed);
      expect(controller.problem, UpdateProblem.location);
      expect(controller.release, isNotNull);
      expect(controller.busy, isFalse);
    });
  });

  group('the About page', () {
    testWidgets('starts as a check, and asks nothing until tapped', (
      WidgetTester tester,
    ) async {
      final _FakeService service = _FakeService();
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_about(controller));
      await tester.pumpAndSettle();

      expect(find.text('Updates'), findsOneWidget);
      expect(find.text('Check for updates'), findsOneWidget);
      expect(find.text('Changelog'), findsOneWidget);
      expect(find.text('GitHub Releases'), findsOneWidget);
      expect(service.checks, 0);
    });

    testWidgets('an available release installs with progress, then restarts', (
      WidgetTester tester,
    ) async {
      final _FakeService service = _FakeService()
        ..next = UpdateAvailable(_releaseModel());
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_about(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pumpAndSettle();
      expect(find.text('Update to v0.2.0'), findsOneWidget);

      service.gate = Completer<void>();
      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Downloading 42%'), findsOneWidget);

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Restarting…'), findsOneWidget);
    });

    testWidgets('a failed check offers the same row as a retry', (
      WidgetTester tester,
    ) async {
      final _FakeService service = _FakeService()
        ..next = const UpdateFailed(
          problem: UpdateProblem.network,
          message: 'no network',
        );
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_about(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pumpAndSettle();
      expect(find.text('Check failed · Retry'), findsOneWidget);

      service.next = const UpdateUpToDate();
      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pumpAndSettle();
      expect(find.text('Up to date'), findsOneWidget);
    });

    testWidgets('a release with no installable file opens its page instead', (
      WidgetTester tester,
    ) async {
      final _FakeService service = _FakeService()
        ..next = UpdateAvailable(_releaseModel(assetName: null));
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_about(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pumpAndSettle();
      expect(find.text('Open releases page'), findsOneWidget);
    });

    testWidgets('a translocated app says where to move it', (
      WidgetTester tester,
    ) async {
      final _FakeService service = _FakeService()
        ..next = UpdateAvailable(_releaseModel())
        ..installError = const UpdateInstallException(
          UpdateProblem.location,
          'translocated',
        );
      final UpdateController controller = UpdateController(service: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_about(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('about-update')));
      await tester.pumpAndSettle();
      expect(find.text('Update failed · Retry'), findsOneWidget);
      expect(
        find.text('Move Kallo to Applications, then update.'),
        findsOneWidget,
      );
    });
  });
}

/// The About page on its own, with a controller a test can drive.
Widget _about(UpdateController controller) {
  return Localizations(
    locale: const Locale('en'),
    delegates: const <LocalizationsDelegate<Object>>[
      KalloStrings.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: KalloScope(
        colors: KalloColors.light,
        pinned: null,
        onPin: (Brightness? brightness) {},
        child: MediaQuery(
          data: const MediaQueryData(size: Size(900, 900), devicePixelRatio: 1),
          child: DefaultTextStyle(
            style: KalloType.body.copyWith(color: KalloColors.light.ink),
            child: SettingsDrawer(
              locale: const Locale('en'),
              onLocale: (Locale? locale) {},
              spectral: false,
              onSpectral: (bool on) {},
              renderMode: RenderMode.gpu,
              onRenderMode: (RenderMode mode) {},
              export: const ExportSetting(
                label: '',
                canChoose: false,
                custom: false,
              ),
              onClose: () {},
              updates: controller,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A service a widget test can drive without a network.
class _FakeService extends UpdateService {
  _FakeService() : super(abi: Abi.macosArm64, macos: true);

  /// What the next check answers.
  UpdateCheck next = const UpdateUpToDate();

  /// What the next install throws, if anything.
  Object? installError;

  /// A gate an install waits on, for the downloading state.
  Completer<void>? gate;

  /// A gate a check waits on, for the checking state.
  Completer<void>? checkGate;

  int checks = 0;
  final List<String> events = <String>[];

  @override
  bool get canInstall => true;

  @override
  Future<UpdateCheck> check() async {
    checks++;
    final Completer<void>? gate = checkGate;
    if (gate != null) {
      await gate.future;
    }
    return next;
  }

  @override
  Future<void> install(
    UpdateRelease release, {
    required ValueChanged<double> onProgress,
    VoidCallback? onRestarting,
  }) async {
    events.add('install');
    onProgress(0.42);
    final Completer<void>? gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    final Object? error = installError;
    if (error != null) {
      throw error;
    }
    onRestarting?.call();
  }
}
