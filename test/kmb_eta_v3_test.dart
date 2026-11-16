import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/kmb_eta_v3_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _testSeed = '000102030405060708090A0B0C0D0E0F';

RouteEntry _route({int stops = 3}) {
  return RouteEntry(
    key: '690+1+CENTRAL+HONG SING GARDEN',
    slug: '690-1-CENTRAL-HONG-SING-GARDEN',
    route: '690',
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.kmb],
    orig: const Terminal(en: 'CENTRAL', zh: '中環'),
    dest: const Terminal(en: 'HONG SING GARDEN', zh: '康盛花園'),
    stops: <BusCompany, List<String>>{
      BusCompany.kmb: <String>[
        for (int index = 0; index < stops; index++) 'STOP$index',
      ],
    },
    bound: const <BusCompany, String>{BusCompany.kmb: 'O'},
    seq: 1,
  );
}

http.Response _json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

KmbEtaV3Client _client(MockClient mock) {
  return KmbEtaV3Client(
    client: mock,
    seedHex: _testSeed,
    now: () => DateTime.utc(2026, 11, 16, 14, 0, 0),
    randomBytes: () => Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6]),
  );
}

void main() {
  test('parses live rows and maps the circular terminal sequence', () async {
    final MockClient mock = MockClient((http.Request request) async {
      expect(request.method, 'POST');
      expect(request.url.host, 'etav3.kmb.hk');
      expect(request.url.queryParameters['action'], 'geteta');
      expect(request.body, contains('"d"'));
      expect(request.body, contains('"ctr"'));
      return _json(<Object>[
        <String, Object>{
          'routeNo': '690',
          'bound': 1,
          'service_type': 1,
          'seq': 0,
          'responsecode': 0,
          'eta': <Object>[
            <String, Object>{
              't': '22:25 ☘',
              'ex': '2026-11-16 22:25:57',
              'dis': 5547,
              'w': 'Y',
            },
            <String, dynamic>{
              't': '22:47 預定班次☘',
              'ex': '2026-11-16 22:47:00',
              'dis': null,
              'w': 'Y',
            },
          ],
        },
        <String, Object>{
          'routeNo': '690',
          'bound': 1,
          'service_type': 1,
          'seq': 1,
          'responsecode': 0,
          'eta': <Object>[
            <String, Object>{
              't': '22:29 九巴',
              'ex': '2026-11-16 22:29:57',
              'dis': 2984,
            },
          ],
        },
        <String, Object>{
          'routeNo': '690',
          'bound': 1,
          'service_type': 1,
          'seq': 999,
          'responsecode': 0,
          'eta': <Object>[
            <String, Object>{
              't': '22:52 尾班車 九巴☘',
              'ex': '2026-11-16 22:52:59',
              'dis': 14941,
            },
          ],
        },
      ]);
    });

    final Map<int, List<BusEta>>? result = await _client(
      mock,
    ).fetchRouteEtas(_route(), language: 'zh');

    expect(result, isNotNull);
    expect(result!.keys.toSet(), <int>{0, 1, 2});
    expect(result[0], hasLength(2));
    expect(result[0]!.first.distanceKm, closeTo(5.547, 0.0001));
    expect(result[0]!.first.liveTracked, isTrue);
    expect(result[0]!.first.wheelchair, isFalse);
    expect(result[0]!.last.scheduled, isTrue);
    expect(result[1]!.single.remarkZh, isEmpty);
    expect(result[2]!.single.remarkZh, contains('尾班車'));
    expect(result[2]!.single.liveTracked, isTrue);
  });

  test('splits larger routes into batches of at most 32', () async {
    int calls = 0;
    final MockClient mock = MockClient((http.Request request) async {
      calls++;
      return _json(<Object>[
        <String, Object>{
          'routeNo': '690',
          'bound': 1,
          'service_type': 1,
          'seq': 0,
          'responsecode': 0,
          'eta': <Object>[
            <String, Object>{
              't': '22:25',
              'ex': '2026-11-16 22:25:57',
              'dis': 100,
            },
          ],
        },
      ]);
    });

    final Map<int, List<BusEta>>? result = await _client(
      mock,
    ).fetchRouteEtas(_route(stops: 33), language: 'zh');

    expect(result, isNotNull);
    expect(calls, 2);
  });

  test('retries a 403 once with a fresh request', () async {
    int calls = 0;
    final MockClient mock = MockClient((http.Request request) async {
      calls++;
      if (calls == 1) {
        return _json(<String, Object>{'error': 'api key expired'}, 403);
      }
      return _json(<Object>[
        <String, Object>{
          'routeNo': '690',
          'bound': 1,
          'service_type': 1,
          'seq': 0,
          'responsecode': 0,
          'eta': <Object>[
            <String, Object>{
              't': '22:25',
              'ex': '2026-11-16 22:25:57',
              'dis': 100,
            },
          ],
        },
      ]);
    });

    final Map<int, List<BusEta>>? result = await _client(
      mock,
    ).fetchRouteEtas(_route(stops: 1), language: 'zh');

    expect(calls, 2);
    expect(result, isNotNull);
    expect(result![0], hasLength(1));
  });

  test('does not call the endpoint without a valid seed', () async {
    int calls = 0;
    final MockClient mock = MockClient((http.Request request) async {
      calls++;
      return _json(<Object>[]);
    });
    final KmbEtaV3Client client = KmbEtaV3Client(
      client: mock,
      seedHex: 'not-a-seed',
    );

    expect(client.isConfigured, isFalse);
    expect(await client.fetchRouteEtas(_route(), language: 'zh'), isNull);
    expect(calls, 0);
  });
}
