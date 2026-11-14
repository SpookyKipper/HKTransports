import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/upstream_eta_scan.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 14, 12);

  UpstreamEtaSample sample(int stopIndex, int minutes) {
    return UpstreamEtaSample(
      stopIndex: stopIndex,
      eta: now.add(Duration(minutes: minutes)),
    );
  }

  test('finds the stop before an upstream ETA jump', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: false,
      currentEta: now.add(const Duration(minutes: 20)),
      upstream: <UpstreamEtaSample>[
        sample(7, 18),
        sample(6, 15),
        sample(5, 1),
        sample(4, 20),
      ],
      now: now,
      scheduled: true,
    );

    expect(notice, isNotNull);
    expect(notice!.scheduled, isTrue);
    expect(notice.stopIndex, 5);
    expect(notice.currentIndex, 8);
    expect(notice.remainingStops, 3);
  });

  test('returns null when the upstream ETAs are monotonic', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: false,
      currentEta: now.add(const Duration(minutes: 20)),
      upstream: <UpstreamEtaSample>[
        sample(7, 16),
        sample(6, 12),
        sample(5, 8),
        sample(4, 3),
      ],
      now: now,
      scheduled: false,
    );

    expect(notice, isNull);
  });

  test('stops when an upstream stop has no live ETA', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: false,
      currentEta: now.add(const Duration(minutes: 20)),
      upstream: <UpstreamEtaSample>[
        sample(7, 15),
        const UpstreamEtaSample(stopIndex: 6, eta: null),
        sample(5, 1),
        sample(4, 20),
      ],
      now: now,
      scheduled: false,
    );

    expect(notice, isNull);
  });

  test('returns null when the current stop has no ETA', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: false,
      currentEta: null,
      upstream: <UpstreamEtaSample>[
        sample(7, 15),
        sample(6, 10),
        sample(5, 1),
        sample(4, 20),
      ],
      now: now,
      scheduled: false,
    );

    expect(notice, isNull);
  });

  test('detects a one-minute increase from N-1 to N', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: false,
      currentEta: now.add(const Duration(minutes: 5)),
      upstream: <UpstreamEtaSample>[sample(7, 6)],
      now: now,
      scheduled: false,
    );

    expect(notice, isNotNull);
    expect(notice!.stopIndex, 8);
    expect(notice.remainingStops, 0);
  });

  test('moves the notice to the next stop when the edge stop has arrived', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 7,
      currentEta: now.add(const Duration(minutes: 10)),
      currentArrived: false,
      upstream: <UpstreamEtaSample>[
        sample(6, 4),
        sample(5, 2),
        sample(4, 0),
        sample(3, 20),
      ],
      now: now,
      scheduled: false,
    );

    expect(notice, isNotNull);
    expect(notice!.stopIndex, 5);
    expect(notice.remainingStops, 2);
  });

  test('shifts when the edge stop is under one minute away', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 7,
      currentEta: now.add(const Duration(minutes: 10)),
      currentArrived: false,
      upstream: <UpstreamEtaSample>[
        sample(6, 4),
        sample(5, 2),
        UpstreamEtaSample(
          stopIndex: 4,
          eta: now.add(const Duration(seconds: 30)),
        ),
        sample(3, 20),
      ],
      now: now,
      scheduled: false,
    );

    expect(notice, isNotNull);
    expect(notice!.stopIndex, 5);
    expect(notice.remainingStops, 2);
  });

  test('uses the current stop when N-1 is later than N', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: false,
      currentEta: now.add(const Duration(minutes: 5)),
      upstream: <UpstreamEtaSample>[sample(7, 20)],
      now: now,
      scheduled: false,
    );

    expect(notice, isNotNull);
    expect(notice!.stopIndex, 8);
    expect(notice.remainingStops, 0);
  });

  test('hides the current stop when it has already arrived', () {
    final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
      currentIndex: 8,
      currentArrived: true,
      currentEta: now,
      upstream: <UpstreamEtaSample>[sample(7, 20)],
      now: now,
      scheduled: false,
    );

    expect(notice, isNull);
  });
}
