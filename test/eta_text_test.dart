import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/eta_text.dart';

void main() {
  testWidgets('shows a text-height wheelchair icon when requested', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EtaText(
          base: '5 min',
          appended: null,
          style: TextStyle(fontSize: 20),
          color: Colors.black,
          appendedKey: '',
          wheelchair: true,
        ),
      ),
    );

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.accessible));
    expect(icon.size, 20);
  });

  testWidgets('hides the wheelchair icon by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EtaText(
          base: '5 min',
          appended: null,
          style: TextStyle(fontSize: 20),
          color: Colors.black,
          appendedKey: '',
        ),
      ),
    );

    expect(find.byIcon(Icons.accessible), findsNothing);
  });
}
