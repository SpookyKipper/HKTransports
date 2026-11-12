import 'dart:convert';

import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_http.dart';
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

  Future<String?> _fetchHtmlRaw(Uri uri, String language) {
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
