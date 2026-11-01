import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/ctb_eta_client.dart';
import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object data) {
  return http.Response(
    jsonEncode(data),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

RouteEntry route({
  String routeNumber = '690',
  List<BusCompany> companies = const [BusCompany.kmb, BusCompany.ctb],
  Map<BusCompany, List<String>>? stops,
  Map<BusCompany, String>? bound,
}) {
  return RouteEntry(
    key: '690+1+CENTRAL+HONG SING GARDEN',
    slug: '690-1-CENTRAL-HONG-SING-GARDEN',
    route: routeNumber,
    serviceType: '1',
    companies: companies,
    orig: const Terminal(en: 'CENTRAL', zh: '中環'),
    dest: const Terminal(en: 'HONG SING GARDEN', zh: '康盛花園'),
    stops:
        stops ??
        const {
          BusCompany.kmb: ['K1', 'K2', 'K3'],
          BusCompany.ctb: ['C1', 'C2', 'C3'],
        },
    bound: bound ?? const {BusCompany.kmb: 'I', BusCompany.ctb: 'O'},
    seq: 3,
  );
}

Map<String, dynamic> eta({
  required String company,
  required String dir,
  required int seq,
  required String time,
  int serviceType = 1,
  int etaSeq = 1,
}) {
  return {
    'co': company,
    'route': '690',
    'dir': dir,
    'service_type': serviceType,
    'seq': seq,
    'dest_tc': '康盛花園',
    'dest_en': 'HONG SING GARDEN',
    'eta_seq': etaSeq,
    'eta': time,
    'rmk_tc': '',
    'rmk_en': '',
  };
}

void main() {
  test('KMB keeps the nearest sequence group', () async {
    final http.Client client = MockClient((request) async {
      expect(request.url.host, 'data.etabus.gov.hk');
      return jsonResponse({
        'data': [
          eta(
            company: 'KMB',
            dir: 'I',
            seq: 1,
            time: '2026-10-29T22:10:00+08:00',
          ),
          eta(
            company: 'KMB',
            dir: 'I',
            seq: 2,
            time: '2026-10-29T22:12:00+08:00',
          ),
          eta(
            company: 'KMB',
            dir: 'O',
            seq: 2,
            time: '2026-10-29T22:15:00+08:00',
          ),
        ],
      });
    });
    final KmbEtaClient kmb = KmbEtaClient(client: client);
    final List<BusEta> result = await kmb.fetch(
      route: route(),
      company: BusCompany.kmb,
      seq: 1,
      language: 'zh',
    );
    expect(result.length, 1);
    expect(result.first.etaSeq, 1);
    expect(result.first.company, BusCompany.kmb);
  });

  test('KMB filters the other direction', () async {
    final http.Client client = MockClient((request) async {
      return jsonResponse({
        'data': [
          eta(
            company: 'KMB',
            dir: 'O',
            seq: 2,
            time: '2026-10-29T22:15:00+08:00',
          ),
        ],
      });
    });
    final KmbEtaClient kmb = KmbEtaClient(client: client);
    final List<BusEta> result = await kmb.fetch(
      route: route(),
      company: BusCompany.kmb,
      seq: 1,
      language: 'zh',
    );
    expect(result, isEmpty);
  });

  test('Citybus accepts both directions for OI bounds', () async {
    final http.Client client = MockClient((request) async {
      return jsonResponse({
        'data': [
          eta(
            company: 'CTB',
            dir: 'O',
            seq: 2,
            time: '2026-10-29T22:15:00+08:00',
          ),
          eta(
            company: 'CTB',
            dir: 'I',
            seq: 2,
            time: '2026-10-29T22:20:00+08:00',
          ),
        ],
      });
    });
    final CtbEtaClient ctb = CtbEtaClient(client: client);
    final List<BusEta> result = await ctb.fetch(
      route: route(
        companies: const [BusCompany.ctb],
        stops: const {
          BusCompany.ctb: ['C1', 'C2', 'C3'],
        },
        bound: const {BusCompany.ctb: 'OI'},
      ),
      company: BusCompany.ctb,
      seq: 1,
      language: 'zh',
    );
    expect(result.length, 2);
  });

  test('Citybus keeps the KMB cycle placeholder as a null ETA', () async {
    final http.Client client = MockClient((request) async {
      return jsonResponse({
        'data': [
          eta(
            company: 'CTB',
            dir: 'O',
            seq: 2,
            time: '2026-10-29T22:15:00+08:00',
          ),
          {
            ...eta(company: 'CTB', dir: 'O', seq: 2, time: ''),
            'rmk_en': 'KMB Cycle',
            'rmk_tc': '九巴時段',
          },
        ],
      });
    });
    final CtbEtaClient ctb = CtbEtaClient(client: client);
    final List<BusEta> result = await ctb.fetch(
      route: route(),
      company: BusCompany.ctb,
      seq: 1,
      language: 'zh',
    );
    expect(result.length, 2);
    expect(result.where((eta) => eta.eta == null).length, 1);
  });

  test('parses NLB style timestamps', () {
    expect(
      parseEtaTime('2026-10-29 22:05:00')?.toUtc(),
      DateTime.utc(2026, 10, 29, 14, 5),
    );
  });
}
