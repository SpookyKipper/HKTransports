import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

const Color _fallbackSeed = Color(0xFF6750A4);

ColorScheme fallbackLightScheme() {
  return ColorScheme.fromSeed(seedColor: _fallbackSeed);
}

ColorScheme fallbackDarkScheme() {
  return ColorScheme.fromSeed(
    seedColor: _fallbackSeed,
    brightness: Brightness.dark,
  );
}

ThemeData buildAppTheme(ColorScheme scheme) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
