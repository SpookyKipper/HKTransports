import 'package:flutter/material.dart';
import 'package:hktransports/app/auto_marquee_text.dart';
import 'package:hktransports/bus/cache/citybus_route_name_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class CitybusRouteNameSubtitle extends StatefulWidget {
  const CitybusRouteNameSubtitle({
    super.key,
    required this.route,
    required this.language,
    required this.enabled,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.marqueeWhenOverflow = false,
  });

  final RouteEntry route;
  final String language;
  final bool enabled;
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool marqueeWhenOverflow;

  @override
  State<CitybusRouteNameSubtitle> createState() =>
      _CitybusRouteNameSubtitleState();
}

class _CitybusRouteNameSubtitleState extends State<CitybusRouteNameSubtitle> {
  static const CitybusRouteNameService _service = CitybusRouteNameService();
  Future<String?>? _routeNameFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CitybusRouteNameSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.route != widget.route.route ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled || !widget.route.companies.contains(BusCompany.ctb)) {
      _routeNameFuture = null;
      return;
    }
    _routeNameFuture = _service.routeName(widget.route.route, widget.language);
  }

  @override
  Widget build(BuildContext context) {
    final Future<String?>? future = _routeNameFuture;
    if (future == null) return _buildText(widget.text);
    return FutureBuilder<String?>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String routeName = snapshot.data?.trim() ?? '';
        final String text = routeName.isEmpty
            ? widget.text
            : widget.text.isEmpty
            ? routeName
            : '${widget.text} · $routeName';
        return _buildText(text);
      },
    );
  }

  Widget _buildText(String text) {
    if (widget.marqueeWhenOverflow) {
      return AutoMarqueeText(text: text, style: widget.style);
    }
    return Text(
      text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
