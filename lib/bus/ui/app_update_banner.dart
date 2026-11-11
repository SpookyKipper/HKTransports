import 'package:flutter/material.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/app/app_update.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final AppConfigController config = context.watch<AppConfigController>();
    if (!config.hasUpdate || config.isCritical) {
      return const SizedBox.shrink();
    }
    final AppSettings settings = context.watch<AppSettings>();
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.primaryContainer,
      child: ListTile(
        iconColor: colors.onPrimaryContainer,
        textColor: colors.onPrimaryContainer,
        onTap: openAppUpdatePage,
        leading: const Icon(Icons.system_update_alt_rounded),
        title: Text(settings.text('有新版本', 'Update available')),
        subtitle: Text(
          settings.text(
            '請更新 HKTransports 以獲取最新功能。',
            'Please update HKTransports to get the latest features.',
          ),
        ),
      ),
    );
  }
}
