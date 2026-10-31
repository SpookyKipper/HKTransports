import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/app_settings.dart';

const Color _fallbackSeed = Color(0xFF6750A4);
const Color purpleSeed = Color(0xFF6F65DC);

ColorScheme fallbackLightScheme() {
  return ColorScheme.fromSeed(seedColor: _fallbackSeed);
}

ColorScheme fallbackDarkScheme() {
  return ColorScheme.fromSeed(
    seedColor: _fallbackSeed,
    brightness: Brightness.dark,
  );
}

ColorScheme purpleLightScheme() {
  return ColorScheme.fromSeed(seedColor: purpleSeed);
}

ColorScheme purpleDarkScheme() {
  return ColorScheme.fromSeed(
    seedColor: purpleSeed,
    brightness: Brightness.dark,
  );
}

PageTransitionsBuilder transitionBuilderFor(PageTransitionStyle style) {
  switch (style) {
    case PageTransitionStyle.fade:
      return const FadeForwardsPageTransitionsBuilder();
    case PageTransitionStyle.predictiveBack:
      return const PredictiveBackPageTransitionsBuilder();
    case PageTransitionStyle.predictiveBackFullscreen:
      return const PredictiveBackFullscreenPageTransitionsBuilder();
    case PageTransitionStyle.cupertino:
      return const CupertinoPageTransitionsBuilder();
    case PageTransitionStyle.zoom:
      return const ZoomPageTransitionsBuilder();
    case PageTransitionStyle.fadeUpwards:
      return const FadeUpwardsPageTransitionsBuilder();
    case PageTransitionStyle.openUpwards:
      return const OpenUpwardsPageTransitionsBuilder();
  }
}

ThemeData buildAppTheme(
  ColorScheme scheme,
  PageTransitionStyle transitionStyle,
) {
  final PageTransitionsBuilder builder = transitionBuilderFor(transitionStyle);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        for (final TargetPlatform platform in TargetPlatform.values)
          platform: builder,
      },
    ),
  );
}

/// Exposes both theme variants so surfaces that should keep their light-mode
/// palette can resolve it even while the app is in dark mode.
class AppColorSchemes extends InheritedWidget {
  const AppColorSchemes({
    super.key,
    required this.light,
    required this.dark,
    required super.child,
  });

  final ColorScheme light;
  final ColorScheme dark;

  static ColorScheme? lightOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppColorSchemes>()?.light;
  }

  @override
  bool updateShouldNotify(AppColorSchemes oldWidget) {
    return light != oldWidget.light || dark != oldWidget.dark;
  }
}
