import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hktransports/app/display_geometry.dart';

class RoundedCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const RoundedCupertinoPageTransitionsBuilder();

  static const CupertinoPageTransitionsBuilder _cupertino =
      CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _cupertino.transitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _cupertino.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Widget transition = _cupertino.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final double radius = devicePixelRatio > 0
        ? DisplayGeometry.physicalCornerRadius / devicePixelRatio
        : 0;
    if (radius <= 0) return transition;

    return AnimatedBuilder(
      animation: animation,
      child: transition,
      builder: (context, child) {
        final double value = animation.value.clamp(0.0, 1.0);
        final double factor = 1 - Curves.easeInCubic.transform(value);
        final double current = radius * factor;
        if (current < 0.5) return child!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(current),
          child: child,
        );
      },
    );
  }
}
