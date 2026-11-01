import 'dart:math' as math;

import 'package:hktransports/bus/data/bus_repository.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class NearbyRouteResult {
  const NearbyRouteResult({
    required this.route,
    required this.stop,
    required this.routeStopId,
    required this.distanceMeters,
  });

  final RouteEntry route;
  final StopEntry stop;
  final String routeStopId;
  final double distanceMeters;
}

List<NearbyRouteResult> findNearbyRoutes({
  required BusDatabase? database,
  required List<RouteStopRef> Function(String physicalStopId) routesAtStop,
  required double latitude,
  required double longitude,
  required double radiusMeters,
}) {
  if (database == null || radiusMeters <= 0) return const [];

  final double latDelta = radiusMeters / 111320.0;
  final double cosLat = math.cos(latitude * math.pi / 180).abs();
  final double lngDelta = radiusMeters / (111320.0 * math.max(cosLat, 0.01));

  final Map<String, NearbyRouteResult> nearestByRoute = {};
  for (final StopEntry stop in database.stops.values) {
    if (stop.lat.abs() > 90 || stop.lng.abs() > 180) continue;
    if ((stop.lat - latitude).abs() > latDelta) continue;
    if ((stop.lng - longitude).abs() > lngDelta) continue;

    final double distance = distanceMetersBetween(
      latitude,
      longitude,
      stop.lat,
      stop.lng,
    );
    if (distance > radiusMeters) continue;

    for (final RouteStopRef ref in routesAtStop(stop.id)) {
      final NearbyRouteResult? existing = nearestByRoute[ref.route.key];
      if (existing != null && existing.distanceMeters <= distance) continue;
      final String routeStopId = _routeStopId(database, ref, stop.id);
      if (routeStopId.isEmpty) continue;
      nearestByRoute[ref.route.key] = NearbyRouteResult(
        route: ref.route,
        stop: stop,
        routeStopId: routeStopId,
        distanceMeters: distance,
      );
    }
  }

  final List<NearbyRouteResult> results = nearestByRoute.values.toList();
  results.sort((NearbyRouteResult a, NearbyRouteResult b) {
    final int distanceCompare = a.distanceMeters.compareTo(b.distanceMeters);
    if (distanceCompare != 0) return distanceCompare;
    return compareRoutes(a.route, b.route);
  });
  return results;
}

double distanceMetersBetween(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const double earthRadius = 6371000;
  final double phi1 = lat1 * math.pi / 180;
  final double phi2 = lat2 * math.pi / 180;
  final double deltaPhi = (lat2 - lat1) * math.pi / 180;
  final double deltaLambda = (lng2 - lng1) * math.pi / 180;
  final double h =
      math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLambda / 2) *
          math.sin(deltaLambda / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

String _routeStopId(
  BusDatabase database,
  RouteStopRef ref,
  String physicalStopId,
) {
  final RouteEntry route = ref.route;
  final List<String> primaryStops = route.primaryStops;
  final String refStopId = route.stopIdAt(ref.company, ref.seq) ?? '';
  if (primaryStops.contains(refStopId)) return refStopId;

  final BusCompany? primaryCompany = route.primaryCompany;
  final List<StopRef>? physicalStops = database.stopMap[physicalStopId];
  if (primaryCompany != null && physicalStops != null) {
    for (final StopRef stopRef in physicalStops) {
      if (stopRef.company == primaryCompany &&
          primaryStops.contains(stopRef.stopId)) {
        return stopRef.stopId;
      }
    }
  }

  if (ref.seq >= 0 && ref.seq < primaryStops.length) {
    return primaryStops[ref.seq];
  }
  return primaryStops.isNotEmpty ? primaryStops.first : '';
}
