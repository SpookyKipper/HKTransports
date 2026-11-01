import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/data/route_waypoints.dart';
import 'package:hktransports/bus/model/bus_models.dart';

RouteEntry route({
  String routeNumber = '690',
  List<BusCompany> companies = const [BusCompany.kmb, BusCompany.ctb],
  Map<BusCompany, String> bound = const {
    BusCompany.kmb: 'O',
    BusCompany.ctb: 'I',
  },
  String destEn = 'CENTRAL',
  String? gtfsId = '1289',
}) {
  return RouteEntry(
    key: 'route-key',
    slug: 'route-slug',
    route: routeNumber,
    serviceType: '1',
    companies: companies,
    orig: const Terminal(en: 'HONG SING GARDEN', zh: '康盛花園'),
    dest: Terminal(en: destEn, zh: '中環'),
    stops: const {
      BusCompany.kmb: ['K1', 'K2'],
      BusCompany.ctb: ['C1', 'C2'],
    },
    bound: bound,
    seq: 2,
    gtfsId: gtfsId,
  );
}

void main() {
  test('uses the first company bound for bus waypoint files', () {
    expect(RouteWaypoints.fileName(route()), '1289-O.json');
    expect(
      RouteWaypoints.fileName(
        route(bound: const {BusCompany.kmb: 'I', BusCompany.ctb: 'O'}),
      ),
      '1289-I.json',
    );
  });

  test('uses the low-case MTR line code for MTR routes', () {
    expect(
      RouteWaypoints.fileName(
        route(
          routeNumber: 'AEL',
          companies: const [BusCompany.mtr],
          bound: const {BusCompany.mtr: 'UT'},
          gtfsId: null,
        ),
      ),
      'ael.json',
    );
  });

  test('uses the light rail direction suffix and circular file', () {
    expect(
      RouteWaypoints.fileName(
        route(
          routeNumber: '505',
          companies: const [BusCompany.lightRail],
          bound: const {BusCompany.lightRail: 'I'},
          gtfsId: null,
        ),
      ),
      '505_I.json',
    );
    expect(
      RouteWaypoints.fileName(
        route(
          routeNumber: '705',
          companies: const [BusCompany.lightRail],
          bound: const {BusCompany.lightRail: 'O'},
          destEn: 'Tin Shui Wai (Circular)',
          gtfsId: null,
        ),
      ),
      '705.json',
    );
  });

  test('uses the route code for ferries', () {
    expect(
      RouteWaypoints.fileName(
        route(
          routeNumber: 'KF4',
          companies: const [BusCompany.hkkf],
          bound: const {BusCompany.hkkf: 'I'},
          gtfsId: null,
        ),
      ),
      'KF4.json',
    );
  });

  test('returns null when there is no usable waypoint source', () {
    expect(
      RouteWaypoints.fileName(
        route(
          routeNumber: 'K12',
          companies: const [BusCompany.lrtfeeder],
          bound: const {BusCompany.lrtfeeder: 'O'},
          gtfsId: null,
        ),
      ),
      isNull,
    );
  });
}
