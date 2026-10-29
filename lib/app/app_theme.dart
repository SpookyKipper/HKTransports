import 'package:hktransports/app/rounded_cupertino_page_transitions_builder.dart';
import 'package:flutter/material.dart';

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

ThemeData buildAppTheme(ColorScheme scheme) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: RoundedCupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: RoundedCupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: RoundedCupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: RoundedCupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: RoundedCupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: RoundedCupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
