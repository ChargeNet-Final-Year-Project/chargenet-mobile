import 'package:geolocator/geolocator.dart';

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();

  @override
  String toString() => 'Location permissions are denied.';
}

class LocationPermissionDeniedForeverException implements Exception {
  const LocationPermissionDeniedForeverException();

  @override
  String toString() => 'Location permission is permanently denied.';
}

Future<Position> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Location services are disabled');
  }
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      return Future.error(const LocationPermissionDeniedException());
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(const LocationPermissionDeniedForeverException());
  }

  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 12),
    ),
  );
}
