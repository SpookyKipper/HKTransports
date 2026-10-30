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
              creditHost: ProprietaryNoticeService.kmbHost,
              errorText: settings.text(
                '未能載入九巴路線最新消息',
                'Could not load KMB route news',
              ),
              loader: () => const ProprietaryNoticeService()
                  .fetchKmbAnnouncements(route, zh: settings.isChinese),
            )
          else
            _DisabledSourceNotice(company: BusCompany.kmb),
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
    return _AsyncNoticeSection(
      key: ValueKey<String>('ctb-stop-$stopId-${settings.language}'),
      title: settings.text('城巴站務通告', 'Citybus stop notices'),
      titleStyle: Theme.of(context).textTheme.titleSmall,
      creditHost: ProprietaryNoticeService.citybusHost,
      showTopDivider: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      errorText: settings.text(
        '未能載入城巴站務通告',
        'Could not load Citybus stop notices',
      ),
      loader: () => const ProprietaryNoticeService().fetchCitybusStopNotices(
        stopId,
        zh: settings.isChinese,
      ),
    );
  }
}

class _CitybusNotices extends StatefulWidget {
  const _CitybusNotices({required this.route});

  final RouteEntry route;

  @override
  State<_CitybusNotices> createState() => _CitybusNoticesState();
}

class _CitybusNoticesState extends State<_CitybusNotices> {
  bool _specialHasNotices = false;
  bool _routeHasNotices = false;

  void _setSpecialHasNotices(bool value) {
    if (!mounted || _specialHasNotices == value) return;
    setState(() => _specialHasNotices = value);
  }

  void _setRouteHasNotices(bool value) {
    if (!mounted || _routeHasNotices == value) return;
    setState(() => _routeHasNotices = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AsyncNoticeSection(
          key: ValueKey<String>('ctb-special-${settings.language}'),
          title: settings.text('城巴特別通告', 'Citybus special notices'),
          errorText: settings.text(
            '未能載入城巴特別通告',
            'Could not load Citybus special notices',
          ),
          onHasDataChanged: _setSpecialHasNotices,
          loader: () => const ProprietaryNoticeService()
              .fetchCitybusSpecialNotices(widget.route, zh: settings.isChinese),
        ),
        _AsyncNoticeSection(
          key: ValueKey<String>('ctb-route-${settings.language}'),
          title: settings.text('城巴路線乘客通告', 'Citybus route passenger notices'),
          errorText: settings.text(
            '未能載入城巴路線乘客通告',
            'Could not load Citybus route notices',
          ),
          onHasDataChanged: _setRouteHasNotices,
          loader: () => const ProprietaryNoticeService()
              .fetchCitybusRouteNotices(widget.route, zh: settings.isChinese),
        ),
        if (_specialHasNotices || _routeHasNotices)
          _CreditsLine(host: ProprietaryNoticeService.citybusHost),
      ],
    );
  }
}

class _AsyncNoticeSection extends StatefulWidget {
  const _AsyncNoticeSection({
    super.key,
    required this.title,
    required this.errorText,
    required this.loader,
    this.creditHost,
    this.titleStyle,
    this.showTopDivider = false,
    this.padding,
    this.onHasDataChanged,
  });

  final String title;
  final String errorText;
  final TextStyle? titleStyle;
  final Future<List<ProprietaryNotice>> Function() loader;
  final String? creditHost;
  final bool showTopDivider;
  final EdgeInsetsGeometry? padding;
  final ValueChanged<bool>? onHasDataChanged;

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
      widget.onHasDataChanged?.call(notices.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notices = null;
        _failed = true;
      });
      widget.onHasDataChanged?.call(false);
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
    if (_notices != null && _notices!.isEmpty && !_failed) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            widget.title,
            style: widget.titleStyle ?? theme.textTheme.titleMedium,
          ),
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
        else ...[
          for (final ProprietaryNotice notice in _notices!)
            _NoticeCard(notice: notice),
          if (widget.creditHost != null) _CreditsLine(host: widget.creditHost!),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTopDivider) const Divider(),
        if (widget.padding != null)
          Padding(padding: widget.padding!, child: content)
        else
          content,
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

class _KmbBbiSection extends StatelessWidget {
  const _KmbBbiSection({required this.route});

  final RouteEntry route;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final bool jointlyOperated = route.companies.length > 1;
    final String title = jointlyOperated
        ? settings.text('九巴第二程路線轉乘計劃', 'KMB second-leg transfer scheme')
        : settings.text('第二程路線轉乘計劃', 'Second-leg transfer scheme');

    return Card.filled(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.alt_route),
        title: Text(title),
        subtitle: Text(
          settings.text('點按查看轉乘優惠', 'Tap to view transfer discounts'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _KmbBbiDialog(route: route, title: title),
        ),
      ),
    );
  }
}

class _KmbBbiDialog extends StatefulWidget {
  const _KmbBbiDialog({required this.route, required this.title});

  final RouteEntry route;
  final String title;

  @override
  State<_KmbBbiDialog> createState() => _KmbBbiDialogState();
}

class _KmbBbiDialogState extends State<_KmbBbiDialog> {
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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.title),
              subtitle: Text('Data from: ${ProprietaryNoticeService.kmbHost}'),
              trailing: IconButton(
                tooltip: settings.text('關閉', 'Close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _content(context, settings)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppSettings settings) {
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                settings.text('未能載入轉乘優惠', 'Could not load transfer discounts'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _retry,
                child: Text(settings.text('重試', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_entries == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(settings.text('正在載入', 'Loading')),
          ],
        ),
      );
    }
    if (_entries!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            settings.text('沒有適用路線', 'No routes applicable'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    return Column(
      children: [
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
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _entries!.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final KmbBbiEntry entry = _entries![index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 76, child: Text(entry.route)),
                    Expanded(child: Text(entry.destination(settings.language))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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
        'Data from: $host',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
