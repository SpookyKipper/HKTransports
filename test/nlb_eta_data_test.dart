import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/nlb_eta_data_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/nlb_eta_match.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

BusEta _eta(DateTime time, int seq) {
  return BusEta(
    company: BusCompany.nlb,
    eta: time,
    remarkZh: '',
    remarkEn: '',
    destZh: '',
    destEn: '',
    etaSeq: seq,
  );
}

void main() {
  test('parses wheelchair arrivals', () {
    final List<NlbEtaArrival> arrivals = parseNlbEtaArrivals(
      jsonEncode(<String, dynamic>{
        'data': <String, dynamic>{
          'arrivals': <dynamic>[
            <String, dynamic>{'minutes': 5, 'wheelchair': true},
            <String, dynamic>{'minutes': 40, 'wheelchair': false},
          ],
        },
      }),
    );

    expect(arrivals, hasLength(2));
    expect(arrivals[0].minutes, 5);
    expect(arrivals[0].wheelchair, isTrue);
    expect(arrivals[1].wheelchair, isFalse);
  });

  test('matches by minutes and discards extra proprietary arrivals', () {
    final DateTime now = DateTime.utc(2026, 11, 12, 8);
    final List<BusEta> etas = <BusEta>[
      _eta(now.add(const Duration(minutes: 5)), 1),
      _eta(now.add(const Duration(minutes: 40)), 2),
    ];
    final List<NlbEtaArrival> arrivals = <NlbEtaArrival>[
      const NlbEtaArrival(minutes: 5, wheelchair: true),
      const NlbEtaArrival(minutes: 40, wheelchair: false),
      const NlbEtaArrival(minutes: 55, wheelchair: true),
    ];

    final List<BusEta> result = applyNlbWheelchairData(
      etas,
      arrivals,
      now: now,
    );

    expect(result[0].wheelchair, isTrue);
    expect(result[1].wheelchair, isFalse);
  });

  test('does not override a known open-data wheelchair status', () {
    final DateTime now = DateTime.utc(2026, 11, 12, 8);
    final BusEta eta = BusEta(
      company: BusCompany.nlb,
      eta: now.add(const Duration(minutes: 5)),
      remarkZh: '',
      remarkEn: '',
      destZh: '',
      destEn: '',
      etaSeq: 1,
      wheelchair: false,
      wheelchairKnown: true,
    );

    final List<BusEta> result = applyNlbWheelchairData(
      <BusEta>[eta],
      <NlbEtaArrival>[const NlbEtaArrival(minutes: 5, wheelchair: true)],
      now: now,
    );

    expect(result.single.wheelchair, isFalse);
  });

  test('does not attach a clearly different arrival', () {
    final DateTime now = DateTime.utc(2026, 11, 12, 8);
    final List<BusEta> result = applyNlbWheelchairData(
      <BusEta>[_eta(now.add(const Duration(minutes: 5)), 1)],
      <NlbEtaArrival>[const NlbEtaArrival(minutes: 8, wheelchair: true)],
      now: now,
    );

    expect(result.single.wheelchair, isFalse);
  });

  test('uses the language-specific NLB ETA API', () async {
    late Uri requested;
    final NlbEtaDataClient client = NlbEtaDataClient(
      client: MockClient((http.Request request) async {
        requested = request.url;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'arrivals': <dynamic>[
                <String, dynamic>{'minutes': 5, 'wheelchair': true},
              ],
            },
          }),
          200,
        );
      }),
    );

    final List<NlbEtaArrival> arrivals = await client.fetch(
      route: '1',
      stationIndex: 7,
      language: 'en',
    );

    expect(arrivals, hasLength(1));
    expect(requested.path, '/api/route/1/eta/7');
    expect(requested.queryParameters['lang'], 'en');
  });
}
