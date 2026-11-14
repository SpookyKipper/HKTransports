import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hktransports/bus/eta/eta_display.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/fade_in.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class RouteEtaView extends StatefulWidget {
  const RouteEtaView({
    super.key,
    required this.route,
    required this.seq,
    this.refreshVersion = 0,
  });

  final RouteEntry route;
  final int seq;
  final int refreshVersion;

  @override
  State<RouteEtaView> createState() => _RouteEtaViewState();
}

class _RouteEtaViewState extends State<RouteEtaView> {
  late final EtaService _etaService;
  StreamSubscription<EtaStatusUpdate>? _statusSubscription;
  late String _language;
  Timer? _timer;
  List<BusEta>? _etas;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _etaService = context.read<EtaService>();
    _language = context.read<AppSettings>().language;
    _etaService.setLanguage(_language);
    _statusSubscription = _etaService.statusUpdates.listen(_onStatusUpdate);
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String language = context.read<AppSettings>().language;
    if (language != _language) {
      _language = language;
      _etaService.setLanguage(language);
      _fetch();
    }
  }

  @override
  void didUpdateWidget(covariant RouteEtaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.seq != widget.seq) {
      setState(() {
        _loading = true;
        _etas = null;
      });
      _start();
    } else if (oldWidget.refreshVersion != widget.refreshVersion) {
      _fetch();
    }
  }

  void _start() {
    _timer?.cancel();
    final AppSettings settings = context.read<AppSettings>();
    _timer = Timer.periodic(
      Duration(seconds: settings.refreshSeconds),
      (_) => _fetch(),
    );
    _fetch();
  }

  Future<void> _fetch() async {
    final int requestId = ++_requestId;
    final List<BusEta> etas = await _etaService.fetchRouteStop(
      widget.route,
      widget.seq,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _etas = etas;
      _loading = false;
    });
  }

  void _onStatusUpdate(EtaStatusUpdate update) {
    if (!mounted ||
        update.routeKey != widget.route.key ||
        update.seq != widget.seq) {
      return;
    }
    final List<BusEta>? current = _etas;
    if (current == null) return;
    final List<BusEta> updated = _etaService.applyCachedStatuses(
      widget.route,
      widget.seq,
      current,
    );
    if (identical(updated, current)) return;
    setState(() => _etas = updated);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<BusEta> etas = (_etas ?? const [])
        .where(
          (eta) =>
              eta.eta != null ||
              eta.proprietaryTime != null ||
              eta.proprietaryMinutes != null,
        )
        .take(3)
        .toList();
    if (_loading && _etas == null) {
      return const M3ELoadingIndicator(size: 24);
    }
    if (etas.isEmpty) {
      return Text('--', style: Theme.of(context).textTheme.bodySmall);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int index = 0; index < etas.length; index++)
            FadeIn(
              key: ValueKey<String>(etaDisplayKey(etas[index])),
              child: _RouteEtaLine(
                eta: etas[index],
                first: index == 0,
                atOrigin: widget.seq == 0,
              ),
            ),
        ],
      ),
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

class _RouteEtaLine extends StatelessWidget {
  const _RouteEtaLine({
    required this.eta,
    required this.first,
    required this.atOrigin,
  });

  final BusEta eta;
  final bool first;
  final bool atOrigin;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final DateTime? time = eta.eta;
    final String remark = eta.remark(settings.language);
    if (time == null) {
      final String? proprietary = _proprietaryOnlyLabel(eta, settings);
      final String message = proprietary ?? remark;
      if (message.isEmpty) return const SizedBox.shrink();
      return Text(
        message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final DateTime hkTime = time.toUtc().add(const Duration(hours: 8));
    final String clock =
        proprietaryClockLabel(eta) ?? DateFormat('HH:mm').format(hkTime);
    final int minutes = time.difference(DateTime.now().toUtc()).inMinutes;
    final String? departed = eta.proprietaryTime == null
        ? departedEtaLabel(eta, settings)
        : null;
    final String wait =
        proprietaryMinutesLabel(eta) ??
        (minutes < 1
            ? atOrigin
                  ? settings.text('即場開出', 'Departing now')
                  : settings.text('即將到達', 'Arriving')
            : '$minutes ${settings.text('分', 'min')}');
    final String base = departed != null
        ? '$clock  $departed'
        : switch (settings.etaFormat) {
            EtaFormat.diff => wait,
            EtaFormat.exact => clock,
            EtaFormat.mixed => '$clock  $wait',
          };
    final Color color = first
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final TextStyle? style = first
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)
        : Theme.of(context).textTheme.bodySmall?.copyWith(color: color);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eta.shouldShowScheduleIcon(DateTime.now()))
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.schedule, size: first ? 16 : 14, color: color),
          ),
        Flexible(
          child: Text(
            base,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: style,
          ),
        ),
      ],
    );
  }
}
