import '../models/car.dart';
import '../state/stations_controller.dart';

/// Por carretera se recorre más que en línea recta. La app solo conoce la
/// distancia en línea recta, así que el viaje se estima multiplicándola por
/// este factor (el rodeo medio en carretera está entre 1,2 y 1,4).
const roadFactor = 1.3;

/// Cómo se va a repostar: cuántos litros, lo que gasta el coche y si hay que
/// volver al punto de partida.
class TripPlan {
  const TripPlan({required this.liters, required this.consumption, this.roundTrip = true});

  /// Litros que se van a repostar.
  final double liters;

  /// Consumo del coche, en litros cada 100 km.
  final double consumption;

  /// Ida y vuelta (se va a propósito) o solo ida (pilla de camino).
  final bool roundTrip;

  /// Valores típicos mientras no se configura el coche: un utilitario.
  static const defaultLiters = 40.0, defaultConsumption = 6.5;

  /// Límites de lo que se puede ajustar en la calculadora.
  static const minLiters = 5.0, maxLiters = 150.0;
  static const minConsumption = 3.0, maxConsumption = 20.0;
}

/// Lo que cuesta repostar en una gasolinera contando el viaje hasta ella.
class StationCost {
  const StationCost({required this.entry, required this.fuelCost, required this.tripKm, required this.tripCost});

  final StationEntry entry;

  /// Los litros que se repostan, al precio de esa gasolinera.
  final double fuelCost;

  /// Kilómetros de viaje por carretera (estimados); 0 sin ubicación.
  final double tripKm;

  /// Combustible que se gasta en el viaje, al precio de esa gasolinera (es
  /// el que se repone allí).
  final double tripCost;

  double get total => fuelCost + tripCost;
}

/// Coste de repostar en [e] con el plan [plan]. Sin ubicación solo cuenta el
/// combustible.
StationCost stationCost(StationEntry e, TripPlan plan) {
  final distance = e.distanceKm;
  final tripKm = distance == null ? 0.0 : distance * roadFactor * (plan.roundTrip ? 2 : 1);
  return StationCost(
    entry: e,
    fuelCost: plan.liters * e.price,
    tripKm: tripKm,
    tripCost: tripKm * plan.consumption / 100 * e.price,
  );
}

/// Solo el total de [stationCost], para ordenar miles de gasolineras sin
/// crear objetos.
double effectiveCost(StationEntry e, TripPlan plan) {
  final distance = e.distanceKm;
  final tripKm = distance == null ? 0.0 : distance * roadFactor * (plan.roundTrip ? 2 : 1);
  return e.price * (plan.liters + tripKm * plan.consumption / 100);
}

/// A qué gasolinera conviene ir: la de menor coste total, comparada con la
/// más cercana y con la más barata.
class Recommendation {
  const Recommendation({
    required this.plan,
    required this.best,
    required this.nearest,
    required this.cheapest,
    required this.ranking,
  });

  final TripPlan plan;

  /// La de menor coste total (combustible + viaje).
  final StationCost best;
  final StationCost nearest;
  final StationCost cheapest;

  /// Las mejores por coste total, empezando por [best].
  final List<StationCost> ranking;

  bool get bestIsNearest => best.entry.station.id == nearest.entry.station.id;
  bool get bestIsCheapest => best.entry.station.id == cheapest.entry.station.id;

  /// Lo que se ahorra yendo a la recomendada en vez de a la más cercana.
  double get savingVsNearest => nearest.total - best.total;

  /// Lo que costaría de más ir a la más barata en vez de a la recomendada.
  double get extraOfCheapest => cheapest.total - best.total;
}

/// Calcula la recomendación entre las gasolineras de [entries] con distancia
/// conocida. `null` si no hay ubicación. Una sola pasada: sirve igual para un
/// pueblo que para toda España.
Recommendation? recommend(Iterable<StationEntry> entries, TripPlan plan, {int top = 5}) {
  StationCost? nearest, cheapest;
  final ranking = <StationCost>[];
  for (final e in entries) {
    final distance = e.distanceKm;
    if (distance == null) continue;
    final total = effectiveCost(e, plan);
    final nearer = nearest == null || distance < nearest.entry.distanceKm!;
    final cheaper =
        cheapest == null ||
        e.price < cheapest.entry.price ||
        (e.price == cheapest.entry.price && distance < cheapest.entry.distanceKm!);
    final ranks = ranking.length < top || total < ranking.last.total;
    if (!nearer && !cheaper && !ranks) continue;

    final cost = stationCost(e, plan);
    if (nearer) nearest = cost;
    if (cheaper) cheapest = cost;
    if (ranks) {
      // Inserción ordenada; a igual coste, primero la que ya estaba (más
      // arriba en la lista del usuario).
      var i = ranking.length;
      while (i > 0 && ranking[i - 1].total > total) {
        i--;
      }
      ranking.insert(i, cost);
      if (ranking.length > top) ranking.removeLast();
    }
  }
  if (ranking.isEmpty) return null;
  final best = ranking.first;
  return Recommendation(plan: plan, best: best, nearest: nearest!, cheapest: cheapest!, ranking: ranking);
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

  final chronological = entries.toList()..sort((a, b) => a.date.compareTo(b.date));
  final withKm = chronological.where((e) => e.odometerKm != null).toList();
  double? consumption;
  if (withKm.length >= 2) {
    final distance = withKm.last.odometerKm! - withKm.first.odometerKm!;
    final first = chronological.indexOf(withKm.first);
    final last = chronological.indexOf(withKm.last);
    final used = chronological.sublist(first + 1, last + 1).fold<double>(0, (sum, e) => sum + e.liters);
    final increasing = List.generate(
      withKm.length - 1,
      (i) => withKm[i + 1].odometerKm! > withKm[i].odometerKm!,
    ).every((valid) => valid);
    if (distance > 0 && increasing) consumption = used / distance * 100;
  }

  return RefuelStats(
    spentThisMonth: spent,
    litersThisMonth: liters,
    totalSaving: saving,
    averagePrice: allLiters > 0 ? allEuros / allLiters : null,
    consumption: consumption,
  );
}
