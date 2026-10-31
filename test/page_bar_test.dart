import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/m3e_scope.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('uses a collapsed M3E top app bar with a larger title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PinnedStopsController>(
        create: (_) => PinnedStopsController(),
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (BuildContext context) {
              return M3EScope(
                scheme: Theme.of(context).colorScheme,
                child: Builder(
                  builder: (BuildContext context) {
                    return Scaffold(
                      appBar: buildPageBar(
                        context,
                        title: 'Test',
                        subtitle: 'Subtitle',
                      ),
                      body: const SizedBox.shrink(),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final Finder finder = find.byType(M3EAppBar);
    expect(finder, findsOneWidget);
    final M3EAppBar appBar = tester.widget<M3EAppBar>(finder);
    expect(appBar.variant, M3EAppBarVariant.small);
    expect(appBar.centerTitle, isFalse);
    expect(appBar.hideOnScroll, isFalse);
    expect(appBar.hideMode, M3EAppBarHideMode.none);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
    final Text title = tester.widget<Text>(find.text('Test'));
    expect(title.style?.fontSize, 24);
  });

  testWidgets('puts title trailing content on the title line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<PinnedStopsController>(
        create: (_) => PinnedStopsController(),
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (BuildContext context) {
              return M3EScope(
                scheme: Theme.of(context).colorScheme,
                child: Builder(
                  builder: (BuildContext context) {
                    return Scaffold(
                      appBar: buildPageBar(
                        context,
                        title: 'Test',
                        titleTrailing: const Text('特別班'),
                        subtitle: 'Subtitle',
                      ),
                      body: const SizedBox.shrink(),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final Offset title = tester.getCenter(find.text('Test'));
    final Offset tag = tester.getCenter(find.text('特別班'));
    final Offset subtitle = tester.getCenter(find.text('Subtitle'));
    expect((tag.dy - title.dy).abs(), lessThan(2));
    expect(tag.dy, lessThan(subtitle.dy));
    expect(tag.dx, greaterThan(title.dx));
  });
}
