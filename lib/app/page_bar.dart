import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

PreferredSizeWidget buildPageBar(
  BuildContext context, {
  required String title,
  Widget? titleTrailing,
  String? subtitle,
  Widget? subtitleWidget,
  List<Widget>? actions,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool hasPinnedStops = context
      .watch<PinnedStopsController>()
      .stations
      .isNotEmpty;
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

  final Widget titleWidget = titleTrailing == null
      ? Text(title, style: titleStyle)
      : Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: titleStyle),
            const SizedBox(width: 8),
            titleTrailing,
          ],
        );

  return M3EAppBar.top(
    title: titleWidget,
    subtitle:
        subtitleWidget ??
        (subtitle == null
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              )),
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
    safeArea: !hasPinnedStops,
    centerTitle: false,
    variant: M3EAppBarVariant.small,
    hideOnScroll: false,
    hideMode: M3EAppBarHideMode.none,
    backgroundColor: scheme.surface,
    foregroundColor: scheme.onSurface,
    elevation: 0,
  );
}
