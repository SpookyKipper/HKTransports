import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/bus/data/route_waypoints.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre/maplibre.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:provider/provider.dart';

class RouteMapStation {
  const RouteMapStation({required this.index, required this.stop});

  final int index;
  final StopEntry stop;
}

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.stations,
    required this.onStationTap,
  });

  final RouteEntry route;
  final List<RouteMapStation> stations;
  final ValueChanged<int> onStationTap;

  @override
  RouteMapState createState() => RouteMapState();
}

class RouteMapState extends State<RouteMap> {
  static const String _baseStyleUrl =
      'https://mapapi.hkmapservice.gov.hk/gs/api/v1.0.0/vt/basemap/WGS84/resources/styles/root.json';
  static const String _basemapTiles =
      'https://mapapi.hkmapservice.gov.hk/gs/api/v1.0.0/vt/basemap/WGS84/tile/{z}/{y}/{x}.pbf';
  static const String _labelStyleBase =
      'https://mapapi.geodata.gov.hk/gs/api/v1.0.0/vt/label/hk';
  static const String _labelTilesBase =
      'https://mapapi.geodata.gov.hk/gs/api/v1.0.0/vt/label/hk';

  static final Map<String, String> _styleCache = {};
  static const String _routeSourceId = 'route-path';
  static const String _routeLayerId = 'route-path-line';
  static const String _routeArrowLayerId = 'route-path-arrows';
  static const String _stationSourceId = 'route-stations';
  static const String _stationLayerId = 'route-stations-layer';
  static const String _arrowImageName = 'route-direction-arrow';
  static const double _stationHitRadius = 26;

  MapController? _mapController;
  StyleController? _styleController;
  Future<String>? _styleFuture;
  Future<Map<String, dynamic>?>? _waypointsFuture;
  bool? _isChinese;
  bool _layersReady = false;
  int? _pendingFocusIndex;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _waypointsFuture = RouteWaypoints.fetch(widget.route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool zh = context.read<AppSettings>().isChinese;
    if (_isChinese == zh) return;
    _isChinese = zh;
    _layersReady = false;
    _styleController = null;
    _mapController = null;
    _styleFuture = _loadStyle(zh);
  }

  @override
  void dispose() {
    _styleController = null;
    _mapController = null;
    super.dispose();
  }

  void focusStation(int index) {
    _selectedIndex = index;
    if (!_layersReady || _mapController == null) {
      _pendingFocusIndex = index;
      return;
    }
    unawaited(_focusStationCamera(index));
  }

  Future<void> _focusStationCamera(int index) async {
    final MapController? controller = _mapController;
    final RouteMapStation? station = _stationAt(index);
    if (controller == null || station == null) return;
    await _updateStationSource();
    if (!mounted || !identical(_mapController, controller)) return;
    await controller.fitBounds(
      bounds: _boundsAround(station.stop.lat, station.stop.lng, 0.004),
      padding: const EdgeInsets.all(24),
      nativeDuration: const Duration(milliseconds: 900),
      webMaxDuration: const Duration(milliseconds: 900),
    );
  }

  RouteMapStation? _stationAt(int index) {
    for (final RouteMapStation station in widget.stations) {
      if (station.index == index) return station;
    }
    return null;
  }

  void _onMapEvent(MapEvent event) {
    if (event is! MapEventClick) return;
    _onMapClick(event.screenPoint);
  }

  void _onMapClick(Offset tap) {
    final MapController? controller = _mapController;
    if (controller == null || !_layersReady) return;
    final List<RouteMapStation> stations = _validStations();
    if (stations.isEmpty) return;

    final List<Offset> screenPoints;
    try {
      screenPoints = controller.toScreenLocations([
        for (final RouteMapStation station in stations)
          Geographic(lon: station.stop.lng, lat: station.stop.lat),
      ]);
    } catch (_) {
      return;
    }
    if (screenPoints.length != stations.length) return;

    int nearestIndex = -1;
    double nearestDistance = double.infinity;
    final List<double> distances = List<double>.filled(stations.length, 0);
    for (int index = 0; index < stations.length; index++) {
      final double distance = (screenPoints[index] - tap).distance;
      distances[index] = distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    if (nearestIndex < 0) return;

    double nearestNeighbour = double.infinity;
    final Offset nearestPoint = screenPoints[nearestIndex];
    for (int index = 0; index < screenPoints.length; index++) {
      if (index == nearestIndex) continue;
      final double distance = (screenPoints[index] - nearestPoint).distance;
      if (distance < nearestNeighbour) nearestNeighbour = distance;
    }
    final double hitRadius = math.min(_stationHitRadius, nearestNeighbour / 2);
    if (distances[nearestIndex] > hitRadius) return;

    _selectedIndex = stations[nearestIndex].index;
    unawaited(_updateStationSource());
    widget.onStationTap(stations[nearestIndex].index);
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    if (!mounted) return;
    _styleController = style;
    _layersReady = false;
    final List<RouteMapStation> stations = _validStations();
    final List<Geographic> points = [
      for (final RouteMapStation station in stations)
        Geographic(lon: station.stop.lng, lat: station.stop.lat),
    ];
    if (points.isEmpty) return;

    await _buildLayers(style, points);
    if (!mounted || !identical(_styleController, style)) return;
    _layersReady = true;

    final int? pending = _pendingFocusIndex;
    if (pending != null) {
      _pendingFocusIndex = null;
      await _focusStationCamera(pending);
    } else {
      await _fitCamera(points);
      if (_selectedIndex != null) {
        await _updateStationSource();
      }
    }
  }

  Future<void> _buildLayers(
    StyleController style,
    List<Geographic> points,
  ) async {
    final ColorScheme scheme =
        AppColorSchemes.lightOf(context) ?? Theme.of(context).colorScheme;
    final String routeColor = _hex(scheme.primary);
    final String selectedColor = _hex(scheme.tertiary);

    await _removeLayers(style);

    final Map<String, dynamic>? waypoints = await _waypointsFuture;
    if (!mounted || !identical(_styleController, style)) return;
    final Map<String, dynamic> fallback = _fallbackRouteGeoJson(points);
    Map<String, dynamic> routeData = waypoints ?? fallback;
    try {
      await style.addSource(
        GeoJsonSource(id: _routeSourceId, data: jsonEncode(routeData)),
      );
    } catch (error) {
      debugPrint('Unable to add route source: $error');
      routeData = fallback;
      try {
        await style.addSource(
          GeoJsonSource(id: _routeSourceId, data: jsonEncode(routeData)),
        );
      } catch (error) {
        debugPrint('Unable to add fallback route source: $error');
        return;
      }
    }

    await style.addLayer(
      LineStyleLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        paint: <String, Object>{
          'line-color': routeColor,
          'line-width': 4.0,
          'line-join': 'round',
          'line-opacity': 0.9,
        },
      ),
    );

    try {
      await style.removeImage(_arrowImageName);
    } catch (_) {
      // First style load has no arrow image yet.
    }
    try {
      await style.addImageFromAssets(
        id: _arrowImageName,
        asset: 'assets/images/route_arrow.png',
      );
      await style.addLayer(
        SymbolStyleLayer(
          id: _routeArrowLayerId,
          sourceId: _routeSourceId,
          layout: <String, Object>{
            'symbol-placement': 'line',
            'symbol-spacing': 50.0,
            'icon-image': _arrowImageName,
            'icon-size': 0.3,
            'icon-rotate': 90.0,
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
            'icon-rotation-alignment': 'map',
          },
        ),
      );
    } catch (error) {
      debugPrint('Unable to draw route direction arrows: $error');
    }

    await style.addSource(
      GeoJsonSource(id: _stationSourceId, data: jsonEncode(_stationGeoJson())),
    );
    await style.addLayer(
      CircleStyleLayer(
        id: _stationLayerId,
        sourceId: _stationSourceId,
        paint: <String, Object>{
          'circle-radius': <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'selected'],
              1,
            ],
            9.0,
            6.0,
          ],
          'circle-color': <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'selected'],
              1,
            ],
            selectedColor,
            routeColor,
          ],
          'circle-stroke-width': <Object>[
            'case',
            <Object>[
              '==',
              <Object>['get', 'selected'],
              1,
            ],
            2.5,
            1.5,
          ],
          'circle-stroke-color': '#FFFFFF',
        },
      ),
    );
  }

  Future<void> _removeLayers(StyleController style) async {
    for (final String layerId in <String>[
      _routeArrowLayerId,
      _routeLayerId,
      _stationLayerId,
    ]) {
      try {
        await style.removeLayer(layerId);
      } catch (_) {
        // Layer does not exist on a fresh style.
      }
    }
    for (final String sourceId in <String>[_routeSourceId, _stationSourceId]) {
      try {
        await style.removeSource(sourceId);
      } catch (_) {
        // Source does not exist on a fresh style.
      }
    }
  }

  Future<void> _updateStationSource() async {
    final StyleController? style = _styleController;
    if (!_layersReady || style == null) return;
    try {
      await style.updateGeoJsonSource(
        id: _stationSourceId,
        data: jsonEncode(_stationGeoJson()),
      );
    } catch (error) {
      debugPrint('Unable to update station highlighting: $error');
    }
  }

  Map<String, dynamic> _stationGeoJson() {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        for (final RouteMapStation station in _validStations())
          <String, dynamic>{
            'type': 'Feature',
            'properties': <String, dynamic>{
              'index': station.index,
              'selected': station.index == _selectedIndex ? 1 : 0,
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[station.stop.lng, station.stop.lat],
            },
          },
      ],
    };
  }

  Map<String, dynamic> _fallbackRouteGeoJson(List<Geographic> points) {
    if (points.length < 2) {
      return <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      };
    }
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': <List<double>>[
              for (final Geographic point in points)
                <double>[point.lon, point.lat],
            ],
          },
        },
      ],
    };
  }

  Future<void> _fitCamera(List<Geographic> points) async {
    final MapController? controller = _mapController;
    if (controller == null || points.isEmpty) return;
    final LngLatBounds bounds = _boundsForPoints(points);
    await controller.fitBounds(
      bounds: bounds,
      padding: const EdgeInsets.all(44),
      nativeDuration: const Duration(milliseconds: 500),
      webMaxDuration: const Duration(milliseconds: 500),
    );
  }

  LngLatBounds _boundsForPoints(List<Geographic> points) {
    if (points.length == 1) {
      return _boundsAround(points.first.lat, points.first.lon, 0.004);
    }
    final LngLatBounds bounds = LngLatBounds.fromPoints(points);
    if (bounds.longitudeWest == bounds.longitudeEast ||
        bounds.latitudeSouth == bounds.latitudeNorth) {
      return _boundsAround(
        (bounds.latitudeSouth + bounds.latitudeNorth) / 2,
        (bounds.longitudeWest + bounds.longitudeEast) / 2,
        0.004,
      );
    }
    return bounds;
  }

  LngLatBounds _boundsAround(double lat, double lng, double delta) {
    return LngLatBounds(
      longitudeWest: lng - delta,
      longitudeEast: lng + delta,
      latitudeSouth: lat - delta,
      latitudeNorth: lat + delta,
    );
  }

  List<RouteMapStation> _validStations() {
    return [
      for (final RouteMapStation station in widget.stations)
        if (_validCoordinate(station.stop.lat, station.stop.lng)) station,
    ];
  }

  Future<String> _loadStyle(bool zh) async {
    final String lang = zh ? 'tc' : 'en';
    final String? cached = _styleCache[lang];
    if (cached != null) return cached;

    final Uri baseUri = Uri.parse(_baseStyleUrl);
    final Uri labelUri = Uri.parse(
      '$_labelStyleBase/$lang/WGS84/resources/styles/root.json',
    );
    final List<http.Response> responses = await Future.wait([
      http.get(baseUri).timeout(const Duration(seconds: 30)),
      http.get(labelUri).timeout(const Duration(seconds: 30)),
    ]);
    if (responses.any((http.Response response) => response.statusCode != 200)) {
      throw Exception('Unable to load map style');
    }
    final dynamic baseJson = jsonDecode(utf8.decode(responses[0].bodyBytes));
    final dynamic labelJson = jsonDecode(utf8.decode(responses[1].bodyBytes));
    if (baseJson is! Map || labelJson is! Map) {
      throw const FormatException('Invalid map style');
    }

    final Map<String, dynamic> base = _map(baseJson);
    final Map<String, dynamic> label = _map(labelJson);
    final Map<String, dynamic> baseSources = _map(base['sources']);
    final Map<String, dynamic> labelSources = _map(label['sources']);
    final Map<String, dynamic> baseSource = _map(baseSources['esri']);
    final Map<String, dynamic> labelSource = _map(labelSources['esri']);

    baseSource
      ..remove('url')
      ..['tiles'] = <String>[_basemapTiles]
      ..['maxzoom'] = 15
      ..['attribution'] = zh
          ? "<a href='https://api.portal.hkmapservice.gov.hk/disclaimer'>&copy; 地圖由地政總署提供</a>"
          : "<a href='https://api.portal.hkmapservice.gov.hk/disclaimer'>&copy; Map provided by Lands Department</a>";
    labelSource
      ..remove('url')
      ..['tiles'] = <String>[
        '$_labelTilesBase/$lang/WGS84/tile/{z}/{y}/{x}.pbf',
      ]
      ..['maxzoom'] = 15
      ..['attribution'] = zh
          ? '&copy; 地圖標籤由 GeoData Hong Kong 提供'
          : '&copy; Map labels by GeoData Hong Kong';

    final List<dynamic> baseLayers = base['layers'] is List
        ? base['layers'] as List<dynamic>
        : const [];
    final List<dynamic> labelLayers = label['layers'] is List
        ? label['layers'] as List<dynamic>
        : const [];
    final List<Map<String, dynamic>> layers = [];
    for (final dynamic value in baseLayers) {
      if (value is Map) layers.add(_map(value));
    }
    for (int index = 0; index < labelLayers.length; index++) {
      final dynamic value = labelLayers[index];
      if (value is! Map) continue;
      final Map<String, dynamic> layer = _map(value);
      layer['id'] = 'labels/${layer['id'] ?? 'layer-$index'}';
      if (layer.containsKey('source')) layer['source'] = 'labels';
      layers.add(layer);
    }

    base['sources'] = <String, dynamic>{
      'esri': baseSource,
      'labels': labelSource,
    };
    base['layers'] = layers;
    base['glyphs'] = labelUri
        .resolve(label['glyphs']?.toString() ?? '')
        .toString()
        .replaceAll('%7B', '{')
        .replaceAll('%7D', '}');
    if (base['sprite'] != null) {
      base['sprite'] = baseUri.resolve(base['sprite'].toString()).toString();
    }
    base['name'] = 'HKTransports';
    final String style = jsonEncode(base);
    _styleCache[lang] = style;
    return style;
  }

  void _retryStyle() {
    final bool zh = _isChinese ?? true;
    _styleCache.remove(zh ? 'tc' : 'en');
    setState(() {
      _styleFuture = _loadStyle(zh);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    context.watch<AppSettings>();
    final Future<String>? styleFuture = _styleFuture;
    return SizedBox(
      height: 256,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(8),
        ),
        child: FutureBuilder<String>(
          future: styleFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.read<AppSettings>().text(
                          '無法載入地圖',
                          'Unable to load map',
                        ),
                      ),
                      M3EButton.text(
                        onPressed: _retryStyle,
                        child: Text(
                          context.read<AppSettings>().text('重試', 'Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final String? style = snapshot.data;
            if (style == null) {
              return ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: const Center(child: M3ELoadingIndicator()),
              );
            }
            return Stack(
              children: [
                MapLibreMap(
                  key: ValueKey<String>('route-map-${_isChinese == true}'),
                  options: MapOptions(
                    initStyle: style,
                    initCenter: _initialCenter(),
                    initZoom: 11,
                    minZoom: 8,
                    maxZoom: 18,
                    gestures: const MapGestures.all(pitch: false),
                  ),
                  onMapCreated: (MapController controller) {
                    _mapController = controller;
                  },
                  onStyleLoaded: (StyleController style) {
                    unawaited(_onStyleLoaded(style));
                  },
                  onEvent: _onMapEvent,
                  children: const [
                    SourceAttribution(
                      showMapLibre: false,
                      alignment: Alignment.bottomRight,
                    ),
                  ],
                ),
                Positioned(
                  right: 44,
                  bottom: 8,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/landsd.png',
                      width: 22,
                      height: 21,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Geographic _initialCenter() {
    final List<RouteMapStation> valid = _validStations();
    if (valid.isEmpty) {
      return const Geographic(lon: 114.1694, lat: 22.3193);
    }
    double lat = 0;
    double lng = 0;
    for (final RouteMapStation station in valid) {
      lat += station.stop.lat;
      lng += station.stop.lng;
    }
    return Geographic(lon: lng / valid.length, lat: lat / valid.length);
  }

  bool _validCoordinate(double lat, double lng) {
    return lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0);
  }

  String _hex(Color color) {
    final int value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
}
