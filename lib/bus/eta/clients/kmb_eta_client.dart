import 'dart:convert';

import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

DateTime? parseEtaTime(String? value) {
  if (value == null) return null;
  final String text = value.trim();
  if (text.isEmpty) return null;
  if (text.contains(' ') && !text.contains('T')) {
    return DateTime.tryParse('${text.replaceFirst(' ', 'T')}+08:00');
  }
  return DateTime.tryParse(text);
}

abstract class EtaClient {
  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required String language,
  });
}

class KmbEtaClient implements EtaClient {
  KmbEtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required String language,
  }) async {
    final String? stopId = route.stopIdAt(company, seq);
    final String? bound = route.boundFor(company);
    if (stopId == null || bound == null || stopId.isEmpty) return const [];

    final Uri uri = Uri.parse(
      'https://data.etabus.gov.hk/v1/transport/kmb/eta/$stopId/${route.route}/${route.serviceType}',
    );
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final List<dynamic> data = (decoded['data'] as List<dynamic>?) ?? const [];

    final List<Map<String, dynamic>> matching = data
        .whereType<Map<String, dynamic>>()
        .where((entry) => entry['dir']?.toString() == bound)
        .toList();
    if (matching.isEmpty) return const [];

    final int targetSeq = seq + 1;
    matching.sort((a, b) {
      final int aSeq = (a['seq'] as num?)?.toInt() ?? 0;
      final int bSeq = (b['seq'] as num?)?.toInt() ?? 0;
      return (aSeq - targetSeq).abs().compareTo((bSeq - targetSeq).abs());
    });
    final int nearest = (matching.first['seq'] as num?)?.toInt() ?? targetSeq;

    final List<BusEta> result = [];
    for (final Map<String, dynamic> entry in matching) {
      final int entrySeq = (entry['seq'] as num?)?.toInt() ?? 0;
      if (entrySeq != nearest) continue;
      final String? entryService = entry['service_type']?.toString();
      if (route.companies.length == 1 &&
          entryService == route.serviceType &&
          entrySeq != targetSeq) {
        continue;
      }
      final List<String> stops = route.primaryStops;
      if (stops.length > 1 &&
          stops.first == stops.last &&
          seq == 0 &&
          entrySeq != targetSeq) {
        continue;
      }
      final String remarkEn = (entry['rmk_en'] ?? '').toString();
      final String remarkZh = (entry['rmk_tc'] ?? '').toString();
      result.add(
        BusEta(
          company: BusCompany.kmb,
          eta: parseEtaTime(entry['eta']?.toString()),
          remarkZh: remarkZh,
          remarkEn: remarkEn,
          destZh: (entry['dest_tc'] ?? '').toString(),
          destEn: (entry['dest_en'] ?? '').toString(),
          etaSeq: (entry['eta_seq'] as num?)?.toInt() ?? 0,
          scheduled: _isScheduled(remarkEn, remarkZh),
        ),
      );
    }
    return result;
  }

  bool _isScheduled(String en, String zh) {
    final String lower = en.toLowerCase();
    return lower.contains('scheduled') ||
        zh.contains('預定') ||
        zh.contains('原定');
  }
}
