import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/favorite_group.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/favorite_group_dialogs.dart';
import 'package:hktransports/bus/ui/citybus_route_name_subtitle.dart';
import 'package:hktransports/bus/ui/notice_banner.dart';
import 'package:hktransports/bus/ui/route_eta_view.dart';
import 'package:hktransports/bus/ui/route_special_tag.dart';
import 'package:hktransports/pages/homeIndexPage/nearby_routes.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent>
    with TickerProviderStateMixin {
  String? _selectedGroupId;
  TabController? _tabController;
  List<String> _groupIds = const [];

  @override
  void initState() {
    super.initState();
    _selectedGroupId = context.read<AppSettings>().lastHomeTabId;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureTabController(int length, int initialIndex) {
    if (_tabController != null && _tabController!.length == length) {
      return;
    }
    final TabController? old = _tabController;
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, length - 1),
    )..addListener(_handleTabChanged);
    if (old != null) {
      old.removeListener(_handleTabChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    }
  }

  void _handleTabChanged() {
    final TabController? controller = _tabController;
    if (controller == null) return;
    final int index = controller.index;
    if (index < 0 || index >= _groupIds.length) return;
    final String id = _groupIds[index];
    if (id != _selectedGroupId) {
      setState(() => _selectedGroupId = id);
      context.read<AppSettings>().setLastHomeTabId(id);
    }
  }

  void _syncSelectedTab(int selectedIndex) {
    final TabController? controller = _tabController;
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller != _tabController) return;
      if (controller.index != selectedIndex) {
        controller.animateTo(selectedIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();

    if (repository.status == BusDataStatus.loading) {
      return const Center(child: M3ELoadingIndicator());
    }

    if (!repository.hasData && repository.status == BusDataStatus.updating) {
      final double? progress = repository.progress;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const M3ELoadingIndicator(),
              const SizedBox(height: 16),
              Text(
                settings.text('正在下載路線資料', 'Downloading route data'),
                textAlign: TextAlign.center,
              ),
              if (progress != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  child: M3EProgressIndicator.linearWavy(
                    value: progress,
                    linearSize: M3EProgressIndicatorSize.m,
                    strokeWidth: 4,
                    trackStrokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).round()}%'),
              ],
            ],
          ),
        ),
      );
    }

    if (!repository.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
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
          M3EButton.icon(
            onPressed: () => context.push('/updateData'),
            icon: const Icon(Icons.download_outlined),
            label: Text(settings.text('下載路線資料', 'Download route data')),
          ),
        ],
      );
    }

    final bool homeActive = TickerMode.of(context);
    final List<FavoriteGroup> groups = repository.favoriteGroups;
    _groupIds = <String>[
      nearbyHomeTabId,
      for (final FavoriteGroup group in groups) group.id,
    ];
    final int selectedIndex = _groupIds.indexOf(
      _selectedGroupId ?? nearbyHomeTabId,
    );
    final int pageIndex = selectedIndex < 0 ? 0 : selectedIndex;
    _ensureTabController(_groupIds.length, pageIndex);
    _syncSelectedTab(pageIndex);
    final Color unselectedTabColor =
        Theme.of(context).tabBarTheme.unselectedLabelColor ??
        Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      children: [
        if (settings.useProprietaryNotice)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: NoticeBanner(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  tabs: [
                    Tab(text: settings.text('附近', 'Nearby')),
                    for (final FavoriteGroup group in groups)
                      Tab(text: group.name),
                  ],
                ),
              ),
              M3EIconButton(
                tooltip: settings.text('管理群組', 'Manage groups'),
                variant: M3EIconButtonVariant.standard,
                onPressed: () => context.push('/favoriteGroups'),
                icon: Icon(Icons.tune, color: unselectedTabColor),
              ),
              M3EIconButton(
                tooltip: settings.text('新增群組', 'New group'),
                variant: M3EIconButtonVariant.standard,
                onPressed: () async {
                  final String? name = await promptFavoriteGroupName(context);
                  if (name != null) {
                    repository.createFavoriteGroup(name);
                  }
                },
                icon: Icon(Icons.add, color: unselectedTabColor),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              NearbyRoutesView(active: homeActive && pageIndex == 0),
              for (int index = 0; index < groups.length; index++)
                _GroupRoutesView(
                  key: PageStorageKey<String>(groups[index].id),
                  group: groups[index],
                  active: homeActive && index + 1 == pageIndex,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupRoutesView extends StatefulWidget {
  const _GroupRoutesView({
    super.key,
    required this.group,
    required this.active,
  });

  final FavoriteGroup group;
  final bool active;

  @override
  State<_GroupRoutesView> createState() => _GroupRoutesViewState();
}

class _GroupRoutesViewState extends State<_GroupRoutesView> {
  bool _sorting = false;
  int _refreshVersion = 0;

  Future<void> _refresh() async {
    setState(() => _refreshVersion++);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final List<FavoriteEntry> entries = repository
        .entriesInGroup(widget.group)
        .where((entry) => repository.routeByKey(entry.routeKey) != null)
        .toList();
    final bool canSort = entries.length > 1;

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
                    '${entries.length} 個收藏',
                    '${entries.length} favourites',
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (canSort)
                M3EButton.icon(
                  onPressed: () => setState(() => _sorting = !_sorting),
                  style: M3EButtonStyle.text,
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
          child: M3ERefreshIndicator.contained(
            onRefresh: _refresh,
            child: entries.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 72, 24, 112),
                    children: [
                      Text(
                        settings.text(
                          '尚未收藏車站\n在路線頁面的車站按星號即可加入。',
                          'No saved stops yet.\nTap the star on a stop to add it.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : _sorting
                ? ReorderableListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 112),
                    buildDefaultDragHandles: false,
                    itemCount: entries.length,
                    onReorder: (oldIndex, newIndex) {
                      final List<FavoriteEntry> reordered = [...entries];
                      if (newIndex > oldIndex) newIndex -= 1;
                      final FavoriteEntry entry = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, entry);
                      repository.setGroupEntries(widget.group.id, reordered);
                    },
                    itemBuilder: (context, index) {
                      final FavoriteEntry entry = entries[index];
                      final RouteEntry route = repository.routeByKey(
                        entry.routeKey,
                      )!;
                      return _FavoriteRouteTile(
                        key: ValueKey('${widget.group.id}-${entry.storageKey}'),
                        route: route,
                        seq: entry.seq,
                        showEta: false,
                        refreshVersion: _refreshVersion,
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 112),
                    itemCount: entries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final FavoriteEntry entry = entries[index];
                      final RouteEntry route = repository.routeByKey(
                        entry.routeKey,
                      )!;
                      return _FavoriteRouteTile(
                        route: route,
                        seq: entry.seq,
                        refreshVersion: _refreshVersion,
                        showEta: widget.active,
                        onTap: () {
                          repository.addRecent(route);
                          final List<String> stops = route.primaryStops;
                          final String? stopId =
                              entry.seq >= 0 && entry.seq < stops.length
                              ? stops[entry.seq]
                              : null;
                          final String stopQuery = stopId == null
                              ? ''
                              : '?stop=${Uri.encodeQueryComponent(stopId)}';
                          context.push('/route/${route.slug}$stopQuery');
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _FavoriteRouteTile extends StatelessWidget {
  const _FavoriteRouteTile({
    super.key,
    required this.route,
    required this.seq,
    this.onTap,
    this.trailing,
    this.showEta = true,
    this.refreshVersion = 0,
  });

  final RouteEntry route;
  final int seq;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showEta;
  final int refreshVersion;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final bool citybusEnabled = settings.isProprietaryEnabled(
      ProprietaryEndpoint.citybusDatabase,
    );
    final List<String> stopIds = route.primaryStops;
    final StopEntry? stop = seq >= 0 && seq < stopIds.length
        ? repository.stopById(stopIds[seq])
        : null;
    final Widget? etaOrTrailing = showEta
        ? RouteEtaView(route: route, seq: seq, refreshVersion: refreshVersion)
        : trailing;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.route,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    route.companiesLabel(settings.language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.bodySmall?.fontSize ??
                              12) -
                          1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.1,
                    ),
                  ),
                  if (route.isSpecial)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RouteSpecialTag(
                          label: settings.text('特別班', 'Special'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
                  ),
                  CitybusRouteNameSubtitle(
                    route: route,
                    language: settings.language,
                    enabled: citybusEnabled,
                    text:
                        stop?.displayName(settings.language) ??
                        route.orig.get(settings.language),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (etaOrTrailing != null) ...[
              const SizedBox(width: 8),
              etaOrTrailing,
            ],
          ],
        ),
      ),
    );
  }
}
