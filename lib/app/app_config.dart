import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const String appConfigUrl = String.fromEnvironment(
  'APPCONFIG_URL',
  defaultValue: 'https://appconfig.spookysrv.com/hktransports.json',
);

const String _appId = 'com.spookysrv.hktransports';
const String _android = 'android';

enum ProprietaryAvailability { supported, updateRequired, unavailable }

class AppConfig {
  const AppConfig({
    required this.app,
    required this.os,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.lastCriticalVersionCode,
    required this.proprietaryApi,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, int> proprietaryApi = <String, int>{};
    final Object? rawApi = json['proprietaryApi'];
    if (rawApi is Map) {
      for (final MapEntry<Object?, Object?> entry in rawApi.entries) {
        final String key = entry.key?.toString().trim() ?? '';
        final int? value = _asInt(entry.value);
        if (key.isEmpty || value == null) continue;
        proprietaryApi[key] = value;
      }
    }
    return AppConfig(
      app: json['app']?.toString().trim() ?? '',
      os: json['os']?.toString().trim().toLowerCase() ?? '',
      latestVersionCode: _asInt(json['latestVersionCode']) ?? 0,
      latestVersionName: json['latestVersionName']?.toString().trim() ?? '',
      lastCriticalVersionCode: _asInt(json['lastCriticalVersionCode']) ?? 0,
      proprietaryApi: Map<String, int>.unmodifiable(proprietaryApi),
    );
  }

  final String app;
  final String os;
  final int latestVersionCode;
  final String latestVersionName;
  final int lastCriticalVersionCode;
  final Map<String, int> proprietaryApi;

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
  Future<void>? _loadFuture;

  AppConfig? get config => _config;
  int? get currentVersionCode => _currentVersionCode;
  List<ProprietaryEndpoint> get disabledAtStartup => _disabledAtStartup;

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

  ProprietaryAvailability availabilityFor(ProprietaryEndpoint endpoint) {
    final AppConfig? value = _config;
    final int? current = _currentVersionCode;
    if (value == null || !value.matchesCurrentApp || current == null) {
      return ProprietaryAvailability.supported;
    }
    final int? minimum = value.proprietaryApi[endpoint.configKey];
    if (minimum == null) return ProprietaryAvailability.supported;
    if (minimum < 0) return ProprietaryAvailability.unavailable;
    if (minimum > current) return ProprietaryAvailability.updateRequired;
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
    return _disabledAtStartup;
  }

  Future<void> load() {
    return _loadFuture ??= _load();
  }

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
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber);
    } catch (error) {
      debugPrint('Unable to read package version code: $error');
      return null;
    }
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
