import 'package:hktransports/dataStore/shared_preferences.dart';
import 'package:hktransports/functions/platform.dart';
import 'package:flutter/material.dart';

class UiFunctions {
  Future<int> getCurrentThemeSetting() async {
    return await sp.getInt('themeMode') ?? 0;
  }

  Future<ThemeMode> getCurrentThemeMode() async {
    final int themeSetting = await getCurrentThemeSetting();
    return ThemeMode.values[themeSetting];
  }

  Future<int> getCurrentThemePlatformId() async {
    return await sp.getInt('themePlatform') ?? 0;
  }

  final themePlatforms = ["system", "material", "cupertino", "yaru"];
  Future<String> getCurrentThemePlatform() async {
    return themePlatforms[await getCurrentThemePlatformId()]; // 0: System, 1: Material, 2: Cupertino, 3: Yaru
  }

  Future<bool> setCurrentThemePlatform(String platform) async {
    final int index = themePlatforms.indexOf(platform);
    if (index != -1) {
      return await sp.setInt('themePlatform', index);
    }
    return false; // Invalid platform
  }

  void setCurrentThemePlatformSync(String platform) {
    setCurrentThemePlatform(platform);
  }

  Future<String> getCurrentThemeTemplate(BuildContext context) async {
    if (await getCurrentThemePlatform() == "system") {
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
      return await getCurrentThemePlatform();
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
