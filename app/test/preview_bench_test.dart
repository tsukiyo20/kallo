import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/model.dart';
import 'package:kallo/lab/preview_bench.dart';

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

void main() {
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
}
