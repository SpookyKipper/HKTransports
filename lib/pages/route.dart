import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_data_updater.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_display.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';
import 'package:hktransports/bus/ui/proprietary_notices.dart';
import 'package:hktransports/bus/ui/route_map.dart';
import 'package:hktransports/bus/ui/route_group_sheet.dart';
import 'package:hktransports/bus/ui/timetable_sheet.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutePageRoute extends StatelessWidget {
  const RoutePageRoute({super.key, required this.slug, this.initialStopId});

  final String slug;
  final String? initialStopId;

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
    return _RoutePage(
      key: ValueKey(route.key),
      route: route,
      initialStopId: initialStopId,
    );
  }
}

class _RoutePage extends StatefulWidget {
  const _RoutePage({super.key, required this.route, this.initialStopId});

  final RouteEntry route;
  final String? initialStopId;

  @override
  State<_RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<_RoutePage> {
  static const double _stationGap = 3;
  static const double _stationInnerRadius = 8;

  late final EtaService _etaService;
  final Map<int, List<BusEta>?> _etas = {};
  final Set<int> _loading = {};
  final GlobalKey<RouteMapState> _mapKey = GlobalKey<RouteMapState>();
  final Map<int, GlobalKey> _stationKeys = {};
  Timer? _timer;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = context.read<AppSettings>();
    _etaService = EtaService(language: settings.language);
    final int initialIndex = widget.route.primaryStops.indexOf(
      widget.initialStopId ?? '',
    );
    if (initialIndex >= 0) {
      _expandedIndex = initialIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startRefresh(initialIndex);
        _mapKey.currentState?.focusStation(initialIndex);
        _scrollToStation(initialIndex);
      });
    }
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
      _mapKey.currentState?.focusStation(index);
    } else {
      setState(() {
        _expandedIndex = null;
        _loading.remove(index);
      });
      _timer?.cancel();
    }
  }

  void _onMapStationTap(int index) {
    if (_expandedIndex != index) {
      _onExpansionChanged(index, true);
    } else {
      _mapKey.currentState?.focusStation(index);
    }
    _scrollToStation(index);
  }

  void _scrollToStation(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final BuildContext? stationContext =
            _stationKeys[index]?.currentContext;
        if (stationContext == null) return;
        Scrollable.ensureVisible(
          stationContext,
          duration: const Duration(milliseconds: 300),
          alignment: 0,
        );
      });
    });
  }

  String? _correspondingStopId(
    RouteEntry current,
    RouteEntry reverse,
    int selectedIndex,
    BusRepository repository,
  ) {
    final List<String> currentStops = current.primaryStops;
    final List<String> reverseStops = reverse.primaryStops;
    if (selectedIndex < 0 || selectedIndex >= currentStops.length) {
      return null;
    }
    final String selectedId = currentStops[selectedIndex];
    if (reverseStops.contains(selectedId)) return selectedId;

    final StopEntry? selected = repository.stopById(selectedId);
    if (selected == null || reverseStops.isEmpty) return null;

    final List<StopRef>? physical = repository.database?.stopMap[selectedId];
    if (physical != null) {
      final Set<String> physicalIds = <String>{
        selectedId,
        for (final StopRef ref in physical) ref.stopId,
      };
      for (final String stopId in reverseStops) {
        if (physicalIds.contains(stopId)) return stopId;
      }
    }

    final List<String> named = [
      for (final String stopId in reverseStops)
        if (_sameStopName(selected, repository.stopById(stopId))) stopId,
    ];
    final String? namedStop = _nearestStop(selected, named, repository);
    if (namedStop != null) return namedStop;

    return _nearestStop(selected, reverseStops, repository, maxMeters: 400);
  }

  bool _sameStopName(StopEntry current, StopEntry? other) {
    if (other == null) return false;
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalize(current.displayEn) == normalize(other.displayEn) ||
        normalize(current.displayZh) == normalize(other.displayZh);
  }

  String? _nearestStop(
    StopEntry selected,
    Iterable<String> stopIds,
    BusRepository repository, {
    double? maxMeters,
  }) {
    String? nearestId;
    double nearestDistance = double.infinity;
    for (final String stopId in stopIds) {
      final StopEntry? stop = repository.stopById(stopId);
      if (stop == null) continue;
      final double distance = _distanceMeters(selected, stop);
      if (maxMeters != null && distance > maxMeters) continue;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = stopId;
      }
    }
    return nearestId;
  }

  double _distanceMeters(StopEntry a, StopEntry b) {
    const double metersPerDegree = 111320;
    final double midLat = (a.lat + b.lat) / 2 * math.pi / 180;
    final double dy = (a.lat - b.lat) * metersPerDegree;
    final double dx = (a.lng - b.lng) * metersPerDegree * math.cos(midLat);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final PinnedStopsController pinned = context.watch<PinnedStopsController>();
    final RouteEntry route = widget.route;
    final List<String> stopIds = route.primaryStops;
    final bool holiday = isHoliday(
      repository.database?.holidays ?? const [],
      hkNow(),
    );
    final List<RouteMapStation> mapStations = [];
    for (int index = 0; index < stopIds.length; index++) {
      final StopEntry? stop = repository.stopById(stopIds[index]);
      if (stop != null) {
        mapStations.add(RouteMapStation(index: index, stop: stop));
      }
    }

    final RouteEntry? reverse = repository.findReverse(route);
    return Scaffold(
      appBar: buildPageBar(
        context,
        title: route.route,
        titleTrailing: _RouteTitleMeta(
          company: route.companiesLabel(settings.language),
          special: route.isSpecial ? settings.text('特別班', 'Special') : null,
        ),
        subtitle:
            '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
        actions: [
          if (reverse != null)
            M3EIconButton(
              tooltip: settings.text('對頭線', 'Reverse route'),
              variant: M3EIconButtonVariant.standard,
              onPressed: () {
                final String? stopId = _expandedIndex == null
                    ? null
                    : _correspondingStopId(
                        route,
                        reverse,
                        _expandedIndex!,
                        repository,
                      );
                final String stopQuery = stopId == null
                    ? ''
                    : '&stop=${Uri.encodeQueryComponent(stopId)}';
                context.pushReplacement(
                  '/route/${reverse.slug}?fade=1$stopQuery',
                );
              },
              icon: const Icon(Icons.swap_horiz),
            ),
          M3EIconButton(
            tooltip: settings.text('時間表', 'Timetable'),
            variant: M3EIconButtonVariant.standard,
            onPressed: () =>
                _showTimetable(context, route, _expandedIndex ?? 0),
            icon: const Icon(Icons.schedule),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, _stationGap),
            child: RouteMap(
              key: _mapKey,
              route: route,
              stations: mapStations,
              onStationTap: _onMapStationTap,
            ),
          ),
          _RouteUpdateNotice(route: route),
          Expanded(
            child: M3ERefreshIndicator.contained(
              onRefresh: () async {
                final int? index = _expandedIndex;
                if (index != null) await _fetch(index);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_stationInnerRadius),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    cacheExtent: 12000,
                    itemCount: stopIds.length,
                    itemBuilder: (context, index) {
                      final bool isExpanded = _expandedIndex == index;
                      return KeyedSubtree(
                        key: _stationKeys.putIfAbsent(index, () => GlobalKey()),
                        child: M3EExpandableItem(
                          key: ValueKey<String>(
                            '${stopIds[index]}|'
                            '${_etas[index]?.length ?? -1}|'
                            '${_loading.contains(index)}',
                          ),
                          index: index,
                          totalCount: stopIds.length,
                          isExpanded: isExpanded,
                          decoration: M3EExpandableStyle(
                            outerRadius: index == 0 ? _stationInnerRadius : 24,
                            innerRadius: _stationInnerRadius,
                            hoverRadius: 24,
                            pressedRadius: 24,
                            gap: _stationGap,
                            elevation: 0,
                            expandedStateFill: false,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            headerPadding: const EdgeInsets.all(16),
                            bodyPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            iconPlacement: M3EExpandableIconPlacement.right,
                            expandIcon: null,
                            collapseIcon: null,
                            useInkWell: false,
                          ),
                          expandMotion: const M3ESpring(
                            stiffness: 300,
                            damping: 0.9,
                          ),
                          collapseMotion: const M3ESpring(
                            stiffness: 320,
                            damping: 0.9,
                          ),
                          onToggle: () =>
                              _onExpansionChanged(index, !isExpanded),
                          headerBuilder: (context, index, progress) =>
                              _buildStopHeader(
                                context,
                                repository,
                                route,
                                stopIds,
                                index,
                                holiday,
                                isExpanded,
                                () => _onExpansionChanged(index, !isExpanded),
                              ),
                          bodyBuilder: (context, index, progress) {
                            if (progress <= 0) {
                              return const SizedBox.shrink();
                            }
                            return Opacity(
                              opacity: progress.clamp(0.0, 1.0),
                              child: _buildStopBody(
                                context,
                                route,
                                stopIds,
                                index,
                                pinned,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
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
    bool expanded,
    VoidCallback onToggle,
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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
          const SizedBox(width: 4),
          M3EIconButton(
            tooltip: settings.text(
              expanded ? '收起' : '展開',
              expanded ? 'Collapse' : 'Expand',
            ),
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.xs,
            inflateHitTarget: false,
            onPressed: onToggle,
            icon: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopBody(
    BuildContext context,
    RouteEntry route,
    List<String> stopIds,
    int index,
    PinnedStopsController pinned,
  ) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final bool isPinned = pinned.contains(route.key, index);
    final Color secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
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
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              M3EIconButton(
                tooltip: settings.text('收藏此站', 'Favourite this stop'),
                icon: const Icon(Icons.star_border),
                selectedIcon: const Icon(Icons.star),
                isSelected: repository.isEntryInAnyGroup(route.key, index),
                variant: M3EIconButtonVariant.standard,
                size: M3EIconButtonSize.xs,
                inflateHitTarget: false,
                onPressed: () =>
                    showRouteGroupSheet(context, route, stopSeq: index),
              ),
              M3EIconButton(
                tooltip: isPinned
                    ? settings.text('取消釘選', 'Unpin station')
                    : settings.text('釘選', 'Pin station'),
                icon: const Icon(Icons.push_pin_outlined),
                selectedIcon: const Icon(Icons.push_pin),
                isSelected: isPinned,
                variant: M3EIconButtonVariant.standard,
                size: M3EIconButtonSize.xs,
                inflateHitTarget: false,
                onPressed: () => pinned.toggle(
                  PinnedStation(routeKey: route.key, seq: index),
                ),
              ),
              M3EButton.icon(
                onPressed: () =>
                    _showStopInfo(context, route, stopIds[index], index),
                style: M3EButtonStyle.text,
                icon: Icon(Icons.info_outline, color: secondaryColor),
                label: Text(
                  settings.text('車站資訊', 'Stop information'),
                  style: TextStyle(color: secondaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showStopInfo(
    BuildContext context,
    RouteEntry route,
    String stopId,
    int stopIndex,
  ) {
    M3EBottomSheet.show<void>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) {
        return _StopInfoSheet(
          route: route,
          stopId: stopId,
          stopIndex: stopIndex,
        );
      },
    );
  }

  void _showTimetable(BuildContext context, RouteEntry route, int stopIndex) {
    M3EBottomSheet.show<void>(
      context,
      initialValue: M3EBottomSheetValue.expanded,
      builder: (context) {
        return TimetableSheet(route: route, initialStopIndex: stopIndex);
      },
    );
  }
}

class _RouteTitleMeta extends StatelessWidget {
  const _RouteTitleMeta({required this.company, this.special});

  final String company;
  final String? special;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (company.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        if (company.isNotEmpty && special != null) const SizedBox(width: 8),
        if (special != null) _RouteSpecialTag(label: special!),
      ],
    );
  }
}

class _RouteSpecialTag extends StatelessWidget {
  const _RouteSpecialTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
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
        child: Center(child: M3ELoadingIndicator(size: 24)),
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
      final String message = showCompany && eta.isDelayedJourney
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
    final String? departed = departedEtaLabel(eta, settings);
    final String wait = minutes < 1
        ? atOrigin
              ? settings.text('即場開出', 'Departing now')
              : settings.text('即將到達', 'Arriving')
        : '$minutes ${settings.text('分鐘', 'min')}';

    final String parts = departed != null
        ? '$clock  $departed'
        : switch (settings.etaFormat) {
            EtaFormat.diff => wait,
            EtaFormat.exact => clock,
            EtaFormat.mixed => '$clock  $wait',
          };
    final bool showDelayedEta =
        departed != null ||
        eta.canShowDelayedEta(
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
            M3ETooltip(
              message: settings.text(
                '預計時間不準確',
                'Estimated time may be inaccurate',
              ),
              child: M3EButton.text(
                onPressed: () =>
                    _showDelayedEtaDialog(context, settings, parts, message),
                size: M3EButtonSize.xs,
                decoration: M3EButtonDecoration.styleFrom(
                  foregroundColor: color,
                  minimumSize: const Size(28, 20),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.info_outline, size: 16),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                showCompany ? '$company · $message' : message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      );
    }
    final String via = eta.company == BusCompany.nlb
        ? eta.dest(settings.language).trim()
        : '';
    final List<String> segments = [
      parts,
      if (showCompany) company,
      if (remark.isNotEmpty) remark,
      if (eta.scheduled && remark.isEmpty) settings.text('預定班次', 'Scheduled'),
      if (via.isNotEmpty) via,
    ];

    final TextStyle? style = first
        ? Theme.of(context).textTheme.titleMedium?.copyWith(color: color)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(segments.join(' · '), style: style),
    );
  }

  void _showDelayedEtaDialog(
    BuildContext context,
    AppSettings settings,
    String etaText,
    String message,
  ) {
    final ThemeData theme = Theme.of(context);
    M3EDialog.show<void>(
      context,
      dialog: M3EDialog(
        title: settings.text('預計到站時間', 'Estimated arrival'),
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
          M3EButton.text(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(settings.text('關閉', 'Close')),
          ),
        ],
      ),
    );
  }
}

String? _citybusStopId(RouteEntry route, String stopId, int stopIndex) {
  if (!route.companies.contains(BusCompany.ctb)) return null;
  final String? citybusId = route.stopIdAt(BusCompany.ctb, stopIndex);
  if (citybusId != null && citybusId.isNotEmpty) return citybusId;
  final List<String>? citybusStops = route.stops[BusCompany.ctb];
  if (citybusStops != null && citybusStops.contains(stopId)) {
    return stopId;
  }
  return null;
}

class _StopInfoSheet extends StatelessWidget {
  const _StopInfoSheet({
    required this.route,
    required this.stopId,
    required this.stopIndex,
  });

  final RouteEntry route;
  final String stopId;
  final int stopIndex;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final StopEntry? stop = repository.stopById(stopId);
    final BusCompany? company = route.primaryCompany;
    final List<String> physicalIds = company == null
        ? const []
        : repository.physicalStopIds(company, stopId);
    final String? citybusStopId = _citybusStopId(route, stopId, stopIndex);
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
          M3EListItem(
            headline: stop?.displayName(settings.language) ?? stopId,
            supportingText: [
              if (stop?.stationCode != null)
                '${settings.text('站碼', 'Code')} ${stop!.stationCode}',
              if (stop?.platformCode != null)
                '${settings.text('月台', 'Platform')} ${stop!.platformCode}',
            ].join('  '),
          ),
          if (stop != null)
            Wrap(
              spacing: 8,
              children: [
                M3EButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/?q=${stop.lat},${stop.lng}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: M3EButtonStyle.text,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(settings.text('地圖', 'Map')),
                ),
                M3EButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/dir/?api=1'
                      '&destination=${stop.lat},${stop.lng}&travelmode=walking',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: M3EButtonStyle.text,
                  icon: const Icon(Icons.directions_walk),
                  label: Text(settings.text('步行路線', 'Walking directions')),
                ),
              ],
            ),
          if (citybusStopId != null) CitybusStopNotices(stopId: citybusStopId),
          const M3EDivider(),
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
              M3EListItem(
                headline:
                    '${ref.route.route} ${settings.text('往', 'to')} ${ref.route.dest.get(settings.language)}',
                supportingText:
                    '${ref.route.orig.get(settings.language)} · ${ref.route.companiesLabel(settings.language)}',
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
      child: M3EListItem(
        variant: M3ECardVariant.filled,
        leading: const Icon(Icons.sync),
        headline: settings.text('有較新的路線資料', 'Newer route data available'),
        supportingText: settings.text('點按更新', 'Tap to update'),
        onTap: () async {
          final bool updated = await repository.update(force: true);
          if (!context.mounted) return;
          M3ESnackbar.show(
            context,
            message: updated
                ? settings.text('資料已更新', 'Data updated')
                : settings.text('更新失敗', 'Update failed'),
          );
        },
      ),
    );
  }
}
