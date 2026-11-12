import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class NlbTimetable {
  const NlbTimetable({required this.sections, required this.notes});

  final List<NlbTimetableSection> sections;
  final List<String> notes;
}

class NlbTimetableSection {
  const NlbTimetableSection({required this.title, required this.rows});

  final String title;
  final List<NlbTimetableRow> rows;
}

class NlbTimetableRow {
  const NlbTimetableRow({required this.time, required this.note});

  final String time;
  final String note;
}

class NlbTimetableService {
  NlbTimetableService({http.Client? client}) : _client = client;

  static final NlbTimetableService instance = NlbTimetableService();

  static const Duration _cacheTtl = Duration(hours: 1);
  static const String _selector =
      'section.space-y-4:nth-child(2) > div:nth-child(2) '
      '> div:nth-child(1) > div:nth-child(1)';

  final http.Client? _client;
  final Map<String, _CachedTimetable> _cache = <String, _CachedTimetable>{};
  Future<SecurityContext>? _securityContextFuture;

  Future<NlbTimetable?> fetch(
    RouteEntry route,
    String language, {
    bool force = false,
  }) async {
    final String key = '${route.route}|${language == 'en' ? 'en' : 'tc'}';
    final _CachedTimetable? cached = _cache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.timetable;
    }
    final String languagePath = language == 'en' ? 'en' : 'tc';
    final Uri uri = Uri.https(
      'www.nlb.com.hk',
      '/$languagePath/route/${Uri.encodeComponent(route.route)}',
    );
    try {
      final String? body = await _fetchHtml(uri, language);
      if (body == null) return null;
      final NlbTimetable? timetable = parseNlbTimetable(body);
      if (timetable == null) return null;
      _cache[key] = _CachedTimetable(
        timetable: timetable,
        fetchedAt: DateTime.now(),
      );
      return timetable;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchHtml(Uri uri, String language) async {
    final http.Client? injected = _client;
    if (injected != null) {
      final http.Response response = await injected
          .get(
            uri,
            headers: <String, String>{
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': language == 'en' ? 'en' : 'zh-Hant-HK',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    }
    return _fetchHtmlRaw(uri, language);
  }

  Future<String?> _fetchHtmlRaw(Uri uri, String language) async {
    final SecurityContext context = await (_securityContextFuture ??=
        _createSecurityContext());
    final SecureSocket socket = await SecureSocket.connect(
      uri.host,
      443,
      context: context,
      supportedProtocols: const <String>['http/1.1'],
      timeout: const Duration(seconds: 20),
    );
    try {
      final String target = uri.hasQuery
          ? '${uri.path}?${uri.query}'
          : uri.path;
      final String request =
          'GET $target HTTP/1.1\r\n'
          'Host: ${uri.host}\r\n'
          'User-Agent: Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36\r\n'
          'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n'
          'Accept-Language: ${language == 'en' ? 'en' : 'zh-Hant-HK'}\r\n'
          'Connection: close\r\n\r\n';
      socket.add(latin1.encode(request));
      await socket.flush();
      final List<int> bytes = await socket
          .fold<List<int>>(<int>[], (List<int> data, List<int> chunk) {
            data.addAll(chunk);
            return data;
          })
          .timeout(const Duration(seconds: 25));
      return _decodeHttpResponse(bytes);
    } finally {
      socket.destroy();
    }
  }

  Future<SecurityContext> _createSecurityContext() async {
    final ByteData data = await rootBundle.load(
      'assets/certs/godaddy_g2_bundle.pem',
    );
    return SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(data.buffer.asUint8List());
  }
}

String? _decodeHttpResponse(List<int> bytes) {
  int headerEnd = -1;
  for (int index = 0; index + 3 < bytes.length; index++) {
    if (bytes[index] == 13 &&
        bytes[index + 1] == 10 &&
        bytes[index + 2] == 13 &&
        bytes[index + 3] == 10) {
      headerEnd = index;
      break;
    }
  }
  if (headerEnd < 0) return null;
  final String headerText = latin1.decode(bytes.sublist(0, headerEnd));
  final List<String> lines = headerText.split('\r\n');
  if (lines.isEmpty) return null;
  final List<String> statusParts = lines.first.split(' ');
  if (statusParts.length < 2 || statusParts[1] != '200') return null;
  final Map<String, String> headers = <String, String>{};
  for (final String line in lines.skip(1)) {
    final int colon = line.indexOf(':');
    if (colon <= 0) continue;
    headers[line.substring(0, colon).trim().toLowerCase()] = line
        .substring(colon + 1)
        .trim();
  }
  final List<int> body = bytes.sublist(headerEnd + 4);
  if (headers['content-encoding']?.toLowerCase().contains('gzip') ?? false) {
    return utf8.decode(gzip.decode(body), allowMalformed: true);
  }
  if (headers['transfer-encoding']?.toLowerCase().contains('chunked') ??
      false) {
    final List<int>? decoded = _decodeChunked(body);
    if (decoded == null) return null;
    return utf8.decode(decoded, allowMalformed: true);
  }
  final int? length = int.tryParse(headers['content-length'] ?? '');
  final List<int> content = length != null && length <= body.length
      ? body.sublist(0, length)
      : body;
  return utf8.decode(content, allowMalformed: true);
}

List<int>? _decodeChunked(List<int> body) {
  final List<int> result = <int>[];
  int offset = 0;
  int lineEnd(int start) {
    for (int index = start; index + 1 < body.length; index++) {
      if (body[index] == 13 && body[index + 1] == 10) return index;
    }
    return -1;
  }

  while (offset < body.length) {
    final int end = lineEnd(offset);
    if (end < 0) return null;
    final String sizeText = latin1
        .decode(body.sublist(offset, end))
        .split(';')
        .first
        .trim();
    final int? size = int.tryParse(sizeText, radix: 16);
    if (size == null) return null;
    offset = end + 2;
    if (size == 0) return result;
    if (offset + size > body.length) return null;
    result.addAll(body.sublist(offset, offset + size));
    offset += size;
    if (offset + 1 < body.length &&
        body[offset] == 13 &&
        body[offset + 1] == 10) {
      offset += 2;
    }
  }
  return result;
}

NlbTimetable? parseNlbTimetable(String html) {
  final Document document = html_parser.parse(html);
  Element? content = document.querySelector(NlbTimetableService._selector);
  if (content == null) {
    for (final Element candidate in document.querySelectorAll(
      'div.ck-content',
    )) {
      final String label = (candidate.attributes['aria-label'] ?? '')
          .toLowerCase();
      if (label.contains('時間表') || label.contains('timetable')) {
        content = candidate;
        break;
      }
    }
  }
  if (content == null) return null;

  final List<NlbTimetableSection> sections = <NlbTimetableSection>[];
  final List<String> notes = <String>[];
  NlbTimetableSection? current;
  final List<Element> children = content.children;
  for (int index = 0; index < children.length; index++) {
    final Element child = children[index];
    if (child.localName == 'table') {
      current ??= const NlbTimetableSection(
        title: '',
        rows: <NlbTimetableRow>[],
      );
      final List<NlbTimetableRow> rows = current.rows.toList();
      for (final Element row in child.querySelectorAll('tr')) {
        final List<Element> cells = row
            .querySelectorAll('td, th')
            .toList(growable: false);
        if (cells.isEmpty) continue;
        final String time = _cleanText(cells.first.text);
        if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time)) continue;
        final String note = cells
            .skip(1)
            .map((Element cell) => _cleanText(cell.text))
            .where((String value) => value.isNotEmpty)
            .join(' ');
        rows.add(NlbTimetableRow(time: time, note: note));
      }
      if (rows.isEmpty) continue;
      current = NlbTimetableSection(title: current.title, rows: rows);
      continue;
    }
    if (child.localName != 'p') continue;
    final String text = _cleanText(child.text);
    if (text.isEmpty) continue;
    final bool followedByTable =
        index + 1 < children.length && children[index + 1].localName == 'table';
    if (followedByTable) {
      if (current != null && current.rows.isNotEmpty) sections.add(current);
      current = NlbTimetableSection(
        title: text,
        rows: const <NlbTimetableRow>[],
      );
    } else if (current != null && current.rows.isNotEmpty) {
      notes.add(text);
    }
  }
  if (current != null && current.rows.isNotEmpty) sections.add(current);
  if (sections.isEmpty) return null;
  return NlbTimetable(sections: sections, notes: notes);
}

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _CachedTimetable {
  const _CachedTimetable({required this.timetable, required this.fetchedAt});

  final NlbTimetable timetable;
  final DateTime fetchedAt;
}
