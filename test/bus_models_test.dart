import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';

void main() {
  group('stop name parsing', () {
    StopEntry parse(String en, [String zh = '']) {
      return StopEntry.fromJson('id', {
        'name': {'en': en, 'zh': zh.isEmpty ? en : zh},
        'location': {'lat': 22.3, 'lng': 114.1},
      });
    }

    test('extracts a standard station code', () {
      final StopEntry stop = parse('PUBLIC SQUARE STREET YAU MA TEI (YT545)');
      expect(stop.displayEn, 'PUBLIC SQUARE STREET YAU MA TEI');
      expect(stop.stationCode, 'YT545');
      expect(stop.platformCode, isNull);
    });

    test('extracts a station code with a lowercase suffix', () {
      final StopEntry stop = parse('CHOI PIK HOUSE CHOI PO COURT (ND105a)');
      expect(stop.displayEn, 'CHOI PIK HOUSE CHOI PO COURT');
      expect(stop.stationCode, 'ND105a');
    });

    test('separates station and platform codes', () {
      final StopEntry stop = parse('PACIFIC PLACE (A1) (CW743)');
      expect(stop.displayEn, 'PACIFIC PLACE');
      expect(stop.stationCode, 'CW743');
      expect(stop.platformCode, 'A1');
    });

    test('keeps a platform code when there is no station code', () {
      final StopEntry stop = parse(
        'FANLING STATION BBI - FANLING STATION (C1)',
      );
      expect(stop.displayEn, 'FANLING STATION BBI - FANLING STATION');
      expect(stop.stationCode, isNull);
      expect(stop.platformCode, 'C1');
    });

    test('does not treat place names as codes', () {
      final StopEntry stop = parse('Central (Macao Ferry)');
      expect(stop.displayEn, 'Central (Macao Ferry)');
      expect(stop.stationCode, isNull);
      expect(stop.platformCode, isNull);
    });

    test('does not treat lamp post references as codes', () {
      final StopEntry stop = parse('Science Park Road near L/P AE1877');
      expect(stop.displayEn, 'Science Park Road near L/P AE1877');
      expect(stop.stationCode, isNull);
    });
  });

  group('route database', () {
    Map<String, dynamic> databaseJson() {
      final Map<String, dynamic> route = {
        'route': '118R',
        'serviceType': '1',
        'co': ['kmb'],
        'orig': {'en': 'SIU SAI WAN SPORTS GROUND', 'zh': '小西灣運動場'},
        'dest': {'en': 'MONG KOK', 'zh': '旺角'},
        'stops': {
          'kmb': ['A', 'B'],
        },
        'bound': {'kmb': 'O'},
        'seq': 2,
        'fares': ['6.0', '6.0'],
        'faresHoliday': null,
        'freq': {
          '287': {
            '0600': ['0900', '600'],
          },
        },
        'jt': '20',
        'gtfsId': null,
        'nlbId': null,
      };
      final Map<String, dynamic> route2 = {
        ...route,
        'co': ['ctb'],
        'orig': {'en': 'Siu Sai Wan Sports Ground', 'zh': '小西灣運動場'},
        'dest': {'en': 'Mong Kok', 'zh': '旺角'},
        'stops': {
          'ctb': ['001', '002'],
        },
        'bound': {'ctb': 'O'},
      };
      return {
        'routeList': {
          '118R+1+SIU SAI WAN SPORTS GROUND+MONG KOK': route,
          '118R+1+Siu Sai Wan Sports Ground+Mong Kok': route2,
        },
        'stopList': {
          'A': {
            'name': {'en': 'Stop A', 'zh': '站 A'},
            'location': {'lat': 22.3, 'lng': 114.1},
          },
          'B': {
            'name': {'en': 'Stop B', 'zh': '站 B'},
            'location': {'lat': 22.31, 'lng': 114.11},
          },
          '001': {
            'name': {'en': 'Stop 1', 'zh': '站 1'},
            'location': {'lat': 22.3, 'lng': 114.1},
          },
          '002': {
            'name': {'en': 'Stop 2', 'zh': '站 2'},
            'location': {'lat': 22.31, 'lng': 114.11},
          },
        },
        'stopMap': {
          'A': [
            ['kmb', 'A'],
          ],
          '001': [
            ['ctb', '001'],
          ],
        },
        'holidays': ['20260101'],
        'serviceDayMap': {
          '287': ['0', '1', '1', '1', '1', '1', '0'],
        },
      };
    }

    test('keeps both routes when normalized keys collide', () {
      final BusDatabase db = BusDatabase.fromJson(databaseJson());
      expect(db.routesByKey.length, 2);
      expect(db.routesByNumber['118R']!.length, 2);
      final Set<String> slugs = db.routesByKey.values
          .map((route) => route.slug)
          .toSet();
      expect(slugs.length, 2);
      expect(slugs.any((slug) => slug.endsWith('-kmb')), isTrue);
      expect(slugs.any((slug) => slug.endsWith('-ctb')), isTrue);
    });

    test('keeps company specific stop lists', () {
      final BusDatabase db = BusDatabase.fromJson(databaseJson());
      final List<RouteEntry> routes = db.routesForNumber('118R');
      final RouteEntry kmb = routes.firstWhere(
        (route) => route.companies.contains(BusCompany.kmb),
      );
      final RouteEntry ctb = routes.firstWhere(
        (route) => route.companies.contains(BusCompany.ctb),
      );
      expect(kmb.primaryStops, ['A', 'B']);
      expect(ctb.primaryStops, ['001', '002']);
    });

    test('parses timetable and fare data', () {
      final BusDatabase db = BusDatabase.fromJson(databaseJson());
      final RouteEntry route = db.routesByNumber['118R']!.first;
      expect(route.freq, isNotNull);
      expect(route.freq!['287']!['0600'], ['0900', '600']);
      expect(route.fareAt(0, holiday: false), '6.0');
      expect(route.jt, '20');
    });
  });

  group('service calendar', () {
    test('detects holidays', () {
      expect(isHoliday(['20260101'], DateTime(2026, 1, 1)), isTrue);
      expect(isHoliday(['20260101'], DateTime(2026, 1, 2)), isFalse);
    });
  });
}
