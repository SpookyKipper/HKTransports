import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/ui/official_links.dart';

RouteEntry _nlbRoute(String route, {String? nlbId}) {
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
    nlbId: nlbId,
  );
}

void main() {
  test('builds the official NLB route URL', () {
    expect(
      officialUrl(
        route: _nlbRoute('3M', nlbId: '123'),
        company: BusCompany.nlb,
        language: 'zh',
      ),
      'https://www.nlb.com.hk/tc/route/123',
    );
    expect(
      officialUrl(
        route: _nlbRoute('3M', nlbId: '123'),
        company: BusCompany.nlb,
        language: 'en',
      ),
      'https://www.nlb.com.hk/en/route/123',
    );
    expect(
      nlbFareTableUrl('123'),
      'https://www.nlb.com.hk/route/123/fare-table',
    );
  });
}
