import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void openNotice(BuildContext context, {required String url, String? title}) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return;
  context.push(
    Uri(
      path: '/notice',
      queryParameters: {
        'url': url,
        if (title != null && title.isNotEmpty) 'title': title,
      },
    ).toString(),
  );
}
