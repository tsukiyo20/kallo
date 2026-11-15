import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/render_device.dart';

void main() {
  test('without the linked model the probe still knows the machine', () async {
    // `flutter test` never loads the linked library, so this is the subprocess
    // path: the page must still draw, and must promise no adapter it has not
    // seen.
    RenderDevice.resetCache();
    final RenderDevice device = await RenderDevice.probe();

    expect(device.cores, greaterThan(0));
    expect(device.gpu, isNull);
    expect(device.platform, isNotEmpty);
  });

  test('a probe is asked once', () async {
    RenderDevice.resetCache();
    final RenderDevice first = await RenderDevice.probe();
    final RenderDevice second = await RenderDevice.probe();

    expect(identical(first, second), isTrue);
  });

  test('a normal machine is an operating system away from a phone', () {
    // The fallback names the platform Dart knows, whatever the machine is.
    expect(Platform.operatingSystem, isNotEmpty);
  });
}
