import 'package:flutter/material.dart';
import 'package:hktransports/bus/ui/fade_in.dart';

/// ETA text with an optional appended status that fades in on its own.
class EtaText extends StatelessWidget {
  const EtaText({
    super.key,
    required this.base,
    this.details,
    required this.appended,
    required this.style,
    required this.color,
    required this.appendedKey,
    this.wheelchair = false,
    this.solarPowered = false,
    this.solarLabel,
    this.occupancyPercent,
    this.occupancyLabel,
    this.doubleWheelchair = false,
    this.doubleWheelchairLabel,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String base;
  final String? details;
  final String? appended;
  final TextStyle? style;
  final Color color;
  final String appendedKey;
  final bool wheelchair;
  final bool solarPowered;
  final String? solarLabel;
  final int? occupancyPercent;
  final String? occupancyLabel;
  final bool doubleWheelchair;
  final String? doubleWheelchairLabel;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final String? text = appended;
    List<InlineSpan> spans(double opacity) {
      final List<InlineSpan> result = <InlineSpan>[];
      bool hasContent = false;

      if (base.isNotEmpty) {
        result.add(TextSpan(text: base));
        hasContent = true;
      }

      final bool hasMarkers =
          solarPowered || occupancyPercent != null || doubleWheelchair;
      if (hasMarkers) {
        if (hasContent) result.add(const TextSpan(text: ' · '));
        if (solarPowered) {
          result.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: solarLabel ?? 'Solar bus',
                  triggerMode: TooltipTriggerMode.tap,
                  waitDuration: Duration.zero,
                  showDuration: const Duration(seconds: 3),
                  preferBelow: false,
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
          );
        }
        if (occupancyPercent != null) {
          result.add(
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
          );
        }
        if (doubleWheelchair) {
          result.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _DoubleWheelchairIndicator(
                  color: color,
                  label: doubleWheelchairLabel,
                  style: style,
                ),
              ),
            ),
          );
        }
        hasContent = true;
      }

      final String? detailText = details;
      if (detailText != null && detailText.isNotEmpty) {
        if (hasContent) {
          result.add(const TextSpan(text: ' · '));
        }
        result.add(TextSpan(text: detailText));
        hasContent = true;
      }

      final String? text = appended;
      if (text != null && text.isNotEmpty) {
        if (hasContent) result.add(const TextSpan(text: ' · '));
        result.add(
          TextSpan(
            text: text,
            style: TextStyle(color: color.withValues(alpha: opacity)),
          ),
        );
        hasContent = true;
      }

      if (wheelchair) {
        result.add(
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
        );
      }
      return result;
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
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 3),
      preferBelow: false,
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

class _DoubleWheelchairIndicator extends StatelessWidget {
  const _DoubleWheelchairIndicator({
    required this.color,
    required this.label,
    required this.style,
  });

  final Color color;
  final String? label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final double size = style?.fontSize ?? 14;
    final Color surface = Theme.of(context).colorScheme.surface;
    return Tooltip(
      message: label ?? 'Double wheelchair bus',
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 3),
      preferBelow: false,
      child: Semantics(
        label: label ?? 'Double wheelchair bus',
        child: SizedBox(
          width: size + 2,
          height: size + 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                bottom: 0,
                child: Icon(Icons.accessible, size: size, color: color),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: size * 0.65,
                  height: size * 0.65,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: color,
                      fontSize: size * 0.48,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
