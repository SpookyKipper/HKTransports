const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

const int appBuildNumber = int.fromEnvironment('APP_BUILD');

String get appBuildLabel => appBuildNumber > 0 ? '$appBuildNumber' : 'dev';
