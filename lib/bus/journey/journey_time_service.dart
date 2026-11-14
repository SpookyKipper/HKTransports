import 'dart:convert';

import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class _CachedFile {
  const _CachedFile(this.data, this.expiresAt);

  final Map<String, dynamic>? data;
  final DateTime expiresAt;
}

/// Loads stop-to-stop travel times from the historical HK Bus ETA dataset.
///
/// This is the runtime bridge used until the route database carries precomputed
/// [RouteJourneyTimes] for every route. Precomputed profiles always take
/// priority in the UI; this service is only called when they are absent.
class JourneyTimeService {
  JourneyTimeService({
    http.Client? client,
    List<String>? baseUrls,
    this.timeout = const Duration(seconds: 8),
    this.cacheTtl = const Duration(hours: 1),
  }) : _client = client,
       _baseUrls = baseUrls ?? defaultBaseUrls;

  static const List<String> defaultBaseUrls = <String>[
    'https://data.hktransports.spookysrv.com',
    'https://raw.githubusercontent.com/HK-Bus-ETA/hk-bus-time-between-stops/refs/heads/pages',
  ];

  static final JourneyTimeService instance = JourneyTimeService();

  final http.Client? _client;
  final List<String> _baseUrls;
  final Duration timeout;
  final Duration cacheTtl;
  final Map<String, _CachedFile> _cache = <String, _CachedFile>{};

  Future<List<int>?> fetchSegmentSeconds({
    required List<StopEntry> stops,
    required List<String> holidays,
    DateTime? now,
  }) async {
    if (stops.length < 2) return null;

    final DateTime hkTime = now ?? hkNow();
    final bool holiday = isHoliday(holidays, hkTime);
    final int day = holiday ? 0 : hkTime.weekday % 7;
    final String hour = hkTime.hour.toString().padLeft(2, '0');
    final Set<String> prefixes = <String>{};
    for (int index = 0; index < stops.length - 1; index++) {
      final String? prefix = _prefix(stops[index].id);
      if (prefix != null) prefixes.add(prefix);
    }
    if (prefixes.isEmpty) return null;

    final http.Client client = _client ?? http.Client();
    try {
      final Map<String, Map<String, dynamic>?> files =
          <String, Map<String, dynamic>?>{};
      await Future.wait(
        prefixes.map((String prefix) async {
          files[prefix] = await _fetchFirst(
            client,
            _candidateUrls(prefix, day, hour),
          );
        }),
      );

      final List<int> seconds = <int>[];
      for (int index = 0; index < stops.length - 1; index++) {
        final String start = stops[index].id;
        final String end = stops[index + 1].id;
        final String? prefix = _prefix(start);
        if (prefix == null) return null;
        final int? value = _lookup(files[prefix], start, end);
        if (value == null || value <= 0) return null;
        seconds.add(value);
      }
      return seconds;
    } finally {
      if (_client == null) client.close();
    }
  }

  List<String> _candidateUrls(String prefix, int day, String hour) {
    final List<String> urls = <String>[];
    for (final String base in _baseUrls) {
      urls.add('$base/times_hourly/$day/$hour/$prefix.json');
      urls.add('$base/times/$prefix.json');
    }
    return urls;
  }

  Future<Map<String, dynamic>?> _fetchFirst(
    http.Client client,
    List<String> urls,
  ) async {
    for (final String url in urls) {
      final DateTime now = DateTime.now();
      final _CachedFile? cached = _cache[url];
      if (cached != null && cached.expiresAt.isAfter(now)) {
        if (cached.data != null) return cached.data;
        continue;
      }
      try {
        final http.Response response = await client
            .get(Uri.parse(url))
            .timeout(timeout);
        if (response.statusCode == 200) {
          final Object? decoded = jsonDecode(
            utf8.decode(response.bodyBytes, allowMalformed: true),
          );
          if (decoded is Map<String, dynamic>) {
            _cache[url] = _CachedFile(decoded, now.add(cacheTtl));
            return decoded;
          }
        }
      } catch (_) {
        // Try the next mirror, then fall back to the distance estimate.
      }
      _cache[url] = _CachedFile(null, now.add(const Duration(minutes: 5)));
    }
    return null;
  }

  String? _prefix(String id) => id.length >= 2 ? id.substring(0, 2) : null;

  int? _lookup(Map<String, dynamic>? file, String start, String end) {
    final Object? row = file?[start];
    if (row is! Map) return null;
    final Object? value = row[end];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  void clearCache() => _cache.clear();
}
