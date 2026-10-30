import 'package:flutter/material.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/journey/journey_time.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/official_links.dart';
import 'package:hktransports/bus/ui/proprietary_notices.dart';
import 'package:provider/provider.dart';

class TimetableSheet extends StatelessWidget {
  const TimetableSheet({
    super.key,
    required this.route,
    this.initialStopIndex = 0,
  });

  final RouteEntry route;
  final int initialStopIndex;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final bool showNotices =
        route.companies.contains(BusCompany.kmb) ||
        route.companies.contains(BusCompany.ctb);
    return DefaultTabController(
      length: showNotices ? 3 : 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            TabBar(
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              tabs: [
                Tab(text: settings.text('時間表', 'Timetable')),
                Tab(text: settings.text('車程', 'Journey')),
                if (showNotices) Tab(text: settings.text('通告', 'Notices')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TimetableTab(route: route),
                  _JourneyTab(route: route, initialStopIndex: initialStopIndex),
                  if (showNotices) ProprietaryNoticesTab(route: route),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableTab extends StatelessWidget {
  const _TimetableTab({required this.route});

  final RouteEntry route;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final Map<String, Map<String, List<String>?>>? freq = route.freq;
    if (freq == null || freq.isEmpty) {
      return Center(
        child: Text(settings.text('此路線沒有時間表資料', 'No timetable for this route')),
      );
    }
    final bool holiday = isHoliday(
      repository.database?.holidays ?? const [],
      hkNow(),
    );
    final DateTime now = hkNow();
    final String currentTime =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final List<String> serviceIds = freq.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final String serviceId in serviceIds)
          _ServiceSection(
            serviceId: serviceId,
            windows: freq[serviceId] ?? const {},
            serviceDays:
                repository.database?.serviceDayMap[serviceId] ?? const [],
            holiday: holiday,
            currentTime: currentTime,
          ),
        OfficialLinks(route: route),
      ],
    );
  }
}

class _ServiceSection extends StatelessWidget {
  const _ServiceSection({
    required this.serviceId,
    required this.windows,
    required this.serviceDays,
    required this.holiday,
    required this.currentTime,
  });

  final String serviceId;
  final Map<String, List<String>?> windows;
  final List<bool> serviceDays;
  final bool holiday;
  final String currentTime;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final List<MapEntry<String, List<String>?>> entries =
        windows.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final bool serviceMatches = _matchesDay(serviceDays, holiday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            serviceIdLabel(serviceId, settings.language),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final MapEntry<String, List<String>?> entry in entries)
          ListTile(
            selected:
                serviceMatches &&
                _isCurrent(entry.key, entry.value, currentTime),
            title: Text(
              entry.value == null
                  ? _formatTime(entry.key)
                  : '${_formatTime(entry.key)} - ${_formatTime(entry.value![0])}',
            ),
            trailing: entry.value == null
                ? null
                : Text(
                    '${(int.tryParse(entry.value![1]) ?? 0) ~/ 60} ${settings.text('分鐘', 'min')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
          ),
      ],
    );
  }

  bool _matchesDay(List<bool> days, bool holiday) {
    if (days.length < 7) return true;
    final int day = hkNow().weekday % 7;
    return days[day] || (holiday && days[0]);
  }

  bool _isCurrent(String start, List<String>? detail, String now) {
    if (detail == null) return false;
    return start.compareTo(now) <= 0 && now.compareTo(detail[0]) <= 0;
  }

  String _formatTime(String value) {
    if (value.length != 4) return value;
    return '${value.substring(0, 2)}:${value.substring(2)}';
  }
}

class _JourneyTab extends StatefulWidget {
  const _JourneyTab({required this.route, required this.initialStopIndex});

  final RouteEntry route;
  final int initialStopIndex;

  @override
  State<_JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<_JourneyTab> {
  late int _startSeq;

  @override
  void initState() {
    super.initState();
    _startSeq = widget.initialStopIndex;
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    final BusRepository repository = context.watch<BusRepository>();
    final List<String> stopIds = widget.route.primaryStops;
    final List<StopEntry> stops = stopIds
        .map(repository.stopById)
        .whereType<StopEntry>()
        .toList();
    if (stops.length != stopIds.length) {
      return Center(
        child: Text(settings.text('車站資料不完整', 'Stop data is incomplete')),
      );
    }
    if (_startSeq >= stops.length) _startSeq = 0;
    final JourneyEstimate estimate = estimateJourney(
      route: widget.route,
      stops: stops,
      startSeq: _startSeq,
    );

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: stops.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settings.text('由', 'From')} ${stops[_startSeq].displayName(settings.language)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${estimate.estimated ? settings.text('預計', 'Estimated') : settings.text('全程約', 'About')} ${estimate.totalMinutes} ${settings.text('分鐘', 'minutes')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  settings.text('點選任何車站可重新計算', 'Tap any stop to recalculate'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }
        final int stopIndex = index - 1;
        final StopEntry stop = stops[stopIndex];
        final bool beforeStart = stopIndex < _startSeq;
        final bool isStart = stopIndex == _startSeq;
        final int? minutes = beforeStart
            ? null
            : estimate.cumulativeMinutes[stopIndex - _startSeq];
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return ListTile(
          selected: isStart,
          leading: Icon(
            isStart ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: beforeStart ? scheme.outline : null,
          ),
          title: Text(
            stop.displayName(settings.language),
            style: beforeStart ? TextStyle(color: scheme.outline) : null,
          ),
          trailing: isStart
              ? Text(settings.text('起點', 'Start'))
              : minutes == null
              ? null
              : Text('$minutes ${settings.text('分鐘', 'min')}'),
          onTap: () => setState(() => _startSeq = stopIndex),
        );
      },
    );
  }
}

String serviceIdLabel(String id, String language) {
  const Map<String, List<String>> labels = {
    '1': ['星期一', 'Monday'],
    '2': ['星期二', 'Tuesday'],
    '4': ['星期三', 'Wednesday'],
    '8': ['星期四', 'Thursday'],
    '16': ['星期五', 'Friday'],
    '32': ['星期六', 'Saturday'],
    '63': ['星期一至六', 'Monday to Saturday'],
    '64': ['星期日', 'Sunday'],
    '111': ['除星期三外', 'Except Wednesday'],
    '257': ['星期一', 'Monday'],
    '258': ['星期二', 'Tuesday'],
    '260': ['星期三', 'Wednesday'],
    '264': ['星期四', 'Thursday'],
    '266': ['星期二至四', 'Tuesday to Thursday'],
    '271': ['星期一至四', 'Monday to Thursday'],
    '272': ['星期五', 'Friday'],
    '287': ['星期一至五', 'Monday to Friday'],
    '288': ['星期六', 'Saturday'],
    '319': ['星期一至六', 'Monday to Saturday'],
    '320': ['星期日及公眾假期', 'Sunday and public holidays'],
    '415': ['星期一至五', 'Monday to Friday'],
    '416': ['星期六至日', 'Saturday and Sunday'],
    '447': ['星期一至六', 'Monday to Saturday'],
    '448': ['星期日及公眾假期', 'Sunday and public holidays'],
    '480': ['星期六至日', 'Saturday and Sunday'],
    '511': ['所有日子', 'All days'],
    '999': ['未知日子', 'Unknown day'],
  };
  final List<String>? label = labels[id];
  if (label == null) return '${language == 'en' ? 'Service' : '服務'} $id';
  return language == 'en' ? label[1] : label[0];
}
