import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/app/m3e_scope.dart';
import 'package:hktransports/bus/ui/route_number_pad.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

Widget _wrap(Widget child) {
  return M3EScope(
    scheme: fallbackLightScheme(),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('impossible letters are hidden and impossible digits disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RouteNumberPad(
          possibleChars: const {'1', '2', '3', '4', 'E'},
          hasQuery: true,
          onCharacter: (_) {},
          onBackspace: () {},
          onClear: () {},
          clearTooltip: 'Clear',
          backspaceTooltip: 'Backspace',
        ),
      ),
    );

    expect(find.text('E'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('5'), findsOneWidget);

    final M3EButton one = tester.widget<M3EButton>(
      find.widgetWithText(M3EButton, '1'),
    );
    final M3EButton five = tester.widget<M3EButton>(
      find.widgetWithText(M3EButton, '5'),
    );
    expect(one.onPressed, isNotNull);
    expect(five.onPressed, isNull);
  });

  testWidgets('letters are hidden when no letter is possible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        RouteNumberPad(
          possibleChars: const {'1', '2', '3'},
          hasQuery: true,
          onCharacter: (_) {},
          onBackspace: () {},
          onClear: () {},
          clearTooltip: 'Clear',
          backspaceTooltip: 'Backspace',
        ),
      ),
    );

    expect(find.text('A'), findsNothing);
    expect(find.text('E'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });
}
