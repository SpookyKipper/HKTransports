import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/page_bar.dart';

void main() {
  testWidgets('uses a cupertino header on iOS', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: buildPageBar(context, title: 'Test'),
              body: const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('uses a material header on Android', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: buildPageBar(context, title: 'Test'),
              body: const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsNothing);
  });
}
