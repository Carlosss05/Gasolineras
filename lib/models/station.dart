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
  });

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

  /// Texto normalizado sobre el que se aplica el buscador. Se calcula la
  /// primera vez que se busca, no al descargar: la mayoría de las veces no
  /// hace falta y son miles de gasolineras.
  late final String searchText = normalize('$brand $address $municipality $locality $postalCode');

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

  /// Forma compacta para guardar los últimos precios en el dispositivo (una
  /// lista en vez de un mapa: la mitad de tamaño con cientos de gasolineras).
  List<Object> toCache() => [
    id,
    brand,
    address,
    municipality,
    municipalityId,
    locality,
    province,
    provinceId,
    communityId,
    postalCode,
    schedule,
    latitude,
    longitude,
    {for (final e in prices.entries) e.key.name: e.value},
  ];

  /// Lee lo guardado con [toCache]. Lo guardado en el dispositivo se puede
  /// manipular, así que pasa los mismos filtros que la API: devuelve `null`
  /// ante tipos inesperados o valores fuera de rango.
  static Station? fromCache(Object? raw) {
    if (raw is! List || raw.length != 14) return null;
    final lat = raw[11], lng = raw[12], rawPrices = raw[13];
    if (lat is! num || lng is! num || rawPrices is! Map) return null;
    final latitude = lat.toDouble(), longitude = lng.toDouble();
    if (!latitude.isFinite || !longitude.isFinite || latitude.abs() > 90 || longitude.abs() > 180) return null;
    for (var i = 0; i < 11; i++) {
      if (raw[i] is! String) return null;
    }
    final id = _text(raw[0]);
    if (id.isEmpty) return null;

    final prices = <FuelType, double>{};
    for (final fuel in FuelType.values) {
      final p = rawPrices[fuel.name];
      if (p is num && p.isFinite && p > 0 && p < maxPrice) prices[fuel] = p.toDouble();
    }
    return Station(
      id: id,
      brand: _text(raw[1]),
      address: _text(raw[2]),
      municipality: _text(raw[3]),
      municipalityId: _text(raw[4]),
      locality: _text(raw[5]),
      province: _text(raw[6]),
      provinceId: _text(raw[7]),
      communityId: _text(raw[8]),
      postalCode: _text(raw[9]),
      schedule: _text(raw[10]),
      latitude: latitude,
      longitude: longitude,
      prices: prices,
    );
  }

  static double? _number(Object? v) => parseApiNumber(v);

  static String _text(Object? v) {
    if (v is! String) return v is num ? '$v' : '';
    final t = v.trim();
    return t.length > maxTextLength ? t.substring(0, maxTextLength) : t;
  }
}

/// Número de la API, que usa coma decimal ("1,949") y cadenas vacías para
/// "sin dato".
double? parseApiNumber(Object? v) {
  if (v is! String || v.isEmpty || v.length > 20) return null;
  final n = double.tryParse(v.replaceAll(',', '.'));
  return n != null && n.isFinite ? n : null;
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
