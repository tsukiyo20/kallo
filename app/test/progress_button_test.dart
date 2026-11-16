import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kallo/design/scope.dart';
import 'package:kallo/design/tokens.dart';
import 'package:kallo/widgets/button.dart';

/// The action's button is the progress bar while the model works.
void main() {
  testWidgets('a working button is a bar, not a disabled grey button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KalloScope(
          colors: KalloColors.dark,
          pinned: null,
          onPin: (Brightness? brightness) {},
          child: const Center(
            child: KalloButton(
              label: '印相',
              onTap: null,
              filled: true,
              progress: 0.4,
            ),
          ),
        ),
      ),
    );

    // The label is drawn twice — once for the grey track, once for the orange
    // fill — so the part of the word the bar has reached stays readable.
    expect(find.text('印相'), findsNWidgets(2));
    expect(tester.widget<KalloButton>(find.byType(KalloButton)).progress, 0.4);
  });

  testWidgets('an idle button is not a bar', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KalloScope(
          colors: KalloColors.dark,
          pinned: null,
          onPin: (Brightness? brightness) {},
          child: const Center(
            child: KalloButton(label: 'Print', onTap: null, filled: true),
          ),
        ),
      ),
    );
    expect(find.text('Print'), findsOneWidget);
  });
}
