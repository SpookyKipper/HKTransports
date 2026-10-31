import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/functions/title_case.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum BbiLeg { first, second }

class BbiEntry {
  const BbiEntry({
    required this.route,
    required this.destination,
    required this.stop,
    required this.discount,
    required this.timeLimit,
    required this.consecutive,
    required this.remark,
    required this.detail,
    required this.validity,
  });

  final String route;
  final String destination;
  final String stop;
  final String discount;
  final String timeLimit;
  final String consecutive;
  final String remark;
  final String detail;
  final String validity;
}

class BbiService {
  const BbiService();

  static const String kmbHost = 'www.kmb.hk';
  static const String citybusHost = 'www.citybus.com.hk';
  static const Duration _timeout = Duration(minutes: 3);
  static final Map<String, List<BbiEntry>> _kmbCache = {};
  static const List<String> _allKmbFiles = [
    'BBI_routeF1.js',
    'BBI_routeF2.js',
    'BBI_routeB1.js',
    'BBI_routeB2.js',
    'en.BBI_routeF1.js',
    'en.BBI_routeF2.js',
    'en.BBI_routeB1.js',
    'en.BBI_routeB2.js',
  ];

  Future<List<BbiEntry>> loadKmb(
    RouteEntry route, {
    required bool zh,
    required BbiLeg leg,
  }) async {
    final String direction = _directionFor(route, BusCompany.kmb);
    final String prefix = zh ? '' : 'en.';
    final String fileName =
        '${prefix}BBI_route$direction${leg == BbiLeg.first ? 1 : 2}.js';
    final File file = await _ensureKmbFile(fileName);
    final String cacheKey = '${file.path}|${route.route}|${zh ? 'zh' : 'en'}';
    final List<BbiEntry>? cached = _kmbCache[cacheKey];
    if (cached != null) return cached;
    final List<List<String>> rows = await compute(_readKmbRecords, <String>[
      file.path,
      route.route,
      zh ? 'chi' : 'eng',
    ]);
    final List<BbiEntry> entries = [
      for (final List<String> row in rows)
        BbiEntry(
          route: row[0],
          destination: zh ? row[1] : toProperCase(row[1]),
          stop: zh ? row[2] : toProperCase(row[2]),
          discount: row[3],
          validity: row[4],
          timeLimit: _kmbTimeLimit(row[4], zh),
          consecutive: row[5],
          remark: row[6],
          detail: row[7],
        ),
    ];
    _kmbCache[cacheKey] = entries;
    return entries;
  }

  Future<List<BbiEntry>> loadCitybus(
    RouteEntry route, {
    required bool zh,
    required BbiLeg leg,
  }) async {
    final Uri uri = Uri.parse(
      'https://$citybusHost/concessionApi/public/bbi/api/v1/route/'
      '${zh ? 'tc' : 'en'}/${Uri.encodeComponent(route.route)}',
    );
    final http.Response response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw HttpException('Citybus BBI request failed: ${response.statusCode}');
    }
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('Unexpected Citybus BBI response');
    }
    final int wantedLeg = leg == BbiLeg.first ? 1 : 2;
    final String wantedBound = _directionFor(route, BusCompany.ctb);
    Map<String, dynamic>? group;
    Map<String, dynamic>? fallback;
    for (final dynamic value in decoded.values) {
      if (value is! Map) continue;
      final int? type = int.tryParse(value['legType']?.toString() ?? '');
      if (type != wantedLeg) continue;
      final Map<String, dynamic> candidate = value.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      fallback ??= candidate;
      if (candidate['bound']?.toString() == wantedBound) {
        group = candidate;
        break;
      }
    }
    group ??= fallback;
    final dynamic raw = group?['ir'];
    if (raw is! List) return const [];
    final List<BbiEntry> entries = [];
    for (final dynamic value in raw) {
      if (value is! Map) continue;
      final String routeNumber = _clean(value['route']);
      if (routeNumber.isEmpty) continue;
      entries.add(
        BbiEntry(
          route: routeNumber,
          destination: _clean(value['direction']),
          stop: _clean(value['stopName']),
          discount: _citybusDiscount(value, zh),
          timeLimit: _minutes(value['timeLimit'], zh),
          consecutive: '',
          remark: _clean(value['remark']),
          detail: '',
          validity: '',
        ),
      );
    }
    return entries;
  }

  Future<bool> refreshAll({
    void Function(int completed, int total)? onProgress,
  }) async {
    bool ok = true;
    for (int index = 0; index < _allKmbFiles.length; index++) {
      try {
        await _ensureKmbFile(_allKmbFiles[index], force: true);
      } catch (_) {
        ok = false;
      }
      onProgress?.call(index + 1, _allKmbFiles.length);
    }
    _kmbCache.clear();
    return ok;
  }

  Future<void> clearCache() async {
    _kmbCache.clear();
    final Directory dir = await _kmbDirectory();
    if (!await dir.exists()) return;
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
  }

  Future<int> storedBytes() async {
    final Directory dir = await _kmbDirectory();
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        total += await entity.length();
      }
    }
    return total;
  }

  String _directionFor(RouteEntry route, BusCompany company) {
    final String? bound = route.boundFor(company);
    return bound == 'I' ? 'B' : 'F';
  }

  Future<Directory> _kmbDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory('${support.path}/hktransports/bbi/kmb');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _ensureKmbFile(String name, {bool force = false}) async {
    final Directory dir = await _kmbDirectory();
    final File file = File('${dir.path}/$name');
    if (!force && await file.exists() && await file.length() > 1000) {
      return file;
    }
    final Uri uri = Uri.https(kmbHost, '/storage/$name');
    final http.Response response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw HttpException('KMB BBI download failed: ${response.statusCode}');
    }
    final File temp = File('${file.path}.tmp');
    await temp.writeAsBytes(response.bodyBytes, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
    return file;
  }

  String _kmbTimeLimit(String validity, bool zh) {
    const Map<String, int> limits = {'^': 30, '#': 60, '*': 90, '@': 120};
    for (final MapEntry<String, int> entry in limits.entries) {
      if (validity.contains(entry.key)) {
        return zh ? '${entry.value} 分鐘' : '${entry.value} min';
      }
    }
    return '';
  }

  String _citybusDiscount(Map<dynamic, dynamic> entry, bool zh) {
    final String code = entry['discount']?.toString() ?? '';
    final Map<dynamic, dynamic> amount = entry['discountAmount'] is Map
        ? entry['discountAmount'] as Map
        : const {};
    final Map<dynamic, dynamic> fare = entry['totalFare'] is Map
        ? entry['totalFare'] as Map
        : const {};
    switch (code) {
      case 'L2':
        return zh ? '次程免費' : 'Second leg free';
      case 'FR':
        return zh
            ? '減收 \$${_money(amount['adult'])}'
            : 'Discount \$${_money(amount['adult'])}';
      case 'TF':
        return zh
            ? '兩程優惠車資合共 \$${_money(fare['adult'])}'
            : 'Combined fare \$${_money(fare['adult'])}';
      default:
        return code;
    }
  }

  String _minutes(dynamic value, bool zh) {
    final String raw = _clean(value);
    if (raw.isEmpty) return '';
    return zh ? '$raw 分鐘' : '$raw min';
  }

  String _money(dynamic value) {
    final String raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '—';
    final double? amount = double.tryParse(raw);
    if (amount == null) return raw;
    return amount == amount.truncateToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
  }
}

List<List<String>> _readKmbRecords(List<String> args) {
  final File file = File(args[0]);
  if (!file.existsSync()) return const [];
  final dynamic decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) return const [];
  final dynamic routeData = decoded[args[1]];
  if (routeData is! Map) return const [];
  final dynamic records = routeData['Records'];
  if (records is! List) return const [];
  final bool zh = args[2] == 'chi';
  return [
    for (final dynamic value in records)
      if (value is Map)
        <String>[
          _clean(value['sec_routeno']),
          _clean(value['sec_dest']),
          _clean(value['xchange']),
          _clean(value['discount_max']),
          _clean(value['validity']),
          _clean(value['success_cnt']),
          _clean(zh ? value['spec_remark_chi'] : value['spec_remark_eng']),
          _detailText(value['detail']?.toString() ?? ''),
        ],
  ];
}

String _detailText(String raw) {
  final String value = raw.trim();
  if (value.isEmpty || value == '--') return '';
  final fragment = html_parser.parseFragment(value);
  final element = fragment.querySelector('[data-title]');
  final String title = element?.attributes['data-title']?.trim() ?? '';
  if (title.isNotEmpty) return _clean(title);
  final String text = (fragment.text ?? '').trim();
  return text == '--' ? '' : _clean(text);
}

String _clean(dynamic value) => (value?.toString() ?? '')
    .replaceAll('\u00a0', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
