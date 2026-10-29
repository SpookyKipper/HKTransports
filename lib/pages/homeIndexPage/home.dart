import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/favorite_group.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/favorite_group_dialogs.dart';
import 'package:hktransports/bus/ui/notice_banner.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
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
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureTabController(List<FavoriteGroup> groups) {
    if (_tabController != null && _tabController!.length == groups.length) {
      return;
    }
    final TabController? old = _tabController;
    final int selectedIndex = groups.indexWhere(
      (group) => group.id == _selectedGroupId,
    );
    final int initialIndex = selectedIndex < 0 ? 0 : selectedIndex;
    _tabController = TabController(
      length: groups.length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, groups.length - 1),
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
          FilledButton.icon(
            onPressed: () => context.push('/updateData'),
            icon: const Icon(Icons.download_outlined),
            label: Text(settings.text('下載路線資料', 'Download route data')),
          ),
        ],
      );
    }

    final List<FavoriteGroup> groups = repository.favoriteGroups;
    _groupIds = groups.map((group) => group.id).toList();
    _ensureTabController(groups);
    final int selectedIndex = groups.indexWhere(
      (group) => group.id == _selectedGroupId,
    );
    final int pageIndex = selectedIndex < 0 ? 0 : selectedIndex;
    _syncSelectedTab(pageIndex);

    return Column(
      children: [
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
                    for (final FavoriteGroup group in groups)
                      Tab(text: group.name),
                  ],
                ),
              ),
              IconButton(
                tooltip: settings.text('管理群組', 'Manage groups'),
                onPressed: () => context.push('/favoriteGroups'),
                icon: const Icon(Icons.tune),
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
            controller: _tabController,
            children: [
              for (final FavoriteGroup group in groups)
                _GroupRoutesView(
                  key: PageStorageKey<String>(group.id),
                  group: group,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupRoutesView extends StatefulWidget {
  const _GroupRoutesView({super.key, required this.group});

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
                    '${entries.length} 條路線',
                    '${entries.length} routes',
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
          child: entries.isEmpty
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

class _FavoriteRouteTile extends StatefulWidget {
  const _FavoriteRouteTile({
    super.key,
    required this.route,
    required this.seq,
    this.onTap,
    this.trailing,
    this.showEta = true,
  });

  final RouteEntry route;
  final int seq;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showEta;

  @override
  State<_FavoriteRouteTile> createState() => _FavoriteRouteTileState();
}

class _FavoriteRouteTileState extends State<_FavoriteRouteTile> {
  late final EtaService _etaService;
  Timer? _timer;
  List<BusEta>? _etas;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _etaService = context.read<EtaService>();
    final AppSettings settings = context.read<AppSettings>();
    _etaService.setLanguage(settings.language);
    _fetch();
    _timer = Timer.periodic(
      Duration(seconds: settings.refreshSeconds),
      (_) => _fetch(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _etaService.setLanguage(context.read<AppSettings>().language);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final List<BusEta> etas = await _etaService.fetchRouteStop(
      widget.route,
      widget.seq,
    );
    if (!mounted) return;
    setState(() {
      _etas = etas;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final List<BusEta> etas = (_etas ?? const [])
        .where(
          (eta) => eta.eta != null || eta.remark(settings.language).isNotEmpty,
        )
        .take(3)
        .toList();

    Widget? trailing = widget.trailing;
    if (widget.showEta) {
      if (_loading && _etas == null) {
        trailing = const M3ELoadingIndicator(
          constraints: BoxConstraints(
            minWidth: 24,
            minHeight: 24,
            maxWidth: 24,
            maxHeight: 24,
          ),
        );
      } else if (etas.isEmpty) {
        trailing = Text('--', style: Theme.of(context).textTheme.bodySmall);
      } else {
        trailing = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int index = 0; index < etas.length; index++)
                _CompactEtaLine(eta: etas[index], first: index == 0),
            ],
          ),
        );
      }
    }

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                widget.route.route,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settings.text('往', 'to')} ${widget.route.dest.get(settings.language)}',
                  ),
                  Text(
                    '${widget.route.orig.get(settings.language)} · ${widget.route.companiesLabel(settings.language)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
  }
}

class _CompactEtaLine extends StatelessWidget {
  const _CompactEtaLine({required this.eta, required this.first});

  final BusEta eta;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final DateTime? time = eta.eta;
    final String remark = eta.remark(settings.language);
    if (time == null) {
      if (remark.isEmpty) return const SizedBox.shrink();
      return Text(
        remark,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final DateTime hkTime = time.toUtc().add(const Duration(hours: 8));
    final String clock = DateFormat('HH:mm').format(hkTime);
    final int minutes = time.difference(DateTime.now().toUtc()).inMinutes;
    final String wait = minutes < 1
        ? settings.text('即將', 'Arriving')
        : '$minutes ${settings.text('分', 'min')}';
    final String text = switch (settings.etaFormat) {
      EtaFormat.diff => wait,
      EtaFormat.exact => clock,
      EtaFormat.mixed => '$clock  $wait',
    };
    final Color color = first
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eta.isScheduledLike)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.schedule, size: 14, color: color),
          ),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
