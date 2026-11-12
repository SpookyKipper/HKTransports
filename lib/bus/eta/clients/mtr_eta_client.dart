import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class MtrEtaClient implements EtaClient {
  MtrEtaClient({http.Client? client}) : _client = client ?? http.Client();

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
    if (stopId == null || stopId.isEmpty || bound == null) return const [];

    final http.Response response = await _client
        .get(
          Uri.https(
            'rt.data.gov.hk',
            '/v1/transport/mtr/getSchedule.php',
            <String, String>{'line': route.route, 'sta': stopId},
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return const [];

    final int? status = (decoded['status'] as num?)?.toInt();
    if (status == 0) {
      final String message = (decoded['message'] ?? '').toString().trim();
      if (message.isEmpty) return const [];
      return <BusEta>[
        BusEta(
          company: BusCompany.mtr,
          eta: null,
          remarkZh: message,
          remarkEn: message,
          destZh: '',
          destEn: '',
          etaSeq: 1,
        ),
      ];
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    final Map<String, dynamic>? line =
        data?['${route.route}-$stopId'] as Map<String, dynamic>?;
    if (line == null) return const [];

    final String direction = bound.endsWith('UT') ? 'UP' : 'DOWN';
    final List<dynamic> entries =
        (line[direction] as List<dynamic>?) ?? const [];
    final List<String> routeStops = route.stops[company] ?? const [];
    final List<BusEta> result = <BusEta>[];
    for (final dynamic value in entries) {
      if (value is! Map<String, dynamic>) continue;
      final String dest = (value['dest'] ?? '').toString();
      if (routeStops.isNotEmpty && !routeStops.contains(dest)) continue;
      final DateTime? eta = parseEtaTime(value['time']?.toString());
      if (eta == null) continue;
      final String? platform = value['plat']?.toString();
      result.add(
        BusEta(
          company: BusCompany.mtr,
          eta: eta,
          remarkZh: '',
          remarkEn: '',
          destZh: dest,
          destEn: dest,
          etaSeq: result.length + 1,
          platform: platform,
        ),
      );
    }
    result.sort((BusEta a, BusEta b) {
      return (a.eta ?? DateTime.now()).compareTo(b.eta ?? DateTime.now());
    });
    return result;
  }
}
