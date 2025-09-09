import 'package:hktransports/dataStore/objectbox.dart';
import 'package:hktransports/functions/platform.dart';
import 'package:flutter/material.dart';

class UiFunctions {
  int getCurrentThemeSetting() {
    return sp.getInt('themeMode') ?? 0; // Default to system
  }

  ThemeMode getCurrentThemeMode() {
    final int themeSetting = getCurrentThemeSetting();
    return ThemeMode.values[themeSetting];
  }

  int getCurrentThemePlatformId() {
    return sp.getInt('themePlatform') ?? 0; // Default to system
  }

  final themePlatforms = ["system", "material", "cupertino", "yaru"];
  String getCurrentThemePlatform() {
    return themePlatforms[getCurrentThemePlatformId()]; // 0: System, 1: Material, 2: Cupertino, 3: Yaru
  }

  bool setCurrentThemePlatform(String platform) {
    final int index = themePlatforms.indexOf(platform);
    if (index != -1) {
      return sp.setInt('themePlatform', index);
    }
    return false; // Invalid platform
  }

  void setCurrentThemePlatformSync(String platform) {
    setCurrentThemePlatform(platform);
  }

  String getCurrentThemeTemplate(BuildContext context) {
    if (getCurrentThemePlatform() == "system") {
      if (context.mounted) {
        if (pf.getPlatformName(context) == "iOS") {
          return "cupertino";
        } else if (pf.getPlatformName(context) == "Android") {
          return "material";
        } else if (pf.getPlatformName(context) == "Linux GNOME") {
          return "yaru";
        } else {
          return "material"; // Default for other platforms
        }
      } else {
        return "material"; // Fallback if context is not mounted
      }
    } else {
      return getCurrentThemePlatform();
    }
  }

  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color processColorLightDark({
    required BuildContext context,
    required List<Color> color,
  }) {
    if (isDarkMode(context)) {
      return color[1];
    } else {
      return color[0];
    }
  }

  get cLD => processColorLightDark;
}

final uf = UiFunctions();
