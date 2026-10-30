import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/route_number_pad.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';

  void _appendNumber(String value) {
    setState(() => _query += value);
  }

  void _backspaceNumber() {
    if (_query.isEmpty) return;
    setState(() => _query = _query.substring(0, _query.length - 1));
  }

  void _clearNumber() {
    if (_query.isEmpty) return;
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();

    if (!repository.hasData) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          Center(
            child: Text(settings.text('請先下載路線資料', 'Download route data first')),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => context.push('/updateData'),
              child: Text(settings.text('下載路線資料', 'Download route data')),
            ),
          ),
        ],
      );
    }

    final List<RouteEntry> results = repository.searchRouteNumbers(_query);
    final Set<String> possibleChars = repository.possibleRouteChars(_query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildNumberBar(context, settings),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(settings.text('沒有符合的路線', 'No matching routes')),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final RouteEntry route = results[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 64,
                        child: Text(
                          route.route,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      title: Text(
                        '${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
                      ),
                      subtitle: Text(
                        '${route.orig.get(settings.language)} · ${route.companiesLabel(settings.language)}',
                      ),
                      trailing: route.isSpecial
                          ? Text(
                              settings.text('特別班', 'Special'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            )
                          : null,
                      onTap: () {
                        repository.addRecent(route);
                        context.push('/route/${route.slug}');
                      },
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
          child: RouteNumberPad(
            possibleChars: possibleChars,
            hasQuery: _query.isNotEmpty,
            onCharacter: _appendNumber,
            onBackspace: _backspaceNumber,
            onClear: _clearNumber,
            clearTooltip: settings.text('清除', 'Clear'),
            backspaceTooltip: settings.text('刪除', 'Backspace'),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberBar(BuildContext context, AppSettings settings) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _query.isEmpty ? settings.text('路線號碼', 'Route number') : _query,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _query.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  letterSpacing: _query.isEmpty ? null : 2,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                tooltip: settings.text('清除', 'Clear'),
                onPressed: _clearNumber,
                icon: const Icon(Icons.close),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
