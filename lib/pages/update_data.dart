import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class UpdateDataPageRoute extends StatelessWidget {
  const UpdateDataPageRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final bool busy = repository.status == BusDataStatus.updating;

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
                  if (repository.md5 != null)
                    Text(
                      'MD5: ${repository.md5}',
                      style: Theme.of(context).textTheme.bodySmall,
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
          if (busy) ...[
            M3EProgressIndicator.linear(
              value: repository.progress,
              strokeWidth: 4,
              trackStrokeWidth: 4,
            ),
            const SizedBox(height: 8),
            Text(
              repository.progress == null
                  ? settings.text('正在下載', 'Downloading')
                  : '${(repository.progress! * 100).round()}%',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          M3EButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final bool updated = await repository.update(
                      force: !repository.hasData,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          updated
                              ? settings.text('資料已更新', 'Data updated')
                              : settings.text('資料已是最新', 'Data is up to date'),
                        ),
                      ),
                    );
                  },
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
                : () async {
                    final bool updated = await repository.update(force: true);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          updated
                              ? settings.text('資料已重新下載', 'Data downloaded')
                              : settings.text('下載失敗', 'Download failed'),
                        ),
                      ),
                    );
                  },
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
