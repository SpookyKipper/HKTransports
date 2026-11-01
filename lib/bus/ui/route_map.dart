import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:hktransports/app/app_theme.dart';
import 'package:hktransports/bus/data/route_waypoints.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/bus/ui/map_attribution.dart';
import 'package:hktransports/location/location_controller.dart';
import 'package:hktransports/location/location_service.dart';
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

class RouteMapState extends State<RouteMap>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  static const double _stationFocusSpan = 0.0012;
  static const String _mapBackgroundColor = '#F5F2EA';
  static const String _userLocationSourceId = 'user-location';
  static const String _userLocationLayerId = 'user-location-layer';
  static const String _userAccuracySourceId = 'user-accuracy';
  static const String _userAccuracyLayerId = 'user-accuracy-layer';
  static const String _userDirectionSourceId = 'user-direction';
  static const String _userDirectionLayerId = 'user-direction-layer';
  static const String _userColor = '#1E88E5';

  MapController? _mapController;
  StyleController? _styleController;
  List<String> _attributions = const [];
  Future<String>? _styleFuture;
  Future<String>? _mapFuture;
  Future<Map<String, dynamic>?>? _waypointsFuture;
  bool? _isChinese;
  bool _layersReady = false;
  int? _pendingFocusIndex;
  int? _selectedIndex;
  late final AnimationController _pulseController;
  double _selectedOpacity = 1;
  DateTime _lastPulseUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _stationSourceWriting = false;
  bool _stationSourceDirty = false;
  late final Future<void> _minimumLoadingTime;
  LocationController? _locationController;
  geo.Position? _userPosition;
  bool _showUserLocation = false;
  bool _locating = false;
  bool _pendingLocate = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _compassHeading;
  double? _compassAccuracy;
  DateTime _lastCompassUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the map placeholder visible for at least 300ms after page launch,
    // even when the style and route data are already cached.
    _minimumLoadingTime = Future<void>.delayed(
      const Duration(milliseconds: 300),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_onPulseTick);
    _waypointsFuture = RouteWaypoints.fetch(widget.route);
  }

  void _onPulseTick() {
    _selectedOpacity = 0.2 + _pulseController.value * 0.8;
    final DateTime now = DateTime.now();
    if (now.difference(_lastPulseUpdate) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastPulseUpdate = now;
    unawaited(_updateStationSource());
  }

  void _startPulse() {
    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppSettings settings = context.read<AppSettings>();
    final LocationController location = context.read<LocationController>();
    if (!identical(_locationController, location)) {
      _locationController?.removeListener(_handleLocationChanged);
      _locationController = location..addListener(_handleLocationChanged);
    }
    if (!settings.locationEnabled && _showUserLocation) {
      _showUserLocation = false;
      _userPosition = null;
      _compassHeading = null;
      _compassAccuracy = null;
      _stopCompass();
      if (_layersReady) unawaited(_updateUserOverlaySources());
    }
    final bool zh = settings.isChinese;
    if (_isChinese == zh) return;
    _isChinese = zh;
    _layersReady = false;
    _styleController = null;
    _mapController = null;
    _attributions = const [];
    _styleFuture = _loadStyle(zh);
    _mapFuture = _prepareMap(_styleFuture!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationController?.removeListener(_handleLocationChanged);
    _locationController = null;
    _stopCompass();
    _pulseController.dispose();
    _styleController = null;
    _mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_showUserLocation) _startCompass();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopCompass();
    }
  }

  void _handleLocationChanged() {
    if (!_showUserLocation) return;
    final geo.Position? position = _locationController?.position;
    if (position == null) return;
    _userPosition = position;
    if (_layersReady) unawaited(_updateUserOverlaySources());
  }

  void _startCompass() {
    if (_compassSubscription != null) return;
    try {
      final Stream<CompassEvent>? events = FlutterCompass.events;
      if (events == null) return;
      _compassSubscription = events.listen(
        (CompassEvent event) {
          final double? heading = event.heading;
          if (heading == null) return;
          _compassHeading = (heading % 360 + 360) % 360;
          _compassAccuracy = event.accuracy;
          final DateTime now = DateTime.now();
          if (now.difference(_lastCompassUpdate) <
              const Duration(milliseconds: 100)) {
            return;
          }
          _lastCompassUpdate = now;
          if (_showUserLocation && _layersReady) {
            unawaited(_updateUserDirectionSource());
          }
        },
        onError: (Object error) {
          _stopCompass();
        },
      );
    } catch (_) {
      _stopCompass();
    }
  }

  void _stopCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  Future<void> _updateUserDirectionSource() async {
    final StyleController? style = _styleController;
    if (!_layersReady || style == null) return;
    try {
      await style.updateGeoJsonSource(
        id: _userDirectionSourceId,
        data: jsonEncode(_userDirectionGeoJson()),
      );
    } catch (error) {
      debugPrint('Unable to update user direction overlay: $error');
    }
  }

  Future<void> _locateUser() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final LocationController location = context.read<LocationController>();
      final LocationAccessStatus access = await location.requestAccess();
      if (!mounted || access != LocationAccessStatus.granted) return;
      final geo.Position? position =
          location.position ?? await location.waitForPosition();
      if (!mounted || position == null) return;
      _userPosition = position;
      _showUserLocation = true;
      _startCompass();
      if (_layersReady) {
        await _updateUserOverlaySources();
        if (!mounted) return;
        await _fitUserLocation(position);
      } else {
        _pendingLocate = true;
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void focusStation(int index) {
    _selectedIndex = index;
    _startPulse();
    if (!_layersReady || _mapController == null) {
      _pendingFocusIndex = index;
      return;
    }
    unawaited(_focusStationCamera(index));
  }

  Future<void> _updateUserOverlaySources() async {
    final StyleController? style = _styleController;
    if (!_layersReady || style == null) return;
    try {
      await Future.wait(<Future<void>>[
        style.updateGeoJsonSource(
          id: _userLocationSourceId,
          data: jsonEncode(_userLocationGeoJson()),
        ),
        style.updateGeoJsonSource(
          id: _userAccuracySourceId,
          data: jsonEncode(_userAccuracyGeoJson()),
        ),
        style.updateGeoJsonSource(
          id: _userDirectionSourceId,
          data: jsonEncode(_userDirectionGeoJson()),
        ),
      ]);
    } catch (error) {
      debugPrint('Unable to update user location overlay: $error');
    }
  }

  Future<void> _fitUserLocation(geo.Position position) async {
    final MapController? controller = _mapController;
    if (controller == null) return;
    final List<Geographic> points = _userFitPoints(position);
    final LngLatBounds bounds;
    if (points.length == 1) {
      bounds = _boundsAround(position.latitude, position.longitude, 0.001);
    } else {
      bounds = LngLatBounds.fromPoints(points);
    }
    await controller.fitBounds(
      bounds: bounds,
      bearing: controller.getCamera().bearing,
      padding: const EdgeInsets.all(32),
      nativeDuration: const Duration(milliseconds: 600),
      webMaxDuration: const Duration(milliseconds: 600),
    );
  }

  List<Geographic> _userFitPoints(geo.Position position) {
    final List<Geographic> points = <Geographic>[
      Geographic(lon: position.longitude, lat: position.latitude),
      ..._accuracyPoints(position),
      ..._directionPoints(position),
    ];
    return points;
  }

  List<Geographic> _accuracyPoints(geo.Position position) {
    if (!position.hasAccuracy || position.accuracy <= 0) return const [];
    return <Geographic>[
      for (int index = 0; index < 8; index++)
        _destinationPoint(
          position.latitude,
          position.longitude,
          position.accuracy,
          index * 45.0,
        ),
    ];
  }

  List<Geographic> _directionPoints(geo.Position position) {
    final double? heading = _effectiveHeading(position);
    if (heading == null) return const [];
    final double length =
        (position.hasAccuracy && position.accuracy > 0
            ? position.accuracy
            : 30.0) +
        20.0;
    final double spread = _effectiveHeadingSpread(position);
    return <Geographic>[
      _destinationPoint(
        position.latitude,
        position.longitude,
        length,
        heading - spread,
      ),
      _destinationPoint(
        position.latitude,
        position.longitude,
        length,
        heading + spread,
      ),
    ];
  }

  double? _effectiveHeading(geo.Position position) {
    if (_compassHeading != null) return _compassHeading;
    return position.hasHeading ? position.heading : null;
  }

  double _effectiveHeadingSpread(geo.Position position) {
    final double? compassAccuracy = _compassAccuracy;
    final double value =
        compassAccuracy ??
        (position.hasHeadingAccuracy ? position.headingAccuracy : 20.0);
    return value.clamp(12.0, 60.0).toDouble();
  }

  Map<String, dynamic> _userLocationGeoJson() {
    final geo.Position? position = _userPosition;
    if (!_showUserLocation || position == null) return _emptyGeoJson();
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[position.longitude, position.latitude],
          },
        },
      ],
    };
  }

  Map<String, dynamic> _userAccuracyGeoJson() {
    final geo.Position? position = _userPosition;
    if (!_showUserLocation ||
        position == null ||
        !position.hasAccuracy ||
        position.accuracy <= 0) {
      return _emptyGeoJson();
    }
    final List<List<double>> ring = <List<double>>[];
    const int segments = 72;
    for (int index = 0; index <= segments; index++) {
      final Geographic point = _destinationPoint(
        position.latitude,
        position.longitude,
        position.accuracy,
        index * 360.0 / segments,
      );
      ring.add(<double>[point.lon, point.lat]);
    }
    return _polygonFeatureCollection(ring);
  }

  Map<String, dynamic> _userDirectionGeoJson() {
    final geo.Position? position = _userPosition;
    final double? heading = position == null
        ? null
        : _effectiveHeading(position);
    if (!_showUserLocation || position == null || heading == null) {
      return _emptyGeoJson();
    }
    final double length =
        (position.hasAccuracy && position.accuracy > 0
            ? position.accuracy
            : 30.0) +
        20.0;
    final double spread = _effectiveHeadingSpread(position);
    final Geographic left = _destinationPoint(
      position.latitude,
      position.longitude,
      length,
      heading - spread,
    );
    final Geographic right = _destinationPoint(
      position.latitude,
      position.longitude,
      length,
      heading + spread,
    );
    return _polygonFeatureCollection(<List<double>>[
      <double>[position.longitude, position.latitude],
      <double>[left.lon, left.lat],
      <double>[right.lon, right.lat],
      <double>[position.longitude, position.latitude],
    ]);
  }

  Map<String, dynamic> _polygonFeatureCollection(List<List<double>> ring) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': <String, dynamic>{
            'type': 'Polygon',
            'coordinates': <dynamic>[ring],
          },
        },
      ],
    };
  }

  Map<String, dynamic> _emptyGeoJson() {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[],
    };
  }

  Geographic _destinationPoint(
    double latitude,
    double longitude,
    double distanceMeters,
    double bearingDegrees,
  ) {
    const double earthRadius = 6371000;
    final double bearing = bearingDegrees * math.pi / 180;
    final double lat1 = latitude * math.pi / 180;
    final double lon1 = longitude * math.pi / 180;
    final double angularDistance = distanceMeters / earthRadius;
    final double lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final double lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );
    return Geographic(lon: lon2 * 180 / math.pi, lat: lat2 * 180 / math.pi);
  }

  Future<void> _focusStationCamera(int index) async {
    final MapController? controller = _mapController;
    final RouteMapStation? station = _stationAt(index);
    if (controller == null || station == null) return;
    await _updateStationSource();
    if (!mounted || !identical(_mapController, controller)) return;
    final double bearing = controller.getCamera().bearing;
    await controller.fitBounds(
      bounds: _boundsAround(
        station.stop.lat,
        station.stop.lng,
        _stationFocusSpan,
      ),
      bearing: bearing,
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

  Future<String> _prepareMap(Future<String> styleFuture) async {
    final String style = await styleFuture;
    await _waypointsFuture;
    await _minimumLoadingTime;
    return style;
  }

  bool get _stationsReady {
    final int expected = widget.route.primaryStops.length;
    return expected > 0 &&
        widget.stations.length == expected &&
        widget.stations.every(
          (RouteMapStation station) =>
              _validCoordinate(station.stop.lat, station.stop.lng),
        );
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    if (!mounted) return;
    _styleController = style;
    _attributions = style.getAttributionsSync();
    _layersReady = false;
    if (mounted) setState(() {});
    final List<RouteMapStation> stations = _validStations();
    final List<Geographic> points = [
      for (final RouteMapStation station in stations)
        Geographic(lon: station.stop.lng, lat: station.stop.lat),
    ];
    if (points.isEmpty) return;

    await _buildLayers(style, points);
    if (!mounted || !identical(_styleController, style)) return;
    _layersReady = true;

    if (_pendingLocate && _showUserLocation && _userPosition != null) {
      _pendingLocate = false;
      await _updateUserOverlaySources();
      if (!mounted) return;
      await _fitUserLocation(_userPosition!);
      return;
    }

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
      GeoJsonSource(
        id: _userAccuracySourceId,
        data: jsonEncode(_userAccuracyGeoJson()),
      ),
    );
    await style.addLayer(
      FillStyleLayer(
        id: _userAccuracyLayerId,
        sourceId: _userAccuracySourceId,
        paint: <String, Object>{
          'fill-color': _userColor,
          'fill-opacity': 0.16,
          'fill-outline-color': _userColor,
        },
      ),
    );

    await style.addSource(
      GeoJsonSource(
        id: _userDirectionSourceId,
        data: jsonEncode(_userDirectionGeoJson()),
      ),
    );
    await style.addLayer(
      FillStyleLayer(
        id: _userDirectionLayerId,
        sourceId: _userDirectionSourceId,
        paint: <String, Object>{'fill-color': _userColor, 'fill-opacity': 0.22},
      ),
    );

    await style.addSource(
      GeoJsonSource(
        id: _userLocationSourceId,
        data: jsonEncode(_userLocationGeoJson()),
      ),
    );
    await style.addLayer(
      CircleStyleLayer(
        id: _userLocationLayerId,
        sourceId: _userLocationSourceId,
        paint: <String, Object>{
          'circle-radius': 7.0,
          'circle-color': _userColor,
          'circle-stroke-width': 2.5,
          'circle-stroke-color': '#FFFFFF',
        },
      ),
    );

    await style.addSource(
      GeoJsonSource(id: _stationSourceId, data: jsonEncode(_stationGeoJson())),
    );
    await style.addLayer(
      CircleStyleLayer(
        id: _stationLayerId,
        sourceId: _stationSourceId,
        paint: <String, Object>{
          'circle-radius': 6.0,
          'circle-color': routeColor,
          'circle-stroke-width': 1.5,
          'circle-stroke-color': '#FFFFFF',
          'circle-opacity': <Object>['get', 'opacity'],
        },
      ),
    );
  }

  Future<void> _removeLayers(StyleController style) async {
    for (final String layerId in <String>[
      _userLocationLayerId,
      _userDirectionLayerId,
      _userAccuracyLayerId,
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
    for (final String sourceId in <String>[
      _userLocationSourceId,
      _userDirectionSourceId,
      _userAccuracySourceId,
      _routeSourceId,
      _stationSourceId,
    ]) {
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
    if (_stationSourceWriting) {
      _stationSourceDirty = true;
      return;
    }
    _stationSourceWriting = true;
    try {
      do {
        _stationSourceDirty = false;
        await style.updateGeoJsonSource(
          id: _stationSourceId,
          data: jsonEncode(_stationGeoJson()),
        );
      } while (_stationSourceDirty &&
          mounted &&
          identical(_styleController, style));
    } catch (error) {
      debugPrint('Unable to update station highlighting: $error');
    } finally {
      _stationSourceWriting = false;
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
              'opacity': station.index == _selectedIndex
                  ? _selectedOpacity
                  : 1.0,
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
    final double bearing = controller.getCamera().bearing;
    await controller.fitBounds(
      bounds: bounds,
      bearing: bearing,
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
    final List<Map<String, dynamic>> layers = [
      <String, dynamic>{
        'id': 'background',
        'type': 'background',
        'paint': <String, dynamic>{'background-color': _mapBackgroundColor},
      },
    ];
    for (final dynamic value in baseLayers) {
      if (value is! Map) continue;
      final Map<String, dynamic> layer = _map(value);
      if (layer['id'] == 'mainland_mask/0/1') {
        final Map<String, dynamic> paint = _map(layer['paint']);
        paint['fill-color'] = _mapBackgroundColor;
        layer['paint'] = paint;
      }
      layers.add(layer);
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
    final Future<String> styleFuture = _loadStyle(zh);
    setState(() {
      _styleFuture = styleFuture;
      _mapFuture = _prepareMap(styleFuture);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = context.watch<AppSettings>();
    final bool dimMap =
        theme.brightness == Brightness.dark && settings.dimMapInDarkMode;
    final Future<String>? styleFuture = _mapFuture;
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
            if (style == null || !_stationsReady) {
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
                    gestures: const MapGestures.all(rotate: true, pitch: false),
                  ),
                  onMapCreated: (MapController controller) {
                    _mapController = controller;
                  },
                  onStyleLoaded: (StyleController style) {
                    unawaited(_onStyleLoaded(style));
                  },
                  onEvent: _onMapEvent,
                  children: [
                    MapCompass(
                      hideIfRotatedNorth: true,
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(12),
                      radius: 18,
                      rotationOffset: 0,
                      child: Tooltip(
                        message: settings.text('重置地圖方向', 'Reset north'),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.92,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 36,
                            child: Icon(
                              Icons.navigation,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: dimMap
                          ? Colors.black.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: MapAttribution(
                    attributions: _attributions,
                    padding: const EdgeInsets.fromLTRB(42, 0, 10, 10),
                  ),
                ),
                if (settings.locationEnabled)
                  Positioned(
                    right: 10,
                    bottom: 48,
                    child: Material(
                      color: theme.scaffoldBackgroundColor,
                      shape: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: 30,
                        child: IconButton(
                          tooltip: settings.text('定位', 'My location'),
                          onPressed: _locating ? null : _locateUser,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: _locating
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  bottom: 10,
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
