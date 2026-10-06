import '../models/region.dart';
import '../models/station.dart';

/// Fuente de precios. La app solo depende de esta interfaz, de modo que se
/// puede sustituir la API pública por un backend propio (caché, histórico,
/// notificaciones…) sin tocar la interfaz de usuario.
abstract interface class FuelPriceRepository {
  Future<List<Province>> provinces();

  Future<List<Community>> communities();

  /// Todos los municipios de España, para buscar pueblos fuera de la zona.
  Future<List<Municipality>> municipalities();

  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false});
}

class FuelApiException implements Exception {
  FuelApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
