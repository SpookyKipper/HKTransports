import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hktransports/app/app_transition_page.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_data_updater.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_display.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/eta/upstream_eta_scan.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/route_display_name.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';
import 'package:hktransports/bus/ui/citybus_fare_label.dart';
import 'package:hktransports/bus/ui/citybus_route_description.dart';
import 'package:hktransports/bus/ui/route_name_subtitle.dart';
import 'package:hktransports/bus/ui/citybus_stop_landmark.dart';
import 'package:hktransports/bus/ui/eta_text.dart';
import 'package:hktransports/bus/ui/fade_in.dart';
import 'package:hktransports/bus/ui/nlb_fare_label.dart';
import 'package:hktransports/bus/ui/nlb_route_special_tag.dart';
import 'package:hktransports/bus/ui/nlb_stop_landmark.dart';
import 'package:hktransports/bus/ui/proprietary_notices.dart';
import 'package:hktransports/bus/ui/route_map.dart';
import 'package:hktransports/bus/ui/route_group_sheet.dart';
import 'package:hktransports/bus/ui/timetable_sheet.dart';
import 'package:hktransports/location/location_controller.dart';
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
  static const double _autoFocusMaxDistanceMeters = 2000;

  late final AppSettings _settings;
  late final EtaService _etaService;
  StreamSubscription<EtaStatusUpdate>? _statusSubscription;
  final Map<int, List<BusEta>?> _etas = {};
  final Set<int> _loading = {};
  final GlobalKey<RouteMapState> _mapKey = GlobalKey<RouteMapState>();
  final Map<int, GlobalKey> _stationKeys = {};
  Timer? _timer;
  int? _expandedIndex;
  final ValueNotifier<int> _refreshCountdown = ValueNotifier<int>(0);
  DateTime? _nextRefreshAt;
  UpstreamEtaNotice? _upstreamEtaNotice;
  int _upstreamEtaRequestId = 0;
  bool _upstreamEtaEnabled = false;
  bool _autoFocusAttempted = false;
  bool _userSelectedStation = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = context.read<AppSettings>();
    _settings = settings;
    _upstreamEtaEnabled = settings.upstreamEtaScan;
    settings.addListener(_onSettingsChanged);
    final BusRepository repository = context.read<BusRepository>();
    _etaService = EtaService(
      language: settings.language,
      settings: settings,
      databaseProvider: () => repository.database,
    );
    _statusSubscription = _etaService.statusUpdates.listen(_onStatusUpdate);
    _prefetchNlbPage(settings);
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
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _autoFocusNearestStation();
      });
    }
  }

  void _autoFocusNearestStation() {
    if (_autoFocusAttempted || _userSelectedStation || !mounted) return;
    _autoFocusAttempted = true;
    if (!context.read<AppSettings>().locationEnabled) return;
    final LocationController location = context.read<LocationController>();
    unawaited(_focusNearestWhenPositionReady(location));
  }

  Future<void> _focusNearestWhenPositionReady(
    LocationController location,
  ) async {
    final Position? position = await location.waitForPosition();
    if (!mounted ||
        position == null ||
        _userSelectedStation ||
        !context.read<AppSettings>().locationEnabled) {
      return;
    }
    final ({int index, double distance})? nearest = _nearestStation(
      position,
      context.read<BusRepository>(),
    );
    if (nearest == null || nearest.distance > _autoFocusMaxDistanceMeters) {
      return;
    }
    _applyStationFocus(nearest.index);
  }

  ({int index, double distance})? _nearestStation(
    Position position,
    BusRepository repository,
  ) {
    final List<String> stopIds = widget.route.primaryStops;
    int? nearestIndex;
    double nearestDistance = double.infinity;
    for (int index = 0; index < stopIds.length; index++) {
      final StopEntry? stop = repository.stopById(stopIds[index]);
      if (stop == null) continue;
      final double distance = _distanceMetersToPosition(position, stop);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    if (nearestIndex == null) return null;
    return (index: nearestIndex, distance: nearestDistance);
  }

  void _applyStationFocus(int index) {
    if (!mounted) return;
    setState(() => _expandedIndex = index);
    _startRefresh(index);
    _mapKey.currentState?.focusStation(index);
    _scrollToStation(index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppSettings settings = context.read<AppSettings>();
    _etaService.setLanguage(settings.language);
    _prefetchNlbPage(settings);
  }

  void _prefetchNlbPage(AppSettings settings) {
    final RouteEntry route = widget.route;
    if (!route.companies.contains(BusCompany.nlb)) return;
    final bool pageDataEnabled =
        settings.isProprietaryEnabled(ProprietaryEndpoint.nlbProprietaryData) ||
        settings.isProprietaryEnabled(ProprietaryEndpoint.nlbRouteNotices);
    if (!pageDataEnabled) return;
    unawaited(
      NlbTimetableService.instance.prefetchPage(route, settings.language),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_onSettingsChanged);
    _timer?.cancel();
    _refreshCountdown.dispose();
    _statusSubscription?.cancel();
    _etaService.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted || _disposed) return;
    final bool enabled = _settings.upstreamEtaScan;
    if (enabled == _upstreamEtaEnabled) return;
    _upstreamEtaEnabled = enabled;
    if (!enabled) {
      ++_upstreamEtaRequestId;
      if (_upstreamEtaNotice != null) {
        setState(() => _upstreamEtaNotice = null);
      }
      return;
    }
    final int? index = _expandedIndex;
    if (index != null) {
      unawaited(_fetch(index, scanUpstream: true));
    }
  }

  void _onStatusUpdate(EtaStatusUpdate update) {
    if (!mounted || update.routeKey != widget.route.key) return;
    final List<BusEta>? current = _etas[update.seq];
    if (current == null) return;
    final List<BusEta> updated = _etaService.applyCachedStatuses(
      widget.route,
      update.seq,
      current,
    );
    if (identical(updated, current)) return;
    setState(() => _etas[update.seq] = updated);
  }

  void _startRefresh(int index) {
    _timer?.cancel();
    _fetch(index, scanUpstream: true);
    _nextRefreshAt = DateTime.now().add(
      Duration(seconds: _settings.refreshSeconds),
    );
    _updateRefreshCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final DateTime now = DateTime.now();
      final DateTime? next = _nextRefreshAt;
      if (next == null) return;
      if (!next.isAfter(now)) {
        _nextRefreshAt = now.add(Duration(seconds: _settings.refreshSeconds));
        _fetch(index, scanUpstream: true);
      }
      _updateRefreshCountdown();
    });
  }

  void _updateRefreshCountdown() {
    if (!mounted || _disposed) return;
    final DateTime? next = _nextRefreshAt;
    final int seconds = next == null
        ? 0
        : (next.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
            0,
            999,
          );
    if (_refreshCountdown.value != seconds) {
      _refreshCountdown.value = seconds;
    }
  }

  Widget _buildReloadAction(
    BuildContext context,
    AppSettings settings,
    int index,
  ) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return ValueListenableBuilder<int>(
      valueListenable: _refreshCountdown,
      builder: (BuildContext context, int seconds, Widget? child) {
        final bool loading = _loading.contains(index);
        return M3EButton.icon(
          onPressed: loading ? null : () => _startRefresh(index),
          style: M3EButtonStyle.text,
          icon: loading
              ? const M3ELoadingIndicator(size: 18)
              : Icon(Icons.refresh, color: color),
          label: Text(
            settings.text('$seconds 秒', '${seconds}s'),
            style: TextStyle(color: color),
          ),
          tooltip: settings.text(
            '立即重新整理（$seconds 秒）',
            'Reload now (${seconds}s)',
          ),
        );
      },
    );
  }

  Future<void> _fetch(int index, {bool scanUpstream = false}) async {
    if (_loading.contains(index)) return;
    setState(() => _loading.add(index));
    try {
      final List<BusEta> etas = await _etaService.fetchRouteStop(
        widget.route,
        index,
      );
      if (!mounted || _disposed) return;
      setState(() {
        _loading.remove(index);
        _etas[index] = etas;
      });
      if (scanUpstream && _expandedIndex == index) {
        unawaited(_scanUpstreamEta(index));
      }
    } catch (error) {
      debugPrint('ETA refresh failed: $error');
      if (mounted && !_disposed) {
        setState(() => _loading.remove(index));
      }
    }
  }

  BusEta? _firstEta(List<BusEta>? etas) {
    for (final BusEta eta in etas ?? const <BusEta>[]) {
      if (eta.eta != null) return eta;
    }
    return null;
  }

  Future<void> _scanUpstreamEta(int index) async {
    if (!mounted || !_settings.upstreamEtaScan || _expandedIndex != index) {
      return;
    }
    final int requestId = ++_upstreamEtaRequestId;
    final BusEta? current = _firstEta(_etas[index]);
    final bool currentScheduled = current == null || current.isScheduledLike;
    final List<UpstreamEtaSample> samples = <UpstreamEtaSample>[];
    DateTime? originEta;
    for (int i = index - 1; i >= 0; i--) {
      final List<BusEta> etas;
      try {
        etas = await _etaService.fetchRouteStop(widget.route, i);
      } catch (error) {
        debugPrint('Upstream ETA scan failed at $i: $error');
        break;
      }
      if (!mounted ||
          requestId != _upstreamEtaRequestId ||
          _expandedIndex != index) {
        return;
      }
      final BusEta? upstream = _firstEta(etas);
      if (upstream?.eta == null) break;
      if (i == 0) originEta = upstream!.eta;
      samples.add(UpstreamEtaSample(stopIndex: i, eta: upstream!.eta));
      final UpstreamEtaNotice? notice = findUpstreamEtaNotice(
        currentIndex: index,
        currentEta: current?.eta,
        upstream: samples,
        scheduled: currentScheduled,
      );
      if (notice != null) {
        setState(
          () => _upstreamEtaNotice = notice.stopIndex == index ? null : notice,
        );
        return;
      }
    }

    if (currentScheduled) {
      if (index == 0) {
        originEta = current?.eta;
      } else if (originEta == null) {
        try {
          final List<BusEta> originEtas = await _etaService.fetchRouteStop(
            widget.route,
            0,
          );
          if (!mounted ||
              requestId != _upstreamEtaRequestId ||
              _expandedIndex != index) {
            return;
          }
          originEta = _firstEta(originEtas)?.eta;
        } catch (error) {
          debugPrint('Upstream origin ETA failed: $error');
        }
      }
      if (originEta != null) {
        final UpstreamEtaNotice notice = UpstreamEtaNotice(
          currentIndex: index,
          stopIndex: 0,
          eta: originEta,
          remainingStops: index,
          scheduled: currentScheduled,
        );
        setState(
          () => _upstreamEtaNotice = notice.stopIndex == index ? null : notice,
        );
        return;
      }
    }
    if (mounted && requestId == _upstreamEtaRequestId) {
      setState(() => _upstreamEtaNotice = null);
    }
  }

  void _onExpansionChanged(int index, bool expanded) {
    _userSelectedStation = true;
    if (_disposed) return;
    if (expanded) {
      ++_upstreamEtaRequestId;
      setState(() {
        _expandedIndex = index;
        _upstreamEtaNotice = null;
      });
      _startRefresh(index);
      _mapKey.currentState?.focusStation(index);
    } else {
      ++_upstreamEtaRequestId;
      setState(() {
        _expandedIndex = null;
        _upstreamEtaNotice = null;
        _loading.remove(index);
      });
      _timer?.cancel();
      _nextRefreshAt = null;
      _refreshCountdown.value = 0;
    }
  }

  void _onMapStationTap(int index) {
    _userSelectedStation = true;
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
    return _distanceMetersBetween(a.lat, a.lng, b.lat, b.lng);
  }

  double _distanceMetersToPosition(Position position, StopEntry stop) {
    return _distanceMetersBetween(
      position.latitude,
      position.longitude,
      stop.lat,
      stop.lng,
    );
  }

  double _distanceMetersBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double metersPerDegree = 111320;
    final double midLat = (lat1 + lat2) / 2 * math.pi / 180;
    final double dy = (lat1 - lat2) * metersPerDegree;
    final double dx = (lng1 - lng2) * metersPerDegree * math.cos(midLat);
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
        title: routeDisplayName(route, settings.language, fullEnglish: true),
        titleTrailing: _RouteTitleMeta(
          company: route.companiesLabel(settings.language),
          special: route.isSpecial
              ? _RouteSpecialTag(label: settings.text('特別班', 'Special'))
              : route.companies.contains(BusCompany.nlb)
              ? NlbRouteSpecialTag(
                  route: route,
                  language: settings.language,
                  enabled: routeNameEnabled(route, settings),
                )
              : null,
        ),
        subtitleWidget: RouteNameSubtitle(
          route: route,
          language: settings.language,
          enabled: routeNameEnabled(route, settings),
          compactAppBar: true,
          text:
              '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
                fadeCurrentRouteOut(context);
                context.pushReplacement(
                  '/route/${reverse.slug}?fade=1$stopQuery',
                );
              },
              icon: const Icon(Icons.swap_horiz),
            ),
          M3EIconButton(
            tooltip: settings.text('路線屬性', 'Route Properties'),
            variant: M3EIconButtonVariant.standard,
            onPressed: () =>
                _showTimetable(context, route, _expandedIndex ?? 0),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          if (route.isSpecial)
            CitybusRouteDescription(
              route: route,
              language: settings.language,
              enabled: settings.isProprietaryEnabled(
                ProprietaryEndpoint.citybusDatabase,
              ),
              fallback: '',
              builder: (BuildContext context, String label) {
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_stationInnerRadius),
                ),
                child: ListView.builder(
                  scrollCacheExtent: ScrollCacheExtent.pixels(12000),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: stopIds.length,
                  itemBuilder: (context, index) {
                    final bool isExpanded = _expandedIndex == index;
                    return KeyedSubtree(
                      key: _stationKeys.putIfAbsent(index, () => GlobalKey()),
                      child: _StationExpandable(
                        isExpanded: isExpanded,
                        isFirst: index == 0,
                        isLast: index == stopIds.length - 1,
                        gap: _stationGap,
                        innerRadius: _stationInnerRadius,
                        header: _buildStopHeader(
                          context,
                          repository,
                          route,
                          stopIds,
                          index,
                          holiday,
                          isExpanded,
                          () => _onExpansionChanged(index, !isExpanded),
                        ),
                        body: _buildStopBody(
                          context,
                          route,
                          stopIds,
                          index,
                          pinned,
                        ),
                        onToggle: () => _onExpansionChanged(index, !isExpanded),
                      ),
                    );
                  },
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
    final String? weekdayFare = route.fareAt(index, holiday: false);
    final String? holidayFare = route.fareAt(index, holiday: true);
    final String? fare = holiday ? holidayFare : weekdayFare;
    final String? normalFare = weekdayFare;
    final String? code = stop?.stationCode;
    final String? platform = stop?.platformCode;
    final bool isTerminus = index == stopIds.length - 1;
    final bool kmbAlightingOnly =
        route.companies.contains(BusCompany.kmb) &&
        (stop?.isAlightingOnly ?? false);

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
                    if (route.companies.contains(BusCompany.nlb))
                      NlbFareLabel(
                        route: route,
                        stopIndex: index,
                        language: settings.language,
                        enabled: settings.isProprietaryEnabled(
                          ProprietaryEndpoint.nlbProprietaryData,
                        ),
                        holiday: holiday,
                        fallbackWeekdayFare: weekdayFare,
                        fallbackHolidayFare: holidayFare,
                        alightingOnly: kmbAlightingOnly,
                      )
                    else
                      CitybusFareLabel(
                        route: route,
                        stopIndex: index,
                        language: settings.language,
                        enabled: settings.isProprietaryEnabled(
                          ProprietaryEndpoint.citybusDatabase,
                        ),
                        fallbackFare: fare ?? normalFare,
                        alightingOnly: kmbAlightingOnly,
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
    final UpstreamEtaNotice? notice = _upstreamEtaNotice;
    final bool showNotice =
        settings.upstreamEtaScan &&
        notice != null &&
        notice.currentIndex == index &&
        notice.stopIndex != index;
    final String noticeStopName = showNotice
        ? repository
                  .stopById(stopIds[notice.stopIndex])
                  ?.displayName(settings.language) ??
              stopIds[notice.stopIndex]
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (route.companies.contains(BusCompany.nlb))
          NlbStopLandmark(
            route: route,
            stopIndex: index,
            language: settings.language,
            enabled: settings.isProprietaryEnabled(
              ProprietaryEndpoint.nlbProprietaryData,
            ),
          ),
        CitybusStopLandmark(
          route: route,
          stopIndex: index,
          language: settings.language,
          enabled: settings.isProprietaryEnabled(
            ProprietaryEndpoint.citybusDatabase,
          ),
        ),
        if (showNotice) ...[
          _UpstreamEtaBanner(notice: notice, stopName: noticeStopName),
          const SizedBox(height: 8),
        ],
        _EtaList(
          route: route,
          loading: _loading.contains(index),
          etas: _etas[index],
          showCompany: route.companies.length > 1,
          atOrigin: index == 0,
          stopIndex: index,
          stopIndexByCode: stopIndexByCode,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_etas[index] != null)
              _buildReloadAction(context, settings, index),
            Expanded(
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Keep the sheet draggable only by its handle so vertical gestures reach
      // the NLB timetable WebView instead of being consumed by the sheet.
      enableDrag: false,
      builder: (context) {
        return TimetableSheet(route: route, initialStopIndex: stopIndex);
      },
    );
  }
}

class _RouteTitleMeta extends StatelessWidget {
  const _RouteTitleMeta({required this.company, this.special});

  final String company;
  final Widget? special;

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
        ?special,
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _UpstreamEtaBanner extends StatelessWidget {
  const _UpstreamEtaBanner({required this.notice, required this.stopName});

  final UpstreamEtaNotice notice;
  final String stopName;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime eta = notice.eta;
    final DateTime hkTime = eta.toUtc().add(const Duration(hours: 8));
    final String clock = DateFormat('HH:mm').format(hkTime);
    final int minutes = eta.difference(DateTime.now().toUtc()).inMinutes;
    final bool departure = notice.stopIndex == 0;
    final String text = departure
        ? notice.scheduled
              ? _scheduledDepartureText(settings, clock, minutes)
              : settings.text(
                  '下班車已在 $stopName 開出（剩餘 ${notice.remainingStops} 個站）',
                  'Next bus has already departed from $stopName (${notice.remainingStops} stops remaining)',
                )
        : minutes <= 0
        ? settings.text(
            '下班車已到達 $stopName（剩餘 ${notice.remainingStops} 個站）',
            'Next bus has arrived at $stopName (${notice.remainingStops} stops remaining)',
          )
        : _arrivalText(settings, clock, minutes);
    return FadeIn(
      key: ValueKey<String>(
        '${notice.currentIndex}|${notice.stopIndex}|${eta.millisecondsSinceEpoch}|${notice.scheduled}|${settings.etaFormat.name}',
      ),
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _scheduledDepartureText(
    AppSettings settings,
    String clock,
    int minutes,
  ) {
    final int shownMinutes = math.max(0, minutes);
    return switch (settings.etaFormat) {
      EtaFormat.diff => settings.text(
        '下班車即將在 $shownMinutes 分鐘後於 $stopName 開出',
        'Next bus will depart from $stopName in $shownMinutes min',
      ),
      EtaFormat.exact => settings.text(
        '下班車即將在 $clock 於 $stopName 開出',
        'Next bus will depart from $stopName at $clock',
      ),
      EtaFormat.mixed => settings.text(
        '下班車即將在 $clock $shownMinutes 分鐘後於 $stopName 開出',
        'Next bus will depart from $stopName at $clock (in $shownMinutes min)',
      ),
    };
  }

  String _arrivalText(AppSettings settings, String clock, int minutes) {
    return switch (settings.etaFormat) {
      EtaFormat.diff => settings.text(
        '下班車將於 $minutes 分鐘後到達 $stopName（剩餘 ${notice.remainingStops} 個站）',
        'Next bus will arrive at $stopName in $minutes min (${notice.remainingStops} stops remaining)',
      ),
      EtaFormat.exact => settings.text(
        '下班車將於 $clock 到達 $stopName（剩餘 ${notice.remainingStops} 個站）',
        'Next bus will arrive at $stopName at $clock (${notice.remainingStops} stops remaining)',
      ),
      EtaFormat.mixed => settings.text(
        '下班車將於 $clock $minutes 分鐘後到達 $stopName（剩餘 ${notice.remainingStops} 個站）',
        'Next bus will arrive at $stopName at $clock (in $minutes min, ${notice.remainingStops} stops remaining)',
      ),
    };
  }
}

class _EtaList extends StatelessWidget {
  const _EtaList({
    required this.route,
    required this.loading,
    required this.etas,
    required this.showCompany,
    required this.atOrigin,
    required this.stopIndex,
    required this.stopIndexByCode,
  });

  final RouteEntry route;
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
          (eta) =>
              eta.eta != null ||
              eta.proprietaryTime != null ||
              eta.proprietaryMinutes != null ||
              eta.remark(settings.language).isNotEmpty ||
              eta.status(settings.language) != null,
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
          FadeIn(
            key: ValueKey<String>(etaDisplayKey(visible[index])),
            child: _EtaLine(
              route: route,
              eta: visible[index],
              first: index == 0,
              showCompany: showCompany,
              atOrigin: atOrigin,
              stopIndex: stopIndex,
              stopIndexByCode: stopIndexByCode,
            ),
          ),
      ],
    );
  }
}

class _EtaLine extends StatelessWidget {
  const _EtaLine({
    required this.route,
    required this.eta,
    required this.first,
    required this.showCompany,
    required this.atOrigin,
    required this.stopIndex,
    required this.stopIndexByCode,
  });

  final RouteEntry route;
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
    final String company = route.companyLabel(eta.company, settings.language);

    if (time == null) {
      final String? proprietary = _proprietaryOnlyLabel(eta, settings);
      final String message = <String>[
        if (showCompany && eta.isDelayedJourney) company,
        if (proprietary != null) proprietary,
        if (remark.isNotEmpty) remark,
        if (eta.status(settings.language) != null)
          eta.status(settings.language)!,
        if (eta.distanceLabel(settings.language) != null)
          eta.distanceLabel(settings.language)!,
      ].join(' · ');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      );
    }

    final DateTime hkTime = time.toUtc().add(const Duration(hours: 8));
    final String clock =
        proprietaryClockLabel(eta) ?? DateFormat('HH:mm').format(hkTime);
    final int minutes = time.difference(DateTime.now().toUtc()).inMinutes;
    final String? departed = departedEtaLabel(eta, settings);
    final String wait =
        proprietaryMinutesLabel(eta) ??
        (minutes < 1
            ? atOrigin
                  ? settings.text('即場開出', 'Departing now')
                  : settings.text('即將到達', 'Arriving')
            : '$minutes ${settings.text('分鐘', 'min')}');

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
            Tooltip(
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
    final String? status = eta.status(settings.language);
    final String? distance = eta.distanceLabel(settings.language);
    final String? platform = eta.platform;
    final List<String> segments = [
      parts,
      if (showCompany) company,
      if (remark.isNotEmpty) remark,
      if (platform != null && platform.isNotEmpty)
        '${settings.text('月台', 'Platform')} $platform',
      if (eta.scheduled && remark.isEmpty) settings.text('預定班次', 'Scheduled'),
      if (via.isNotEmpty) via,
    ];
    final List<String> appended = <String>[?status, ?distance];

    final TextStyle? style = first
        ? Theme.of(context).textTheme.titleMedium?.copyWith(color: color)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: EtaText(
        base: segments.join(' · '),
        appended: appended.isEmpty ? null : appended.join(' · '),
        appendedKey: etaLiveStatusKey(eta),
        style: style,
        color: color,
        wheelchair: eta.wheelchair,
      ),
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
            M3EButton.text(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(settings.text('關閉', 'Close')),
            ),
          ],
        );
      },
    );
  }
}

String? _proprietaryOnlyLabel(BusEta eta, AppSettings settings) {
  final String? time = proprietaryClockLabel(eta);
  final String? minutes = proprietaryMinutesLabel(eta);
  final String base = switch (settings.etaFormat) {
    EtaFormat.diff => minutes ?? time ?? '',
    EtaFormat.exact => time ?? minutes ?? '',
    EtaFormat.mixed => <String?>[
      time,
      minutes,
    ].whereType<String>().where((String value) => value.isNotEmpty).join('  '),
  };
  return base.isEmpty ? null : base;
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
                  '${routeDisplayName(ref.route, settings.language)} ${settings.text('往', 'to')} ${ref.route.dest.get(settings.language)}',
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

class _StationExpandable extends StatelessWidget {
  const _StationExpandable({
    required this.isExpanded,
    required this.isFirst,
    required this.isLast,
    required this.gap,
    required this.innerRadius,
    required this.header,
    required this.body,
    required this.onToggle,
  });

  final bool isExpanded;
  final bool isFirst;
  final bool isLast;
  final double gap;
  final double innerRadius;
  final Widget header;
  final Widget body;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius;
    if (isFirst && isLast) {
      radius = BorderRadius.circular(innerRadius);
    } else if (isFirst) {
      radius = BorderRadius.vertical(
        top: Radius.circular(innerRadius),
        bottom: Radius.circular(innerRadius),
      );
    } else if (isLast) {
      radius = BorderRadius.vertical(
        top: Radius.circular(innerRadius),
        bottom: Radius.circular(24),
      );
    } else {
      radius = BorderRadius.circular(innerRadius);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : gap),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(onTap: onToggle, child: header),
            ClipRect(
              child: AnimatedSize(
                alignment: Alignment.topCenter,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: body,
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ),
          ],
        ),
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
