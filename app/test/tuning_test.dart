import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/tuning.dart';

void main() {
  test('the identity is eight ones in the model\'s order', () {
    expect(Tuning.identity.isIdentity, isTrue);
    expect(Tuning.identity.toList(), <double>[1, 1, 1, 1, 1, 1, 1, 1]);
    expect(Tuning.keys, hasLength(8));
    for (final String key in Tuning.keys) {
      expect(Tuning.identity.valueOf(key), 1.0, reason: key);
    }
  });

  test('toList follows the keys the bridge takes', () {
    final Tuning tuning = Tuning.identity
        .withValue('grain.strength', 0.5)
        .withValue('blur.sharpness', 1.5);
    expect(tuning.grainStrength, 0.5);
    expect(tuning.blurSharpness, 1.5);
    expect(tuning.toList(), <double>[0.5, 1, 1, 1.5, 1, 1, 1, 1]);
    expect(tuning.isIdentity, isFalse);
    expect(tuning.overrides, <String, double>{
      'grain.strength': 0.5,
      'blur.sharpness': 1.5,
    });
  });

  test('the eight values round-trip through fromList', () {
    final Tuning tuning = Tuning.identity
        .withValue('grain.strength', 0.25)
        .withValue('grain.size', 1.75)
        .withValue('mask.strength', 0.5)
        .withValue('blur.sharpness', 2.0)
        .withValue('dyes.saturation', 0.0)
        .withValue('halation.strength', 1.25)
        .withValue('couplers.strength', 0.75)
        .withValue('interimage.strength', 1.5);
    expect(Tuning.fromList(tuning.toList()), tuning);
    expect(Tuning.fromList(<double>[1, 1, 1, 1, 1, 1, 1, 1]), Tuning.identity);
    expect(
      () => Tuning.fromList(<double>[1, 1]),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('copyWith moves one control and leaves the rest', () {
    final Tuning tuning = Tuning.identity.copyWith(grainSize: 0.5);
    expect(tuning.grainSize, 0.5);
    expect(tuning.grainStrength, 1.0);
    expect(tuning.isIdentity, isFalse);
  });

  test('a control the model does not have is refused', () {
    expect(Tuning.identity.valueOf('made.up'), isNull);
    expect(
      () => Tuning.identity.withValue('made.up', 2),
      throwsA(isA<ArgumentError>()),
    );
  });
}
