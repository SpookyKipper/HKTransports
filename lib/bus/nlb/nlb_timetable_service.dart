import 'dart:convert';

import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_http.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class NlbRouteStopData {
  const NlbRouteStopData({
    required this.index,
    required this.name,
    required this.location,
    required this.weekdayFare,
    required this.holidayFare,
  });

  final int index;
  final String name;
  final String location;
  final String? weekdayFare;
  final String? holidayFare;
}

class NlbRoutePageData {
  const NlbRoutePageData({required this.stops});

  final Map<int, NlbRouteStopData> stops;
}

class NlbRouteNotice {
  const NlbRouteNotice({
    required this.title,
    required this.date,
    required this.url,
  });

  final String title;
  final String date;
  final Uri? url;
}

class NlbTimetableService {
  NlbTimetableService({http.Client? client}) : _client = client;

  static final NlbTimetableService instance = NlbTimetableService();

  static const Duration _cacheTtl = Duration(hours: 1);
  static const String _selector =
      'section.space-y-4:nth-child(2) > div:nth-child(2) '
      '> div:nth-child(1) > div:nth-child(1)';

  final http.Client? _client;
  final Map<String, _CachedTimetableHtml> _timetableCache =
      <String, _CachedTimetableHtml>{};
  final Map<String, _CachedRoutePage> _routeDataCache =
      <String, _CachedRoutePage>{};
  final Map<String, Future<NlbRoutePageData?>> _routeDataLoading =
      <String, Future<NlbRoutePageData?>>{};
  final Map<String, _CachedNotice> _noticeCache = <String, _CachedNotice>{};
  final Map<String, _CachedPageHtml> _pageCache = <String, _CachedPageHtml>{};
  final Map<String, Future<String?>> _pageLoading = <String, Future<String?>>{};

  Future<void> prefetchPage(RouteEntry route, String language) async {
    await _getPageHtml(route, language);
  }

  Future<String?> fetchTimetableHtml(
    RouteEntry route,
    String language, {
    bool force = false,
  }) async {
    final String key = '${route.nlbRouteId}|${language == 'en' ? 'en' : 'tc'}';
    final _CachedTimetableHtml? cached = _timetableCache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.html;
    }
    try {
      final String? page = await _getPageHtml(route, language, force: force);
      if (page == null) return null;
      final String? html = parseNlbTimetableHtml(page, language: language);
      if (html == null) return null;
      _timetableCache[key] = _CachedTimetableHtml(
        html: html,
        fetchedAt: DateTime.now(),
      );
      return html;
    } catch (_) {
      return null;
    }
  }

  Future<NlbRouteNotice?> fetchRouteNotice(
    RouteEntry route,
    String language, {
    bool force = false,
  }) async {
    final String key = '${route.nlbRouteId}|${language == 'en' ? 'en' : 'tc'}';
    final _CachedNotice? cached = _noticeCache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.notice;
    }
    try {
      final String? html = await _getPageHtml(route, language, force: force);
      if (html == null) return null;
      final NlbRouteNotice? notice = parseNlbRouteNotice(
        html,
        baseUri: _pageUri(route, language),
      );
      if (notice == null) return null;
      _noticeCache[key] = _CachedNotice(
        notice: notice,
        fetchedAt: DateTime.now(),
      );
      return notice;
    } catch (_) {
      return null;
    }
  }

  Future<NlbRoutePageData?> fetchRouteData(
    RouteEntry route,
    String language, {
    bool force = false,
  }) {
    final String key = '${route.nlbRouteId}|${language == 'en' ? 'en' : 'tc'}';
    final _CachedRoutePage? cached = _routeDataCache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return Future<NlbRoutePageData?>.value(cached.data);
    }
    if (!force) {
      final Future<NlbRoutePageData?>? running = _routeDataLoading[key];
      if (running != null) return running;
    }
    final Future<NlbRoutePageData?> future = _loadRouteData(
      route,
      language,
      key,
    );
    _routeDataLoading[key] = future;
    return future.whenComplete(() {
      if (identical(_routeDataLoading[key], future)) {
        _routeDataLoading.remove(key);
      }
    });
  }

  Future<NlbRoutePageData?> _loadRouteData(
    RouteEntry route,
    String language,
    String key,
  ) async {
    try {
      final String? html = await _getPageHtml(route, language);
      if (html == null) return null;
      final NlbRoutePageData? data = parseNlbRouteData(html);
      if (data == null) return null;
      _routeDataCache[key] = _CachedRoutePage(
        data: data,
        fetchedAt: DateTime.now(),
      );
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getPageHtml(
    RouteEntry route,
    String language, {
    bool force = false,
  }) {
    final String key = '${route.nlbRouteId}|${language == 'en' ? 'en' : 'tc'}';
    final _CachedPageHtml? cached = _pageCache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return Future<String?>.value(cached.html);
    }
    if (!force) {
      final Future<String?>? running = _pageLoading[key];
      if (running != null) return running;
    }
    final Future<String?> future = _loadPage(
      _pageUri(route, language),
      language,
      key,
    );
    _pageLoading[key] = future;
    return future.whenComplete(() {
      if (identical(_pageLoading[key], future)) {
        _pageLoading.remove(key);
      }
    });
  }

  Future<String?> _loadPage(Uri uri, String language, String key) async {
    try {
      final String? html = await _fetchHtml(uri, language);
      if (html == null) return null;
      _pageCache[key] = _CachedPageHtml(html: html, fetchedAt: DateTime.now());
      return html;
    } catch (_) {
      return null;
    }
  }

  Uri _pageUri(RouteEntry route, String language) {
    final String languagePath = language == 'en' ? 'en' : 'tc';
    return Uri.https(
      'www.nlb.com.hk',
      '/$languagePath/route/${Uri.encodeComponent(route.nlbRouteId)}',
    );
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
    return NlbHttp.get(
      uri,
      headers: <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': language == 'en' ? 'en' : 'zh-Hant-HK',
      },
    );
  }
}

/// Returns the selected timetable HTML exactly as rendered by NLB.
String? parseNlbTimetableHtml(String html, {String language = 'tc'}) {
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
  final Element? fareNote =
      document.querySelector(
        '#route-fare > div:nth-child(2) > div:nth-child(1)',
      ) ??
      document.querySelector('#route-fare div.ck-content');
  final String noteHtml =
      fareNote != null && _cleanText(fareNote.text).isNotEmpty
      ? '<div class="nlb-fare-note">${fareNote.outerHtml}</div>'
      : '';
  _addTimetableLegend(content, language);
  return '$noteHtml${content.outerHtml}';
}

void _addTimetableLegend(Element content, String language) {
  final List<Element> children = content.children.toList(growable: false);
  final List<Element> notes = <Element>[];
  bool seenTable = false;
  for (int index = 0; index < children.length; index++) {
    final Element child = children[index];
    if (child.localName == 'table') {
      seenTable = true;
      continue;
    }
    if (!seenTable || child.localName != 'p') continue;
    if (_cleanText(child.text).isEmpty) {
      child.remove();
      continue;
    }
    final bool nextIsTable =
        index + 1 < children.length && children[index + 1].localName == 'table';
    if (!nextIsTable) notes.add(child);
  }
  if (notes.isEmpty) return;
  final Element legend = Element.tag('div')
    ..classes.add('nlb-timetable-legend');
  legend.append(
    Element.tag('p')
      ..classes.add('nlb-timetable-legend-title')
      ..text = language == 'en' ? 'Notes' : '備註',
  );
  for (final Element note in notes) {
    legend.append(note.clone(true));
    note.remove();
  }
  content.nodes.insert(0, legend);
}

NlbRoutePageData? parseNlbRouteData(String html) {
  final Document document = html_parser.parse(html);
  Element? list = document.querySelector('ol.relative.w-full.space-y-0.ms-3');
  if (list == null) {
    for (final Element candidate in document.querySelectorAll('ol')) {
      if (candidate.querySelectorAll('li').length > 1) {
        list = candidate;
        break;
      }
    }
  }
  if (list == null) return null;

  final Map<int, NlbRouteStopData> stops = <int, NlbRouteStopData>{};
  int fallbackIndex = 0;
  for (final Element item in list.children.where(
    (Element element) => element.localName == 'li',
  )) {
    fallbackIndex++;
    final String stationText = item
        .querySelectorAll('p')
        .map((Element p) => _cleanText(p.text))
        .firstWhere(
          (String text) =>
              RegExp(r'第\s*\d+\s*站').hasMatch(text) ||
              RegExp(r'Stop\s*\d+', caseSensitive: false).hasMatch(text),
          orElse: () => '',
        );
    final RegExpMatch? indexMatch = RegExp(
      r'第\s*(\d+)\s*站|Stop\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(stationText);
    final int index =
        int.tryParse(indexMatch?.group(1) ?? indexMatch?.group(2) ?? '') ??
        fallbackIndex;
    final String name = _firstTextByClass(item, 'text-lg');
    final List<String> smallTexts = item
        .querySelectorAll('p')
        .where((Element p) => p.className.contains('text-xs'))
        .map((Element p) => _cleanText(p.text))
        .where((String text) => text.isNotEmpty)
        .toList();
    final String location = smallTexts.isEmpty ? '' : smallTexts.last;

    String? weekdayFare;
    String? holidayFare;
    for (final Element term in item.querySelectorAll('dt')) {
      final String label = _cleanText(term.text).toLowerCase();
      final Element? value = term.nextElementSibling;
      if (value == null || value.localName != 'dd') continue;
      final String fare = _cleanText(value.text);
      if (fare.isEmpty) continue;
      if (label.contains('平日') || label.contains('weekday')) {
        weekdayFare = fare;
      } else if (label.contains('假日') || label.contains('holiday')) {
        holidayFare = fare;
      }
    }
    if (name.isEmpty && weekdayFare == null && holidayFare == null) continue;
    stops[index] = NlbRouteStopData(
      index: index,
      name: name,
      location: location,
      weekdayFare: weekdayFare,
      holidayFare: holidayFare,
    );
  }
  if (stops.isEmpty) return null;
  return NlbRoutePageData(stops: stops);
}

NlbRouteNotice? parseNlbRouteNotice(String html, {required Uri baseUri}) {
  final Document document = html_parser.parse(html);
  final Element? card =
      document.querySelector('.space-y-3 > div:nth-child(1)') ??
      document.querySelector('div.space-y-3 > div');
  if (card == null) return null;
  final String title = _cleanText(card.querySelector('h3')?.text ?? '');
  if (title.isEmpty) return null;
  final String date = _cleanText(card.querySelector('p')?.text ?? '');
  final String? href = card.querySelector('a[href]')?.attributes['href'];
  Uri? url;
  if (href != null && href.isNotEmpty) {
    url = baseUri.resolve(href);
  }
  return NlbRouteNotice(title: title, date: date, url: url);
}

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _firstTextByClass(Element element, String className) {
  for (final Element child in element.querySelectorAll('p')) {
    if (child.className.contains(className)) return _cleanText(child.text);
  }
  return '';
}

class _CachedNotice {
  const _CachedNotice({required this.notice, required this.fetchedAt});

  final NlbRouteNotice notice;
  final DateTime fetchedAt;
}

class _CachedPageHtml {
  const _CachedPageHtml({required this.html, required this.fetchedAt});

  final String html;
  final DateTime fetchedAt;
}

class _CachedRoutePage {
  const _CachedRoutePage({required this.data, required this.fetchedAt});

  final NlbRoutePageData data;
  final DateTime fetchedAt;
}

class _CachedTimetableHtml {
  const _CachedTimetableHtml({required this.html, required this.fetchedAt});

  final String html;
  final DateTime fetchedAt;
}
