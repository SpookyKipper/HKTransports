import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

/// Fetches the official route alignment GeoJSON for a route.
///
/// This mirrors the lookup used by the HK Bus ETA route map, but points at
/// the hktransports waypoint mirror. Files are static GeoJSON documents.
class RouteWaypoints {
  RouteWaypoints._();

  static const String baseUrl = 'https://waypoints.hktransports.spookysrv.com';
  static const Duration timeout = Duration(seconds: 20);

  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Returns the static waypoint file name for [route], or `null` when this
  /// route type has no waypoint file.
  static String? fileName(RouteEntry route) {
    final Set<BusCompany> companies = route.companies.toSet();

    if (companies.any(_ferryCompanies.contains)) {
      final String code = route.route.trim();
      if (code.isNotEmpty) return '$code.json';
    }

    if (companies.contains(BusCompany.mtr)) {
      final String code = route.route.trim().toLowerCase();
      if (code.isNotEmpty) return '$code.json';
    }

    if (companies.contains(BusCompany.lightRail)) {
      final String code = route.route.replaceAll('*', '').trim();
      if (code.isEmpty) return null;
      final bool circular =
          route.dest.en.toLowerCase().contains('circular') || route.isCircular;
      return circular ? '$code.json' : '${code}_${_direction(route)}.json';
    }

    final String? gtfsId = route.gtfsId?.trim();
    if (gtfsId != null && gtfsId.isNotEmpty) {
      return '$gtfsId-${_direction(route)}.json';
    }
    return null;
  }

  static const Set<BusCompany> _ferryCompanies = {
    BusCompany.sunferry,
    BusCompany.fortuneferry,
    BusCompany.hkkf,
  };

  static String _direction(RouteEntry route) {
    final BusCompany? company = route.companies.isNotEmpty
        ? route.companies.first
        : route.primaryCompany;
    final String? bound = company == null ? null : route.boundFor(company);
    return bound == 'I' ? 'I' : 'O';
  }

  /// Fetches and caches route geometry. Returns `null` if the route has no
  /// waypoint file or the request/response is invalid.
  static Future<Map<String, dynamic>?> fetch(RouteEntry route) async {
    final String? file = fileName(route);
    if (file == null) return null;
    final Map<String, dynamic>? cached = _cache[file];
    if (cached != null) return cached;

    try {
      final http.Response response = await http
          .get(Uri.parse('$baseUrl/$file'))
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final dynamic features = decoded['features'];
      if (features is! List || features.isEmpty) return null;
      _cache[file] = decoded;
      return decoded;
    } catch (error) {
      debugPrint('Route waypoint fetch failed for $file: $error');
      return null;
    }
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();
}
