import 'dart:ui' as ui;

import 'model.dart';
import 'tuning.dart';

/// The session a bench holds, and the one it is replacing.
///
/// A stage comes and goes while the model's session is still being opened: a
/// person clicks develop, then clicks print, and the first session may not have
/// answered yet. The bench is the small piece of bookkeeping that keeps that
/// from freeing a session under a frame that is still being drawn: it counts
/// the frames in flight, retires a session only when the count reaches zero,
/// and closes a session that arrives after the stage has gone.
class PreviewBench {
  PreviewBench({required this.open, this.tuning});

  /// Open the model's session, or return null when the model has none.
  final Future<PreviewSession?> Function() open;

  /// The recipe the bench prints with, read again as each frame is asked for.
  ///
  /// The recipe is a stock's, and it can change while the session is open: a
  /// person writes a departure on the stock's record and comes back to the
  /// bench. Reading it here — rather than copying it once when the session
  /// opens — is what makes the easel show the print the next development would
  /// make. Null when the caller has no recipe: the session prints the file's
  /// own numbers, which is also the identity [Tuning].
  final Tuning Function()? tuning;

  PreviewSession? _session;
  Future<PreviewSession?>? _opening;
  final List<PreviewSession> _retired = <PreviewSession>[];
  int _busy = 0;
  bool _closed = false;

  /// The recipe the session was last told, so an unchanged one is no call.
  Tuning? _applied;

  /// Start reading the photograph before the first frame is asked for.
  ///
  /// The bench is opened while the step is still drawing, so the first drag of
  /// the ruler finds a decode already in progress rather than starting one.
  void warm() {
    if (!_closed) {
      _opening ??= _start();
    }
  }

  /// Take another box off the shelf without closing the session.
  ///
  /// The session may still be opening when the person has already clicked
  /// another film; the choice is applied as soon as it arrives, and every
  /// frame asked for after this call is of the new box. The new stock's recipe
  /// follows on the next frame, because a film is a recipe's owner.
  Future<void> setMaterials({
    required String film,
    required String paper,
    required double tempC,
  }) => _apply(
    (PreviewSession session) =>
        session.setMaterials(film: film, paper: paper, tempC: tempC),
  );

  /// The print the model would make at this setting, or null when there is no
  /// session to make it in.
  Future<ui.Image?> frame({
    required double minutes,
    double? balanceFrom,
    double printEv = 0,
    String filters = '',
    String? heatGlass,
  }) async {
    if (_closed) {
      return null;
    }
    final PreviewSession? session = await (_opening ??= _start());
    if (session == null || _closed) {
      return null;
    }
    _busy++;
    try {
      // The recipe is read before the render, not when the session opened: a
      // frame asked for after a departure was written is of that departure.
      await _syncTuning(session);
      return await session.frame(
        minutes: minutes,
        balanceFrom: balanceFrom,
        printEv: printEv,
        filters: filters,
        heatGlass: heatGlass,
      );
    } finally {
      _busy--;
      _release();
    }
  }

  /// Tell the session the recipe the bench holds, when it has changed.
  Future<void> _syncTuning(PreviewSession session) async {
    final Tuning Function()? recipe = tuning;
    if (recipe == null) {
      return;
    }
    final Tuning wanted = recipe();
    if (wanted == _applied) {
      return;
    }
    await session.setTuning(tuning: wanted);
    _applied = wanted;
  }

  /// Run one change on the session, counting it as a frame in flight so the
  /// session is not freed under it.
  Future<void> _apply(
    Future<void> Function(PreviewSession session) change,
  ) async {
    if (_closed) {
      return;
    }
    final PreviewSession? session = await (_opening ??= _start());
    if (session == null || _closed) {
      return;
    }
    _busy++;
    try {
      await change(session);
    } finally {
      _busy--;
      _release();
    }
  }

  Future<PreviewSession?> _start() async {
    PreviewSession? session;
    try {
      session = await open();
    } on Object catch (error) {
      Model.log('the preview session could not be opened: $error');
      return null;
    }
    if (_closed) {
      session?.dispose();
      return null;
    }
    _session = session;
    return session;
  }

  /// Close the session, or retire it until the frame in flight is finished.
  void dispose() {
    if (_closed) {
      return;
    }
    _closed = true;
    final PreviewSession? session = _session;
    _session = null;
    if (session != null) {
      if (_busy > 0) {
        _retired.add(session);
      } else {
        session.dispose();
      }
    }
  }

  void _release() {
    if (_busy > 0 || _retired.isEmpty) {
      return;
    }
    for (final PreviewSession session in _retired) {
      session.dispose();
    }
    _retired.clear();
  }
}
