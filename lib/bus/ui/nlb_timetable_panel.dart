import 'package:flutter/material.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NlbTimetablePanel extends StatefulWidget {
  const NlbTimetablePanel({super.key, required this.route});

  final RouteEntry route;

  @override
  State<NlbTimetablePanel> createState() => _NlbTimetablePanelState();
}

class _NlbTimetablePanelState extends State<NlbTimetablePanel> {
  Future<String?>? _future;
  String? _language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NlbTimetablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String language = context.read<AppSettings>().language;
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.route.nlbRouteId != widget.route.nlbRouteId ||
        _language != language) {
      _load();
    }
  }

  void _load({bool force = false}) {
    _language = context.read<AppSettings>().language;
    _future = NlbTimetableService.instance.fetchTimetableHtml(
      widget.route,
      _language!,
      force: force,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<String?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: M3ELoadingIndicator(size: 24));
        }
        final String? html = snapshot.data;
        if (html == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.text(
                    '未能載入嶼巴官方時間表',
                    'Could not load the official NLB timetable',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                M3EButton.text(
                  onPressed: () => setState(() => _load(force: true)),
                  child: Text(settings.text('重試', 'Retry')),
                ),
              ],
            ),
          );
        }
        return _NlbTimetableWebView(html: html);
      },
    );
  }
}

class _NlbTimetableWebView extends StatefulWidget {
  const _NlbTimetableWebView({required this.html});

  final String html;

  @override
  State<_NlbTimetableWebView> createState() => _NlbTimetableWebViewState();
}

class _NlbTimetableWebViewState extends State<_NlbTimetableWebView> {
  late final WebViewController _controller;
  String? _loadedSignature;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double scale = MediaQuery.textScalerOf(context).scale(1);
    final double fontSize = (theme.textTheme.bodySmall?.fontSize ?? 12) * scale;
    final String signature =
        '${widget.html}|${colors.surface.toARGB32()}|'
        '${colors.onSurface.toARGB32()}|${colors.primary.toARGB32()}|'
        '${colors.outlineVariant.toARGB32()}|$fontSize';
    if (signature == _loadedSignature) return;
    _loadedSignature = signature;
    _controller.setBackgroundColor(Colors.transparent);
    _controller.loadHtmlString(_document(colors, theme, fontSize));
  }

  String _document(ColorScheme colors, ThemeData theme, double fontSize) {
    final String foreground = _css(colors.onSurface);
    final String primary = _css(colors.primary);
    final String border = _css(colors.outlineVariant);
    final String fontFamily =
        theme.textTheme.bodyMedium?.fontFamily ?? 'sans-serif';
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
html, body {
  margin: 0;
  padding: 0;
  background: transparent;
  color: $foreground;
  overflow: auto;
  -webkit-overflow-scrolling: touch;
  touch-action: pan-x pan-y;
  font-family: $fontFamily, sans-serif;
  font-size: ${fontSize.toStringAsFixed(1)}px;
  line-height: 1.45;
}
body { padding: 8px 14px 24px; background: transparent; }
p { margin: 10px 0 6px; font-weight: 600; color: $primary; }
h1, h2, h3, h4 { margin: 10px 0 6px; color: $primary; font-size: 1.05em; }
table {
  width: 100% !important;
  border-collapse: collapse;
  table-layout: fixed;
}
td, th {
  width: auto !important;
  padding: 4px 6px;
  border-bottom: 1px solid $border;
  vertical-align: top;
  word-break: break-word;
}
td:first-child, th:first-child {
  width: 32% !important;
  font-variant-numeric: tabular-nums;
}
.nlb-timetable-legend {
  margin: 0 0 12px;
  padding: 8px 10px;
  border: 1px solid $border;
  border-radius: 8px;
}
.nlb-timetable-legend-title {
  margin: 0 0 4px;
  font-weight: 700;
  color: $primary;
}
.nlb-timetable-legend p {
  margin: 2px 0;
  font-weight: 400;
  color: $foreground;
}
.nlb-fare-note {
  margin: 0 0 12px;
  padding: 10px 12px;
  border: 1px solid $border;
  border-radius: 8px;
}
.nlb-fare-note p {
  margin: 0;
  font-weight: 400;
  color: $foreground;
}
</style>
</head>
<body>
${widget.html}
</body>
</html>
''';
  }

  String _css(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
