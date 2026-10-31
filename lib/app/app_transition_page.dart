import 'package:flutter/material.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/bus/state/app_settings.dart';

class AppTransitionPage<T> extends Page<T> {
  const AppTransitionPage({
    required this.child,
    required this.style,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final PageTransitionStyle style;

  @override
  Route<T> createRoute(BuildContext context) {
    return _AppTransitionRoute<T>(this);
  }
}

class _AppTransitionRoute<T> extends PageRoute<T> {
  _AppTransitionRoute(AppTransitionPage<T> page) : super(settings: page);

  AppTransitionPage<T> get _page => settings as AppTransitionPage<T>;

  PageTransitionsBuilder get _builder => transitionBuilderFor(_page.style);

  @override
  Duration get transitionDuration => _builder.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _builder.reverseTransitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => false;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _page.child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _builder.buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
