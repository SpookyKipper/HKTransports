import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/journey/journey_time.dart';
import 'package:hktransports/bus/model/bus_models.dart';

RouteEntry _route({String? jt, int stopCount = 19}) {
  final List<StopEntry> stops = _stops(stopCount);
  return RouteEntry(
    key: '117A+1',
    slug: '117a',
    route: '117A',
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.gmb],
    orig: const Terminal(en: 'Anderson', zh: '安達臣'),
    dest: const Terminal(en: 'Sheung Tak', zh: '尚德'),
    stops: <BusCompany, List<String>>{
      BusCompany.gmb: stops.map((StopEntry stop) => stop.id).toList(),
    },
    bound: const <BusCompany, String>{BusCompany.gmb: 'O'},
    seq: 0,
    jt: jt,
  );
}

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
  test('uses an official journey time when present', () {
    final List<StopEntry> stops = _stops(19);
    final JourneyEstimate estimate = estimateJourney(
      route: _route(jt: '42', stopCount: stops.length),
      stops: stops,
      startSeq: 0,
    );

    expect(estimate.estimated, isFalse);
    expect(estimate.totalMinutes, 42);
    expect(estimate.cumulativeMinutes.last, 42);
  });

  test(
    'estimates missing journey times from distance, not stop count alone',
    () {
      final List<StopEntry> stops = _stops(19);
      final JourneyEstimate estimate = estimateJourney(
        route: _route(stopCount: stops.length),
        stops: stops,
        startSeq: 0,
      );

      expect(estimate.estimated, isTrue);
      expect(estimate.totalMinutes, greaterThan(20));
      expect(estimate.totalMinutes, lessThan(40));
      expect(
        estimate.totalMinutes,
        lessThan((stops.length - 1) * 4),
        reason: 'the old flat four-minutes-per-stop fallback was too large',
      );
      expect(estimate.cumulativeMinutes.last, estimate.totalMinutes);
    },
  );

  test('treats an invalid official journey time as missing', () {
    final List<StopEntry> stops = _stops(19);
    final JourneyEstimate estimate = estimateJourney(
      route: _route(jt: '0', stopCount: stops.length),
      stops: stops,
      startSeq: 0,
    );

    expect(estimate.estimated, isTrue);
    expect(estimate.totalMinutes, greaterThan(0));
  });
}
