import 'dart:convert';
import 'dart:math';

import 'package:hktransports/dataStore/objectbox.dart';
import 'package:http/http.dart' as http;

class AppNotice {
  const AppNotice({
    required this.id,
    required this.icon,
    required this.contentZh,
    required this.contentEn,
    required this.linkZh,
    required this.linkEn,
    required this.url,
    required this.startDate,
    required this.endDate,
    required this.probability,
    required this.isShown,
  });

  final String id;
  final String icon;
  final List<String> contentZh;
  final List<String> contentEn;
  final String linkZh;
  final String linkEn;
  final String url;
  final DateTime? startDate;
  final DateTime? endDate;
  final double probability;
  final bool isShown;

  List<String> content(String language) =>
      language == 'en' ? contentEn : contentZh;

  String link(String language) => language == 'en' ? linkEn : linkZh;

  factory AppNotice.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> content =
        (json['content'] as Map<String, dynamic>?) ?? const {};
    final Map<String, dynamic> link =
        (json['link'] as Map<String, dynamic>?) ?? const {};
    return AppNotice(
      id: (json['id'] ?? '').toString(),
      icon: (json['icon'] ?? 'info').toString(),
      contentZh: _strings(content['zh']),
      contentEn: _strings(content['en']),
      linkZh: (link['zh'] ?? '').toString(),
      linkEn: (link['en'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      startDate: DateTime.tryParse((json['startDate'] ?? '').toString()),
      endDate: DateTime.tryParse((json['endDate'] ?? '').toString()),
      probability: (json['probability'] as num?)?.toDouble() ?? 1,
      isShown: json['isShown'] != false,
    );
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((dynamic item) => item.toString()).toList();
  }
}

class NoticeService {
  static final Random _random = Random();
  static final Map<String, bool> _rolled = {};

  Future<List<AppNotice>> load() async {
    final http.Response response = await http
        .get(Uri.parse('https://notice.hkbus.app/notices.json'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    final DateTime now = DateTime.now();
    final Set<String> dismissed = _dismissedIds();
    final List<AppNotice> result = [];
    for (final dynamic value in decoded) {
      if (value is! Map<String, dynamic>) continue;
      final AppNotice notice = AppNotice.fromJson(value);
      if (!notice.isShown) continue;
      if (dismissed.contains(notice.id)) continue;
      if (notice.startDate != null && notice.startDate!.isAfter(now)) continue;
      if (notice.endDate != null && notice.endDate!.isBefore(now)) continue;
      if (notice.probability < 1) {
        final bool? rolled = _rolled[notice.id];
        if (rolled == null) {
          _rolled[notice.id] = _random.nextDouble() < notice.probability;
        }
        if (_rolled[notice.id] != true) continue;
      }
      result.add(notice);
    }
    return result;
  }

  void dismiss(String id) {
    final Set<String> ids = _dismissedIds()..add(id);
    sp.setString('dismissedNotices', jsonEncode(ids.toList()));
  }

  Set<String> _dismissedIds() {
    final String? raw = sp.getString('dismissedNotices');
    if (raw == null || raw.isEmpty) return {};
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((dynamic value) => value.toString()).toSet();
      }
    } catch (_) {}
    return {};
  }
}
