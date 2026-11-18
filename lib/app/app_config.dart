import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:hktransports/app/app_version.dart';

const String appConfigUrl = String.fromEnvironment(
  'APPCONFIG_URL',
  defaultValue: 'https://appconfig.spookysrv.com/hktransports.json',
);

const String _appId = 'com.spookysrv.hktransports';
const String _android = 'android';

enum ProprietaryAvailability { supported, updateRequired, unavailable }

class KmbRouteDataConfig {
  const KmbRouteDataConfig({
    required this.lastUpdate,
    required this.downloadUrl,
    this.checkUpdateUrl = '',
  });

  factory KmbRouteDataConfig.fromJson(Map<String, dynamic> json) {
    return KmbRouteDataConfig(
      lastUpdate: json['lastUpdate']?.toString().trim() ?? '',
      checkUpdateUrl: json['checkUpdateUrl']?.toString().trim() ?? '',
      downloadUrl: json['downloadUrl']?.toString().trim() ?? '',
    );
  }

  final String lastUpdate;
  final String checkUpdateUrl;
  final String downloadUrl;

  bool get isDownloadable => downloadUrl.isNotEmpty;
}

enum SpecialFeature { joyYouFare, scanUpstreamStation }

extension SpecialFeatureInfo on SpecialFeature {
  String get configKey {
    switch (this) {
      case SpecialFeature.joyYouFare:
        return 'joyYouFare';
      case SpecialFeature.scanUpstreamStation:
        return 'scanUpstreamStation';
    }
  }

  String label(AppSettings settings) {
    switch (this) {
      case SpecialFeature.joyYouFare:
        return settings.text('樂悠車費', 'JoyYou fares');
      case SpecialFeature.scanUpstreamStation:
        return settings.text('掃描上游車站', 'Scan upstream stops');
    }
  }
}

class AppConfig {
  const AppConfig({
    required this.app,
    required this.os,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.doOtaUpdate,
    required this.lastCriticalVersionCode,
    required this.proprietaryApi,
    required this.specialFeatures,
    this.kmbRouteData,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final int latestVersionCode = _asInt(json['latestVersionCode']) ?? 0;
    final Object? rawInstructions = json['downloadInstructions'];
    final Object? rawKmb = rawInstructions is Map
        ? rawInstructions['kmbRouteData']
        : null;
    return AppConfig(
      app: json['app']?.toString().trim() ?? '',
      os: json['os']?.toString().trim().toLowerCase() ?? '',
      latestVersionCode: latestVersionCode,
      latestVersionName: json['latestVersionName']?.toString().trim() ?? '',
      doOtaUpdate: _otaMinimumVersionCode(
        json['doOtaUpdate'],
        latestVersionCode: latestVersionCode,
      ),
      lastCriticalVersionCode: _asInt(json['lastCriticalVersionCode']) ?? 0,
      proprietaryApi: _asIntMap(json['proprietaryApi']),
      specialFeatures: _asIntMap(json['specialFeatures']),
      kmbRouteData: rawKmb is Map<String, dynamic>
          ? KmbRouteDataConfig.fromJson(rawKmb)
          : null,
    );
  }

  final String app;
  final String os;
  final int latestVersionCode;
  final String latestVersionName;
  final int doOtaUpdate;
  final int lastCriticalVersionCode;
  final Map<String, int> proprietaryApi;
  final Map<String, int> specialFeatures;
  final KmbRouteDataConfig? kmbRouteData;

  bool get matchesCurrentApp => app == _appId && os == _android;
}

class AppConfigController {
  AppConfigController({
    http.Client? client,
    this.configUrl = appConfigUrl,
    Future<int?> Function()? versionCodeLoader,
    AppConfig? initialConfig,
    int? initialVersionCode,
  }) : _client = client,
       _versionCodeLoader = versionCodeLoader ?? _platformVersionCode,
       _config = initialConfig,
       _currentVersionCode = initialVersionCode;

  final String configUrl;
  final http.Client? _client;
  final Future<int?> Function() _versionCodeLoader;
  AppConfig? _config;
  int? _currentVersionCode;
  List<ProprietaryEndpoint> _disabledAtStartup = const <ProprietaryEndpoint>[];
  List<SpecialFeature> _disabledSpecialFeaturesAtStartup =
      const <SpecialFeature>[];
  Future<void>? _loadFuture;

  AppConfig? get config => _config;
  int? get currentVersionCode => _currentVersionCode;
  KmbRouteDataConfig? get kmbRouteData =>
      _matchesCurrentApp ? _config?.kmbRouteData : null;
  List<ProprietaryEndpoint> get disabledAtStartup => _disabledAtStartup;
  List<SpecialFeature> get disabledSpecialFeaturesAtStartup =>
      _disabledSpecialFeaturesAtStartup;

  bool get _matchesCurrentApp => _config?.matchesCurrentApp ?? false;

  bool get hasUpdate {
    final AppConfig? value = _config;
    final int? current = _currentVersionCode;
    return _matchesCurrentApp &&
        value != null &&
        current != null &&
        value.latestVersionCode > current;
  }

  bool get isCritical {
    final AppConfig? value = _config;
    final int? current = _currentVersionCode;
    return _matchesCurrentApp &&
        value != null &&
        current != null &&
        value.lastCriticalVersionCode > current;
  }

  bool get canUseInAppUpdate {
    final AppConfig? value = _config;
    final int? current = _currentVersionCode;
    return _matchesCurrentApp &&
        value != null &&
        current != null &&
        current >= value.doOtaUpdate;
  }

  ProprietaryAvailability availabilityFor(ProprietaryEndpoint endpoint) {
    final AppConfig? value = _config;
    final int? current = _currentVersionCode;
    if (value == null || !value.matchesCurrentApp || current == null) {
      return ProprietaryAvailability.supported;
    }
    return _availabilityForVersion(value.proprietaryApi, endpoint.configKey);
  }

  ProprietaryAvailability availabilityForFeature(SpecialFeature feature) {
    final AppConfig? value = _config;
    final int? current = _currentVersionCode;
    if (value == null || !value.matchesCurrentApp || current == null) {
      return ProprietaryAvailability.supported;
    }
    return _availabilityForVersion(value.specialFeatures, feature.configKey);
  }

  ProprietaryAvailability _availabilityForVersion(
    Map<String, int> minimums,
    String key,
  ) {
    final int? minimum = minimums[key];
    if (minimum == null) return ProprietaryAvailability.supported;
    if (minimum < 0) return ProprietaryAvailability.unavailable;
    if (minimum > _currentVersionCode!) {
      return ProprietaryAvailability.updateRequired;
    }
    return ProprietaryAvailability.supported;
  }

  List<ProprietaryEndpoint> applyToSettings(AppSettings settings) {
    final List<ProprietaryEndpoint> disabled = <ProprietaryEndpoint>[];
    for (final ProprietaryEndpoint endpoint in ProprietaryEndpoint.values) {
      if (!settings.isProprietaryEnabled(endpoint)) continue;
      if (availabilityFor(endpoint) == ProprietaryAvailability.supported) {
        continue;
      }
      settings.setProprietaryEndpoint(endpoint, false);
      disabled.add(endpoint);
    }
    _disabledAtStartup = List<ProprietaryEndpoint>.unmodifiable(disabled);

    final List<SpecialFeature> disabledFeatures = <SpecialFeature>[];
    for (final SpecialFeature feature in SpecialFeature.values) {
      final bool enabled = switch (feature) {
        SpecialFeature.joyYouFare => settings.showJoyYouFare,
        SpecialFeature.scanUpstreamStation => settings.upstreamEtaScan,
      };
      if (!enabled) continue;
      if (availabilityForFeature(feature) ==
          ProprietaryAvailability.supported) {
        continue;
      }
      switch (feature) {
        case SpecialFeature.joyYouFare:
          settings.setShowJoyYouFare(false);
        case SpecialFeature.scanUpstreamStation:
          settings.setUpstreamEtaScan(false);
      }
      disabledFeatures.add(feature);
    }
    _disabledSpecialFeaturesAtStartup = List<SpecialFeature>.unmodifiable(
      disabledFeatures,
    );
    return _disabledAtStartup;
  }

  Future<void> load() {
    return _loadFuture ??= _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    try {
      _currentVersionCode = await _versionCodeLoader();
    } catch (error) {
      debugPrint('Unable to read app version code: $error');
    }

    final http.Client client = _client ?? http.Client();
    try {
      final http.Response response = await client
          .get(
            Uri.parse(configUrl),
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        throw FormatException(
          'App config failed with status ${response.statusCode}',
        );
      }
      final String body = utf8
          .decode(response.bodyBytes, allowMalformed: true)
          .replaceFirst('\uFEFF', '');
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('App config is not a JSON object');
      }
      _config = AppConfig.fromJson(decoded);
    } catch (error) {
      debugPrint('Unable to load app config: $error');
    } finally {
      if (_client == null) client.close();
    }
  }

  static Future<int?> _platformVersionCode() async {
    return appBuildNumber > 0 ? appBuildNumber : null;
  }
}

int _otaMinimumVersionCode(Object? raw, {required int latestVersionCode}) {
  final int? value = _asInt(raw);
  if (value != null) return value;
  // Accept the previous boolean config while the server migrates.
  if (raw is bool) {
    return raw ? 0 : latestVersionCode + 1;
  }
  return 0;
}

Map<String, int> _asIntMap(Object? raw) {
  final Map<String, int> result = <String, int>{};
  if (raw is! Map) return Map<String, int>.unmodifiable(result);
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    final String key = entry.key?.toString().trim() ?? '';
    final int? value = _asInt(entry.value);
    if (key.isEmpty || value == null) continue;
    result[key] = value;
  }
  return Map<String, int>.unmodifiable(result);
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
