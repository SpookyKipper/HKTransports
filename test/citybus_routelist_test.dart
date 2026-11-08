import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late CitybusRoutelistReader reader;

  setUp(() {
    database = sqlite3.openInMemory();
    database.execute('''
      CREATE TABLE ROUTE (
        COMPANY_CODE TEXT,
        SERVICE_NO TEXT,
        DIRECTION TEXT,
        DEST_LOCATION TEXT,
        ROUTING_SEQ INTEGER,
        BOUND TEXT,
        WEB_ORIGIN TEXT,
        WEB_DESTIN TEXT,
        WEB_SHOW TEXT,
        ROUTE_RDV TEXT,
        RDV TEXT,
        ROUTING_REMARK TEXT,
        VARDESC TEXT,
        ROUTE_INDEX INTEGER
      )
    ''');
    database.execute('''
      CREATE TABLE ROUTESTOP (
        COMPANY_CODE TEXT,
        SERVICE_NO TEXT,
        ROUTE_INDEX INTEGER,
        BSA_SEQ INTEGER,
        STOP_ID TEXT,
        ADULT_FARE REAL,
        CHILD_FARE REAL,
        SENIOR_FARE REAL,
        BUSSTOP_INFO TEXT,
        DESC_NAME TEXT
      )
    ''');
    database.execute('''
      CREATE TABLE ROUTELIST (
        service_no TEXT,
        dest_location TEXT
      )
    ''');
    database.execute('''
      INSERT INTO ROUTE VALUES (
        'CTB', '792M', 'O', 'SAK', 1, 'O',
        'Tseung Kwan O Station', 'Sai Kung', 'Y',
        '792M-SAK-1', '792M-SAK-1', 'Normal Route', 'Normal Route', 100
      )
      ''');
    database.execute('''
      INSERT INTO ROUTE VALUES (
        'CTB', '792M', 'I', 'TKO', 1, 'I',
        'Sai Kung', 'Tseung Kwan O Station', 'Y',
        '792M-TKO-1', '792M-TKO-1', 'Normal Route', 'Normal Route', 101
      )
      ''');
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', '792M', 100, 1, '002918', 9.4, 4.7, 2, NULL, 'Sai Kung')",
    );
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', '792M', 100, 2, '001823', 6.5, 3.3, 2, 'Tseung Kwan O', 'Sai Kung')",
    );
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', '792M', 100, 3, '002109', 0, 0, 0, NULL, 'Sai Kung')",
    );
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', '792M', 101, 1, '002109', 9.4, 4.7, 2, NULL, 'Tseung Kwan O Station')",
    );
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', '792M', 101, 2, '001823', 6.5, 3.3, 2, 'Tseung Kwan O', 'Tseung Kwan O Station')",
    );
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', '792M', 101, 3, '002918', 0, 0, 0, NULL, 'Tseung Kwan O Station')",
    );
    database.execute(
      "INSERT INTO ROUTELIST VALUES ('792M', 'CTB||792M||SAK||2||Tseung Kwan O Station||Sai Kung||2||792M--Sai_Kung||100||O||Scenic Summit||792M-SAK-1||Sai Kung')",
    );
    database.execute(
      "INSERT INTO ROUTELIST VALUES ('792M', 'CTB||792M||TKO||2||Sai Kung||Tseung Kwan O Station||2||792M--Tseung_Kwan_O_Station||101||I||Scenic Return||792M-TKO-1||Tseung Kwan O Station')",
    );
    database.execute(
      "INSERT INTO ROUTELIST VALUES ('792M', 'NLB||792M||N/A||1||Sai Kung||Tseung Kwan O||1||792M--Other||900||I||Other operator||N/A||Not used')",
    );
    database.execute('''
      INSERT INTO ROUTE VALUES (
        'CTB', 'A28', 'I', 'LHP', 1, 'I',
        'Airport', 'LOHAS Park', 'Y',
        '0A28-LHP-1', 'A28-LHP-1', 'Normal Route', 'Normal Route', 200
      )
      ''');
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', 'A28', 200, 1, '001837', 44, 22, 22, NULL, 'LOHAS Park')",
    );
    database.execute(
      "INSERT INTO ROUTESTOP VALUES ('CTB', 'A28', 200, 2, '003329', 0, 0, 0, NULL, 'LOHAS Park')",
    );
    database.execute(
      "INSERT INTO ROUTELIST VALUES ('A28', 'CTB||A28||LHP||2||Airport||LOHAS Park||1||A28--LOHAS_Park||200||I||||A28-LHP-1||LOHAS Park')",
    );
    reader = CitybusRoutelistReader(database);
  });

  tearDown(() {
    reader.dispose();
  });

  test('parses packed ROUTELIST route metadata', () {
    final CitybusRoutelistRecord? record = parseCitybusRoutelistRecord(
      'CTB||792M||SAK||2||Tseung Kwan O Station||Sai Kung||2||792M--Sai_Kung||10596||O||Scenic Summit||792M-SAK-1||Sai Kung',
    );
    expect(record, isNotNull);
    expect(record!.company, 'CTB');
    expect(record.serviceNo, '792M');
    expect(record.origin, 'Tseung Kwan O Station');
    expect(record.destination, 'Sai Kung');
    expect(record.routeIndex, 10596);
    expect(record.bound, 'O');
    expect(record.name, 'Scenic Summit');
    expect(record.rdv, '792M-SAK-1');
    expect(record.destinationLabel, 'Sai Kung');
  });

  test('matches the outbound variant, route name, fare and bus stop info', () {
    final RouteEntry route = _route(
      orig: const Terminal(en: 'Tseung Kwan O Station', zh: '將軍澳站'),
      dest: const Terminal(en: 'Sai Kung', zh: '西貢'),
      bound: 'O',
      stops: <String>['002918', '001823', '002109'],
    );

    final CitybusRouteData? data = reader.routeData(route, 'en');
    expect(data, isNotNull);
    expect(data!.routeIndex, 100);
    expect(data.rdv, '792M-SAK-1');
    expect(data.routeName, 'Scenic Summit');
    expect(reader.routeName(route, 'en'), 'Scenic Summit');
    expect(reader.remarkInfoKeys(route), <String>['792M-SAK-1']);

    final CitybusStopData? stop = reader.stopData(route, 1, 'en');
    expect(stop, isNotNull);
    expect(stop!.stopId, '001823');
    expect(stop.landmark, 'Tseung Kwan O');
    expect(stop.adultFare, 6.5);
    expect(stop.childFare, 3.3);
  });

  test('uses bound and terminals to choose the matching direction', () {
    final RouteEntry route = _route(
      orig: const Terminal(en: 'Sai Kung', zh: '西貢'),
      dest: const Terminal(en: 'Tseung Kwan O Station', zh: '將軍澳站'),
      bound: 'I',
      stops: <String>['002109', '001823', '002918'],
    );

    final CitybusRouteData? data = reader.routeData(route, 'en');
    expect(data, isNotNull);
    expect(data!.routeIndex, 101);
    expect(data.rdv, '792M-TKO-1');
    expect(reader.routeName(route, 'en'), 'Scenic Return');
  });

  test('keeps matching a variant when the stop list has minor differences', () {
    final RouteEntry route = _route(
      orig: const Terminal(en: 'Tseung Kwan O Station', zh: '將軍澳站'),
      dest: const Terminal(en: 'Sai Kung', zh: '西貢'),
      bound: 'O',
      stops: <String>['002918', '001823'],
    );

    final CitybusRouteData? data = reader.routeData(route, 'en');
    expect(data, isNotNull);
    expect(data!.routeIndex, 100);
    expect(reader.stopData(route, 1, 'en')?.landmark, 'Tseung Kwan O');
  });

  test('uses the unpadded RDV identifier for A28 remarks', () {
    final RouteEntry route = _route(
      routeNumber: 'A28',
      orig: const Terminal(en: 'Airport', zh: '機場'),
      dest: const Terminal(en: 'LOHAS Park', zh: '日出康城'),
      bound: 'I',
      stops: <String>['001837', '003329'],
    );

    expect(reader.remarkInfoKeys(route), <String>['A28-LHP-1']);
  });

  test('prepares indexes before the database is stored', () {
    prepareCitybusRoutelistDatabase(database);
    final ResultSet indexes = database.select(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name LIKE 'citybus_%' ORDER BY name",
    );
    expect(
      indexes.map((Row row) => row['name']),
      containsAll(<String>[
        'citybus_route_service',
        'citybus_routestop_service',
        'citybus_routelist_service',
      ]),
    );
  });

  test('extracts a routelist database from the ZIP payload', () {
    final Uint8List bytes = Uint8List.fromList(<int>[
      ...'SQLite format 3\u0000'.codeUnits,
      ...List<int>.filled(32, 0),
    ]);
    final Archive archive = Archive()
      ..addFile(ArchiveFile('routelist0.db', bytes.length, bytes));
    final Uint8List zip = ZipEncoder().encodeBytes(archive);
    expect(extractCitybusDatabaseBytes(zip, '0'), bytes);
    expect(() => extractCitybusDatabaseBytes(zip, '1'), throwsFormatException);
  });
}

RouteEntry _route({
  String routeNumber = '792M',
  required Terminal orig,
  required Terminal dest,
  required String bound,
  required List<String> stops,
}) {
  return RouteEntry(
    key: '$routeNumber+1+${orig.en}+${dest.en}',
    slug: '$routeNumber-ctb',
    route: routeNumber,
    serviceType: '1',
    companies: <BusCompany>[BusCompany.ctb],
    orig: orig,
    dest: dest,
    stops: <BusCompany, List<String>>{BusCompany.ctb: stops},
    bound: <BusCompany, String>{BusCompany.ctb: bound},
    seq: stops.length,
  );
}
