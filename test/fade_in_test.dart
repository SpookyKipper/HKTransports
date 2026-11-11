import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/fade_in.dart';

void main() {
  testWidgets('fades its child in', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FadeIn(duration: Duration(milliseconds: 200), child: Text('ETA')),
      ),
    );

    final Finder opacity = find.descendant(
      of: find.byType(FadeIn),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
  });
}
