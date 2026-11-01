import 'dart:math' as math;

import 'package:hktransports/bus/model/bus_models.dart';

class JourneyEstimate {
  const JourneyEstimate({
    required this.cumulativeMinutes,
    required this.totalMinutes,
    required this.estimated,
  });

  final List<int> cumulativeMinutes;
  final int totalMinutes;
  final bool estimated;
}

JourneyEstimate estimateJourney({
  required RouteEntry route,
  required List<StopEntry> stops,
  required int startSeq,
}) {
  if (stops.length < 2) {
    return const JourneyEstimate(
      cumulativeMinutes: <int>[0],
      totalMinutes: 0,
      estimated: true,
    );
  }
  final int safeStart = startSeq.clamp(0, stops.length - 1);
  final List<double> distances = [];
  for (int index = 0; index < stops.length - 1; index++) {
    distances.add(_distanceMetres(stops[index], stops[index + 1]));
  }
  final double totalDistance = distances.fold(0, (a, b) => a + b);
  final int? jt = int.tryParse(route.jt ?? '');
  final bool estimated = jt == null;
  final double totalMinutes = (jt ?? (distances.length * 4)).toDouble();

  final List<double> segmentMinutes = [];
  for (final double distance in distances) {
    if (totalDistance <= 0) {
      segmentMinutes.add(totalMinutes / distances.length);
    } else {
      segmentMinutes.add(totalMinutes * distance / totalDistance);
    }
  }

  final List<int> cumulative = [];
  double running = 0;
  for (int index = safeStart; index < stops.length; index++) {
    if (index > safeStart) {
      running += segmentMinutes[index - 1];
    }
    cumulative.add(running.round());
  }
  final int remaining = cumulative.isEmpty ? 0 : cumulative.last;
  return JourneyEstimate(
    cumulativeMinutes: cumulative,
    totalMinutes: remaining,
    estimated: estimated,
  );
}

double _distanceMetres(StopEntry a, StopEntry b) {
  const double earthRadius = 6371000;
  final double lat1 = a.lat * math.pi / 180;
  final double lat2 = b.lat * math.pi / 180;
  final double deltaLat = (b.lat - a.lat) * math.pi / 180;
  final double deltaLng = (b.lng - a.lng) * math.pi / 180;
  final double h =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
