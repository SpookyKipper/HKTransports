import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';

class NlbRouteNameService {
  const NlbRouteNameService();

  Future<String?> routeName(RouteEntry route, String language) {
    if (!route.companies.contains(BusCompany.nlb)) {
      return Future<String?>.value(null);
    }
    return NlbTimetableService.instance.fetchRouteName(route, language);
  }
}
