import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/notice_banner.dart';
import 'package:provider/provider.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();

    if (repository.status == BusDataStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!repository.hasData) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.text('香港巴士到站預報', 'Hong Kong bus arrivals'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.text(
                      '下載路線資料後即可開始使用。',
                      'Download route data to get started.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/updateData'),
            icon: const Icon(Icons.download_outlined),
            label: Text(settings.text('下載路線資料', 'Download route data')),
          ),
        ],
      );
    }

    final List<RouteEntry> saved = repository.savedRoutes
        .map(repository.routeByKey)
        .whereType<RouteEntry>()
        .toList();
    final String toLabel = settings.text('往', 'to');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const NoticeBanner(),
        Text(
          settings.text('常用路線', 'Saved routes'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (saved.isEmpty)
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(settings.text('尚未收藏路線', 'No saved routes yet')),
                  const SizedBox(height: 8),
                  Text(
                    settings.text(
                      '在路線頁面按星號即可加入。',
                      'Open a route and tap the star to save it.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          ...saved.map(
            (RouteEntry route) => Card.filled(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${route.route} $toLabel ${route.dest.get(settings.language)}',
                ),
                subtitle: Text(
                  '${route.orig.get(settings.language)} · ${route.companiesLabel(settings.language)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/route/${route.slug}'),
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => context.push('/updateData'),
          icon: const Icon(Icons.storage_outlined),
          label: Text(settings.text('路線資料', 'Route data')),
        ),
      ],
    );
  }
}
