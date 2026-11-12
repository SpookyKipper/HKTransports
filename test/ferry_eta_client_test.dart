import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/ferry_eta_client.dart';
import 'package:hktransports/bus/model/bus_models.dart';

RouteEntry _routeWithFreq(Map<String, Map<String, List<String>?>> freq) {
  return RouteEntry(
    key: 'CCCE+1+CHEUNG CHAU+CENTRAL',
    slug: 'ccce-test',
    route: 'CCCE',
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.sunferry],
    orig: const Terminal(en: 'Cheung Chau', zh: '長洲'),
    dest: const Terminal(en: 'Central', zh: '中環'),
    stops: const <BusCompany, List<String>>{
      BusCompany.sunferry: <String>['101101', '101102'],
    },
    bound: const <BusCompany, String>{BusCompany.sunferry: 'O'},
    seq: 2,
    freq: freq,
  );
}

BusDatabase _database({List<bool>? days}) {
  return BusDatabase(
    routesByKey: const <String, RouteEntry>{},
    routesBySlug: const <String, RouteEntry>{},
    routesByNumber: const <String, List<RouteEntry>>{},
    stops: const <String, StopEntry>{},
    stopMap: const <String, List<StopRef>>{},
    holidays: const <String>[],
    serviceDayMap: <String, List<bool>>{
      '1': days ?? const <bool>[true, true, true, true, true, true, true],
    },
  );
}

void main() {
  test('computes upcoming ferry departures from the timetable', () {
    final RouteEntry route = _routeWithFreq(
      <String, Map<String, List<String>?>>{
        '1': <String, List<String>?>{'1000': null, '1100': null, '1500': null},
      },
    );

    final List<DateTime> times = upcomingFerryDepartures(
      route: route,
      database: _database(),
      now: DateTime.utc(2026, 11, 12, 1), // 09:00 HKT.
    );

    expect(times, hasLength(2));
    expect(times[0], DateTime.utc(2026, 11, 12, 2));
    expect(times[1], DateTime.utc(2026, 11, 12, 3));
  });

  test('skips a service not running on the current day', () {
    final RouteEntry route = _routeWithFreq(
      <String, Map<String, List<String>?>>{
        '1': <String, List<String>?>{'1000': null},
      },
    );

    final List<DateTime> times = upcomingFerryDepartures(
      route: route,
      database: _database(
        days: const <bool>[false, false, false, false, false, false, false],
      ),
      now: DateTime.utc(2026, 11, 12, 1),
    );

    expect(times, isEmpty);
  });
}
