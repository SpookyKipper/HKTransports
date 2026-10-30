import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/functions/title_case.dart';
import 'package:http/http.dart' as http;

class ProprietaryNotice {
  const ProprietaryNotice({
    required this.title,
    this.date,
    this.detail,
    this.url,
  });

  final String title;
  final String? date;
  final String? detail;
  final Uri? url;
}

class KmbBbiEntry {
  const KmbBbiEntry({
    required this.route,
    required this.destinationZh,
    required this.destinationEn,
  });

  final String route;
  final String destinationZh;
  final String destinationEn;

  String destination(String language) =>
      language == 'en' ? destinationEn : destinationZh;
}

class ProprietaryNoticeException implements Exception {
  const ProprietaryNoticeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProprietaryNoticeService {
  static const Duration _timeout = Duration(seconds: 20);
  static const String kmbHost = 'search.kmb.hk';
  static const String citybusHost = 'mobile.citybus.com.hk';

  const ProprietaryNoticeService();

  Future<List<ProprietaryNotice>> fetchKmbAnnouncements(
    RouteEntry route, {
    required bool zh,
  }) async {
    final Uri uri = Uri.https(
      kmbHost,
      '/kmbwebsite/Function/FunctionRequest.ashx',
      {
        'action': 'getAnnounce',
        'route': route.route,
        'bound': _kmbBound(route),
      },
    );
    final Map<String, dynamic> json = await _getJson(uri);
    final dynamic data = json['data'];
    if (data is! List) return const [];
    final List<ProprietaryNotice> notices = [];
    for (final dynamic value in data) {
      if (value is! Map) continue;
      final String titleZh = _string(value['kpi_title_chi']);
      final String titleEn = _string(value['kpi_title']);
      final String title = zh
          ? (titleZh.isNotEmpty ? titleZh : titleEn)
          : (titleEn.isNotEmpty ? titleEn : titleZh);
      if (title.isEmpty) continue;
      notices.add(
        ProprietaryNotice(
          title: title,
          url: _kmbAnnouncementUri(_string(value['kpi_noticeimageurl'])),
        ),
      );
    }
    return notices;
  }

  Future<List<KmbBbiEntry>> fetchKmbBbi(RouteEntry route) async {
    final Uri uri = Uri.https(
      kmbHost,
      '/kmbwebsite/Function/FunctionRequest.ashx',
      {
        'action': 'getbbiforroute',
        'route': route.route,
        'bound': _kmbBound(route),
      },
    );
    final Map<String, dynamic> json = await _getJson(uri);
    final dynamic data = json['data'];
    final dynamic rawEntries = data is Map ? data['BBIs'] : null;
    if (rawEntries is! List) return const [];
    final List<KmbBbiEntry> entries = [];
    for (final dynamic value in rawEntries) {
      if (value is! Map) continue;
      final String routeNumber = _string(value['Route2']);
      if (routeNumber.isEmpty) continue;
      entries.add(
        KmbBbiEntry(
          route: routeNumber,
          destinationZh: _string(value['Destination_CHI']),
          destinationEn: toProperCase(_string(value['Destination_ENG'])),
        ),
      );
    }
    return entries;
  }

  Future<List<ProprietaryNotice>> fetchCitybusSpecialNotices(
    RouteEntry route, {
    required bool zh,
  }) async {
    final Uri uri = Uri.https(citybusHost, '/nwp3/specialNote.php', {
      'r': route.route,
      'l': zh ? '0' : '1',
    });
    return parseCitybusSpecialNoticeHtml(await _getText(uri));
  }

  Future<List<ProprietaryNotice>> fetchCitybusRouteNotices(
    RouteEntry route, {
    required bool zh,
  }) async {
    final Uri uri = Uri.https(citybusHost, '/nwp3/getnotice.php', {
      'id': route.route,
      'l': zh ? '0' : '1',
    });
    return parseCitybusNoticeHtml(await _getText(uri));
  }

  Future<List<ProprietaryNotice>> fetchCitybusStopNotices(
    String stopId, {
    required bool zh,
  }) async {
    final Uri uri = Uri.https(citybusHost, '/nwp3/getnotice_stop.php', {
      'stopid': stopId,
      'l': zh ? '0' : '1',
    });
    return parseCitybusNoticeHtml(await _getText(uri));
  }

  String _kmbBound(RouteEntry route) {
    final String? bound = route.boundFor(BusCompany.kmb);
    return switch (bound) {
      'I' => '2',
      'O' => '1',
      null || '' => '1',
      _ => bound,
    };
  }

  Uri? _kmbAnnouncementUri(String value) {
    final String raw = value.trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final Uri? uri = Uri.tryParse(raw);
      if (uri != null && uri.host == kmbHost) {
        return uri.replace(scheme: 'https');
      }
      return uri;
    }
    return Uri.https(kmbHost, '/kmbwebsite/AnnouncementPicture.ashx', {
      'url': raw,
    });
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final String body = await _getText(uri);
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const ProprietaryNoticeException('Unexpected JSON response');
    }
    return decoded.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }

  Future<String> _getText(Uri uri) async {
    final http.Response response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ProprietaryNoticeException(
        'Request failed with HTTP ${response.statusCode}',
      );
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}

List<ProprietaryNotice> parseCitybusNoticeHtml(String source) {
  final dom.Document document = html_parser.parse(source);
  final List<ProprietaryNotice> notices = [];
  for (final dom.Element row in document.querySelectorAll('tr')) {
    final Uri? url = _citybusLinkFromRow(row);
    if (url == null) continue;
    final dom.Element? dateElement = row.querySelector('font');
    final String date = _cleanText(dateElement?.text ?? '');
    String title = _cleanText(row.text);
    if (date.isNotEmpty && title.startsWith(date)) {
      title = title.substring(date.length).trim();
    }
    String? detail;
    final int routeIndex = title.indexOf('路線:');
    if (routeIndex >= 0) {
      detail = title.substring(routeIndex).trim();
      title = title.substring(0, routeIndex).trim();
    }
    if (title.isEmpty) continue;
    notices.add(
      ProprietaryNotice(
        title: title,
        date: date.isEmpty ? null : date,
        detail: detail,
        url: url,
      ),
    );
  }
  return notices;
}

List<ProprietaryNotice> parseCitybusSpecialNoticeHtml(String source) {
  final dom.Document document = html_parser.parse(source);
  final dom.Element? container = document.querySelector('#specialnotelist');
  if (container == null) return const [];
  final List<ProprietaryNotice> notices = [];
  for (final dom.Element row in container.querySelectorAll('tr')) {
    final String text = _cleanText(row.text);
    if (text.isEmpty || text.contains('路線服務狀況') || text == '關閉') {
      continue;
    }
    if (row.querySelector('img[src*="close"], img[title="關閉"]') != null) {
      continue;
    }
    final dom.Element? dateElement = row.querySelector('font');
    final String date = _cleanText(dateElement?.text ?? '');
    String title = text;
    if (date.isNotEmpty && title.startsWith(date)) {
      title = title.substring(date.length).trim();
    }
    if (title.isEmpty) continue;
    notices.add(
      ProprietaryNotice(
        title: title,
        date: date.isEmpty ? null : date,
        url: _citybusLinkFromRow(row),
      ),
    );
  }
  return notices;
}

Uri? _citybusLinkFromRow(dom.Element row) {
  final RegExp windowOpen = RegExp(r'''window\.open\(\s*["']([^"']+)["']''');
  final List<String> candidates = [
    if (row.attributes['onclick'] != null) row.attributes['onclick']!,
    for (final dom.Element element in row.querySelectorAll('[onclick]'))
      element.attributes['onclick'] ?? '',
  ];
  for (final String onclick in candidates) {
    final RegExpMatch? match = windowOpen.firstMatch(onclick);
    final String? value = match?.group(1)?.trim();
    final Uri? uri = _citybusUri(value);
    if (uri != null) return uri;
  }
  final String? href = row.querySelector('a[href]')?.attributes['href']?.trim();
  return _citybusUri(href);
}

Uri? _citybusUri(String? value) {
  if (value == null || value.isEmpty || value.startsWith('javascript:')) {
    return null;
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    final Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.host == 'mobile.citybus.com.hk') {
      return uri.replace(scheme: 'https');
    }
    return uri;
  }
  return Uri.parse('https://mobile.citybus.com.hk/nwp3/').resolve(value);
}

String _cleanText(String value) =>
    value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _string(dynamic value) => value?.toString().trim() ?? '';
