/// How long the darkroom's work takes, remembered across runs.
///
/// The model reports no progress while it renders, so the button's bar is
/// time-based: it fills against the length the last develop or print took,
/// which is the only estimate this app can honestly have before the work is
/// done. A first run uses the fallback; every run after it is right for this
/// machine and this size of print, because a print is measured, not guessed.
abstract final class WorkClock {
  static final Map<String, Duration> _last = <String, Duration>{};

  /// What the last work under [key] took, or [fallback] before there is one.
  static Duration estimate(String key, Duration fallback) =>
      _last[key] ?? fallback;

  /// Remember one run, smoothed against the run before it so a single slow
  /// print does not make the next bar wrong for the whole session.
  static void record(String key, Duration took) {
    final Duration? previous = _last[key];
    _last[key] = previous == null
        ? took
        : Duration(
            microseconds:
                (previous.inMicroseconds * 2 + took.inMicroseconds) ~/ 3,
          );
  }

  /// Forget every measurement. A test does not inherit the previous test's
  /// machine, and a golden drawn at the bench does not want one.
  static void clear() => _last.clear();
}
