import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    required this.stations,
    required this.onStationTap,
  });

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

  MapLibreMapController? _controller;
  Future<String>? _styleFuture;
  final List<Circle> _circles = [];
  bool? _isChinese;
  bool _styleLoaded = false;
  int? _pendingFocusIndex;
  int? _selectedIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool zh = context.read<AppSettings>().isChinese;
    if (_isChinese == zh) return;
    _isChinese = zh;
    _styleLoaded = false;
    _controller = null;
    _circles.clear();
    _styleFuture = _loadStyle(zh);
  }

  @override
  void dispose() {
    _controller?.onCircleTapped.remove(_onCircleTapped);
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
      duration: const Duration(milliseconds: 350),
    );
    await _updateCircleSelection(controller, index);
  }

  RouteMapStation? _stationAt(int index) {
    for (final RouteMapStation station in widget.stations) {
      if (station.index == index) return station;
    }
    return null;
  }

  void _onCircleTapped(Circle circle) {
    final dynamic raw = circle.data?['index'];
    final int? index = raw is int ? raw : int.tryParse('$raw');
    if (index == null) return;
    _selectedIndex = index;
    widget.onStationTap(index);
  }

  void _onMapClick(LatLng point) {
    RouteMapStation? nearest;
    double nearestDistance = double.infinity;
    for (final RouteMapStation station in widget.stations) {
      if (!_validCoordinate(station.stop.lat, station.stop.lng)) continue;
      final double distance = _distanceMeters(
        point.latitude,
        point.longitude,
        station.stop.lat,
        station.stop.lng,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = station;
      }
    }
    if (nearest == null || nearestDistance > 50) return;
    _selectedIndex = nearest.index;
    widget.onStationTap(nearest.index);
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double metersPerDegree = 111320;
    final double midLat = (lat1 + lat2) / 2 * math.pi / 180;
    final double dy = (lat1 - lat2) * metersPerDegree;
    final double dx = (lng1 - lng2) * metersPerDegree * math.cos(midLat);
    return math.sqrt(dx * dx + dy * dy);
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

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String routeColor = _hex(scheme.primary);
    final List<LatLng> points = [
      for (final RouteMapStation station in validStations)
        LatLng(station.stop.lat, station.stop.lng),
    ];
    if (points.length > 1) {
      await controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: routeColor,
          lineWidth: 4,
          lineJoin: 'round',
          lineOpacity: 0.9,
        ),
      );
    }

    final List<CircleOptions> circles = [
      for (final RouteMapStation station in validStations)
        CircleOptions(
          geometry: LatLng(station.stop.lat, station.stop.lng),
          circleRadius: 8,
          circleColor: routeColor,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String routeColor = _hex(scheme.primary);
    final String selectedColor = _hex(scheme.tertiary);
    for (final Circle circle in List<Circle>.from(_circles)) {
      final dynamic raw = circle.data?['index'];
      final int? index = raw is int ? raw : int.tryParse('$raw');
      final bool isSelected = index == selected;
      await controller.updateCircle(
        circle,
        CircleOptions(
          circleRadius: isSelected ? 11 : 8,
          circleColor: isSelected ? selectedColor : routeColor,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: isSelected ? 3 : 2,
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
      ..['attribution'] =
          "<a href='https://api.portal.hkmapservice.gov.hk/disclaimer'>&copy; Map information from Lands Department</a>";
    labelSource
      ..remove('url')
      ..['tiles'] = <String>[
        '$_labelTilesBase/$lang/WGS84/tile/{z}/{y}/{x}.pbf',
      ]
      ..['maxzoom'] = 15
      ..['attribution'] = '&copy; GeoData Hong Kong';

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
      height: 224,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                  minMaxZoomPreference: const MinMaxZoomPreference(10, 15),
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  logoEnabled: false,
                  attributionButtonPosition:
                      AttributionButtonPosition.bottomRight,
                  onMapCreated: (MapLibreMapController controller) {
                    _controller = controller;
                    controller.onCircleTapped.add(_onCircleTapped);
                  },
                  onMapClick: (_, LatLng coordinates) =>
                      _onMapClick(coordinates),
                  onStyleLoadedCallback: _onStyleLoaded,
                ),
                Positioned(
                  right: 38,
                  bottom: 6,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/landsd.png',
                      width: 30,
                      height: 29,
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
