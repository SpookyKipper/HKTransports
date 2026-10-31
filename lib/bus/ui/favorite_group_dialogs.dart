import 'package:flutter/material.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

Future<String?> promptFavoriteGroupName(
  BuildContext context, {
  String? initial,
}) async {
  final AppSettings settings = context.read<AppSettings>();
  String value = initial ?? '';
  final TextEditingController controller = TextEditingController(
    text: initial ?? '',
  );
  final String? result = await M3EDialog.show<String>(
    context,
    autofocusFirst: false,
    dialog: M3EDialog(
      title: initial == null
          ? settings.text('新增群組', 'New group')
          : settings.text('重新命名群組', 'Rename group'),
      content: M3ETextField(
        controller: controller,
        label: settings.text('群組名稱', 'Group name'),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (text) => value = text,
        onSubmitted: (text) => Navigator.pop(context, text),
      ),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.pop(context),
          child: Text(settings.text('取消', 'Cancel')),
        ),
        M3EButton.text(
          onPressed: () => Navigator.pop(context, value),
          child: Text(settings.text('確定', 'OK')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
