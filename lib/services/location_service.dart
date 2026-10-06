import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  LocationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  late final Geocoding _geocoding = Geocoding(locale: const Locale('es', 'ES'));

  /// Pide permiso si hace falta. Devuelve `true` si se puede usar el GPS.
  Future<bool> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<Position?> current() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      // getLastKnownPosition no existe en la web y ahí lanza una excepción.
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Emite una posición nueva cada vez que te desplazas [distanceFilterMeters].
  Stream<Position> watch({int distanceFilterMeters = 100}) => Geolocator.getPositionStream(
    locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters),
  );

  /// Código de provincia (INE, "03" = Alicante) para unas coordenadas.
  ///
  /// Primero prueba el geocodificador del sistema (Android/iOS). En la web no
  /// existe, así que se usa OpenStreetMap (Nominatim), que también sirve de
  /// respaldo si el del sistema falla.
  Future<String?> provinceIdAt(double latitude, double longitude) async {
    if (!kIsWeb) {
      try {
        final marks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
        for (final m in marks) {
          final id = provinceFromPostalCode(m.postalCode);
          if (id != null) return id;
        }
      } catch (_) {
        // Sin servicio de geocodificación: se prueba con OpenStreetMap.
      }
    }
    return _provinceFromNominatim(latitude, longitude);
  }

  Future<String?> _provinceFromNominatim(double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
        'zoom': '18',
        'addressdetails': '1',
      });
      final res = await _client
          .get(
            uri,
            // Nominatim exige identificar la app. En la web el navegador no
            // deja cambiar el User-Agent y basta con el Referer.
            headers: kIsWeb ? null : {'User-Agent': 'Gasolineras/1.0 (github.com/Carlosss05/Gasolineras)'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return provinceFromAddress((json['address'] as Map?)?.cast<String, dynamic>() ?? const {});
    } catch (_) {
      return null;
    }
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
}

/// Los dos primeros dígitos del código postal español son la provincia.
String? provinceFromPostalCode(String? postalCode) {
  final cp = postalCode?.trim() ?? '';
  if (!RegExp(r'^\d{5}$').hasMatch(cp)) return null;
  final id = cp.substring(0, 2);
  final n = int.parse(id);
  return n >= 1 && n <= 52 ? id : null;
}

/// Provincia a partir de la dirección de Nominatim: código postal o, si no
/// lo hay (zonas rurales), el código ISO 3166-2 de la provincia o comunidad.
String? provinceFromAddress(Map<String, dynamic> address) {
  if (address['country_code'] != null && address['country_code'] != 'es') return null;
  return provinceFromPostalCode(address['postcode'] as String?) ??
      _isoToIne[address['ISO3166-2-lvl6']] ??
      _isoToIne[address['ISO3166-2-lvl4']];
}

/// ISO 3166-2 (provincias y comunidades uniprovinciales) -> código INE.
const _isoToIne = {
  'ES-VI': '01',
  'ES-AB': '02',
  'ES-A': '03',
  'ES-AL': '04',
  'ES-AV': '05',
  'ES-BA': '06',
  'ES-PM': '07',
  'ES-IB': '07',
  'ES-B': '08',
  'ES-BU': '09',
  'ES-CC': '10',
  'ES-CA': '11',
  'ES-CS': '12',
  'ES-CR': '13',
  'ES-CO': '14',
  'ES-C': '15',
  'ES-CU': '16',
  'ES-GI': '17',
  'ES-GR': '18',
  'ES-GU': '19',
  'ES-SS': '20',
  'ES-H': '21',
  'ES-HU': '22',
  'ES-J': '23',
  'ES-LE': '24',
  'ES-L': '25',
  'ES-LO': '26',
  'ES-RI': '26',
  'ES-LU': '27',
  'ES-M': '28',
  'ES-MD': '28',
  'ES-MA': '29',
  'ES-MU': '30',
  'ES-MC': '30',
  'ES-NA': '31',
  'ES-NC': '31',
  'ES-O': '33',
  'ES-AS': '33',
  'ES-OR': '32',
  'ES-P': '34',
  'ES-GC': '35',
  'ES-PO': '36',
  'ES-SA': '37',
  'ES-TF': '38',
  'ES-S': '39',
  'ES-CB': '39',
  'ES-SG': '40',
  'ES-SE': '41',
  'ES-SO': '42',
  'ES-T': '43',
  'ES-TE': '44',
  'ES-TO': '45',
  'ES-V': '46',
  'ES-VA': '47',
  'ES-BI': '48',
  'ES-ZA': '49',
  'ES-Z': '50',
  'ES-CE': '51',
  'ES-ML': '52',
};
