import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/proprietary_settings_section.dart';
import 'package:hktransports/functions/app.dart';
import 'package:hktransports/location/location_controller.dart';
import 'package:hktransports/location/location_service.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _DropdownSetting<AppThemeChoice>(
            icon: Icons.brightness_6_outlined,
            title: settings.text('外觀', 'Appearance'),
            value: settings.themeChoice,
            items: [
              for (final AppThemeChoice choice in AppThemeChoice.values)
                M3EDropdownItem(
                  label: choice.label(settings.language),
                  value: choice,
                ),
            ],
            onChanged: settings.setThemeChoice,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_4_outlined),
            title: Text(settings.text('在深色模式下調暗地圖', 'Dim map in dark mode')),
            subtitle: Text(
              settings.text(
                '降低地圖亮度，減少夜間眩光',
                'Reduce map brightness for less glare at night',
              ),
            ),
            value: settings.dimMapInDarkMode,
            onChanged: settings.setDimMapInDarkMode,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.my_location_outlined),
            title: Text(settings.text('使用定位服務', 'Use location')),
            subtitle: Text(
              settings.text(
                '在「附近」分頁顯示附近的路線，需要精確定位權限。',
                'Show nearby routes in the Nearby tab. Precise location permission is required.',
              ),
            ),
            value: settings.locationEnabled,
            onChanged: (bool value) =>
                _setLocationEnabled(context, settings, value),
          ),
          _DropdownSetting<PageTransitionStyle>(
            icon: Icons.animation,
            title: settings.text('頁面轉場', 'Page transition'),
            value: settings.transitionStyle,
            items: [
              for (final PageTransitionStyle style
                  in PageTransitionStyle.values)
                M3EDropdownItem(
                  label: style.label(settings.language),
                  value: style,
                ),
            ],
            onChanged: settings.setTransitionStyle,
          ),
          _SliderSetting(
            icon: Icons.format_size,
            title: settings.text('文字大小', 'Text size'),
            footer: '${settings.textScalePercent}%',
            child: M3ESlider(
              min: 80,
              max: 160,
              divisions: 8,
              value: settings.textScalePercent.toDouble(),
              label: '${settings.textScalePercent}%',
              onChanged: (double value) {
                settings.setTextScalePercent(value.round());
              },
            ),
          ),
          _DropdownSetting<String>(
            icon: Icons.language,
            title: settings.text('語言', 'Language'),
            value: settings.language,
            items: const [
              M3EDropdownItem(label: '繁體中文', value: 'zh'),
              M3EDropdownItem(label: 'English', value: 'en'),
            ],
            onChanged: settings.setLanguage,
          ),
          _DropdownSetting<EtaFormat>(
            icon: Icons.schedule,
            title: settings.text('到站時間格式', 'ETA format'),
            value: settings.etaFormat,
            items: [
              for (final EtaFormat format in EtaFormat.values)
                M3EDropdownItem(
                  label: _etaFormatLabel(format, settings),
                  value: format,
                ),
            ],
            onChanged: settings.setEtaFormat,
          ),
          _SliderSetting(
            icon: Icons.refresh,
            title: settings.text('更新頻率', 'Refresh interval'),
            footer: '${settings.refreshSeconds}s',
            child: M3ESlider(
              min: 5,
              max: 60,
              divisions: 11,
              value: settings.refreshSeconds.toDouble().clamp(5, 60),
              label: '${settings.refreshSeconds}s',
              onChanged: (double value) {
                settings.setRefreshSeconds(value.round());
              },
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
            subtitle: Text(
              settings.text(
                '按下方間隔檢查更新',
                'Checks for updates at the interval below',
              ),
            ),
            value: settings.autoRenew,
            onChanged: settings.setAutoRenew,
          ),
          _DropdownSetting<int>(
            icon: Icons.timer_outlined,
            title: settings.text('更新間隔', 'Update interval'),
            value: settings.autoUpdateHours,
            enabled: settings.autoRenew,
            caption: _autoUpdateLabel(settings),
            items: [
              for (final int hours in const [6, 12, 24, 48, 72, 168])
                M3EDropdownItem(
                  label: settings.text('$hours 小時', '$hours hours'),
                  value: hours,
                ),
            ],
            onChanged: settings.setAutoUpdateHours,
          ),
          _DropdownSetting<AutoUpdateNetwork>(
            icon: Icons.wifi,
            title: settings.text('自動更新網絡', 'Auto-update network'),
            value: settings.autoUpdateNetwork,
            enabled: settings.autoRenew,
            caption: settings.text(
              '僅套用於自動更新',
              'Only applies to automatic updates',
            ),
            items: [
              for (final AutoUpdateNetwork network in AutoUpdateNetwork.values)
                M3EDropdownItem(
                  label: network.label(settings.language),
                  value: network,
                ),
            ],
            onChanged: settings.setAutoUpdateNetwork,
          ),
          const ProprietarySettingsSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(settings.text('管理收藏群組', 'Manage favourite groups')),
            subtitle: Text(settings.text('排序及編輯群組', 'Reorder and edit groups')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/favoriteGroups'),
          ),
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
          const Divider(),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: af.getVersionBuilder(
              builder: (String value) =>
                  Text('${settings.text('版本', 'Version')} $value [BETA]'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setLocationEnabled(
    BuildContext context,
    AppSettings settings,
    bool value,
  ) async {
    if (!value) {
      settings.setLocationEnabled(false);
      return;
    }
    settings.setLocationEnabled(true);
    final LocationAccessStatus status = await context
        .read<LocationController>()
        .requestAccess();
    if (!context.mounted) return;
    final String? message = switch (status) {
      LocationAccessStatus.granted || LocationAccessStatus.unsupported => null,
      LocationAccessStatus.serviceDisabled => settings.text(
        '請在系統設定中開啟定位服務。',
        'Turn on location services in system settings.',
      ),
      LocationAccessStatus.denied => settings.text(
        '定位權限未授予，可在「附近」分頁重試。',
        'Location permission was not granted. Retry from the Nearby tab.',
      ),
      LocationAccessStatus.deniedForever => settings.text(
        '定位權限已被永久拒絕，請在應用程式設定中允許。',
        'Location permission was permanently denied. Allow it in app settings.',
      ),
    };
    if (status == LocationAccessStatus.unsupported) {
      settings.setLocationEnabled(false);
    }
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _etaFormatLabel(EtaFormat format, AppSettings settings) {
    switch (format) {
      case EtaFormat.diff:
        return settings.text('到站時差', 'Minutes remaining');
      case EtaFormat.exact:
        return settings.text('到站時間', 'Clock time');
      case EtaFormat.mixed:
        return settings.text('到站時間 + 到站時差', 'Clock time + minutes remaining');
    }
  }

  String _autoUpdateLabel(AppSettings settings) {
    final int hours = settings.autoUpdateHours;
    return settings.text('上次更新後 $hours 小時', '$hours hours after last update');
  }
}

class _DropdownSetting<T> extends StatefulWidget {
  const _DropdownSetting({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.caption,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<M3EDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final String? caption;
  final bool enabled;

  @override
  State<_DropdownSetting<T>> createState() => _DropdownSettingState<T>();
}

class _DropdownSettingState<T> extends State<_DropdownSetting<T>> {
  late final M3EDropdownController<T> _controller;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _controller = M3EDropdownController<T>();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSelection(List<M3EDropdownItem<T>> selection) {
    if (_restoring) return;
    if (selection.isEmpty) {
      _restoring = true;
      _controller.selectWhere((item) => item.value == widget.value);
      _restoring = false;
      return;
    }
    final T next = selection.first.value;
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          M3EDropdownMenu<T>(
            controller: _controller,
            showChipAnimation: false,
            itemStyle: M3EDropdownItemStyle(
              outerRadius: 20,
              backgroundColor: Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.surfaceContainerLow
                  : null,
            ),
            items: [
              for (final M3EDropdownItem<T> item in widget.items)
                item.copyWith(selected: item.value == widget.value),
            ],
            singleSelect: true,
            enabled: widget.enabled,
            onSelectionChanged: _handleSelection,
          ),
          if (widget.caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.caption!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.icon,
    required this.title,
    required this.child,
    this.footer,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          child,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                footer!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
