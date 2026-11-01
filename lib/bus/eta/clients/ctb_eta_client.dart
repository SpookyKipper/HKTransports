import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class CtbEtaClient implements EtaClient {
  CtbEtaClient({http.Client? client}) : _client = client ?? http.Client();

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

    List<dynamic> data = await _fetchData(
      'https://rt.data.gov.hk/v2/transport/citybus/eta/CTB/$stopId/${route.route}',
    );
    if (data.isEmpty) {
      data = await _fetchData(
        'https://rt.data.gov.hk/v1/transport/citybus-nwfb/eta/CTB/$stopId/${route.route}',
      );
    }
    if (data.isEmpty) return const [];

    final List<Map<String, dynamic>> matching = data
        .whereType<Map<String, dynamic>>()
        .where((entry) => bound.contains(entry['dir']?.toString() ?? ''))
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
      final String etaText = (entry['eta'] ?? '').toString();
      final String remarkEn = (entry['rmk_en'] ?? '').toString();
      final String remarkZh = (entry['rmk_tc'] ?? '').toString();
      result.add(
        BusEta(
          company: BusCompany.ctb,
          eta: etaText.isEmpty ? null : parseEtaTime(etaText),
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

  Future<List<dynamic>> _fetchData(String url) async {
    final http.Response response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    return (decoded['data'] as List<dynamic>?) ?? const [];
  }

  bool _isScheduled(String en, String zh) {
    final String lower = en.toLowerCase();
    return lower.contains('scheduled') ||
        zh.contains('預定') ||
        zh.contains('原定');
  }
}
