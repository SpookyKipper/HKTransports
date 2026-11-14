import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/eta_display.dart';

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
