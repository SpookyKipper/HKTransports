import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class CitybusEtaStatus {
  const CitybusEtaStatus({
    this.statusZh,
    this.statusEn,
    this.distanceKm,
    this.timeMinutes,
    this.timeText,
    this.minutesText,
  });

  final String? statusZh;
  final String? statusEn;
  final double? distanceKm;

  /// Minutes after midnight reported by nwp3, for matching open-data ETAs.
  final int? timeMinutes;

  /// Literal clock and minutes text from nwp3, for display.
  final String? timeText;
  final String? minutesText;
}

/// Reads Citybus' proprietary nwp3 ETA popup.
///
/// Route ETA display consumes these rows directly when the proprietary Citybus
/// ETA option is enabled. The literal time and minutes fields are preserved;
/// time is also parsed for ordering and upstream comparisons.
class CitybusEtaStatusClient {
  CitybusEtaStatusClient({Duration timeout = const Duration(seconds: 20)})
    : _timeout = timeout;

  static const String _host = 'mobile.citybus.com.hk';
  static const String _basePath = '/nwp3';
  static const String _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';
  static const String _secChUa =
      '"Chromium";v="158", "Not.A/Brand";v="24", "HeadlessChrome";v="158"';

  static const Map<String, String> _homeHeaders = <String, String>{
    'User-Agent': _ua,
    'Accept-Language': 'zh-Hant-HK',
    'Upgrade-Insecure-Requests': '1',
    'Sec-CH-UA': _secChUa,
    'Sec-CH-UA-Mobile': '?0',
    'Sec-CH-UA-Platform': '"Android"',
    'Accept-Encoding': 'identity',
    'Connection': 'keep-alive',
  };

  static const Map<String, String> _xhrHeaders = <String, String>{
    'User-Agent': _ua,
    'Accept': '*/*',
    'Accept-Language': 'zh-Hant-HK',
    'Referer': 'https://mobile.citybus.com.hk/nwp3/',
    'Sec-CH-UA': _secChUa,
    'Sec-CH-UA-Mobile': '?0',
    'Sec-CH-UA-Platform': '"Android"',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'Accept-Encoding': 'identity',
    'Connection': 'keep-alive',
  };

  final Duration _timeout;

  // Reuse the nwp3 session until a request indicates it has expired or the
  // hashed result endpoint has changed.
  String? _ssid;
  String? _resultPath;
  Map<String, String> _cookies = const <String, String>{};
  Future<void> _queue = Future<void>.value();

  bool get _hasSession =>
      _ssid != null && _resultPath != null && _cookies.isNotEmpty;

  Future<List<CitybusEtaStatus>> fetch(CitybusEtaArguments args) {
    final Completer<List<CitybusEtaStatus>> completer =
        Completer<List<CitybusEtaStatus>>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await _fetchWithRetry(args));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<List<CitybusEtaStatus>> _fetchWithRetry(
    CitybusEtaArguments args,
  ) async {
    Object? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      final bool hadSession = _hasSession;
      try {
        final String body = await _fetchBody(args, bootstrap: !hadSession);
        return parseCitybusEtaStatuses(body);
      } on _Nwp3ConnectionException catch (error) {
        lastError = error;
        _clearSession();
      } on _Nwp3Exception catch (error) {
        lastError = error;
        if (!hadSession) break;
        _clearSession();
      }
    }
    if (lastError != null) {
      debugPrint('Citybus nwp3 ETA status failed: $lastError');
    }
    return const <CitybusEtaStatus>[];
  }

  Future<String> _fetchBody(
    CitybusEtaArguments args, {
    required bool bootstrap,
  }) async {
    _HttpConnection? connection;
    try {
      final SecureSocket socket = await SecureSocket.connect(
        _host,
        443,
        timeout: _timeout,
        supportedProtocols: const <String>['http/1.1'],
      );
      connection = _HttpConnection(
        socket,
        timeout: _timeout,
        cookies: _cookies,
      );

      String ssid;
      String resultPath;
      if (bootstrap) {
        final _HttpResponse home = await connection.get(
          _uri('$_basePath/'),
          _homeHeaders,
        );
        _requireOk(home);
        final String? parsedSsid = _firstMatch(home.text, <RegExp>[
          RegExp(r'''var\s+ssid\s*=\s*["']([0-9a-fA-F]+)["']'''),
          RegExp(r'fb\.php\?ssid=([0-9a-fA-F]+)'),
        ]);
        if (parsedSsid == null || parsedSsid.isEmpty) {
          throw const _Nwp3Exception('nwp3 homepage did not contain an ssid');
        }
        ssid = parsedSsid;
        resultPath = await _fetchResultScriptPath(connection, ssid);
      } else {
        ssid = _ssid!;
        resultPath = _resultPath!;
      }

      final _HttpResponse menu = await connection.get(
        _uri('$_basePath/menu2.php', <String, String>{
          'l': '0',
          'info': '',
          'ssid': ssid,
          'sysid': '1',
        }),
        _xhrHeaders,
      );
      _requireOk(menu);

      final _HttpResponse popup = await connection.get(
        _uri('$_basePath/getrouteinstop.php', <String, String>{
          'stopid': args.stopId,
          'lat': args.lat.toString(),
          'lon': args.lon.toString(),
          'seq': args.seq.toString(),
          'rdv': args.rdv,
          'bound': args.bound,
          'eta': 'Y',
          'l': '0',
          'ref': '1',
          'altLat': args.altLat,
          'altLon': args.altLon,
          'ssid': ssid,
          'sysid': '3',
        }),
        _xhrHeaders,
      );
      _requireOk(popup);
      final CitybusNwp3Registration? registration =
          parseCitybusNwp3Registration(popup.text);
      if (registration == null) {
        throw const _Nwp3Exception('nwp3 popup did not contain a registration');
      }

      final _HttpResponse blank = await connection.get(
        _uri('$_basePath/blank.php', <String, String>{
          'ssid': ssid,
          'sysid': '4',
        }),
        _xhrHeaders,
      );
      _requireOk(blank);

      final _HttpResponse register = await connection.get(
        _uri('$_basePath/${registration.path}', <String, String>{
          'info': registration.info,
          'ssid': ssid,
          'sysid': '5',
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        }),
        <String, String>{..._xhrHeaders, 'X-Requested-With': 'XMLHttpRequest'},
      );
      _requireOk(register);
      if (!register.text.trim().contains('OK')) {
        throw const _Nwp3Exception('nwp3 registration was rejected');
      }

      final _HttpResponse checkCall = await connection.get(
        _uri('$_basePath/checkCall.php', <String, String>{
          'type': 'eta',
          'ssid': ssid,
          'sysid': '6',
        }),
        _xhrHeaders,
      );
      _requireOk(checkCall);
      final String? checkValue = _firstMatch(checkCall.text, <RegExp>[
        RegExp(r'checkValue=([0-9a-fA-F]+)'),
      ]);
      if (checkValue == null || checkValue.isEmpty) {
        throw const _Nwp3Exception('nwp3 checkCall did not return a value');
      }

      final _HttpResponse checkSuccess = await connection.get(
        _uri('$_basePath/checkSuccess.php', <String, String>{
          'type': 'eta',
          'checkValue': checkValue,
          'ssid': ssid,
          'sysid': '7',
        }),
        _xhrHeaders,
      );
      _requireOk(checkSuccess);
      if (!checkSuccess.text.contains('recaptcha_check_called = true')) {
        throw const _Nwp3Exception('nwp3 verification did not complete');
      }

      final ({String body, String path}) result = await _resultBody(
        connection,
        ssid,
        resultPath,
      );
      _ssid = ssid;
      _resultPath = result.path;
      _cookies = Map<String, String>.unmodifiable(connection.cookies);
      return result.body;
    } on _Nwp3Exception {
      rethrow;
    } on IOException catch (error) {
      throw _Nwp3ConnectionException('$error');
    } on TimeoutException catch (error) {
      throw _Nwp3ConnectionException('$error');
    } finally {
      await connection?.close();
    }
  }

  Future<String> _fetchResultScriptPath(
    _HttpConnection connection,
    String ssid,
  ) async {
    final _HttpResponse response = await connection.get(
      _uri('$_basePath/fb.php', <String, String>{'ssid': ssid}),
      _xhrHeaders,
    );
    _requireOk(response);
    final String? resultPath = parseCitybusNwp3ResultPath(response.text);
    if (resultPath == null) {
      throw const _Nwp3Exception(
        'nwp3 script did not contain a result endpoint',
      );
    }
    return resultPath;
  }

  Future<({String body, String path})> _resultBody(
    _HttpConnection connection,
    String ssid,
    String resultPath,
  ) async {
    String path = resultPath;
    _HttpResponse response = await _getResult(connection, ssid, path);
    if (response.statusCode == 404 || response.statusCode == 410) {
      path = await _fetchResultScriptPath(connection, ssid);
      response = await _getResult(connection, ssid, path);
    }
    _requireOk(response);
    return (body: response.text, path: path);
  }

  void _clearSession() {
    _ssid = null;
    _resultPath = null;
    _cookies = const <String, String>{};
  }

  Future<_HttpResponse> _getResult(
    _HttpConnection connection,
    String ssid,
    String path,
  ) {
    return connection.get(
      _uri('$_basePath/$path', <String, String>{
        'l': '0',
        'ssid': ssid,
        'sysid': '9',
      }),
      _xhrHeaders,
    );
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri(
      scheme: 'https',
      host: _host,
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  void _requireOk(_HttpResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _Nwp3Exception('nwp3 request returned ${response.statusCode}');
    }
  }

  String? _firstMatch(String input, List<RegExp> patterns) {
    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(input);
      if (match != null) return match.group(1);
    }
    return null;
  }
}

class CitybusNwp3Registration {
  const CitybusNwp3Registration({required this.path, required this.info});

  final String path;
  final String info;
}

CitybusNwp3Registration? parseCitybusNwp3Registration(String html) {
  final RegExpMatch? match = RegExp(
    r'''(auto_[0-9a-fA-F]+\.php)\?info=([^"']+)''',
  ).firstMatch(html);
  final String? path = match?.group(1);
  final String? rawInfo = match?.group(2);
  if (path == null || rawInfo == null) return null;
  return CitybusNwp3Registration(
    path: path,
    info: _decodeQueryComponent(rawInfo),
  );
}

String? parseCitybusNwp3ResultPath(String script) {
  final RegExpMatch? match = RegExp(
    r'function\s+showeta\s*\(\s*\)\s*\{[\s\S]*?(auto_[0-9a-fA-F]+\.php)\?l=',
  ).firstMatch(script);
  return match?.group(1);
}

String _decodeQueryComponent(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

List<CitybusEtaStatus> parseCitybusEtaStatuses(String body) {
  final String html = body.replaceFirst('\uFEFF', '').trim();
  if (html.isEmpty) return const <CitybusEtaStatus>[];
  if (html.contains('未能提供預計抵站時間')) {
    return const <CitybusEtaStatus>[];
  }

  final Document document = html_parser.parse(html);
  final Element? list = document.querySelector('#nextbus_listitem');
  if (list == null) return const <CitybusEtaStatus>[];

  final List<CitybusEtaStatus> statuses = <CitybusEtaStatus>[];
  for (final Element table in list.children.where(
    (Element element) => element.localName == 'table',
  )) {
    final List<Element> cells = table
        .querySelectorAll('td')
        .where((Element cell) => cell.querySelector('table') == null)
        .toList(growable: false);
    String? destination;
    String? statusText;
    String? minutesText;
    String? timeText;
    int? timeMinutes;
    for (final Element cell in cells) {
      final String text = _cleanText(cell.text);
      if (text.isEmpty) continue;
      if (timeMinutes == null) {
        final int? parsedTime = _parseTimeMinutes(text);
        if (parsedTime != null) {
          timeMinutes = parsedTime;
          timeText = text;
          continue;
        }
      }
      if (destination == null &&
          (text.startsWith('往:') ||
              text.startsWith('往：') ||
              text.toLowerCase().startsWith('to:'))) {
        destination = text;
        continue;
      }
      if (minutesText == null) {
        final RegExpMatch? minutes = _minutesPattern.firstMatch(text);
        if (minutes != null) {
          minutesText = minutes.group(0);
          final String remainder = text
              .replaceRange(minutes.start, minutes.end, '')
              .trim();
          if (remainder.isNotEmpty) statusText ??= remainder;
          continue;
        }
        if (RegExp(r'^\d+$').hasMatch(text)) {
          minutesText = text;
          continue;
        }
      }
      statusText ??= text;
    }
    if ((statusText == null || statusText.isEmpty) &&
        minutesText == null &&
        timeText == null) {
      continue;
    }
    String? normalizedStatus = statusText;
    if (normalizedStatus != null) {
      normalizedStatus = _normalizeStatusText(normalizedStatus);
    }

    double? distanceKm;
    final String statusForDistance = normalizedStatus ?? '';
    final RegExpMatch? distance = RegExp(
      r'距離\s*[:：]?\s*([0-9]+(?:\.[0-9]+)?)\s*公里',
    ).firstMatch(statusForDistance);
    if (distance != null) {
      distanceKm = double.tryParse(distance.group(1) ?? '');
      normalizedStatus = _normalizeStatusText(
        statusForDistance.replaceRange(distance.start, distance.end, ''),
      );
    }

    final String? statusZh =
        normalizedStatus == null || normalizedStatus.isEmpty
        ? null
        : normalizedStatus;
    final String? statusEn = statusZh == null
        ? null
        : _translateStatus(statusZh);
    if (statusZh == null && distanceKm == null && minutesText == null) {
      continue;
    }
    statuses.add(
      CitybusEtaStatus(
        statusZh: statusZh,
        statusEn: statusEn,
        distanceKm: distanceKm,
        timeMinutes: timeMinutes,
        timeText: timeText,
        minutesText: minutesText,
      ),
    );
    if (statuses.length >= 3) break;
  }
  return statuses;
}

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final RegExp _minutesPattern = RegExp(
  r'(?:少於|<|＜)?\s*\d+\s*(?:分鐘|分|minutes|minute|mins|min)',
  caseSensitive: false,
);

int? _parseTimeMinutes(String value) {
  final RegExpMatch? match = RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final int? hour = int.tryParse(match.group(1) ?? '');
  final int? minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String _stripOperatorPrefix(String status) {
  return status
      .replaceFirst(RegExp(r'^(?:城巴|Citybus)\s+', caseSensitive: false), '')
      .trim();
}

String _normalizeStatusText(String status) {
  return _stripOperatorPrefix(status)
      .replaceFirst(RegExp(r'^[,，、;；:：·\-\s]+'), '')
      .replaceFirst(RegExp(r'[,，、;；:：·\-\s]+$'), '')
      .trim();
}

String _translateStatus(String status) {
  return switch (status) {
    '未開出' => 'Not yet departed',
    '正在前往' => 'En route',
    '正在上落客' => 'Boarding / alighting',
    '已到站' => 'Arrived',
    '即將到達' => 'Arriving',
    '即將開出' => 'Departing soon',
    _ => status,
  };
}

class _HttpResponse {
  const _HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final Uint8List body;

  String get text => utf8.decode(body, allowMalformed: true);
}

class _HttpConnection {
  _HttpConnection(
    this._socket, {
    required this.timeout,
    Map<String, String> cookies = const <String, String>{},
  }) : _iterator = StreamIterator<List<int>>(_socket),
       _cookies = Map<String, String>.of(cookies);

  final SecureSocket _socket;
  final Duration timeout;
  final StreamIterator<List<int>> _iterator;
  final List<int> _buffer = <int>[];
  final Map<String, String> _cookies;
  bool _closed = false;

  Map<String, String> get cookies => Map<String, String>.unmodifiable(_cookies);

  Future<_HttpResponse> get(Uri uri, Map<String, String> headers) async {
    final String target = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final Map<String, String> requestHeaders = <String, String>{
      ...headers,
      'Host': uri.host,
      'Accept-Encoding': headers['Accept-Encoding'] ?? 'identity',
      'Connection': headers['Connection'] ?? 'keep-alive',
    };
    if (_cookies.isNotEmpty) {
      requestHeaders['Cookie'] = _cookies.entries
          .map(
            (MapEntry<String, String> entry) => '${entry.key}=${entry.value}',
          )
          .join('; ');
    }
    final StringBuffer request = StringBuffer()
      ..write('GET ')
      ..write(target)
      ..write(' HTTP/1.1\r\n');
    for (final MapEntry<String, String> header in requestHeaders.entries) {
      request
        ..write(header.key)
        ..write(': ')
        ..write(header.value)
        ..write('\r\n');
    }
    request.write('\r\n');
    _socket.add(utf8.encode(request.toString()));
    await _socket.flush();

    final String statusLine = await _readLine();
    final List<String> statusParts = statusLine.split(' ');
    final int? statusCode = statusParts.length < 2
        ? null
        : int.tryParse(statusParts[1]);
    if (statusCode == null) {
      throw _Nwp3ConnectionException('Invalid nwp3 status line: $statusLine');
    }

    final Map<String, List<String>> responseHeaders = <String, List<String>>{};
    while (true) {
      final String line = await _readLine();
      if (line.isEmpty) break;
      final int colon = line.indexOf(':');
      if (colon <= 0) continue;
      final String name = line.substring(0, colon).trim().toLowerCase();
      final String value = line.substring(colon + 1).trim();
      responseHeaders.putIfAbsent(name, () => <String>[]).add(value);
      if (name == 'set-cookie') _storeCookie(value);
    }

    final String? transferEncoding = responseHeaders['transfer-encoding']
        ?.join(',')
        .toLowerCase();
    final int? contentLength = int.tryParse(
      responseHeaders['content-length']?.firstOrNull ?? '',
    );

    Uint8List body;
    if (transferEncoding != null && transferEncoding.contains('chunked')) {
      body = await _readChunked();
    } else if (contentLength != null) {
      body = await _readExact(contentLength);
    } else {
      body = Uint8List(0);
    }
    return _HttpResponse(
      statusCode: statusCode,
      headers: responseHeaders,
      body: body,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _iterator.cancel();
    } catch (_) {}
    try {
      await _socket.close();
    } catch (_) {}
  }

  void _storeCookie(String raw) {
    final String pair = raw.split(';').first.trim();
    final int equals = pair.indexOf('=');
    if (equals <= 0) return;
    final String name = pair.substring(0, equals).trim();
    final String value = pair.substring(equals + 1).trim();
    if (name.isEmpty) return;
    if (value.isEmpty) {
      _cookies.remove(name);
    } else {
      _cookies[name] = value;
    }
  }

  Future<Uint8List> _readChunked() async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    while (true) {
      final String sizeLine = await _readLine();
      final String sizeText = sizeLine.split(';').first.trim();
      final int? size = int.tryParse(sizeText, radix: 16);
      if (size == null) {
        throw _Nwp3Exception('Invalid nwp3 chunk size: $sizeLine');
      }
      if (size == 0) {
        while ((await _readLine()).isNotEmpty) {}
        break;
      }
      builder.add(await _readExact(size));
      final Uint8List crlf = await _readExact(2);
      if (crlf.length != 2 || crlf[0] != 13 || crlf[1] != 10) {
        throw const _Nwp3Exception('Invalid nwp3 chunk terminator');
      }
    }
    return builder.takeBytes();
  }

  Future<Uint8List> _readExact(int length) async {
    if (length == 0) return Uint8List(0);
    while (_buffer.length < length) {
      if (!await _fill()) {
        throw const _Nwp3ConnectionException('nwp3 connection closed early');
      }
    }
    final Uint8List result = Uint8List.fromList(_buffer.sublist(0, length));
    _buffer.removeRange(0, length);
    return result;
  }

  Future<String> _readLine() async {
    while (true) {
      for (int index = 0; index + 1 < _buffer.length; index++) {
        if (_buffer[index] == 13 && _buffer[index + 1] == 10) {
          final String line = utf8.decode(
            _buffer.sublist(0, index),
            allowMalformed: true,
          );
          _buffer.removeRange(0, index + 2);
          return line;
        }
      }
      if (!await _fill()) {
        throw const _Nwp3ConnectionException(
          'nwp3 connection closed before headers',
        );
      }
    }
  }

  Future<bool> _fill() async {
    try {
      final bool hasNext = await _iterator.moveNext().timeout(timeout);
      if (!hasNext) return false;
      _buffer.addAll(_iterator.current);
      return true;
    } on TimeoutException {
      throw const _Nwp3ConnectionException('nwp3 response timed out');
    } on SocketException catch (error) {
      throw _Nwp3ConnectionException('$error');
    } on IOException catch (error) {
      throw _Nwp3ConnectionException('$error');
    }
  }
}

class _Nwp3Exception implements Exception {
  const _Nwp3Exception(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Nwp3ConnectionException implements Exception {
  const _Nwp3ConnectionException(this.message);

  final String message;

  @override
  String toString() => message;
}
