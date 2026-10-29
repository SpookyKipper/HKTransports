import 'package:flutter/material.dart';
import 'package:hkbusapi/trafficnews/trafficnews.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:provider/provider.dart';

class TrafficNews extends StatefulWidget {
  const TrafficNews({super.key});

  @override
  State<TrafficNews> createState() => _TrafficNewsState();
}

class _TrafficNewsState extends State<TrafficNews> {
  late Future<List<TrafficNewsItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = getTrafficNews();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();

    return FutureBuilder<List<TrafficNewsItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: M3ELoadingIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              settings.text('無法載入交通快訊', 'Unable to load traffic news'),
            ),
          );
        }
        final List<TrafficNewsItem> items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Text(settings.text('暫無交通快訊', 'No traffic news')),
          );
        }
        final int languageIndex = settings.isChinese ? 0 : 1;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final TrafficNewsItem item = items[index];
            final String? title = item.title == null
                ? null
                : _at(item.title!, languageIndex);
            final String description = _at(item.description, languageIndex);
            return Card.filled(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: item.status <= 2
                    ? Icon(
                        Icons.warning_amber,
                        color: Theme.of(context).colorScheme.error,
                      )
                    : const Icon(Icons.info_outline),
                title: title == null ? null : Text(title),
                subtitle: Text(description),
                trailing: item.date.isEmpty ? null : Text(item.date),
              ),
            );
          },
        );
      },
    );
  }

  String _at(List<String> values, int index) {
    if (values.isEmpty) return '';
    return values[index.clamp(0, values.length - 1)];
  }
}
