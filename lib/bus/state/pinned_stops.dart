import 'package:flutter/foundation.dart';

class PinnedStation {
  const PinnedStation({required this.routeKey, required this.seq});

  final String routeKey;
  final int seq;

  String get id => '$routeKey|$seq';

  @override
  bool operator ==(Object other) =>
      other is PinnedStation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class PinnedStopsController extends ChangeNotifier {
  final List<PinnedStation> _stations = [];

  List<PinnedStation> get stations => List.unmodifiable(_stations);

  bool contains(String routeKey, int seq) {
    final String id = '$routeKey|$seq';
    return _stations.any((station) => station.id == id);
  }

  void toggle(PinnedStation station) {
    final int index = _stations.indexWhere((item) => item.id == station.id);
    if (index >= 0) {
      _stations.removeAt(index);
    } else {
      _stations.add(station);
    }
    notifyListeners();
  }

  void remove(PinnedStation station) {
    final int index = _stations.indexWhere((item) => item.id == station.id);
    if (index < 0) return;
    _stations.removeAt(index);
    notifyListeners();
  }
}
