import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/functions/title_case.dart';

void main() {
  test('KMB stop names are converted to title case', () {
    expect(
      toProperCase('TSUEN WAN WEST STATION BUS TERMINUS(Alighting)'),
      'Tsuen Wan West Station Bus Terminus(Alighting)',
    );
    expect(
      toProperCase('PUBLIC SQUARE STREET YAU MA TEI (YT545)'),
      'Public Square Street Yau Ma Tei (YT545)',
    );
  });

  test('known acronyms and brand names keep their casing', () {
    expect(toProperCase('BBI'), 'BBI');
    expect(toProperCase('MTR'), 'MTR');
    expect(toProperCase('KMB'), 'KMB');
    expect(toProperCase('apm'), 'apm');
    expect(toProperCase('LOHAS PARK STATION'), 'LOHAS Park Station');
    expect(toProperCase('NOVO LAND'), 'NOVO LAND');
    expect(toProperCase('YOHO MALL'), 'YOHO MALL');
    expect(toProperCase('ASIAWORLD-EXPO'), 'AsiaWorld-Expo');
    expect(toProperCase('ASIAWORLD EXPO'), 'AsiaWorld Expo');
    expect(
      toProperCase("CHOI WAN ST. JOSEPH'S SCHOOL"),
      "Choi Wan St. Joseph's School",
    );
  });

  test('small words and ordinals follow the special-case list', () {
    expect(toProperCase('AND'), 'and');
    expect(toProperCase('OF THE'), 'of the');
    expect(toProperCase('FOR'), 'for');
    expect(toProperCase('1ST'), '1st');
    expect(toProperCase('2ND'), '2nd');
  });

  test('apostrophes and embedded codes are handled', () {
    expect(toProperCase("O'BRIEN ROAD"), "O'Brien Road");
    expect(toProperCase("QUEEN'S ROAD"), "Queen's Road");
    expect(toProperCase('TSING WAN (TW123)'), 'Tsing Wan (TW123)');
  });

  test('only KMB stops receive title casing', () {
    final StopEntry kmb = StopEntry.fromJson('F282012BBB2865E5', {
      'name': {'en': 'TSUEN WAN WEST STATION', 'zh': '荃灣西站'},
      'location': {'lat': 22.3, 'lng': 114.1},
    });
    final StopEntry ctb = StopEntry.fromJson('001145', {
      'name': {'en': "JARDINE'S LOOKOUT", 'zh': '渣甸山'},
      'location': {'lat': 22.2, 'lng': 114.2},
    });

    expect(kmb.displayName('en'), 'Tsuen Wan West Station');
    expect(ctb.displayName('en'), "JARDINE'S LOOKOUT");
  });

  test('KMB route terminals are title cased', () {
    final BusDatabase db = BusDatabase.fromJson({
      'routeList': {
        'R+1+HONG SING GARDEN+CENTRAL (EXCHANGE SQUARE)': {
          'route': 'R',
          'serviceType': '1',
          'co': ['kmb'],
          'orig': {'en': 'HONG SING GARDEN', 'zh': '康盛花園'},
          'dest': {'en': 'CENTRAL (EXCHANGE SQUARE)', 'zh': '中環(交易廣場)'},
          'stops': {'kmb': <String>[]},
          'bound': {'kmb': 'O'},
          'seq': 0,
        },
      },
      'stopList': <String, dynamic>{},
      'stopMap': <String, dynamic>{},
      'holidays': <dynamic>[],
      'serviceDayMap': <String, dynamic>{},
    });

    final RouteEntry route = db.routesByKey.values.first;
    expect(route.orig.en, 'Hong Sing Garden');
    expect(route.dest.en, 'Central (Exchange Square)');
  });
}
