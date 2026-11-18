import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide appFlavor;
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/app/app_update.dart';
import 'package:hktransports/app/app_version.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _checking = false;

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    final AppConfigController controller = context.read<AppConfigController>();
    setState(() => _checking = true);
    await controller.refresh();
    if (!mounted) return;
    setState(() => _checking = false);
    if (controller.hasUpdate) {
      await startAppUpdate(context, controller);
      return;
    }
    final AppSettings settings = context.read<AppSettings>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          settings.text('你已使用最新版本。', 'You are on the latest version.'),
        ),
      ),
    );
  }

  Future<void> _copyVersionInfo() async {
    await Clipboard.setData(ClipboardData(text: appVersionInfoText));
    if (!mounted) return;
    final AppSettings settings = context.read<AppSettings>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(settings.text('版本資訊已複製。', 'Version info copied.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final AppConfigController config = context.watch<AppConfigController>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String updateLabel = config.hasUpdate && config.config != null
        ? settings.text(
            '更新至 ${config.config!.latestVersionName}',
            'Update to ${config.config!.latestVersionName}',
          )
        : settings.text('檢查更新', 'Check for update');

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('關於應用程式', 'About App'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'HKTransports',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${settings.text('版本', 'Version')} $appVersion ($appBuildLabel) [BETA]',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${settings.text('版本渠道', 'Flavor')}: $appFlavor',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          M3EButton.filled(
            onPressed: _checking ? null : _checkForUpdate,
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt_rounded),
            label: Text(updateLabel),
          ),
          const SizedBox(height: 12),
          M3EButton.outlined(
            onPressed: _copyVersionInfo,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(settings.text('複製版本資訊', 'Copy version info')),
          ),
        ],
      ),
    );
  }
}
