import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/data/bus_data_updater.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/dataStore/objectbox.dart';

enum BusDataStatus { loading, noData, ready, updating, error }

class RouteStopRef {
  const RouteStopRef({
    required this.route,
    required this.company,
    required this.seq,
  });

  final RouteEntry route;
  final BusCompany company;
  final int seq;
}

class BusRepository extends ChangeNotifier {
  BusRepository(this.settings);

  final AppSettings settings;
  final BusDataUpdater updater = BusDataUpdater();

  BusDataStatus _status = BusDataStatus.loading;
  BusDatabase? _database;
  BusDatabase? _pendingDatabase;
  String? _error;
  double? _progress;
  Map<String, List<RouteStopRef>>? _stopIndex;
  Map<String, Set<String>>? _physicalByCompanyStop;
  List<String>? _savedRoutes;
  List<String>? _recentRoutes;

  BusDataStatus get status => _status;
  BusDatabase? get database => _database;
  BusDatabase? get pendingDatabase => _pendingDatabase;
  String? get error => _error;
  double? get progress => _progress;
  DateTime? get lastUpdate => updater.lastUpdate;
  String? get md5 => updater.storedMd5;

  bool get hasData => _database != null;

  Future<void> initialize() async {
    _status = BusDataStatus.loading;
    notifyListeners();
    final BusDatabase? cached = await updater.loadCached();
    if (cached == null) {
      _status = BusDataStatus.noData;
      notifyListeners();
      return;
    }
    _database = cached;
    _stopIndex = null;
    _status = BusDataStatus.ready;
    notifyListeners();
  }

  Future<bool> checkForUpdate() async {
    if (_database == null) return true;
    try {
      final bool update = await updater.hasUpdate();
      if (!update) updater.markChecked();
      return update;
    } catch (error) {
      debugPrint('Update check failed: $error');
      return false;
    }
  }

  Future<bool> update({bool force = false}) async {
    if (_status == BusDataStatus.updating) return false;
    _status = BusDataStatus.updating;
    _progress = null;
    _error = null;
    notifyListeners();
    try {
      if (!force) {
        final bool needed = await checkForUpdate();
        if (!needed && _database != null) {
          _status = BusDataStatus.ready;
          notifyListeners();
          return false;
        }
      }
      final BusDatabase db = await updater.download(
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );
      _database = db;
      _stopIndex = null;
      _status = BusDataStatus.ready;
      _progress = 1;
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      _status = _database == null ? BusDataStatus.noData : BusDataStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<BusDatabase> loadDownloaded(BusDatabase db) async {
    _database = db;
    _stopIndex = null;
    _status = BusDataStatus.ready;
    notifyListeners();
    return db;
  }

  Future<void> autoCheckIfDue() async {
    if (_database == null) return;
    if (!settings.autoRenew) return;
    if (!await updater.shouldAutoCheck()) return;
    updater.markChecked();
    final bool needed = await checkForUpdate();
    if (needed) {
      await update();
    }
  }

  List<RouteEntry> search(String query) {
    final BusDatabase? db = _database;
    if (db == null) return const [];
    final String q = query.trim().toUpperCase();
    final List<RouteEntry> routes = db.routesByKey.values.toList();
    final List<RouteEntry> filtered = q.isEmpty
        ? routes
        : routes.where((route) {
            if (route.route.toUpperCase().contains(q)) return true;
            if (route.orig.en.toUpperCase().contains(q)) return true;
            if (route.dest.en.toUpperCase().contains(q)) return true;
            if (route.orig.zh.contains(query.trim())) return true;
            if (route.dest.zh.contains(query.trim())) return true;
            return route.companies.any(
              (company) =>
                  company.labelEn.toUpperCase().contains(q) ||
                  company.labelZh.contains(query.trim()),
            );
          }).toList();
    filtered.sort(compareRoutes);
    return filtered;
  }

  List<RouteEntry> routesForNumber(String number) {
    final BusDatabase? db = _database;
    if (db == null) return const [];
    final List<RouteEntry> routes = db.routesForNumber(number);
    final List<RouteEntry> sorted = [...routes]..sort(compareRoutes);
    return sorted;
  }

  RouteEntry? routeBySlug(String slug) => _database?.routeBySlug(slug);

  StopEntry? stopById(String id) => _database?.stops[id];

  String stopIdFor(RouteEntry route, BusCompany company, int seq) {
    return route.stopIdAt(company, seq) ?? '';
  }

  RouteEntry? findReverse(RouteEntry route) {
    final BusDatabase? db = _database;
    if (db == null) return null;
    final List<RouteEntry> candidates =
        (db.routesByNumber[route.route.toUpperCase()] ?? const [])
            .where((candidate) => candidate.key != route.key)
            .where((candidate) {
              final List<String> a = route.companies.map((c) => c.id).toList()
                ..sort();
              final List<String> b =
                  candidate.companies.map((c) => c.id).toList()..sort();
              if (a.join('|') != b.join('|')) return false;
              if (route.companies.contains(BusCompany.gmb) &&
                  route.gtfsId != null &&
                  candidate.gtfsId != route.gtfsId) {
                return false;
              }
              return true;
            })
            .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final bool aSwap =
          a.orig.en == route.dest.en && a.dest.en == route.orig.en;
      final bool bSwap =
          b.orig.en == route.dest.en && b.dest.en == route.orig.en;
      if (aSwap != bSwap) return aSwap ? -1 : 1;
      final int serviceA = int.tryParse(a.serviceType) ?? 99;
      final int serviceB = int.tryParse(b.serviceType) ?? 99;
      return serviceA.compareTo(serviceB);
    });
    return candidates.first;
  }

  List<String> physicalStopIds(BusCompany company, String stopId) {
    final BusDatabase? db = _database;
    if (db == null) return const [];
    _physicalByCompanyStop ??= _buildPhysicalStopIndex(db);
    return (_physicalByCompanyStop!['${company.id}|$stopId'] ?? const {})
        .toList();
  }

  Map<String, Set<String>> _buildPhysicalStopIndex(BusDatabase db) {
    final Map<String, Set<String>> index = {};
    for (final MapEntry<String, List<StopRef>> entry in db.stopMap.entries) {
      for (final StopRef ref in entry.value) {
        index
            .putIfAbsent('${ref.company.id}|${ref.stopId}', () => {})
            .add(entry.key);
      }
    }
    return index;
  }

  List<RouteStopRef> routesAtStop(String physicalStopId) {
    final BusDatabase? db = _database;
    if (db == null) return const [];
    _stopIndex ??= _buildStopIndex(db);
    final List<StopRef> refs = db.stopMap[physicalStopId] ?? const [];
    final List<RouteStopRef> result = [];
    for (final StopRef ref in refs) {
      final List<RouteStopRef>? entries = _stopIndex![ref.stopId];
      if (entries != null) result.addAll(entries);
    }
    return _dedupeStopRoutes(result);
  }

  Map<String, List<RouteStopRef>> _buildStopIndex(BusDatabase db) {
    final Map<String, List<RouteStopRef>> index = {};
    for (final RouteEntry route in db.routesByKey.values) {
      for (final MapEntry<BusCompany, List<String>> company
          in route.stops.entries) {
        for (int seq = 0; seq < company.value.length; seq++) {
          index
              .putIfAbsent(company.value[seq], () => [])
              .add(RouteStopRef(route: route, company: company.key, seq: seq));
        }
      }
    }
    return index;
  }

  List<RouteStopRef> _dedupeStopRoutes(List<RouteStopRef> refs) {
    final List<RouteStopRef> result = [];
    final Set<String> seen = {};
    for (final RouteStopRef ref in refs) {
      final String key = '${ref.route.key}|${ref.company.id}|${ref.seq}';
      if (seen.add(key)) result.add(ref);
    }
    result.sort((a, b) => compareRoutes(a.route, b.route));
    return result;
  }

  List<String> get savedRoutes {
    _savedRoutes ??= _readStringList('savedRoutes');
    return _savedRoutes!;
  }

  List<String> get recentRoutes {
    _recentRoutes ??= _readStringList('recentRoutes');
    return _recentRoutes!;
  }

  bool isSaved(RouteEntry route) => savedRoutes.contains(route.key);

  void toggleSaved(RouteEntry route) {
    final List<String> list = [...savedRoutes];
    if (list.contains(route.key)) {
      list.remove(route.key);
    } else {
      list.add(route.key);
    }
    _savedRoutes = list;
    sp.setString('savedRoutes', jsonEncode(list));
    notifyListeners();
  }

  void addRecent(RouteEntry route) {
    final List<String> list = [...recentRoutes];
    list.remove(route.key);
    list.insert(0, route.key);
    if (list.length > 20) list.removeRange(20, list.length);
    _recentRoutes = list;
    sp.setString('recentRoutes', jsonEncode(list));
    notifyListeners();
  }

  RouteEntry? routeByKey(String key) => _database?.routesByKey[key];

  List<String> _readStringList(String key) {
    final String? raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((dynamic value) => value.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}

int compareRoutes(RouteEntry a, RouteEntry b) {
  final int numberCompare = _compareRouteNumber(a.route, b.route);
  if (numberCompare != 0) return numberCompare;
  final int companyCompare = a.sortedCompanies.first.priority.compareTo(
    b.sortedCompanies.first.priority,
  );
  if (companyCompare != 0) return companyCompare;
  final int serviceCompare = (int.tryParse(a.serviceType) ?? 99).compareTo(
    int.tryParse(b.serviceType) ?? 99,
  );
  if (serviceCompare != 0) return serviceCompare;
  return a.dest.en.compareTo(b.dest.en);
}

int _compareRouteNumber(String a, String b) {
  final int? aNumber = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
  final int? bNumber = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
  if (aNumber != null && bNumber != null && aNumber != bNumber) {
    return aNumber.compareTo(bNumber);
  }
  return a.compareTo(b);
}
