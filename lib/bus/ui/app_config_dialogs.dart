import 'package:flutter/material.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/app/app_update.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

Future<void> showDisabledProprietaryApisDialog(
  BuildContext context,
  List<ProprietaryEndpoint> endpoints, {
  List<SpecialFeature> features = const <SpecialFeature>[],
}) {
  if (endpoints.isEmpty && features.isEmpty) return Future<void>.value();
  final AppSettings settings = context.read<AppSettings>();
  return _showPrimaryDialog(
    context,
    title: features.isEmpty
        ? settings.text('專有 API 已停用', 'Proprietary APIs disabled')
        : settings.text('部分功能已停用', 'Some features disabled'),
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (endpoints.isNotEmpty) ...[
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
        if (features.isNotEmpty) ...[
          if (endpoints.isNotEmpty) const SizedBox(height: 12),
          Text(
            settings.text(
              '以下功能已不再受此版本支援，並已自動停用：',
              'The following features are no longer supported by this app version and have been disabled:',
            ),
          ),
          const SizedBox(height: 10),
          for (final SpecialFeature feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${feature.label(settings)}'),
            ),
        ],
      ],
    ),
  );
}

Future<void> showFeatureAvailabilityDialog(
  BuildContext context,
  SpecialFeature feature,
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
    showUpdateAction: updateRequired,
    content: Text(
      updateRequired
          ? settings.text(
              '${feature.label(settings)}需要較新版本的 HKTransports。請更新應用程式後再啟用。',
              '${feature.label(settings)} requires a newer version of HKTransports. Please update the app before enabling it.',
            )
          : settings.text(
              '${feature.label(settings)}目前無法使用。',
              '${feature.label(settings)} is currently unavailable.',
            ),
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
    showUpdateAction: updateRequired,
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
  bool showUpdateAction = false,
}) async {
  final AppSettings settings = context.read<AppSettings>();
  await M3EDialog.show<void>(
    context,
    barrierDismissible: barrierDismissible,
    dialog: Builder(
      builder: (BuildContext dialogContext) {
        return M3EDialog(
          title: title,
          icon: const Icon(Icons.info_outline),
          content: content,
          actions: <Widget>[
            M3EButton.text(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(settings.text('確定', 'OK')),
            ),
            if (showUpdateAction)
              M3EButton.filled(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  startAppUpdate(context, context.read<AppConfigController>());
                },
                child: Text(settings.text('更新', 'Update')),
              ),
          ],
        );
      },
    ),
  );
}
