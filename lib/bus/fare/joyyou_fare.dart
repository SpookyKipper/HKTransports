import 'package:hktransports/bus/model/bus_models.dart';

/// Calculates the JoyYou fare from the adult fare at a stop.
///
/// Mirrors the HK Independent Bus ETA derivation:
/// - A/NA/H/P CTB or KMB routes are excluded.
/// - Fares below $2 stay unchanged.
/// - Fares below $10 become $2.0.
/// - Higher fares become 20%, rounded to the nearest $0.1.
String? calculateJoyYouFare({
  required String route,
  required List<BusCompany> companies,
  required double adultFare,
}) {
  final String routeNumber = route.trim().toUpperCase();
  final bool ctbOrKmb =
      companies.contains(BusCompany.ctb) || companies.contains(BusCompany.kmb);
  if (ctbOrKmb &&
      (routeNumber.startsWith('A') ||
          routeNumber.startsWith('NA') ||
          routeNumber.startsWith('H') ||
          routeNumber.startsWith('P'))) {
    return null;
  }
  if (adultFare < 2) return _formatFare(adultFare);
  if (adultFare < 10) return '2.0';
  return ((adultFare * 2).round() / 10).toStringAsFixed(1);
}

String _formatFare(double fare) {
  String value = fare.toStringAsFixed(2);
  value = value.replaceFirst(RegExp(r'\.?0+$'), '');
  return value.isEmpty ? '0' : value;
}
