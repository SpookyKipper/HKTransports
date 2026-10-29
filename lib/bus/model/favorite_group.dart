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
