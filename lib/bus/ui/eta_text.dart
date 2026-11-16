import 'package:flutter/material.dart';
import 'package:hktransports/bus/ui/fade_in.dart';

/// ETA text with an optional appended status that fades in on its own.
class EtaText extends StatelessWidget {
  const EtaText({
    super.key,
    required this.base,
    required this.appended,
    required this.style,
    required this.color,
    required this.appendedKey,
    this.wheelchair = false,
    this.solarPowered = false,
    this.solarLabel,
    this.occupancyPercent,
    this.occupancyLabel,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String base;
  final String? appended;
  final TextStyle? style;
  final Color color;
  final String appendedKey;
  final bool wheelchair;
  final bool solarPowered;
  final String? solarLabel;
  final int? occupancyPercent;
  final String? occupancyLabel;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final String? text = appended;
    List<InlineSpan> spans(double opacity) {
      return <InlineSpan>[
        if (solarPowered)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: solarLabel ?? 'Solar bus',
                child: FadeIn(
                  key: const ValueKey<String>('solar-powered'),
                  child: Icon(
                    Icons.solar_power,
                    size: style?.fontSize ?? 14,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        if (occupancyPercent != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _OccupancyIndicator(
                percent: occupancyPercent!,
                color: color,
                label: occupancyLabel,
                style: style,
              ),
            ),
          ),
        if (base.isNotEmpty) TextSpan(text: base),
        if (text != null && text.isNotEmpty)
          TextSpan(
            text: base.isEmpty ? text : ' · $text',
            style: TextStyle(color: color.withValues(alpha: opacity)),
          ),
        if (wheelchair)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: FadeIn(
                key: const ValueKey<String>('wheelchair'),
                child: Icon(
                  Icons.accessible,
                  size: style?.fontSize ?? 14,
                  color: color,
                ),
              ),
            ),
          ),
      ];
    }

    if (text == null || text.isEmpty) {
      return Text.rich(
        TextSpan(children: spans(1)),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(appendedKey),
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (BuildContext context, double opacity, Widget? child) {
        return Text.rich(
          TextSpan(children: spans(opacity)),
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        );
      },
    );
  }
}

class _OccupancyIndicator extends StatelessWidget {
  const _OccupancyIndicator({
    required this.percent,
    required this.color,
    required this.label,
    required this.style,
  });

  final int percent;
  final Color color;
  final String? label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final double size = (style?.fontSize ?? 14) + 2;
    return Tooltip(
      message: label ?? '$percent% full',
      child: Semantics(
        label: label ?? '$percent% full',
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: percent / 100,
                  strokeWidth: 1.5,
                  backgroundColor: color.withValues(alpha: 0.22),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Icon(Icons.person, size: size * 0.55, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
