import 'package:flutter/material.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class NlbTimetablePanel extends StatefulWidget {
  const NlbTimetablePanel({super.key, required this.route});

  final RouteEntry route;

  @override
  State<NlbTimetablePanel> createState() => _NlbTimetablePanelState();
}

class _NlbTimetablePanelState extends State<NlbTimetablePanel> {
  Future<NlbTimetable?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NlbTimetablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String language = context.read<AppSettings>().language;
    if (oldWidget.route.key != widget.route.key ||
        oldWidget.route.route != widget.route.route ||
        _language != language) {
      _load();
    }
  }

  String? _language;

  void _load({bool force = false}) {
    _language = context.read<AppSettings>().language;
    _future = NlbTimetableService.instance.fetch(
      widget.route,
      _language!,
      force: force,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<NlbTimetable?>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<NlbTimetable?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: M3ELoadingIndicator(size: 24),
          );
        }
        final NlbTimetable? timetable = snapshot.data;
        if (timetable == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.text(
                    '未能載入嶼巴官方時間表',
                    'Could not load the official NLB timetable',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                M3EButton.text(
                  onPressed: () => setState(() => _load(force: true)),
                  child: Text(settings.text('重試', 'Retry')),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.text('官方時間表', 'Official timetable'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final NlbTimetableSection section in timetable.sections) ...[
              if (section.title.isNotEmpty) ...[
                Text(
                  section.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final NlbTimetableRow row in section.rows)
                    _TimeChip(row: row),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (timetable.notes.isNotEmpty)
              Text(
                timetable.notes.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.row});

  final NlbTimetableRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        row.note.isEmpty ? row.time : '${row.time} ${row.note}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
