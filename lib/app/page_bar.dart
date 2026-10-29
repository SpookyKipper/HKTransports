import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

PreferredSizeWidget buildPageBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool canPop = Navigator.of(context).canPop();
  return CupertinoNavigationBar(
    middle: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      overflow: TextOverflow.ellipsis,
    ),
    leading: canPop
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.maybePop(context),
            child: Icon(CupertinoIcons.back, color: scheme.onSurface),
          )
        : null,
    trailing: actions == null || actions.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: actions),
    backgroundColor: scheme.surface,
    border: null,
    brightness: Theme.of(context).brightness,
  );
}
