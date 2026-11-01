import 'package:flutter/material.dart';
import 'package:hktransports/bus/traffic/traffic_news_service.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 112),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final TrafficNewsItem item = items[index];
            final String? title = item.title == null
                ? null
                : _at(item.title!, languageIndex);
            final String description = _at(item.description, languageIndex);
            return Card.filled(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        item.status <= 2
                            ? Icon(
                                Icons.warning_amber,
                                color: Theme.of(context).colorScheme.error,
                              )
                            : const Icon(Icons.info_outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title ?? description,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    if (title != null) ...[
                      const SizedBox(height: 8),
                      Text(description),
                    ],
                    if (item.date.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          item.date,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
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
