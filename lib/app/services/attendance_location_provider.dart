import 'dart:async';

import 'package:geolocator/geolocator.dart';

class AttendanceLocationException implements Exception {
  const AttendanceLocationException(this.message);

  final String message;
}

class AttendanceLocationFix {
  const AttendanceLocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };
}

abstract interface class AttendanceLocationProvider {
  Future<AttendanceLocationFix> getCurrentFix();
}

class GeolocatorAttendanceLocationProvider
    implements AttendanceLocationProvider {
  const GeolocatorAttendanceLocationProvider();

  @override
  Future<AttendanceLocationFix> getCurrentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AttendanceLocationException(
        'Enable device location services to record attendance.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const AttendanceLocationException(
        'Location permission is required to record attendance.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AttendanceLocationException(
        'Location permission is blocked. Enable it in device settings to record attendance.',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const AttendanceLocationException(
        'Location permission is required to record attendance.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          !position.accuracy.isFinite ||
          position.accuracy <= 0 ||
          position.accuracy > 50) {
        throw const AttendanceLocationException(
          'GPS accuracy is not sufficient. Move to an open area and retry.',
        );
      }
      return AttendanceLocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
      );
    } on LocationServiceDisabledException {
      throw const AttendanceLocationException(
        'Enable device location services to record attendance.',
      );
    } on PermissionDeniedException {
      throw const AttendanceLocationException(
        'Location permission is required to record attendance.',
      );
    } on TimeoutException {
      throw const AttendanceLocationException(
        'Could not get a current GPS location. Move to an open area and retry.',
      );
    }
  }
}
