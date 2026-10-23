import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationService {
  static const _maximumAccuracyMeters = 500.0;

  static Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Turn on device location services and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        'Location permission is needed to share your current pin.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        kIsWeb
            ? 'Allow location access for this site in your browser settings, then retry.'
            : 'Enable location permission for LifePulse AI in device Settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      ).timeout(const Duration(seconds: 30));
      if (position.accuracy > _maximumAccuracyMeters) {
        throw LocationException(
          'Location is only accurate to about ${position.accuracy.round()} m. '
          'Allow location access in your browser or device settings, then retry outdoors. '
          'LifePulse accepts location estimates within ${_maximumAccuracyMeters.round()} m.',
        );
      }
      return position;
    } on TimeoutException {
      throw const LocationException(
        kIsWeb
            ? 'The browser could not get your location. Allow location access for this site and retry.'
            : 'Could not get a GPS fix. Move near a window or outdoors and retry.',
      );
    } on PermissionDeniedException {
      throw const LocationException(
        kIsWeb
            ? 'Location access is blocked for this site. Allow it in your browser site settings and retry.'
            : 'Location permission is blocked. Enable it for LifePulse AI in device Settings.',
      );
    } on PositionUpdateException {
      throw const LocationException(
        kIsWeb
            ? 'The browser could not determine your location. Check browser location access and retry.'
            : 'Could not get a GPS fix. Check device location services and retry outdoors.',
      );
    }
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}
