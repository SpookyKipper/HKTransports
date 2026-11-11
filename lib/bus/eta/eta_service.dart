import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/eta/citybus_eta_status_client.dart';
import 'package:hktransports/bus/eta/clients/ctb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/gmb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/lrtfeeder_eta_client.dart';
import 'package:hktransports/bus/eta/clients/nlb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

class EtaService {
  EtaService({String language = 'zh', AppSettings? settings})
    : _language = language,
      _settings = settings;

  String _language;
  final AppSettings? _settings;

  final KmbEtaClient _kmb = KmbEtaClient();
  final CtbEtaClient _ctb = CtbEtaClient();
  final NlbEtaClient _nlb = NlbEtaClient();
  final GmbEtaClient _gmb = GmbEtaClient();
  final LrtFeederEtaClient _lrtFeeder = LrtFeederEtaClient();
  final CitybusEtaStatusClient _ctbStatus = const CitybusEtaStatusClient();

  String get language => _language;

  void setLanguage(String language) {
    _language = language == 'en' ? 'en' : 'zh';
  }

  Future<List<BusEta>> fetchRouteStop(RouteEntry route, int seq) async {
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
    return _normalise(merged);
  }

  Future<List<BusEta>> _fetchCompany(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) {
    switch (company) {
      case BusCompany.kmb:
        return _kmb.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
      case BusCompany.ctb:
        return _fetchCitybus(route, company, seq);
      case BusCompany.nlb:
        return _nlb.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
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
      case BusCompany.lightRail:
      case BusCompany.sunferry:
      case BusCompany.fortuneferry:
      case BusCompany.hkkf:
        return Future.value(const []);
    }
  }

  Future<List<BusEta>> _fetchCitybus(
    RouteEntry route,
    BusCompany company,
    int seq,
  ) async {
    final List<BusEta> base = await _ctb.fetch(
      route: route,
      company: company,
      seq: seq,
      language: _language,
    );
    final AppSettings? settings = _settings;
    if (base.isEmpty ||
        settings == null ||
        !settings.isProprietaryEnabled(ProprietaryEndpoint.citybusEtaStatus)) {
      return base;
    }

    try {
      final CitybusEtaArguments? args = await CitybusRoutelistService.instance
          .etaArguments(route, seq, _language);
      if (args == null) return base;
      final List<CitybusEtaStatus> statuses = await _ctbStatus.fetch(args);
      if (statuses.isEmpty) return base;

      final List<BusEta> sorted = List<BusEta>.of(base)
        ..sort((BusEta a, BusEta b) {
          final DateTime? aTime = a.eta;
          final DateTime? bTime = b.eta;
          if (aTime == null && bTime == null) {
            return a.etaSeq.compareTo(b.etaSeq);
          }
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          final int byTime = aTime.compareTo(bTime);
          if (byTime != 0) return byTime;
          return a.etaSeq.compareTo(b.etaSeq);
        });

      final List<BusEta> enriched = <BusEta>[];
      int statusIndex = 0;
      for (final BusEta eta in sorted) {
        if (eta.eta == null || statusIndex >= statuses.length) {
          enriched.add(eta);
          continue;
        }
        final CitybusEtaStatus status = statuses[statusIndex++];
        enriched.add(
          eta.copyWith(
            statusZh: status.statusZh,
            statusEn: status.statusEn,
            distanceKm: status.distanceKm,
          ),
        );
      }
      return enriched;
    } catch (error) {
      debugPrint('Citybus ETA status failed: $error');
      return base;
    }
  }

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
