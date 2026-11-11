import 'package:flutter/material.dart';
import 'package:hktransports/app/app_config.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/app_config_dialogs.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class ProprietarySettingsSection extends StatelessWidget {
  const ProprietarySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card.filled(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      settings.text(
                        '這些來源未獲完整授權。啟用任何來源均可能違反使用條款或授權。你需自行承擔所有風險。所有請求均由你的裝置直接發出。',
                        'These sources are not fully licensed. Enabling any source may violate terms of use or licenses. You bear all risk. Requests are made directly from your device.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final ProprietaryGroup group in ProprietaryGroup.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Text(
                group.label(settings),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final ProprietaryEndpoint endpoint
                in ProprietaryEndpoint.values.where(
                  (ProprietaryEndpoint value) => value.group == group,
                ))
              _EndpointTile(endpoint: endpoint),
          ],
        ],
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({required this.endpoint});

  final ProprietaryEndpoint endpoint;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(_icon(endpoint)),
      title: Text(endpoint.label(settings)),
      subtitle: Text(endpoint.description(settings)),
      value: settings.isProprietaryEnabled(endpoint),
      onChanged: (bool value) => _setEndpoint(context, settings, value),
    );
  }

  Future<void> _setEndpoint(
    BuildContext context,
    AppSettings settings,
    bool value,
  ) async {
    if (value) {
      final ProprietaryAvailability availability = context
          .read<AppConfigController>()
          .availabilityFor(endpoint);
      if (availability != ProprietaryAvailability.supported) {
        await showProprietaryAvailabilityDialog(
          context,
          endpoint,
          availability,
        );
        return;
      }
    }
    settings.setProprietaryEndpoint(endpoint, value);
    if (endpoint == ProprietaryEndpoint.kmbInterchange) {
      if (!value) {
        await const BbiService().clearCache();
        return;
      }
      if (await const BbiService().storedBytes() > 0) return;
      if (!context.mounted) return;
      final bool? downloaded = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) =>
            const _KmbInterchangeDownloadDialog(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded == true
                ? settings.text(
                    '九巴/龍運轉乘資料已下載',
                    'KMB/LWB interchange data downloaded',
                  )
                : settings.text(
                    '九巴/龍運轉乘資料下載失敗，可在「更新資料」重試',
                    'KMB/LWB interchange data download failed. Retry in Update data.',
                  ),
          ),
        ),
      );
      return;
    }
    if (endpoint != ProprietaryEndpoint.citybusDatabase) return;

    if (!value) {
      await CitybusRoutelistService.instance.delete();
      return;
    }
    if (await CitybusRoutelistService.instance.isDownloaded) return;
    if (!context.mounted) return;
    final bool? downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const _CitybusDownloadDialog(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded == true
              ? settings.text(
                  '城巴專有路線資料已下載',
                  'Citybus proprietary route data downloaded',
                )
              : settings.text(
                  '城巴專有路線資料下載失敗，可在「更新資料」重試',
                  'Citybus proprietary data download failed. Retry in Update data.',
                ),
        ),
      ),
    );
  }

  IconData _icon(ProprietaryEndpoint endpoint) {
    switch (endpoint) {
      case ProprietaryEndpoint.noticeFeed:
        return Icons.notifications_active_outlined;
      case ProprietaryEndpoint.kmbAnnouncements:
        return Icons.campaign_outlined;
      case ProprietaryEndpoint.kmbInterchange:
        return Icons.alt_route;
      case ProprietaryEndpoint.citybusSpecialNotices:
        return Icons.campaign_outlined;
      case ProprietaryEndpoint.citybusRouteNotices:
        return Icons.notifications_outlined;
      case ProprietaryEndpoint.citybusStopNotices:
        return Icons.signpost_outlined;
      case ProprietaryEndpoint.citybusRemarks:
        return Icons.notes_outlined;
      case ProprietaryEndpoint.citybusInterchange:
        return Icons.alt_route;
      case ProprietaryEndpoint.citybusDatabase:
        return Icons.storage_outlined;
      case ProprietaryEndpoint.citybusEtaStatus:
        return Icons.schedule_outlined;
    }
  }
}

class _KmbInterchangeDownloadDialog extends StatefulWidget {
  const _KmbInterchangeDownloadDialog();

  @override
  State<_KmbInterchangeDownloadDialog> createState() =>
      _KmbInterchangeDownloadDialogState();
}

class _KmbInterchangeDownloadDialogState
    extends State<_KmbInterchangeDownloadDialog> {
  int _completed = 0;
  int _total = 4;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    bool success = false;
    try {
      final AppSettings settings = context.read<AppSettings>();
      success = await const BbiService().refreshAll(
        zh: settings.isChinese,
        onProgress: (int completed, int total) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final double value = _total == 0 ? 0 : _completed / _total;
    return AlertDialog(
      title: Text(
        settings.text('下載九巴/龍運轉乘資料', 'Downloading KMB/LWB interchange data'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animated, Widget? child) {
              return M3EProgressIndicator.linearWavy(
                value: animated,
                linearSize: M3EProgressIndicatorSize.m,
                strokeWidth: 4,
                trackStrokeWidth: 4,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '$_completed / $_total · ${settings.text('約 61 MB', 'approx. 61 MB')}',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CitybusDownloadDialog extends StatefulWidget {
  const _CitybusDownloadDialog();

  @override
  State<_CitybusDownloadDialog> createState() => _CitybusDownloadDialogState();
}

class _CitybusDownloadDialogState extends State<_CitybusDownloadDialog> {
  double? _progress;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    bool success = false;
    try {
      await CitybusRoutelistService.instance.ensureDownloaded(
        force: true,
        onProgress: (double? progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      success = true;
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final int percent = ((_progress ?? 0) * 100).round().clamp(0, 100);
    return AlertDialog(
      title: Text(settings.text('下載城巴專有資料', 'Downloading Citybus data')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3EProgressIndicator.linearWavy(
            value: _progress,
            linearSize: M3EProgressIndicatorSize.m,
            strokeWidth: 4,
            trackStrokeWidth: 4,
          ),
          const SizedBox(height: 12),
          Text(
            _progress == null
                ? settings.text('正在連線…', 'Connecting…')
                : '$percent%',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
