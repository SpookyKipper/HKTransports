import 'package:flutter/material.dart';
import 'package:hktransports/bus/kmb/kmb_route_data_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

typedef KmbRouteDescriptionBuilder =
    Widget Function(BuildContext context, String label);

class KmbRouteDescription extends StatefulWidget {
  const KmbRouteDescription({
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
  final KmbRouteDescriptionBuilder builder;

  @override
  State<KmbRouteDescription> createState() => _KmbRouteDescriptionState();
}

class _KmbRouteDescriptionState extends State<KmbRouteDescription> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant KmbRouteDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
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
    _future = KmbRouteDataService.instance.serviceDescription(
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
