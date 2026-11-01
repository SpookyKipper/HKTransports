import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/data/nearby_routes.dart';
import 'package:hktransports/bus/model/bus_models.dart';

RouteEntry route({
  required String key,
  required String number,
  required List<BusCompany> companies,
  required Map<BusCompany, List<String>> stops,
}) {
  return RouteEntry(
    key: key,
    slug: key,
    route: number,
    serviceType: '1',
    companies: companies,
    orig: const Terminal(en: 'A', zh: '甲'),
    dest: const Terminal(en: 'B', zh: '乙'),
    stops: stops,
    bound: const {},
    seq: 0,
  );
}

StopEntry stop(String id, double lat, double lng) {
  return StopEntry(
    id: id,
    nameEn: id,
    displayEn: id,
    nameZh: id,
    displayZh: id,
    lat: lat,
    lng: lng,
  );
}

void main() {
  test('finds the nearest stop per route within the radius', () {
    final RouteEntry kmb = route(
      key: '1+F+A+B',
      number: '1',
      companies: const [BusCompany.kmb],
      stops: const {
        BusCompany.kmb: ['K1', 'K2'],
      },
    );
    final RouteEntry far = route(
      key: '2+F+A+B',
      number: '2',
      companies: const [BusCompany.kmb],
      stops: const {
        BusCompany.kmb: ['K3'],
      },
    );
    final Map<String, StopEntry> stops = {
      'K1': stop('K1', 22.3000, 114.1000),
      'K2': stop('K2', 22.3100, 114.1000),
      'K3': stop('K3', 22.5000, 114.5000),
    };
    final BusDatabase database = BusDatabase(
      routesByKey: {kmb.key: kmb, far.key: far},
      routesBySlug: {kmb.slug: kmb, far.slug: far},
      routesByNumber: {
        '1': [kmb],
        '2': [far],
      },
      stops: stops,
      stopMap: const {
        'K1': [StopRef(company: BusCompany.kmb, stopId: 'K1')],
        'K2': [StopRef(company: BusCompany.kmb, stopId: 'K2')],
        'K3': [StopRef(company: BusCompany.kmb, stopId: 'K3')],
      },
      holidays: const [],
      serviceDayMap: const {},
    );

    List<RouteStopRef> routesAt(String physicalStopId) {
      final List<RouteStopRef> result = [];
      for (final StopRef ref in database.stopMap[physicalStopId] ?? const []) {
        for (final RouteEntry value in database.routesByKey.values) {
          final List<String> ids = value.stops[ref.company] ?? const [];
          for (int seq = 0; seq < ids.length; seq++) {
            if (ids[seq] == ref.stopId) {
              result.add(
                RouteStopRef(route: value, company: ref.company, seq: seq),
              );
            }
          }
        }
      }
      return result;
    }

    final List<NearbyRouteResult> near = findNearbyRoutes(
      database: database,
      routesAtStop: routesAt,
      latitude: 22.3001,
      longitude: 114.1001,
      radiusMeters: 200,
    );
    expect(near.length, 1);
    expect(near.single.route.key, kmb.key);
    expect(near.single.stop.id, 'K1');
    expect(near.single.routeStopId, 'K1');
    expect(near.single.routeSeq, 0);
    expect(near.single.distanceMeters, lessThan(50));

    final List<NearbyRouteResult> wider = findNearbyRoutes(
      database: database,
      routesAtStop: routesAt,
      latitude: 22.3001,
      longitude: 114.1001,
      radiusMeters: 2000,
    );
    expect(wider.length, 1);
    expect(wider.single.stop.id, 'K1');

    final List<NearbyRouteResult> atSecondStop = findNearbyRoutes(
      database: database,
      routesAtStop: routesAt,
      latitude: 22.3100,
      longitude: 114.1000,
      radiusMeters: 200,
    );
    expect(atSecondStop.length, 1);
    expect(atSecondStop.single.stop.id, 'K2');
    expect(atSecondStop.single.routeStopId, 'K2');
    expect(atSecondStop.single.routeSeq, 1);
  });

  test('maps a secondary company stop back to the primary route stop', () {
    final RouteEntry combined = route(
      key: '3+F+A+B',
      number: '3',
      companies: const [BusCompany.kmb, BusCompany.ctb],
      stops: const {
        BusCompany.kmb: ['K1'],
        BusCompany.ctb: ['C1'],
      },
    );
    final BusDatabase database = BusDatabase(
      routesByKey: {combined.key: combined},
      routesBySlug: {combined.slug: combined},
      routesByNumber: {
        '3': [combined],
      },
      stops: {'P': stop('P', 22.3, 114.1)},
      stopMap: const {
        'P': [
          StopRef(company: BusCompany.kmb, stopId: 'K1'),
          StopRef(company: BusCompany.ctb, stopId: 'C1'),
        ],
      },
      holidays: const [],
      serviceDayMap: const {},
    );

    final List<NearbyRouteResult> results = findNearbyRoutes(
      database: database,
      routesAtStop: (String physicalStopId) => [
        RouteStopRef(route: combined, company: BusCompany.ctb, seq: 0),
      ],
      latitude: 22.3,
      longitude: 114.1,
      radiusMeters: 100,
    );
    expect(results.single.routeStopId, 'K1');
    expect(results.single.routeSeq, 0);
  });
}
