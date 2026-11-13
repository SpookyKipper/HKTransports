import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/route_category.dart';

void main() {
  test('maps companies to search categories', () {
    for (final BusCompany company in <BusCompany>[
      BusCompany.kmb,
      BusCompany.ctb,
      BusCompany.nlb,
      BusCompany.lrtfeeder,
    ]) {
      expect(categoryForCompany(company), RouteCategory.bus);
    }
    expect(categoryForCompany(BusCompany.gmb), RouteCategory.minibus);
    expect(categoryForCompany(BusCompany.mtr), RouteCategory.train);
    expect(categoryForCompany(BusCompany.lightRail), RouteCategory.lightRail);
    for (final BusCompany company in <BusCompany>[
      BusCompany.sunferry,
      BusCompany.fortuneferry,
      BusCompany.hkkf,
    ]) {
      expect(categoryForCompany(company), RouteCategory.ferry);
    }
  });

  test('filters routes by category', () {
    final RouteEntry bus = _route(<BusCompany>[BusCompany.kmb]);
    final RouteEntry minibus = _route(<BusCompany>[BusCompany.gmb]);
    final RouteEntry train = _route(<BusCompany>[BusCompany.mtr]);
    final RouteEntry lightRail = _route(<BusCompany>[BusCompany.lightRail]);
    final RouteEntry ferry = _route(<BusCompany>[BusCompany.hkkf]);
    final RouteEntry jointBus = _route(<BusCompany>[
      BusCompany.kmb,
      BusCompany.ctb,
    ]);

    expect(routeMatchesCategory(bus, RouteCategory.bus), isTrue);
    expect(routeMatchesCategory(jointBus, RouteCategory.bus), isTrue);
    expect(routeMatchesCategory(bus, RouteCategory.train), isFalse);
    expect(routeMatchesCategory(minibus, RouteCategory.minibus), isTrue);
    expect(routeMatchesCategory(train, RouteCategory.train), isTrue);
    expect(routeMatchesCategory(lightRail, RouteCategory.lightRail), isTrue);
    expect(routeMatchesCategory(ferry, RouteCategory.ferry), isTrue);
    expect(routeMatchesCategory(bus, RouteCategory.all), isTrue);
  });

  test('localizes category labels', () {
    expect(RouteCategory.all.label('zh'), '全部');
    expect(RouteCategory.bus.label('en'), 'Bus');
    expect(RouteCategory.minibus.label('zh'), '專線小巴');
    expect(RouteCategory.train.label('en'), 'Train');
    expect(RouteCategory.lightRail.label('zh'), '輕鐵');
    expect(RouteCategory.ferry.label('en'), 'Ferry');
  });
}

RouteEntry _route(List<BusCompany> companies) {
  return RouteEntry(
    key: 'R+1+Origin+Destination',
    slug: 'r-test',
    route: 'R',
    serviceType: '1',
    companies: companies,
    orig: const Terminal(en: 'Origin', zh: '起點'),
    dest: const Terminal(en: 'Destination', zh: '終點'),
    stops: <BusCompany, List<String>>{
      for (final BusCompany company in companies) company: const <String>['S1'],
    },
    bound: <BusCompany, String>{
      for (final BusCompany company in companies) company: 'O',
    },
    seq: 1,
  );
}
