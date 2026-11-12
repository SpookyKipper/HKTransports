import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/eta_display.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';

BusEta busEta(DateTime? time) {
  return BusEta(
    company: BusCompany.kmb,
    eta: time,
    remarkZh: '',
    remarkEn: '',
    destZh: '',
    destEn: '',
    etaSeq: 1,
  );
}

void main() {
  final DateTime now = DateTime.utc(2026, 10, 31, 12, 0, 0);

  test('an ETA becomes departed after 30 seconds', () {
    expect(
      busEta(now.subtract(const Duration(seconds: 29))).hasDepartedAt(now),
      isFalse,
    );
    expect(
      busEta(now.subtract(const Duration(seconds: 30))).hasDepartedAt(now),
      isTrue,
    );
    expect(
      busEta(now.subtract(const Duration(seconds: 31))).hasDepartedAt(now),
      isTrue,
    );
  });

  test('future ETAs and missing times are not departed', () {
    expect(
      busEta(now.add(const Duration(seconds: 1))).hasDepartedAt(now),
      isFalse,
    );
    expect(busEta(null).hasDepartedAt(now), isFalse);
  });

  test('the departed grace period can be overridden', () {
    final BusEta eta = busEta(now.subtract(const Duration(seconds: 10)));
    expect(eta.hasDepartedAt(now), isFalse);
    expect(eta.hasDepartedAt(now, grace: const Duration(seconds: 10)), isTrue);
  });

  test('proprietary status and distance are localised', () {
    final BusEta eta = busEta(
      now,
    ).copyWith(statusZh: '未開出', statusEn: 'Not yet departed', distanceKm: 1.2);

    expect(eta.status('zh'), '未開出');
    expect(eta.status('en'), 'Not yet departed');
    expect(eta.distanceLabel('zh'), '距離 1.2 公里');
    expect(eta.distanceLabel('en'), '1.2 km away');
    expect(eta.isScheduledLike, isTrue);
  });

  test('schedule icon is hidden for imminent and departed ETAs', () {
    BusEta scheduled(DateTime time) =>
        busEta(time).copyWith(statusZh: '未開出', statusEn: 'Not yet departed');

    expect(
      scheduled(
        now.add(const Duration(minutes: 5)),
      ).shouldShowScheduleIcon(now),
      isTrue,
    );
    expect(
      scheduled(
        now.add(const Duration(seconds: 30)),
      ).shouldShowScheduleIcon(now),
      isFalse,
    );
    expect(
      scheduled(
        now.subtract(const Duration(minutes: 1)),
      ).shouldShowScheduleIcon(now),
      isFalse,
    );
    expect(
      busEta(now.add(const Duration(minutes: 5))).shouldShowScheduleIcon(now),
      isFalse,
    );
  });

  test('live status does not change the base ETA animation key', () {
    final BusEta base = busEta(now);
    final BusEta enriched = base.copyWith(
      statusZh: '未開出',
      statusEn: 'Not yet departed',
      distanceKm: 1.2,
    );

    expect(etaDisplayKey(enriched), etaDisplayKey(base));
    expect(etaLiveStatusKey(enriched), isNot(etaLiveStatusKey(base)));
  });
}
