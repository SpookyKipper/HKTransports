import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/ui/company_logos.dart';

RouteEntry route(String number, BusCompany company) {
  return RouteEntry(
    key: '$number-${company.id}',
    slug: '$number-${company.id}',
    route: number,
    serviceType: '1',
    companies: <BusCompany>[company],
    orig: const Terminal(en: 'A', zh: '甲'),
    dest: const Terminal(en: 'B', zh: '乙'),
    stops: <BusCompany, List<String>>{
      company: const <String>['S'],
    },
    bound: const <BusCompany, String>{},
    seq: 0,
  );
}

void main() {
  test('selects the correct Citybus brand logo', () {
    expect(
      companyLogoAsset(route('A21', BusCompany.ctb), BusCompany.ctb),
      'assets/images/companies/cityflyer.png',
    );
    expect(
      companyLogoAsset(route('20A', BusCompany.ctb), BusCompany.ctb),
      'assets/images/companies/citybus.png',
    );
  });

  test('selects the correct KMB group logo', () {
    expect(
      companyLogoAsset(route('A41', BusCompany.kmb), BusCompany.kmb),
      'assets/images/companies/lwb.png',
    );
    expect(
      companyLogoAsset(route('SP1', BusCompany.kmb), BusCompany.kmb),
      'assets/images/companies/kmb.png',
    );
  });

  test('maps the remaining supported companies', () {
    expect(
      companyLogoAsset(route('1', BusCompany.nlb), BusCompany.nlb),
      'assets/images/companies/nlb.png',
    );
    expect(
      companyLogoAsset(route('46', BusCompany.gmb), BusCompany.gmb),
      'assets/images/companies/green_minibus.png',
    );
    expect(
      companyLogoAsset(route('MTR', BusCompany.mtr), BusCompany.mtr),
      'assets/images/companies/mtr.png',
    );
    expect(
      companyLogoAsset(
        route('505', BusCompany.lightRail),
        BusCompany.lightRail,
      ),
      isNull,
    );
  });
}
