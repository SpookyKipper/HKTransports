import 'package:flutter/material.dart';

/// A page that fades in, but uses the user's chosen transition when popped.
///
/// Used when swapping a route's direction: the new direction fades in, while
/// going back still follows the page-transition setting.
class FadeForwardPage<T> extends Page<T> {
  const FadeForwardPage({
    required this.child,
    required this.reverseBuilder,
    super.key,
  });

  final Widget child;
  final PageTransitionsBuilder reverseBuilder;

  @override
  Route<T> createRoute(BuildContext context) => _FadeForwardPageRoute<T>(this);
}

class _FadeForwardPageRoute<T> extends PageRoute<T> {
  _FadeForwardPageRoute(FadeForwardPage<T> page) : super(settings: page);

  FadeForwardPage<T> get _page => settings as FadeForwardPage<T>;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration =>
      _page.reverseBuilder.transitionDuration;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (animation.status == AnimationStatus.forward) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _page.reverseBuilder.buildTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
