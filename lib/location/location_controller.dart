import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hktransports/bus/state/app_settings.dart';
import 'package:hktransports/location/location_service.dart';

class LocationController extends ChangeNotifier with WidgetsBindingObserver {
  LocationController(
    this._settings, {
    LocationService service = const LocationService(),
  }) : _service = service {
    _settings.addListener(_handleSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final AppSettings _settings;
  final LocationService _service;

  LocationAccessStatus? _access;
  Position? _position;
  StreamSubscription<Position>? _subscription;
  Completer<Position?>? _positionWaiter;
  Completer<void>? _startCompleter;
  bool _starting = false;
  bool _restartRequested = false;
  int _generation = 0;
  bool _disposed = false;

  LocationAccessStatus? get access => _access;
  Position? get position => _position;
  bool get isTracking => _subscription != null;

  Future<LocationAccessStatus> requestAccess() async {
    final LocationAccessStatus status = await _service.requestAccess();
    if (_disposed) return status;
    _setAccess(status);
    if (status == LocationAccessStatus.granted) {
      await ensureStarted();
    }
    return status;
  }

  Future<void> ensureStarted() {
    if (_disposed || !_settings.locationEnabled) return Future<void>.value();
    if (_subscription != null) return Future<void>.value();
    if (_starting) {
      _restartRequested = true;
      return _startCompleter?.future ?? Future<void>.value();
    }

    final Completer<void> completer = Completer<void>();
    _startCompleter = completer;
    _starting = true;
    unawaited(
      _runStartLoop().whenComplete(_finishStart).catchError((Object error) {}),
    );
    return completer.future;
  }

  Future<void> _runStartLoop() async {
    do {
      _restartRequested = false;
      final int generation = ++_generation;
      final LocationAccessStatus status = await _service.checkAccess();
      if (_disposed ||
          generation != _generation ||
          !_settings.locationEnabled) {
        return;
      }
      _setAccess(status);
      if (status != LocationAccessStatus.granted || _subscription != null) {
        return;
      }

      try {
        final Stream<Position> stream = _service.positionStream();
        _subscription = stream.listen(
          (Position position) {
            if (generation != _generation || _disposed) return;
            _setPosition(position);
          },
          onError: (Object error) {
            if (generation != _generation || _disposed) return;
            unawaited(_handleStreamError());
          },
        );
      } catch (_) {
        await _handleStreamError();
        return;
      }
    } while (_restartRequested && _subscription == null);
  }

  void _finishStart() {
    _starting = false;
    final Completer<void>? completer = _startCompleter;
    _startCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    if (!_disposed &&
        _settings.locationEnabled &&
        _subscription == null &&
        _restartRequested) {
      _restartRequested = false;
      unawaited(ensureStarted());
    }
  }

  Future<Position?> waitForPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_position != null) return _position;
    if (!_settings.locationEnabled) return null;
    if (_access != LocationAccessStatus.granted) return null;
    await ensureStarted();
    if (_position != null) return _position;
    if (_access != LocationAccessStatus.granted || _subscription == null) {
      return null;
    }

    final Completer<Position?> waiter = _positionWaiter ??=
        Completer<Position?>();
    try {
      return await waiter.future.timeout(timeout);
    } on TimeoutException {
      if (identical(_positionWaiter, waiter)) _positionWaiter = null;
      return _position;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_settings.locationEnabled) unawaited(ensureStarted());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTracking(clearPosition: false);
    }
  }

  void _handleSettingsChanged() {
    if (!_settings.locationEnabled) {
      _stopTracking(clearPosition: true);
      return;
    }
    unawaited(ensureStarted());
  }

  void _setAccess(LocationAccessStatus status) {
    if (_access == status) return;
    _access = status;
    if (status != LocationAccessStatus.granted) {
      _position = null;
      _completeWaiter(null);
    }
    if (!_disposed) notifyListeners();
  }

  void _setPosition(Position position) {
    _position = position;
    _completeWaiter(position);
    if (!_disposed) notifyListeners();
  }

  void _completeWaiter(Position? position) {
    final Completer<Position?>? waiter = _positionWaiter;
    _positionWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete(position);
  }

  Future<void> _handleStreamError() async {
    _stopTracking(clearPosition: false);
    if (_disposed || !_settings.locationEnabled) return;
    final LocationAccessStatus status = await _service.checkAccess();
    if (_disposed || !_settings.locationEnabled) return;
    _setAccess(status);
  }

  void _stopTracking({required bool clearPosition}) {
    _generation++;
    _restartRequested = false;
    final StreamSubscription<Position>? subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _completeWaiter(null);
    if (clearPosition) {
      _position = null;
      _access = null;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_handleSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    _completeWaiter(null);
    super.dispose();
  }
}
