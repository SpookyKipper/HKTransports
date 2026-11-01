import 'package:flutter/material.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/bus/state/app_settings.dart';

/// Allows the current route to fade out in place when another route is pushed.
abstract interface class FadeOutOnNextPush {
  void prepareFadeOut();
}

Widget buildFadeOutTransition(
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<double> opacity = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic),
  );
  return FadeTransition(opacity: opacity, child: child);
}

/// Makes the current route fade out in place instead of using its configured
/// page transition when the next route is pushed.
void fadeCurrentRouteOut(BuildContext context) {
  final ModalRoute<dynamic>? route = ModalRoute.of(context);
  if (route is FadeOutOnNextPush) {
    (route as FadeOutOnNextPush).prepareFadeOut();
  }
}

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

class _AppTransitionRoute<T> extends PageRoute<T> implements FadeOutOnNextPush {
  _AppTransitionRoute(AppTransitionPage<T> page) : super(settings: page);

  AppTransitionPage<T> get _page => settings as AppTransitionPage<T>;

  PageTransitionsBuilder get _builder => transitionBuilderFor(_page.style);
  bool _fadeOutOnNextPush = false;

  @override
  void prepareFadeOut() {
    _fadeOutOnNextPush = true;
  }

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
    if (_fadeOutOnNextPush) {
      return buildFadeOutTransition(secondaryAnimation, child);
    }
    return _builder.buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
