import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
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
      appBar: buildPageBar(context, title: settings.text('設定', 'Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(settings.text('外觀', 'Appearance')),
            subtitle: Text(settings.themeChoice.label(settings.language)),
            onTap: () => _pickThemeChoice(context, settings),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(settings.text('文字大小', 'Text size')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  min: 80,
                  max: 160,
                  divisions: 8,
                  value: settings.textScalePercent.toDouble(),
                  label: '${settings.textScalePercent}%',
                  onChanged: (double value) {
                    settings.setTextScalePercent(value.round());
                  },
                ),
                Text('${settings.textScalePercent}%'),
              ],
            ),
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

  Future<void> _pickThemeChoice(
    BuildContext context,
    AppSettings settings,
  ) async {
    final AppThemeChoice? result = await showDialog<AppThemeChoice>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(settings.text('外觀', 'Appearance')),
          children: [
            RadioGroup<AppThemeChoice>(
              groupValue: settings.themeChoice,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final AppThemeChoice choice in AppThemeChoice.values)
                    RadioListTile<AppThemeChoice>(
                      value: choice,
                      title: Text(choice.label(settings.language)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (result != null) {
      settings.setThemeChoice(result);
    }
  }

  Future<void> _pickLanguage(BuildContext context, AppSettings settings) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(settings.text('語言', 'Language')),
          children: [
            RadioGroup<String>(
              groupValue: settings.language,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(value: 'zh', title: const Text('繁體中文')),
                  RadioListTile<String>(
                    value: 'en',
                    title: const Text('English'),
                  ),
                ],
              ),
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
            RadioGroup<EtaFormat>(
              groupValue: settings.etaFormat,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<EtaFormat>(
                    value: EtaFormat.mixed,
                    title: Text(
                      settings.text(
                        '到站時間（到站時差）',
                        'Clock time (minutes remaining)',
                      ),
                    ),
                  ),
                  RadioListTile<EtaFormat>(
                    value: EtaFormat.exact,
                    title: Text(settings.text('到站時間', 'Clock time')),
                  ),
                  RadioListTile<EtaFormat>(
                    value: EtaFormat.diff,
                    title: Text(settings.text('到站時差', 'Minutes remaining')),
                  ),
                ],
              ),
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
