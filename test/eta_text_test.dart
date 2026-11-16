import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/eta_text.dart';

void main() {
  testWidgets('shows solar, occupancy and double-wheelchair indicators', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EtaText(
            base: '22:48  3 min',
            appended: '1.0 km away',
            style: const TextStyle(fontSize: 14),
            color: Colors.black,
            appendedKey: 'test',
            solarPowered: true,
            solarLabel: 'Solar bus',
            occupancyPercent: 50,
            occupancyLabel: '50% full',
            doubleWheelchair: true,
            doubleWheelchairLabel: 'Double wheelchair bus',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.solar_power), findsOneWidget);
    expect(find.byIcon(Icons.people_alt), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byIcon(Icons.accessible), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
