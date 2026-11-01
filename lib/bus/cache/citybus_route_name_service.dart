import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CitybusRouteNameService {
  const CitybusRouteNameService();

  static const Duration cacheDuration = Duration(days: 31);
  static const Duration _timeout = Duration(seconds: 20);
  static const String _fileName = 'citybus_route_names.json';

  static Map<String, _CitybusRouteNameEntry>? _entries;
  static Future<void>? _loading;
  static final Map<String, Future<String?>> _inFlight = {};
  static Future<void> _writeQueue = Future<void>.value();
  static int _generation = 0;

  Future<String?> routeName(String route, String language) async {
    final String routeNumber = route.trim().toUpperCase();
    if (_isAirportRoute(routeNumber)) return null;
    final String lang = language == 'en' ? 'en' : 'zh';
    final String key = '$routeNumber|$lang';
    final Future<String?>? existing = _inFlight[key];
    if (existing != null) return existing;

    final int generation = _generation;
    final Future<String?> future = _loadOrFetch(
      routeNumber,
      lang,
      key,
      generation,
    );
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  Future<int> storedRouteCount() async {
    await _ensureCacheLoaded();
    return _entries!.values
        .map((_CitybusRouteNameEntry entry) => entry.route)
        .toSet()
        .length;
  }

  Future<int> storedBytes() async {
    final File file = await _cacheFile();
    if (!await file.exists()) return 0;
    return file.length();
  }

  Future<void> clearCache() async {
    _generation++;
    _entries = {};
    _inFlight.clear();
    final File file = await _cacheFile();
    _writeQueue = _writeQueue.catchError((Object error) {}).then((_) async {
      if (await file.exists()) await file.delete();
    });
    await _writeQueue;
  }

  bool _isAirportRoute(String routeNumber) {
    return routeNumber.startsWith('A') || routeNumber.startsWith('NA');
  }

  Future<String?> _loadOrFetch(
    String routeNumber,
    String lang,
    String key,
    int generation,
  ) async {
    await _ensureCacheLoaded();
    if (generation != _generation) return null;

    final DateTime now = DateTime.now().toUtc();
    final _CitybusRouteNameEntry? cached = _entries![key];
    if (cached != null && now.difference(cached.fetchedAt) < cacheDuration) {
      return cached.name;
    }

    final ({bool ok, String? name}) fetch = await _fetchRouteName(
      routeNumber,
      lang,
    );
    if (generation != _generation) return null;
    if (!fetch.ok) return cached?.name;

    final String name = fetch.name ?? '';
    _entries![key] = _CitybusRouteNameEntry(
      route: routeNumber,
      language: lang,
      name: name,
      fetchedAt: now,
    );
    await _saveCache();
    return fetch.name;
  }

  Future<({bool ok, String? name})> _fetchRouteName(
    String routeNumber,
    String lang,
  ) async {
    try {
      final Uri uri = Uri.https(
        'mobile.citybus.com.hk',
        '/nwp3/routesearch.php',
        <String, String>{
          'rtype': '',
          'skey': routeNumber,
          if (lang == 'en') 'l': '1',
        },
      );
      final http.Response response = await http
          .get(
            uri,
            headers: const <String, String>{'User-Agent': 'Mozilla/5.0'},
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return (ok: false, name: null);
      }
      final String body = utf8.decode(response.bodyBytes);
      if (!body.contains('id="stopname_0"')) {
        return (ok: false, name: null);
      }
      return (
        ok: true,
        name: parseCitybusRouteName(body, english: lang == 'en'),
      );
    } catch (error) {
      debugPrint('Citybus route name fetch failed for $routeNumber: $error');
      return (ok: false, name: null);
    }
  }

  Future<void> _ensureCacheLoaded() async {
    if (_entries != null) return;
    final Future<void>? loading = _loading;
    if (loading != null) {
      await loading;
      return;
    }
    final Future<void> future = _readCache();
    _loading = future;
    try {
      await future;
    } finally {
      if (identical(_loading, future)) _loading = null;
    }
  }

  Future<void> _readCache() async {
    final Map<String, _CitybusRouteNameEntry> entries = {};
    try {
      final File file = await _cacheFile();
      if (await file.exists()) {
        final dynamic decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final dynamic rawNames = decoded['names'];
          if (rawNames is Map) {
            for (final MapEntry<dynamic, dynamic> item in rawNames.entries) {
              final dynamic value = item.value;
              if (value is! Map) continue;
              final _CitybusRouteNameEntry? entry =
                  _CitybusRouteNameEntry.fromJson(value);
              if (entry != null) entries[item.key.toString()] = entry;
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Unable to read Citybus route name cache: $error');
    }
    _entries = entries;
  }

  Future<void> _saveCache() {
    final Map<String, dynamic> names = <String, dynamic>{
      for (final MapEntry<String, _CitybusRouteNameEntry> item
          in _entries!.entries)
        item.key: item.value.toJson(),
    };
    final String data = jsonEncode(<String, dynamic>{
      'version': 1,
      'names': names,
    });
    _writeQueue = _writeQueue
        .catchError((Object error) {})
        .then((_) => _writeCache(data));
    return _writeQueue;
  }

  Future<void> _writeCache(String data) async {
    final File file = await _cacheFile();
    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(data, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<File> _cacheFile() async {
    final Directory support = await getApplicationSupportDirectory();
    return File('${support.path}/hktransports/cache/$_fileName');
  }
}

class _CitybusRouteNameEntry {
  const _CitybusRouteNameEntry({
    required this.route,
    required this.language,
    required this.name,
    required this.fetchedAt,
  });

  final String route;
  final String language;
  final String name;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'route': route,
      'language': language,
      'name': name,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  static _CitybusRouteNameEntry? fromJson(Map<dynamic, dynamic> json) {
    final String? route = json['route']?.toString();
    final String? language = json['language']?.toString();
    final String? name = json['name']?.toString();
    final DateTime? fetchedAt = DateTime.tryParse(
      json['fetchedAt']?.toString() ?? '',
    );
    if (route == null ||
        language == null ||
        name == null ||
        fetchedAt == null) {
      return null;
    }
    return _CitybusRouteNameEntry(
      route: route,
      language: language,
      name: name,
      fetchedAt: fetchedAt,
    );
  }
}

String? parseCitybusRouteName(String source, {required bool english}) {
  final Document document = html_parser.parse(source);
  final Element? stop = document.querySelector('#stopname_0');
  if (stop == null) return null;
  final List<Element> fonts = stop.querySelectorAll('font');
  if (fonts.isEmpty) return null;
  final String raw = _cleanText(fonts.last.text);
  if (raw.isEmpty) return null;
  final String name = _stripCompanyPrefix(raw, english);
  return name.isEmpty ? null : name;
}

String _stripCompanyPrefix(String value, bool english) {
  String text = value;
  const List<String> prefixes = <String>['Citybus', '城巴'];
  for (final String prefix in prefixes) {
    if (text.toLowerCase().startsWith(prefix.toLowerCase())) {
      text = text.substring(prefix.length);
      break;
    }
  }
  return text.replaceFirst(RegExp(r'^[\s,，、:：\-–—]+'), '').trim();
}

String _cleanText(String value) {
  return value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
