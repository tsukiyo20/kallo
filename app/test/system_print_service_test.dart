import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/lab/system_print_service.dart';

void main() {
  test('media access reads the platform answer', () {
    final MediaAccess granted = MediaAccess.fromMap(const <Object?, Object?>{
      'granted': true,
      'canAsk': true,
      'canListAll': true,
      'limited': false,
    });
    expect(granted.granted, isTrue);
    expect(granted.canAsk, isTrue);
    expect(granted.canListAll, isTrue);
    expect(granted.limited, isFalse);

    final MediaAccess limited = MediaAccess.fromMap(const <Object?, Object?>{
      'granted': true,
      'canAsk': true,
      'canListAll': false,
      'limited': true,
    });
    expect(limited.granted, isTrue);
    expect(limited.canListAll, isFalse);
    expect(limited.limited, isTrue);

    final MediaAccess denied = MediaAccess.fromMap(const <Object?, Object?>{
      'granted': false,
      'canAsk': false,
      'canListAll': false,
      'limited': false,
    });
    expect(denied.granted, isFalse);
    expect(denied.canAsk, isFalse);
    expect(denied.canListAll, isFalse);
  });
}
