import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class LightRailEtaClient implements EtaClient {
  LightRailEtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required String language,
  }) async {
    final String? stopId = route.stopIdAt(company, seq);
    if (stopId == null || stopId.isEmpty) return const [];
    final String stationId = stopId.startsWith('LR')
        ? stopId.substring(2)
        : stopId;

    final http.Response response = await _client
        .get(
          Uri.https(
            'rt.data.gov.hk',
            '/v1/transport/mtr/lrt/getSchedule',
            <String, String>{'station_id': stationId, 'with_special': '1'},
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return const [];
    final List<dynamic> platforms =
        (decoded['platform_list'] as List<dynamic>?) ?? const [];
    if (platforms.isEmpty) return const [];

    final bool ended = platforms.every((dynamic value) {
      if (value is! Map<String, dynamic>) return true;
      final Object? status = value['end_service_status'];
      return status == true || status == 1 || status?.toString() == '1';
    });
    if (ended) {
      return <BusEta>[
        BusEta(
          company: BusCompany.lightRail,
          eta: null,
          remarkZh: '此站今日服務已經終止',
          remarkEn: "This stop's service for today has ended",
          destZh: '',
          destEn: '',
          etaSeq: 1,
        ),
      ];
    }

    final String routeNumber = route.route.replaceAll('*', '').trim();
    final List<BusEta> result = <BusEta>[];
    for (final dynamic platformValue in platforms) {
      if (platformValue is! Map<String, dynamic>) continue;
      final String platform = (platformValue['platform_id'] ?? '').toString();
      final List<dynamic> routeList =
          (platformValue['route_list'] as List<dynamic>?) ?? const [];
      for (final dynamic value in routeList) {
        if (value is! Map<String, dynamic>) continue;
        final String routeNo = (value['route_no'] ?? '').toString().trim();
        final String additional = (value['additionalInfo1'] ?? '')
            .toString()
            .trim();
        final String destZh = (value['dest_ch'] ?? '').toString();
        final String destEn = (value['dest_en'] ?? '').toString();
        final bool routeMatches =
            routeNo == routeNumber || additional == routeNumber;
        final bool destMatches =
            destZh == route.dest.zh ||
            destEn.toLowerCase().contains('circular');
        final bool atStop = (value['stop'] ?? '').toString() == '0';
        if (!routeMatches || !destMatches || !atStop) continue;

        final int waitMinutes = _waitMinutes(value['time_en']?.toString());
        final int trainLength =
            int.tryParse((value['train_length'] ?? '').toString()) ?? 0;
        final String cars = List<String>.filled(trainLength, '▭').join();
        final String routeRemarkZh = (value['routeRemarkChi2'] ?? '')
            .toString()
            .trim();
        final String routeRemarkEn = (value['routeRemarkEng2'] ?? '')
            .toString()
            .trim();
        final String remarkZh = routeRemarkZh.isEmpty
            ? cars
            : '$cars - $routeRemarkZh';
        final String remarkEn = routeRemarkEn.isEmpty
            ? cars
            : '$cars - $routeRemarkEn';
        result.add(
          BusEta(
            company: BusCompany.lightRail,
            eta: DateTime.now().toUtc().add(Duration(minutes: waitMinutes)),
            remarkZh: remarkZh,
            remarkEn: remarkEn,
            destZh: destZh,
            destEn: destEn,
            etaSeq: result.length + 1,
            platform: platform,
          ),
        );
      }
    }
    result.sort((BusEta a, BusEta b) {
      return (a.eta ?? DateTime.now()).compareTo(b.eta ?? DateTime.now());
    });
    return result;
  }

  int _waitMinutes(String? time) {
    final String value = (time ?? '').trim().toLowerCase();
    if (value.isEmpty ||
        value == '-' ||
        value == 'arriving' ||
        value == 'departing') {
      return 0;
    }
    final RegExpMatch? match = RegExp(r'\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '') ?? 0;
  }
}
