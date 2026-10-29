import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();

    if (!repository.hasData) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SearchBar(
            controller: _controller,
            hintText: settings.text('路線號碼或目的地', 'Route number or destination'),
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 48),
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

    final List<RouteEntry> results = repository.search(_query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            controller: _controller,
            hintText: settings.text('路線號碼或目的地', 'Route number or destination'),
            leading: const Icon(Icons.search),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
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
      ],
    );
  }
}
