import 'package:hktransports/bus/eta/citybus_eta_status_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';

/// Matches Citybus nwp3 rows to open-data ETAs by the closest clock time.
///
/// Unmatched proprietary rows are discarded, and unmatched open-data ETAs are
/// left without a status.
List<BusEta> applyCitybusStatusesByTime(
  List<BusEta> etas,
  List<CitybusEtaStatus>? statuses,
) {
  if (statuses == null || statuses.isEmpty) return etas;

  final Map<int, int> etaMinuteByIndex = <int, int>{};
  for (int index = 0; index < etas.length; index++) {
    final BusEta eta = etas[index];
    final DateTime? time = eta.eta;
    if (eta.company != BusCompany.ctb || time == null) continue;
    final DateTime hkTime = time.toUtc().add(const Duration(hours: 8));
    etaMinuteByIndex[index] = hkTime.hour * 60 + hkTime.minute;
  }
  if (etaMinuteByIndex.isEmpty) return etas;

  final List<int> timedStatusIndexes = <int>[];
  for (int index = 0; index < statuses.length; index++) {
    if (statuses[index].timeMinutes != null) timedStatusIndexes.add(index);
  }

  final Map<int, CitybusEtaStatus> statusByEtaIndex = <int, CitybusEtaStatus>{};
  if (timedStatusIndexes.isEmpty) {
    int statusIndex = 0;
    for (final int etaIndex in etaMinuteByIndex.keys) {
      if (statusIndex >= statuses.length) break;
      statusByEtaIndex[etaIndex] = statuses[statusIndex++];
    }
  } else {
    final List<_StatusCandidate> candidates = <_StatusCandidate>[];
    for (final MapEntry<int, int> etaEntry in etaMinuteByIndex.entries) {
      for (final int statusIndex in timedStatusIndexes) {
        candidates.add(
          _StatusCandidate(
            etaIndex: etaEntry.key,
            statusIndex: statusIndex,
            distance: _minuteDistance(
              etaEntry.value,
              statuses[statusIndex].timeMinutes!,
            ),
          ),
        );
      }
    }
    candidates.sort((_StatusCandidate a, _StatusCandidate b) {
      final int byDistance = a.distance.compareTo(b.distance);
      if (byDistance != 0) return byDistance;
      final int byEta = a.etaIndex.compareTo(b.etaIndex);
      if (byEta != 0) return byEta;
      return a.statusIndex.compareTo(b.statusIndex);
    });

    final Set<int> usedEtas = <int>{};
    final Set<int> usedStatuses = <int>{};
    for (final _StatusCandidate candidate in candidates) {
      if (usedEtas.contains(candidate.etaIndex) ||
          usedStatuses.contains(candidate.statusIndex)) {
        continue;
      }
      usedEtas.add(candidate.etaIndex);
      usedStatuses.add(candidate.statusIndex);
      statusByEtaIndex[candidate.etaIndex] = statuses[candidate.statusIndex];
    }
  }

  if (statusByEtaIndex.isEmpty) return etas;
  final List<BusEta> result = List<BusEta>.of(etas);
  for (final MapEntry<int, CitybusEtaStatus> entry
      in statusByEtaIndex.entries) {
    final CitybusEtaStatus status = entry.value;
    result[entry.key] = result[entry.key].copyWith(
      statusZh: status.statusZh,
      statusEn: status.statusEn,
      distanceKm: status.distanceKm,
    );
  }
  return result;
}

int _minuteDistance(int a, int b) {
  final int direct = (a - b).abs();
  return direct > 720 ? 1440 - direct : direct;
}

class _StatusCandidate {
  const _StatusCandidate({
    required this.etaIndex,
    required this.statusIndex,
    required this.distance,
  });

  final int etaIndex;
  final int statusIndex;
  final int distance;
}
