import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class NlbEtaClient implements EtaClient {
  NlbEtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required String language,
  }) async {
    final String? stopId = route.stopIdAt(company, seq);
    final String? routeId = route.nlbId;
    if (stopId == null || routeId == null || stopId.isEmpty) return const [];

    final Uri uri = Uri.parse(
      'https://rt.data.gov.hk/v2/transport/nlb/stop.php'
      '?action=estimatedArrivals&routeId=$routeId&stopId=$stopId'
      '&language=${language == 'en' ? 'en' : 'zh'}',
    );
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final List<dynamic> arrivals =
        (decoded['estimatedArrivals'] as List<dynamic>?) ?? const [];
    if (arrivals.isEmpty) {
      final String message = (decoded['message'] ?? '').toString();
      if (message.isEmpty) return const [];
      return [
        BusEta(
          company: BusCompany.nlb,
          eta: null,
          remarkZh: language == 'en' ? '' : message,
          remarkEn: language == 'en' ? message : '',
          destZh: '',
          destEn: '',
          etaSeq: 0,
        ),
      ];
    }

    final List<BusEta> result = [];
    for (final dynamic value in arrivals) {
      if (value is! Map<String, dynamic>) continue;
      final String etaText = (value['estimatedArrivalTime'] ?? '').toString();
      if (etaText.isEmpty) continue;
      final bool scheduled =
          value['departed']?.toString() != '1' ||
          value['noGPS']?.toString() == '1';
      final String variant = (value['routeVariantName'] ?? '').toString();
      final Object? wheelchairValue =
          value['wheelChair'] ?? value['wheelchair'];
      result.add(
        BusEta(
          company: BusCompany.nlb,
          eta: parseEtaTime(etaText),
          remarkZh: scheduled ? '預定班次' : '',
          remarkEn: scheduled ? 'Scheduled' : '',
          destZh: language == 'en' ? '' : variant,
          destEn: language == 'en' ? variant : '',
          etaSeq: result.length + 1,
          scheduled: scheduled,
          wheelchair: _isWheelchair(wheelchairValue),
        ),
      );
    }
    return result;
  }
}

bool _isWheelchair(Object? value) {
  if (value == true) return true;
  if (value is num) return value == 1;
  final String text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true';
}
