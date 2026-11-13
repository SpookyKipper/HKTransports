import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';

class NlbRouteNameService {
  const NlbRouteNameService();

  Future<NlbRouteInfo?> routeInfo(RouteEntry route, String language) {
    if (!route.companies.contains(BusCompany.nlb)) {
      return Future<NlbRouteInfo?>.value(null);
    }
    return NlbTimetableService.instance.fetchRouteInfo(route, language);
  }

  Future<String?> routeName(RouteEntry route, String language) async {
    final NlbRouteInfo? info = await routeInfo(route, language);
    return info?.name;
  }

  Future<bool> isSpecial(RouteEntry route, String language) async {
    final NlbRouteInfo? info = await routeInfo(route, language);
    return info?.special ?? false;
  }
}
