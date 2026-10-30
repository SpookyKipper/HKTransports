import 'package:flutter/material.dart';
import 'package:hktransports/app/notice_link.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/notice/proprietary_notice_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class ProprietaryNoticesTab extends StatelessWidget {
  const ProprietaryNoticesTab({super.key, required this.route});

  final RouteEntry route;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final bool hasKmb = route.companies.contains(BusCompany.kmb);
    final bool hasCtb = route.companies.contains(BusCompany.ctb);
    final bool kmbEnabled = settings.isProprietaryEnabled(
      ProprietaryDataSource.kmb,
    );
    final bool ctbEnabled = settings.isProprietaryEnabled(
      ProprietaryDataSource.citybus,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (hasKmb)
          if (kmbEnabled)
            _AsyncNoticeSection(
              key: ValueKey<String>('kmb-${settings.language}'),
              title: settings.text('九巴路線最新消息', 'KMB route news'),
              emptyText: settings.text('現時沒有路線最新消息', 'No route news'),
              errorText: settings.text(
                '未能載入九巴路線最新消息',
                'Could not load KMB route news',
              ),
              loader: () => const ProprietaryNoticeService()
                  .fetchKmbAnnouncements(route, zh: settings.isChinese),
            )
          else
            _DisabledSourceNotice(company: BusCompany.kmb),
        if (hasKmb && kmbEnabled)
          _CreditsLine(host: ProprietaryNoticeService.kmbHost),
        if (hasCtb)
          if (ctbEnabled)
            _CitybusNotices(route: route)
          else
            _DisabledSourceNotice(company: BusCompany.ctb),
        if (hasKmb && kmbEnabled) _KmbBbiSection(route: route),
      ],
    );
  }
}

class CitybusStopNotices extends StatelessWidget {
  const CitybusStopNotices({super.key, required this.stopId});

  final String stopId;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    if (!settings.isProprietaryEnabled(ProprietaryDataSource.citybus)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AsyncNoticeSection(
            key: ValueKey<String>('ctb-stop-$stopId-${settings.language}'),
            title: settings.text('城巴站務通告', 'Citybus stop notices'),
            emptyText: settings.text('現時沒有站務通告', 'No stop notices'),
            errorText: settings.text(
              '未能載入城巴站務通告',
              'Could not load Citybus stop notices',
            ),
            loader: () => const ProprietaryNoticeService()
                .fetchCitybusStopNotices(stopId, zh: settings.isChinese),
          ),
        ),
        _CreditsLine(host: ProprietaryNoticeService.citybusHost),
      ],
    );
  }
}

class _CitybusNotices extends StatelessWidget {
  const _CitybusNotices({required this.route});

  final RouteEntry route;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AsyncNoticeSection(
          key: ValueKey<String>('ctb-special-${settings.language}'),
          title: settings.text('城巴特別通告', 'Citybus special notices'),
          emptyText: settings.text('現時沒有特別通告', 'No special notices'),
          errorText: settings.text(
            '未能載入城巴特別通告',
            'Could not load Citybus special notices',
          ),
          loader: () => const ProprietaryNoticeService()
              .fetchCitybusSpecialNotices(route, zh: settings.isChinese),
        ),
        _AsyncNoticeSection(
          key: ValueKey<String>('ctb-route-${settings.language}'),
          title: settings.text('城巴路線乘客通告', 'Citybus route passenger notices'),
          emptyText: settings.text('現時沒有路線乘客通告', 'No route passenger notices'),
          errorText: settings.text(
            '未能載入城巴路線乘客通告',
            'Could not load Citybus route notices',
          ),
          loader: () => const ProprietaryNoticeService()
              .fetchCitybusRouteNotices(route, zh: settings.isChinese),
        ),
        _CreditsLine(host: ProprietaryNoticeService.citybusHost),
      ],
    );
  }
}

class _AsyncNoticeSection extends StatefulWidget {
  const _AsyncNoticeSection({
    super.key,
    required this.title,
    required this.emptyText,
    required this.errorText,
    required this.loader,
  });

  final String title;
  final String emptyText;
  final String errorText;
  final Future<List<ProprietaryNotice>> Function() loader;

  @override
  State<_AsyncNoticeSection> createState() => _AsyncNoticeSectionState();
}

class _AsyncNoticeSectionState extends State<_AsyncNoticeSection> {
  List<ProprietaryNotice>? _notices;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<ProprietaryNotice> notices = await widget.loader();
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notices = null;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _notices = null;
      _failed = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(widget.title, style: theme.textTheme.titleMedium),
        ),
        if (_failed)
          Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.errorText)),
              TextButton(
                onPressed: _retry,
                child: Text(
                  Provider.of<AppSettings>(
                    context,
                    listen: false,
                  ).text('重試', 'Retry'),
                ),
              ),
            ],
          )
        else if (_notices == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: M3EProgressIndicator.linear(
              strokeWidth: 4,
              trackStrokeWidth: 4,
            ),
          )
        else if (_notices!.isEmpty)
          Text(
            widget.emptyText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final ProprietaryNotice notice in _notices!)
            _NoticeCard(notice: notice),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final ProprietaryNotice notice;

  @override
  Widget build(BuildContext context) {
    final List<String> meta = [
      if (notice.date != null) notice.date!,
      if (notice.detail != null) notice.detail!,
    ];
    final Uri? url = notice.url;
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(notice.title),
        subtitle: meta.isEmpty ? null : Text(meta.join(' · ')),
        trailing: url == null ? null : const Icon(Icons.open_in_new),
        onTap: url == null
            ? null
            : () =>
                  openNotice(context, url: url.toString(), title: notice.title),
      ),
    );
  }
}

class _DisabledSourceNotice extends StatelessWidget {
  const _DisabledSourceNotice({required this.company});

  final BusCompany company;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final String name = company.label(settings.language);
    final bool kmb = company == BusCompany.kmb;
    return Card.filled(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text(
          settings.text('$name通告未顯示', '$name notices are not displayed'),
        ),
        subtitle: Text(
          kmb
              ? settings.text(
                  '九巴專有資料來源尚未啟用。如需查看，請在「設定」→「專有資料」中啟用。',
                  'The KMB proprietary source is not enabled. Enable it in Settings → Proprietary data to view these notices.',
                )
              : settings.text(
                  '城巴專有資料來源尚未啟用。如需查看，請在「設定」→「專有資料」中啟用。',
                  'The Citybus proprietary source is not enabled. Enable it in Settings → Proprietary data to view these notices.',
                ),
        ),
      ),
    );
  }
}

class _KmbBbiSection extends StatefulWidget {
  const _KmbBbiSection({required this.route});

  final RouteEntry route;

  @override
  State<_KmbBbiSection> createState() => _KmbBbiSectionState();
}

class _KmbBbiSectionState extends State<_KmbBbiSection> {
  List<KmbBbiEntry>? _entries;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<KmbBbiEntry> entries = await const ProprietaryNoticeService()
          .fetchKmbBbi(widget.route);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = null;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _entries = null;
      _failed = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final int count = _entries?.length ?? 0;
    final String subtitle;
    if (_failed) {
      subtitle = settings.text('載入失敗，點按重試', 'Could not load; tap to retry');
    } else if (_entries == null) {
      subtitle = settings.text('載入中', 'Loading');
    } else if (_entries!.isEmpty) {
      subtitle = settings.text('現時沒有轉乘優惠資料', 'No transfer discounts available');
    } else {
      subtitle = settings.text(
        '點按查看 $count 項轉乘優惠',
        'Tap to view $count transfer discounts',
      );
    }

    return Card.filled(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.alt_route),
        title: Text(settings.text('第二程路線轉乘計劃', 'Second-leg transfer scheme')),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _entries != null && _entries!.isNotEmpty
            ? () => _showDialog(context, _entries!)
            : _failed
            ? _retry
            : null,
      ),
    );
  }

  Future<void> _showDialog(
    BuildContext context,
    List<KmbBbiEntry> entries,
  ) async {
    final AppSettings settings = context.read<AppSettings>();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(dialogContext).height * 0.8,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    settings.text('第二程路線轉乘計劃', 'Second-leg transfer scheme'),
                  ),
                  subtitle: Text(
                    settings.text(
                      'Credits: search.kmb.hk',
                      'Credits: search.kmb.hk',
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: settings.text('關閉', 'Close'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          settings.text('第二程路線', 'Second route'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          settings.text('目的地', 'Destination'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          settings.text('優惠', 'Discount'),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final KmbBbiEntry entry = entries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 76, child: Text(entry.route)),
                            Expanded(
                              child: Text(entry.destination(settings.language)),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text(
                                _discountLabel(entry.discount),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    settings.text(
                      '轉乘優惠資料由 search.kmb.hk 提供',
                      'Transfer discount data provided by search.kmb.hk',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _discountLabel(String value) {
    final double? discount = double.tryParse(value);
    if (discount == null) return value.isEmpty ? '—' : value;
    if (discount <= 0) return '—';
    final String amount = discount == discount.truncateToDouble()
        ? discount.toStringAsFixed(0)
        : discount.toStringAsFixed(1);
    return '\$$amount';
  }
}

class _CreditsLine extends StatelessWidget {
  const _CreditsLine({required this.host});

  final String host;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        'Credits: $host',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
