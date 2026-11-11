import 'package:flutter/material.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

Future<void> showDisabledProprietaryApisDialog(
  BuildContext context,
  List<ProprietaryEndpoint> endpoints,
) {
  if (endpoints.isEmpty) return Future<void>.value();
  final AppSettings settings = context.read<AppSettings>();
  return _showPrimaryDialog(
    context,
    title: settings.text('專有 API 已停用', 'Proprietary APIs disabled'),
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settings.text(
            '以下專有 API 已不再受此版本支援，並已自動停用：',
            'The following proprietary APIs are no longer supported by this app version and have been disabled:',
          ),
        ),
        const SizedBox(height: 10),
        for (final ProprietaryEndpoint endpoint in endpoints)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${endpoint.label(settings)}'),
          ),
      ],
    ),
  );
}

Future<void> showProprietaryAvailabilityDialog(
  BuildContext context,
  ProprietaryEndpoint endpoint,
  ProprietaryAvailability availability,
) {
  if (availability == ProprietaryAvailability.supported) {
    return Future<void>.value();
  }
  final AppSettings settings = context.read<AppSettings>();
  final bool updateRequired =
      availability == ProprietaryAvailability.updateRequired;
  return _showPrimaryDialog(
    context,
    title: updateRequired
        ? settings.text('需要更新', 'Update required')
        : settings.text('目前無法使用', 'Currently unavailable'),
    content: Text(
      updateRequired
          ? settings.text(
              '此專有 API 需要較新版本的 HKTransports。請更新應用程式後再啟用。',
              'This proprietary API requires a newer version of HKTransports. Please update the app before enabling it.',
            )
          : settings.text(
              '此專有 API 目前無法使用。',
              'This proprietary API is currently unavailable.',
            ),
    ),
  );
}

Future<void> _showPrimaryDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  bool barrierDismissible = true,
}) async {
  final AppSettings settings = context.read<AppSettings>();
  final ColorScheme colors = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: colors.primaryContainer,
        icon: Icon(Icons.info_outline, color: colors.onPrimaryContainer),
        title: Text(title, style: TextStyle(color: colors.onPrimaryContainer)),
        content: DefaultTextStyle.merge(
          style: TextStyle(color: colors.onPrimaryContainer),
          child: content,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: colors.onPrimaryContainer,
            ),
            child: Text(settings.text('確定', 'OK')),
          ),
        ],
      );
    },
  );
}
