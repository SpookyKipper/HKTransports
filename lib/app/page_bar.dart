import 'package:flutter/material.dart';

PreferredSizeWidget buildPageBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    actions: actions,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}
