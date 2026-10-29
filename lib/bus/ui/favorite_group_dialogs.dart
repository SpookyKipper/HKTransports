import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

Future<String?> promptFavoriteGroupName(
  BuildContext context, {
  String? initial,
}) async {
  final AppSettings settings = context.read<AppSettings>();
  final TextEditingController controller = TextEditingController(
    text: initial ?? '',
  );
  final String? result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          initial == null
              ? settings.text('新增群組', 'New group')
              : settings.text('重新命名群組', 'Rename group'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: settings.text('群組名稱', 'Group name'),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(settings.text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(settings.text('確定', 'OK')),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
