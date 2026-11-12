import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/mtr_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RouteEntry _route({
  String route = 'TKL',
  required String bound,
  required List<String> stops,
}) {
  return RouteEntry(
    key: '$route+1+test',
    slug: '$route-test',
    route: route,
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.mtr],
    orig: const Terminal(en: 'Tiu Keng Leng', zh: '調景嶺'),
    dest: const Terminal(en: 'LOHAS Park', zh: '康城'),
    stops: <BusCompany, List<String>>{BusCompany.mtr: stops},
    bound: <BusCompany, String>{BusCompany.mtr: bound},
    seq: stops.length,
  );
}

void main() {
  test(
    'maps MTR direction, filters branch destinations, and keeps platform',
    () async {
      final MtrEtaClient client = MtrEtaClient(
        client: MockClient((http.Request request) async {
          expect(request.url.queryParameters['line'], 'TKL');
          expect(request.url.queryParameters['sta'], 'TIK');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 1,
              'data': <String, dynamic>{
                'TKL-TIK': <String, dynamic>{
                  'UP': <dynamic>[
                    <String, dynamic>{
                      'dest': 'LHP',
                      'plat': '3',
                      'time': '2026-11-12 16:38:56',
                    },
                    <String, dynamic>{
                      'dest': 'POA',
                      'plat': '3',
                      'time': '2026-11-12 16:40:56',
                    },
                  ],
                  'DOWN': <dynamic>[
                    <String, dynamic>{
                      'dest': 'NOP',
                      'plat': '4',
                      'time': '2026-11-12 16:37:56',
                    },
                  ],
                },
              },
            }),
            200,
          );
        }),
      );

      final List<BusEta> etas = await client.fetch(
        route: _route(bound: 'TKS-UT', stops: <String>['TIK', 'TKO', 'LHP']),
        company: BusCompany.mtr,
        seq: 0,
        language: 'en',
      );

      expect(etas, hasLength(1));
      expect(etas.single.destEn, 'LHP');
      expect(etas.single.platform, '3');
      expect(etas.single.eta, isNotNull);
    },
  );

  test(
    'returns the MTR service message when the API reports no service',
    () async {
      final MtrEtaClient client = MtrEtaClient(
        client: MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': 0,
              'message': 'Service ended',
            }),
            200,
          );
        }),
      );

      final List<BusEta> etas = await client.fetch(
        route: _route(bound: 'UT', stops: <String>['TIK', 'TKO', 'LHP']),
        company: BusCompany.mtr,
        seq: 0,
        language: 'en',
      );

      expect(etas, hasLength(1));
      expect(etas.single.eta, isNull);
      expect(etas.single.remarkEn, 'Service ended');
    },
  );
}
