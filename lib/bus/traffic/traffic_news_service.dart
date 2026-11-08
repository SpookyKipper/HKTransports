import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

final Uri _trafficNewsUriv1 = Uri.parse(
  'https://resource.data.one.gov.hk/td/en/specialtrafficnews.xml?date=1',
);
final Uri _trafficNewsUriv2 = Uri.parse(
  'https://www.td.gov.hk/tc/special_news/trafficnews.xml',
);

Future<List<TrafficNewsItem>> getTrafficNews() async {
  final List<TrafficNewsItem> v2NewsItems = await _getNewsV2();
  final List<TrafficNewsItem> v1NewsItems = await _getNewsV1();
  return mergeTrafficNews(v2NewsItems, v1NewsItems);
}

List<TrafficNewsItem> mergeTrafficNews(
  List<TrafficNewsItem> current,
  List<TrafficNewsItem> legacy,
) {
  final List<TrafficNewsItem> result = <TrafficNewsItem>[...current];
  for (final TrafficNewsItem item in legacy) {
    if (result.any(
      (TrafficNewsItem existing) => _sameNewsContent(item, existing),
    )) {
      continue;
    }
    result.add(item);
  }
  return result;
}

Future<List<TrafficNewsItem>> _getNewsV1() async {
  final http.Response res = await http.get(_trafficNewsUriv1);
  if (res.statusCode != 200) {
    return <TrafficNewsItem>[
      TrafficNewsItem(
        description: const <String>['請求失敗', 'Unable to fetch traffic news'],
        date: '',
      ),
    ];
  }
  final XmlDocument document = XmlDocument.parse(utf8.decode(res.bodyBytes));
  return <TrafficNewsItem>[
    for (final XmlElement news in document.findAllElements('message'))
      TrafficNewsItem(
        description: <String>[_text(news, 'ChinText'), _text(news, 'EngText')],
        date: _text(
          news,
          'ReferenceDate',
        ).replaceAll('上午', 'AM').replaceAll('下午', 'PM'),
        status: int.tryParse(_text(news, 'CurrentStatus')) ?? 3,
      ),
  ];
}

Future<List<TrafficNewsItem>> _getNewsV2() async {
  final http.Response res = await http.get(_trafficNewsUriv2);
  if (res.statusCode != 200) {
    return <TrafficNewsItem>[
      TrafficNewsItem(
        description: const <String>[
          '請求失敗 (v2)',
          'Unable to fetch traffic news (v2)',
        ],
        date: '',
      ),
    ];
  }
  final XmlDocument document = XmlDocument.parse(utf8.decode(res.bodyBytes));
  return <TrafficNewsItem>[
    for (final XmlElement news in document.findAllElements('message'))
      TrafficNewsItem(
        title: <String>[
          '${_text(news, 'INCIDENT_HEADING_CN')} - '
              '${_text(news, 'INCIDENT_DETAIL_CN')}',
          '${_text(news, 'INCIDENT_HEADING_EN')} - '
              '${_text(news, 'INCIDENT_DETAIL_EN')}',
        ],
        description: <String>[
          _text(news, 'CONTENT_CN'),
          _text(news, 'CONTENT_EN'),
        ],
        date: _formatDate(_text(news, 'ANNOUNCEMENT_DATE')),
        status: -1,
      ),
  ];
}

String _text(XmlElement element, String name) {
  final Iterable<XmlElement> found = element.findAllElements(name);
  return found.isEmpty ? '' : found.first.innerText;
}

String _formatDate(String value) {
  final DateTime? date = DateTime.tryParse(value);
  return date == null ? '' : DateFormat('HH:mm').format(date);
}

bool _sameNewsContent(TrafficNewsItem a, TrafficNewsItem b) {
  final Set<String> left = a.description
      .map(_normaliseNewsText)
      .where((String value) => value.isNotEmpty)
      .toSet();
  if (left.isEmpty) return false;
  for (final String right in b.description.map(_normaliseNewsText)) {
    if (right.isNotEmpty && left.contains(right)) return true;
  }
  return false;
}

String _normaliseNewsText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '');
}

class TrafficNewsItem {
  const TrafficNewsItem({
    this.title,
    required this.description,
    required this.date,
    this.status = 3,
  });

  final List<String>? title;
  final List<String> description;
  final String date;
  final int status;
}
