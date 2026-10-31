import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/app/app_transition_page.dart';
import 'package:hktransports/bus/state/app_settings.dart';

void main() {
  testWidgets('selected transition runs on pushed routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(fallbackLightScheme(), PageTransitionStyle.zoom),
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    final AppTransitionPage<Object?> page =
                        AppTransitionPage<Object?>(
                          style: PageTransitionStyle.zoom,
                          child: const Scaffold(body: Text('Target')),
                        );
                    Navigator.of(context).push(page.createRoute(context));
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final ModalRoute<dynamic> route = ModalRoute.of(
      tester.element(find.text('Target', skipOffstage: false)),
    )!;
    expect(route.animation!.value, greaterThan(0));
    expect(route.animation!.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
  });
}
