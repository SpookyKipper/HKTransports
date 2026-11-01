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

  Future<LocationAccessStatus> requestAccess() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return LocationAccessStatus.serviceDisabled;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return LocationAccessStatus.granted;
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationAccessStatus.deniedForever;
      }
      return LocationAccessStatus.denied;
    } on MissingPluginException {
      return LocationAccessStatus.unsupported;
    } on UnsupportedError {
      return LocationAccessStatus.unsupported;
    } catch (_) {
      return LocationAccessStatus.denied;
    }
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
}
