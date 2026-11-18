import 'package:flutter/foundation.dart';

const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

const int appBuildNumber = int.fromEnvironment('APP_BUILD');

String get appBuildLabel => appBuildNumber > 0 ? '$appBuildNumber' : 'dev';

const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'debug',
);

String get appFlavorLabel {
  switch (appFlavor) {
    case 'full':
      return 'Full';
    case 'foss':
      return 'FOSS';
    case 'gplay':
      return 'Google Play';
    default:
      return 'Debug';
  }
}

const String _defaultPackageName = 'com.spookysrv.hktransports';

String get appPackageName {
  final String base = String.fromEnvironment(
    'APP_PACKAGE_NAME',
    defaultValue: _defaultPackageName,
  );
  return kDebugMode ? '$base.debug' : base;
}

String get appBuildType {
  if (kReleaseMode) return 'release';
  if (kDebugMode) return 'debug';
  return 'profile';
}

String get appVersionInfoText => <String>[
  'Package: $appPackageName',
  'Version name: $appVersion',
  'Version code: $appBuildLabel',
  'Flavor: $appFlavor',
  'Build: $appBuildType',
].join('\n');
