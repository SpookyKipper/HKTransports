import 'package:flutter/material.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_reader.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/fare/joyyou_fare.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class CitybusFareLabel extends StatefulWidget {
  const CitybusFareLabel({
    super.key,
    required this.route,
    required this.stopIndex,
    required this.language,
    required this.enabled,
    this.fallbackFare,
    this.alightingOnly = false,
  });

  final RouteEntry route;
  final int stopIndex;
  final String language;
  final bool enabled;
  final String? fallbackFare;
  final bool alightingOnly;

  @override
  State<CitybusFareLabel> createState() => _CitybusFareLabelState();
}

class _CitybusFareLabelState extends State<CitybusFareLabel> {
  Future<CitybusStopData?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CitybusFareLabel oldWidget) {
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
    if (widget.alightingOnly) return _buildAlightingOnly(context);
    final Future<CitybusStopData?>? future = _future;
    if (future == null) return _buildFallback(context);
    final AppSettings settings = context.watch<AppSettings>();
    return FutureBuilder<CitybusStopData?>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<CitybusStopData?> snapshot) {
            final double? fare = snapshot.data?.adultFare;
            if (fare == null) return _buildFallback(context);
            if (fare == 0) return _buildAlightingOnly(context);
            return _buildFare(
              context,
              '${settings.text('車費', 'Fare')} \$${formatCitybusFare(fare)}',
              fare,
            );
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
    final AppSettings settings = context.watch<AppSettings>();
    return _buildFare(
      context,
      '${settings.text('車費', 'Fare')} \$$fallback',
      double.tryParse(fallback),
    );
  }

  Widget _buildFare(
    BuildContext context,
    String adultLabel,
    double? adultFare,
  ) {
    final AppSettings settings = context.watch<AppSettings>();
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    final String? joyYouFare =
        settings.showJoyYouFare && adultFare != null && adultFare > 0
        ? calculateJoyYouFare(
            route: widget.route.route,
            companies: widget.route.companies,
            adultFare: adultFare,
          )
        : null;
    if (joyYouFare == null) {
      return Text(adultLabel, style: style);
    }
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

String formatCitybusFare(double fare) {
  String value = fare.toStringAsFixed(2);
  value = value.replaceFirst(RegExp(r'\.?0+$'), '');
  return value.isEmpty ? '0' : value;
}
