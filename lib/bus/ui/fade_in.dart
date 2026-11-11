import 'package:flutter/material.dart';

/// Fades its child in when this widget is first inserted.
class FadeIn extends StatelessWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOut,
      child: child,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(opacity: value, child: child);
      },
    );
  }
}
