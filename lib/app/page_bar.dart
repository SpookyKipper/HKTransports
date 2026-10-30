import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

PreferredSizeWidget buildPageBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return M3EAppBar.top(
    titleText: title,
    subtitleText: subtitle,
    actions: actions,
    leading: Navigator.of(context).canPop() ? const BackButton() : null,
    automaticallyImplyLeading: false,
    centerTitle: false,
    variant: M3EAppBarVariant.mediumFlexible,
    hideOnScroll: false,
    hideMode: M3EAppBarHideMode.none,
    backgroundColor: scheme.surface,
    foregroundColor: scheme.onSurface,
    elevation: 0,
  );
}
