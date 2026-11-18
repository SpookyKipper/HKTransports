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
