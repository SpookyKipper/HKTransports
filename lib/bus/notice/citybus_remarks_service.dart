import 'dart:convert';
import 'dart:io';

import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class CitybusRemarkRun {
  const CitybusRemarkRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.href,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? href;
}

class CitybusRemarkLine {
  const CitybusRemarkLine(this.runs);

  final List<CitybusRemarkRun> runs;

  String get text => runs.map((CitybusRemarkRun run) => run.text).join();
}

class CitybusRemarksService {
  const CitybusRemarksService();

  static const Duration _timeout = Duration(seconds: 20);

  Future<List<CitybusRemarkLine>?> fetchRemarks(
    RouteEntry route, {
    required bool zh,
  }) async {
    if (route.route.trim().isEmpty) return null;
    final List<String> infoKeys = await CitybusRoutelistService.instance
        .remarkInfoKeys(route);
    if (infoKeys.isEmpty) return null;

    Object? lastError;
    bool anySuccess = false;
    for (final String infoKey in infoKeys) {
      try {
        final Uri uri = Uri.https(
          'mobile.citybus.com.hk',
          '/nwp3/getremark.php',
          <String, String>{'info': 'CTB||$infoKey||', 'l': zh ? '0' : '1'},
        );
        final http.Response response = await http
            .get(
              uri,
              headers: const <String, String>{'User-Agent': 'Mozilla/5.0'},
            )
            .timeout(_timeout);
        if (response.statusCode != 200) {
          lastError = HttpException(
            'Citybus remarks request failed: ${response.statusCode}',
          );
          continue;
        }
        anySuccess = true;
        final List<CitybusRemarkLine>? remarks = parseCitybusRemarks(
          utf8.decode(response.bodyBytes),
        );
        if (remarks != null && remarks.isNotEmpty) return remarks;
      } catch (error) {
        lastError = error;
      }
    }
    if (!anySuccess && lastError != null) throw lastError;
    return null;
  }
}

List<CitybusRemarkLine>? parseCitybusRemarks(String source) {
  final Document document = html_parser.parse(source);
  final Element? container =
      document.querySelector('#remarkitemlist') ?? document.body;
  if (container == null) return null;

  final _RemarkBuilder builder = _RemarkBuilder();
  builder.visitChildren(container, const _RemarkStyle());
  final List<CitybusRemarkLine> lines = builder.finish();
  final List<CitybusRemarkLine> filtered = <CitybusRemarkLine>[];
  bool removeNextBbiLine = false;
  for (final CitybusRemarkLine line in lines) {
    final String text = line.text.trim();
    if (removeNextBbiLine) {
      if (text.isEmpty) {
        filtered.add(line);
        continue;
      }
      removeNextBbiLine = false;
      if (_isBbiBody(text)) continue;
    }
    if (_isBbiHeading(text)) {
      removeNextBbiLine = true;
      continue;
    }
    if (_isBbiCoverage(text)) continue;
    filtered.add(line);
  }
  while (filtered.isNotEmpty && filtered.first.text.trim().isEmpty) {
    filtered.removeAt(0);
  }
  while (filtered.isNotEmpty && filtered.last.text.trim().isEmpty) {
    filtered.removeLast();
  }
  final List<CitybusRemarkLine> styled = <CitybusRemarkLine>[
    for (final CitybusRemarkLine line in filtered) _styleSpecialLine(line),
  ];
  return styled.isEmpty ? null : styled;
}

CitybusRemarkLine _styleSpecialLine(CitybusRemarkLine line) {
  final String text = line.text.trim();
  final String lower = text.toLowerCase();
  if (text.contains('車費備註') || lower.contains('fare remark')) {
    return CitybusRemarkLine(<CitybusRemarkRun>[
      CitybusRemarkRun(
        text: text.contains('車費備註') ? '車費備註' : 'Fare Remark',
        bold: true,
      ),
    ]);
  }
  if (text.contains('路線備註') || lower.contains('routing remark')) {
    return CitybusRemarkLine(<CitybusRemarkRun>[
      CitybusRemarkRun(
        text: text.contains('路線備註')
            ? '=== 以下備註由城巴提供 ===\n路線備註'
            : '=== Remarks here are from Citybus ===\nRouting Remark',
        bold: true,
      ),
    ]);
  }
  if (text == '成人收費' || lower == 'adult fare') {
    return CitybusRemarkLine(<CitybusRemarkRun>[
      for (final CitybusRemarkRun run in line.runs)
        CitybusRemarkRun(
          text: run.text,
          bold: run.bold,
          italic: run.italic,
          underline: true,
          href: run.href,
        ),
    ]);
  }
  return line;
}

bool _isBbiHeading(String text) {
  final String lower = text.toLowerCase();
  return text == '巴士轉乘計劃' || lower == 'bus-bus interchange';
}

bool _isBbiBody(String text) {
  final String lower = text.toLowerCase();
  return text.startsWith('有關巴士轉乘車費優惠詳情') ||
      lower.startsWith('for details of bus-bus interchange concession') ||
      lower.startsWith('for details of bus-bus interchange');
}

bool _isBbiCoverage(String text) {
  final String lower = text.toLowerCase();
  return text.contains('按此瀏覽八達通巴士轉乘優惠計劃的適用範圍') ||
      lower.contains(
        'coverage of relevant bus-bus interchange concession schemes',
      );
}

class _RemarkStyle {
  const _RemarkStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.href,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final String? href;

  _RemarkStyle merge(Element element) {
    final String tag = element.localName ?? '';
    final String? href = tag == 'a'
        ? element.attributes['href']?.trim()
        : this.href;
    return _RemarkStyle(
      bold: bold || tag == 'b' || tag == 'strong',
      italic: italic || tag == 'i' || tag == 'em',
      underline: underline || tag == 'u',
      href: href == null || href.isEmpty ? null : href,
    );
  }
}

class _RemarkBuilder {
  static const Set<String> _blocks = <String>{
    'p',
    'div',
    'tr',
    'table',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'ul',
    'ol',
  };
  static const Set<String> _ignored = <String>{
    'head',
    'script',
    'style',
    'meta',
    'title',
  };

  final List<CitybusRemarkLine> _lines = <CitybusRemarkLine>[];
  List<CitybusRemarkRun> _runs = <CitybusRemarkRun>[];

  void visitChildren(Element element, _RemarkStyle style) {
    for (final Node node in element.nodes) {
      _visit(node, style);
    }
  }

  void _visit(Node node, _RemarkStyle style) {
    if (node is Text) {
      _addText(node.text, style);
      return;
    }
    if (node is! Element) return;
    final String tag = node.localName ?? '';
    if (_ignored.contains(tag)) return;
    if (tag == 'br') {
      _endLine();
      return;
    }
    final bool block = _blocks.contains(tag);
    if (block) _breakBlock();
    final _RemarkStyle next = style.merge(node);
    for (final Node child in node.nodes) {
      _visit(child, next);
    }
    if (block) _breakBlock();
  }

  void _addText(String value, _RemarkStyle style) {
    String text = value
        .replaceAll('\ufeff', '')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
    if (text.trim().isEmpty) {
      if (text.isNotEmpty && _runs.isNotEmpty && !_endsWithSpace()) {
        text = ' ';
      } else {
        return;
      }
    }
    if (_runs.isEmpty) text = text.replaceFirst(RegExp(r'^\s+'), '');
    if (text.isEmpty) return;
    _runs.add(
      CitybusRemarkRun(
        text: text,
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        href: style.href,
      ),
    );
  }

  bool _endsWithSpace() {
    if (_runs.isEmpty) return true;
    return _runs.last.text.endsWith(' ');
  }

  void _endLine() {
    _trimCurrentLine();
    _lines.add(CitybusRemarkLine(List<CitybusRemarkRun>.unmodifiable(_runs)));
    _runs = <CitybusRemarkRun>[];
  }

  void _breakBlock() {
    if (_runs.isNotEmpty) _endLine();
  }

  void _trimCurrentLine() {
    while (_runs.isNotEmpty && _runs.first.text.trim().isEmpty) {
      _runs.removeAt(0);
    }
    while (_runs.isNotEmpty && _runs.last.text.trim().isEmpty) {
      _runs.removeLast();
    }
    if (_runs.isNotEmpty) {
      final CitybusRemarkRun first = _runs.first;
      _runs[0] = CitybusRemarkRun(
        text: first.text.replaceFirst(RegExp(r'^\s+'), ''),
        bold: first.bold,
        italic: first.italic,
        underline: first.underline,
        href: first.href,
      );
      final CitybusRemarkRun last = _runs.last;
      _runs[_runs.length - 1] = CitybusRemarkRun(
        text: last.text.replaceFirst(RegExp(r'\s+$'), ''),
        bold: last.bold,
        italic: last.italic,
        underline: last.underline,
        href: last.href,
      );
    }
  }

  List<CitybusRemarkLine> finish() {
    if (_runs.isNotEmpty) _endLine();
    return _lines;
  }
}
