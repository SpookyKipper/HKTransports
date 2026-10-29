import 'package:flutter/material.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class RoutePageRoute extends StatelessWidget {
  const RoutePageRoute({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final RouteEntry? route = repository.routeBySlug(slug);

    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: Text(settings.text('路線', 'Route'))),
        body: Center(child: Text(settings.text('找不到路線', 'Route not found'))),
      );
    }

    final List<String> stopIds = route.primaryStops;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${route.route} ${settings.text('往', 'to')} ${route.dest.get(settings.language)}',
        ),
      ),
      body: ListView.builder(
        itemCount: stopIds.length,
        itemBuilder: (context, index) {
          final StopEntry? stop = repository.stopById(stopIds[index]);
          return ListTile(
            leading: Text('${index + 1}'),
            title: Text(stop?.displayName(settings.language) ?? stopIds[index]),
            subtitle: stop?.stationCode == null
                ? null
                : Text('${settings.text('站碼', 'Code')} ${stop!.stationCode}'),
          );
        },
      ),
    );
  }
}
