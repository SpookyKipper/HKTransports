import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class GmbEtaClient implements EtaClient {
  GmbEtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required String language,
  }) async {
    final String? stopId = route.stopIdAt(company, seq);
    final String? gtfsId = route.gtfsId;
    final String? bound = route.boundFor(company);
    if (stopId == null ||
        stopId.isEmpty ||
        gtfsId == null ||
        gtfsId.isEmpty ||
        bound == null) {
      return const [];
    }

    final Uri uri = Uri.parse(
      'https://data.etagmb.gov.hk/eta/route-stop/$gtfsId/$stopId',
    );
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final List<dynamic> data = (decoded['data'] as List<dynamic>?) ?? const [];
    final int routeSeq = bound == 'I' ? 2 : 1;
    final int stopSeq = seq + 1;

    final List<BusEta> result = [];
    for (final dynamic value in data) {
      if (value is! Map<String, dynamic>) continue;
      if ((value['route_seq'] as num?)?.toInt() != routeSeq) continue;
      if ((value['stop_seq'] as num?)?.toInt() != stopSeq) continue;
      final bool enabled = value['enabled'] == true;
      if (!enabled) {
        result.add(
          BusEta(
            company: BusCompany.gmb,
            eta: null,
            remarkZh: (value['description_tc'] ?? '').toString(),
            remarkEn: (value['description_en'] ?? '').toString(),
            destZh: '',
            destEn: '',
            etaSeq: 0,
          ),
        );
        continue;
      }
      final List<dynamic> etas = (value['eta'] as List<dynamic>?) ?? const [];
      for (final dynamic etaValue in etas) {
        if (etaValue is! Map<String, dynamic>) continue;
        result.add(
          BusEta(
            company: BusCompany.gmb,
            eta: parseEtaTime(etaValue['timestamp']?.toString()),
            remarkZh: (etaValue['remarks_tc'] ?? '').toString(),
            remarkEn: (etaValue['remarks_en'] ?? '').toString(),
            destZh: '',
            destEn: '',
            etaSeq: (etaValue['eta_seq'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return result;
  }
}
