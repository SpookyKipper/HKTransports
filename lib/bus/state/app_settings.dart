import 'package:flutter/material.dart';
import 'package:hktransports/dataStore/objectbox.dart';

enum EtaFormat { diff, exact, mixed }

enum AutoUpdateNetwork { wifiOnly, wifiOrMobile }

extension AutoUpdateNetworkInfo on AutoUpdateNetwork {
  String label(String language) {
    final bool zh = language != 'en';
    switch (this) {
      case AutoUpdateNetwork.wifiOnly:
        return zh ? '僅 Wi-Fi' : 'Wi-Fi only';
      case AutoUpdateNetwork.wifiOrMobile:
        return zh ? 'Wi-Fi 或流動數據' : 'Wi-Fi or mobile data';
    }
  }
}

enum ProprietaryGroup { notice, kmb, citybus, nlb }

enum ProprietaryEndpoint {
  noticeFeed,
  kmbAnnouncements,
  kmbInterchange,
  kmbRouteDatabase,
  kmbEtaStatus,
  citybusSpecialNotices,
  citybusRouteNotices,
  citybusStopNotices,
  citybusRemarks,
  citybusInterchange,
  citybusDatabase,
  citybusEtaStatus,
  nlbProprietaryData,
  nlbRouteNotices,
}

extension ProprietaryEndpointInfo on ProprietaryEndpoint {
  String get storageKey => 'proprietary.endpoint.$name';

  String get configKey {
    switch (this) {
      case ProprietaryEndpoint.noticeFeed:
        return 'hkbus-notice';
      case ProprietaryEndpoint.kmbAnnouncements:
        return 'kmb-routenotice';
      case ProprietaryEndpoint.kmbInterchange:
        return 'kmb-interchange';
      case ProprietaryEndpoint.kmbRouteDatabase:
        return 'kmb-routedata';
      case ProprietaryEndpoint.kmbEtaStatus:
        return 'kmb-eta';
      case ProprietaryEndpoint.citybusSpecialNotices:
        return 'ctb-specialnotice';
      case ProprietaryEndpoint.citybusRouteNotices:
        return 'ctb-routenotice';
      case ProprietaryEndpoint.citybusStopNotices:
        return 'ctb-stationnotice';
      case ProprietaryEndpoint.citybusRemarks:
        return 'ctb-routeremark';
      case ProprietaryEndpoint.citybusInterchange:
        return 'ctb-interchange';
      case ProprietaryEndpoint.citybusDatabase:
        return 'ctb-routedata';
      case ProprietaryEndpoint.citybusEtaStatus:
        return 'ctb-eta';
      case ProprietaryEndpoint.nlbProprietaryData:
        return 'nlb-routedata';
      case ProprietaryEndpoint.nlbRouteNotices:
        return 'nlb-routenotice';
    }
  }

  String get legacyKey {
    switch (this) {
      case ProprietaryEndpoint.noticeFeed:
        return 'proprietary.notice';
      case ProprietaryEndpoint.kmbAnnouncements:
      case ProprietaryEndpoint.kmbInterchange:
        return 'proprietary.kmb';
      case ProprietaryEndpoint.kmbRouteDatabase:
        return 'proprietary.kmb.routedata';
      case ProprietaryEndpoint.kmbEtaStatus:
        return 'proprietary.kmb.etaStatus';
      case ProprietaryEndpoint.citybusSpecialNotices:
      case ProprietaryEndpoint.citybusRouteNotices:
      case ProprietaryEndpoint.citybusStopNotices:
      case ProprietaryEndpoint.citybusRemarks:
      case ProprietaryEndpoint.citybusInterchange:
      case ProprietaryEndpoint.citybusDatabase:
        return 'proprietary.citybus';
      case ProprietaryEndpoint.citybusEtaStatus:
        return 'proprietary.citybus.etaStatus';
      case ProprietaryEndpoint.nlbProprietaryData:
        return 'proprietary.nlb.data';
      case ProprietaryEndpoint.nlbRouteNotices:
        return 'proprietary.nlb.routeNotice';
    }
  }

  ProprietaryGroup get group {
    switch (this) {
      case ProprietaryEndpoint.noticeFeed:
        return ProprietaryGroup.notice;
      case ProprietaryEndpoint.kmbAnnouncements:
      case ProprietaryEndpoint.kmbInterchange:
      case ProprietaryEndpoint.kmbRouteDatabase:
      case ProprietaryEndpoint.kmbEtaStatus:
        return ProprietaryGroup.kmb;
      case ProprietaryEndpoint.citybusSpecialNotices:
      case ProprietaryEndpoint.citybusRouteNotices:
      case ProprietaryEndpoint.citybusStopNotices:
      case ProprietaryEndpoint.citybusRemarks:
      case ProprietaryEndpoint.citybusInterchange:
      case ProprietaryEndpoint.citybusDatabase:
      case ProprietaryEndpoint.citybusEtaStatus:
        return ProprietaryGroup.citybus;
      case ProprietaryEndpoint.nlbProprietaryData:
      case ProprietaryEndpoint.nlbRouteNotices:
        return ProprietaryGroup.nlb;
    }
  }

  String label(AppSettings settings) {
    switch (this) {
      case ProprietaryEndpoint.noticeFeed:
        return 'notice.hkbus.app';
      case ProprietaryEndpoint.kmbAnnouncements:
        return settings.text('九巴/龍運路線通告', 'KMB/LWB route announcements');
      case ProprietaryEndpoint.kmbInterchange:
        return settings.text('九巴/龍運轉乘優惠', 'KMB/LWB interchange discounts');
      case ProprietaryEndpoint.kmbRouteDatabase:
        return settings.text('九巴/龍運路線資料庫', 'KMB/LWB route data');
      case ProprietaryEndpoint.kmbEtaStatus:
        return settings.text('九巴/龍運實時到站', 'KMB/LWB live ETA');
      case ProprietaryEndpoint.citybusSpecialNotices:
        return settings.text('城巴特別通告', 'Citybus special notices');
      case ProprietaryEndpoint.citybusRouteNotices:
        return settings.text('城巴路線通告', 'Citybus route notices');
      case ProprietaryEndpoint.citybusStopNotices:
        return settings.text('城巴站務通告', 'Citybus stop notices');
      case ProprietaryEndpoint.citybusRemarks:
        return settings.text('城巴路線備註', 'Citybus route remarks');
      case ProprietaryEndpoint.citybusInterchange:
        return settings.text('城巴轉乘優惠', 'Citybus interchange discounts');
      case ProprietaryEndpoint.citybusDatabase:
        return settings.text('城巴路線資料庫', 'Citybus route database');
      case ProprietaryEndpoint.citybusEtaStatus:
        return settings.text('城巴實時到站狀態', 'Citybus live ETA status');
      case ProprietaryEndpoint.nlbProprietaryData:
        return settings.text('嶼巴路線資料', 'NLB route data');
      case ProprietaryEndpoint.nlbRouteNotices:
        return settings.text('嶼巴路線通告', 'NLB route notices');
    }
  }

  String description(AppSettings settings) {
    switch (this) {
      case ProprietaryEndpoint.noticeFeed:
        return settings.text('HK Bus ETA 通告服務', 'HK Bus ETA notices');
      case ProprietaryEndpoint.kmbAnnouncements:
        return settings.text('九巴路線最新消息', 'KMB route news');
      case ProprietaryEndpoint.kmbInterchange:
        return settings.text(
          '九巴/龍運轉乘優惠資料 ~ 61 MB',
          'KMB/LWB transfer data ~ 61 MB',
        );
      case ProprietaryEndpoint.kmbRouteDatabase:
        return settings.text(
          '擴展車站名稱及特別班次描述 ~ 6.5 MB',
          'Extended stop names and special departure descriptions ~ 6.5 MB',
        );
      case ProprietaryEndpoint.kmbEtaStatus:
        return settings.text(
          '實時距離、太陽能及載客量',
          'Live distance, solar bus and passenger load',
        );
      case ProprietaryEndpoint.citybusSpecialNotices:
        return settings.text('城巴特別通告', 'Citybus special notices');
      case ProprietaryEndpoint.citybusRouteNotices:
        return settings.text('城巴路線乘客通告', 'Citybus route passenger notices');
      case ProprietaryEndpoint.citybusStopNotices:
        return settings.text('城巴站務通告', 'Citybus stop notices');
      case ProprietaryEndpoint.citybusRemarks:
        return settings.text('城巴路線備註', 'Citybus route remarks');
      case ProprietaryEndpoint.citybusInterchange:
        return settings.text('城巴轉乘優惠資料', 'Citybus interchange data');
      case ProprietaryEndpoint.citybusDatabase:
        return settings.text(
          '路線名稱、車站地標、車費及特別路線說明 ~ 65 MB',
          'Route names, stop landmarks, fares, and special route descriptions ~ 65 MB',
        );
      case ProprietaryEndpoint.citybusEtaStatus:
        return settings.text(
          '未開出及距離等狀態 · 需城巴路線資料庫',
          'Not yet departed, distance status etc. · requires Citybus route database',
        );
      case ProprietaryEndpoint.nlbProprietaryData:
        return settings.text(
          '車費、附近地標及官方時間表',
          'Fares, nearby landmarks, and official timetable',
        );
      case ProprietaryEndpoint.nlbRouteNotices:
        return settings.text('官方路線通告', 'Official route notices');
    }
  }
}

extension ProprietaryGroupInfo on ProprietaryGroup {
  String label(AppSettings settings) {
    switch (this) {
      case ProprietaryGroup.notice:
        return settings.text('通告服務', 'Notice service');
      case ProprietaryGroup.kmb:
        return settings.text('九巴/龍運', 'KMB / LWB');
      case ProprietaryGroup.citybus:
        return settings.text('城巴', 'Citybus');
      case ProprietaryGroup.nlb:
        return settings.text('嶼巴', 'NLB');
    }
  }
}

enum PageTransitionStyle {
  fade,
  predictiveBack,
  predictiveBackFullscreen,
  cupertino,
  zoom,
  fadeUpwards,
  openUpwards,
}

extension PageTransitionStyleInfo on PageTransitionStyle {
  String label(String language) {
    final bool zh = language != 'en';
    switch (this) {
      case PageTransitionStyle.fade:
        return zh ? '淡入（預設）' : 'Fade (default)';
      case PageTransitionStyle.predictiveBack:
        return zh ? '預測返回' : 'Predictive back';
      case PageTransitionStyle.predictiveBackFullscreen:
        return zh ? '預測返回（全螢幕）' : 'Predictive back (fullscreen)';
      case PageTransitionStyle.cupertino:
        return zh ? '滑動' : 'Slide';
      case PageTransitionStyle.zoom:
        return zh ? '縮放' : 'Zoom';
      case PageTransitionStyle.fadeUpwards:
        return zh ? '向上淡入' : 'Fade upwards';
      case PageTransitionStyle.openUpwards:
        return zh ? '向上展開' : 'Open upwards';
    }
  }
}

enum AppThemeChoice {
  systemDynamic,
  lightDynamic,
  darkDynamic,
  lightPurple,
  darkPurple,
}

extension AppThemeChoiceInfo on AppThemeChoice {
  bool get isPurple =>
      this == AppThemeChoice.lightPurple || this == AppThemeChoice.darkPurple;

  ThemeMode get themeMode {
    switch (this) {
      case AppThemeChoice.systemDynamic:
        return ThemeMode.system;
      case AppThemeChoice.lightDynamic:
      case AppThemeChoice.lightPurple:
        return ThemeMode.light;
      case AppThemeChoice.darkDynamic:
      case AppThemeChoice.darkPurple:
        return ThemeMode.dark;
    }
  }

  String label(String language) {
    final bool zh = language != 'en';
    switch (this) {
      case AppThemeChoice.systemDynamic:
        return zh ? '跟隨系統' : 'System';
      case AppThemeChoice.lightDynamic:
        return zh ? '淺色（動態色彩）' : 'Light (dynamic color)';
      case AppThemeChoice.darkDynamic:
        return zh ? '深色（動態色彩）' : 'Dark (dynamic color)';
      case AppThemeChoice.lightPurple:
        return zh ? '淺色（紫色）' : 'Light (purple)';
      case AppThemeChoice.darkPurple:
        return zh ? '深色（紫色）' : 'Dark (purple)';
    }
  }
}

class AppSettings extends ChangeNotifier {
  AppThemeChoice _themeChoice = AppThemeChoice.systemDynamic;
  PageTransitionStyle _transitionStyle = PageTransitionStyle.fade;
  String _language = 'zh';
  EtaFormat _etaFormat = EtaFormat.mixed;
  int _refreshSeconds = 30;
  int _textScalePercent = 110;
  bool _routeFilter = false;
  bool _showJoyYouFare = false;
  bool _dimMapInDarkMode = true;
  bool _autoRenew = true;
  int _autoUpdateHours = 24;
  AutoUpdateNetwork _autoUpdateNetwork = AutoUpdateNetwork.wifiOrMobile;
  bool _upstreamEtaScan = false;
  bool _locationEnabled = false;
  int _nearbyRadiusMeters = 200;
  String? _lastHomeTabId;
  final Set<ProprietaryEndpoint> _proprietaryEndpoints = {};

  AppThemeChoice get themeChoice => _themeChoice;
  ThemeMode get themeMode => _themeChoice.themeMode;
  bool get usesPurpleTheme => _themeChoice.isPurple;
  PageTransitionStyle get transitionStyle => _transitionStyle;
  String get language => _language;
  bool get isChinese => _language == 'zh';
  EtaFormat get etaFormat => _etaFormat;
  int get refreshSeconds => _refreshSeconds;
  int get textScalePercent => _textScalePercent;
  double get textScale => _textScalePercent / 100;
  bool get routeFilter => _routeFilter;
  bool get showJoyYouFare => _showJoyYouFare;
  bool get dimMapInDarkMode => _dimMapInDarkMode;
  bool get autoRenew => _autoRenew;
  int get autoUpdateHours => _autoUpdateHours;
  AutoUpdateNetwork get autoUpdateNetwork => _autoUpdateNetwork;
  bool get upstreamEtaScan => _upstreamEtaScan;
  bool get locationEnabled => _locationEnabled;
  int get nearbyRadiusMeters => _nearbyRadiusMeters;
  String? get lastHomeTabId => _lastHomeTabId;
  Set<ProprietaryEndpoint> get proprietaryEndpoints =>
      Set.unmodifiable(_proprietaryEndpoints);
  bool isProprietaryEnabled(ProprietaryEndpoint endpoint) =>
      _proprietaryEndpoints.contains(endpoint);
  bool get useProprietaryNotice =>
      isProprietaryEnabled(ProprietaryEndpoint.noticeFeed);

  AppSettings() {
    final String? storedChoice = sp.getString('themeChoice');
    if (storedChoice != null) {
      _themeChoice = AppThemeChoice.values.firstWhere(
        (value) => value.name == storedChoice,
        orElse: () => AppThemeChoice.systemDynamic,
      );
    } else {
      final int mode = sp.getInt('themeMode') ?? 0;
      _themeChoice = switch (mode) {
        1 => AppThemeChoice.lightDynamic,
        2 => AppThemeChoice.darkDynamic,
        _ => AppThemeChoice.systemDynamic,
      };
    }
    final String storedTransition = sp.getString('pageTransition') ?? 'fade';
    _transitionStyle = PageTransitionStyle.values.firstWhere(
      (style) => style.name == storedTransition,
      orElse: () => PageTransitionStyle.fade,
    );
    final String storedLanguage = (sp.getString('appLanguage') ?? 'zh')
        .toLowerCase();
    _language = storedLanguage.startsWith('en') ? 'en' : 'zh';
    final String format = sp.getString('etaFormat') ?? 'mixed';
    _etaFormat = EtaFormat.values.firstWhere(
      (value) => value.name == format,
      orElse: () => EtaFormat.mixed,
    );
    _refreshSeconds = (sp.getInt('refreshSeconds') ?? 30).clamp(5, 120);
    _textScalePercent = (sp.getInt('textScalePercent') ?? 110).clamp(80, 160);
    _routeFilter = sp.getBool('routeFilter') ?? false;
    _showJoyYouFare = sp.getBool('showJoyYouFare') ?? false;
    _dimMapInDarkMode = sp.getBool('dimMapInDarkMode') ?? true;
    _autoRenew = sp.getBool('autoRenew') ?? true;
    _autoUpdateHours = (sp.getInt('autoUpdateHours') ?? 24).clamp(1, 168);
    final String storedNetwork =
        sp.getString('autoUpdateNetwork') ??
        AutoUpdateNetwork.wifiOrMobile.name;
    _autoUpdateNetwork = AutoUpdateNetwork.values.firstWhere(
      (AutoUpdateNetwork value) => value.name == storedNetwork,
      orElse: () => AutoUpdateNetwork.wifiOrMobile,
    );
    _upstreamEtaScan = sp.getBool('upstreamEtaScan') ?? false;
    _locationEnabled = sp.getBool('locationEnabled') ?? false;
    _nearbyRadiusMeters = (sp.getInt('nearbyRadiusMeters') ?? 200).clamp(
      20,
      2000,
    );
    final String? lastTab = sp.getString('lastHomeTabId');
    _lastHomeTabId = lastTab == null || lastTab.isEmpty ? null : lastTab;
    for (final ProprietaryEndpoint endpoint in ProprietaryEndpoint.values) {
      final bool enabled =
          sp.getBool(endpoint.storageKey) ??
          sp.getBool(endpoint.legacyKey) ??
          false;
      if (enabled) _proprietaryEndpoints.add(endpoint);
    }
  }

  void setThemeChoice(AppThemeChoice choice) {
    if (_themeChoice == choice) return;
    _themeChoice = choice;
    sp.setString('themeChoice', choice.name);
    notifyListeners();
  }

  void setTransitionStyle(PageTransitionStyle style) {
    if (_transitionStyle == style) return;
    _transitionStyle = style;
    sp.setString('pageTransition', style.name);
    notifyListeners();
  }

  void setLanguage(String language) {
    final String next = language == 'en' ? 'en' : 'zh';
    if (_language == next) return;
    _language = next;
    sp.setString('appLanguage', next);
    notifyListeners();
  }

  void setEtaFormat(EtaFormat format) {
    if (_etaFormat == format) return;
    _etaFormat = format;
    sp.setString('etaFormat', format.name);
    notifyListeners();
  }

  void setRefreshSeconds(int seconds) {
    final int next = seconds.clamp(5, 120);
    if (_refreshSeconds == next) return;
    _refreshSeconds = next;
    sp.setInt('refreshSeconds', next);
    notifyListeners();
  }

  void setTextScalePercent(int percent) {
    final int next = percent.clamp(80, 160);
    if (_textScalePercent == next) return;
    _textScalePercent = next;
    sp.setInt('textScalePercent', next);
    notifyListeners();
  }

  void setRouteFilter(bool value) {
    if (_routeFilter == value) return;
    _routeFilter = value;
    sp.setBool('routeFilter', value);
    notifyListeners();
  }

  void setShowJoyYouFare(bool value) {
    if (_showJoyYouFare == value) return;
    _showJoyYouFare = value;
    sp.setBool('showJoyYouFare', value);
    notifyListeners();
  }

  void setDimMapInDarkMode(bool value) {
    if (_dimMapInDarkMode == value) return;
    _dimMapInDarkMode = value;
    sp.setBool('dimMapInDarkMode', value);
    notifyListeners();
  }

  void setAutoRenew(bool value) {
    if (_autoRenew == value) return;
    _autoRenew = value;
    sp.setBool('autoRenew', value);
    notifyListeners();
  }

  void setAutoUpdateHours(int hours) {
    final int next = hours.clamp(1, 168);
    if (_autoUpdateHours == next) return;
    _autoUpdateHours = next;
    sp.setInt('autoUpdateHours', next);
    notifyListeners();
  }

  void setAutoUpdateNetwork(AutoUpdateNetwork network) {
    if (_autoUpdateNetwork == network) return;
    _autoUpdateNetwork = network;
    sp.setString('autoUpdateNetwork', network.name);
    notifyListeners();
  }

  void setUpstreamEtaScan(bool value) {
    if (_upstreamEtaScan == value) return;
    _upstreamEtaScan = value;
    sp.setBool('upstreamEtaScan', value);
    notifyListeners();
  }

  void setLocationEnabled(bool value) {
    if (_locationEnabled == value) return;
    _locationEnabled = value;
    sp.setBool('locationEnabled', value);
    notifyListeners();
  }

  void setNearbyRadiusMeters(int meters) {
    final int next = meters.clamp(20, 2000);
    if (_nearbyRadiusMeters == next) return;
    _nearbyRadiusMeters = next;
    sp.setInt('nearbyRadiusMeters', next);
    notifyListeners();
  }

  void setLastHomeTabId(String id) {
    if (_lastHomeTabId == id) return;
    _lastHomeTabId = id;
    sp.setString('lastHomeTabId', id);
    notifyListeners();
  }

  void setProprietaryEndpoint(ProprietaryEndpoint endpoint, bool enabled) {
    final bool changed = enabled
        ? _proprietaryEndpoints.add(endpoint)
        : _proprietaryEndpoints.remove(endpoint);
    if (!changed) return;
    sp.setBool(endpoint.storageKey, enabled);
    notifyListeners();
  }

  String text(String zh, String en) => isChinese ? zh : en;
}
