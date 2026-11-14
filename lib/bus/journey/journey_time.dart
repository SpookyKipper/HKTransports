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
  final int? parsedJourneyTime = int.tryParse(route.jt?.trim() ?? '');
  final int? journeyTime = parsedJourneyTime != null && parsedJourneyTime > 0
      ? parsedJourneyTime
      : null;
  final bool estimated = journeyTime == null;
  final double totalMinutes =
      journeyTime?.toDouble() ??
      _estimateJourneyMinutes(totalDistance, stops.length);

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

/// Estimates a full-route journey time from stop-to-stop distance.
///
/// The coefficients are calibrated against the routes that include an official
/// journey time. Without this fallback, routes with no timetable data used a
/// flat four minutes per stop, which badly overestimated short, closely spaced
/// routes (for example 117A).
double _estimateJourneyMinutes(double totalDistanceMetres, int stopCount) {
  final double distanceKm = totalDistanceMetres / 1000;
  final double minutes = distanceKm * 2.0 + stopCount * 0.8;
  return minutes.clamp(1, 1440);
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
