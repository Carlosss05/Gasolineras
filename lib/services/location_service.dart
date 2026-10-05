import 'dart:ui' show Locale;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  late final Geocoding _geocoding = Geocoding(locale: const Locale('es', 'ES'));

  /// Pide permiso si hace falta. Devuelve `true` si se puede usar el GPS.
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  }

  Future<Position?> current() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Emite una posición nueva cada vez que te desplazas [distanceFilterMeters].
  Stream<Position> watch({int distanceFilterMeters = 100}) => Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        ),
      );

  /// Código de provincia (INE, "03" = Alicante) para unas coordenadas.
  /// Los dos primeros dígitos del código postal español son la provincia.
  Future<String?> provinceIdAt(double latitude, double longitude) async {
    try {
      final marks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
      for (final m in marks) {
        final cp = m.postalCode ?? '';
        if (RegExp(r'^\d{5}$').hasMatch(cp)) return cp.substring(0, 2);
      }
    } catch (_) {
      // Sin conexión o sin servicio de geocodificación: el usuario elige zona.
    }
    return null;
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
}
