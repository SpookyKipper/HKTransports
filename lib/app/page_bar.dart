import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

PreferredSizeWidget buildPageBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  final TargetPlatform platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoNavigationBar(
      middle: Text(title),
      trailing: actions == null || actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.92),
      brightness: Theme.of(context).brightness,
    );
  }
  return AppBar(title: Text(title), actions: actions);
}
