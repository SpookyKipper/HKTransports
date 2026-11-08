import 'package:flutter/material.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class CitybusStopLandmark extends StatefulWidget {
  const CitybusStopLandmark({
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
  State<CitybusStopLandmark> createState() => _CitybusStopLandmarkState();
}

class _CitybusStopLandmarkState extends State<CitybusStopLandmark> {
  Future<CitybusStopData?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CitybusStopLandmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.stopIndex != widget.stopIndex ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled || !widget.route.companies.contains(BusCompany.ctb)) {
      _future = null;
      return;
    }
    _future = CitybusRoutelistService.instance.stopData(
      widget.route,
      widget.stopIndex,
      widget.language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Future<CitybusStopData?>? future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<CitybusStopData?>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<CitybusStopData?> snapshot) {
            final String landmark = snapshot.data?.landmark?.trim() ?? '';
            if (landmark.isEmpty) return const SizedBox.shrink();
            final ThemeData theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      landmark,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}
