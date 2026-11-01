import 'dart:convert';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;

class LrtFeederEtaClient implements EtaClient {
  LrtFeederEtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, _ScheduleCache> _cache = {};

  @override
  Future<List<BusEta>> fetch({
    required RouteEntry route,
    required BusCompany company,
    required int seq,
    required String language,
  }) async {
    final String? stopId = route.stopIdAt(company, seq);
    if (stopId == null || stopId.isEmpty) return const [];

    final _ScheduleCache? cached = _cache[route.route];
    final DateTime now = DateTime.now();
    Map<String, dynamic>? decoded;
    if (cached != null &&
        now.difference(cached.fetchedAt) < const Duration(seconds: 30)) {
      decoded = cached.data;
    } else {
      final http.Response response = await _client
          .post(
            Uri.parse(
              'https://rt.data.gov.hk/v1/transport/mtr/bus/getSchedule',
            ),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'language': language, 'routeName': route.route}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];
      final dynamic value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) return const [];
      decoded = value;
      _cache[route.route] = _ScheduleCache(data: value, fetchedAt: now);
    }

    final List<dynamic> busStops =
        (decoded['busStop'] as List<dynamic>?) ?? const [];
    final List<BusEta> result = [];
    for (final dynamic busStop in busStops) {
      if (busStop is! Map<String, dynamic>) continue;
      if (busStop['busStopId']?.toString() != stopId) continue;
      final String busStopRemark = (busStop['busStopRemark'] ?? '').toString();
      final List<dynamic> buses =
          (busStop['bus'] as List<dynamic>?) ?? const [];
      for (final dynamic bus in buses) {
        if (bus is! Map<String, dynamic>) continue;
        String secondsText = (bus['arrivalTimeInSecond'] ?? '').toString();
        if (secondsText == '108000') {
          secondsText = (bus['departureTimeInSecond'] ?? '').toString();
        }
        final int? seconds = int.tryParse(secondsText);
        if (seconds == null) continue;
        final String remark = busStopRemark.isNotEmpty
            ? busStopRemark
            : (bus['busRemark'] ?? '').toString();
        final bool scheduled = bus['isScheduled']?.toString() == '1';
        result.add(
          BusEta(
            company: BusCompany.lrtfeeder,
            eta: DateTime.now().toUtc().add(Duration(seconds: seconds)),
            remarkZh: remark.isNotEmpty ? remark : (scheduled ? '預定班次' : ''),
            remarkEn: remark.isNotEmpty
                ? remark
                : (scheduled ? 'Scheduled' : ''),
            destZh: '',
            destEn: '',
            etaSeq: result.length + 1,
            scheduled: scheduled,
          ),
        );
      }
    }
    return result;
  }
}

class _ScheduleCache {
  const _ScheduleCache({required this.data, required this.fetchedAt});

  final Map<String, dynamic> data;
  final DateTime fetchedAt;
}
