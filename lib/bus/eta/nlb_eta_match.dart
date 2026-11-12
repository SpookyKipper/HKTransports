import 'package:hktransports/bus/eta/clients/nlb_eta_data_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';

/// Matches NLB proprietary arrivals to open-data ETAs by their minute value.
List<BusEta> applyNlbWheelchairData(
  List<BusEta> etas,
  List<NlbEtaArrival>? arrivals, {
  DateTime? now,
}) {
  if (arrivals == null || arrivals.isEmpty) return etas;
  final DateTime reference = (now ?? DateTime.now()).toUtc();
  final Map<int, int> etaMinutes = <int, int>{};
  for (int index = 0; index < etas.length; index++) {
    final BusEta eta = etas[index];
    final DateTime? time = eta.eta;
    if (eta.company != BusCompany.nlb || time == null) continue;
    etaMinutes[index] = (time.toUtc().difference(reference).inSeconds / 60)
        .round();
  }
  if (etaMinutes.isEmpty) return etas;

  final List<_WheelchairCandidate> candidates = <_WheelchairCandidate>[];
  for (final MapEntry<int, int> eta in etaMinutes.entries) {
    for (int arrivalIndex = 0; arrivalIndex < arrivals.length; arrivalIndex++) {
      final int distance = (eta.value - arrivals[arrivalIndex].minutes).abs();
      if (distance > 2) continue;
      candidates.add(
        _WheelchairCandidate(
          etaIndex: eta.key,
          arrivalIndex: arrivalIndex,
          distance: distance,
        ),
      );
    }
  }
  candidates.sort((_WheelchairCandidate a, _WheelchairCandidate b) {
    final int byDistance = a.distance.compareTo(b.distance);
    if (byDistance != 0) return byDistance;
    final int byEta = a.etaIndex.compareTo(b.etaIndex);
    if (byEta != 0) return byEta;
    return a.arrivalIndex.compareTo(b.arrivalIndex);
  });

  final Set<int> usedEtas = <int>{};
  final Set<int> usedArrivals = <int>{};
  final List<BusEta> result = List<BusEta>.of(etas);
  bool changed = false;
  for (final _WheelchairCandidate candidate in candidates) {
    if (usedEtas.contains(candidate.etaIndex) ||
        usedArrivals.contains(candidate.arrivalIndex)) {
      continue;
    }
    usedEtas.add(candidate.etaIndex);
    usedArrivals.add(candidate.arrivalIndex);
    if (!arrivals[candidate.arrivalIndex].wheelchair) continue;
    result[candidate.etaIndex] = result[candidate.etaIndex].copyWith(
      wheelchair: true,
    );
    changed = true;
  }
  return changed ? result : etas;
}

class _WheelchairCandidate {
  const _WheelchairCandidate({
    required this.etaIndex,
    required this.arrivalIndex,
    required this.distance,
  });

  final int etaIndex;
  final int arrivalIndex;
  final int distance;
}
