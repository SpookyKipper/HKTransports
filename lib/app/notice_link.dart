import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void openNotice(
  BuildContext context, {
  required String url,
  String? title,
  bool forcePdf = false,
}) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return;
  final bool pdf = forcePdf && !isNlbNewsUri(uri);
  context.push(
    Uri(
      path: '/notice',
      queryParameters: {
        'url': url,
        if (title != null && title.isNotEmpty) 'title': title,
        if (pdf) 'pdf': '1',
      },
    ).toString(),
  );
}

bool isNlbNewsUri(Uri uri) {
  final String host = uri.host.toLowerCase();
  if (host != 'nlb.com.hk' && !host.endsWith('.nlb.com.hk')) return false;
  final List<String> segments = uri.pathSegments;
  return segments.length >= 3 &&
      (segments[0] == 'tc' || segments[0] == 'en') &&
      segments[1] == 'news';
}
