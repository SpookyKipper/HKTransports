import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_data_updater.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/route_group_sheet.dart';
import 'package:hktransports/bus/ui/timetable_sheet.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutePageRoute extends StatelessWidget {
  const RoutePageRoute({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final BusRepository repository = context.watch<BusRepository>();
    final RouteEntry? route = repository.routeBySlug(slug);
    if (route == null) {
      final AppSettings settings = context.watch<AppSettings>();
      return Scaffold(
        appBar: buildPageBar(context, title: settings.text('路線', 'Route')),
        body: Center(child: Text(settings.text('找不到路線', 'Route not found'))),
      );
    }
    return _RoutePage(key: ValueKey(route.key), route: route);
  }
}

class _RoutePage extends StatefulWidget {
  const _RoutePage({super.key, required this.route});

  final RouteEntry route;

  @override
  State<_RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<_RoutePage> {
  late final EtaService _etaService;
  final Map<int, List<BusEta>?> _etas = {};
  final Set<int> _loading = {};
  Timer? _timer;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = context.read<AppSettings>();
    _etaService = EtaService(language: settings.language);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppSettings settings = context.read<AppSettings>();
    _etaService.setLanguage(settings.language);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRefresh(int index) {
    _timer?.cancel();
    _fetch(index);
    final AppSettings settings = context.read<AppSettings>();
    _timer = Timer.periodic(
      Duration(seconds: settings.refreshSeconds),
      (_) => _fetch(index),
    );
  }

  Future<void> _fetch(int index) async {
    if (_loading.contains(index)) return;
    setState(() => _loading.add(index));
    final List<BusEta> etas = await _etaService.fetchRouteStop(
      widget.route,
      index,
    );
    if (!mounted) return;
    setState(() {
      _loading.remove(index);
      _etas[index] = etas;
    });
  }

  void _onExpansionChanged(int index, bool expanded) {
    if (expanded) {
      setState(() => _expandedIndex = index);
      _startRefresh(index);
    } else {
      setState(() {
        _expandedIndex = null;
        _loading.remove(index);
      });
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final RouteEntry route = widget.route;
    final List<String> stopIds = route.primaryStops;
    final bool holiday = isHoliday(
      repository.database?.holidays ?? const [],
      hkNow(),
    );

    final RouteEntry? reverse = repository.findReverse(route);
    return Scaffold(
      appBar: buildPageBar(
        context,
        title:
            '${route.route} ${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
        actions: [
          if (reverse != null)
            IconButton(
              tooltip: settings.text('對頭線', 'Reverse route'),
              onPressed: () =>
                  context.pushReplacement('/route/${reverse.slug}?fade=1'),
              icon: const Icon(Icons.swap_horiz),
            ),
          IconButton(
            tooltip: settings.text('收藏', 'Favourites'),
            onPressed: () => showRouteGroupSheet(
              context,
              route,
              stopSeq: _expandedIndex ?? 0,
            ),
            icon: Icon(
              repository.isRouteInAnyGroup(route.key)
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
          IconButton(
            tooltip: settings.text('時間表', 'Timetable'),
            onPressed: () =>
                _showTimetable(context, route, _expandedIndex ?? 0),
            icon: const Icon(Icons.schedule),
          ),
        ],
      ),
      body: Column(
        children: [
          _RouteHeader(route: route),
          _RouteUpdateNotice(route: route),
          Expanded(
            child: M3EPullToRefreshIndicator(
              indicatorIcon: const M3EContainedLoadingIndicator(
                width: 48,
                height: 48,
                padding: EdgeInsets.all(4),
              ),
              onRefresh: () async {
                final int? index = _expandedIndex;
                if (index != null) await _fetch(index);
              },
              child: M3EExpandableCardList.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: stopIds.length,
                allowMultipleExpanded: false,
                initiallyExpanded: const {},
                onExpansionChanged: _onExpansionChanged,
                style: M3EExpandableStyle(
                  outerRadius: 24,
                  innerRadius: 8,
                  hoverRadius: 10,
                  pressedRadius: 4,
                  border: BorderSide.none,
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  headerPadding: const EdgeInsets.all(16),
                  bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  iconPlacement: IconPlacement.right,
                ),
                headerBuilder: (context, index, progress) => _buildStopHeader(
                  context,
                  repository,
                  route,
                  stopIds,
                  index,
                  holiday,
                ),
                bodyBuilder: (context, index, progress) =>
                    _buildStopBody(context, route, stopIds, index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopHeader(
    BuildContext context,
    BusRepository repository,
    RouteEntry route,
    List<String> stopIds,
    int index,
    bool holiday,
  ) {
    final AppSettings settings = context.watch<AppSettings>();
    final String stopId = stopIds[index];
    final StopEntry? stop = repository.stopById(stopId);
    final String name = stop?.displayName(settings.language) ?? stopId;
    final String? fare = route.fareAt(index, holiday: holiday);
    final String? normalFare = route.fareAt(index, holiday: false);
    final String? code = stop?.stationCode;
    final String? platform = stop?.platformCode;
    final bool isTerminus = index == stopIds.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 48,
          child: Center(
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isTerminus)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        settings.text('總站', 'Terminus'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (fare != null)
                    Text(
                      '${settings.text('車費', 'Fare')} \$$fare',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (normalFare != null)
                    Text(
                      '${settings.text('車費', 'Fare')} \$$normalFare',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (code != null)
                    Text(
                      '${settings.text('站碼', 'Code')} $code',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  if (platform != null)
                    Text(
                      '${settings.text('月台', 'Platform')} $platform',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStopBody(
    BuildContext context,
    RouteEntry route,
    List<String> stopIds,
    int index,
  ) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.read<BusRepository>();
    final Map<String, int> stopIndexByCode = {};
    for (int i = 0; i < stopIds.length; i++) {
      final String? code = repository.stopById(stopIds[i])?.stationCode;
      if (code != null) {
        stopIndexByCode.putIfAbsent(code, () => i);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EtaList(
          loading: _loading.contains(index),
          etas: _etas[index],
          showCompany: route.companies.length > 1,
          atOrigin: index == 0,
          stopIndex: index,
          stopIndexByCode: stopIndexByCode,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showStopInfo(context, route, stopIds[index]),
            icon: const Icon(Icons.info_outline),
            label: Text(settings.text('車站資訊', 'Stop information')),
          ),
        ),
      ],
    );
  }

  void _showStopInfo(BuildContext context, RouteEntry route, String stopId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _StopInfoSheet(route: route, stopId: stopId);
      },
    );
  }

  void _showTimetable(BuildContext context, RouteEntry route, int stopIndex) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return TimetableSheet(route: route, initialStopIndex: stopIndex);
      },
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({required this.route});

  final RouteEntry route;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: Card.filled(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.route,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${settings.text('由', 'from')} ${route.orig.get(settings.language)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  route.companiesLabel(settings.language),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (route.jt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${settings.text('全程約', 'About')} ${route.jt} ${settings.text('分鐘', 'minutes')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EtaList extends StatelessWidget {
  const _EtaList({
    required this.loading,
    required this.etas,
    required this.showCompany,
    required this.atOrigin,
    required this.stopIndex,
    required this.stopIndexByCode,
  });

  final bool loading;
  final List<BusEta>? etas;
  final bool showCompany;
  final bool atOrigin;
  final int stopIndex;
  final Map<String, int> stopIndexByCode;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final List<BusEta> visible = (etas ?? const [])
        .where(
          (eta) => eta.eta != null || eta.remark(settings.language).isNotEmpty,
        )
        .toList();

    if (loading && visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: M3ELinearProgressIndicator(),
      );
    }
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          settings.text('暫無到站資料', 'No arrival data'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int index = 0; index < visible.length; index++)
          _EtaLine(
            eta: visible[index],
            first: index == 0,
            showCompany: showCompany,
            atOrigin: atOrigin,
            stopIndex: stopIndex,
            stopIndexByCode: stopIndexByCode,
          ),
      ],
    );
  }
}

class _EtaLine extends StatelessWidget {
  const _EtaLine({
    required this.eta,
    required this.first,
    required this.showCompany,
    required this.atOrigin,
    required this.stopIndex,
    required this.stopIndexByCode,
  });

  final BusEta eta;
  final bool first;
  final bool showCompany;
  final bool atOrigin;
  final int stopIndex;
  final Map<String, int> stopIndexByCode;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final Color color = first
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final DateTime? time = eta.eta;
    final String remark = eta.remark(settings.language);
    final String company = eta.company.label(settings.language);

    if (time == null) {
      final String message = eta.isDelayedJourney && remark.isNotEmpty
          ? '$company · $remark'
          : remark;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      );
    }

    final DateTime hkTime = time.toUtc().add(const Duration(hours: 8));
    final String clock = DateFormat('HH:mm').format(hkTime);
    final int minutes = time.difference(DateTime.now().toUtc()).inMinutes;
    final String wait = minutes < 1
        ? atOrigin
              ? settings.text('即場開出', 'Departing now')
              : settings.text('即將到達', 'Arriving')
        : '$minutes ${settings.text('分鐘', 'min')}';

    final String parts = switch (settings.etaFormat) {
      EtaFormat.diff => wait,
      EtaFormat.exact => clock,
      EtaFormat.mixed => '$clock  $wait',
    };
    final bool showDelayedEta = eta.canShowDelayedEta(
      stopIndex: stopIndex,
      stopIndexByCode: stopIndexByCode,
      minutes: minutes,
    );
    if (!showDelayedEta) {
      final String message = remark.isEmpty
          ? settings.text('延誤', 'Delayed')
          : remark;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$company · $message',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: settings.text(
                '預計時間不準確',
                'Estimated time may be inaccurate',
              ),
              child: TextButton.icon(
                onPressed: () =>
                    _showDelayedEtaDialog(context, settings, parts, message),
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(parts),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final String via = eta.company == BusCompany.nlb
        ? eta.dest(settings.language).trim()
        : '';
    final String suffix = [
      if (showCompany || eta.isDelayedJourney) company,
      if (remark.isNotEmpty) remark,
      if (eta.scheduled && remark.isEmpty) settings.text('預定班次', 'Scheduled'),
      if (via.isNotEmpty) via,
    ].join(' · ');

    final TextStyle? style = first
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(suffix.isEmpty ? parts : '$parts  ·  $suffix', style: style),
    );
  }

  void _showDelayedEtaDialog(
    BuildContext context,
    AppSettings settings,
    String etaText,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(settings.text('預計到站時間', 'Estimated arrival')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etaText, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                settings.text(
                  '此預計時間未必準確。',
                  'This estimated time may not be accurate.',
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(settings.text('關閉', 'Close')),
            ),
          ],
        );
      },
    );
  }
}

class _StopInfoSheet extends StatelessWidget {
  const _StopInfoSheet({required this.route, required this.stopId});

  final RouteEntry route;
  final String stopId;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final StopEntry? stop = repository.stopById(stopId);
    final BusCompany? company = route.primaryCompany;
    final List<String> physicalIds = company == null
        ? const []
        : repository.physicalStopIds(company, stopId);
    final List<RouteStopRef> routes = [];
    final Set<String> seenRoutes = {};
    for (final String physicalId in physicalIds) {
      for (final RouteStopRef ref in repository.routesAtStop(physicalId)) {
        if (seenRoutes.add(ref.route.key)) routes.add(ref);
      }
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text(stop?.displayName(settings.language) ?? stopId),
            subtitle: Text(
              [
                if (stop?.stationCode != null)
                  '${settings.text('站碼', 'Code')} ${stop!.stationCode}',
                if (stop?.platformCode != null)
                  '${settings.text('月台', 'Platform')} ${stop!.platformCode}',
              ].join('  '),
            ),
          ),
          if (stop != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/?q=${stop.lat},${stop.lng}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(settings.text('地圖', 'Map')),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/dir/?api=1'
                      '&destination=${stop.lat},${stop.lng}&travelmode=walking',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.directions_walk),
                  label: Text(settings.text('步行路線', 'Walking directions')),
                ),
              ],
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              settings.text('本站路線', 'Routes at this stop'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (routes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(settings.text('沒有其他路線', 'No other routes')),
            )
          else
            for (final RouteStopRef ref in routes)
              ListTile(
                title: Text(
                  '${ref.route.route} ${settings.text('往', 'to')} ${ref.route.dest.get(settings.language)}',
                ),
                subtitle: Text(
                  '${ref.route.orig.get(settings.language)} · ${ref.route.companiesLabel(settings.language)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/route/${ref.route.slug}');
                },
              ),
        ],
      ),
    );
  }
}

class _RouteUpdateNotice extends StatefulWidget {
  const _RouteUpdateNotice({required this.route});

  final RouteEntry route;

  @override
  State<_RouteUpdateNotice> createState() => _RouteUpdateNoticeState();
}

class _RouteUpdateNoticeState extends State<_RouteUpdateNotice> {
  DateTime? _updatedAt;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final BusRepository repository = context.read<BusRepository>();
    final DateTime? updated = await repository.updater.fetchRouteUpdatedAt(
      widget.route,
    );
    if (!mounted) return;
    setState(() {
      _updatedAt = updated;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || _updatedAt == null) return const SizedBox.shrink();
    final BusRepository repository = context.watch<BusRepository>();
    final AppSettings settings = context.watch<AppSettings>();
    final DateTime? local = repository.lastUpdate;
    if (local != null && !_updatedAt!.isAfter(local)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card.filled(
        child: ListTile(
          leading: const Icon(Icons.sync),
          title: Text(settings.text('有較新的路線資料', 'Newer route data available')),
          subtitle: Text(settings.text('點按更新', 'Tap to update')),
          onTap: () async {
            final bool updated = await repository.update(force: true);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  updated
                      ? settings.text('資料已更新', 'Data updated')
                      : settings.text('更新失敗', 'Update failed'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
