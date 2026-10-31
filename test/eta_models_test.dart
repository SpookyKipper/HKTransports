import 'package:flutter_test/flutter_test.dart';
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
}
