import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/route_display_name.dart';

void main() {
  test('uses the Chinese MTR line name everywhere', () {
    expect(routeDisplayName(_route('AEL'), 'zh'), '機場快綫');
    expect(routeDisplayName(_route('TKL'), 'zh'), '將軍澳綫');
  });

  test('uses the full English MTR name only when requested', () {
    expect(routeDisplayName(_route('AEL'), 'en'), 'AEL');
    expect(
      routeDisplayName(_route('AEL'), 'en', fullEnglish: true),
      'Airport Express',
    );
    expect(
      routeDisplayName(_route('TKL'), 'en', fullEnglish: true),
      'Tseung Kwan O Line',
    );
  });

  test('leaves non-MTR route codes unchanged', () {
    expect(
      routeDisplayName(_route('720', company: BusCompany.ctb), 'zh'),
      '720',
    );
    expect(
      routeDisplayName(_route('720', company: BusCompany.ctb), 'en'),
      '720',
    );
  });
}

RouteEntry _route(String number, {BusCompany company = BusCompany.mtr}) {
  return RouteEntry(
    key: '$number+1+Origin+Destination',
    slug: '$number-${company.id}',
    route: number,
    serviceType: '1',
    companies: <BusCompany>[company],
    orig: const Terminal(en: 'Origin', zh: '起點'),
    dest: const Terminal(en: 'Destination', zh: '終點'),
    stops: <BusCompany, List<String>>{
      company: const <String>['STOP1'],
    },
    bound: <BusCompany, String>{company: 'O'},
    seq: 1,
  );
}
