import 'package:flutter/material.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/favorite_group.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/favorite_group_dialogs.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

Future<void> showRouteGroupSheet(
  BuildContext context,
  RouteEntry route, {
  int stopSeq = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return RouteGroupSheet(route: route, stopSeq: stopSeq);
    },
  );
}

class RouteGroupSheet extends StatelessWidget {
  const RouteGroupSheet({super.key, required this.route, this.stopSeq = 0});

  final RouteEntry route;
  final int stopSeq;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final List<FavoriteGroup> groups = repository.favoriteGroups;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text(
              '${route.route} ${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
            ),
            subtitle: Text(route.companiesLabel(settings.language)),
            leading: const Icon(Icons.star_outline),
          ),
          const Divider(),
          for (final FavoriteGroup group in groups)
            ListTile(
              leading: Checkbox(
                value: repository.isRouteInGroup(group.id, route.key),
                onChanged: (_) => repository.toggleRouteInGroup(
                  group.id,
                  route.key,
                  seq: stopSeq,
                ),
              ),
              title: Text(group.name),
              subtitle: Text(
                settings.text(
                  '${repository.routesInGroup(group).length} 條路線',
                  '${repository.routesInGroup(group).length} routes',
                ),
              ),
              trailing: group.isDefault
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        M3EIconButton(
                          tooltip: settings.text('重新命名', 'Rename'),
                          variant: M3EIconButtonVariant.standard,
                          onPressed: () async {
                            final String? name = await promptFavoriteGroupName(
                              context,
                              initial: group.name,
                            );
                            if (name != null) {
                              repository.renameFavoriteGroup(group.id, name);
                            }
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        M3EIconButton(
                          tooltip: settings.text('刪除群組', 'Delete group'),
                          variant: M3EIconButtonVariant.standard,
                          onPressed: () =>
                              _deleteGroup(context, repository, group),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
              onTap: () => repository.toggleRouteInGroup(
                group.id,
                route.key,
                seq: stopSeq,
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(settings.text('新增群組', 'New group')),
            onTap: () async {
              final String? name = await promptFavoriteGroupName(context);
              if (name == null) return;
              final FavoriteGroup? group = repository.createFavoriteGroup(name);
              if (group != null) {
                repository.toggleRouteInGroup(
                  group.id,
                  route.key,
                  seq: stopSeq,
                );
              }
            },
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
