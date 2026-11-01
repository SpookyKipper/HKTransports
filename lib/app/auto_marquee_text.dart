import 'package:flutter/material.dart';

class AutoMarqueeText extends StatefulWidget {
  const AutoMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 35,
    this.gap = 24,
  });

  final String text;
  final TextStyle? style;
  final double velocity;
  final double gap;

  @override
  State<AutoMarqueeText> createState() => _AutoMarqueeTextState();
}

class _AutoMarqueeTextState extends State<AutoMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  _MarqueeConfig? _config;
  double _distance = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = widget.style ?? DefaultTextStyle.of(context).style;
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          );
        }
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout();
        final double overflow = painter.width - constraints.maxWidth;
        final _MarqueeConfig config = _MarqueeConfig(
          text: widget.text,
          width: constraints.maxWidth,
          overflow: overflow,
          style: style,
        );
        if (overflow <= 0) {
          _scheduleConfig(config);
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          );
        }

        _scheduleConfig(config);
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double offset = _offsetFor(_controller.value);
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Text(
                widget.text,
                style: style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleConfig(_MarqueeConfig config) {
    if (_config == config) return;
    _config = config;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _config != config) return;
      if (config.overflow <= 0) {
        _controller.stop();
        _distance = 0;
        return;
      }
      final double distance = config.overflow + widget.gap;
      final int scrollMs = (distance / widget.velocity * 1000).round().clamp(
        1600,
        24000,
      );
      _controller.stop();
      _controller.duration = Duration(milliseconds: scrollMs + 2400);
      _distance = distance;
      _controller.repeat();
    });
  }

  double _offsetFor(double value) {
    const double start = 0.11;
    const double end = 0.89;
    if (value <= start) return 0;
    if (value >= end) return -_distance;
    final double progress = (value - start) / (end - start);
    return -_distance * progress;
  }
}

class _MarqueeConfig {
  const _MarqueeConfig({
    required this.text,
    required this.width,
    required this.overflow,
    required this.style,
  });

  final String text;
  final double width;
  final double overflow;
  final TextStyle style;

  @override
  bool operator ==(Object other) {
    return other is _MarqueeConfig &&
        other.text == text &&
        other.width == width &&
        other.overflow == overflow &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(text, width, overflow, style);
}
