import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/widgets/window_controls.dart';

void main() {
  test('the mac setting names the gesture the band performs', () {
    expect(titleBarGesture('Minimize'), TitleBarGesture.minimize);
    expect(titleBarGesture('None'), TitleBarGesture.none);
    expect(titleBarGesture('Maximize'), TitleBarGesture.zoom);
    // Fill is the newer word for the same idea. AppKit has no public Fill
    // action, so the band zooms the window the way the green button does.
    expect(titleBarGesture('Fill'), TitleBarGesture.zoom);
    // A setting that was never written is the system's default, which makes
    // the window bigger.
    expect(titleBarGesture(null), TitleBarGesture.zoom);
    expect(titleBarGesture('a word from a later system'), TitleBarGesture.zoom);
  });
}
