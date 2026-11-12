import 'package:flutter/material.dart';
import 'package:hktransports/app/notice_link.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/notice/proprietary_notice_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:hktransports/bus/ui/official_links.dart';
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
    final bool showNlbFareTable =
        route.companies.contains(BusCompany.nlb) &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.nlbProprietaryData);
    final bool showNlbRouteNotices =
        route.companies.contains(BusCompany.nlb) &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.nlbRouteNotices);
    final bool showKmbNews =
        hasKmb &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.kmbAnnouncements);
    final bool showKmbBbi =
        hasKmb &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.kmbInterchange);
    final bool showCtbSpecial =
        hasCtb &&
        settings.isProprietaryEnabled(
          ProprietaryEndpoint.citybusSpecialNotices,
        );
    final bool showCtbRouteNotices =
        hasCtb &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.citybusRouteNotices);
    final bool showCtbBbi =
        hasCtb &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.citybusInterchange);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (showNlbFareTable) _NlbFareTableNotice(route: route),
        if (showNlbRouteNotices)
          _AsyncNoticeSection(
            key: ValueKey<String>('nlb-route-${settings.language}'),
            title: settings.text('嶼巴路線通告', 'NLB route notices'),
            creditHost: 'www.nlb.com.hk',
            errorText: settings.text(
              '未能載入嶼巴路線通告',
              'Could not load NLB route notices',
            ),
            loader: () async {
              final List<NlbRouteNotice> notices = await NlbTimetableService
                  .instance
                  .fetchRouteNotices(route, settings.language);
              return <ProprietaryNotice>[
                for (final NlbRouteNotice notice in notices)
                  ProprietaryNotice(
                    title: notice.title,
                    date: notice.date,
                    url: notice.url,
                  ),
              ];
            },
          ),
        if (showKmbNews)
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
          ),
        if (showCtbSpecial || showCtbRouteNotices)
          _CitybusNotices(
            route: route,
            showSpecial: showCtbSpecial,
            showRouteNotices: showCtbRouteNotices,
          ),
        if (showKmbBbi) _BbiSection(company: BusCompany.kmb, route: route),
        if (showCtbBbi)
          _BbiSection(
            company: BusCompany.ctb,
            route: route,
            topMargin: showKmbBbi ? 0 : 12,
          ),
      ],
    );
  }
}

class _NlbFareTableNotice extends StatefulWidget {
  const _NlbFareTableNotice({required this.route});

  final RouteEntry route;

  @override
  State<_NlbFareTableNotice> createState() => _NlbFareTableNoticeState();
}

class _NlbFareTableNoticeState extends State<_NlbFareTableNotice> {
  Future<NlbRoutePageData?>? _future;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String language = context.read<AppSettings>().language;
    if (_language == language) return;
    _language = language;
    _load(language);
  }

  @override
  void didUpdateWidget(covariant _NlbFareTableNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.route.nlbRouteId != widget.route.nlbRouteId) {
      _load(_language ?? context.read<AppSettings>().language);
    }
  }

  void _load(String language) {
    _future = NlbTimetableService.instance.fetchRouteData(
      widget.route,
      language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    final Uri uri = Uri.parse(nlbFareTableUrl(widget.route.nlbRouteId));
    final String title = settings.text('車資表', 'Fare Table');
    final Future<NlbRoutePageData?>? future = _future;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(title),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => openNotice(
              context,
              url: uri.toString(),
              title: title,
              forcePdf: true,
            ),
          ),
          if (future != null)
            FutureBuilder<NlbRoutePageData?>(
              future: future,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<NlbRoutePageData?> snapshot,
                  ) {
                    final String note = snapshot.data?.fareNote?.trim() ?? '';
                    if (note.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
            ),
        ],
      ),
    );
  }
}

class CitybusStopNotices extends StatelessWidget {
  const CitybusStopNotices({super.key, required this.stopId});

  final String stopId;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    if (!settings.isProprietaryEnabled(
      ProprietaryEndpoint.citybusStopNotices,
    )) {
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
  const _CitybusNotices({
    required this.route,
    required this.showSpecial,
    required this.showRouteNotices,
  });

  final RouteEntry route;
  final bool showSpecial;
  final bool showRouteNotices;

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
        if (widget.showSpecial)
          _AsyncNoticeSection(
            key: ValueKey<String>('ctb-special-${settings.language}'),
            title: settings.text('城巴特別通告', 'Citybus special notices'),
            errorText: settings.text(
              '未能載入城巴特別通告',
              'Could not load Citybus special notices',
            ),
            onHasDataChanged: _setSpecialHasNotices,
            loader: () =>
                const ProprietaryNoticeService().fetchCitybusSpecialNotices(
                  widget.route,
                  zh: settings.isChinese,
                ),
          ),
        if (widget.showRouteNotices)
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
              M3EButton.text(
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
            child: Center(child: M3ELoadingIndicator(size: 24)),
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
    return Card.filled(
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

class _BbiSection extends StatelessWidget {
  const _BbiSection({
    required this.company,
    required this.route,
    this.topMargin = 12,
  });

  final BusCompany company;
  final RouteEntry route;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final bool kmb = company == BusCompany.kmb;
    final String title = kmb
        ? settings.text('九巴/龍運轉乘優惠', 'KMB/LWB interchange discounts')
        : settings.text('城巴轉乘優惠', 'Citybus interchange discounts');

    return Card.filled(
      margin: EdgeInsets.only(top: topMargin, bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.alt_route),
        title: Text(title),
        subtitle: Text(
          settings.text('點按查看轉乘優惠', 'Tap to view interchange discounts'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) =>
              _BbiDialog(company: company, route: route, title: title),
        ),
      ),
    );
  }
}

class _BbiDialog extends StatefulWidget {
  const _BbiDialog({
    required this.company,
    required this.route,
    required this.title,
  });

  final BusCompany company;
  final RouteEntry route;
  final String title;

  @override
  State<_BbiDialog> createState() => _BbiDialogState();
}

class _BbiDialogState extends State<_BbiDialog> {
  BbiLeg _leg = BbiLeg.first;
  List<BbiEntry>? _entries;
  bool _failed = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final String value = _searchController.text;
    if (value == _query) return;
    setState(() => _query = value);
  }

  Future<void> _load() async {
    final BbiLeg requestedLeg = _leg;
    try {
      final AppSettings settings = context.read<AppSettings>();
      final BbiService service = const BbiService();
      final List<BbiEntry> entries = widget.company == BusCompany.kmb
          ? await service.loadKmb(
              widget.route,
              zh: settings.isChinese,
              leg: requestedLeg,
            )
          : await service.loadCitybus(
              widget.route,
              zh: settings.isChinese,
              leg: requestedLeg,
            );
      if (!mounted || requestedLeg != _leg) return;
      setState(() {
        _entries = entries;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || requestedLeg != _leg) return;
      setState(() {
        _entries = null;
        _failed = true;
      });
    }
  }

  void _selectLeg(BbiLeg leg) {
    if (_leg == leg) return;
    setState(() {
      _leg = leg;
      _entries = null;
      _failed = false;
    });
    _load();
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
    final bool kmb = widget.company == BusCompany.kmb;
    final String host = kmb ? BbiService.kmbHost : BbiService.citybusHost;
    final ThemeData theme = Theme.of(context);
    final Color searchBackground = theme.colorScheme.surfaceContainerHighest;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.title),
              subtitle: Text('Data from: $host'),
              trailing: M3EIconButton(
                tooltip: settings.text('關閉', 'Close'),
                variant: M3EIconButtonVariant.standard,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: M3ESegmentedButton<BbiLeg>(
                segments: [
                  M3ESegment(
                    value: BbiLeg.first,
                    label: settings.text('本線為首程', 'First leg'),
                  ),
                  M3ESegment(
                    value: BbiLeg.second,
                    label: settings.text('本線為次程', 'Second leg'),
                  ),
                ],
                selected: {_leg},
                showSelectedIcon: false,
                onSelectionChanged: (Set<BbiLeg> selection) {
                  if (selection.isNotEmpty) _selectLeg(selection.first);
                },
              ),
            ),
            if (!_failed && _entries != null && _entries!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search),
                  hintText: settings.text('搜尋轉乘路線', 'Search transfer routes'),
                  backgroundColor: WidgetStatePropertyAll(searchBackground),
                  elevation: const WidgetStatePropertyAll(0),
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: settings.text('清除', 'Clear'),
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close),
                      ),
                  ],
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
                settings.text('未能載入轉乘資料', 'Could not load interchange data'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              M3EButton.text(
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const M3ELoadingIndicator(),
              const SizedBox(height: 12),
              Text(
                settings.text('正在載入轉乘資料', 'Loading interchange data'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final List<BbiEntry> allEntries = _entries!;
    final String query = _query.trim().toLowerCase();
    final List<BbiEntry> entries = query.isEmpty
        ? allEntries
        : allEntries.where((BbiEntry entry) {
            return entry.route.toLowerCase().contains(query) ||
                entry.destination.toLowerCase().contains(query) ||
                entry.stop.toLowerCase().contains(query);
          }).toList();
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            query.isEmpty
                ? settings.text('沒有適用路線', 'No routes applicable')
                : settings.text('沒有符合的轉乘路線', 'No matching transfer routes'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _BbiCard(entry: entries[index], leg: _leg);
      },
    );
  }
}

class _BbiCard extends StatelessWidget {
  const _BbiCard({required this.entry, required this.leg});

  final BbiEntry entry;
  final BbiLeg leg;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.route, style: theme.textTheme.titleMedium),
                const SizedBox(width: 6),
                Text(
                  leg == BbiLeg.first
                      ? settings.text('次程', 'Second leg')
                      : settings.text('首程', 'First leg'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${settings.text('往', 'to')} ${entry.destination}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (entry.stop.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(entry.stop)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (entry.discount.isNotEmpty)
                  _BbiTag(icon: Icons.payments_outlined, label: entry.discount),
                if (entry.timeLimit.isNotEmpty)
                  _BbiTag(icon: Icons.schedule, label: entry.timeLimit),
                if (entry.consecutive.isNotEmpty)
                  _BbiTag(
                    icon: Icons.repeat,
                    label:
                        '${settings.text('連續', 'Consecutive')} ${entry.consecutive}',
                  ),
              ],
            ),
            if (entry.remark.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.remark,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (entry.detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BbiTag extends StatelessWidget {
  const _BbiTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: theme.textTheme.labelMedium)),
        ],
      ),
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
