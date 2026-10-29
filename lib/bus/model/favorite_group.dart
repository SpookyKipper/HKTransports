class FavoriteGroup {
  const FavoriteGroup({
    required this.id,
    required this.name,
    required this.routes,
  });

  static const String favoritesId = 'favorites';

  final String id;
  final String name;
  final List<String> routes;

  bool get isDefault => id == favoritesId;

  FavoriteGroup copyWith({String? name, List<String>? routes}) {
    return FavoriteGroup(
      id: id,
      name: name ?? this.name,
      routes: routes ?? this.routes,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'routes': routes};
  }

  factory FavoriteGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> routes = (json['routes'] as List<dynamic>?) ?? const [];
    return FavoriteGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      routes: routes.map((dynamic value) => value.toString()).toList(),
    );
  }
}

class FavoriteEntry {
  const FavoriteEntry({required this.routeKey, required this.seq});

  final String routeKey;
  final int seq;

  String get storageKey => FavoriteEntry.encode(routeKey, seq);

  static String encode(String routeKey, int seq) => '$routeKey|$seq';

  static FavoriteEntry parse(String raw) {
    final int separator = raw.lastIndexOf('|');
    if (separator <= 0) {
      return FavoriteEntry(routeKey: raw, seq: 0);
    }
    final String key = raw.substring(0, separator);
    final int seq = int.tryParse(raw.substring(separator + 1)) ?? 0;
    return FavoriteEntry(routeKey: key, seq: seq);
  }
}
