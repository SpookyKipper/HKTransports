import 'package:flutter/material.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/app/app_update.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class AppConfigGate extends StatelessWidget {
  const AppConfigGate({super.key, required this.config, required this.child});

  final AppConfigController config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (config.isCritical) return const CriticalUpdateScreen();
    return child;
  }
}

class CriticalUpdateScreen extends StatelessWidget {
  const CriticalUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.primaryContainer,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 72,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 24),
                Text(
                  settings.text('需要更新', 'Update required'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  settings.text(
                    '此版本的 HKTransports 已無法繼續使用。請更新應用程式後再開啟。',
                    'This version of HKTransports can no longer be used. Please update the app to continue.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: openAppUpdatePage,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(settings.text('更新', 'Update')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
