import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/app/app_update.dart';
import 'package:hktransports/bus/state/app_settings.dart';

AppConfig _config({
  int latest = 3,
  int critical = 1,
  Map<String, int> proprietaryApi = const <String, int>{},
}) {
  return AppConfig.fromJson(<String, dynamic>{
    'app': 'com.spookysrv.hktransports',
    'os': 'android',
    'latestVersionCode': latest,
    'lastCriticalVersionCode': critical,
    'proprietaryApi': proprietaryApi,
  });
}

void main() {
  test('parses version codes and proprietary API minima', () {
    final AppConfig config = AppConfig.fromJson(<String, dynamic>{
      'app': 'com.spookysrv.hktransports',
      'os': 'android',
      'latestVersionCode': '3',
      'lastCriticalVersionCode': 2,
      'proprietaryApi': <String, Object>{
        'ctb-eta': -1,
        'kmb-interchange': '4',
        'ignored': 'nope',
      },
    });

    expect(config.latestVersionCode, 3);
    expect(config.lastCriticalVersionCode, 2);
    expect(config.proprietaryApi['ctb-eta'], -1);
    expect(config.proprietaryApi['kmb-interchange'], 4);
    expect(config.proprietaryApi.containsKey('ignored'), isFalse);
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
  });

  test('uses the expected config keys', () {
    expect(ProprietaryEndpoint.noticeFeed.configKey, 'hkbus-notice');
    expect(ProprietaryEndpoint.kmbInterchange.configKey, 'kmb-interchange');
    expect(ProprietaryEndpoint.citybusDatabase.configKey, 'ctb-routedata');
    expect(ProprietaryEndpoint.citybusEtaStatus.configKey, 'ctb-eta');
  });

  test('points update prompts at the app repository page', () {
    expect(
      appUpdateUrl,
      'https://repo.spookysrv.com/apps/com.spookysrv.hktransports',
    );
  });
}
