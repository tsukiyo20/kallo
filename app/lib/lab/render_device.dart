import 'dart:io';

import 'package:kallo/src/rust/api/device.dart' as device_api;

/// What the machine says it has.
///
/// The linked model answers with the adapter wgpu would open — the same probe a
/// print makes, so a settings page cannot name a card a render would not get —
/// and with the processor the operating system will name. The name is allowed
/// to be missing (Android may withhold it); the core count is not.
class RenderDevice {
  const RenderDevice({
    this.gpu,
    this.gpuError,
    this.cpu,
    this.cores = 1,
    this.architecture = '',
    this.platform = '',
  });

  /// The adapter a render would open, e.g. `Adreno (TM) 730 (Vulkan)`.
  final String? gpu;

  /// Why there is no adapter, when there is none.
  final String? gpuError;

  /// The processor's name, when the operating system lets an app read it.
  final String? cpu;

  /// Logical processors: the width the CPU renderer works across.
  final int cores;

  /// The architecture the app was built for: `aarch64`, `x86_64`, …
  final String architecture;

  /// The operating system: `macos`, `android`, …
  final String platform;

  /// Whether a render has a device to open.
  bool get hasGpu => gpu != null;

  static RenderDevice? _cached;

  /// Ask the machine once.
  ///
  /// The linked model answers first. Without it — a test, or the subprocess
  /// path — the answer is what Dart itself knows, so the page still draws and
  /// promises nothing it cannot support: a core count and the platform, and no
  /// adapter name.
  static Future<RenderDevice> probe() async {
    final RenderDevice? cached = _cached;
    if (cached != null) {
      return cached;
    }
    RenderDevice device;
    try {
      final device_api.DeviceReport report = await device_api.describeDevice();
      device = RenderDevice(
        gpu: report.gpu,
        gpuError: report.gpuError,
        cpu: report.cpu,
        cores: report.cores,
        architecture: report.architecture,
        platform: report.platform,
      );
    } on Object {
      // The library is not loaded: tests, and the subprocess path.
      device = RenderDevice(
        cores: Platform.numberOfProcessors,
        platform: Platform.operatingSystem,
      );
    }
    return _cached = device;
  }

  /// Forget the answer, for a test that wants a fresh probe.
  static void resetCache() => _cached = null;
}
