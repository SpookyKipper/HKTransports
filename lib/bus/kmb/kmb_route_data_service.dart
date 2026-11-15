import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/dataStore/objectbox.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const String defaultKmbRouteDataCheckUrl =
    'https://kmb-m4.socif.co/kmb-ws/checkupdateapp.php?version=1.3.5';
const String _fallbackBaseLastUpdate = '20250509022620';
const String _lastUpdateKey = 'kmb.routeData.lastUpdate';
const String _updatedAtKey = 'kmb.routeData.updatedAt';
const String _schemaKey = 'kmb.routeData.schema';
const String _schemaVersion = '1';

const String _fullStopSchema = '''
CREATE TABLE IF NOT EXISTS kmb_routestopfile_ST (
  route_no TEXT, bound TEXT, stop_seq INTEGER, area TEXT,
  normal_fare REAL, air_cond_fare REAL,
  stop_loc1 TEXT, stop_loc2 TEXT, stop_loc3 TEXT, dummy TEXT,
  stop_loc_chi1 TEXT, stop_loc_chi2 TEXT, stop_loc_chi3 TEXT,
  stop_loc_cn1 TEXT, stop_loc_cn2 TEXT, stop_loc_cn3 TEXT,
  subarea TEXT, stop_name TEXT, stop_name_chi TEXT, stop_name_cn TEXT,
  district TEXT, service_type TEXT, lat TEXT, lng TEXT
)''';

const String _fullBoundSchema = '''
CREATE TABLE IF NOT EXISTS kmb_routeboundmaster_ST (
  route_no TEXT, bound_no INTEGER, origin TEXT,
  origin_chi TEXT, origin_cn TEXT, destination TEXT,
  destination_chi TEXT, destination_cn TEXT,
  wf_first_trip INTEGER, wf_last_trip INTEGER,
  hd_first_trip INTEGER, hd_last_trip INTEGER,
  sat_first_trip INTEGER, sat_last_trip INTEGER,
  service_type TEXT, service_type_desc_eng TEXT,
  service_type_desc_chi TEXT, service_type_desc_cn TEXT
)''';

const String _fullStopIndexes = '''
CREATE INDEX IF NOT EXISTS kmb_routestopfile_ST_idx
ON kmb_routestopfile_ST (route_no, bound, stop_seq, service_type);
CREATE INDEX IF NOT EXISTS kmb_routeboundmaster_ST_idx
ON kmb_routeboundmaster_ST (route_no, bound_no, service_type);
''';

const String _slimStopSchema = '''
CREATE TABLE IF NOT EXISTS slim.kmb_stop (
  route_no TEXT NOT NULL, bound TEXT NOT NULL,
  stop_seq INTEGER NOT NULL, service_type TEXT NOT NULL,
  stop_loc1 TEXT, stop_loc2 TEXT, stop_loc3 TEXT,
  stop_loc_chi1 TEXT, stop_loc_chi2 TEXT, stop_loc_chi3 TEXT,
  PRIMARY KEY (route_no, bound, stop_seq, service_type)
)''';

const String _slimBoundSchema = '''
CREATE TABLE IF NOT EXISTS slim.kmb_bound (
  route_no TEXT NOT NULL, bound_no INTEGER NOT NULL,
  service_type TEXT NOT NULL,
  service_type_desc_eng TEXT, service_type_desc_chi TEXT,
  PRIMARY KEY (route_no, bound_no, service_type)
)''';

class KmbRouteDataException implements Exception {
  const KmbRouteDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KmbRouteDataService {
  KmbRouteDataService({http.Client? client, Directory? directory})
    : _client = client,
      _directoryOverride = directory;

  static final KmbRouteDataService instance = KmbRouteDataService();

  final http.Client? _client;
  final Directory? _directoryOverride;
  Future<void>? _updateFuture;
  Future<KmbRouteDataReader?>? _readerFuture;

  String? get storedLastUpdate {
    final String? value = sp.getString(_lastUpdateKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  DateTime? get storedUpdatedAt {
    final int? seconds = sp.getInt(_updatedAtKey);
    return seconds == null || seconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  Future<int> storedBytes() async {
    final File file = await _databaseFile();
    return await file.exists() ? file.length() : 0;
  }

  Future<bool> isDownloaded() async {
    final File file = await _databaseFile();
    if (!await file.exists() || await file.length() == 0) return false;
    try {
      final Database db = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        return db
            .select(
              "SELECT 1 FROM sqlite_master WHERE type='table' AND name='kmb_stop'",
            )
            .isNotEmpty;
      } finally {
        db.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> ensureDownloaded({
    required KmbRouteDataConfig? remote,
    bool force = false,
    void Function(double? progress)? onProgress,
  }) {
    final Future<void>? running = _updateFuture;
    if (running != null) return running;
    final Future<void> future = _ensureDownloaded(
      remote: remote,
      force: force,
      onProgress: onProgress,
    );
    _updateFuture = future;
    return future.whenComplete(() {
      if (identical(_updateFuture, future)) _updateFuture = null;
    });
  }

  Future<List<String>> stopLocations(
    RouteEntry route,
    int stopIndex,
    String language,
  ) async {
    final KmbRouteDataReader? reader = await _reader();
    return reader?.stopLocations(route, stopIndex, language) ??
        const <String>[];
  }

  Future<String?> serviceDescription(RouteEntry route, String language) async {
    final KmbRouteDataReader? reader = await _reader();
    return reader?.serviceDescription(route, language);
  }

  Future<void> delete() async {
    await _closeReader();
    final Directory directory = await _directory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    sp.removeString(_lastUpdateKey);
    sp.removeInt(_updatedAtKey);
    sp.removeString(_schemaKey);
  }

  Future<void> _ensureDownloaded({
    required KmbRouteDataConfig? remote,
    required bool force,
    required void Function(double? progress)? onProgress,
  }) async {
    if (force) await delete();

    if (!await isDownloaded() || storedLastUpdate == null) {
      await _bootstrap(remote, onProgress);
    }
    await _checkAndUpdate(remote, onProgress);
  }

  Future<void> _bootstrap(
    KmbRouteDataConfig? remote,
    void Function(double? progress)? onProgress,
  ) async {
    if (remote == null || !remote.isDownloadable) {
      throw const KmbRouteDataException('KMB route data URL is not configured');
    }

    final Directory directory = await _directory();
    final File base = File('${directory.path}/base.db.tmp');
    final File newSlim = File('${directory.path}/routedata.db.new');
    try {
      await _downloadFile(
        Uri.parse(remote.downloadUrl),
        base,
        onProgress: (double? value) =>
            onProgress?.call(value == null ? null : value * 0.72),
      );
      await _closeReader();
      if (await newSlim.exists()) await newSlim.delete();
      if (_isSlimDatabase(base.path)) {
        await base.copy(newSlim.path);
      } else {
        await Isolate.run(() => _buildSlimFromBase(base.path, newSlim.path));
      }
      await _replaceDatabase(newSlim);
      final String baseline = remote.lastUpdate.isNotEmpty
          ? remote.lastUpdate
          : _fallbackBaseLastUpdate;
      _storeMetadata(baseline);
      onProgress?.call(0.78);
    } finally {
      if (await base.exists()) await base.delete();
      if (await newSlim.exists()) await newSlim.delete();
    }
  }

  Future<void> _checkAndUpdate(
    KmbRouteDataConfig? remote,
    void Function(double? progress)? onProgress,
  ) async {
    final String? lastUpdate = storedLastUpdate;
    if (lastUpdate == null) return;

    final Uri uri = _checkUri(remote, lastUpdate);
    final Map<String, dynamic> json = await _fetchJson(uri);
    final String serverLast = (json['lasttime'] ?? '').toString().trim();
    final String deltaUrl = (json['deltadataurl'] ?? '').toString().trim();

    if (deltaUrl.isEmpty) {
      if (serverLast.isNotEmpty) sp.setString(_lastUpdateKey, serverLast);
      onProgress?.call(1);
      return;
    }
    if (serverLast.isEmpty) {
      throw const KmbRouteDataException('KMB update has no lasttime');
    }

    final Directory directory = await _directory();
    final File delta = File('${directory.path}/update.xml.tmp');
    final File full = File('${directory.path}/working.db.tmp');
    final File newSlim = File('${directory.path}/routedata.db.new');
    try {
      await _downloadFile(
        Uri.parse(deltaUrl),
        delta,
        onProgress: (double? value) =>
            onProgress?.call(value == null ? null : 0.78 + value * 0.17),
      );
      await _closeReader();
      if (await full.exists()) await full.delete();
      if (await newSlim.exists()) await newSlim.delete();
      final File current = await _databaseFile();
      await Isolate.run(
        () => _buildIncrementalSlim(
          currentPath: current.path,
          fullPath: full.path,
          newSlimPath: newSlim.path,
          deltaPath: delta.path,
        ),
      );
      await _replaceDatabase(newSlim);
      _storeMetadata(serverLast);
      onProgress?.call(1);
    } finally {
      if (await delta.exists()) await delta.delete();
      if (await full.exists()) await full.delete();
      if (await newSlim.exists()) await newSlim.delete();
    }
  }

  Uri _checkUri(KmbRouteDataConfig? remote, String lastUpdate) {
    final String configured = remote?.checkUpdateUrl.trim() ?? '';
    final String base = configured.isEmpty
        ? defaultKmbRouteDataCheckUrl
        : configured;
    final Uri uri = Uri.parse(base);
    final Map<String, String> params = <String, String>{
      ...uri.queryParameters,
      'lastupdate': lastUpdate,
    };
    if (!params.containsKey('version')) params['version'] = '1.3.5';
    return uri.replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final http.Client client = _client ?? http.Client();
    try {
      final http.Response response = await client
          .get(
            uri,
            headers: const <String, String>{'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw KmbRouteDataException(
          'KMB update check failed (${response.statusCode})',
        );
      }
      final Object? decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const KmbRouteDataException(
          'KMB update check returned invalid JSON',
        );
      }
      return decoded;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<void> _downloadFile(
    Uri uri,
    File target, {
    void Function(double? progress)? onProgress,
  }) async {
    final http.Client client = _client ?? http.Client();
    try {
      final http.Request request = http.Request('GET', uri)
        ..headers['User-Agent'] = 'HKTransports'
        ..headers['Accept'] = '*/*';
      final http.StreamedResponse response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw KmbRouteDataException(
          'KMB data download failed (${response.statusCode})',
        );
      }
      final int? total = response.contentLength;
      final IOSink sink = target.openWrite();
      int received = 0;
      try {
        await for (final List<int> chunk in response.stream.timeout(
          const Duration(seconds: 90),
        )) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received == 0) {
        throw const KmbRouteDataException('Downloaded KMB data was empty');
      }
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<void> _replaceDatabase(File newSlim) async {
    await _closeReader();
    final File target = await _databaseFile();
    if (await target.exists()) await target.delete();
    await newSlim.rename(target.path);
  }

  void _storeMetadata(String lastUpdate) {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    sp.setString(_lastUpdateKey, lastUpdate);
    sp.setInt(_updatedAtKey, now);
    sp.setString(_schemaKey, _schemaVersion);
  }

  Future<KmbRouteDataReader?> _reader() async {
    final Future<KmbRouteDataReader?>? cached = _readerFuture;
    if (cached != null) return cached;
    if (!await isDownloaded()) return null;
    try {
      final File file = await _databaseFile();
      final KmbRouteDataReader reader = KmbRouteDataReader(
        sqlite3.open(file.path, mode: OpenMode.readOnly),
      );
      final Future<KmbRouteDataReader?> future =
          Future<KmbRouteDataReader?>.value(reader);
      _readerFuture = future;
      return reader;
    } catch (error) {
      debugPrint('Unable to open KMB route data: $error');
      return null;
    }
  }

  Future<void> _closeReader() async {
    final Future<KmbRouteDataReader?>? future = _readerFuture;
    _readerFuture = null;
    if (future == null) return;
    try {
      final KmbRouteDataReader? reader = await future;
      reader?.dispose();
    } catch (_) {}
  }

  Future<Directory> _directory() async {
    final Directory base =
        _directoryOverride ?? await getApplicationSupportDirectory();
    final Directory directory = Directory('${base.path}/hktransports/kmb');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _databaseFile() async {
    final Directory directory = await _directory();
    return File('${directory.path}/routedata.db');
  }
}

class KmbRouteDataReader {
  KmbRouteDataReader(this._database);

  final Database _database;

  List<String> stopLocations(RouteEntry route, int stopIndex, String language) {
    final int? bound = _kmbBound(route.boundFor(BusCompany.kmb));
    if (bound == null || !route.companies.contains(BusCompany.kmb)) {
      return const <String>[];
    }
    final ResultSet rows = _database.select(
      '''
      SELECT stop_loc1, stop_loc2, stop_loc3,
             stop_loc_chi1, stop_loc_chi2, stop_loc_chi3
      FROM kmb_stop
      WHERE route_no = ? AND bound = ? AND stop_seq = ? AND service_type = ?
      LIMIT 1
      ''',
      <Object?>[
        route.route.trim().toUpperCase(),
        bound.toString(),
        stopIndex,
        _kmbServiceType(route.serviceType),
      ],
    );
    if (rows.isEmpty) return const <String>[];
    final Row row = rows.first;
    final bool english = language == 'en';
    final List<String> values = english
        ? <String>[
            _text(row['stop_loc1']),
            _text(row['stop_loc2']),
            _text(row['stop_loc3']),
          ]
        : <String>[
            _text(row['stop_loc_chi1']),
            _text(row['stop_loc_chi2']),
            _text(row['stop_loc_chi3']),
          ];
    return values.where((String value) => value.isNotEmpty).toList();
  }

  String? serviceDescription(RouteEntry route, String language) {
    final int? bound = _kmbBound(route.boundFor(BusCompany.kmb));
    if (bound == null || !route.companies.contains(BusCompany.kmb)) {
      return null;
    }
    final ResultSet rows = _database.select(
      '''
      SELECT service_type_desc_eng, service_type_desc_chi
      FROM kmb_bound
      WHERE route_no = ? AND bound_no = ? AND service_type = ?
      LIMIT 1
      ''',
      <Object?>[
        route.route.trim().toUpperCase(),
        bound,
        _kmbServiceType(route.serviceType),
      ],
    );
    if (rows.isEmpty) return null;
    final Row row = rows.first;
    final String selected = _stripDescriptionBrackets(
      _text(
        language == 'en'
            ? row['service_type_desc_eng']
            : row['service_type_desc_chi'],
      ),
    );
    if (!_isNormalDescription(selected)) return selected;
    final String other = _stripDescriptionBrackets(
      _text(
        language == 'en'
            ? row['service_type_desc_chi']
            : row['service_type_desc_eng'],
      ),
    );
    return _isNormalDescription(other) ? null : other;
  }

  void dispose() => _database.close();
}

int? _kmbBound(String? value) {
  switch (value?.trim().toUpperCase()) {
    case 'O':
    case '1':
      return 1;
    case 'I':
    case '2':
      return 2;
    default:
      return null;
  }
}

String _kmbServiceType(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? '01' : trimmed.padLeft(2, '0');
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _stripDescriptionBrackets(String value) {
  String text = value.trim();
  final RegExpMatch? outer = RegExp(
    r'^[（(\[【]\s*(.*?)\s*[）)\]】]$',
  ).firstMatch(text);
  if (outer != null) text = outer.group(1) ?? text;
  text = text.replaceAll(RegExp(r'[（）()\[\]【】]'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isNormalDescription(String value) {
  final String text = value.trim().toLowerCase();
  return text.isEmpty ||
      text == 'normal' ||
      text == 'normal route' ||
      text == '正常' ||
      text == '正常路線';
}

bool _isSlimDatabase(String path) {
  try {
    final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final Set<String> tables = db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((Row row) => row['name'].toString())
          .toSet();
      if (!tables.contains('kmb_stop') || !tables.contains('kmb_bound')) {
        return false;
      }
      final Set<String> stopColumns = _columns(db, 'kmb_stop');
      final Set<String> boundColumns = _columns(db, 'kmb_bound');
      return <String>{
            'route_no',
            'bound',
            'stop_seq',
            'service_type',
            'stop_loc1',
            'stop_loc2',
            'stop_loc3',
            'stop_loc_chi1',
            'stop_loc_chi2',
            'stop_loc_chi3',
          }.every(stopColumns.contains) &&
          <String>{
            'route_no',
            'bound_no',
            'service_type',
            'service_type_desc_eng',
            'service_type_desc_chi',
          }.every(boundColumns.contains);
    } finally {
      db.close();
    }
  } catch (_) {
    return false;
  }
}

Set<String> _columns(Database db, String table) {
  return db
      .select('PRAGMA table_info($table)')
      .map((Row row) => row['name'].toString())
      .toSet();
}

Future<void> _buildSlimFromBase(String basePath, String slimPath) async {
  final Database base = sqlite3.open(basePath);
  try {
    final bool valid = base
        .select(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name='kmb_routestopfile_ST'",
        )
        .isNotEmpty;
    if (!valid) {
      throw const KmbRouteDataException('KMB base database has no route table');
    }
    _createSlimDatabase(base, slimPath);
  } finally {
    base.close();
  }
}

Future<void> _buildIncrementalSlim({
  required String currentPath,
  required String fullPath,
  required String newSlimPath,
  required String deltaPath,
}) async {
  final Database full = sqlite3.open(fullPath);
  try {
    full.execute(_fullStopSchema);
    full.execute(_fullBoundSchema);
    full.execute('ATTACH DATABASE ? AS old', <Object?>[currentPath]);
    full.execute('''
      INSERT INTO kmb_routestopfile_ST
        (route_no, bound, stop_seq, service_type, stop_loc1, stop_loc2,
         stop_loc3, stop_loc_chi1, stop_loc_chi2, stop_loc_chi3)
      SELECT route_no, bound, stop_seq, service_type, stop_loc1, stop_loc2,
             stop_loc3, stop_loc_chi1, stop_loc_chi2, stop_loc_chi3
      FROM old.kmb_stop
      ''');
    full.execute('''
      INSERT INTO kmb_routeboundmaster_ST
        (route_no, bound_no, service_type, service_type_desc_eng,
         service_type_desc_chi)
      SELECT route_no, bound_no, service_type, service_type_desc_eng,
             service_type_desc_chi
      FROM old.kmb_bound
      ''');
    full.execute('DETACH DATABASE old');
    full.execute(_fullStopIndexes);
    await _applyDelta(full, deltaPath);
    _createSlimDatabase(full, newSlimPath);
  } finally {
    full.close();
  }
}

void _createSlimDatabase(Database source, String slimPath) {
  final File slimFile = File(slimPath);
  if (slimFile.existsSync()) slimFile.deleteSync();
  source.execute('ATTACH DATABASE ? AS slim', <Object?>[slimPath]);
  try {
    source.execute(_slimStopSchema);
    source.execute(_slimBoundSchema);
    source.execute('''
      INSERT OR REPLACE INTO slim.kmb_stop
        (route_no, bound, stop_seq, service_type, stop_loc1, stop_loc2,
         stop_loc3, stop_loc_chi1, stop_loc_chi2, stop_loc_chi3)
      SELECT route_no, bound, stop_seq, service_type, stop_loc1, stop_loc2,
             stop_loc3, stop_loc_chi1, stop_loc_chi2, stop_loc_chi3
      FROM main.kmb_routestopfile_ST
      ''');
    source.execute('''
      INSERT OR REPLACE INTO slim.kmb_bound
        (route_no, bound_no, service_type, service_type_desc_eng,
         service_type_desc_chi)
      SELECT route_no, bound_no, service_type, service_type_desc_eng,
             service_type_desc_chi
      FROM main.kmb_routeboundmaster_ST
      ''');
  } finally {
    source.execute('DETACH DATABASE slim');
  }
  final Database slim = sqlite3.open(slimPath);
  try {
    slim.execute('VACUUM');
  } finally {
    slim.close();
  }
}

Future<void> _applyDelta(Database db, String deltaPath) async {
  db.execute('BEGIN IMMEDIATE');
  try {
    final RegExp allowed = RegExp(
      r'^\s*(?:insert\s+into|update|delete\s+from)\s+(?:kmb_routestopfile_ST|kmb_routeboundmaster_ST)\b',
      caseSensitive: false,
    );
    final Stream<String> stream = File(
      deltaPath,
    ).openRead().transform(utf8.decoder);
    String pending = '';
    bool inCdata = false;
    await for (final String chunk in stream) {
      pending += chunk;
      while (true) {
        if (!inCdata) {
          final int start = pending.indexOf('<![CDATA[');
          if (start < 0) {
            if (pending.length > 8) {
              pending = pending.substring(pending.length - 8);
            }
            break;
          }
          pending = pending.substring(start + 9);
          inCdata = true;
        } else {
          final int end = pending.indexOf(']]>');
          if (end < 0) break;
          final String sql = pending.substring(0, end).trim();
          pending = pending.substring(end + 3);
          inCdata = false;
          if (sql.isEmpty || !allowed.hasMatch(sql)) continue;
          try {
            db.execute(sql);
          } catch (error) {
            throw KmbRouteDataException(
              'KMB delta statement failed: $error\n${sql.substring(0, sql.length.clamp(0, 180))}',
            );
          }
        }
      }
    }
    db.execute('COMMIT');
  } catch (error) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {}
    rethrow;
  }
}
