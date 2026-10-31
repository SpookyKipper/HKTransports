import 'package:flutter/material.dart';
import 'package:hktransports/app/page_bar.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/favorite_group.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/favorite_group_dialogs.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class FavoriteGroupsPage extends StatelessWidget {
  const FavoriteGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final List<FavoriteGroup> groups = repository.favoriteGroups
        .where((group) => !group.isDefault)
        .toList();

    return Scaffold(
      appBar: buildPageBar(
        context,
        title: settings.text('管理收藏群組', 'Manage favourite groups'),
        actions: [
          M3EIconButton(
            tooltip: settings.text('新增群組', 'New group'),
            variant: M3EIconButtonVariant.standard,
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
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(settings.text('尚未建立群組', 'No custom groups yet')),
                    const SizedBox(height: 12),
                    M3EButton.icon(
                      onPressed: () async {
                        final String? name = await promptFavoriteGroupName(
                          context,
                        );
                        if (name != null) {
                          repository.createFavoriteGroup(name);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(settings.text('新增群組', 'New group')),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    settings.text(
                      '常用 固定在最前，其他群組可拖動排序。',
                      'Favourites stays first. Drag the other groups to reorder them.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    buildDefaultDragHandles: false,
                    itemCount: groups.length,
                    onReorder: repository.reorderCustomGroups,
                    itemBuilder: (context, index) {
                      final FavoriteGroup group = groups[index];
                      return ListTile(
                        key: ValueKey(group.id),
                        leading: const Icon(Icons.star_outline),
                        title: Text(group.name),
                        subtitle: Text(
                          settings.text(
                            '${repository.entriesInGroup(group).length} 個收藏',
                            '${repository.entriesInGroup(group).length} favourites',
                          ),
                        ),
                        onTap: () async {
                          final String? name = await promptFavoriteGroupName(
                            context,
                            initial: group.name,
                          );
                          if (name != null) {
                            repository.renameFavoriteGroup(group.id, name);
                          }
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            M3EIconButton(
                              tooltip: settings.text('刪除群組', 'Delete group'),
                              variant: M3EIconButtonVariant.standard,
                              onPressed: () =>
                                  _deleteGroup(context, repository, group),
                              icon: const Icon(Icons.delete_outline),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _deleteGroup(
    BuildContext context,
    BusRepository repository,
    FavoriteGroup group,
  ) async {
    final AppSettings settings = context.read<AppSettings>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(settings.text('刪除群組', 'Delete group')),
          content: Text(
            settings.text('確定刪除「${group.name}」？', 'Delete "${group.name}"?'),
          ),
          actions: [
            M3EButton.text(
              onPressed: () => Navigator.pop(context, false),
              child: Text(settings.text('取消', 'Cancel')),
            ),
            M3EButton.text(
              onPressed: () => Navigator.pop(context, true),
              child: Text(settings.text('刪除', 'Delete')),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      repository.deleteFavoriteGroup(group.id);
    }
  }
}
