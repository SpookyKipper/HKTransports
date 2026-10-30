import 'package:flutter/material.dart';
import 'package:hktransports/app/notice_link.dart';
import 'package:hktransports/bus/notice/notice_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class NoticeBanner extends StatefulWidget {
  const NoticeBanner({super.key});

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner> {
  final NoticeService _service = NoticeService();
  List<AppNotice> _notices = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<AppNotice> notices = await _service.load();
    if (!mounted) return;
    setState(() {
      _notices = notices;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _notices.isEmpty) return const SizedBox.shrink();
    final AppSettings settings = context.watch<AppSettings>();
    final AppNotice notice = _notices.first;
    final List<String> content = notice.content(settings.language);
    if (content.isEmpty) return const SizedBox.shrink();
    final String link = notice.link(settings.language).isNotEmpty
        ? notice.link(settings.language)
        : notice.url;

    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          notice.icon == 'warning' ? Icons.warning_amber : Icons.info_outline,
        ),
        title: Text(content.first),
        subtitle: content.length > 1 ? Text(content.skip(1).join('\n')) : null,
        trailing: M3EIconButton(
          tooltip: settings.text('關閉通知', 'Dismiss notice'),
          icon: const Icon(Icons.close),
          variant: M3EIconButtonVariant.standard,
          onPressed: () {
            _service.dismiss(notice.id);
            setState(() => _notices = _notices.skip(1).toList());
          },
        ),
        onTap: link.isEmpty
            ? null
            : () => openNotice(context, url: link, title: content.first),
      ),
    );
  }
}
