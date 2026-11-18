import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/app/m3e_scope.dart';
import 'package:hktransports/app/notice_link.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/nlb/nlb_http.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NoticeViewerPage extends StatefulWidget {
  const NoticeViewerPage({
    super.key,
    required this.url,
    this.title,
    this.forcePdf = false,
  });

  final String url;
  final String? title;
  final bool forcePdf;

  @override
  State<NoticeViewerPage> createState() => _NoticeViewerPageState();
}

class _NoticeViewerPageState extends State<NoticeViewerPage> {
  WebViewController? _webViewController;
  bool _loading = true;
  bool _failed = false;
  late final bool _isPdf;

  bool get _isCitybusSpecial {
    final Uri? uri = Uri.tryParse(widget.url);
    return uri != null &&
        uri.host == 'mobile.citybus.com.hk' &&
        uri.path == '/nwp3/specialNote.php';
  }

  @override
  void initState() {
    super.initState();
    final Uri? uri = Uri.tryParse(widget.url);
    final bool isNlbNews = uri != null && isNlbNewsUri(uri);
    _isPdf = !isNlbNews && (widget.forcePdf || (uri != null && _isPdfUri(uri)));
    if (_isPdf || uri == null) {
      _loading = false;
      _failed = uri == null;
      return;
    }
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        _isCitybusSpecial ? Colors.transparent : Colors.white,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            final Uri? finished = Uri.tryParse(url);
            final bool targetLoaded =
                !isNlbNews || (finished != null && isNlbNewsUri(finished));
            if (!targetLoaded) return;
            await _applyNlbNoticeStyles();
            await _applyCitybusSpecialStyles();
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
          onSslAuthError: (SslAuthError error) {
            // NLB serves an incomplete certificate chain. The rest of the app
            // uses NlbHttp with the bundled GoDaddy intermediate certificate;
            // allow the same NLB pages to render in its notice WebView.
            final bool nlb = _isNlbHost(uri);
            final bool untrusted = error.platform.description
                .toLowerCase()
                .contains('not trusted');
            if (nlb && untrusted) {
              error.proceed().ignore();
            } else {
              error.cancel().ignore();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final Uri? target = Uri.tryParse(request.url);
            if (target != null && _isPdfUri(target)) {
              // Keep PDF navigation inside the app.
              if (mounted) {
                context.push(
                  Uri(
                    path: '/notice',
                    queryParameters: {'url': request.url},
                  ).toString(),
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    if (isNlbNews) {
      // Nuxt reads its colour mode from localStorage during startup, so set it
      // before navigating to the notice page.
      _webViewController!.loadHtmlString(
        _nlbLightBootstrap(uri.toString()),
        baseUrl: '${uri.scheme}://${uri.host}/',
      );
    } else {
      _webViewController!.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final String title = settings.text('通告', 'Notice');
    final ColorScheme scheme = _isCitybusSpecial
        ? Theme.of(context).colorScheme
        : (AppColorSchemes.lightOf(context) ?? fallbackLightScheme());
    final bool dark = scheme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: M3EScope(
        scheme: scheme,
        child: Theme(
          data: buildAppTheme(scheme, settings.transitionStyle),
          child: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                appBar: buildPageBar(
                  context,
                  title: title,
                  subtitle: widget.title,
                ),
                body: Column(
                  children: [
                    Expanded(child: _body(context, settings)),
                    _ViewerCredit(host: _host),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String get _host => Uri.tryParse(widget.url)?.host ?? '';

  Widget _body(BuildContext context, AppSettings settings) {
    if (_isPdf) {
      final Uri? uri = Uri.tryParse(widget.url);
      if (uri == null) return _error(context, settings);
      if (widget.forcePdf && _isNlbHost(uri)) {
        return _NlbPdfView(uri: uri, settings: settings);
      }
      final ThemeData theme = Theme.of(context);
      return PdfViewer.uri(
        uri,
        params: PdfViewerParams(
          backgroundColor: theme.colorScheme.surface,
          loadingBannerBuilder: (context, downloaded, total) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const M3ELoadingIndicator(size: 36),
                    const SizedBox(height: 12),
                    Text(settings.text('正在載入通告', 'Loading notice')),
                  ],
                ),
              ),
            );
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            return _error(context, settings);
          },
        ),
      );
    }
    if (_webViewController == null) return _error(context, settings);
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_loading)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const M3ELoadingIndicator(size: 36),
                      const SizedBox(height: 12),
                      Text(settings.text('正在載入通告', 'Loading notice')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_failed)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _error(context, settings),
            ),
          ),
      ],
    );
  }

  String _nlbLightBootstrap(String target) {
    return '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
<script>
try {
  localStorage.setItem('nuxt-color-mode', 'light');
} catch (_) {}
location.replace(${jsonEncode(target)});
</script>
</body>
</html>
''';
  }

  Future<void> _applyNlbNoticeStyles() async {
    final WebViewController? controller = _webViewController;
    final Uri? uri = Uri.tryParse(widget.url);
    if (controller == null || uri == null || !isNlbNewsUri(uri)) return;
    try {
      await controller.runJavaScript(_nlbNoticeStyleScript);
    } catch (_) {
      // Leave the page usable even if the style injection fails.
    }
  }

  Future<void> _applyCitybusSpecialStyles() async {
    if (!_isCitybusSpecial) return;
    final WebViewController? controller = _webViewController;
    if (controller == null) return;
    try {
      await controller.runJavaScript(
        _citybusSpecialStyleScript(Theme.of(context).colorScheme),
      );
    } catch (_) {
      // Leave the page usable even if the style injection fails.
    }
  }

  Widget _error(BuildContext context, AppSettings settings) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              settings.text('未能載入通告', 'Could not load notice'),
              textAlign: TextAlign.center,
            ),
            if (_webViewController != null) ...[
              const SizedBox(height: 12),
              M3EButton.text(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _failed = false;
                  });
                  _webViewController!.reload();
                },
                child: Text(settings.text('重試', 'Retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewerCredit extends StatelessWidget {
  const _ViewerCredit({required this.host});

  final String host;

  @override
  Widget build(BuildContext context) {
    if (host.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Data from: $host',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

String _citybusSpecialStyleScript(ColorScheme colors) {
  final String text = _cssColor(colors.onSurface);
  final String primary = _cssColor(colors.primary);
  final String outline = _cssColor(colors.outlineVariant);
  return '''
(() => {
  let style = document.getElementById('hktransports-citybus-special-style');
  if (!style) {
    style = document.createElement('style');
    style.id = 'hktransports-citybus-special-style';
    document.head.appendChild(style);
  }
  style.textContent = `
    html, body {
      background: transparent !important;
      color: $text !important;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      font-size: 15px;
      line-height: 1.45;
      margin: 0;
      padding: 16px;
    }
    #specialnotelist {
      background: transparent !important;
      color: $text !important;
      height: auto !important;
      overflow: visible !important;
    }
    #specialnotelist table {
      width: 100% !important;
      border-color: $outline !important;
      border-collapse: collapse !important;
    }
    #specialnotelist td {
      color: $text !important;
      border-color: $outline !important;
      padding: 8px 0 !important;
    }
    #specialnotelist td[style*="font-weight:bold"],
    #specialnotelist td[style*="font-weight: bold"] {
      color: $primary !important;
      font-weight: 600 !important;
      padding-top: 16px !important;
    }
    #specialnotelist td[style*="background-color"] {
      background: transparent !important;
    }
    #specialnotelist td[style*="border-bottom"] {
      border-bottom: 1px solid $outline !important;
    }
    #specialnotelist img[src*="close"],
    #specialnotelist img[title="關閉"],
    #specialnotelist [onclick*="hidespecialNote"] {
      display: none !important;
    }
    #specialnotelist iframe {
      display: none !important;
    }
  `;
})();
''';
}

String _cssColor(Color color) {
  final int value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}

const String _nlbNoticeStyleScript = r'''
(() => {
  let style = document.getElementById('hktransports-nlb-notice-style');
  if (!style) {
    style = document.createElement('style');
    style.id = 'hktransports-nlb-notice-style';
    document.head.appendChild(style);
  }
  style.textContent = `
    #__nuxt > div > header,
    #__nuxt > div > footer,
    #__nuxt > div > aside,
    body > div:not(#__nuxt):not(#teleports),
    body > iframe,
    article > a[href*="/news"] {
      display: none !important;
    }
    main > div {
      padding-top: 8px !important;
      padding-bottom: 24px !important;
    }
    article {
      margin: 0 !important;
      max-width: none !important;
    }
    article > header {
      margin-top: 0 !important;
    }
  `;
})();
''';

bool _isPdfUri(Uri uri) {
  if (uri.path.toLowerCase().endsWith('.pdf')) return true;
  final String source = uri.queryParameters['url']?.toLowerCase() ?? '';
  return source.endsWith('.pdf');
}

bool _isNlbHost(Uri uri) {
  return uri.host == 'nlb.com.hk' || uri.host.endsWith('.nlb.com.hk');
}

class _NlbPdfView extends StatefulWidget {
  const _NlbPdfView({required this.uri, required this.settings});

  final Uri uri;
  final AppSettings settings;

  @override
  State<_NlbPdfView> createState() => _NlbPdfViewState();
}

class _NlbPdfViewState extends State<_NlbPdfView> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = NlbHttp.getBytes(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const M3ELoadingIndicator(size: 36),
                  const SizedBox(height: 12),
                  Text(widget.settings.text('正在載入通告', 'Loading notice')),
                ],
              ),
            ),
          );
        }
        final Uint8List? bytes = snapshot.data;
        if (bytes == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(widget.settings.text('未能載入通告', 'Could not load notice')),
                  const SizedBox(height: 12),
                  M3EButton.text(
                    onPressed: () => setState(_load),
                    child: Text(widget.settings.text('重試', 'Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        return PdfViewer.data(
          bytes,
          sourceName: widget.uri.toString(),
          params: PdfViewerParams(backgroundColor: theme.colorScheme.surface),
        );
      },
    );
  }
}
