import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

PreferredSizeWidget buildPageBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final TextStyle titleStyle =
      Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(color: scheme.onSurface) ??
      TextStyle(color: scheme.onSurface, fontSize: 24);
  final TextStyle subtitleStyle =
      Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant) ??
      TextStyle(color: scheme.onSurfaceVariant);

  return M3EAppBar.top(
    title: Text(title, style: titleStyle),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
    actions: actions,
    leading: Navigator.of(context).canPop()
        ? M3EIconButton(
            icon: const BackButtonIcon(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            variant: M3EIconButtonVariant.standard,
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,
    automaticallyImplyLeading: false,
    centerTitle: false,
    variant: M3EAppBarVariant.small,
    hideOnScroll: false,
    hideMode: M3EAppBarHideMode.none,
    backgroundColor: scheme.surface,
    foregroundColor: scheme.onSurface,
    elevation: 0,
  );
}
