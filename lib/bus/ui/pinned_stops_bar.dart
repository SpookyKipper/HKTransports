import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_display.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/route_display_name.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';
import 'package:hktransports/bus/ui/fade_in.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class PinnedStopsHost extends StatelessWidget {
  const PinnedStopsHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PinnedStopsController controller = context
        .watch<PinnedStopsController>();
    if (controller.stations.isEmpty) return child;
    final MediaQueryData media = MediaQuery.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PinnedStopsBar(),
        Expanded(
          child: MediaQuery(
            data: media.copyWith(padding: media.padding.copyWith(top: 0)),
            child: child,
          ),
        ),
      ],
    );
  }
}

class PinnedStopsBar extends StatefulWidget {
  const PinnedStopsBar({super.key});

  @override
  State<PinnedStopsBar> createState() => _PinnedStopsBarState();
}

class _PinnedStopsBarState extends State<PinnedStopsBar> {
  PinnedStopsController? _controller;
  late EtaService _etaService;
  EtaService? _subscribedService;
  StreamSubscription<EtaStatusUpdate>? _statusSubscription;
  Timer? _timer;
  Map<String, List<BusEta>> _etas = const {};
  int _generation = 0;
  String _language = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _etaService = context.read<EtaService>();
    if (!identical(_subscribedService, _etaService)) {
      _statusSubscription?.cancel();
      _subscribedService = _etaService;
      _statusSubscription = _etaService.statusUpdates.listen(_onStatusUpdate);
    }
    final AppSettings settings = context.read<AppSettings>();
    if (_language != settings.language) {
      _language = settings.language;
      _etaService.setLanguage(settings.language);
      _restart();
    }
    final PinnedStopsController next = context.read<PinnedStopsController>();
    if (_controller != next) {
      _controller?.removeListener(_handlePinsChanged);
      _controller = next;
      _controller!.addListener(_handlePinsChanged);
      _restart();
    }
  }

  void _handlePinsChanged() {
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    final PinnedStopsController? controller = _controller;
    if (controller == null || controller.stations.isEmpty) {
      _etas = const {};
      return;
    }
    final int generation = _generation;
    _etas = const {};
    _fetchAll(generation);
    _timer = Timer.periodic(
      Duration(seconds: context.read<AppSettings>().refreshSeconds),
      (_) => _fetchAll(generation),
    );
  }

  Future<void> _fetchAll(int generation) async {
    final PinnedStopsController? controller = _controller;
    if (controller == null || controller.stations.isEmpty) return;
    final BusRepository repository = context.read<BusRepository>();
    final Map<String, List<BusEta>> results = {};
    await Future.wait(
      controller.stations.map((PinnedStation pin) async {
        final RouteEntry? route = repository.routeByKey(pin.routeKey);
        if (route == null ||
            pin.seq < 0 ||
            pin.seq >= route.primaryStops.length) {
          return;
        }
        try {
          results[pin.id] = await _etaService.fetchRouteStop(route, pin.seq);
        } catch (_) {
          results[pin.id] = const [];
        }
      }),
    );
    if (!mounted || generation != _generation) return;
    setState(() => _etas = results);
  }

  void _onStatusUpdate(EtaStatusUpdate update) {
    if (!mounted) return;
    final PinnedStopsController? controller = _controller;
    if (controller == null || controller.stations.isEmpty) return;
    final BusRepository repository = context.read<BusRepository>();
    bool changed = false;
    final Map<String, List<BusEta>> next = Map<String, List<BusEta>>.of(_etas);
    for (final PinnedStation pin in controller.stations) {
      if (pin.seq != update.seq) continue;
      final RouteEntry? route = repository.routeByKey(pin.routeKey);
      if (route == null || route.key != update.routeKey) continue;
      final List<BusEta>? current = next[pin.id];
      if (current == null) continue;
      final List<BusEta> updated = _etaService.applyCachedStatuses(
        route,
        pin.seq,
        current,
      );
      if (identical(updated, current)) continue;
      next[pin.id] = updated;
      changed = true;
    }
    if (changed) setState(() => _etas = next);
  }

  @override
  void dispose() {
    _controller?.removeListener(_handlePinsChanged);
    _timer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final List<PinnedStation> pins = context
        .watch<PinnedStopsController>()
        .stations;
    if (pins.isEmpty) return const SizedBox.shrink();

    final List<_PinnedChipData> items = [];
    for (final PinnedStation pin in pins) {
      final RouteEntry? route = repository.routeByKey(pin.routeKey);
      if (route == null ||
          pin.seq < 0 ||
          pin.seq >= route.primaryStops.length) {
        continue;
      }
      final String stopId = route.primaryStops[pin.seq];
      final StopEntry? stop = repository.stopById(stopId);
      final List<BusEta>? etas = _etas[pin.id];
      BusEta? next;
      for (final BusEta eta in etas ?? const <BusEta>[]) {
        if (eta.eta != null || eta.remark(settings.language).isNotEmpty) {
          next = eta;
          break;
        }
      }
      items.add(
        _PinnedChipData(
          pin: pin,
          route: route,
          stopName: stop?.displayName(settings.language) ?? stopId,
          eta: next,
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (int index = 0; index < items.length; index++) ...[
                  _PinnedChip(
                    item: items[index],
                    settings: settings,
                    onUnpin: () => context.read<PinnedStopsController>().remove(
                      items[index].pin,
                    ),
                  ),
                  if (index != items.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedChipData {
  const _PinnedChipData({
    required this.pin,
    required this.route,
    required this.stopName,
    required this.eta,
  });

  final PinnedStation pin;
  final RouteEntry route;
  final String stopName;
  final BusEta? eta;
}

class _PinnedChip extends StatelessWidget {
  const _PinnedChip({
    required this.item,
    required this.settings,
    required this.onUnpin,
  });

  final _PinnedChipData item;
  final AppSettings settings;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = _etaLabel(item.eta, settings);
    return Container(
      width: 214,
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${routeDisplayName(item.route, settings.language)} · ${item.stopName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                FadeIn(
                  key: ValueKey<String>(
                    item.eta == null
                        ? 'empty|${item.pin.id}'
                        : etaDisplayKey(item.eta!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.eta?.shouldShowScheduleIcon(DateTime.now()) ??
                          false)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.schedule,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          M3EIconButton(
            tooltip: settings.text('取消釘選', 'Unpin'),
            icon: const Icon(Icons.close),
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.xs,
            inflateHitTarget: false,
            onPressed: onUnpin,
          ),
        ],
      ),
    );
  }

  String _etaLabel(BusEta? eta, AppSettings settings) {
    if (eta == null) return '--';
    final DateTime? time = eta.eta;
    if (time == null) {
      final String remark = eta.remark(settings.language);
      return remark.isEmpty ? '--' : remark;
    }
    final DateTime hkTime = time.toUtc().add(const Duration(hours: 8));
    final String clock =
        proprietaryClockLabel(eta) ?? DateFormat('HH:mm').format(hkTime);
    final int minutes = time.difference(DateTime.now().toUtc()).inMinutes;
    final String? departed = departedEtaLabel(eta, settings);
    final String wait =
        proprietaryMinutesLabel(eta, settings) ??
        (minutes < 1
            ? settings.text('即將到達', 'Arriving')
            : '$minutes ${settings.text('分', 'min')}');
    return departed != null
        ? '$clock · $departed'
        : switch (settings.etaFormat) {
            EtaFormat.diff => wait,
            EtaFormat.exact => clock,
            EtaFormat.mixed => '$clock · $wait',
          };
  }
}
