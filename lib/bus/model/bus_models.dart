import 'package:hktransports/functions/title_case.dart';

enum BusCompany {
  kmb,
  ctb,
  nlb,
  gmb,
  lrtfeeder,
  lightRail,
  mtr,
  sunferry,
  fortuneferry,
  hkkf;

  static BusCompany? fromId(String? value) {
    if (value == null) return null;
    for (final BusCompany company in BusCompany.values) {
      if (company.name == value) return company;
    }
    return null;
  }
}

extension BusCompanyInfo on BusCompany {
  String get id => name;

  String get labelZh {
    switch (this) {
      case BusCompany.kmb:
        return '九巴';
      case BusCompany.ctb:
        return '城巴';
      case BusCompany.nlb:
        return '嶼巴';
      case BusCompany.gmb:
        return '專線小巴';
      case BusCompany.lrtfeeder:
        return '港鐵巴士';
      case BusCompany.lightRail:
        return '輕鐵';
      case BusCompany.mtr:
        return '港鐵';
      case BusCompany.sunferry:
        return '新渡輪';
      case BusCompany.fortuneferry:
        return '富裕小輪';
      case BusCompany.hkkf:
        return '港九小輪';
    }
  }

  String get labelEn {
    switch (this) {
      case BusCompany.kmb:
        return 'KMB';
      case BusCompany.ctb:
        return 'Citybus';
      case BusCompany.nlb:
        return 'NLB';
      case BusCompany.gmb:
        return 'GMB';
      case BusCompany.lrtfeeder:
        return 'MTR bus';
      case BusCompany.lightRail:
        return 'Light Rail';
      case BusCompany.mtr:
        return 'MTR';
      case BusCompany.sunferry:
        return 'Sun Ferry';
      case BusCompany.fortuneferry:
        return 'Fortune Ferry';
      case BusCompany.hkkf:
        return 'HKKF';
    }
  }

  String label(String language) => language == 'en' ? labelEn : labelZh;

  int get priority {
    switch (this) {
      case BusCompany.kmb:
        return 0;
      case BusCompany.ctb:
        return 1;
      case BusCompany.nlb:
        return 2;
      case BusCompany.gmb:
        return 3;
      case BusCompany.lrtfeeder:
        return 4;
      case BusCompany.mtr:
        return 5;
      case BusCompany.lightRail:
        return 6;
      case BusCompany.sunferry:
        return 7;
      case BusCompany.fortuneferry:
        return 8;
      case BusCompany.hkkf:
        return 9;
    }
  }

  bool get isBus {
    return this == BusCompany.kmb ||
        this == BusCompany.ctb ||
        this == BusCompany.nlb ||
        this == BusCompany.gmb ||
        this == BusCompany.lrtfeeder;
  }
}

class Terminal {
  const Terminal({required this.en, required this.zh});

  final String en;
  final String zh;

  String get(String language) => language == 'en' ? en : zh;

  factory Terminal.fromJson(Map<String, dynamic> json) {
    return Terminal(
      en: (json['en'] ?? '').toString(),
      zh: (json['zh'] ?? '').toString(),
    );
  }
}

class StopEntry {
  const StopEntry({
    required this.id,
    required this.nameEn,
    required this.displayEn,
    required this.nameZh,
    required this.displayZh,
    required this.lat,
    required this.lng,
    this.stationCode,
    this.platformCode,
  });

  final String id;
  final String nameEn;
  final String displayEn;
  final String nameZh;
  final String displayZh;
  final double lat;
  final double lng;
  final String? stationCode;
  final String? platformCode;

  String displayName(String language) =>
      language == 'en' ? displayEn : displayZh;

  String rawName(String language) => language == 'en' ? nameEn : nameZh;

  factory StopEntry.fromJson(String id, Map<String, dynamic> json) {
    final Map<String, dynamic> name =
        (json['name'] as Map<String, dynamic>?) ?? const {};
    final Map<String, dynamic> location =
        (json['location'] as Map<String, dynamic>?) ?? const {};
    final String nameEn = (name['en'] ?? '').toString();
    final String nameZh = (name['zh'] ?? '').toString();
    final _ParsedName parsedEn = _parseStopName(nameEn);
    final _ParsedName parsedZh = _parseStopName(nameZh);
    final bool isKmb = _kmbStopIdPattern.hasMatch(id);
    return StopEntry(
      id: id,
      nameEn: nameEn,
      displayEn: isKmb ? toProperCase(parsedEn.display) : parsedEn.display,
      nameZh: nameZh,
      displayZh: parsedZh.display,
      lat: (location['lat'] as num?)?.toDouble() ?? 0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0,
      stationCode: parsedEn.stationCode ?? parsedZh.stationCode,
      platformCode: parsedEn.platformCode ?? parsedZh.platformCode,
    );
  }
}

class _ParsedName {
  const _ParsedName(this.display, this.stationCode, this.platformCode);

  final String display;
  final String? stationCode;
  final String? platformCode;
}

final RegExp _stationCodePattern = RegExp(r'\s*\(([A-Z]{2}\d{3}[a-z]?)\)\s*$');
final RegExp _kmbStopIdPattern = RegExp(r'^[0-9A-Fa-f]{16}$');
final RegExp _platformCodePattern = RegExp(r'\s*\(([A-Z]\d{1,2})\)\s*$');

_ParsedName _parseStopName(String raw) {
  String display = raw.trim();
  String? stationCode;
  String? platformCode;

  final RegExpMatch? stationMatch = _stationCodePattern.firstMatch(display);
  if (stationMatch != null) {
    stationCode = stationMatch.group(1);
    display = display
        .replaceRange(stationMatch.start, stationMatch.end, '')
        .trim();
  }

  final RegExpMatch? platformMatch = _platformCodePattern.firstMatch(display);
  if (platformMatch != null) {
    platformCode = platformMatch.group(1);
    display = display
        .replaceRange(platformMatch.start, platformMatch.end, '')
        .trim();
  }

  return _ParsedName(display, stationCode, platformCode);
}

class StopRef {
  const StopRef({required this.company, required this.stopId});

  final BusCompany company;
  final String stopId;
}

class RouteEntry {
  const RouteEntry({
    required this.key,
    required this.slug,
    required this.route,
    required this.serviceType,
    required this.companies,
    required this.orig,
    required this.dest,
    required this.stops,
    required this.bound,
    required this.seq,
    this.fares,
    this.faresHoliday,
    this.freq,
    this.jt,
    this.gtfsId,
    this.nlbId,
  });

  final String key;
  final String slug;
  final String route;
  final String serviceType;
  final List<BusCompany> companies;
  final Terminal orig;
  final Terminal dest;
  final Map<BusCompany, List<String>> stops;
  final Map<BusCompany, String> bound;
  final int seq;
  final List<String>? fares;
  final List<String>? faresHoliday;
  final Map<String, Map<String, List<String>?>>? freq;
  final String? jt;
  final String? gtfsId;
  final String? nlbId;

  List<BusCompany> get sortedCompanies {
    final List<BusCompany> result = [...companies];
    result.sort((a, b) => a.priority.compareTo(b.priority));
    return result;
  }

  BusCompany? get primaryCompany {
    for (final BusCompany company in sortedCompanies) {
      final List<String>? list = stops[company];
      if (list != null && list.isNotEmpty) return company;
    }
    return null;
  }

  List<String> get primaryStops {
    final BusCompany? company = primaryCompany;
    if (company == null) return const [];
    return stops[company] ?? const [];
  }

  bool get isSpecial {
    final int? value = int.tryParse(serviceType);
    return value != null && value >= 2;
  }

  bool get isCircular {
    final List<String> list = primaryStops;
    return list.length > 1 && list.first == list.last;
  }

  String? stopIdAt(BusCompany company, int index) {
    final List<String>? list = stops[company];
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index];
  }

  String? boundFor(BusCompany company) => bound[company];

  String? fareAt(int index, {required bool holiday}) {
    final List<String>? list = holiday ? faresHoliday : fares;
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index];
  }

  String companyLabel(BusCompany company, String language) {
    final String routeNumber = route.trim().toUpperCase();
    final bool english = language == 'en';
    if (company == BusCompany.ctb &&
        (routeNumber.startsWith('A') || routeNumber.startsWith('NA'))) {
      return english ? 'Cityflyer' : '城巴機場快線';
    }
    if (company == BusCompany.kmb && _isLongWinRoute(routeNumber)) {
      return english ? 'LWB' : '龍運';
    }
    return company.label(language);
  }

  bool _isLongWinRoute(String routeNumber) {
    if (routeNumber.startsWith('SP')) return false;
    if (routeNumber.startsWith('A') ||
        routeNumber.startsWith('NA') ||
        routeNumber.startsWith('E') ||
        routeNumber.startsWith('R') ||
        routeNumber.startsWith('X') ||
        routeNumber.startsWith('S')) {
      return true;
    }
    return const <String>{
      'N30',
      'N31',
      'N42',
      'N42A',
      'N64',
    }.contains(routeNumber);
  }

  String companiesLabel(String language) {
    return sortedCompanies
        .map((company) => companyLabel(company, language))
        .join(' + ');
  }
}

class BusDatabase {
  BusDatabase({
    required this.routesByKey,
    required this.routesBySlug,
    required this.routesByNumber,
    required this.stops,
    required this.stopMap,
    required this.holidays,
    required this.serviceDayMap,
  });

  final Map<String, RouteEntry> routesByKey;
  final Map<String, RouteEntry> routesBySlug;
  final Map<String, List<RouteEntry>> routesByNumber;
  final Map<String, StopEntry> stops;
  final Map<String, List<StopRef>> stopMap;
  final List<String> holidays;
  final Map<String, List<bool>> serviceDayMap;

  int get routeCount => routesByKey.length;
  int get stopCount => stops.length;

  RouteEntry? routeBySlug(String slug) => routesBySlug[slug];

  List<RouteEntry> routesForNumber(String number) {
    return routesByNumber[number.toUpperCase()] ?? const [];
  }

  factory BusDatabase.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> routeJson =
        (json['routeList'] as Map<String, dynamic>?) ?? const {};
    final Map<String, dynamic> stopJson =
        (json['stopList'] as Map<String, dynamic>?) ?? const {};
    final Map<String, dynamic> stopMapJson =
        (json['stopMap'] as Map<String, dynamic>?) ?? const {};
    final List<dynamic> holidayJson =
        (json['holidays'] as List<dynamic>?) ?? const [];
    final Map<String, dynamic> serviceDayJson =
        (json['serviceDayMap'] as Map<String, dynamic>?) ?? const {};

    final Map<String, StopEntry> stops = {};
    for (final MapEntry<String, dynamic> entry in stopJson.entries) {
      if (entry.value is Map<String, dynamic>) {
        stops[entry.key] = StopEntry.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        );
      }
    }

    final Map<String, List<StopRef>> stopMap = {};
    for (final MapEntry<String, dynamic> entry in stopMapJson.entries) {
      final List<dynamic> values = entry.value as List<dynamic>? ?? const [];
      final List<StopRef> refs = [];
      for (final dynamic value in values) {
        if (value is List && value.length >= 2) {
          final BusCompany? company = BusCompany.fromId(value[0]?.toString());
          if (company != null) {
            refs.add(StopRef(company: company, stopId: value[1].toString()));
          }
        }
      }
      stopMap[entry.key] = refs;
    }

    final Map<String, List<bool>> serviceDayMap = {};
    for (final MapEntry<String, dynamic> entry in serviceDayJson.entries) {
      final List<dynamic> days = entry.value as List<dynamic>? ?? const [];
      serviceDayMap[entry.key] = days
          .map((dynamic value) => value.toString() == '1')
          .toList(growable: false);
    }

    final List<_RawRoute> rawRoutes = [];
    for (final MapEntry<String, dynamic> entry in routeJson.entries) {
      final Map<String, dynamic> value = entry.value as Map<String, dynamic>;
      final List<BusCompany> companies = [];
      final List<dynamic> companyJson =
          (value['co'] as List<dynamic>?) ?? const [];
      for (final dynamic company in companyJson) {
        final BusCompany? parsed = BusCompany.fromId(company?.toString());
        if (parsed != null) companies.add(parsed);
      }
      final Map<BusCompany, List<String>> routeStops = {};
      final Map<String, dynamic> stopsJson =
          (value['stops'] as Map<String, dynamic>?) ?? const {};
      for (final MapEntry<String, dynamic> stopEntry in stopsJson.entries) {
        final BusCompany? company = BusCompany.fromId(stopEntry.key);
        if (company == null) continue;
        final List<dynamic> ids = stopEntry.value as List<dynamic>? ?? const [];
        routeStops[company] = ids.map((dynamic id) => id.toString()).toList();
      }
      final Map<BusCompany, String> bound = {};
      final Map<String, dynamic> boundJson =
          (value['bound'] as Map<String, dynamic>?) ?? const {};
      for (final MapEntry<String, dynamic> boundEntry in boundJson.entries) {
        final BusCompany? company = BusCompany.fromId(boundEntry.key);
        if (company != null) {
          bound[company] = boundEntry.value.toString();
        }
      }
      final Map<String, Map<String, List<String>?>>? freq = _parseFreq(
        value['freq'],
      );
      Terminal orig = Terminal.fromJson(
        (value['orig'] as Map<String, dynamic>?) ?? const {},
      );
      Terminal dest = Terminal.fromJson(
        (value['dest'] as Map<String, dynamic>?) ?? const {},
      );
      if (companies.contains(BusCompany.kmb)) {
        orig = Terminal(en: toProperCase(orig.en), zh: orig.zh);
        dest = Terminal(en: toProperCase(dest.en), zh: dest.zh);
      }
      rawRoutes.add(
        _RawRoute(
          key: entry.key,
          route: (value['route'] ?? '').toString(),
          serviceType: (value['serviceType'] ?? '1').toString(),
          companies: companies,
          orig: orig,
          dest: dest,
          stops: routeStops,
          bound: bound,
          seq: (value['seq'] as num?)?.toInt() ?? 0,
          fares: _stringList(value['fares']),
          faresHoliday: _stringList(value['faresHoliday']),
          freq: freq,
          jt: value['jt']?.toString(),
          gtfsId: value['gtfsId']?.toString(),
          nlbId: value['nlbId']?.toString(),
        ),
      );
    }

    final Map<String, List<_RawRoute>> slugGroups = {};
    for (final _RawRoute raw in rawRoutes) {
      final String base = normalizeRouteKey(raw.key);
      slugGroups.putIfAbsent(base, () => []).add(raw);
    }

    final Map<String, RouteEntry> routesByKey = {};
    final Map<String, RouteEntry> routesBySlug = {};
    final Map<String, List<RouteEntry>> routesByNumber = {};
    for (final MapEntry<String, List<_RawRoute>> group in slugGroups.entries) {
      final List<_RawRoute> routes = group.value;
      routes.sort((a, b) => a.key.compareTo(b.key));
      for (int index = 0; index < routes.length; index++) {
        final _RawRoute raw = routes[index];
        String slug = group.key;
        if (routes.length > 1) {
          final BusCompany company = _primaryCompany(raw.companies, raw.stops);
          slug = '${group.key}-${company.id}';
          if (routes.where((candidate) {
                final BusCompany candidateCompany = _primaryCompany(
                  candidate.companies,
                  candidate.stops,
                );
                return '${group.key}-${candidateCompany.id}' == slug;
              }).length >
              1) {
            slug = '$slug-${index + 1}';
          }
        }
        final RouteEntry route = RouteEntry(
          key: raw.key,
          slug: slug,
          route: raw.route,
          serviceType: raw.serviceType,
          companies: raw.companies,
          orig: raw.orig,
          dest: raw.dest,
          stops: raw.stops,
          bound: raw.bound,
          seq: raw.seq,
          fares: raw.fares,
          faresHoliday: raw.faresHoliday,
          freq: raw.freq,
          jt: raw.jt,
          gtfsId: raw.gtfsId,
          nlbId: raw.nlbId,
        );
        routesByKey[route.key] = route;
        routesBySlug[route.slug] = route;
        routesByNumber
            .putIfAbsent(route.route.toUpperCase(), () => [])
            .add(route);
      }
    }

    return BusDatabase(
      routesByKey: routesByKey,
      routesBySlug: routesBySlug,
      routesByNumber: routesByNumber,
      stops: stops,
      stopMap: stopMap,
      holidays: holidayJson.map((dynamic value) => value.toString()).toList(),
      serviceDayMap: serviceDayMap,
    );
  }

  static BusCompany _primaryCompany(
    List<BusCompany> companies,
    Map<BusCompany, List<String>> stops,
  ) {
    final List<BusCompany> sorted = [...companies]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (final BusCompany company in sorted) {
      if ((stops[company] ?? const []).isNotEmpty) return company;
    }
    return sorted.isEmpty ? BusCompany.kmb : sorted.first;
  }

  static Map<String, Map<String, List<String>?>>? _parseFreq(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final Map<String, Map<String, List<String>?>> result = {};
    for (final MapEntry<String, dynamic> service in value.entries) {
      if (service.value is! Map<String, dynamic>) continue;
      final Map<String, List<String>?> windows = {};
      for (final MapEntry<String, dynamic> window
          in (service.value as Map<String, dynamic>).entries) {
        final dynamic detail = window.value;
        if (detail is List && detail.length >= 2) {
          windows[window.key] = [detail[0].toString(), detail[1].toString()];
        } else {
          windows[window.key] = null;
        }
      }
      result[service.key] = windows;
    }
    return result;
  }

  static List<String>? _stringList(dynamic value) {
    if (value is! List) return null;
    return value.map((dynamic item) => item.toString()).toList();
  }
}

String normalizeRouteKey(String key) {
  return key.replaceAll('+', '-').replaceAll(' ', '-').toUpperCase();
}

class _RawRoute {
  const _RawRoute({
    required this.key,
    required this.route,
    required this.serviceType,
    required this.companies,
    required this.orig,
    required this.dest,
    required this.stops,
    required this.bound,
    required this.seq,
    this.fares,
    this.faresHoliday,
    this.freq,
    this.jt,
    this.gtfsId,
    this.nlbId,
  });

  final String key;
  final String route;
  final String serviceType;
  final List<BusCompany> companies;
  final Terminal orig;
  final Terminal dest;
  final Map<BusCompany, List<String>> stops;
  final Map<BusCompany, String> bound;
  final int seq;
  final List<String>? fares;
  final List<String>? faresHoliday;
  final Map<String, Map<String, List<String>?>>? freq;
  final String? jt;
  final String? gtfsId;
  final String? nlbId;
}

String hkDateKey(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}$month$day';
}

DateTime hkNow() {
  return DateTime.now().toUtc().add(const Duration(hours: 8));
}

bool isHoliday(List<String> holidays, DateTime date) {
  return holidays.contains(hkDateKey(date));
}

int weeklyMinute(DateTime date) {
  return date.weekday % 7 * 24 * 60 + date.hour * 60 + date.minute;
}

int weeklyMinuteForDay(int day, String hhmm) {
  final int hour = int.tryParse(hhmm.substring(0, 2)) ?? 0;
  final int minute = int.tryParse(hhmm.substring(2)) ?? 0;
  return day * 24 * 60 + hour * 60 + minute;
}

bool isRouteAvailable(
  RouteEntry route,
  bool holiday,
  Map<String, List<bool>> serviceDayMap,
  DateTime now,
) {
  final Map<String, Map<String, List<String>?>>? freq = route.freq;
  if (freq == null || freq.isEmpty) return true;

  final int current = weeklyMinute(now);
  final int wholeWeek = 7 * 24 * 60;
  for (final MapEntry<String, Map<String, List<String>?>> service
      in freq.entries) {
    final List<bool> days = serviceDayMap[service.key] ?? const [];
    if (days.isEmpty) return true;
    for (int day = 0; day < days.length; day++) {
      if (!days[day]) continue;
      for (final MapEntry<String, List<String>?> window
          in service.value.entries) {
        final String start = window.key;
        final List<String>? detail = window.value;
        final int startMinute = weeklyMinuteForDay(day, start);
        final int endMinute = detail == null
            ? startMinute
            : weeklyMinuteForDay(day, detail[0]);
        if (startMinute - 60 <= current && current <= endMinute + 60) {
          return true;
        }
        if (startMinute - 60 <= current + wholeWeek &&
            current + wholeWeek <= endMinute + 60) {
          return true;
        }
      }
    }
  }
  return false;
}
