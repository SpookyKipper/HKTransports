import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/app/app_update.dart';
import 'package:hktransports/bus/state/app_settings.dart';

AppConfig _config({
  int latest = 3,
  String name = '0.0.1',
  int ota = 0,
  int critical = 1,
  Map<String, int> proprietaryApi = const <String, int>{},
  Map<String, int> specialFeatures = const <String, int>{},
}) {
  return AppConfig.fromJson(<String, dynamic>{
    'app': 'com.spookysrv.hktransports',
    'os': 'android',
    'latestVersionCode': latest,
    'latestVersionName': name,
    'doOtaUpdate': ota,
    'lastCriticalVersionCode': critical,
    'proprietaryApi': proprietaryApi,
    'specialFeatures': specialFeatures,
  });
}

void main() {
  test('parses version codes and proprietary API minima', () {
    final AppConfig config = AppConfig.fromJson(<String, dynamic>{
      'app': 'com.spookysrv.hktransports',
      'os': 'android',
      'latestVersionCode': '3',
      'latestVersionName': '0.0.1',
      'doOtaUpdate': 2,
      'lastCriticalVersionCode': 2,
      'proprietaryApi': <String, Object>{
        'ctb-eta': -1,
        'kmb-interchange': '4',
        'ignored': 'nope',
      },
      'specialFeatures': <String, Object>{
        'joyYouFare': -1,
        'scanUpstreamStation': '4',
        'ignored': 'nope',
      },
      'downloadInstructions': <String, Object>{
        'kmbRouteData': <String, Object>{
          'lastUpdate': '20250509022620',
          'checkUpdateUrl': 'https://example.test/check',
          'downloadUrl': 'https://example.test/base.db',
        },
      },
    });

    expect(config.latestVersionCode, 3);
    expect(config.latestVersionName, '0.0.1');
    expect(config.doOtaUpdate, 2);
    expect(config.lastCriticalVersionCode, 2);
    expect(config.proprietaryApi['ctb-eta'], -1);
    expect(config.proprietaryApi['kmb-interchange'], 4);
    expect(config.proprietaryApi.containsKey('ignored'), isFalse);
    expect(config.specialFeatures['joyYouFare'], -1);
    expect(config.specialFeatures['scanUpstreamStation'], 4);
    expect(config.specialFeatures.containsKey('ignored'), isFalse);
    expect(config.kmbRouteData?.lastUpdate, '20250509022620');
    expect(config.kmbRouteData?.checkUpdateUrl, 'https://example.test/check');
    expect(config.kmbRouteData?.downloadUrl, 'https://example.test/base.db');
    expect(config.kmbRouteData?.isDownloadable, isTrue);
    expect(config.matchesCurrentApp, isTrue);
  });

  test('ignores configs for another app or platform', () {
    final AppConfigController config = AppConfigController(
      initialConfig: AppConfig.fromJson(<String, dynamic>{
        'app': 'com.example.other',
        'os': 'android',
        'latestVersionCode': 99,
        'lastCriticalVersionCode': 99,
      }),
      initialVersionCode: 1,
    );

    expect(config.hasUpdate, isFalse);
    expect(config.isCritical, isFalse);
    expect(
      config.availabilityFor(ProprietaryEndpoint.noticeFeed),
      ProprietaryAvailability.supported,
    );
  });

  test('defaults doOtaUpdate to the lowest version code', () {
    final AppConfig config = AppConfig.fromJson(<String, dynamic>{
      'app': 'com.spookysrv.hktransports',
      'os': 'android',
      'latestVersionCode': 3,
      'latestVersionName': '0.0.1',
      'lastCriticalVersionCode': 1,
    });

    expect(config.doOtaUpdate, 0);
  });

  test('keeps updates available but redirects below the OTA minimum', () {
    final AppConfigController config = AppConfigController(
      initialConfig: _config(ota: 2),
      initialVersionCode: 1,
    );

    expect(config.hasUpdate, isTrue);
    expect(config.canUseInAppUpdate, isFalse);
  });

  test('allows in-app OTA at or above the OTA minimum', () {
    final AppConfigController atMinimum = AppConfigController(
      initialConfig: _config(ota: 2),
      initialVersionCode: 2,
    );
    final AppConfigController aboveMinimum = AppConfigController(
      initialConfig: _config(ota: 2),
      initialVersionCode: 3,
    );
    final AppConfigController belowMinimum = AppConfigController(
      initialConfig: _config(ota: 3),
      initialVersionCode: 2,
    );

    expect(atMinimum.canUseInAppUpdate, isTrue);
    expect(aboveMinimum.canUseInAppUpdate, isTrue);
    expect(belowMinimum.canUseInAppUpdate, isFalse);
  });

  test('maps the previous boolean OTA flag during migration', () {
    final AppConfig enabled = AppConfig.fromJson(<String, dynamic>{
      'app': 'com.spookysrv.hktransports',
      'os': 'android',
      'latestVersionCode': 3,
      'latestVersionName': '0.0.1',
      'doOtaUpdate': true,
      'lastCriticalVersionCode': 1,
    });
    final AppConfig disabled = AppConfig.fromJson(<String, dynamic>{
      'app': 'com.spookysrv.hktransports',
      'os': 'android',
      'latestVersionCode': 3,
      'latestVersionName': '0.0.1',
      'doOtaUpdate': false,
      'lastCriticalVersionCode': 1,
    });

    expect(enabled.doOtaUpdate, 0);
    expect(disabled.doOtaUpdate, 4);
  });

  test('compares version codes only, never version names', () {
    final AppConfigController sameCodeNewName = AppConfigController(
      initialConfig: _config(latest: 1, name: '99.0.0'),
      initialVersionCode: 1,
    );
    final AppConfigController newerCodeOldName = AppConfigController(
      initialConfig: _config(latest: 2, name: '0.0.0'),
      initialVersionCode: 1,
    );

    expect(sameCodeNewName.hasUpdate, isFalse);
    expect(newerCodeOldName.hasUpdate, isTrue);
  });

  test('detects update and critical version codes', () {
    final AppConfigController update = AppConfigController(
      initialConfig: _config(latest: 3, critical: 1),
      initialVersionCode: 1,
    );
    final AppConfigController critical = AppConfigController(
      initialConfig: _config(latest: 3, critical: 2),
      initialVersionCode: 1,
    );
    final AppConfigController current = AppConfigController(
      initialConfig: _config(latest: 1, critical: 1),
      initialVersionCode: 1,
    );

    expect(update.hasUpdate, isTrue);
    expect(update.isCritical, isFalse);
    expect(critical.isCritical, isTrue);
    expect(current.hasUpdate, isFalse);
    expect(current.isCritical, isFalse);
  });

  test('maps proprietary API version limits', () {
    final AppConfigController config = AppConfigController(
      initialConfig: _config(
        proprietaryApi: <String, int>{
          'hkbus-notice': 1,
          'kmb-interchange': 2,
          'ctb-eta': -1,
          'nlb-routedata': -1,
        },
      ),
      initialVersionCode: 1,
    );

    expect(
      config.availabilityFor(ProprietaryEndpoint.noticeFeed),
      ProprietaryAvailability.supported,
    );
    expect(
      config.availabilityFor(ProprietaryEndpoint.kmbInterchange),
      ProprietaryAvailability.updateRequired,
    );
    expect(
      config.availabilityFor(ProprietaryEndpoint.citybusEtaStatus),
      ProprietaryAvailability.unavailable,
    );
    expect(
      config.availabilityFor(ProprietaryEndpoint.citybusDatabase),
      ProprietaryAvailability.supported,
    );
    expect(
      config.availabilityFor(ProprietaryEndpoint.nlbProprietaryData),
      ProprietaryAvailability.unavailable,
    );
  });

  test('maps the KMB route data kill switch', () {
    final AppConfigController disabled = AppConfigController(
      initialConfig: _config(
        proprietaryApi: <String, int>{'kmb-routedata': -1},
      ),
      initialVersionCode: 99,
    );
    final AppConfigController updateRequired = AppConfigController(
      initialConfig: _config(proprietaryApi: <String, int>{'kmb-routedata': 4}),
      initialVersionCode: 3,
    );

    expect(
      disabled.availabilityFor(ProprietaryEndpoint.kmbRouteDatabase),
      ProprietaryAvailability.unavailable,
    );
    expect(
      updateRequired.availabilityFor(ProprietaryEndpoint.kmbRouteDatabase),
      ProprietaryAvailability.updateRequired,
    );
  });

  test('maps special feature version limits using version codes', () {
    final AppConfigController config = AppConfigController(
      initialConfig: _config(
        specialFeatures: <String, int>{
          'joyYouFare': 2,
          'scanUpstreamStation': 3,
        },
      ),
      initialVersionCode: 2,
    );

    expect(
      config.availabilityForFeature(SpecialFeature.joyYouFare),
      ProprietaryAvailability.supported,
    );
    expect(
      config.availabilityForFeature(SpecialFeature.scanUpstreamStation),
      ProprietaryAvailability.updateRequired,
    );
  });

  test('fully disables a special feature with a negative minimum', () {
    final AppConfigController config = AppConfigController(
      initialConfig: _config(
        specialFeatures: <String, int>{
          'joyYouFare': -1,
          'scanUpstreamStation': -1,
        },
      ),
      initialVersionCode: 99,
    );

    expect(
      config.availabilityForFeature(SpecialFeature.joyYouFare),
      ProprietaryAvailability.unavailable,
    );
    expect(
      config.availabilityForFeature(SpecialFeature.scanUpstreamStation),
      ProprietaryAvailability.unavailable,
    );
  });

  test('treats missing special features as supported', () {
    final AppConfigController config = AppConfigController(
      initialConfig: _config(),
      initialVersionCode: 1,
    );

    expect(
      config.availabilityForFeature(SpecialFeature.joyYouFare),
      ProprietaryAvailability.supported,
    );
    expect(
      config.availabilityForFeature(SpecialFeature.scanUpstreamStation),
      ProprietaryAvailability.supported,
    );
  });

  test('uses the expected config keys', () {
    expect(ProprietaryEndpoint.noticeFeed.configKey, 'hkbus-notice');
    expect(ProprietaryEndpoint.kmbInterchange.configKey, 'kmb-interchange');
    expect(ProprietaryEndpoint.citybusDatabase.configKey, 'ctb-routedata');
    expect(ProprietaryEndpoint.citybusEtaStatus.configKey, 'ctb-eta');
    expect(ProprietaryEndpoint.nlbProprietaryData.configKey, 'nlb-routedata');
    expect(SpecialFeature.joyYouFare.configKey, 'joyYouFare');
    expect(SpecialFeature.scanUpstreamStation.configKey, 'scanUpstreamStation');
  });

  test('points non-OTA update prompts at the app repository page', () {
    expect(
      appRepositoryUrl,
      'https://repo.spookysrv.com/apps/com.spookysrv.hktransports',
    );
  });

  test('builds the GitHub APK download URL from the version name', () {
    expect(
      appUpdateDownloadUrl('0.0.1'),
      'https://github.com/SpookyKipper/HKTransports/releases/latest/download/'
      'HKTransports-v0.0.1.apk',
    );
  });
}
