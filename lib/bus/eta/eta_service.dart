import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/eta/clients/ctb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/gmb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/lrtfeeder_eta_client.dart';
import 'package:hktransports/bus/eta/clients/nlb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class EtaService {
  EtaService({String language = 'zh'}) : _language = language;

  String _language;

  final KmbEtaClient _kmb = KmbEtaClient();
  final CtbEtaClient _ctb = CtbEtaClient();
  final NlbEtaClient _nlb = NlbEtaClient();
  final GmbEtaClient _gmb = GmbEtaClient();
  final LrtFeederEtaClient _lrtFeeder = LrtFeederEtaClient();

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
        return _ctb.fetch(
          route: route,
          company: company,
          seq: seq,
          language: _language,
        );
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
