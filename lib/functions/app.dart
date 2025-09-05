import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppFunctions {
  Future<String> getVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
      // print('Version: $version, Build: $buildNumber');
    } catch (e) {
      // print('Failed to get package info: $e');
      return 'Get version failed';
    }
  }
  Future<String> getBuildNumber() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      return 'Get build number failed';
    }
  }

  FutureBuilder<String?> getVersionBuilder({
    required Widget Function(String value) builder,
  }) {
    return FutureBuilder<String?>(
      future: getVersion(),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Loading...");
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return builder(snapshot.data ?? "Get version failed");
        }
      },
    );
  }
}

final af = AppFunctions(); 