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
    final String languagePath = language == 'en' ? 'en' : 'tc';
    final Uri uri = Uri.https(
      'www.nlb.com.hk',
      '/$languagePath/route/${Uri.encodeComponent(route.nlbRouteId)}',
    );
    try {
      final String? page = await _fetchHtml(uri, language);
      if (page == null) return null;
      final String? html = parseNlbTimetableHtml(page);
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
    final String languagePath = language == 'en' ? 'en' : 'tc';
    final Uri uri = Uri.https(
      'www.nlb.com.hk',
      '/$languagePath/route/${Uri.encodeComponent(route.nlbRouteId)}',
    );
    try {
      final String? html = await _fetchHtml(uri, language);
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
String? parseNlbTimetableHtml(String html) {
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
  return content?.outerHtml;
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

String _cleanText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _firstTextByClass(Element element, String className) {
  for (final Element child in element.querySelectorAll('p')) {
    if (child.className.contains(className)) return _cleanText(child.text);
  }
  return '';
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
