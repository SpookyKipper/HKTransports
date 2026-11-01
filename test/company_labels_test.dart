import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';

RouteEntry route(String number, List<BusCompany> companies) {
  return RouteEntry(
    key: '$number+${companies.map((company) => company.id).join('+')}',
    slug: number,
    route: number,
    serviceType: '1',
    companies: companies,
    orig: const Terminal(en: 'A', zh: '甲'),
    dest: const Terminal(en: 'B', zh: '乙'),
    stops: {
      for (final BusCompany company in companies) company: const <String>['S'],
    },
    bound: const {},
    seq: 0,
  );
}

void main() {
  group('route company display labels', () {
    test('shows Cityflyer for Citybus A and NA routes', () {
      for (final String number in <String>['A21', 'NA21']) {
        final RouteEntry value = route(number, const [BusCompany.ctb]);
        expect(value.companiesLabel('zh'), '城巴機場快線');
        expect(value.companiesLabel('en'), 'Cityflyer');
        expect(value.companies, const [BusCompany.ctb]);
      }
    });

    test('keeps Citybus for non-airport routes', () {
      final RouteEntry value = route('20A', const [BusCompany.ctb]);
      expect(value.companiesLabel('zh'), '城巴');
      expect(value.companiesLabel('en'), 'Citybus');
    });

    test('shows LWB for KMB A/NA/E/R/X/S routes', () {
      for (final String number in <String>[
        'A41',
        'NA41',
        'E33',
        'R8',
        'X1',
        'S1',
      ]) {
        final RouteEntry value = route(number, const [BusCompany.kmb]);
        expect(value.companiesLabel('zh'), '龍運');
        expect(value.companiesLabel('en'), 'LWB');
      }
    });

    test('shows LWB for the listed KMB night routes', () {
      for (final String number in <String>[
        'N30',
        'N31',
        'N42',
        'N42A',
        'N64',
      ]) {
        final RouteEntry value = route(number, const [BusCompany.kmb]);
        expect(value.companiesLabel('zh'), '龍運');
        expect(value.companiesLabel('en'), 'LWB');
      }
    });

    test('keeps KMB for other routes', () {
      final RouteEntry value = route('N281', const [BusCompany.kmb]);
      expect(value.companiesLabel('zh'), '九巴');
      expect(value.companiesLabel('en'), 'KMB');
    });

    test('uses shortened GMB labels', () {
      final RouteEntry value = route('46', const [BusCompany.gmb]);
      expect(value.companiesLabel('zh'), '專線小巴');
      expect(value.companiesLabel('en'), 'GMB');
    });

    test('does not override NLB routes', () {
      final RouteEntry value = route('A35', const [BusCompany.nlb]);
      expect(value.companiesLabel('zh'), '嶼巴');
      expect(value.companiesLabel('en'), 'NLB');
    });
  });
}
