import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/journey/journey_time_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<StopEntry> _stops() {
  return <StopEntry>[
    StopEntry(
      id: '20021481',
      nameEn: 'Start',
      displayEn: 'Start',
      nameZh: '起點',
      displayZh: '起點',
      lat: 22.32906,
      lng: 114.23354,
    ),
    StopEntry(
      id: '20021980',
      nameEn: 'End',
      displayEn: 'End',
      nameZh: '終點',
      displayZh: '終點',
      lat: 22.326,
      lng: 114.23364,
    ),
  ];
}

void main() {
  final DateTime mondayMorning = DateTime(2026, 11, 16, 8);

  test('reads the current hourly historical file', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path == '/times_hourly/1/08/20.json') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            '20021481': <String, dynamic>{'20021980': 126.4},
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    final JourneyTimeService service = JourneyTimeService(
      client: client,
      baseUrls: const <String>['https://example.test'],
    );
    final List<int>? seconds = await service.fetchSegmentSeconds(
      stops: _stops(),
      holidays: const <String>[],
      now: mondayMorning,
    );

    expect(seconds, <int>[126]);
  });

  test('falls back to the generic historical file', () async {
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path == '/times/20.json') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            '20021481': <String, dynamic>{'20021980': 98},
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    final JourneyTimeService service = JourneyTimeService(
      client: client,
      baseUrls: const <String>['https://example.test'],
    );
    final List<int>? seconds = await service.fetchSegmentSeconds(
      stops: _stops(),
      holidays: const <String>[],
      now: mondayMorning,
    );

    expect(seconds, <int>[98]);
  });

  test('returns null when a stop pair is missing', () async {
    final MockClient client = MockClient(
      (http.Request request) async => http.Response('{}', 200),
    );

    final JourneyTimeService service = JourneyTimeService(
      client: client,
      baseUrls: const <String>['https://example.test'],
    );
    final List<int>? seconds = await service.fetchSegmentSeconds(
      stops: _stops(),
      holidays: const <String>[],
      now: mondayMorning,
    );

    expect(seconds, isNull);
  });
}
