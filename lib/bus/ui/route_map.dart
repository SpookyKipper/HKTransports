import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/bus/data/route_waypoints.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
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
  static const String _arrowImageName = 'route-direction-arrow';
  static const double _stationHitRadius = 26;

  MapLibreMapController? _controller;
  Future<String>? _styleFuture;
  Future<Map<String, dynamic>?>? _waypointsFuture;
  final List<Circle> _circles = [];
  bool? _isChinese;
  bool _styleLoaded = false;
  bool _arrowImageAdded = false;
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
    _styleLoaded = false;
    _controller = null;
    _arrowImageAdded = false;
    _circles.clear();
    _styleFuture = _loadStyle(zh);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void focusStation(int index) {
    _selectedIndex = index;
    if (!_styleLoaded || _controller == null) {
      _pendingFocusIndex = index;
      return;
    }
    _focusStationCamera(index);
  }

  Future<void> _focusStationCamera(int index) async {
    final MapLibreMapController? controller = _controller;
    if (controller == null) return;
    final RouteMapStation? station = _stationAt(index);
    if (station == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(station.stop.lat, station.stop.lng),
        15,
      ),
      duration: const Duration(milliseconds: 900),
    );
    await _updateCircleSelection(controller, index);
  }

  RouteMapStation? _stationAt(int index) {
    for (final RouteMapStation station in widget.stations) {
      if (station.index == index) return station;
    }
    return null;
  }

  Future<void> _onMapClick(double x, double y) async {
    final MapLibreMapController? controller = _controller;
    if (controller == null) return;
    final List<RouteMapStation> stations = [
      for (final RouteMapStation station in widget.stations)
        if (_validCoordinate(station.stop.lat, station.stop.lng)) station,
    ];
    if (stations.isEmpty) return;

    final List<math.Point> screenPoints;
    try {
      screenPoints = await controller.toScreenLocationBatch([
        for (final RouteMapStation station in stations)
          LatLng(station.stop.lat, station.stop.lng),
      ]);
    } catch (_) {
      return;
    }
    if (!mounted ||
        !identical(_controller, controller) ||
        screenPoints.length != stations.length) {
      return;
    }

    int nearestIndex = -1;
    double nearestDistance = double.infinity;
    final List<double> distances = List<double>.filled(stations.length, 0);
    for (int index = 0; index < stations.length; index++) {
      final math.Point point = screenPoints[index];
      final double dx = point.x.toDouble() - x;
      final double dy = point.y.toDouble() - y;
      final double distance = math.sqrt(dx * dx + dy * dy);
      distances[index] = distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    if (nearestIndex < 0) return;

    double nearestNeighbour = double.infinity;
    final math.Point nearestPoint = screenPoints[nearestIndex];
    for (int index = 0; index < screenPoints.length; index++) {
      if (index == nearestIndex) continue;
      final math.Point point = screenPoints[index];
      final double dx = point.x.toDouble() - nearestPoint.x.toDouble();
      final double dy = point.y.toDouble() - nearestPoint.y.toDouble();
      final double distance = math.sqrt(dx * dx + dy * dy);
      if (distance < nearestNeighbour) nearestNeighbour = distance;
    }

    // Keep the enlarged click target inside the gap to the closest dot.
    final double hitRadius = math.min(_stationHitRadius, nearestNeighbour / 2);
    if (distances[nearestIndex] > hitRadius) return;
    _selectedIndex = stations[nearestIndex].index;
    widget.onStationTap(stations[nearestIndex].index);
  }

  Future<void> _onStyleLoaded() async {
    final MapLibreMapController? controller = _controller;
    if (controller == null) return;
    _styleLoaded = true;
    await controller.clearCircles();
    await controller.clearLines();

    final List<RouteMapStation> validStations = [
      for (final RouteMapStation station in widget.stations)
        if (_validCoordinate(station.stop.lat, station.stop.lng)) station,
    ];
    if (validStations.isEmpty) return;

    final ColorScheme scheme =
        AppColorSchemes.lightOf(context) ?? Theme.of(context).colorScheme;
    final String routeColor = _hex(scheme.primary);
    final List<LatLng> points = [
      for (final RouteMapStation station in validStations)
        LatLng(station.stop.lat, station.stop.lng),
    ];

    final List<CircleOptions> circles = [
      for (final RouteMapStation station in validStations)
        CircleOptions(
          geometry: LatLng(station.stop.lat, station.stop.lng),
          circleRadius: 6,
          circleColor: routeColor,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1.5,
        ),
    ];
    final List<Map<String, dynamic>> data = [
      for (final RouteMapStation station in validStations)
        <String, dynamic>{'index': station.index},
    ];
    final List<Circle> added = await controller.addCircles(circles, data);
    _circles
      ..clear()
      ..addAll(added);

    final int? pending = _pendingFocusIndex;
    if (pending != null) {
      _pendingFocusIndex = null;
      await _focusStationCamera(pending);
    } else {
      await _fitCamera(points);
      if (_selectedIndex != null) {
        await _updateCircleSelection(controller, _selectedIndex!);
      }
    }
    await _drawRouteLine(controller, routeColor, points);
  }

  Future<void> _drawRouteLine(
    MapLibreMapController controller,
    String color,
    List<LatLng> stopPoints,
  ) async {
    final Map<String, dynamic>? waypoints = await _waypointsFuture;
    if (!mounted || !identical(_controller, controller)) return;
    final Map<String, dynamic> fallback = _fallbackRouteGeoJson(stopPoints);
    if (waypoints == null) {
      await _setRouteLine(controller, fallback, color);
      return;
    }
    try {
      await _setRouteLine(controller, waypoints, color);
    } catch (error) {
      debugPrint('Unable to draw route waypoints: $error');
      if (!mounted || !identical(_controller, controller)) return;
      await _setRouteLine(controller, fallback, color);
    }
  }

  Future<void> _setRouteLine(
    MapLibreMapController controller,
    Map<String, dynamic> geoJson,
    String color,
  ) async {
    try {
      await controller.removeLayer(_routeArrowLayerId);
    } catch (_) {
      // The arrow layer does not exist on a fresh style.
    }
    try {
      await controller.removeLayer(_routeLayerId);
    } catch (_) {
      // The layer does not exist on a fresh style.
    }
    try {
      await controller.removeSource(_routeSourceId);
    } catch (_) {
      // The source does not exist on a fresh style.
    }
    await controller.addGeoJsonSource(_routeSourceId, geoJson);
    await controller.addLineLayer(
      _routeSourceId,
      _routeLayerId,
      LineLayerProperties(
        lineColor: color,
        lineWidth: 4,
        lineJoin: 'round',
        lineOpacity: 0.9,
      ),
    );
    if (await _ensureArrowImage(controller)) {
      try {
        await controller.addSymbolLayer(
          _routeSourceId,
          _routeArrowLayerId,
          SymbolLayerProperties(
            symbolPlacement: 'line',
            symbolSpacing: 50,
            iconImage: _arrowImageName,
            iconSize: 0.65,
            iconRotate: 90,
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconRotationAlignment: 'map',
          ),
        );
      } catch (error) {
        debugPrint('Unable to draw route direction arrows: $error');
      }
    }
  }

  Future<bool> _ensureArrowImage(MapLibreMapController controller) async {
    if (_arrowImageAdded) return true;
    try {
      final ByteData data = await rootBundle.load(
        'assets/images/route_arrow.png',
      );
      await controller.addImage(_arrowImageName, data.buffer.asUint8List());
      _arrowImageAdded = true;
      return true;
    } catch (error) {
      debugPrint('Unable to load route direction arrow: $error');
      return false;
    }
  }

  Map<String, dynamic> _fallbackRouteGeoJson(List<LatLng> points) {
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
              for (final LatLng point in points)
                <double>[point.longitude, point.latitude],
            ],
          },
        },
      ],
    };
  }

  Future<void> _fitCamera(List<LatLng> points) async {
    final MapLibreMapController? controller = _controller;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final LatLng point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    if (minLat == maxLat && minLng == maxLng) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
        duration: const Duration(milliseconds: 400),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 44,
        top: 44,
        right: 44,
        bottom: 44,
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _updateCircleSelection(
    MapLibreMapController controller,
    int selected,
  ) async {
    if (!mounted || _circles.isEmpty) return;
    final ColorScheme scheme =
        AppColorSchemes.lightOf(context) ?? Theme.of(context).colorScheme;
    final String routeColor = _hex(scheme.primary);
    final String selectedColor = _hex(scheme.tertiary);
    for (final Circle circle in List<Circle>.from(_circles)) {
      final dynamic raw = circle.data?['index'];
      final int? index = raw is int ? raw : int.tryParse('$raw');
      final bool isSelected = index == selected;
      await controller.updateCircle(
        circle,
        CircleOptions(
          circleRadius: isSelected ? 9 : 6,
          circleColor: isSelected ? selectedColor : routeColor,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: isSelected ? 2.5 : 1.5,
        ),
      );
    }
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
                  styleString: style,
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget(),
                    zoom: 11,
                  ),
                  minMaxZoomPreference: const MinMaxZoomPreference(8, 18),
                  compassEnabled: false,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  logoEnabled: false,
                  attributionButtonPosition:
                      AttributionButtonPosition.bottomRight,
                  onMapCreated: (MapLibreMapController controller) {
                    _controller = controller;
                  },
                  featureTapsTriggersMapClick: true,
                  onMapClick: (math.Point point, LatLng _) {
                    unawaited(
                      _onMapClick(point.x.toDouble(), point.y.toDouble()),
                    );
                  },
                  onStyleLoadedCallback: _onStyleLoaded,
                ),
                Positioned(
                  right: 38,
                  bottom: 6,
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

  LatLng _initialTarget() {
    final List<RouteMapStation> valid = [
      for (final RouteMapStation station in widget.stations)
        if (_validCoordinate(station.stop.lat, station.stop.lng)) station,
    ];
    if (valid.isEmpty) return const LatLng(22.3193, 114.1694);
    double lat = 0;
    double lng = 0;
    for (final RouteMapStation station in valid) {
      lat += station.stop.lat;
      lng += station.stop.lng;
    }
    return LatLng(lat / valid.length, lng / valid.length);
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
