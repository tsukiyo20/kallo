/// Which engine may render a print.
///
/// A property of the machine, not of a photograph: the strip can be developed
/// through the spectral path or not, but both engines carry the same model. The
/// choice outlives every strip, so it is one value the model reads rather than an
/// argument threaded through previews, rolls and prints.
enum RenderMode {
  /// The device, through wgpu. Faster, and the default.
  gpu,

  /// The processor. Slower, and the same picture on every machine.
  cpu;

  /// Whether a render may open the device.
  bool get isGpu => this == RenderMode.gpu;

  /// The word the settings file keeps.
  String get storage => name;

  /// Read a stored value back.
  ///
  /// Absent is the default, because a settings file written before this choice
  /// existed belongs to an app whose renders all went to the GPU.
  static RenderMode fromStorage(Object? value) =>
      value == 'cpu' ? RenderMode.cpu : RenderMode.gpu;
}

/// The engine the model is allowed to use.
///
/// The settings file owns the value, and `main` sets it when the file is read or
/// a person moves the switch. The model reads it at the call: a preview, a roll
/// and a print are the same choice, and threading it through all three would be
/// three places to forget it.
///
/// It is mutable on purpose. Unlike the preview bench's state, this is a device
/// preference: the app has one, and every render in the process shares it.
abstract final class RenderPreference {
  static RenderMode _mode = RenderMode.gpu;

  /// The mode last read from settings, or the default.
  static RenderMode get mode => _mode;

  /// Whether a render may open the device.
  static bool get gpu => _mode.isGpu;

  /// Set when settings are read, and when the switch is moved.
  static void set(RenderMode mode) => _mode = mode;
}
