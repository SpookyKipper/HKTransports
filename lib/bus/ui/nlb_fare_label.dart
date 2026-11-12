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
    this.fallbackWeekdayFare,
    this.fallbackHolidayFare,
    this.alightingOnly = false,
  });

  final RouteEntry route;
  final int stopIndex;
  final String language;
  final bool enabled;
  final bool holiday;
  final String? fallbackWeekdayFare;
  final String? fallbackHolidayFare;
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
            final String? weekday = _nonEmpty(
              stop?.weekdayFare,
              widget.fallbackWeekdayFare,
            );
            final String? holiday = _nonEmpty(
              stop?.holidayFare,
              widget.fallbackHolidayFare,
            );
            if (weekday == null && holiday == null) {
              return _buildFallback(context);
            }
            return _buildFares(context, weekday, holiday);
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

  String? _nonEmpty(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) return primary.trim();
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    return null;
  }

  Widget _buildFallback(BuildContext context) {
    final String? weekday = _nonEmpty(null, widget.fallbackWeekdayFare);
    final String? holiday = _nonEmpty(null, widget.fallbackHolidayFare);
    if (weekday == null && holiday == null) return const SizedBox.shrink();
    return _buildFares(context, weekday, holiday);
  }

  Widget _buildFares(BuildContext context, String? weekday, String? holiday) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    final TextStyle? normalStyle = theme.textTheme.bodySmall;
    final TextStyle? disabledStyle = normalStyle?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
    );
    final List<Widget> children = <Widget>[];
    if (weekday != null) {
      children.add(
        Text(
          '${settings.text('車費', 'Fare')}: \$$weekday',
          style: widget.holiday ? disabledStyle : normalStyle,
        ),
      );
    }
    if (holiday != null) {
      children.add(
        Text(
          '${settings.text('假日', 'Holiday')}: \$$holiday',
          style: widget.holiday ? normalStyle : disabledStyle,
        ),
      );
    }
    final String? current = widget.holiday ? holiday : weekday;
    final double? currentValue = current == null
        ? null
        : double.tryParse(current);
    final String? joyYouFare =
        settings.showJoyYouFare && currentValue != null && currentValue > 0
        ? calculateJoyYouFare(
            route: widget.route.route,
            companies: widget.route.companies,
            adultFare: currentValue,
          )
        : null;
    if (joyYouFare != null) {
      children.add(
        Text(
          '${settings.text('樂悠', 'JoyYou')}: \$$joyYouFare',
          style: normalStyle,
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 4, children: children);
  }
}
