import 'package:flutter/material.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

typedef CitybusRouteDescriptionBuilder =
    Widget Function(BuildContext context, String label);

class CitybusRouteDescription extends StatefulWidget {
  const CitybusRouteDescription({
    super.key,
    required this.route,
    required this.language,
    required this.enabled,
    required this.fallback,
    required this.builder,
  });

  final RouteEntry route;
  final String language;
  final bool enabled;
  final String fallback;
  final CitybusRouteDescriptionBuilder builder;

  @override
  State<CitybusRouteDescription> createState() =>
      _CitybusRouteDescriptionState();
}

class _CitybusRouteDescriptionState extends State<CitybusRouteDescription> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CitybusRouteDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled ||
        !widget.route.isSpecial ||
        !widget.route.companies.contains(BusCompany.ctb)) {
      _future = null;
      return;
    }
    _future = CitybusRoutelistService.instance.specialDescription(
      widget.route,
      widget.language,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Future<String?>? future = _future;
    if (future == null) return widget.builder(context, widget.fallback);
    return FutureBuilder<String?>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String description = snapshot.data?.trim() ?? '';
        return widget.builder(
          context,
          description.isEmpty ? widget.fallback : description,
        );
      },
    );
  }
}
