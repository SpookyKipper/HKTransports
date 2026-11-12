import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/journey/journey_time.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/notice/citybus_remarks_service.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/nlb_timetable_panel.dart';
import 'package:hktransports/bus/ui/official_links.dart';
import 'package:hktransports/bus/ui/proprietary_notices.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final bool hasKmb = route.companies.contains(BusCompany.kmb);
    final bool hasCtb = route.companies.contains(BusCompany.ctb);
    final bool hasNlb = route.companies.contains(BusCompany.nlb);
    final bool showNlbProprietary =
        hasNlb &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.nlbProprietaryData);
    final bool showNotices =
        showNlbProprietary ||
        (hasKmb &&
            (settings.isProprietaryEnabled(
                  ProprietaryEndpoint.kmbAnnouncements,
                ) ||
                settings.isProprietaryEnabled(
                  ProprietaryEndpoint.kmbInterchange,
                ))) ||
        (hasCtb &&
            (settings.isProprietaryEnabled(
                  ProprietaryEndpoint.citybusSpecialNotices,
                ) ||
                settings.isProprietaryEnabled(
                  ProprietaryEndpoint.citybusRouteNotices,
                ) ||
                settings.isProprietaryEnabled(
                  ProprietaryEndpoint.citybusInterchange,
                )));
    final bool showRemarks =
        hasCtb &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.citybusRemarks);
    return DefaultTabController(
      length: 2 + (showNotices ? 1 : 0) + (showRemarks ? 1 : 0),
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
                if (showRemarks) Tab(text: settings.text('備註', 'Remarks')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TimetableTab(route: route),
                  _JourneyTab(route: route, initialStopIndex: initialStopIndex),
                  if (showNotices) ProprietaryNoticesTab(route: route),
                  if (showRemarks) _RemarksTab(route: route),
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
    final bool showNlbTimetable =
        route.companies.contains(BusCompany.nlb) &&
        settings.isProprietaryEnabled(ProprietaryEndpoint.nlbProprietaryData);
    if (showNlbTimetable) {
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: NlbTimetablePanel(route: route),
            ),
          ),
          OfficialLinks(route: route),
        ],
      );
    }
    final Map<String, Map<String, List<String>?>>? freq = route.freq;
    if (freq == null || freq.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        children: [
          Center(
            child: Text(
              settings.text('此路線沒有時間表資料', 'No timetable for this route'),
            ),
          ),
          OfficialLinks(route: route),
        ],
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
          Builder(
            builder: (context) {
              final bool isCurrent =
                  serviceMatches &&
                  _isCurrent(entry.key, entry.value, currentTime);
              final ColorScheme scheme = Theme.of(context).colorScheme;
              return ListTile(
                selected: isCurrent,
                title: Text(
                  entry.value == null
                      ? _formatTime(entry.key)
                      : '${_formatTime(entry.key)} - ${_formatTime(entry.value![0])}',
                ),
                trailing: entry.value == null
                    ? null
                    : Text(
                        '${(int.tryParse(entry.value![1]) ?? 0) ~/ 60} ${settings.text('分鐘', 'min')}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isCurrent ? scheme.primary : null,
                              fontWeight: isCurrent ? FontWeight.w700 : null,
                            ),
                      ),
              );
            },
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

class _RemarksTab extends StatefulWidget {
  const _RemarksTab({required this.route});

  final RouteEntry route;

  @override
  State<_RemarksTab> createState() => _RemarksTabState();
}

class _RemarksTabState extends State<_RemarksTab> {
  static const CitybusRemarksService _service = CitybusRemarksService();

  Future<List<CitybusRemarkLine>?>? _future;
  bool _lastEnabled = false;
  String _lastLanguage = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppSettings settings = context.read<AppSettings>();
    final bool enabled = settings.isProprietaryEnabled(
      ProprietaryEndpoint.citybusRemarks,
    );
    if (enabled == _lastEnabled && settings.language == _lastLanguage) return;
    _lastEnabled = enabled;
    _lastLanguage = settings.language;
    _future = _load(settings);
  }

  Future<List<CitybusRemarkLine>?>? _load(AppSettings settings) {
    if (!settings.isProprietaryEnabled(ProprietaryEndpoint.citybusRemarks)) {
      return null;
    }
    return _service.fetchRemarks(widget.route, zh: settings.isChinese);
  }

  void _retry() {
    final AppSettings settings = context.read<AppSettings>();
    setState(() => _future = _load(settings));
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = context.watch<AppSettings>();
    if (!settings.isProprietaryEnabled(ProprietaryEndpoint.citybusRemarks)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            settings.text(
              '請在設定中啟用城巴路線備註。',
              'Enable Citybus route remarks in Settings to view them.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final Future<List<CitybusRemarkLine>?>? future = _future;
    if (future == null) {
      return const Center(child: M3ELoadingIndicator());
    }
    return FutureBuilder<List<CitybusRemarkLine>?>(
      future: future,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<CitybusRemarkLine>?> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: M3ELoadingIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.text('無法載入備註', 'Unable to load remarks'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      M3EButton.text(
                        onPressed: _retry,
                        child: Text(settings.text('重試', 'Retry')),
                      ),
                    ],
                  ),
                ),
              );
            }
            final List<CitybusRemarkLine> remarks =
                snapshot.data ?? const <CitybusRemarkLine>[];
            if (remarks.isEmpty) {
              return Center(child: Text(settings.text('沒有備註', 'No remarks')));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [_RemarksContent(lines: remarks)],
            );
          },
    );
  }
}

class _RemarksContent extends StatefulWidget {
  const _RemarksContent({required this.lines});

  final List<CitybusRemarkLine> lines;

  @override
  State<_RemarksContent> createState() => _RemarksContentState();
}

class _RemarksContentState extends State<_RemarksContent> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final ThemeData theme = Theme.of(context);
    final TextStyle? base = theme.textTheme.bodyMedium;
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int index = 0; index < widget.lines.length; index++) {
      if (index > 0) spans.add(const TextSpan(text: '\n'));
      final CitybusRemarkLine line = widget.lines[index];
      for (final CitybusRemarkRun run in line.runs) {
        TapGestureRecognizer? recognizer;
        final String? href = run.href;
        if (href != null && href.isNotEmpty) {
          final Uri? uri = Uri.tryParse(href);
          if (uri != null) {
            recognizer = TapGestureRecognizer()
              ..onTap = () =>
                  launchUrl(uri, mode: LaunchMode.externalApplication);
            _recognizers.add(recognizer);
          }
        }
        final TextStyle? style = base?.copyWith(
          fontWeight: run.bold ? FontWeight.bold : null,
          fontStyle: run.italic ? FontStyle.italic : null,
          decoration: run.underline || recognizer != null
              ? TextDecoration.underline
              : null,
          color: recognizer != null ? theme.colorScheme.primary : null,
        );
        spans.add(
          TextSpan(text: run.text, style: style, recognizer: recognizer),
        );
      }
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
