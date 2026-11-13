import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/nlb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RouteEntry _route() {
  return RouteEntry(
    key: '1+1+Mui Wo+Tung Chung',
    slug: '1-nlb',
    route: '1',
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.nlb],
    orig: const Terminal(en: 'Mui Wo', zh: '梅窩'),
    dest: const Terminal(en: 'Tung Chung', zh: '東涌'),
    stops: const <BusCompany, List<String>>{
      BusCompany.nlb: <String>['1'],
    },
    bound: const <BusCompany, String>{BusCompany.nlb: 'O'},
    seq: 1,
    nlbId: '1',
  );
}

NlbEtaClient _client() {
  return NlbEtaClient(
    client: MockClient((http.Request request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'estimatedArrivals': <dynamic>[
              <String, dynamic>{
                'estimatedArrivalTime': '2026-11-13 22:40:00',
                'routeVariantName': '',
                'departed': 0,
                'noGPS': 0,
                'wheelChair': 1,
              },
              <String, dynamic>{
                'estimatedArrivalTime': '2026-11-13 22:55:00',
                'routeVariantName': '',
                'departed': 0,
                'noGPS': 0,
                'wheelChair': 0,
              },
              <String, dynamic>{
                'estimatedArrivalTime': '2026-11-13 23:10:00',
                'routeVariantName': '',
                'departed': 0,
                'noGPS': 0,
              },
            ],
          }),
        ),
        200,
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    }),
  );
}

void main() {
  test('reads open-data NLB wheelchair flags', () async {
    final List<BusEta> etas = await _client().fetch(
      route: _route(),
      company: BusCompany.nlb,
      seq: 0,
      language: 'zh',
      includeWheelchair: true,
    );

    expect(etas, hasLength(3));
    expect(etas[0].wheelchair, isTrue);
    expect(etas[0].wheelchairKnown, isTrue);
    expect(etas[1].wheelchair, isFalse);
    expect(etas[1].wheelchairKnown, isTrue);
    expect(etas[2].wheelchair, isFalse);
    expect(etas[2].wheelchairKnown, isFalse);
  });

  test('can suppress open-data NLB wheelchair flags', () async {
    final List<BusEta> etas = await _client().fetch(
      route: _route(),
      company: BusCompany.nlb,
      seq: 0,
      language: 'zh',
      includeWheelchair: false,
    );

    expect(etas, hasLength(3));
    for (final BusEta eta in etas) {
      expect(eta.wheelchair, isFalse);
      expect(eta.wheelchairKnown, isFalse);
    }
  });
}
