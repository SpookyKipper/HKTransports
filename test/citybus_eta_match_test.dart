import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/citybus_eta_match.dart';
import 'package:hktransports/bus/eta/citybus_eta_status_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';

BusEta _eta(DateTime time, int seq, {BusCompany company = BusCompany.ctb}) {
  return BusEta(
    company: company,
    eta: time,
    remarkZh: '',
    remarkEn: '',
    destZh: '',
    destEn: '',
    etaSeq: seq,
  );
}

CitybusEtaStatus _status(
  String label, {
  int? timeMinutes,
  String? timeText,
  String? minutesText,
}) {
  return CitybusEtaStatus(
    statusZh: label,
    statusEn: label,
    timeMinutes: timeMinutes,
    timeText: timeText,
    minutesText: minutesText,
  );
}

void main() {
  final DateTime hkBase = DateTime.utc(2026, 1, 1, 2); // 10:00 HKT.

  test('matches by closest time and discards excess proprietary rows', () {
    final List<BusEta> etas = <BusEta>[
      _eta(hkBase.add(const Duration(minutes: 20)), 1),
      _eta(hkBase.add(const Duration(minutes: 40)), 2),
    ];
    final List<CitybusEtaStatus> statuses = <CitybusEtaStatus>[
      _status(
        'A',
        timeMinutes: 10 * 60 + 20,
        timeText: '10:20',
        minutesText: '3分鐘',
      ),
      _status('B', timeMinutes: 10 * 60 + 35),
      _status('C', timeMinutes: 11 * 60),
    ];

    final List<BusEta> result = applyCitybusStatusesByTime(etas, statuses);

    expect(result[0].status('zh'), 'A');
    expect(result[0].proprietaryTime, '10:20');
    expect(result[0].proprietaryMinutes, '3分鐘');
    expect(result[1].status('zh'), 'B');
    expect(result.any((BusEta eta) => eta.status('zh') == 'C'), isFalse);
  });

  test('does not assign the same status to two open-data ETAs', () {
    final List<BusEta> etas = <BusEta>[
      _eta(hkBase.add(const Duration(minutes: 20)), 1),
      _eta(hkBase.add(const Duration(minutes: 40)), 2),
    ];
    final List<CitybusEtaStatus> statuses = <CitybusEtaStatus>[
      _status('A', timeMinutes: 10 * 60 + 20),
      _status('B', timeMinutes: 10 * 60 + 21),
      _status('C', timeMinutes: 10 * 60 + 40),
    ];

    final List<BusEta> result = applyCitybusStatusesByTime(etas, statuses);

    expect(result[0].status('zh'), 'A');
    expect(result[1].status('zh'), 'C');
  });

  test('handles midnight wrapping', () {
    final DateTime hkMidnight = DateTime.utc(2026, 1, 1, 16); // 00:00 HKT.
    final List<BusEta> etas = <BusEta>[
      _eta(hkMidnight.add(const Duration(minutes: 5)), 1),
    ];
    final List<CitybusEtaStatus> statuses = <CitybusEtaStatus>[
      _status('A', timeMinutes: 23 * 60 + 59),
      _status('B', timeMinutes: 0 * 60 + 20),
    ];

    final List<BusEta> result = applyCitybusStatusesByTime(etas, statuses);
    expect(result.single.status('zh'), 'A');
  });

  test('leaves non-Citybus ETAs untouched', () {
    final BusEta kmb = _eta(
      hkBase.add(const Duration(minutes: 20)),
      1,
      company: BusCompany.kmb,
    );
    final List<BusEta> result = applyCitybusStatusesByTime(
      <BusEta>[kmb],
      <CitybusEtaStatus>[_status('A', timeMinutes: 10 * 60 + 20)],
    );

    expect(result.single.status('zh'), isNull);
  });

  test('falls back to order when nwp3 has no times', () {
    final List<BusEta> etas = <BusEta>[
      _eta(hkBase.add(const Duration(minutes: 20)), 1),
      _eta(hkBase.add(const Duration(minutes: 40)), 2),
    ];
    final List<CitybusEtaStatus> statuses = <CitybusEtaStatus>[
      _status('A'),
      _status('B'),
      _status('C'),
    ];

    final List<BusEta> result = applyCitybusStatusesByTime(etas, statuses);
    expect(result[0].status('zh'), 'A');
    expect(result[1].status('zh'), 'B');
  });
}
