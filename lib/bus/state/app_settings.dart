import 'package:flutter/material.dart';
import 'package:hktransports/dataStore/objectbox.dart';

enum EtaFormat { diff, exact, mixed }

enum ProprietaryDataSource { notice, kmb, citybus }

extension ProprietaryDataSourceInfo on ProprietaryDataSource {
  String get storageKey => 'proprietary.${name}';

  String label(AppSettings settings) {
    switch (this) {
      case ProprietaryDataSource.notice:
        return 'notice.hkbus.app';
      case ProprietaryDataSource.kmb:
        return settings.text('九巴專有 API', 'KMB Proprietary API');
      case ProprietaryDataSource.citybus:
        return settings.text('城巴專有 API', 'Citybus Proprietary API');
    }
  }

  String description(AppSettings settings) {
    switch (this) {
      case ProprietaryDataSource.notice:
        return settings.text('HK Bus ETA 通告服務', 'HK Bus ETA notices');
      case ProprietaryDataSource.kmb:
        return settings.text(
          '路線最新消息及轉乘優惠',
          'Route news and transfer discounts',
        );
      case ProprietaryDataSource.citybus:
        return settings.text('特別、路線及站務通告', 'Special, route and stop notices');
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
  bool _autoRenew = true;
  int _autoUpdateHours = 24;
  final Set<ProprietaryDataSource> _proprietarySources = {};

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
  bool get autoRenew => _autoRenew;
  int get autoUpdateHours => _autoUpdateHours;
  Set<ProprietaryDataSource> get proprietarySources =>
      Set.unmodifiable(_proprietarySources);
  bool isProprietaryEnabled(ProprietaryDataSource source) =>
      _proprietarySources.contains(source);
  bool get useProprietaryNotice =>
      isProprietaryEnabled(ProprietaryDataSource.notice);

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
    _autoRenew = sp.getBool('autoRenew') ?? true;
    _autoUpdateHours = (sp.getInt('autoUpdateHours') ?? 24).clamp(1, 168);
    for (final ProprietaryDataSource source in ProprietaryDataSource.values) {
      if (sp.getBool(source.storageKey) ?? false) {
        _proprietarySources.add(source);
      }
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

  void setProprietarySource(ProprietaryDataSource source, bool enabled) {
    final bool changed = enabled
        ? _proprietarySources.add(source)
        : _proprietarySources.remove(source);
    if (!changed) return;
    sp.setBool(source.storageKey, enabled);
    notifyListeners();
  }

  String text(String zh, String en) => isChinese ? zh : en;
}
