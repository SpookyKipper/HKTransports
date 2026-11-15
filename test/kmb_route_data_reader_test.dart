import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/kmb/kmb_route_data_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:sqlite3/sqlite3.dart';

RouteEntry _route({String serviceType = '1', String bound = 'O'}) {
  return RouteEntry(
    key: '87C+1+TEST+DEST',
    slug: '87c',
    route: '87C',
    serviceType: serviceType,
    companies: const <BusCompany>[BusCompany.kmb],
    orig: const Terminal(en: 'TEST', zh: '測試'),
    dest: const Terminal(en: 'DEST', zh: '終點'),
    stops: const <BusCompany, List<String>>{
      BusCompany.kmb: <String>['A', 'B', 'C'],
    },
    bound: <BusCompany, String>{BusCompany.kmb: bound},
    seq: 1,
  );
}

void main() {
  late Database db;
  late KmbRouteDataReader reader;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE kmb_stop (
        route_no TEXT NOT NULL, bound TEXT NOT NULL,
        stop_seq INTEGER NOT NULL, service_type TEXT NOT NULL,
        stop_loc1 TEXT, stop_loc2 TEXT, stop_loc3 TEXT,
        stop_loc_chi1 TEXT, stop_loc_chi2 TEXT, stop_loc_chi3 TEXT,
        PRIMARY KEY (route_no, bound, stop_seq, service_type)
      )
    ''');
    db.execute('''
      CREATE TABLE kmb_bound (
        route_no TEXT NOT NULL, bound_no INTEGER NOT NULL,
        service_type TEXT NOT NULL,
        service_type_desc_eng TEXT, service_type_desc_chi TEXT,
        PRIMARY KEY (route_no, bound_no, service_type)
      )
    ''');
    db.execute('''
      INSERT INTO kmb_stop VALUES
        ('87C','1',1,'01','ROAD','NEAR PARK','','道路','近公園','')
      ''');
    db.execute('''
      INSERT INTO kmb_bound VALUES
        ('87C',1,'01','Special departures','特別班次')
      ''');
    reader = KmbRouteDataReader(db);
  });

  tearDown(() => reader.dispose());

  test('reads localised extended stop names by bound and service type', () {
    expect(reader.stopLocations(_route(), 1, 'zh'), <String>['道路', '近公園']);
    expect(reader.stopLocations(_route(), 1, 'en'), <String>[
      'ROAD',
      'NEAR PARK',
    ]);
  });

  test('maps inbound bound to bound 2', () {
    db.execute('''
      INSERT INTO kmb_stop VALUES
        ('87C','2',1,'01','INBOUND ROAD','','','入站道路','','')
      ''');
    expect(reader.stopLocations(_route(bound: 'I'), 1, 'en'), <String>[
      'INBOUND ROAD',
    ]);
  });

  test('reads service type descriptions and hides normal text', () {
    expect(reader.serviceDescription(_route(), 'zh'), '特別班次');
    expect(reader.serviceDescription(_route(), 'en'), 'Special departures');
    db.execute("UPDATE kmb_bound SET service_type_desc_eng = 'Normal'");
    expect(reader.serviceDescription(_route(), 'en'), '特別班次');
  });

  test('removes brackets from service type descriptions', () {
    db.execute(
      "UPDATE kmb_bound SET service_type_desc_chi = '(經樂華)', service_type_desc_eng = '(Via Lok Wah)'",
    );
    expect(reader.serviceDescription(_route(), 'zh'), '經樂華');
    expect(reader.serviceDescription(_route(), 'en'), 'Via Lok Wah');
  });
}
