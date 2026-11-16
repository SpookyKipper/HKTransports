import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/eta/citybus_eta_match.dart';
import 'package:hktransports/bus/eta/citybus_eta_status_client.dart';
import 'package:hktransports/bus/eta/clients/ctb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/ferry_eta_client.dart';
import 'package:hktransports/bus/eta/clients/gmb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/lightrail_eta_client.dart';
import 'package:hktransports/bus/eta/clients/lrtfeeder_eta_client.dart';
import 'package:hktransports/bus/eta/clients/mtr_eta_client.dart';
import 'package:hktransports/bus/eta/clients/nlb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

class EtaService {
  EtaService({
    String language = 'zh',
    AppSettings? settings,
    BusDatabase? Function()? databaseProvider,
  }) : _language = language,
       _settings = settings,
       _databaseProvider = databaseProvider;

  String _language;
  final AppSettings? _settings;
  final BusDatabase? Function()? _databaseProvider;

  final KmbEtaClient _kmb = KmbEtaClient();
  final CtbEtaClient _ctb = CtbEtaClient();
  final NlbEtaClient _nlb = NlbEtaClient();
  final GmbEtaClient _gmb = GmbEtaClient();
  final LrtFeederEtaClient _lrtFeeder = LrtFeederEtaClient();
  final MtrEtaClient _mtr = MtrEtaClient();
  final LightRailEtaClient _lightRail = LightRailEtaClient();
  final FerryEtaClient _ferry = FerryEtaClient();
  final CitybusEtaStatusClient _ctbStatus = CitybusEtaStatusClient();
  static const Duration _statusCacheTtl = Duration(seconds: 90);
  static const Duration _citybusNoEtaRetryDelay = Duration(seconds: 5);

  final StreamController<EtaStatusUpdate> _statusUpdates =
      StreamController<EtaStatusUpdate>.broadcast();
  final Map<String, _CachedCitybusStatus> _statusCache =
      <String, _CachedCitybusStatus>{};
  final Map<String, _CachedKmbRouteEtas> _kmbRouteCache =
      <String, _CachedKmbRouteEtas>{};
  final Map<String, Future<Map<int, List<BusEta>>?>> _kmbRouteRequests =
      <String, Future<Map<int, List<BusEta>>?>>{};

  String get language => _language;

  Stream<EtaStatusUpdate> get statusUpdates => _statusUpdates.stream;

  void setLanguage(String language) {
    _language = language == 'en' ? 'en' : 'zh';
  }

  void dispose() {
    _statusUpdates.close();
    unawaited(_ctbStatus.dispose());
  }

  Future<List<BusEta>> fetchRouteStop(RouteEntry route, int seq) async {
    try {
      final List<BusCompany> companies = route.sortedCompanies.where((company) {
        final List<String>? stops = route.stops[company];
        return stops != null && seq >= 0 && seq < stops.length;
      }).toList();
      if (companies.isEmpty) return const [];

      final List<Future<List<BusEta>>> tasks = companies.map((company) {
        return _fetchCompany(route, company, seq).catchError((Object error) {
          debugPrint('ETA fetch failed for ${company.name}: $error');
          return <BusEta>[];
        });
      }).toList();

      final List<List<BusEta>> results = await Future.wait(tasks);
      final List<BusEta> merged = [];
      for (final List<BusEta> result in results) {
        merged.addAll(result);
      }
      return _normalise(filterJointOperatorEtas(route, merged));
    } catch (error) {
      debugPrint('ETA fetch failed: $error');
      return const <BusEta>[];
    }
  }

  Future<List<BusEta>> _fetchCompany(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) {
    switch (company) {
      case BusCompany.kmb:
        return _fetchKmbRouteStop(route, company, seq);
      case BusCompany.ctb:
        return _fetchCitybus(route, company, seq);
      case BusCompany.nlb:
        return _fetchNlb(route, company, seq);
      case BusCompany.gmb:
        return _gmb.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
      case BusCompany.lrtfeeder:
        return _lrtFeeder.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
      case BusCompany.mtr:
        return _mtr.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
      case BusCompany.lightRail:
        return _lightRail.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
      case BusCompany.sunferry:
      case BusCompany.fortuneferry:
      case BusCompany.hkkf:
        return _ferry.fetch(
          route: route,
          company: company,
          seq: seq,
          database: _databaseProvider?.call(),
        );
    }
  }

  bool get _kmbRouteCacheEnabled => _settings?.upstreamEtaScan ?? false;

  Duration get _kmbRouteEtaCacheTtl {
    final int seconds = _settings?.refreshSeconds ?? 30;
    return Duration(seconds: seconds.clamp(5, 120));
  }

  Future<List<BusEta>> _fetchKmbRouteStop(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) async {
    if (!_kmbRouteCacheEnabled) {
      return _kmb.fetch(
        route: route,
        company: company,
        seq: seq,
        language: _language,
      );
    }

    final String key = _kmbRouteCacheKey(route);
    final Map<int, List<BusEta>>? bySeq = await _kmbRouteEtas(route, key);
    if (bySeq == null) {
      return _kmb.fetch(
        route: route,
        company: company,
        seq: seq,
        language: _language,
      );
    }
    return _selectKmbRouteStopEtas(bySeq, route, seq);
  }

  void invalidateKmbRouteCache(RouteEntry route) {
    _kmbRouteCache.remove(_kmbRouteCacheKey(route));
  }

  String _kmbRouteCacheKey(RouteEntry route) {
    return '${route.key}|${route.serviceType}|'
        '${route.boundFor(BusCompany.kmb) ?? ''}';
  }

  Future<Map<int, List<BusEta>>?> _kmbRouteEtas(
    RouteEntry route,
    String key,
  ) async {
    final _CachedKmbRouteEtas? cached = _kmbRouteCache[key];
    if (cached != null) {
      if (DateTime.now().difference(cached.fetchedAt) <= _kmbRouteEtaCacheTtl) {
        return cached.bySeq;
      }
      _kmbRouteCache.remove(key);
    }

    final Future<Map<int, List<BusEta>>?>? running = _kmbRouteRequests[key];
    if (running != null) return running;

    final Future<Map<int, List<BusEta>>?> future = _kmb.fetchRouteEtas(route);
    _kmbRouteRequests[key] = future;
    try {
      final Map<int, List<BusEta>>? bySeq = await future;
      if (bySeq != null) {
        _kmbRouteCache[key] = _CachedKmbRouteEtas(
          bySeq: bySeq,
          fetchedAt: DateTime.now(),
        );
      }
      return bySeq;
    } finally {
      if (identical(_kmbRouteRequests[key], future)) {
        _kmbRouteRequests.remove(key);
      }
    }
  }

  List<BusEta> _selectKmbRouteStopEtas(
    Map<int, List<BusEta>> bySeq,
    RouteEntry route,
    int seq,
  ) {
    if (bySeq.isEmpty) return const <BusEta>[];
    final int targetSeq = seq + 1;
    int? nearest;
    for (final int value in bySeq.keys) {
      if (nearest == null ||
          (value - targetSeq).abs() < (nearest - targetSeq).abs()) {
        nearest = value;
      }
    }
    if (nearest == null) return const <BusEta>[];
    if (route.companies.length == 1 && nearest != targetSeq) {
      return const <BusEta>[];
    }
    final List<String> stops = route.primaryStops;
    if (stops.length > 1 &&
        stops.first == stops.last &&
        seq == 0 &&
        nearest != targetSeq) {
      return const <BusEta>[];
    }
    return List<BusEta>.of(bySeq[nearest] ?? const <BusEta>[]);
  }

  Future<List<BusEta>> _fetchCitybus(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) async {
    List<BusEta> first = const <BusEta>[];
    try {
      first = await _fetchCitybusOnce(route, company, seq);
    } catch (error) {
      debugPrint('Citybus ETA fetch failed: $error');
    }
    if (first.isNotEmpty) return first;

    await Future<void>.delayed(_citybusNoEtaRetryDelay);
    try {
      return await _fetchCitybusOnce(route, company, seq);
    } catch (error) {
      debugPrint('Citybus ETA retry failed: $error');
      return const <BusEta>[];
    }
  }

  Future<List<BusEta>> _fetchCitybusOnce(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) async {
    final AppSettings? settings = _settings;
    if (settings != null &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.citybusEtaStatus)) {
      return _fetchCitybusProprietary(route, seq);
    }
    return _ctb.fetch(
      route: route,
      company: company,
      seq: seq,
      language: _language,
    );
  }

  Future<List<BusEta>> _fetchCitybusProprietary(
    RouteEntry route,
    int seq,
  ) async {
    final CitybusEtaArguments? args = await CitybusRoutelistService.instance
        .etaArguments(route, seq, _language);
    if (args == null) return const <BusEta>[];

    final List<CitybusEtaStatus> statuses = await _ctbStatus.fetch(
      args,
      language: _language,
    );
    if (statuses.isEmpty) return const <BusEta>[];

    final List<BusEta> result = <BusEta>[];
    for (int index = 0; index < statuses.length; index++) {
      final CitybusEtaStatus status = statuses[index];
      result.add(
        BusEta(
          company: BusCompany.ctb,
          eta: _parseCitybusTime(status.timeText),
          remarkZh: '',
          remarkEn: '',
          destZh: route.dest.zh,
          destEn: route.dest.en,
          etaSeq: index + 1,
          statusZh: status.statusZh,
          statusEn: status.statusEn,
          distanceKm: status.distanceKm,
          proprietaryTime: status.timeText,
          proprietaryMinutes: status.minutesText,
        ),
      );
    }
    return result;
  }

  DateTime? _parseCitybusTime(String? text) {
    final RegExpMatch? match = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(text?.trim() ?? '');
    if (match == null) return null;
    final int? hour = int.tryParse(match.group(1) ?? '');
    final int? minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    final DateTime hkTime = hkNow();
    DateTime value = DateTime.utc(
      hkTime.year,
      hkTime.month,
      hkTime.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 8));
    final DateTime nowUtc = DateTime.now().toUtc();
    if (value.isBefore(nowUtc.subtract(const Duration(hours: 12)))) {
      value = value.add(const Duration(days: 1));
    }
    return value;
  }

  List<BusEta> applyCachedStatuses(
    RouteEntry route,
    int seq,
    List<BusEta> etas,
  ) {
    final String key = _statusKey(route, seq);
    return applyCitybusStatusesByTime(etas, _cachedStatuses(key));
  }

  Future<List<BusEta>> _fetchNlb(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) {
    return _nlb.fetch(
      route: route,
      company: company,
      seq: seq,
      language: _language,
    );
  }

  List<CitybusEtaStatus>? _cachedStatuses(String key) {
    final _CachedCitybusStatus? cached = _statusCache[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.fetchedAt) > _statusCacheTtl) {
      _statusCache.remove(key);
      return null;
    }
    return cached.statuses;
  }

  String _statusKey(RouteEntry route, int seq) => '${route.key}|$seq';

  List<BusEta> _normalise(List<BusEta> input) {
    if (input.isEmpty) return const [];
    final bool hasEta = input.any((eta) => eta.hasEta);
    final List<BusEta> result = hasEta
        ? input.where((eta) => eta.hasEta).toList()
        : input;
    final Map<String, BusEta> deduped = {};
    for (final BusEta eta in result) {
      final int time = eta.eta?.millisecondsSinceEpoch ?? 0;
      final String key = '$time|${eta.destEn}|${eta.etaSeq}';
      final BusEta? existing = deduped[key];
      if (existing == null ||
          eta.company.priority < existing.company.priority) {
        deduped[key] = eta;
      }
    }
    final List<BusEta> sorted = deduped.values.toList();
    sorted.sort((a, b) {
      final DateTime? aTime = a.eta;
      final DateTime? bTime = b.eta;
      if (aTime == null && bTime == null) {
        return a.company.priority.compareTo(b.company.priority);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final int timeCompare = aTime.compareTo(bTime);
      if (timeCompare != 0) return timeCompare;
      final int companyCompare = a.company.priority.compareTo(
        b.company.priority,
      );
      if (companyCompare != 0) return companyCompare;
      return a.etaSeq.compareTo(b.etaSeq);
    });
    return sorted;
  }
}

class EtaStatusUpdate {
  const EtaStatusUpdate({required this.routeKey, required this.seq});

  final String routeKey;
  final int seq;
}

class _CachedKmbRouteEtas {
  const _CachedKmbRouteEtas({required this.bySeq, required this.fetchedAt});

  final Map<int, List<BusEta>> bySeq;
  final DateTime fetchedAt;
}

class _CachedCitybusStatus {
  const _CachedCitybusStatus({required this.statuses, required this.fetchedAt});

  final List<CitybusEtaStatus> statuses;
  final DateTime fetchedAt;
}

/// Removes Citybus proprietary rows that represent the KMB/LWB half of a
/// jointly operated route. Those rows duplicate the KMB open-data entries.
@visibleForTesting
List<BusEta> filterJointOperatorEtas(RouteEntry route, Iterable<BusEta> etas) {
  final bool jointWithKmb =
      route.companies.contains(BusCompany.ctb) &&
      route.companies.contains(BusCompany.kmb);
  if (!jointWithKmb) return etas.toList(growable: false);

  final List<BusEta> kmbEtas = etas
      .where((BusEta eta) => eta.company == BusCompany.kmb && eta.eta != null)
      .toList(growable: false);
  return etas
      .where((BusEta eta) {
        if (eta.company != BusCompany.ctb) return true;
        final String status = '${eta.statusZh ?? ''} ${eta.statusEn ?? ''}'
            .toLowerCase();
        if (status.contains('九巴') ||
            status.contains('龍運') ||
            status.contains('kmb') ||
            status.contains('lwb')) {
          return false;
        }
        return !_isDuplicateCitybusJourney(eta, kmbEtas);
      })
      .toList(growable: false);
}

/// Citybus' proprietary board sometimes lists an LWB departure with no operator
/// label, no status, and no Citybus distance. Its clock time can differ from the
/// KMB open-data timestamp by up to a minute because nwp3 only shows minutes.
bool _isDuplicateCitybusJourney(BusEta eta, List<BusEta> kmbEtas) {
  final DateTime? time = eta.eta;
  if (time == null || eta.proprietaryTime == null) return false;
  // A live Citybus vehicle has a distance and is not a scheduled LWB row.
  if (eta.distanceKm != null) return false;

  const Duration duplicateWindow = Duration(seconds: 90);
  for (final BusEta kmb in kmbEtas) {
    final DateTime? kmbTime = kmb.eta;
    if (kmbTime == null) continue;
    if (time.difference(kmbTime).abs() <= duplicateWindow) return true;
  }
  return false;
}
