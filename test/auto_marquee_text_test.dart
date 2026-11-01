import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/auto_marquee_text.dart';

void main() {
  testWidgets('scrolls only when the text overflows', (
    WidgetTester tester,
  ) async {
    const String text = 'A subtitle that is much wider than the box';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: AutoMarqueeText(
                text: text,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AutoMarqueeText),
        matching: find.byType(Transform),
      ),
      findsOneWidget,
    );
    final Transform before = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AutoMarqueeText),
        matching: find.byType(Transform),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    final Transform after = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AutoMarqueeText),
        matching: find.byType(Transform),
      ),
    );
    expect(
      after.transform.getTranslation().x,
      lessThan(before.transform.getTranslation().x),
    );
  });

  testWidgets('does not marquee when the text fits', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: AutoMarqueeText(
                text: 'Short',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AutoMarqueeText),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
