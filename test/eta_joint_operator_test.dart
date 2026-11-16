import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

RouteEntry _route(List<BusCompany> companies) {
  return RouteEntry(
    key: 'joint',
    slug: 'joint',
    route: '1',
    serviceType: '1',
    companies: companies,
    orig: const Terminal(en: 'A', zh: '甲'),
    dest: const Terminal(en: 'B', zh: '乙'),
    stops: const <BusCompany, List<String>>{},
    bound: const <BusCompany, String>{},
    seq: 1,
  );
}

BusEta _eta(
  BusCompany company, {
  String? statusZh,
  String? statusEn,
  DateTime? time,
  bool proprietary = false,
  double? distanceKm,
}) {
  return BusEta(
    company: company,
    eta: time ?? DateTime.utc(2026, 11, 16, 12),
    remarkZh: '',
    remarkEn: '',
    destZh: '乙',
    destEn: 'B',
    etaSeq: 1,
    statusZh: statusZh,
    statusEn: statusEn,
    proprietaryTime: proprietary ? '12:00' : null,
    distanceKm: distanceKm,
  );
}

void main() {
  test('removes Citybus KMB/LWB rows on joint routes', () {
    final List<BusEta> result = filterJointOperatorEtas(
      _route(const <BusCompany>[BusCompany.ctb, BusCompany.kmb]),
      <BusEta>[
        _eta(BusCompany.ctb, statusZh: '九巴'),
        _eta(BusCompany.ctb, statusEn: 'KMB'),
        _eta(BusCompany.ctb, statusZh: '龍運'),
        _eta(BusCompany.ctb, statusEn: 'LWB'),
        _eta(BusCompany.ctb, statusEn: 'En route'),
        _eta(BusCompany.kmb),
      ],
    );

    expect(result, hasLength(2));
    expect(result[0].statusEn, 'En route');
    expect(result[1].company, BusCompany.kmb);
  });

  test('removes a Citybus LWB duplicate within the time window', () {
    final List<BusEta> result = filterJointOperatorEtas(
      _route(const <BusCompany>[BusCompany.ctb, BusCompany.kmb]),
      <BusEta>[
        _eta(BusCompany.kmb, time: DateTime.utc(2026, 11, 16, 12, 0, 30)),
        _eta(
          BusCompany.ctb,
          time: DateTime.utc(2026, 11, 16, 12, 1),
          statusZh: '預定班次',
          proprietary: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.company, BusCompany.kmb);
  });

  test('keeps Citybus rows outside the duplicate time window', () {
    final List<BusEta> result = filterJointOperatorEtas(
      _route(const <BusCompany>[BusCompany.ctb, BusCompany.kmb]),
      <BusEta>[
        _eta(BusCompany.kmb, time: DateTime.utc(2026, 11, 16, 12)),
        _eta(
          BusCompany.ctb,
          time: DateTime.utc(2026, 11, 16, 12, 2),
          statusZh: '預定班次',
          proprietary: true,
        ),
      ],
    );

    expect(result, hasLength(2));
  });

  test('keeps a live Citybus vehicle near a KMB departure', () {
    final List<BusEta> result = filterJointOperatorEtas(
      _route(const <BusCompany>[BusCompany.ctb, BusCompany.kmb]),
      <BusEta>[
        _eta(BusCompany.kmb, time: DateTime.utc(2026, 11, 16, 12)),
        _eta(
          BusCompany.ctb,
          time: DateTime.utc(2026, 11, 16, 12, 1),
          distanceKm: 1.2,
          proprietary: true,
        ),
      ],
    );

    expect(result, hasLength(2));
  });

  test('keeps open-data Citybus rows near a KMB departure', () {
    final List<BusEta> result = filterJointOperatorEtas(
      _route(const <BusCompany>[BusCompany.ctb, BusCompany.kmb]),
      <BusEta>[
        _eta(BusCompany.kmb, time: DateTime.utc(2026, 11, 16, 12)),
        _eta(BusCompany.ctb, time: DateTime.utc(2026, 11, 16, 12, 1)),
      ],
    );

    expect(result, hasLength(2));
  });

  test('keeps rows on routes without KMB', () {
    final List<BusEta> result = filterJointOperatorEtas(
      _route(const <BusCompany>[BusCompany.ctb]),
      <BusEta>[_eta(BusCompany.ctb, statusEn: 'KMB')],
    );

    expect(result, hasLength(1));
  });
}
