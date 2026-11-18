import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/model.dart';
import 'package:kallo/lab/preview_bench.dart';
import 'package:kallo/lab/tuning.dart';

/// A session with no pixels: the bench's bookkeeping is what is under test.
class _Session implements PreviewSession {
  bool disposed = false;

  @override
  void dispose() => disposed = true;

  @override
  Future<ui.Image> frame({
    required double minutes,
    double? balanceFrom,
    double printEv = 0,
    String filters = '',
    String? heatGlass,
  }) async => throw UnimplementedError('the test never asks for pixels');

  @override
  Future<void> setMaterials({
    required String film,
    required String paper,
    required double tempC,
  }) async {}

  @override
  Future<void> setTuning({required Tuning tuning}) async {}
}

/// A session that remembers which box it was pointed at.
class _MaterialsSession extends _Session {
  final List<String> calls = <String>[];

  @override
  Future<void> setMaterials({
    required String film,
    required String paper,
    required double tempC,
  }) async {
    calls.add('$film|$paper|$tempC');
  }
}

/// A one-pixel picture, so a frame can be asked for without a render.
Future<ui.Image> _pixel() {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF808080),
  );
  return recorder.endRecording().toImage(1, 1);
}

/// A session that records the recipe it was told and answers a pixel.
class _TuningSession extends _Session {
  final List<Tuning> tunings = <Tuning>[];

  @override
  Future<ui.Image> frame({
    required double minutes,
    double? balanceFrom,
    double printEv = 0,
    String filters = '',
    String? heatGlass,
  }) async => _pixel();

  @override
  Future<void> setTuning({required Tuning tuning}) async => tunings.add(tuning);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session that arrives after the bench closes is let go', () async {
    final Completer<PreviewSession?> opening = Completer<PreviewSession?>();
    final PreviewBench bench = PreviewBench(open: () => opening.future);
    bench.warm();
    bench.dispose();

    final _Session session = _Session();
    opening.complete(session);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(session.disposed, isTrue);
  });

  test('a closed bench asks for nothing', () async {
    final PreviewBench bench = PreviewBench(
      open: () async => throw StateError('the bench is closed'),
    );
    bench.dispose();
    expect(
      await bench.frame(minutes: 6),
      isNull,
      reason: 'a closed bench has no session and no work',
    );
  });

  test('another box is a call on the session, not a new one', () async {
    final _MaterialsSession session = _MaterialsSession();
    int opened = 0;
    final PreviewBench bench = PreviewBench(
      open: () async {
        opened++;
        return session;
      },
    );
    bench.warm();
    await bench.setMaterials(
      film: 'kodak_portra_400',
      paper: 'portra_endura',
      tempC: 20,
    );
    expect(session.calls, <String>['kodak_portra_400|portra_endura|20.0']);
    expect(opened, 1, reason: 'the photograph was not read again');
    bench.dispose();
    expect(session.disposed, isTrue);
  });

  test('a closed bench changes no box', () async {
    final _MaterialsSession session = _MaterialsSession();
    final PreviewBench bench = PreviewBench(open: () async => session);
    bench.dispose();
    await bench.setMaterials(
      film: 'kodak_portra_400',
      paper: 'portra_endura',
      tempC: 20,
    );
    expect(session.calls, isEmpty);
  });

  test('a frame is printed with the recipe the bench holds', () async {
    final _TuningSession session = _TuningSession();
    final Tuning recipe = Tuning.identity.copyWith(grainStrength: 0.5);
    int opened = 0;
    final PreviewBench bench = PreviewBench(
      open: () async {
        opened++;
        return session;
      },
      tuning: () => recipe,
    );
    final ui.Image frame = (await bench.frame(minutes: 6))!;
    frame.dispose();

    expect(opened, 1, reason: 'the photograph was not read again');
    expect(session.tunings, <Tuning>[recipe]);
    bench.dispose();
    expect(session.disposed, isTrue);
  });

  test('another recipe is a call on the session, not a new one', () async {
    final _TuningSession session = _TuningSession();
    Tuning recipe = Tuning.identity;
    int opened = 0;
    final PreviewBench bench = PreviewBench(
      open: () async {
        opened++;
        return session;
      },
      tuning: () => recipe,
    );
    (await bench.frame(minutes: 6))!.dispose();
    recipe = recipe.copyWith(maskStrength: 0.5);
    (await bench.frame(minutes: 6))!.dispose();
    final int calls = session.tunings.length;
    (await bench.frame(minutes: 6))!.dispose();

    expect(opened, 1, reason: 'the negative and the meter stayed');
    expect(session.tunings, hasLength(calls), reason: 'the recipe did not move');
    expect(session.tunings.last, recipe);
    bench.dispose();
  });

  test('a bench with no recipe does not touch one', () async {
    final _TuningSession session = _TuningSession();
    final PreviewBench bench = PreviewBench(open: () async => session);
    (await bench.frame(minutes: 6))!.dispose();
    expect(session.tunings, isEmpty);
    bench.dispose();
  });

  test('a closed bench changes no recipe', () async {
    final _TuningSession session = _TuningSession();
    Tuning recipe = Tuning.identity.copyWith(maskStrength: 0.5);
    final PreviewBench bench = PreviewBench(
      open: () async => session,
      tuning: () => recipe,
    );
    bench.dispose();
    recipe = recipe.copyWith(grainStrength: 0.5);
    expect(await bench.frame(minutes: 6), isNull);
    expect(session.tunings, isEmpty);
  });
}
