import 'package:flutter/material.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';

class NlbStopLandmark extends StatefulWidget {
  const NlbStopLandmark({
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
  State<NlbStopLandmark> createState() => _NlbStopLandmarkState();
}

class _NlbStopLandmarkState extends State<NlbStopLandmark> {
  Future<NlbRoutePageData?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NlbStopLandmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.stopIndex != widget.stopIndex ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled || !widget.route.companies.contains(BusCompany.nlb)) {
      _future = null;
      return;
    }
    _future = NlbTimetableService.instance.fetchRouteData(
      widget.route,
      widget.language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Future<NlbRoutePageData?>? future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<NlbRoutePageData?>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<NlbRoutePageData?> snapshot) {
            final NlbRouteStopData? stop =
                snapshot.data?.stops[widget.stopIndex + 1];
            final String location = stop?.location.trim() ?? '';
            if (location.isEmpty || location == stop?.name) {
              return const SizedBox.shrink();
            }
            final ThemeData theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                location,
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
