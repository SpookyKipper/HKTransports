import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

Future<String?> promptFavoriteGroupName(
  BuildContext context, {
  String? initial,
}) async {
  final AppSettings settings = context.read<AppSettings>();
  String value = initial ?? '';
  final String? result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          initial == null
              ? settings.text('新增群組', 'New group')
              : settings.text('重新命名群組', 'Rename group'),
        ),
        content: TextFormField(
          initialValue: initial ?? '',
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: settings.text('群組名稱', 'Group name'),
          ),
          onChanged: (text) => value = text,
          onFieldSubmitted: (text) => Navigator.pop(context, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(settings.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, value),
            child: Text(settings.text('確定', 'OK')),
          ),
        ],
      );
    },
  );
  return result;
}
