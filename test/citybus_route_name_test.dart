import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/cache/citybus_route_name_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

void main() {
  test('does not fetch Cityflyer A/NA routes', () async {
    const CitybusRouteNameService service = CitybusRouteNameService();
    expect(await service.routeName(_route('A21'), 'en'), isNull);
    expect(await service.routeName(_route('NA21'), 'en'), isNull);
  });

  test('does not look up non-Citybus routes', () async {
    const CitybusRouteNameService service = CitybusRouteNameService();
    expect(
      await service.routeName(_route('720', company: BusCompany.kmb), 'en'),
      isNull,
    );
  });
}

RouteEntry _route(String number, {BusCompany company = BusCompany.ctb}) {
  return RouteEntry(
    key: '$number+1+Origin+Destination',
    slug: '$number-${company.id}',
    route: number,
    serviceType: '1',
    companies: <BusCompany>[company],
    orig: const Terminal(en: 'Origin', zh: '起點'),
    dest: const Terminal(en: 'Destination', zh: '終點'),
    stops: <BusCompany, List<String>>{
      company: const <String>['001825'],
    },
    bound: <BusCompany, String>{company: 'O'},
    seq: 1,
  );
}
