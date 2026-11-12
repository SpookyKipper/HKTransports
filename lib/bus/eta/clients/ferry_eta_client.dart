import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class FerryEtaClient {
  FerryEtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required BusDatabase? database,
  }) async {
    switch (company) {
      case BusCompany.sunferry:
        return _sunFerry(route, seq, database);
      case BusCompany.hkkf:
        return _hkkf(route, seq, database);
      case BusCompany.fortuneferry:
        if (seq != 0) return const [];
        return _scheduled(route, company, database);
      default:
        return const [];
    }
  }

  Future<List<BusEta>> _sunFerry(
    RouteEntry route,
    int seq,
    BusDatabase? database,
  ) async {
    if (seq > 1) return const [];
    final DateTime now = DateTime.now().toUtc();
    final List<BusEta> apiEtas = <BusEta>[];
    try {
      final http.Response response = await _client
          .get(
            Uri.https('www.sunferry.com.hk', '/eta/', {'route': route.route}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          final List<dynamic> data =
              (decoded['data'] as List<dynamic>?) ?? const [];
          for (final dynamic value in data) {
            if (value is! Map<String, dynamic>) continue;
            final String? depart = value['depart_time']?.toString();
            final String? arrival = value['eta']?.toString();
            final bool useDeparture = seq == 0;
            final DateTime? eta = _parseHkTime(
              useDeparture ? depart : arrival,
              now,
            );
            if (eta == null) continue;
            if (useDeparture && arrival != null && arrival.isNotEmpty) {
              continue;
            }
            if (!eta.isAfter(now)) continue;
            final String remarkZh = (value['rmk_tc'] ?? '').toString().trim();
            final String remarkEn = (value['rmk_en'] ?? '').toString().trim();
            apiEtas.add(
              BusEta(
                company: BusCompany.sunferry,
                eta: eta,
                remarkZh: useDeparture
                    ? (remarkZh.isEmpty ? '預定班次' : remarkZh)
                    : remarkZh,
                remarkEn: useDeparture
                    ? (remarkEn.isEmpty ? 'Scheduled' : remarkEn)
                    : remarkEn,
                destZh: route.dest.zh,
                destEn: route.dest.en,
                etaSeq: apiEtas.length + 1,
                scheduled: useDeparture,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Fall back to the published timetable below.
    }
    if (seq == 1) {
      apiEtas.sort(_compareEta);
      return apiEtas;
    }
    return _mergeScheduled(route, BusCompany.sunferry, database, apiEtas);
  }

  Future<List<BusEta>> _hkkf(
    RouteEntry route,
    int seq,
    BusDatabase? database,
  ) async {
    if (seq == 0) {
      return _scheduled(route, BusCompany.hkkf, database);
    }
    if (seq != 1) return const [];
    final String? bound = route.boundFor(BusCompany.hkkf);
    final String routeNumber = route.route.startsWith('KF')
        ? route.route.substring(2)
        : route.route;
    try {
      final http.Response response = await _client
          .get(
            Uri.https(
              'www.hkkfeta.com',
              '/opendata/eta/$routeNumber/${bound == 'I' ? 'inbound' : 'outbound'}',
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const [];
      final List<dynamic> data =
          (decoded['data'] as List<dynamic>?) ?? const [];
      final DateTime now = DateTime.now().toUtc();
      final List<BusEta> result = <BusEta>[];
      for (final dynamic value in data) {
        if (value is! Map<String, dynamic>) continue;
        final String raw = (value['ETA'] ?? '').toString().trim();
        if (raw.isEmpty) continue;
        final DateTime? eta = parseEtaTime(raw) ?? _parseHkTime(raw, now);
        if (eta == null || !eta.isAfter(now)) continue;
        result.add(
          BusEta(
            company: BusCompany.hkkf,
            eta: eta,
            remarkZh: '',
            remarkEn: '',
            destZh: route.dest.zh,
            destEn: route.dest.en,
            etaSeq: result.length + 1,
          ),
        );
      }
      result.sort(_compareEta);
      return result;
    } catch (_) {
      return const [];
    }
  }

  List<BusEta> _scheduled(
    RouteEntry route,
    BusCompany company,
    BusDatabase? database,
  ) {
    final DateTime now = DateTime.now().toUtc();
    final List<DateTime> times = upcomingFerryDepartures(
      route: route,
      database: database,
      now: now,
    );
    return <BusEta>[
      for (int index = 0; index < times.length; index++)
        BusEta(
          company: company,
          eta: times[index],
          remarkZh: '預定班次',
          remarkEn: 'Scheduled',
          destZh: route.dest.zh,
          destEn: route.dest.en,
          etaSeq: index + 1,
          scheduled: true,
        ),
    ];
  }

  List<BusEta> _mergeScheduled(
    RouteEntry route,
    BusCompany company,
    BusDatabase? database,
    List<BusEta> apiEtas,
  ) {
    final List<BusEta> result = List<BusEta>.of(apiEtas);
    final Set<int> used = apiEtas
        .map((BusEta eta) => eta.eta?.millisecondsSinceEpoch ?? 0)
        .toSet();
    for (final DateTime time in upcomingFerryDepartures(
      route: route,
      database: database,
      now: DateTime.now().toUtc(),
    )) {
      final int key = time.millisecondsSinceEpoch;
      if (used.contains(key)) continue;
      used.add(key);
      result.add(
        BusEta(
          company: company,
          eta: time,
          remarkZh: '預定班次',
          remarkEn: 'Scheduled',
          destZh: route.dest.zh,
          destEn: route.dest.en,
          etaSeq: 0,
          scheduled: true,
        ),
      );
    }
    result.sort(_compareEta);
    return _withSequence(result);
  }

  int _compareEta(BusEta a, BusEta b) {
    return (a.eta ?? DateTime.now()).compareTo(b.eta ?? DateTime.now());
  }

  List<BusEta> _withSequence(List<BusEta> etas) {
    return <BusEta>[
      for (int index = 0; index < etas.length; index++)
        etas[index].copyWith(etaSeq: index + 1),
    ];
  }
}

/// Upcoming departures from the published ferry timetable within 3 hours.
List<DateTime> upcomingFerryDepartures({
  required RouteEntry route,
  required BusDatabase? database,
  required DateTime now,
  Duration horizon = const Duration(hours: 3),
}) {
  final Map<String, Map<String, List<String>?>>? freq = route.freq;
  final Map<String, List<bool>>? serviceDayMap = database?.serviceDayMap;
  if (freq == null || freq.isEmpty || serviceDayMap == null) {
    return const <DateTime>[];
  }
  final DateTime hkNow = now.toUtc().add(const Duration(hours: 8));
  final DateTime firstDay = DateTime.utc(hkNow.year, hkNow.month, hkNow.day);
  final Set<int> seen = <int>{};
  final List<DateTime> result = <DateTime>[];
  for (int offset = 0; offset < 3; offset++) {
    final DateTime day = firstDay.add(Duration(days: offset));
    final int weekday = day.weekday % 7;
    final bool holiday =
        weekday == 0 || (database?.holidays.contains(hkDateKey(day)) ?? false);
    for (final MapEntry<String, Map<String, List<String>?>> service
        in freq.entries) {
      final List<bool> days = serviceDayMap[service.key] ?? const [];
      if (days.isEmpty) continue;
      final bool active = holiday
          ? days[0]
          : weekday < days.length && days[weekday];
      if (!active) continue;
      for (final String time in service.value.keys) {
        final String padded = time.padLeft(4, '0');
        final int? hour = int.tryParse(padded.substring(0, 2));
        final int? minute = int.tryParse(padded.substring(2));
        if (hour == null || minute == null) continue;
        final DateTime local = day.add(Duration(hours: hour, minutes: minute));
        final DateTime eta = local.subtract(const Duration(hours: 8));
        if (!eta.isAfter(now) || eta.difference(now) > horizon) continue;
        if (seen.add(eta.millisecondsSinceEpoch)) result.add(eta);
      }
    }
  }
  result.sort();
  return result;
}

DateTime? _parseHkTime(String? hhmm, DateTime now) {
  final RegExpMatch? match = RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch((hhmm ?? '').trim());
  if (match == null) return null;
  final int? hour = int.tryParse(match.group(1) ?? '');
  final int? minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null) return null;
  final DateTime hkNow = now.toUtc().add(const Duration(hours: 8));
  DateTime local = DateTime.utc(
    hkNow.year,
    hkNow.month,
    hkNow.day,
    hour,
    minute,
  );
  if (local.isBefore(hkNow.subtract(const Duration(hours: 12)))) {
    local = local.add(const Duration(days: 1));
  }
  return local.subtract(const Duration(hours: 8));
}
