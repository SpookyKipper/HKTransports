import 'package:hktransports/bus/model/bus_models.dart';

const Map<String, ({String en, String zh})> _mtrLineNames =
    <String, ({String en, String zh})>{
      'AEL': (en: 'Airport Express', zh: '機場快綫'),
      'DRL': (en: 'Disneyland Resort Line', zh: '迪士尼綫'),
      'EAL': (en: 'East Rail Line', zh: '東鐵綫'),
      'ISL': (en: 'Island Line', zh: '港島綫'),
      'KTL': (en: 'Kwun Tong Line', zh: '觀塘綫'),
      'SIL': (en: 'South Island Line', zh: '南港島綫'),
      'TCL': (en: 'Tung Chung Line', zh: '東涌綫'),
      'TKL': (en: 'Tseung Kwan O Line', zh: '將軍澳綫'),
      'TML': (en: 'Tuen Ma Line', zh: '屯馬綫'),
      'TWL': (en: 'Tsuen Wan Line', zh: '荃灣綫'),
    };

/// Display name for a route in the UI.
///
/// MTR line codes become their Chinese names everywhere. In English, the full
/// line name is only used on the route details page; list-style surfaces keep
/// the compact line code.
const double routeCompactColumnWidth = 80;
const double routeWideColumnWidth = 100;

/// Width for the compact route-number/company column in list rows.
double routeColumnWidth(RouteEntry route, String language) {
  if (language == 'en') return routeCompactColumnWidth;
  if (routeDisplayName(route, language) != route.route) {
    return routeWideColumnWidth;
  }
  if (_isCityflyerRoute(route)) return routeWideColumnWidth;
  return routeCompactColumnWidth;
}

bool _isCityflyerRoute(RouteEntry route) {
  if (!route.companies.contains(BusCompany.ctb)) return false;
  final String code = route.route.trim().toUpperCase();
  return code.startsWith('A') || code.startsWith('NA');
}

String routeDisplayName(
  RouteEntry route,
  String language, {
  bool fullEnglish = false,
}) {
  if (!route.companies.contains(BusCompany.mtr)) return route.route;
  final String code = route.route.trim().toUpperCase();
  final ({String en, String zh})? name = _mtrLineNames[code];
  if (name == null) return route.route;
  if (language == 'en') return fullEnglish ? name.en : route.route;
  return name.zh;
}
