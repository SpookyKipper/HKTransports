import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class CitybusRemarksService {
  const CitybusRemarksService();

  static const Duration _timeout = Duration(seconds: 20);

  Future<String?> fetchRemarks(String routeNumber, {required bool zh}) async {
    final String route = routeNumber.trim().toUpperCase();
    if (route.isEmpty) return null;
    final String? infoKey = await _fetchInfoKey(route);
    if (infoKey == null) return null;

    final Uri uri = Uri.https(
      'mobile.citybus.com.hk',
      '/nwp3/getremark.php',
      <String, String>{'info': 'CTB||$infoKey||', 'l': zh ? '0' : '1'},
    );
    final http.Response response = await http
        .get(uri, headers: const <String, String>{'User-Agent': 'Mozilla/5.0'})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'Citybus remarks request failed: ${response.statusCode}',
      );
    }
    return parseCitybusRemarks(utf8.decode(response.bodyBytes), zh: zh);
  }

  Future<String?> _fetchInfoKey(String routeNumber) async {
    final Uri uri = Uri.https(
      'www.citybus.com.hk',
      '/concessionApi/public/bbi/api/v1/route/en/$routeNumber',
    );
    final http.Response response = await http
        .get(uri, headers: const <String, String>{'User-Agent': 'Mozilla/5.0'})
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map || decoded.isEmpty) return null;
    return citybusRemarkInfoKey(decoded.keys.first.toString());
  }
}

String? citybusRemarkInfoKey(String concessionKey) {
  final List<String> parts = concessionKey.split('-');
  if (parts.length < 4) return null;
  return '${parts[0]}-${parts[2]}-${parts[3]}';
}

String? parseCitybusRemarks(String source, {required bool zh}) {
  final Document document = html_parser.parse(source);
  final Element? container =
      document.querySelector('#remarkitemlist') ?? document.body;
  if (container == null) return null;

  String html = container.innerHtml;
  html = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  html = html.replaceAll(
    RegExp(r'</(?:p|div|tr|table|h[1-6]|li)>', caseSensitive: false),
    '\n',
  );
  final String raw = html_parser.parseFragment(html).text ?? '';
  final List<String> lines = [];
  final RegExp bbi = RegExp(
    r'bus[\s-]*bus[\s-]*interchange|巴士轉乘|轉乘計劃|轉乘優惠',
    caseSensitive: false,
  );
  for (final String rawLine in raw.split('\n')) {
    String line = _cleanLine(rawLine);
    if (line.isEmpty) continue;
    line = line
        .replaceAll(
          RegExp(r'\s*/\s*Bus-Bus Interchange', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s*/\s*巴士轉乘計劃'), '')
        .trim();
    if (line.isEmpty || bbi.hasMatch(line)) continue;
    lines.add(line);
  }
  final String result = lines.join('\n').trim();
  return result.isEmpty ? null : result;
}

String _cleanLine(String value) {
  return value
      .replaceAll('\ufeff', '')
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}
