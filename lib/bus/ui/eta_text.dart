import 'package:flutter/material.dart';

/// ETA text with an optional appended status that fades in on its own.
class EtaText extends StatelessWidget {
  const EtaText({
    super.key,
    required this.base,
    required this.appended,
    required this.style,
    required this.color,
    required this.appendedKey,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String base;
  final String? appended;
  final TextStyle? style;
  final Color color;
  final String appendedKey;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final String? text = appended;
    if (text == null || text.isEmpty) {
      return Text.rich(
        TextSpan(text: base),
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
          TextSpan(
            children: [
              TextSpan(text: base),
              TextSpan(
                text: ' · $text',
                style: TextStyle(color: color.withValues(alpha: opacity)),
              ),
            ],
          ),
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        );
      },
    );
  }
}
