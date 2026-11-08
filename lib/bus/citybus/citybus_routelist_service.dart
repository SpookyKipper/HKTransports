import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/dataStore/objectbox.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class CitybusRoutelistService {
  CitybusRoutelistService._();

  static final CitybusRoutelistService instance = CitybusRoutelistService._();

  static const Duration _timeout = Duration(seconds: 60);
  static const String _host = 'mobile.citybus.com.hk';
  static const String _downloadPath = '/api6/getroutelist_download_v3.php';
  static const String _updatedAtKey = 'citybus.routelist.updatedAt';
  static const List<String> _locales = <String>['0', '1'];
  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
    'Accept': '*/*',
    'Referer': 'https://mobile.citybus.com.hk/',
  };

  final Map<String, Future<CitybusRoutelistReader?>> _readers =
      <String, Future<CitybusRoutelistReader?>>{};
  Future<void>? _downloadFuture;

  DateTime? get storedUpdatedAt {
    final int? seconds = sp.getInt(_updatedAtKey);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  Future<bool> get isDownloaded async {
    for (final String locale in _locales) {
      final File file = await _databaseFile(locale);
      if (!await _isSqliteFile(file)) return false;
    }
    return true;
  }

  Future<int> storedBytes() async {
    int total = 0;
    for (final String locale in _locales) {
      final File file = await _databaseFile(locale);
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  Future<void> ensureDownloaded({
    bool force = false,
    void Function(double? progress)? onProgress,
  }) {
    final Future<void>? running = _downloadFuture;
    if (running != null) return running;
    final Future<void> future = _ensureDownloaded(
      force: force,
      onProgress: onProgress,
    );
    _downloadFuture = future;
    return future.whenComplete(() {
      if (identical(_downloadFuture, future)) _downloadFuture = null;
    });
  }

  Future<CitybusRouteData?> routeData(RouteEntry route, String language) async {
    final CitybusRoutelistReader? reader = await _readerFor(language);
    return reader?.routeData(route, language);
  }

  Future<CitybusStopData?> stopData(
    RouteEntry route,
    int stopIndex,
    String language,
  ) async {
    final CitybusRoutelistReader? reader = await _readerFor(language);
    return reader?.stopData(route, stopIndex, language);
  }

  Future<String?> routeName(RouteEntry route, String language) async {
    final CitybusRoutelistReader? reader = await _readerFor(language);
    return reader?.routeName(route, language);
  }

  Future<List<String>> remarkInfoKeys(RouteEntry route) async {
    final CitybusRoutelistReader? zh = await _readerFor('zh');
    final List<String> keys = zh?.remarkInfoKeys(route) ?? const <String>[];
    if (keys.isNotEmpty) return keys;
    final CitybusRoutelistReader? en = await _readerFor('en');
    return en?.remarkInfoKeys(route) ?? const <String>[];
  }

  Future<void> delete() async {
    await _closeReaders();
    final Directory directory = await _directory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    sp.setInt(_updatedAtKey, 0);
    await _deleteLegacyRouteNameCache();
  }

  Future<void> _ensureDownloaded({
    required bool force,
    void Function(double? progress)? onProgress,
  }) async {
    final Directory directory = await _directory();
    await _deleteLegacyRouteNameCache();
    if (!force && await isDownloaded) return;

    final List<File> zips = <File>[];
    final Map<String, File> pendingDatabases = <String, File>{};
    try {
      for (int index = 0; index < _locales.length; index++) {
        final String locale = _locales[index];
        final File zip = File('${directory.path}/routelist$locale.zip.tmp');
        zips.add(zip);
        await _downloadZip(
          locale,
          zip,
          onProgress: (double? fraction) {
            if (fraction == null) {
              onProgress?.call(null);
            } else {
              onProgress?.call((index + fraction) / _locales.length);
            }
          },
        );
        final Uint8List database = extractCitybusDatabaseBytes(
          await zip.readAsBytes(),
          locale,
        );
        final File pending = File('${directory.path}/routelist$locale.db.new');
        await pending.writeAsBytes(database, flush: true);
        pendingDatabases[locale] = pending;
      }

      await _closeReaders();
      for (final String locale in _locales) {
        final File pending = pendingDatabases[locale]!;
        final File target = await _databaseFile(locale);
        if (await target.exists()) await target.delete();
        await pending.rename(target.path);
      }
      sp.setInt(_updatedAtKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
      onProgress?.call(1);
    } finally {
      for (final File zip in zips) {
        if (await zip.exists()) await zip.delete();
      }
      for (final File pending in pendingDatabases.values) {
        if (await pending.exists()) await pending.delete();
      }
    }
  }

  Future<void> _downloadZip(
    String locale,
    File target, {
    void Function(double? progress)? onProgress,
  }) async {
    final Uri uri = Uri.https(_host, _downloadPath, <String, String>{
      'l': locale,
    });
    final http.Client client = http.Client();
    try {
      final http.Request request = http.Request('GET', uri)
        ..headers.addAll(_headers);
      final http.StreamedResponse response = await client
          .send(request)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw HttpException(
          'Citybus routelist download failed: ${response.statusCode}',
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
        throw const FormatException('Citybus routelist download was empty');
      }
    } finally {
      client.close();
    }
  }

  Future<CitybusRoutelistReader?> _readerFor(String language) {
    final String locale = language == 'en' ? '1' : '0';
    return _readers.putIfAbsent(locale, () => _openReader(locale));
  }

  Future<CitybusRoutelistReader?> _openReader(String locale) async {
    final File file = await _databaseFile(locale);
    if (!await _isSqliteFile(file)) return null;
    try {
      final Database database = sqlite3.open(file.path);
      return CitybusRoutelistReader(database);
    } catch (error) {
      debugPrint('Unable to open Citybus routelist database: $error');
      return null;
    }
  }

  Future<void> _closeReaders() async {
    final List<MapEntry<String, Future<CitybusRoutelistReader?>>> readers =
        _readers.entries.toList(growable: false);
    _readers.clear();
    for (final MapEntry<String, Future<CitybusRoutelistReader?>> entry
        in readers) {
      try {
        final CitybusRoutelistReader? reader = await entry.value;
        reader?.dispose();
      } catch (error) {
        debugPrint('Unable to close Citybus routelist database: $error');
      }
    }
  }

  Future<Directory> _directory() async {
    final Directory support = await getApplicationSupportDirectory();
    final Directory directory = Directory(
      '${support.path}/hktransports/citybus',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _databaseFile(String locale) async {
    final Directory directory = await _directory();
    return File('${directory.path}/routelist$locale.db');
  }

  Future<void> _deleteLegacyRouteNameCache() async {
    try {
      final Directory support = await getApplicationSupportDirectory();
      final File legacy = File(
        '${support.path}/hktransports/cache/citybus_route_names.json',
      );
      if (await legacy.exists()) await legacy.delete();
    } catch (error) {
      debugPrint('Unable to delete legacy Citybus route name cache: $error');
    }
  }
}

/// Extracts and validates the SQLite database from a Citybus routelist ZIP.
Uint8List extractCitybusDatabaseBytes(List<int> zipBytes, String locale) {
  final Archive archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
  final String expected = 'routelist$locale.db';
  ArchiveFile? databaseFile;
  for (final ArchiveFile file in archive.files) {
    if (!file.isFile) continue;
    final String name = file.name.split(RegExp(r'[/\\]')).last;
    if (name == expected) {
      databaseFile = file;
      break;
    }
  }
  if (databaseFile == null) {
    throw FormatException('Citybus routelist ZIP does not contain $expected');
  }
  final Uint8List? bytes = databaseFile.readBytes();
  if (bytes == null || !isCitybusDatabaseBytes(bytes)) {
    throw const FormatException('Citybus routelist database is invalid');
  }
  return bytes;
}

bool isCitybusDatabaseBytes(List<int> bytes) {
  const String header = 'SQLite format 3\u0000';
  if (bytes.length < header.length) return false;
  for (int index = 0; index < header.length; index++) {
    if (bytes[index] != header.codeUnitAt(index)) return false;
  }
  return true;
}

Future<bool> _isSqliteFile(File file) async {
  if (!await file.exists()) return false;
  if (await file.length() < 1024) return false;
  RandomAccessFile? reader;
  try {
    reader = await file.open();
    return isCitybusDatabaseBytes(await reader.read(16));
  } catch (error) {
    debugPrint('Unable to validate Citybus routelist database: $error');
    return false;
  } finally {
    await reader?.close();
  }
}
