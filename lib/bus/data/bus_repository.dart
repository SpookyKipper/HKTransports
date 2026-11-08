import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/data/bus_data_updater.dart';
import 'package:hktransports/bus/data/network_policy.dart';
import 'package:hktransports/bus/data/route_search.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/favorite_group.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';
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
  List<FavoriteGroup>? _customGroups;
  List<String>? _favoriteGroupOrder;
  Timer? _autoTimer;
  bool _checking = false;

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

  void startAutoUpdate() {
    _autoTimer?.cancel();
    unawaited(_initialDataCheck());
    _autoTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => unawaited(_periodicDataCheck()),
    );
  }

  Future<void> _initialDataCheck() async {
    await ensureDataAvailable();
    await autoCheckIfDue();
  }

  Future<void> _periodicDataCheck() async {
    await ensureDataAvailable();
    await autoCheckIfDue();
  }

  Future<void> ensureDataAvailable() async {
    if (_status == BusDataStatus.updating) return;
    if (_database == null || updater.isCompletelyOutdated) {
      if (!await AutoUpdateNetworkPolicy.allows(settings.autoUpdateNetwork)) {
        return;
      }
      final bool updated = await update();
      if (updated) await const BbiService().clearCache();
    }
  }

  Future<void> autoCheckIfDue() async {
    if (_database == null) return;
    if (!settings.autoRenew) return;
    if (_checking) return;
    if (!await AutoUpdateNetworkPolicy.allows(settings.autoUpdateNetwork)) {
      return;
    }
    if (!await updater.shouldAutoCheck(settings.autoUpdateHours)) return;
    _checking = true;
    try {
      final bool needed = await checkForUpdate();
      if (needed) {
        final bool updated = await update(force: true);
        if (updated) await const BbiService().clearCache();
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
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

  List<RouteEntry> searchRouteNumbers(String query) {
    final BusDatabase? db = _database;
    if (db == null) return const [];
    final String prefix = query.trim().toUpperCase();
    final List<RouteEntry> routes = db.routesByKey.values
        .where((route) => route.route.toUpperCase().startsWith(prefix))
        .toList();
    routes.sort(compareRoutes);
    return routes;
  }

  Set<String> possibleRouteChars(String query) {
    final BusDatabase? db = _database;
    if (db == null) return const {};
    return possibleRouteCharsFor(
      db.routesByKey.values.map((route) => route.route),
      query,
    );
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

  List<FavoriteGroup> get favoriteGroups {
    _customGroups ??= _readFavoriteGroups();
    _favoriteGroupOrder ??= _readStringList('favoriteGroupOrder');
    final Map<String, FavoriteGroup> byId = {
      FavoriteGroup.favoritesId: FavoriteGroup(
        id: FavoriteGroup.favoritesId,
        name: settings.text('常用', 'Favourites'),
        routes: [...savedRoutes],
      ),
      for (final FavoriteGroup group in _customGroups!) group.id: group,
    };
    final List<FavoriteGroup> ordered = [];
    final Set<String> added = {};
    for (final String id in _favoriteGroupOrder!) {
      final FavoriteGroup? group = byId[id];
      if (group != null && added.add(id)) ordered.add(group);
    }
    if (added.add(FavoriteGroup.favoritesId)) {
      ordered.insert(0, byId[FavoriteGroup.favoritesId]!);
    }
    for (final FavoriteGroup group in _customGroups!) {
      if (added.add(group.id)) ordered.add(group);
    }
    return ordered;
  }

  FavoriteGroup? favoriteGroupById(String id) {
    for (final FavoriteGroup group in favoriteGroups) {
      if (group.id == id) return group;
    }
    return null;
  }

  List<FavoriteEntry> entriesInGroup(FavoriteGroup group) {
    return group.routes.map(FavoriteEntry.parse).toList();
  }

  List<RouteEntry> routesInGroup(FavoriteGroup group) {
    return entriesInGroup(group)
        .map((entry) => routeByKey(entry.routeKey))
        .whereType<RouteEntry>()
        .toList();
  }

  bool isRouteInGroup(String groupId, String routeKey) {
    final FavoriteGroup? group = favoriteGroupById(groupId);
    if (group == null) return false;
    return group.routes.any(
      (entry) => FavoriteEntry.parse(entry).routeKey == routeKey,
    );
  }

  bool isRouteInAnyGroup(String routeKey) {
    return favoriteGroups.any(
      (group) => group.routes.any(
        (entry) => FavoriteEntry.parse(entry).routeKey == routeKey,
      ),
    );
  }

  bool isEntryInGroup(String groupId, String routeKey, int seq) {
    final FavoriteGroup? group = favoriteGroupById(groupId);
    if (group == null) return false;
    return group.routes.any((value) {
      final FavoriteEntry entry = FavoriteEntry.parse(value);
      return entry.routeKey == routeKey && entry.seq == seq;
    });
  }

  bool isEntryInAnyGroup(String routeKey, int seq) {
    return favoriteGroups.any(
      (group) => group.routes.any((value) {
        final FavoriteEntry entry = FavoriteEntry.parse(value);
        return entry.routeKey == routeKey && entry.seq == seq;
      }),
    );
  }

  FavoriteGroup? createFavoriteGroup(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    _customGroups ??= _readFavoriteGroups();
    final FavoriteGroup group = FavoriteGroup(
      id: 'group_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      routes: [],
    );
    _customGroups = [..._customGroups!, group];
    _saveFavoriteGroups();
    _saveFavoriteGroupOrder(favoriteGroups);
    notifyListeners();
    return group;
  }

  void renameFavoriteGroup(String id, String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || id == FavoriteGroup.favoritesId) return;
    _customGroups ??= _readFavoriteGroups();
    _customGroups = _customGroups!
        .map((group) => group.id == id ? group.copyWith(name: trimmed) : group)
        .toList();
    _saveFavoriteGroups();
    notifyListeners();
  }

  void reorderFavoriteGroups(int oldIndex, int newIndex) {
    final List<FavoriteGroup> groups = [...favoriteGroups];
    if (oldIndex < 0 || oldIndex >= groups.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= groups.length) return;
    final FavoriteGroup group = groups.removeAt(oldIndex);
    groups.insert(newIndex, group);
    _saveFavoriteGroupOrder(groups);
    notifyListeners();
  }

  void deleteFavoriteGroup(String id) {
    if (id == FavoriteGroup.favoritesId) return;
    _customGroups ??= _readFavoriteGroups();
    _customGroups = _customGroups!.where((group) => group.id != id).toList();
    _favoriteGroupOrder = _favoriteGroupOrder
        ?.where((groupId) => groupId != id)
        .toList();
    _saveFavoriteGroups();
    _saveFavoriteGroupOrder(favoriteGroups);
    notifyListeners();
  }

  void toggleRouteInGroup(String groupId, String routeKey, {int seq = 0}) {
    final String entry = FavoriteEntry.encode(routeKey, seq);
    bool matchesEntry(String value) {
      final FavoriteEntry parsed = FavoriteEntry.parse(value);
      return parsed.routeKey == routeKey && parsed.seq == seq;
    }

    if (groupId == FavoriteGroup.favoritesId) {
      final List<String> list = [...savedRoutes];
      final bool exists = list.any(matchesEntry);
      if (exists) {
        list.removeWhere(matchesEntry);
      } else {
        list.add(entry);
      }
      _savedRoutes = list;
      sp.setString('savedRoutes', jsonEncode(list));
      notifyListeners();
      return;
    }
    _customGroups ??= _readFavoriteGroups();
    _customGroups = _customGroups!.map((group) {
      if (group.id != groupId) return group;
      final List<String> routes = [...group.routes];
      final bool exists = routes.any(matchesEntry);
      if (exists) {
        routes.removeWhere(matchesEntry);
      } else {
        routes.add(entry);
      }
      return group.copyWith(routes: routes);
    }).toList();
    _saveFavoriteGroups();
    notifyListeners();
  }

  void reorderFavoriteGroup(String groupId, int oldIndex, int newIndex) {
    final FavoriteGroup? group = favoriteGroupById(groupId);
    if (group == null) return;
    final List<String> routes = [...group.routes];
    if (oldIndex < 0 || oldIndex >= routes.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= routes.length) return;
    final String item = routes.removeAt(oldIndex);
    routes.insert(newIndex, item);
    if (groupId == FavoriteGroup.favoritesId) {
      _savedRoutes = routes;
      sp.setString('savedRoutes', jsonEncode(routes));
    } else {
      _customGroups ??= _readFavoriteGroups();
      _customGroups = _customGroups!
          .map(
            (group) =>
                group.id == groupId ? group.copyWith(routes: routes) : group,
          )
          .toList();
      _saveFavoriteGroups();
    }
    notifyListeners();
  }

  void setGroupEntries(String groupId, List<FavoriteEntry> entries) {
    final List<String> keys = entries.map((entry) => entry.storageKey).toList();
    if (groupId == FavoriteGroup.favoritesId) {
      _savedRoutes = keys;
      sp.setString('savedRoutes', jsonEncode(keys));
      notifyListeners();
      return;
    }
    _customGroups ??= _readFavoriteGroups();
    _customGroups = _customGroups!
        .map(
          (group) => group.id == groupId ? group.copyWith(routes: keys) : group,
        )
        .toList();
    _saveFavoriteGroups();
    notifyListeners();
  }

  void removeRouteFromGroup(String groupId, String routeKey) {
    if (!isRouteInGroup(groupId, routeKey)) return;
    toggleRouteInGroup(groupId, routeKey);
  }

  List<String> get recentRoutes {
    _recentRoutes ??= _readStringList('recentRoutes');
    return _recentRoutes!;
  }

  bool isSaved(RouteEntry route) => isRouteInAnyGroup(route.key);

  void toggleSaved(RouteEntry route) {
    toggleRouteInGroup(FavoriteGroup.favoritesId, route.key);
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

  void _saveFavoriteGroupOrder(List<FavoriteGroup> groups) {
    final List<String> ids = groups
        .map((FavoriteGroup group) => group.id)
        .toList();
    _favoriteGroupOrder = ids;
    sp.setString('favoriteGroupOrder', jsonEncode(ids));
  }

  List<FavoriteGroup> _readFavoriteGroups() {
    final String? raw = sp.getString('favoriteGroups');
    if (raw == null || raw.isEmpty) return [];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(FavoriteGroup.fromJson)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void _saveFavoriteGroups() {
    sp.setString(
      'favoriteGroups',
      jsonEncode((_customGroups ?? []).map((group) => group.toJson()).toList()),
    );
  }

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
