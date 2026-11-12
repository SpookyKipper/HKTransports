import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/lightrail_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RouteEntry _route() {
  return RouteEntry(
    key: '505+1+Sam Shing+Siu Hong',
    slug: '505-test',
    route: '505',
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.lightRail],
    orig: const Terminal(en: 'Sam Shing', zh: '三聖'),
    dest: const Terminal(en: 'Siu Hong', zh: '兆康'),
    stops: const <BusCompany, List<String>>{
      BusCompany.lightRail: <String>['LR920', 'LR265', 'LR100'],
    },
    bound: const <BusCompany, String>{BusCompany.lightRail: 'O'},
    seq: 3,
  );
}

void main() {
  test(
    'filters Light Rail route and exposes platform and car length',
    () async {
      final LightRailEtaClient client = LightRailEtaClient(
        client: MockClient((http.Request request) async {
          expect(request.url.queryParameters['station_id'], '920');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'platform_list': <dynamic>[
                  <String, dynamic>{
                    'platform_id': 1,
                    'end_service_status': false,
                    'route_list': <dynamic>[
                      <String, dynamic>{
                        'route_no': '505',
                        'additionalInfo1': '',
                        'dest_ch': '兆康',
                        'dest_en': 'Siu Hong',
                        'time_en': '2 mins',
                        'train_length': 2,
                        'routeRemarkChi2': '',
                        'routeRemarkEng2': '',
                        'stop': 0,
                      },
                      <String, dynamic>{
                        'route_no': '615',
                        'additionalInfo1': '',
                        'dest_ch': '兆康',
                        'dest_en': 'Siu Hong',
                        'time_en': '5 mins',
                        'train_length': 1,
                        'routeRemarkChi2': '',
                        'routeRemarkEng2': '',
                        'stop': 0,
                      },
                    ],
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

      final List<BusEta> etas = await client.fetch(
        route: _route(),
        company: BusCompany.lightRail,
        seq: 0,
        language: 'en',
      );

      expect(etas, hasLength(1));
      expect(etas.single.platform, '1');
      expect(etas.single.remarkZh, '▭▭');
      expect(etas.single.eta, isNotNull);
    },
  );

  test('returns the end-of-service message', () async {
    final LightRailEtaClient client = LightRailEtaClient(
      client: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'platform_list': <dynamic>[
              <String, dynamic>{
                'platform_id': 1,
                'end_service_status': true,
                'route_list': <dynamic>[],
              },
            ],
          }),
          200,
        );
      }),
    );

    final List<BusEta> etas = await client.fetch(
      route: _route(),
      company: BusCompany.lightRail,
      seq: 0,
      language: 'en',
    );

    expect(etas, hasLength(1));
    expect(etas.single.eta, isNull);
  });
}
