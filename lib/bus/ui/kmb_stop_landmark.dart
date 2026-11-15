import 'package:flutter/material.dart';
import 'package:hktransports/bus/kmb/kmb_route_data_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class KmbStopLandmark extends StatefulWidget {
  const KmbStopLandmark({
    super.key,
    required this.route,
    required this.stopIndex,
    required this.language,
    required this.enabled,
  });

  final RouteEntry route;
  final int stopIndex;
  final String language;
  final bool enabled;

  @override
  State<KmbStopLandmark> createState() => _KmbStopLandmarkState();
}

class _KmbStopLandmarkState extends State<KmbStopLandmark> {
  Future<List<String>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant KmbStopLandmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.stopIndex != widget.stopIndex ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled || !widget.route.companies.contains(BusCompany.kmb)) {
      _future = null;
      return;
    }
    _future = KmbRouteDataService.instance.stopLocations(
      widget.route,
      widget.stopIndex,
      widget.language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Future<List<String>>? future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<String>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
        final List<String> parts = snapshot.data ?? const <String>[];
        if (parts.isEmpty) return const SizedBox.shrink();
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            parts.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
