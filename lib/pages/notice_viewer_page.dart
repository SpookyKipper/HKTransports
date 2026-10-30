import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NoticeViewerPage extends StatefulWidget {
  const NoticeViewerPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<NoticeViewerPage> createState() => _NoticeViewerPageState();
}

class _NoticeViewerPageState extends State<NoticeViewerPage> {
  WebViewController? _webViewController;
  bool _loading = true;
  bool _failed = false;
  late final bool _isPdf;

  @override
  void initState() {
    super.initState();
    final Uri? uri = Uri.tryParse(widget.url);
    _isPdf = uri != null && _isPdfUri(uri);
    if (_isPdf || uri == null) {
      _loading = false;
      _failed = uri == null;
      return;
    }
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) {
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
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final String title = settings.text('通告', 'Notice');
    return Scaffold(
      appBar: buildPageBar(context, title: title, subtitle: widget.title),
      body: Column(
        children: [
          Expanded(child: _body(context, settings)),
          _ViewerCredit(host: _host),
        ],
      ),
    );
  }

  String get _host => Uri.tryParse(widget.url)?.host ?? '';

  Widget _body(BuildContext context, AppSettings settings) {
    if (_isPdf) {
      final Uri? uri = Uri.tryParse(widget.url);
      if (uri == null) return _error(context, settings);
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
                    CircularProgressIndicator(
                      value: total == null ? null : downloaded / total,
                    ),
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
        if (_loading) const LinearProgressIndicator(minHeight: 2),
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

bool _isPdfUri(Uri uri) {
  if (uri.path.toLowerCase().endsWith('.pdf')) return true;
  final String source = uri.queryParameters['url']?.toLowerCase() ?? '';
  return source.endsWith('.pdf');
}
