import '../utils/text.dart';
import 'fuel_type.dart';

class Station {
  Station({
    required this.id,
    required this.brand,
    required this.address,
    required this.municipality,
    this.municipalityId = '',
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

  /// Código de municipio del Ministerio ("187" = Calpe/Calp).
  final String municipalityId;

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

  /// Precio máximo creíble por litro; por encima se descarta como dato erróneo.
  static const maxPrice = 10.0;

  /// Longitud máxima de los textos que llegan de la API.
  static const maxTextLength = 200;

  /// Construye una estación a partir de un elemento de `ListaEESSPrecio`.
  /// Devuelve `null` si no tiene identificador o coordenadas válidas. Los
  /// datos se tratan como no fiables: precios fuera de rango se ignoran y
  /// los textos se recortan.
  static Station? fromApi(Map<String, dynamic> j) {
    final id = _text(j['IDEESS']);
    final lat = _number(j['Latitud']);
    final lng = _number(j['Longitud (WGS84)']);
    if (id.isEmpty || lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;

    final prices = <FuelType, double>{};
    for (final fuel in FuelType.values) {
      final p = _number(j[fuel.apiKey]);
      if (p != null && p > 0 && p < maxPrice) prices[fuel] = p;
    }

    return Station(
      id: id,
      brand: prettyName(_text(j['Rótulo'])),
      address: prettyName(_text(j['Dirección'])),
      municipality: prettyName(_text(j['Municipio'])),
      municipalityId: _text(j['IDMunicipio']),
      locality: prettyName(_text(j['Localidad'])),
      province: prettyName(_text(j['Provincia'])),
      provinceId: _text(j['IDProvincia']),
      communityId: _text(j['IDCCAA']),
      postalCode: _text(j['C.P.']),
      schedule: _text(j['Horario']),
      latitude: lat,
      longitude: lng,
      prices: prices,
    );
  }

  /// La API usa coma decimal ("1,949") y cadenas vacías para "sin dato".
  static double? _number(Object? v) {
    if (v is! String || v.isEmpty || v.length > 20) return null;
    final n = double.tryParse(v.replaceAll(',', '.'));
    return n != null && n.isFinite ? n : null;
  }

  static String _text(Object? v) {
    if (v is! String) return v is num ? '$v' : '';
    final t = v.trim();
    return t.length > maxTextLength ? t.substring(0, maxTextLength) : t;
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
