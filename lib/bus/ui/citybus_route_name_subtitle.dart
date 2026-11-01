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
        if (routeName.isEmpty) return _buildText(widget.text);
        if (widget.text.isEmpty) return _buildText(routeName);
        if (widget.marqueeWhenOverflow) {
          return _buildText('${widget.text} · $routeName');
        }
        return _RouteNameWithNote(
          base: widget.text,
          routeName: routeName,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
    );
  }

  Widget _buildText(String text) {
    if (widget.marqueeWhenOverflow) {
      return AutoMarqueeText(text: text, style: widget.style);
    }
    return _RouteSubtitleText(
      text: text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

class _RouteNameWithNote extends StatelessWidget {
  const _RouteNameWithNote({
    required this.base,
    required this.routeName,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String base;
  final String routeName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.maxWidth.isFinite) {
          return _RouteSubtitleText(
            text: '$base · $routeName',
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          );
        }
        final TextStyle effectiveStyle =
            style ?? DefaultTextStyle.of(context).style;
        final TextPainter painter = TextPainter(
          text: TextSpan(text: '$base · $routeName', style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        if (painter.width <= constraints.maxWidth) {
          return _RouteSubtitleText(
            text: '$base · $routeName',
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouteSubtitleText(
              text: base,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
            ),
            _RouteSubtitleText(
              text: routeName,
              style: style,
              maxLines: maxLines,
              overflow: overflow,
            ),
          ],
        );
      },
    );
  }
}

class _RouteSubtitleText extends StatelessWidget {
  const _RouteSubtitleText({
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style, maxLines: maxLines, overflow: overflow);
  }
}
