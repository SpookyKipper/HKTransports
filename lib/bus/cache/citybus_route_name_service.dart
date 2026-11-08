import 'package:hktransports/bus/citybus/citybus_routelist_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

class CitybusRouteNameService {
  const CitybusRouteNameService();

  Future<String?> routeName(RouteEntry route, String language) async {
    if (!route.companies.contains(BusCompany.ctb)) return null;
    if (_isAirportRoute(route.route)) return null;
    return CitybusRoutelistService.instance.routeName(route, language);
  }

  bool _isAirportRoute(String routeNumber) {
    final String route = routeNumber.trim().toUpperCase();
    return route.startsWith('A') || route.startsWith('NA');
  }
}
