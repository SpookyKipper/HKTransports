import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/favorite_group.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/favorite_group_dialogs.dart';
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

    final List<FavoriteGroup> groups = repository.favoriteGroups;

    return DefaultTabController(
      length: groups.length,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: NoticeBanner(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    dividerHeight: 0,
                    tabs: [
                      for (final FavoriteGroup group in groups)
                        Tab(text: group.name),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: settings.text('新增群組', 'New group'),
                  onPressed: () async {
                    final String? name = await promptFavoriteGroupName(context);
                    if (name != null) {
                      repository.createFavoriteGroup(name);
                    }
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final FavoriteGroup group in groups)
                  _GroupRoutesView(group: group),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRoutesView extends StatefulWidget {
  const _GroupRoutesView({required this.group});

  final FavoriteGroup group;

  @override
  State<_GroupRoutesView> createState() => _GroupRoutesViewState();
}

class _GroupRoutesViewState extends State<_GroupRoutesView> {
  bool _sorting = false;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final List<RouteEntry> routes = repository.routesInGroup(widget.group);
    final bool canSort = routes.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  settings.text(
                    '${routes.length} 條路線',
                    '${routes.length} routes',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (canSort)
                TextButton.icon(
                  onPressed: () => setState(() => _sorting = !_sorting),
                  icon: Icon(_sorting ? Icons.check : Icons.sort),
                  label: Text(
                    _sorting
                        ? settings.text('完成', 'Done')
                        : settings.text('排序', 'Sort'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: routes.isEmpty
              ? Center(
                  child: Text(
                    settings.text(
                      '尚未收藏路線\n在路線頁面按星號即可加入。',
                      'No saved routes yet.\nTap the star on a route to add it.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : _sorting
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  buildDefaultDragHandles: false,
                  itemCount: routes.length,
                  onReorder: (oldIndex, newIndex) {
                    repository.reorderFavoriteGroup(
                      widget.group.id,
                      oldIndex,
                      newIndex,
                    );
                  },
                  itemBuilder: (context, index) {
                    final RouteEntry route = routes[index];
                    return _RouteTile(
                      key: ValueKey('${widget.group.id}-${route.key}'),
                      route: route,
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                      onTap: null,
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: routes.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final RouteEntry route = routes[index];
                    return _RouteTile(
                      route: route,
                      onTap: () {
                        repository.addRecent(route);
                        context.push('/route/${route.slug}');
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({super.key, required this.route, this.onTap, this.trailing});

  final RouteEntry route;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    return ListTile(
      leading: SizedBox(
        width: 64,
        child: Text(route.route, style: Theme.of(context).textTheme.titleLarge),
      ),
      title: Text(
        '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
      ),
      subtitle: Text(
        '${route.orig.get(settings.language)} · ${route.companiesLabel(settings.language)}',
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
