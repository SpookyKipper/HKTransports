import 'package:hktransports/bus/model/bus_models.dart';

enum RouteCategory { all, bus, minibus, train, lightRail, ferry }

extension RouteCategoryInfo on RouteCategory {
  String label(String language) {
    final bool zh = language != 'en';
    switch (this) {
      case RouteCategory.all:
        return zh ? '全部' : 'All';
      case RouteCategory.bus:
        return zh ? '巴士' : 'Bus';
      case RouteCategory.minibus:
        return zh ? '專線小巴' : 'Minibus';
      case RouteCategory.train:
        return zh ? '港鐵' : 'Train';
      case RouteCategory.lightRail:
        return zh ? '輕鐵' : 'Light Rail';
      case RouteCategory.ferry:
        return zh ? '渡輪' : 'Ferry';
    }
  }
}

RouteCategory categoryForCompany(BusCompany company) {
  switch (company) {
    case BusCompany.kmb:
    case BusCompany.ctb:
    case BusCompany.nlb:
    case BusCompany.lrtfeeder:
      return RouteCategory.bus;
    case BusCompany.gmb:
      return RouteCategory.minibus;
    case BusCompany.mtr:
      return RouteCategory.train;
    case BusCompany.lightRail:
      return RouteCategory.lightRail;
    case BusCompany.sunferry:
    case BusCompany.fortuneferry:
    case BusCompany.hkkf:
      return RouteCategory.ferry;
  }
}

bool routeMatchesCategory(RouteEntry route, RouteCategory category) {
  if (category == RouteCategory.all) return true;
  return route.companies.any(
    (BusCompany company) => categoryForCompany(company) == category,
  );
}
