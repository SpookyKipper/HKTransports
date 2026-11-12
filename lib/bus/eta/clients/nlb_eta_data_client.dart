import 'dart:convert';

import 'package:hktransports/bus/nlb/nlb_http.dart';
import 'package:http/http.dart' as http;

class NlbEtaArrival {
  const NlbEtaArrival({required this.minutes, required this.wheelchair});

  final int minutes;
  final bool wheelchair;
}

class NlbEtaDataClient {
  NlbEtaDataClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<List<NlbEtaArrival>> fetch({
    required String route,
    required int stationIndex,
    required String language,
  }) async {
    final Uri uri = Uri.https(
      'www.nlb.com.hk',
      '/api/route/$route/eta/$stationIndex',
      <String, String>{'lang': language == 'en' ? 'en' : 'tc'},
    );
    final String? body;
    try {
      final http.Client? injected = _client;
      if (injected != null) {
        final http.Response response = await injected
            .get(uri)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return const [];
        body = utf8.decode(response.bodyBytes, allowMalformed: true);
      } else {
        body = await NlbHttp.get(
          uri,
          headers: <String, String>{
            'Accept': 'application/json',
            'Accept-Language': language == 'en' ? 'en' : 'zh-Hant-HK',
          },
        );
      }
    } catch (_) {
      return const [];
    }
    if (body == null) return const [];
    return parseNlbEtaArrivals(body);
  }
}

List<NlbEtaArrival> parseNlbEtaArrivals(String body) {
  final Object? decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
  if (data == null) return const [];
  final List<dynamic> arrivals =
      (data['arrivals'] as List<dynamic>?) ?? const [];
  final List<NlbEtaArrival> result = <NlbEtaArrival>[];
  for (final dynamic value in arrivals) {
    if (value is! Map<String, dynamic>) continue;
    final int? minutes = (value['minutes'] as num?)?.toInt();
    if (minutes == null) continue;
    result.add(
      NlbEtaArrival(minutes: minutes, wheelchair: value['wheelchair'] == true),
    );
  }
  return result;
}
