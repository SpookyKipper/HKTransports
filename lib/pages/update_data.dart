import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
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
    if (!latestSettings.isProprietaryEnabled(ProprietaryDataSource.kmb)) {
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
    _showMessage(
      refreshed
          ? settings.text('路線及轉乘資料已更新', 'Route and interchange data updated')
          : settings.text(
              '路線資料已更新，但轉乘資料更新失敗',
              'Route data updated, but interchange data refresh failed',
            ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final bool routeBusy = repository.status == BusDataStatus.updating;
    final bool busy = routeBusy || _refreshingBbi;

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('更新資料', 'Update data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  FutureBuilder<List<int>>(
                    future: Future.wait([
                      repository.updater.dataSizeBytes(),
                      const BbiService().storedBytes(),
                    ]),
                    builder: (context, snapshot) {
                      final List<int>? sizes = snapshot.data;
                      if (sizes == null) return const SizedBox.shrink();
                      final int total = sizes[0] + sizes[1];
                      return Text(
                        settings.text(
                          '資料大小: ${_formatBytes(total)}',
                          'Data size: ${_formatBytes(total)}',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (routeBusy) ...[
            if (repository.progress != null)
              M3EProgressIndicator.linearWavy(
                value: repository.progress,
                linearSize: M3EProgressIndicatorSize.m,
                strokeWidth: 4,
                trackStrokeWidth: 4,
              )
            else
              const M3ELoadingIndicator(size: 24),
            const SizedBox(height: 8),
            Text(
              repository.progress == null
                  ? settings.text('正在下載', 'Downloading')
                  : '${(repository.progress! * 100).round()}%',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          if (_refreshingBbi) ...[
            M3EProgressIndicator.linearWavy(
              value: _bbiTotal == 0 ? 0 : _bbiCompleted / _bbiTotal,
              linearSize: M3EProgressIndicatorSize.m,
              strokeWidth: 4,
              trackStrokeWidth: 4,
            ),
            const SizedBox(height: 8),
            Text(
              settings.text(
                '正在更新轉乘資料 $_bbiCompleted/$_bbiTotal',
                'Updating interchange data $_bbiCompleted/$_bbiTotal',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          M3EButton.icon(
            onPressed: busy
                ? null
                : () => _runUpdate(
                    force: !repository.hasData,
                    downloadAgain: false,
                  ),
            icon: const Icon(Icons.download_outlined),
            label: Text(
              repository.hasData
                  ? settings.text('檢查更新', 'Check for updates')
                  : settings.text('下載路線資料', 'Download route data'),
            ),
          ),
          const SizedBox(height: 8),
          M3EButton.icon(
            style: M3EButtonStyle.text,
            onPressed: busy
                ? null
                : () => _runUpdate(force: true, downloadAgain: true),
            icon: const Icon(Icons.refresh),
            label: Text(settings.text('重新下載', 'Download again')),
          ),
          if (repository.error != null) ...[
            const SizedBox(height: 16),
            Text(
              repository.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
