import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/dataStore/objectbox.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const String busDataBaseUrl = 'https://data.hktransports.spookysrv.com';
const String busDataSchema = 'route-fare-list-v1';

class BusDataUpdater {
  static const String _fileName = 'routeFareList.min.json';

  Future<Directory> _dataDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory dir = Directory('${support.path}/hktransports/busdb');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> dataFile() async {
    final Directory dir = await _dataDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> backupFile() async {
    final Directory dir = await _dataDirectory();
    return File('${dir.path}/$_fileName.bak');
  }

  String? get storedMd5 => sp.getString('busDb.md5');

  int? get lastUpdateSeconds => sp.getInt('busDb.updateTime');

  int? get lastCheckSeconds => sp.getInt('busDb.lastCheck');

  DateTime? get lastUpdate {
    final int? value = lastUpdateSeconds;
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  String? get storedSchema => sp.getString('busDb.schema');

  bool get hasData {
    return lastUpdateSeconds != null && storedMd5 != null;
  }

  Future<BusDatabase?> loadCached() async {
    final File file = await dataFile();
    final File backup = await backupFile();
    for (final File candidate in [file, backup]) {
      if (!await candidate.exists()) continue;
      try {
        final String raw = await candidate.readAsString();
        final BusDatabase db = await compute(_parseDatabase, raw);
        if (_isValid(db)) {
          if (!identical(candidate, file) && await file.exists() == false) {
            await candidate.copy(file.path);
          }
          return db;
        }
      } catch (error) {
        debugPrint('Unable to parse bus database: $error');
      }
    }
    return null;
  }

  Future<String?> fetchRemoteMd5() async {
    final Uri uri = Uri.parse('$busDataBaseUrl/routeFareList.md5');
    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return response.body.trim();
  }

  Future<bool> hasUpdate() async {
    final String? remote = await fetchRemoteMd5();
    if (remote == null) return false;
    return remote != storedMd5;
  }

  Future<BusDatabase> download({
    void Function(double? progress)? onProgress,
  }) async {
    final File target = await dataFile();
    final File backup = await backupFile();
    final File temp = File('${target.path}.tmp');
    final http.Client client = http.Client();
    try {
      final http.Request request = http.Request(
        'GET',
        Uri.parse('$busDataBaseUrl/routeFareList.min.json'),
      );
      final http.StreamedResponse response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Data download failed: ${response.statusCode}');
      }
      final int? total = response.contentLength;
      final BytesBuilder builder = BytesBuilder(copy: false);
      int received = 0;
      await for (final List<int> chunk in response.stream) {
        builder.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          onProgress?.call(received / total);
        }
      }
      onProgress?.call(1);
      final Uint8List bytes = builder.takeBytes();
      final String md5 = md5Of(bytes);
      final String? expected = await fetchRemoteMd5();
      if (expected != null && expected != md5) {
        throw const FormatException('Downloaded data checksum does not match');
      }
      final BusDatabase db = await compute(_parseDatabase, utf8.decode(bytes));
      if (!_isValid(db)) {
        throw const FormatException('Downloaded data is incomplete');
      }
      if (await target.exists()) {
        if (await backup.exists()) {
          await backup.delete();
        }
        await target.rename(backup.path);
      }
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(target.path);
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      sp.setString('busDb.md5', md5);
      sp.setInt('busDb.updateTime', now);
      sp.setInt('busDb.lastCheck', now);
      sp.setString('busDb.schema', busDataSchema);
      return db;
    } finally {
      client.close();
      if (await temp.exists()) {
        await temp.delete();
      }
    }
  }

  void markChecked() {
    sp.setInt('busDb.lastCheck', DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  static const Duration completelyOutdatedAfter = Duration(days: 7);

  bool get _isValidSchema => storedSchema == busDataSchema;

  bool get isCompletelyOutdated {
    if (!hasData || !_isValidSchema) return true;
    final DateTime? updated = lastUpdate;
    if (updated == null) return true;
    return DateTime.now().difference(updated) > completelyOutdatedAfter;
  }

  Future<bool> shouldAutoCheck(int intervalHours) async {
    if (!_isValidSchema) return true;
    final int? lastFetch = lastUpdateSeconds;
    if (lastFetch == null) return true;
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int interval = intervalHours * 3600;
    if (now - lastFetch < interval) return false;
    final int? lastCheck = lastCheckSeconds;
    if (lastCheck != null && now - lastCheck < interval) return false;
    return true;
  }

  static String md5Of(List<int> bytes) {
    return md5.convert(bytes).toString();
  }
}

Future<BusDatabase> _parseDatabase(String raw) async {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Route data is not an object');
  }
  return BusDatabase.fromJson(decoded);
}

bool _isValid(BusDatabase db) {
  return db.routesByKey.length > 1000 &&
      db.stops.length > 10000 &&
      db.stopMap.isNotEmpty &&
      db.holidays.isNotEmpty &&
      db.serviceDayMap.isNotEmpty;
}

extension RouteUpdateCheck on BusDataUpdater {
  Future<DateTime?> fetchRouteUpdatedAt(RouteEntry route) async {
    final String name =
        '${route.route}+${route.serviceType}+${route.orig.en}+${route.dest.en}'
            .toUpperCase()
            .replaceAll(RegExp(r'''[\\/:*?"<>|\]']'''), '');
    final Uri uri = Uri.parse(
      '$busDataBaseUrl/route-ts/${Uri.encodeComponent(name)}',
    );
    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final int? seconds = int.tryParse(response.body.trim());
      if (seconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {
      return null;
    }
  }
}
