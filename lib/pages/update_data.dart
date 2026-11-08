import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class UpdateDataPageRoute extends StatefulWidget {
  const UpdateDataPageRoute({super.key});

  @override
  State<UpdateDataPageRoute> createState() => _UpdateDataPageRouteState();
}

class _UpdateDataPageRouteState extends State<UpdateDataPageRoute> {
  bool _refreshingBbi = false;
  int _bbiCompleted = 0;
  int _bbiTotal = 4;
  int? _routeBytes;
  int? _kmbBytes;
  DateTime? _kmbUpdatedAt;
  int? _citybusBytes;
  DateTime? _citybusUpdatedAt;
  bool _refreshingCitybus = false;
  double? _citybusProgress;
  String? _citybusError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSizes());
  }

  Future<void> _loadSizes() async {
    final BusRepository repository = context.read<BusRepository>();
    final int routeBytes = await repository.updater.dataSizeBytes();
    final BbiService bbi = const BbiService();
    final int kmbBytes = await bbi.storedBytes();
    final DateTime? kmbUpdatedAt = await bbi.storedUpdatedAt();
    final CitybusRoutelistService citybus = CitybusRoutelistService.instance;
    final int citybusBytes = await citybus.storedBytes();
    final DateTime? citybusUpdatedAt = citybus.storedUpdatedAt;
    if (!mounted) return;
    setState(() {
      _routeBytes = routeBytes;
      _kmbBytes = kmbBytes;
      _kmbUpdatedAt = kmbUpdatedAt;
      _citybusBytes = citybusBytes;
      _citybusUpdatedAt = citybusUpdatedAt;
    });
  }

  Future<void> _runUpdate({
    required bool force,
    required bool downloadAgain,
  }) async {
    final AppSettings settings = context.read<AppSettings>();
    final BusRepository repository = context.read<BusRepository>();
    final bool updated = await repository.update(force: force);
    if (!mounted) return;
    if (!updated) {
      final bool failed = repository.error != null;
      _showMessage(
        downloadAgain || failed
            ? settings.text('下載失敗', 'Download failed')
            : settings.text('資料已是最新', 'Data is up to date'),
      );
      return;
    }

    final AppSettings latestSettings = context.read<AppSettings>();
    if (downloadAgain ||
        !latestSettings.isProprietaryEnabled(ProprietaryDataSource.kmb)) {
      await _loadSizes();
      if (!mounted) return;
      _showMessage(
        downloadAgain
            ? latestSettings.text('資料已重新下載', 'Data downloaded')
            : latestSettings.text('資料已更新', 'Data updated'),
      );
      return;
    }

    setState(() {
      _refreshingBbi = true;
      _bbiCompleted = 0;
      _bbiTotal = 4;
    });
    bool refreshed = false;
    try {
      refreshed = await const BbiService().refreshAll(
        zh: latestSettings.isChinese,
        onProgress: (int completed, int total) {
          if (!mounted) return;
          setState(() {
            _bbiCompleted = completed;
            _bbiTotal = total;
          });
        },
      );
    } catch (_) {
      refreshed = false;
    }
    if (!mounted) return;
    setState(() => _refreshingBbi = false);
    await _loadSizes();
    if (!mounted) return;
    _showMessage(
      refreshed
          ? latestSettings.text(
              '路線及轉乘資料已更新',
              'Route and interchange data updated',
            )
          : latestSettings.text(
              '路線資料已更新，但轉乘資料更新失敗',
              'Route data updated, but interchange data refresh failed',
            ),
    );
  }

  Future<void> _refreshKmb() async {
    final AppSettings settings = context.read<AppSettings>();
    setState(() {
      _refreshingBbi = true;
      _bbiCompleted = 0;
      _bbiTotal = 4;
    });
    bool refreshed = false;
    try {
      refreshed = await const BbiService().refreshAll(
        zh: settings.isChinese,
        onProgress: (int completed, int total) {
          if (!mounted) return;
          setState(() {
            _bbiCompleted = completed;
            _bbiTotal = total;
          });
        },
      );
    } catch (_) {
      refreshed = false;
    }
    if (!mounted) return;
    setState(() => _refreshingBbi = false);
    await _loadSizes();
    if (!mounted) return;
    _showMessage(
      refreshed
          ? settings.text('九巴/龍運轉乘資料已更新', 'KMB/LWB interchange data updated')
          : settings.text('轉乘資料更新失敗', 'Interchange data update failed'),
    );
  }

  Future<void> _deleteKmb() async {
    final AppSettings settings = context.read<AppSettings>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            settings.text('刪除九巴/龍運轉乘資料', 'Delete KMB/LWB interchange data'),
          ),
          content: Text(
            settings.text(
              '這些是非必要資料，下次使用時會重新下載。',
              'This is optional data and will be downloaded again when needed.',
            ),
          ),
          actions: [
            M3EButton.text(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(settings.text('取消', 'Cancel')),
            ),
            M3EButton.text(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(settings.text('刪除', 'Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await const BbiService().clearCache();
    await _loadSizes();
    if (!mounted) return;
    _showMessage(settings.text('九巴轉乘資料已刪除', 'KMB interchange data deleted'));
  }

  Future<void> _downloadCitybus({required bool force}) async {
    final AppSettings settings = context.read<AppSettings>();
    setState(() {
      _refreshingCitybus = true;
      _citybusProgress = null;
      _citybusError = null;
    });
    try {
      await CitybusRoutelistService.instance.ensureDownloaded(
        force: force,
        onProgress: (double? progress) {
          if (!mounted) return;
          setState(() => _citybusProgress = progress);
        },
      );
      await _loadSizes();
      if (!mounted) return;
      _showMessage(
        settings.text('城巴專有路線資料已更新', 'Citybus proprietary route data updated'),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _citybusError = error.toString());
      _showMessage(settings.text('城巴專有資料下載失敗', 'Citybus data download failed'));
    } finally {
      if (mounted) setState(() => _refreshingCitybus = false);
    }
  }

  Future<void> _deleteCitybus() async {
    final AppSettings settings = context.read<AppSettings>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            settings.text('刪除城巴專有資料', 'Delete Citybus proprietary data'),
          ),
          content: Text(
            settings.text(
              '路線名稱、車站地標及車費數據會被刪除。你仍可保持城巴專有 API 啟用並重新下載。',
              'Route names, stop landmarks and fare data will be deleted. You can keep the Citybus proprietary API enabled and download it again.',
            ),
          ),
          actions: [
            M3EButton.text(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(settings.text('取消', 'Cancel')),
            ),
            M3EButton.text(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(settings.text('刪除', 'Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await CitybusRoutelistService.instance.delete();
    await _loadSizes();
    if (!mounted) return;
    _showMessage(
      settings.text('城巴專有資料已刪除', 'Citybus proprietary data deleted'),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _nextRefreshText(AppSettings settings, BusRepository repository) {
    if (!settings.autoRenew) {
      return settings.text('自動更新已停用', 'Automatic refresh is off');
    }
    DateTime? latest;
    void consider(DateTime? value) {
      if (value == null) return;
      if (latest == null || value.isAfter(latest!)) latest = value;
    }

    consider(repository.updater.lastUpdate);
    final int? checkSeconds = repository.updater.lastCheckSeconds;
    if (checkSeconds != null) {
      consider(DateTime.fromMillisecondsSinceEpoch(checkSeconds * 1000));
    }
    if (latest == null) {
      return settings.text('下載資料後安排', 'Scheduled after data download');
    }
    final DateTime due = latest!.add(Duration(hours: settings.autoUpdateHours));
    if (!due.isAfter(DateTime.now())) {
      return settings.text('即將更新', 'Due now');
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(due);
  }

  Widget _sizeText(
    BuildContext context,
    AppSettings settings,
    int? bytes, {
    bool optional = false,
  }) {
    final ThemeData theme = Theme.of(context);
    if (bytes == null) {
      return Text(
        '${settings.text('大小', 'Size')}: ...',
        style: theme.textTheme.bodySmall,
      );
    }
    if (bytes == 0) {
      return Text(
        settings.text('未下載', 'Not downloaded'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Text(
      '${settings.text('大小', 'Size')}: ${_formatBytes(bytes)}'
      '${optional ? ' · ${settings.text('可刪除', 'Can be deleted')}' : ''}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _progress(
    BuildContext context,
    AppSettings settings, {
    required bool route,
  }) {
    final BusRepository repository = context.read<BusRepository>();
    final double? value = route
        ? repository.progress
        : (_bbiTotal == 0 ? 0 : _bbiCompleted / _bbiTotal);
    final Widget progressBar = value == null
        ? const M3EProgressIndicator.linearWavy(
            value: null,
            linearSize: M3EProgressIndicatorSize.m,
            strokeWidth: 4,
            trackStrokeWidth: 4,
          )
        : TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: value.clamp(0.0, 1.0).toDouble(),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, animated, child) {
              return M3EProgressIndicator.linearWavy(
                value: animated,
                linearSize: M3EProgressIndicatorSize.m,
                strokeWidth: 4,
                trackStrokeWidth: 4,
              );
            },
          );
    return Column(
      children: [
        const SizedBox(height: 12),
        progressBar,
        const SizedBox(height: 8),
        Text(
          route
              ? (value == null
                    ? settings.text('正在下載', 'Downloading')
                    : '${(value * 100).round()}%')
              : settings.text(
                  '正在更新轉乘資料 $_bbiCompleted/$_bbiTotal',
                  'Updating interchange data $_bbiCompleted/$_bbiTotal',
                ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final bool routeBusy = repository.status == BusDataStatus.updating;
    final bool busy = routeBusy || _refreshingBbi || _refreshingCitybus;
    final bool kmbEnabled = settings.isProprietaryEnabled(
      ProprietaryDataSource.kmb,
    );
    final bool citybusEnabled = settings.isProprietaryEnabled(
      ProprietaryDataSource.citybus,
    );

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('更新資料', 'Update data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card.filled(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(settings.text('下次自動更新', 'Next automatic refresh')),
              subtitle: Text(_nextRefreshText(settings, repository)),
              trailing: Text(
                settings.text(
                  '每 ${settings.autoUpdateHours} 小時',
                  'Every ${settings.autoUpdateHours}h',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            settings.text('可下載資料', 'Downloadable data'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.text('路線資料', 'Route data'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    repository.hasData
                        ? '${repository.database!.routeCount} routes, '
                              '${repository.database!.stopCount} stops'
                        : settings.text('尚未下載', 'Not downloaded'),
                  ),
                  if (repository.lastUpdate != null)
                    Text(
                      '${settings.text('上次更新', 'Last update')}: '
                      '${DateFormat('yyyy-MM-dd HH:mm').format(repository.lastUpdate!)}',
                    ),
                  _sizeText(context, settings, _routeBytes),
                  if (routeBusy) _progress(context, settings, route: true),
                  if (repository.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      repository.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      M3EButton.icon(
                        onPressed: busy
                            ? null
                            : () => _runUpdate(
                                force: !repository.hasData,
                                downloadAgain: false,
                              ),
                        icon: const Icon(Icons.sync),
                        label: Text(
                          repository.hasData
                              ? settings.text('檢查更新', 'Check for updates')
                              : settings.text('下載路線資料', 'Download route data'),
                        ),
                      ),
                      M3EButton.icon(
                        style: M3EButtonStyle.text,
                        onPressed: busy
                            ? null
                            : () =>
                                  _runUpdate(force: true, downloadAgain: true),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(settings.text('重新下載', 'Download again')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (kmbEnabled) ...[
            const SizedBox(height: 16),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.text('九巴/龍運轉乘資料', 'KMB/LWB interchange data'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _sizeText(context, settings, _kmbBytes, optional: true),
                    if (_kmbUpdatedAt != null)
                      Text(
                        '${settings.text('上次更新', 'Last updated')}: '
                        '${DateFormat('yyyy-MM-dd HH:mm').format(_kmbUpdatedAt!)}',
                      ),
                    if (_refreshingBbi)
                      _progress(context, settings, route: false),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        M3EButton.icon(
                          onPressed: busy ? null : _refreshKmb,
                          icon: const Icon(Icons.sync),
                          label: Text(
                            (_kmbBytes ?? 0) > 0
                                ? settings.text(
                                    '更新轉乘資料',
                                    'Update interchange data',
                                  )
                                : settings.text(
                                    '下載轉乘資料',
                                    'Download interchange data',
                                  ),
                          ),
                        ),
                        M3EButton.icon(
                          style: M3EButtonStyle.text,
                          onPressed: busy || (_kmbBytes ?? 0) == 0
                              ? null
                              : _deleteKmb,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(settings.text('刪除', 'Delete')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (citybusEnabled) ...[
            const SizedBox(height: 16),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.text(
                        '城巴專有路線資料',
                        'Citybus proprietary route data',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.text(
                        '路線名稱、車站地標及車費',
                        'Route names, stop landmarks and fares',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sizeText(context, settings, _citybusBytes, optional: true),
                    if (_citybusUpdatedAt != null)
                      Text(
                        '${settings.text('上次更新', 'Last updated')}: '
                        '${DateFormat('yyyy-MM-dd HH:mm').format(_citybusUpdatedAt!)}',
                      ),
                    if (_refreshingCitybus) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _citybusProgress),
                      const SizedBox(height: 6),
                      Text(
                        _citybusProgress == null
                            ? settings.text('正在下載', 'Downloading')
                            : '${(_citybusProgress! * 100).round()}%',
                      ),
                    ],
                    if (_citybusError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _citybusError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        M3EButton.icon(
                          onPressed: busy
                              ? null
                              : () => _downloadCitybus(force: true),
                          icon: const Icon(Icons.sync),
                          label: Text(
                            (_citybusBytes ?? 0) > 0
                                ? settings.text('更新城巴資料', 'Update Citybus data')
                                : settings.text(
                                    '下載城巴資料',
                                    'Download Citybus data',
                                  ),
                          ),
                        ),
                        M3EButton.icon(
                          style: M3EButtonStyle.text,
                          onPressed: busy || (_citybusBytes ?? 0) == 0
                              ? null
                              : _deleteCitybus,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(settings.text('刪除', 'Delete')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '$bytes B';
}
