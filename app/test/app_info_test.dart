import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/app_info.dart';

void main() {
  test('the app version is the package version', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? found = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(found, isNotNull);
    expect(KalloInfo.version, found!.group(1));
  });

  // The updater and the changelog row both point at the repository by name;
  // a moved repository must move all three addresses together.
  test('the releases and API addresses belong to the repository', () {
    expect(KalloInfo.repository, 'https://github.com/tsukiyo20/kallo');
    expect(KalloInfo.releases, '${KalloInfo.repository}/releases');
    expect(KalloInfo.api, 'https://api.github.com/repos/tsukiyo20/kallo');
    expect(Uri.parse(KalloInfo.releases).host, 'github.com');
    expect(Uri.parse(KalloInfo.api).host, 'api.github.com');
  });
}
