import '../utils/text.dart';
import 'fuel_type.dart';

class Station {
  Station({
    required this.id,
    required this.brand,
    required this.address,
    required this.municipality,
    this.locality = '',
    required this.province,
    required this.provinceId,
    required this.communityId,
    required this.postalCode,
    required this.schedule,
    required this.latitude,
    required this.longitude,
    required this.prices,
  }) : searchText = normalize('$brand $address $municipality $locality $postalCode');

  final String id;
  final String brand;
  final String address;
  final String municipality;

  /// Núcleo de población (pedanía, urbanización…), p. ej. "La Zenia".
  final String locality;
  final String province;
  final String provinceId;
  final String communityId;
  final String postalCode;
  final String schedule;
  final double latitude;
  final double longitude;
  final Map<FuelType, double> prices;

  /// Texto normalizado sobre el que se aplica el buscador.
  final String searchText;

  /// Construye una estación a partir de un elemento de `ListaEESSPrecio`.
  /// Devuelve `null` si no tiene coordenadas válidas.
  static Station? fromApi(Map<String, dynamic> j) {
    final lat = _number(j['Latitud']);
    final lng = _number(j['Longitud (WGS84)']);
    if (lat == null || lng == null) return null;

    final prices = <FuelType, double>{};
    for (final fuel in FuelType.values) {
      final p = _number(j[fuel.apiKey]);
      if (p != null && p > 0) prices[fuel] = p;
    }

    return Station(
      id: '${j['IDEESS']}',
      brand: prettyName('${j['Rótulo'] ?? ''}'),
      address: prettyName('${j['Dirección'] ?? ''}'),
      municipality: prettyName('${j['Municipio'] ?? ''}'),
      locality: prettyName('${j['Localidad'] ?? ''}'),
      province: prettyName('${j['Provincia'] ?? ''}'),
      provinceId: '${j['IDProvincia'] ?? ''}',
      communityId: '${j['IDCCAA'] ?? ''}',
      postalCode: '${j['C.P.'] ?? ''}',
      schedule: '${j['Horario'] ?? ''}',
      latitude: lat,
      longitude: lng,
      prices: prices,
    );
  }

  /// La API usa coma decimal ("1,949") y cadenas vacías para "sin dato".
  static double? _number(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return double.tryParse(v.replaceAll(',', '.'));
  }
}

/// Resultado de una consulta: estaciones y momento en que el Ministerio
/// publicó esos precios.
class PriceSnapshot {
  PriceSnapshot({required this.stations, required this.publishedAt, DateTime? fetchedAt})
    : fetchedAt = fetchedAt ?? DateTime.now();

  final List<Station> stations;
  final DateTime? publishedAt;
  final DateTime fetchedAt;
}
