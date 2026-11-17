import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/eta_display.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 14, 12);

  test('shows a dash when the ETA is earlier than now', () {
    expect(
      etaMinuteWaitLabel(
        now.subtract(const Duration(seconds: 30)),
        '分鐘',
        now: now,
      ),
      '- 分鐘',
    );
    expect(etaMinuteWaitLabel(now, '分鐘', now: now), '- 分鐘');
  });

  test('shows less than one minute only for a future ETA', () {
    expect(
      etaMinuteWaitLabel(now.add(const Duration(seconds: 30)), '分鐘', now: now),
      '<1 分鐘',
    );
    expect(
      etaMinuteWaitLabel(now.add(const Duration(seconds: 30)), '分', now: now),
      '<1 分',
    );
  });

  test('uses distance for the under-one-minute label', () {
    expect(etaUnderOneWaitLabel(true, '分鐘'), '<1 分鐘');
    expect(etaUnderOneWaitLabel(false, '分鐘'), '- 分鐘');
  });

  test('KMB proprietary ETA at 0.0 km counts as arrived', () {
    BusEta kmbEta(double? distanceKm) => BusEta(
      company: BusCompany.kmb,
      eta: now.add(const Duration(seconds: 30)),
      remarkZh: '',
      remarkEn: '',
      destZh: '',
      destEn: '',
      etaSeq: 1,
      distanceKm: distanceKm,
      kmbProprietary: true,
    );

    expect(etaArrivedAtStop(kmbEta(0.0)), isTrue);
    expect(etaArrivedAtStop(kmbEta(0.4)), isFalse);
    expect(etaArrivedAtStop(kmbEta(null)), isFalse);

    expect(kmbEta(0.0).distanceLabel('zh'), isNull);
    expect(kmbEta(0.0).distanceLabel('en'), isNull);
    expect(kmbEta(0.4).distanceLabel('zh'), '距離 0.4 公里');
    expect(kmbEta(0.4).distanceLabel('en'), '0.4 km away');
  });

  test('shows whole minutes for an ETA at least one minute away', () {
    expect(
      etaMinuteWaitLabel(now.add(const Duration(minutes: 1)), '分鐘', now: now),
      '1 分鐘',
    );
    expect(
      etaMinuteWaitLabel(
        now.add(const Duration(minutes: 1, seconds: 59)),
        '分鐘',
        now: now,
      ),
      '1 分鐘',
    );
    expect(
      etaMinuteWaitLabel(now.add(const Duration(minutes: 5)), '分鐘', now: now),
      '5 分鐘',
    );
  });
}
