import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class SettingsPageRoute extends StatelessWidget {
  const SettingsPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SettingsPage());
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: Text(settings.text('設定', 'Settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(settings.text('外觀', 'Appearance')),
            subtitle: Text(_themeModeLabel(settings)),
            onTap: () => _pickThemeMode(context, settings),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(settings.text('語言', 'Language')),
            subtitle: Text(settings.isChinese ? '繁體中文' : 'English'),
            onTap: () => _pickLanguage(context, settings),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(settings.text('到站時間格式', 'ETA format')),
            subtitle: Text(_etaFormatLabel(settings)),
            onTap: () => _pickEtaFormat(context, settings),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(settings.text('更新頻率', 'Refresh interval')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  min: 5,
                  max: 60,
                  divisions: 11,
                  value: settings.refreshSeconds.toDouble().clamp(5, 60),
                  label: '${settings.refreshSeconds}s',
                  onChanged: (double value) {
                    settings.setRefreshSeconds(value.round());
                  },
                ),
                Text('${settings.refreshSeconds}s'),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.filter_alt_outlined),
            title: Text(
              settings.text('只顯示現時服務的路線', 'Only show routes running now'),
            ),
            value: settings.routeFilter,
            onChanged: settings.setRouteFilter,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync),
            title: Text(settings.text('自動更新路線資料', 'Auto update route data')),
            subtitle: Text(settings.text('每七日檢查一次', 'Check every seven days')),
            value: settings.autoRenew,
            onChanged: settings.setAutoRenew,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(settings.text('路線及車站資料', 'Route and stop data')),
            subtitle: Text(
              settings.text('下載、更新或重新整理', 'Download, update or refresh'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/updateData'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(settings.text('鳴謝', 'Credits')),
            subtitle: Text(
              settings.text('資料來源與開源項目', 'Data sources and open source'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/credits'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(settings.text('開源授權', 'Open source licenses')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'HKTransports',
                applicationLegalese:
                    'Data from DATA.GOV.HK and HK Bus Crawling.',
              );
            },
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(AppSettings settings) {
    switch (settings.themeMode) {
      case ThemeMode.light:
        return settings.text('淺色', 'Light');
      case ThemeMode.dark:
        return settings.text('深色', 'Dark');
      case ThemeMode.system:
        return settings.text('跟隨系統', 'System');
    }
  }

  String _etaFormatLabel(AppSettings settings) {
    switch (settings.etaFormat) {
      case EtaFormat.diff:
        return settings.text('到站時差', 'Minutes remaining');
      case EtaFormat.exact:
        return settings.text('到站時間', 'Clock time');
      case EtaFormat.mixed:
        return settings.text('到站時間（到站時差）', 'Clock time (minutes remaining)');
    }
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    AppSettings settings,
  ) async {
    final ThemeMode? result = await showDialog<ThemeMode>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(settings.text('外觀', 'Appearance')),
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              title: Text(settings.text('跟隨系統', 'System')),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              title: Text(settings.text('淺色', 'Light')),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              title: Text(settings.text('深色', 'Dark')),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        );
      },
    );
    if (result != null) {
      settings.setThemeMode(result);
    }
  }

  Future<void> _pickLanguage(BuildContext context, AppSettings settings) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(settings.text('語言', 'Language')),
          children: [
            RadioListTile<String>(
              value: 'zh',
              groupValue: settings.language,
              title: const Text('繁體中文'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: settings.language,
              title: const Text('English'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        );
      },
    );
    if (result != null) {
      settings.setLanguage(result);
    }
  }

  Future<void> _pickEtaFormat(
    BuildContext context,
    AppSettings settings,
  ) async {
    final EtaFormat? result = await showDialog<EtaFormat>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(settings.text('到站時間格式', 'ETA format')),
          children: [
            RadioListTile<EtaFormat>(
              value: EtaFormat.mixed,
              groupValue: settings.etaFormat,
              title: Text(
                settings.text('到站時間（到站時差）', 'Clock time (minutes remaining)'),
              ),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<EtaFormat>(
              value: EtaFormat.exact,
              groupValue: settings.etaFormat,
              title: Text(settings.text('到站時間', 'Clock time')),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<EtaFormat>(
              value: EtaFormat.diff,
              groupValue: settings.etaFormat,
              title: Text(settings.text('到站時差', 'Minutes remaining')),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        );
      },
    );
    if (result != null) {
      settings.setEtaFormat(result);
    }
  }
}
