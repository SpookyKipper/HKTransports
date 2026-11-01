import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

enum LocationAccessStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unsupported,
}

class LocationService {
  const LocationService();

  Future<LocationAccessStatus> checkAccess() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationAccessStatus.serviceDisabled;
      return _statusFor(await Geolocator.checkPermission());
    } on MissingPluginException {
      return LocationAccessStatus.unsupported;
    } on UnsupportedError {
      return LocationAccessStatus.unsupported;
    } catch (_) {
      return LocationAccessStatus.denied;
    }
  }

  Future<LocationAccessStatus> requestAccess() async {
    final LocationAccessStatus current = await checkAccess();
    if (current != LocationAccessStatus.denied) return current;
    try {
      return _statusFor(await Geolocator.requestPermission());
    } on MissingPluginException {
      return LocationAccessStatus.unsupported;
    } on UnsupportedError {
      return LocationAccessStatus.unsupported;
    } catch (_) {
      return LocationAccessStatus.denied;
    }
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }

  LocationAccessStatus _statusFor(LocationPermission permission) {
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return LocationAccessStatus.granted;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAccessStatus.deniedForever;
    }
    return LocationAccessStatus.denied;
  }
}
