import 'package:flutter/material.dart';
import 'package:hktransports/bus/cache/nlb_route_name_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/route_special_tag.dart';
import 'package:provider/provider.dart';

/// Shows the native special-route tag for NLB routes whose official page
/// marks them as special departures.
class NlbRouteSpecialTag extends StatefulWidget {
  const NlbRouteSpecialTag({
    super.key,
    required this.route,
    required this.language,
    required this.enabled,
    this.padding = EdgeInsets.zero,
  });

  final RouteEntry route;
  final String language;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  State<NlbRouteSpecialTag> createState() => _NlbRouteSpecialTagState();
}

class _NlbRouteSpecialTagState extends State<NlbRouteSpecialTag> {
  static const NlbRouteNameService _service = NlbRouteNameService();
  Future<bool>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NlbRouteSpecialTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.route.nlbRouteId != widget.route.nlbRouteId ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled ||
        widget.route.isSpecial ||
        !widget.route.companies.contains(BusCompany.nlb)) {
      _future = null;
      return;
    }
    _future = _service.isSpecial(widget.route, widget.language);
  }

  @override
  Widget build(BuildContext context) {
    final Future<bool>? future = _future;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<bool>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final AppSettings settings = context.watch<AppSettings>();
        return Padding(
          padding: widget.padding,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RouteSpecialTag(
              label: settings.text('特別班', 'Special'),
            ),
          ),
        );
      },
    );
  }
}
