import '../models/car.dart';
import '../state/stations_controller.dart';

/// Coste de ir a una gasolinera y volver, con el combustible que se va a
/// pagar allí.
double roundTripCost({required double distanceKm, required double consumption, required double price}) =>
    2 * distanceKm * consumption / 100 * price;

/// Coste real de llenar el depósito en una gasolinera: el combustible más
/// lo que se gasta en el viaje de ida y vuelta.
double effectiveCost(StationEntry e, CarProfile car) =>
    e.price * car.tankLiters +
    (e.distanceKm == null
        ? 0
        : roundTripCost(distanceKm: e.distanceKm!, consumption: car.consumption, price: e.price));

/// Comparación entre ir a la gasolinera más barata o a la más cercana.
class WorthIt {
  const WorthIt({
    required this.cheapest,
    required this.nearest,
    required this.fuelSaving,
    required this.extraTripCost,
  });

  final StationEntry cheapest;
  final StationEntry nearest;

  /// Lo que se ahorra en combustible llenando el depósito en la barata.
  final double fuelSaving;

  /// Lo que cuesta de más el viaje a la barata frente a la cercana.
  final double extraTripCost;

  double get netSaving => fuelSaving - extraTripCost;
  bool get worthIt => netSaving > 0.05;
}

/// `null` si no se puede comparar (sin ubicación) o si la más barata ya es
/// la más cercana.
WorthIt? compareCheapestWithNearest(List<StationEntry> entries, CarProfile car) {
  final located = entries.where((e) => e.distanceKm != null).toList();
  if (located.length < 2) return null;
  final cheapest = located.reduce((a, b) => b.price < a.price ? b : a);
  final nearest = located.reduce((a, b) => b.distanceKm! < a.distanceKm! ? b : a);
  if (identical(cheapest, nearest) || cheapest.station.id == nearest.station.id) return null;

  final fuelSaving = (nearest.price - cheapest.price) * car.tankLiters;
  final extraTrip =
      roundTripCost(distanceKm: cheapest.distanceKm!, consumption: car.consumption, price: cheapest.price) -
      roundTripCost(distanceKm: nearest.distanceKm!, consumption: car.consumption, price: nearest.price);
  return WorthIt(cheapest: cheapest, nearest: nearest, fuelSaving: fuelSaving, extraTripCost: extraTrip);
}

/// Resumen del diario de repostajes.
class RefuelStats {
  const RefuelStats({
    required this.spentThisMonth,
    required this.litersThisMonth,
    required this.totalSaving,
    required this.averagePrice,
    required this.consumption,
  });

  final double spentThisMonth;
  final double litersThisMonth;
  final double totalSaving;

  /// Precio medio pagado por litro (ponderado por litros), o `null` sin datos.
  final double? averagePrice;

  /// Consumo real en L/100 km a partir del cuentakilómetros, o `null` si
  /// todavía no hay al menos dos repostajes con kilómetros.
  final double? consumption;
}

/// Calcula el resumen. El consumo supone que en cada repostaje se llena el
/// depósito: los litros puestos desde el primer registro con kilómetros son
/// los gastados en la distancia recorrida.
RefuelStats computeStats(List<RefuelEntry> entries, {required DateTime now}) {
  var spent = 0.0, liters = 0.0, saving = 0.0, allLiters = 0.0, allEuros = 0.0;
  for (final e in entries) {
    saving += e.saving;
    allLiters += e.liters;
    allEuros += e.totalEuros;
    if (e.date.year == now.year && e.date.month == now.month) {
      spent += e.totalEuros;
      liters += e.liters;
    }
  }

  final withKm = entries.where((e) => e.odometerKm != null).toList()
    ..sort((a, b) => a.odometerKm!.compareTo(b.odometerKm!));
  double? consumption;
  if (withKm.length >= 2) {
    final distance = withKm.last.odometerKm! - withKm.first.odometerKm!;
    final used = withKm.skip(1).fold<double>(0, (sum, e) => sum + e.liters);
    if (distance > 0) consumption = used / distance * 100;
  }

  return RefuelStats(
    spentThisMonth: spent,
    litersThisMonth: liters,
    totalSaving: saving,
    averagePrice: allLiters > 0 ? allEuros / allLiters : null,
    consumption: consumption,
  );
}
