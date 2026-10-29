import 'package:flutter/material.dart';
import 'package:hktransports/dataStore/objectbox.dart';

enum EtaFormat { diff, exact, mixed }

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'zh';
  EtaFormat _etaFormat = EtaFormat.mixed;
  int _refreshSeconds = 30;
  int _textScalePercent = 110;
  bool _routeFilter = false;
  bool _autoRenew = true;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get isChinese => _language == 'zh';
  EtaFormat get etaFormat => _etaFormat;
  int get refreshSeconds => _refreshSeconds;
  int get textScalePercent => _textScalePercent;
  double get textScale => _textScalePercent / 100;
  bool get routeFilter => _routeFilter;
  bool get autoRenew => _autoRenew;

  AppSettings() {
    final int mode = sp.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[mode.clamp(0, 2)];
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
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    sp.setInt('themeMode', mode.index);
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

  String text(String zh, String en) => isChinese ? zh : en;
}
