import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/ui/official_links.dart';

RouteEntry _nlbRoute(String route) {
  return RouteEntry(
    key: '$route+1+test',
    slug: '$route-nlb',
    route: route,
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.nlb],
    orig: const Terminal(en: 'Mui Wo', zh: '梅窩'),
    dest: const Terminal(en: 'Tung Chung', zh: '東涌'),
    stops: const <BusCompany, List<String>>{
      BusCompany.nlb: <String>['A', 'B'],
    },
    bound: const <BusCompany, String>{BusCompany.nlb: 'O'},
    seq: 2,
  );
}

void main() {
  test('builds the official NLB route URL', () {
    expect(
      officialUrl(
        route: _nlbRoute('3M'),
        company: BusCompany.nlb,
        language: 'zh',
      ),
      'https://www.nlb.com.hk/tc/route?q=3M',
    );
    expect(
      officialUrl(
        route: _nlbRoute('3M'),
        company: BusCompany.nlb,
        language: 'en',
      ),
      'https://www.nlb.com.hk/en/route?q=3M',
    );
    expect(nlbFareTableUrl('3M'), 'https://www.nlb.com.hk/route/3M/fare-table');
  });
}
