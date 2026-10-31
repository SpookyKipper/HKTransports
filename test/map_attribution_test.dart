import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/map_attribution.dart';

void main() {
  testWidgets('map credits expand to at most two lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapAttribution(
            attributions: [
              '<a href="https://example.com">Map data</a>',
              '<a href="https://example.com">Map labels</a>',
            ],
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.info), findsOneWidget);
    expect(find.byType(Text), findsNothing);

    await tester.tap(find.byIcon(Icons.info));
    await tester.pumpAndSettle();

    final Text credits = tester.widget<Text>(find.byType(Text));
    expect(credits.maxLines, 2);
    expect(find.byIcon(Icons.info), findsOneWidget);
  });
}
