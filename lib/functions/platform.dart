// Functions for platform-specific behavior and UI
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformFunctions {
  String getPlatformName(BuildContext context, {bool noWeb = false}) {
    // return "iOS";

    if (noWeb == false) {
      if (kIsWeb) {
        return "Web - ${getPlatformName(context, noWeb: true)}";
      }
    }
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return "iOS";
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      return "Android";
    } else if (Theme.of(context).platform == TargetPlatform.windows) {
      return "Windows";
    } else if (Theme.of(context).platform == TargetPlatform.macOS) {
      return "macOS";
    } else if (Theme.of(context).platform == TargetPlatform.linux) {
      return "Linux GNOME";
    } else if (Theme.of(context).platform == TargetPlatform.fuchsia) {
      return "Fuchsia";
    } else {
      return "Web";
    }
  }

  // Future<String> getThemePlatformName(BuildContext context) async {
  //   if (uf.getCurrentThemePlatform() == "system") {
  //     return getPlatformName(context);
  //   } else {
  //     return await uf.getCurrentThemePlatform();
  //   }
  // }

  bool isIOS(BuildContext context) {
    return getPlatformName(context) == "iOS";
  }

  bool isGnome(BuildContext context) {
    return getPlatformName(context) == "Linux GNOME";
  }

  bool isAndroid(BuildContext context) {
    return getPlatformName(context) == "Android";
  }

  bool isWeb() {
    return kIsWeb;
  }

  bool isDesktop(BuildContext context) {
    return (getPlatformName(context) == "Linux GNOME" ||
        getPlatformName(context) == "Windows" ||
        getPlatformName(context) == "macOS");
  }

  bool isMacOS(BuildContext context) {
    return (getPlatformName(context) == "macOS");
  }

  bool isAppleOS(BuildContext context) {
    return (getPlatformName(context, noWeb: true) == "iOS" ||
        getPlatformName(context, noWeb: true) == "macOS");
  }
}

final pf =
    PlatformFunctions(); // Functions for platform-specific behavior and UI
