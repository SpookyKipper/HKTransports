import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:sqlite3/sqlite3.dart';

class CitybusStopData {
  const CitybusStopData({
    required this.stopId,
    this.routeSeq,
    this.lat,
    this.lon,
    this.adultFare,
    this.childFare,
    this.seniorFare,
    this.landmark,
    this.destinationName,
  });

  final String stopId;
  final int? routeSeq;
  final double? lat;
  final double? lon;
  final double? adultFare;
  final double? childFare;
  final double? seniorFare;
  final String? landmark;
  final String? destinationName;
}

class CitybusEtaArguments {
  const CitybusEtaArguments({
    required this.stopId,
    required this.rdv,
    required this.seq,
    required this.bound,
    required this.lat,
    required this.lon,
  });

  final String stopId;
  final String rdv;
  final int seq;
  final String bound;
  final double lat;
  final double lon;

  String get info => '$stopId||$rdv||$seq||$bound';

  String get altLat => lat.toString();

  String get altLon => lon.toString();
}

class CitybusRouteData {
  const CitybusRouteData({
    required this.routeIndex,
    required this.stops,
    this.routeName,
    this.rdv,
    this.bound,
    this.routingRemark,
    this.variantDescription,
  });

  final int routeIndex;
  final List<CitybusStopData> stops;
  final String? routeName;
  final String? rdv;
  final String? bound;
  final String? routingRemark;
  final String? variantDescription;

  String? get specialDescription {
    final String? variant = _nonNormalDescription(variantDescription);
    if (variant != null) {
      final String? derived = _descriptionWithoutRouteName(variant, routeName);
      if (derived != null) return derived;
    }
    return _nonNormalDescription(routingRemark);
  }

  CitybusStopData? stopById(String stopId, {int? occurrence}) {
    CitybusStopData? found;
    int seen = 0;
    for (final CitybusStopData stop in stops) {
      if (stop.stopId != stopId) continue;
      if (occurrence == null || seen == occurrence) return stop;
      seen++;
      found ??= stop;
    }
    return found;
  }
}

String? _nonNormalDescription(String? value) {
  final String description = value?.trim() ?? '';
  if (description.isEmpty) return null;
  if (isNormalCitybusRouteDescription(description)) return null;
  return description;
}

/// Removes a leading phrase that duplicates the route name. If the remaining
/// part is parenthesised, only the parenthetical note is returned.
String? _descriptionWithoutRouteName(String description, String? routeName) {
  final String route = routeName?.trim() ?? '';
  if (route.isEmpty) return description;

  final RegExpMatch? openMatch = RegExp(r'[\(（]').firstMatch(description);
  if (openMatch != null) {
    final String prefix = description.substring(0, openMatch.start).trim();
    if (prefix.isNotEmpty && route.contains(prefix)) {
      final int close = description.indexOf(RegExp(r'[\)）]'), openMatch.end);
      if (close > openMatch.end) {
        final String note = description.substring(openMatch.end, close).trim();
        if (note.isNotEmpty) return note;
      }
      return null;
    }
  }
  if (route.contains(description)) return null;
  return description;
}

bool isNormalCitybusRouteDescription(String value) {
  final String normalised = value
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalised == '正常路線' ||
      normalised == 'normal route' ||
      normalised == 'normal service' ||
      normalised == 'normal';
}

class CitybusRoutelistRecord {
  const CitybusRoutelistRecord({
    required this.company,
    required this.serviceNo,
    required this.destLocation,
    required this.origin,
    required this.destination,
    required this.routeKey,
    required this.routeIndex,
    required this.bound,
    required this.name,
    required this.rdv,
    required this.destinationLabel,
  });

  final String company;
  final String serviceNo;
  final String destLocation;
  final String origin;
  final String destination;
  final String routeKey;
  final int routeIndex;
  final String bound;
  final String name;
  final String rdv;
  final String destinationLabel;
}

/// Parses the packed `dest_location` value from Citybus `ROUTELIST`.
CitybusRoutelistRecord? parseCitybusRoutelistRecord(String packed) {
  final List<String> fields = packed.split('||');
  if (fields.length < 13) return null;
  final int? routeIndex = int.tryParse(fields[8].trim());
  if (routeIndex == null) return null;
  final CitybusRoutelistRecord record = CitybusRoutelistRecord(
    company: fields[0].trim().toUpperCase(),
    serviceNo: fields[1].trim().toUpperCase(),
    destLocation: fields[2].trim(),
    origin: fields[4].trim(),
    destination: fields[5].trim(),
    routeKey: fields[7].trim(),
    routeIndex: routeIndex,
    bound: fields[9].trim(),
    name: fields[10].trim(),
    rdv: fields[11].trim(),
    destinationLabel: fields[12].trim(),
  );
  if (record.company.isEmpty || record.serviceNo.isEmpty) return null;
  return record;
}

class CitybusRoutelistReader {
  CitybusRoutelistReader(this.database);

  final Database database;
  final Map<String, CitybusRouteData?> _routeCache = {};
  final Map<String, List<CitybusRoutelistRecord>> _recordCache = {};

  void dispose() {
    database.close();
  }

  CitybusRouteData? routeData(RouteEntry route, String language) {
    if (!route.companies.contains(BusCompany.ctb)) return null;
    final List<String> currentStops =
        route.stops[BusCompany.ctb] ?? const <String>[];
    if (currentStops.isEmpty) return null;
    final String cacheKey = '${route.key}|${language == 'en' ? 'en' : 'zh'}';
    if (_routeCache.containsKey(cacheKey)) return _routeCache[cacheKey];

    final CitybusRouteData? result = _loadRouteData(
      route,
      currentStops,
      language,
    );
    _routeCache[cacheKey] = result;
    return result;
  }

  CitybusStopData? stopData(RouteEntry route, int stopIndex, String language) {
    final CitybusRouteData? data = routeData(route, language);
    if (data == null) return null;
    final String? stopId = route.stopIdAt(BusCompany.ctb, stopIndex);
    if (stopId == null || stopId.isEmpty) return null;
    final List<String> currentStops =
        route.stops[BusCompany.ctb] ?? const <String>[];
    int occurrence;
    if (data.stops.length == currentStops.length) {
      occurrence = stopIndex;
    } else {
      occurrence = 0;
    }
    return data.stopById(stopId, occurrence: occurrence);
  }

  CitybusEtaArguments? etaArguments(
    RouteEntry route,
    int stopIndex,
    String language,
  ) {
    final CitybusRouteData? data = routeData(route, language);
    if (data == null) return null;
    final String? stopId = route.stopIdAt(BusCompany.ctb, stopIndex);
    if (stopId == null || stopId.isEmpty) return null;
    final List<String> currentStops =
        route.stops[BusCompany.ctb] ?? const <String>[];
    final int occurrence = data.stops.length == currentStops.length
        ? stopIndex
        : 0;
    final CitybusStopData? stop = data.stopById(stopId, occurrence: occurrence);
    final String rdv = data.rdv?.trim() ?? '';
    final int? seq = stop?.routeSeq;
    final double? lat = stop?.lat;
    final double? lon = stop?.lon;
    final String bound = (data.bound ?? route.boundFor(BusCompany.ctb) ?? '')
        .trim()
        .toUpperCase();
    if (stop == null ||
        rdv.isEmpty ||
        seq == null ||
        seq <= 0 ||
        lat == null ||
        lon == null ||
        (bound != 'O' && bound != 'I')) {
      return null;
    }
    return CitybusEtaArguments(
      stopId: stop.stopId,
      rdv: rdv,
      seq: seq,
      bound: bound,
      lat: lat,
      lon: lon,
    );
  }

  String? routeName(RouteEntry route, String language) {
    if (!route.companies.contains(BusCompany.ctb)) return null;
    final CitybusRouteData? data = routeData(route, language);
    if (data != null && data.routeName != null && data.routeName!.isNotEmpty) {
      return data.routeName;
    }
    return _bestRecordName(route, language);
  }

  List<String> remarkInfoKeys(RouteEntry route) {
    final CitybusRouteData? data =
        routeData(route, 'zh') ?? routeData(route, 'en');
    if (data != null && data.rdv != null && data.rdv!.isNotEmpty) {
      return <String>[data.rdv!];
    }
    final String? rdv = _bestRecordRdv(route);
    return rdv == null || rdv.isEmpty ? const <String>[] : <String>[rdv];
  }

  CitybusRouteData? _loadRouteData(
    RouteEntry route,
    List<String> currentStops,
    String language,
  ) {
    final String serviceNo = route.route.trim().toUpperCase();
    if (serviceNo.isEmpty) return null;
    final ResultSet rows = database.select(
      '''
      SELECT ROUTE_INDEX, BOUND, DIRECTION, DEST_LOCATION, ROUTING_SEQ,
             WEB_ORIGIN, WEB_DESTIN, WEB_SHOW, ROUTE_RDV, RDV,
             ROUTING_REMARK, VARDESC
      FROM ROUTE
      WHERE COMPANY_CODE = ? AND SERVICE_NO = ?
      ''',
      <Object?>['CTB', serviceNo],
    );
    if (rows.isEmpty) return null;

    final Map<int, Map<String, Object?>> rowsByIndex =
        <int, Map<String, Object?>>{};
    final String? currentBound = route.boundFor(BusCompany.ctb);
    for (final Row row in rows) {
      final int? routeIndex = _asInt(row['ROUTE_INDEX']);
      if (routeIndex == null) continue;
      final Map<String, Object?> candidate = _rowMap(row);
      final Map<String, Object?>? existing = rowsByIndex[routeIndex];
      if (existing == null ||
          _preferRouteRow(candidate, existing, currentBound)) {
        rowsByIndex[routeIndex] = candidate;
      }
    }

    _Candidate? best;
    for (final MapEntry<int, Map<String, Object?>> entry
        in rowsByIndex.entries) {
      final List<CitybusStopData> stops = _stopsFor(serviceNo, entry.key);
      if (stops.isEmpty) continue;
      final double score = _routeScore(
        route,
        currentStops,
        stops,
        entry.value,
        language,
      );
      if (best == null || score > best.score) {
        best = _Candidate(entry.value, stops, score);
      }
    }
    if (best == null) return null;

    final int routeIndex = _asInt(best.row['ROUTE_INDEX'])!;
    final String? routeName = _routeNameForIndex(route, language, routeIndex);
    final String? rdv = _firstText(<Object?>[
      best.row['RDV'],
      _normaliseRdv(_text(best.row['ROUTE_RDV']), route.route),
    ]);
    return CitybusRouteData(
      routeIndex: routeIndex,
      stops: List<CitybusStopData>.unmodifiable(best.stops),
      routeName: routeName,
      rdv: rdv,
      bound: _text(best.row['BOUND']),
      routingRemark: _text(best.row['ROUTING_REMARK']),
      variantDescription: _text(best.row['VARDESC']),
    );
  }

  String? _routeNameForIndex(
    RouteEntry route,
    String language,
    int? routeIndex,
  ) {
    final List<CitybusRoutelistRecord> records = _records(route.route);
    if (routeIndex != null) {
      for (final CitybusRoutelistRecord record in records) {
        if (record.routeIndex == routeIndex && record.name.isNotEmpty) {
          return record.name;
        }
      }
    }
    return _bestRecordName(route, language);
  }

  String? _bestRecordName(RouteEntry route, String language) {
    final List<CitybusRoutelistRecord> records = _records(route.route);
    final String? bound = route.boundFor(BusCompany.ctb);
    CitybusRoutelistRecord? best;
    double bestScore = -1;
    for (final CitybusRoutelistRecord record in records) {
      final double score = _recordScore(record, route, bound, language);
      if (score > bestScore) {
        bestScore = score;
        best = record;
      }
    }
    if (best == null || best.name.isEmpty) return null;
    return best.name;
  }

  List<CitybusStopData> _stopsFor(String serviceNo, int routeIndex) {
    final ResultSet rows = database.select(
      '''
      SELECT STOP_ID, BSA_SEQ, LAT, LON, ADULT_FARE, CHILD_FARE,
             SENIOR_FARE, BUSSTOP_INFO, DESC_NAME
      FROM ROUTESTOP
      WHERE COMPANY_CODE = ? AND SERVICE_NO = ? AND ROUTE_INDEX = ?
      ORDER BY BSA_SEQ
      ''',
      <Object?>['CTB', serviceNo, routeIndex],
    );
    final List<CitybusStopData> result = <CitybusStopData>[];
    for (final Row row in rows) {
      final String? stopId = _text(row['STOP_ID']);
      if (stopId == null || stopId.isEmpty) continue;
      result.add(
        CitybusStopData(
          stopId: stopId,
          routeSeq: _asInt(row['BSA_SEQ']),
          lat: _asDouble(row['LAT']),
          lon: _asDouble(row['LON']),
          adultFare: _asDouble(row['ADULT_FARE']),
          childFare: _asDouble(row['CHILD_FARE']),
          seniorFare: _asDouble(row['SENIOR_FARE']),
          landmark: _text(row['BUSSTOP_INFO']),
          destinationName: _text(row['DESC_NAME']),
        ),
      );
    }
    return result;
  }

  List<CitybusRoutelistRecord> _records(String serviceNo) {
    final String key = serviceNo.trim().toUpperCase();
    final List<CitybusRoutelistRecord>? cached = _recordCache[key];
    if (cached != null) return cached;
    final ResultSet rows = database.select(
      'SELECT dest_location FROM ROUTELIST WHERE service_no = ?',
      <Object?>[key],
    );
    final List<CitybusRoutelistRecord> records = <CitybusRoutelistRecord>[];
    for (final Row row in rows) {
      final String? packed = _text(row['dest_location']);
      if (packed == null) continue;
      final CitybusRoutelistRecord? record = parseCitybusRoutelistRecord(
        packed,
      );
      if (record == null || record.company != 'CTB') continue;
      if (record.serviceNo != key) continue;
      records.add(record);
    }
    _recordCache[key] = records;
    return records;
  }

  String? _bestRecordRdv(RouteEntry route) {
    final List<CitybusRoutelistRecord> records = _records(route.route);
    final String? bound = route.boundFor(BusCompany.ctb);
    CitybusRoutelistRecord? best;
    double bestScore = -1;
    for (final CitybusRoutelistRecord record in records) {
      final double score = _recordScore(record, route, bound, 'zh');
      if (score > bestScore) {
        bestScore = score;
        best = record;
      }
    }
    return best?.rdv;
  }

  double _routeScore(
    RouteEntry route,
    List<String> currentStops,
    List<CitybusStopData> candidateStops,
    Map<String, Object?> row,
    String language,
  ) {
    final List<String> candidateIds = candidateStops
        .map((CitybusStopData stop) => stop.stopId)
        .toList(growable: false);
    final Set<String> currentSet = currentStops.toSet();
    final Set<String> candidateSet = candidateIds.toSet();
    final int common = currentSet.intersection(candidateSet).length;
    final int union = currentSet.union(candidateSet).length;
    final double overlap = union == 0 ? 0 : common / union;
    final bool exact = listEquals(currentStops, candidateIds);
    final String? currentBound = route.boundFor(BusCompany.ctb);
    final bool boundMatch =
        currentBound != null && currentBound == _text(row['BOUND']);
    final double originScore = _nameScore(
      route.orig.get(language),
      _text(row['WEB_ORIGIN']),
    );
    final double destinationScore = _nameScore(
      route.dest.get(language),
      _text(row['WEB_DESTIN']),
    );
    final double lengthPenalty = currentStops.isEmpty
        ? 0
        : (currentStops.length - candidateIds.length).abs() /
              currentStops.length;
    if (exact) {
      return 1000 +
          (boundMatch ? 100 : 0) +
          originScore * 20 +
          destinationScore * 20;
    }
    return overlap * 100 +
        (boundMatch ? 25 : 0) +
        originScore * 15 +
        destinationScore * 15 -
        lengthPenalty * 10;
  }

  double _recordScore(
    CitybusRoutelistRecord record,
    RouteEntry route,
    String? bound,
    String language,
  ) {
    double score = 0;
    if (bound != null && record.bound == bound) score += 20;
    score += _nameScore(route.orig.get(language), record.origin) * 10;
    score += _nameScore(route.dest.get(language), record.destination) * 10;
    return score;
  }

  bool _preferRouteRow(
    Map<String, Object?> candidate,
    Map<String, Object?> existing,
    String? bound,
  ) {
    final bool candidateBound =
        bound != null && _text(candidate['BOUND']) == bound;
    final bool existingBound =
        bound != null && _text(existing['BOUND']) == bound;
    if (candidateBound != existingBound) return candidateBound;
    final bool candidateWeb = _text(candidate['WEB_SHOW']) == 'Y';
    final bool existingWeb = _text(existing['WEB_SHOW']) == 'Y';
    if (candidateWeb != existingWeb) return candidateWeb;
    return false;
  }
}

void prepareCitybusRoutelistDatabase(Database database) {
  try {
    database.execute(
      'CREATE INDEX IF NOT EXISTS citybus_route_service '
      'ON ROUTE(COMPANY_CODE, SERVICE_NO)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS citybus_routestop_service '
      'ON ROUTESTOP(COMPANY_CODE, SERVICE_NO, ROUTE_INDEX, BSA_SEQ)',
    );
    database.execute(
      'CREATE INDEX IF NOT EXISTS citybus_routelist_service '
      'ON ROUTELIST(service_no)',
    );
  } catch (error) {
    debugPrint('Unable to prepare Citybus routelist indexes: $error');
  }
}

class _Candidate {
  const _Candidate(this.row, this.stops, this.score);

  final Map<String, Object?> row;
  final List<CitybusStopData> stops;
  final double score;
}

Map<String, Object?> _rowMap(Row row) {
  final Map<String, Object?> result = <String, Object?>{};
  for (final String key in row.keys) {
    result[key] = row[key];
  }
  return result;
}

String? _text(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// `ROUTE_RDV` uses a zero-padded route prefix (for example `0A28-LHP-1`),
/// while the remark endpoint expects the normal route number (`A28-LHP-1`).
String? _normaliseRdv(String? value, String routeNumber) {
  if (value == null) return null;
  final String route = routeNumber.trim().toUpperCase();
  String result = value.trim();
  if (route.isEmpty || result.toUpperCase().startsWith(route)) return result;
  while (result.startsWith('0') &&
      result.length > 1 &&
      !result.toUpperCase().startsWith(route)) {
    result = result.substring(1);
  }
  return result.isEmpty ? null : result;
}

String? _firstText(List<Object?> values) {
  for (final Object? value in values) {
    final String? text = _text(value);
    if (text != null) return text;
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double _nameScore(String? a, String? b) {
  final String left = _normaliseName(a);
  final String right = _normaliseName(b);
  if (left.isEmpty || right.isEmpty) return 0;
  if (left == right) return 1;
  if (left.contains(right) || right.contains(left)) return 0.8;
  final Set<String> leftWords = _words(a);
  final Set<String> rightWords = _words(b);
  if (leftWords.isEmpty || rightWords.isEmpty) return 0;
  final int common = leftWords.intersection(rightWords).length;
  final int union = leftWords.union(rightWords).length;
  return union == 0 ? 0 : common / union;
}

String _normaliseName(String? value) {
  return (value ?? '').toLowerCase().replaceAll(
    RegExp(r'[\s,，、·:：()（）\-–—_/]+'),
    '',
  );
}

Set<String> _words(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
      .split(' ')
      .where((String word) => word.isNotEmpty)
      .toSet();
}
