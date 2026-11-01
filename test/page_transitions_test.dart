import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/bus/state/app_settings.dart';

void main() {
  test('default fade uses the fade forwards builder', () {
    final ThemeData theme = buildAppTheme(
      fallbackLightScheme(),
      PageTransitionStyle.fade,
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<FadeForwardsPageTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<FadeForwardsPageTransitionsBuilder>(),
    );
  });

  test('predictive back options use their builders', () {
    final ThemeData theme = buildAppTheme(
      fallbackLightScheme(),
      PageTransitionStyle.predictiveBack,
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
    final ThemeData fullscreen = buildAppTheme(
      fallbackLightScheme(),
      PageTransitionStyle.predictiveBackFullscreen,
    );
    expect(
      fullscreen.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackFullscreenPageTransitionsBuilder>(),
    );
  });

  test('cupertino uses the default Cupertino builder', () {
    final ThemeData theme = buildAppTheme(
      fallbackLightScheme(),
      PageTransitionStyle.cupertino,
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  test('all flutter transition choices are mapped', () {
    expect(
      transitionBuilderFor(PageTransitionStyle.zoom),
      isA<ZoomPageTransitionsBuilder>(),
    );
    expect(
      transitionBuilderFor(PageTransitionStyle.fadeUpwards),
      isA<FadeUpwardsPageTransitionsBuilder>(),
    );
    expect(
      transitionBuilderFor(PageTransitionStyle.openUpwards),
      isA<OpenUpwardsPageTransitionsBuilder>(),
    );
  });
}
