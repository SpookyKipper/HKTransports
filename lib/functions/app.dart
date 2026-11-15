import 'package:flutter/material.dart';
import 'package:hktransports/app/app_version.dart';

class AppFunctions {
  Future<String> getVersion() async => appVersion;

  Future<String> getBuildNumber() async => appBuildLabel;

  FutureBuilder<String?> getVersionBuilder({
    required Widget Function(String value) builder,
  }) {
    return FutureBuilder<String?>(
      future: getVersion(),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading...');
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return builder(snapshot.data ?? appVersion);
        }
      },
    );
  }
}

final af = AppFunctions();
