import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/journey/journey_time.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/journey_times.dart';

List<StopEntry> _stops(int count) {
  return List<StopEntry>.generate(count, (int index) {
    return StopEntry(
      id: 'stop-$index',
      nameEn: 'Stop $index',
      displayEn: 'Stop $index',
      nameZh: '站 $index',
      displayZh: '站 $index',
      lat: 22.3 + index * 0.004,
      lng: 114.2,
    );
  });
}

void main() {
  test('uses segment times with the HK Bus ETA margin', () {
    final List<StopEntry> stops = _stops(4);
    final JourneyEstimate estimate = estimateJourney(
      stops: stops,
      startSeq: 0,
      segmentSeconds: const <int>[60, 120, 180],
    );

    expect(estimate.cumulativeMinutes, <int>[0, 1, 3, 7]);
    expect(estimate.totalMinutes, 7);
    expect(estimate.estimated, isTrue);
  });

  test('estimates missing journey times from distance', () {
    final List<StopEntry> stops = _stops(19);
    final JourneyEstimate estimate = estimateJourney(stops: stops, startSeq: 0);

    expect(estimate.estimated, isTrue);
    expect(estimate.totalMinutes, greaterThan(20));
    expect(estimate.totalMinutes, lessThan(40));
    expect(
      estimate.totalMinutes,
      lessThan((stops.length - 1) * 4),
      reason: 'the old flat four-minutes-per-stop fallback was too large',
    );
    expect(estimate.cumulativeMinutes.last, estimate.totalMinutes);
  });

  test('ignores segment times with the wrong number of segments', () {
    final List<StopEntry> stops = _stops(4);
    final JourneyEstimate estimate = estimateJourney(
      stops: stops,
      startSeq: 0,
      segmentSeconds: const <int>[60],
    );

    expect(estimate.totalMinutes, lessThan(10));
    expect(estimate.totalMinutes, greaterThan(0));
  });

  test('treats travel time as seconds and applies the 10% margin', () {
    final List<StopEntry> stops = _stops(3);
    final JourneyEstimate estimate = estimateJourney(
      stops: stops,
      startSeq: 1,
      segmentSeconds: const <int>[100, 200],
    );

    expect(estimate.cumulativeMinutes, <int>[0, 4]);
    expect(estimate.totalMinutes, 4);
  });

  test('parses and selects journey time profiles', () {
    final RouteJourneyTimes times = RouteJourneyTimes.fromJson(
      <String, dynamic>{
        'weekdayPeak': <int>[60, 120],
        'weekdayOffPeak': <int>[50, 100],
        'weekend': <int>[40, 80],
      },
    );

    expect(
      times.segmentSecondsFor(DateTime(2026, 11, 16, 8), holiday: false),
      <int>[60, 120],
    );
    expect(
      times.segmentSecondsFor(DateTime(2026, 11, 16, 12), holiday: false),
      <int>[50, 100],
    );
    expect(
      times.segmentSecondsFor(DateTime(2026, 11, 21, 12), holiday: false),
      <int>[40, 80],
    );
    expect(
      times.segmentSecondsFor(DateTime(2026, 11, 16, 8), holiday: true),
      <int>[40, 80],
    );
  });
}
