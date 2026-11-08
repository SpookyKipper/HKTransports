import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class ProprietaryDataPage extends StatelessWidget {
  const ProprietaryDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('專有資料', 'Proprietary data'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          M3ECard(
            variant: M3ECardVariant.filled,
            color: scheme.errorContainer,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.text('自行承擔風險', 'Use at your own risk'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        settings.text(
                          '這些來源未獲完整授權。啟用任何來源均可能違反使用條款或授權。你需自行承擔所有風險。這些來源的所有請求均由你的裝置直接發出，不經代理伺服器。',
                          'These sources are not fully licensed. Enabling any source may violate terms of use or licenses. You bear all risk. All requests for these sources are made directly from your device; no proxy server is used.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            settings.text('資料來源', 'Sources'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            settings.text(
              '可選多項。預設不啟用任何來源。',
              'Select any combination. Nothing is enabled by default.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          M3EList(
            variant: M3ECardVariant.filled,
            itemCount: ProprietaryDataSource.values.length,
            onTap: (int index) {
              final ProprietaryDataSource source =
                  ProprietaryDataSource.values[index];
              _setProprietarySource(
                context,
                settings,
                source,
                !settings.isProprietaryEnabled(source),
              );
            },
            itemBuilder: (BuildContext context, int index) {
              final ProprietaryDataSource source =
                  ProprietaryDataSource.values[index];
              final bool enabled = settings.isProprietaryEnabled(source);
              return M3EListItem(
                headline: source.label(settings),
                supportingText: source.description(settings),
                trailing: ExcludeFocus(
                  child: IgnorePointer(
                    child: M3ECheckbox(
                      value: enabled,
                      onChanged: (bool? value) {
                        if (value != null) {
                          _setProprietarySource(
                            context,
                            settings,
                            source,
                            value,
                          );
                        }
                      },
                      focusable: false,
                      semanticLabel: source.label(settings),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setProprietarySource(
    BuildContext context,
    AppSettings settings,
    ProprietaryDataSource source,
    bool value,
  ) async {
    settings.setProprietarySource(source, value);
    if (!value && source == ProprietaryDataSource.kmb) {
      await const BbiService().clearCache();
    }
    if (source == ProprietaryDataSource.citybus) {
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
  }
}

class _CitybusDownloadDialog extends StatefulWidget {
  const _CitybusDownloadDialog();

  @override
  State<_CitybusDownloadDialog> createState() => _CitybusDownloadDialogState();
}

class _CitybusDownloadDialogState extends State<_CitybusDownloadDialog> {
  double? _progress;
  bool _finished = false;

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
    setState(() => _finished = true);
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
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 12),
          Text(
            _finished
                ? settings.text('完成', 'Finished')
                : _progress == null
                ? settings.text('正在連線…', 'Connecting…')
                : '$percent%',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
