import 'package:flutter/material.dart';
import 'package:hktransports/bus/fare/joyyou_fare.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class NlbFareLabel extends StatefulWidget {
  const NlbFareLabel({
    super.key,
    required this.route,
    required this.stopIndex,
    required this.language,
    required this.enabled,
    required this.holiday,
    this.fallbackFare,
    this.alightingOnly = false,
  });

  final RouteEntry route;
  final int stopIndex;
  final String language;
  final bool enabled;
  final bool holiday;
  final String? fallbackFare;
  final bool alightingOnly;

  @override
  State<NlbFareLabel> createState() => _NlbFareLabelState();
}

class _NlbFareLabelState extends State<NlbFareLabel> {
  Future<NlbRoutePageData?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NlbFareLabel oldWidget) {
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
    if (widget.alightingOnly) return _buildAlightingOnly(context);
    final Future<NlbRoutePageData?>? future = _future;
    if (future == null) return _buildFallback(context);
    return FutureBuilder<NlbRoutePageData?>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<NlbRoutePageData?> snapshot) {
            final NlbRouteStopData? stop =
                snapshot.data?.stops[widget.stopIndex + 1];
            final String? pageFare = widget.holiday
                ? stop?.holidayFare
                : stop?.weekdayFare;
            if (pageFare == null || pageFare.isEmpty) {
              return _buildFallback(context);
            }
            return _buildFare(context, pageFare);
          },
    );
  }

  Widget _buildAlightingOnly(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return Text(
      settings.text('只供落客', 'Alighting only'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final String? fallback = widget.fallbackFare;
    if (fallback == null) return const SizedBox.shrink();
    return _buildFare(context, fallback);
  }

  Widget _buildFare(BuildContext context, String adultFare) {
    final AppSettings settings = context.watch<AppSettings>();
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    final double? adultValue = double.tryParse(adultFare);
    final String? joyYouFare =
        settings.showJoyYouFare && adultValue != null && adultValue > 0
        ? calculateJoyYouFare(
            route: widget.route.route,
            companies: widget.route.companies,
            adultFare: adultValue,
          )
        : null;
    final String adultLabel = '${settings.text('車費', 'Fare')} \$$adultFare';
    if (joyYouFare == null) return Text(adultLabel, style: style);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(adultLabel, style: style),
        Text('${settings.text('樂悠', 'JoyYou')} \$$joyYouFare', style: style),
      ],
    );
  }
}
