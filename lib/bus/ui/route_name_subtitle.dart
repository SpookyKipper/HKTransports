import 'package:flutter/material.dart';
import 'package:hktransports/bus/cache/citybus_route_name_service.dart';
import 'package:hktransports/bus/cache/nlb_route_name_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

bool routeNameEnabled(RouteEntry route, AppSettings settings) {
  if (route.companies.contains(BusCompany.ctb)) {
    return settings.isProprietaryEnabled(ProprietaryEndpoint.citybusDatabase);
  }
  if (route.companies.contains(BusCompany.nlb)) {
    return settings.isProprietaryEnabled(
      ProprietaryEndpoint.nlbProprietaryData,
    );
  }
  return false;
}

class RouteNameSubtitle extends StatefulWidget {
  const RouteNameSubtitle({
    super.key,
    required this.route,
    required this.language,
    required this.enabled,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.compactAppBar = false,
  });

  final RouteEntry route;
  final String language;
  final bool enabled;
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool compactAppBar;

  @override
  State<RouteNameSubtitle> createState() => _RouteNameSubtitleState();
}

class _RouteNameSubtitleState extends State<RouteNameSubtitle> {
  static const CitybusRouteNameService _citybusService =
      CitybusRouteNameService();
  static const NlbRouteNameService _nlbService = NlbRouteNameService();
  Future<String?>? _routeNameFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RouteNameSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.route.nlbRouteId != widget.route.nlbRouteId ||
        oldWidget.language != widget.language ||
        oldWidget.enabled != widget.enabled) {
      _load();
    }
  }

  void _load() {
    if (!widget.enabled) {
      _routeNameFuture = null;
      return;
    }
    if (widget.route.companies.contains(BusCompany.ctb)) {
      _routeNameFuture = _citybusService.routeName(
        widget.route,
        widget.language,
      );
    } else if (widget.route.companies.contains(BusCompany.nlb)) {
      _routeNameFuture = _nlbService.routeName(widget.route, widget.language);
    } else {
      _routeNameFuture = null;
    }
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
        if (widget.compactAppBar) {
          return _CompactRouteSubtitle(
            base: widget.text,
            routeName: routeName,
            style: widget.style,
          );
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
    return _RouteSubtitleText(
      text: text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

class _CompactRouteSubtitle extends StatelessWidget {
  const _CompactRouteSubtitle({
    required this.base,
    required this.routeName,
    this.style,
  });

  final String base;
  final String routeName;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final String fullText = '$base · $routeName';
        if (constraints.maxWidth.isFinite) {
          final TextPainter painter = TextPainter(
            text: TextSpan(
              text: fullText,
              style: style ?? DefaultTextStyle.of(context).style,
            ),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          if (painter.width <= constraints.maxWidth) {
            return _RouteSubtitleText(
              text: fullText,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.clip,
            );
          }
        }
        final String compactName = stripCitybusPeakNotice(routeName);
        final String compactText = compactName.isEmpty
            ? base
            : '$base · $compactName';
        return _RouteSubtitleText(
          text: compactText,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

String stripCitybusPeakNotice(String routeName) {
  String text = routeName.trim();
  text = text.replaceFirst(RegExp(r'繁忙時間\s*星期一至五'), '');
  text = text.replaceFirst(
    RegExp(r'peak only,?\s*monday to friday only', caseSensitive: false),
    '',
  );
  text = text.replaceFirst(
    RegExp(r'peak hours?,?\s*monday to friday', caseSensitive: false),
    '',
  );
  return text.replaceFirst(RegExp(r'^[\s,，、·:：\-–—]+'), '').trim();
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
