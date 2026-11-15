import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/logic/savings.dart';
import 'package:gasolineras/models/car.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/state/stations_controller.dart';

Station _st(String id, double price, double lat, double lng) => Station(
  id: id,
  brand: id,
  address: '',
  municipality: 'Calpe/Calp',
  province: 'Alicante',
  provinceId: '03',
  communityId: '10',
  postalCode: '03710',
  schedule: '',
  latitude: lat,
  longitude: lng,
  prices: {FuelType.gasolina95: price},
);

StationEntry _e(String id, double price, double km) => StationEntry(_st(id, price, 0, 0), price, km);

const _car = CarProfile(fuel: FuelType.gasolina95, tankLiters: 50, consumption: 6);

/// Llenar 50 L con un coche que gasta 6 L/100 km, ida y vuelta.
const _plan = TripPlan(liters: 50, consumption: 6);

void main() {
  test('coste de repostar contando el viaje', () {
    // 10 km en línea recta ≈ 13 km por carretera; ida y vuelta, 26 km.
    // 26 km · 6 L/100 km = 1,56 L · 1,60 €/L = 2,496 €.
    final cost = stationCost(_e('a', 1.6, 10), _plan);
    expect(cost.fuelCost, closeTo(80, 1e-9));
    expect(cost.tripKm, closeTo(26, 1e-9));
    expect(cost.tripCost, closeTo(2.496, 1e-9));
    expect(cost.total, closeTo(82.496, 1e-9));
    expect(effectiveCost(_e('a', 1.6, 10), _plan), closeTo(cost.total, 1e-9));

    // Solo ida: la mitad de viaje.
    const oneWay = TripPlan(liters: 50, consumption: 6, roundTrip: false);
    expect(stationCost(_e('a', 1.6, 10), oneWay).tripCost, closeTo(1.248, 1e-9));

    // Sin ubicación solo cuenta el combustible.
    final unknown = StationEntry(_st('a', 1.6, 0, 0), 1.6, null);
    expect(stationCost(unknown, _plan).total, closeTo(80, 1e-9));
    expect(effectiveCost(unknown, _plan), closeTo(80, 1e-9));
  });

  group('¿Dónde reposto?', () {
    test('la barata, si lo que ahorra en combustible supera el viaje', () {
      final r = recommend([_e('cerca', 1.70, 1), _e('barata', 1.60, 5)], _plan)!;
      // Cerca: 85 € + 2,6 km·0,06·1,70 = 85,2652 €. Barata: 80 € + 13 km·0,06·1,60 = 81,248 €.
      expect(r.best.entry.station.id, 'barata');
      expect(r.nearest.entry.station.id, 'cerca');
      expect(r.cheapest.entry.station.id, 'barata');
      expect(r.best.total, closeTo(81.248, 1e-9));
      expect(r.savingVsNearest, closeTo(4.0172, 1e-9));
      expect(r.bestIsCheapest, isTrue);
      expect(r.bestIsNearest, isFalse);
    });

    test('la cercana, si la barata está tan lejos que el viaje se come el ahorro', () {
      final r = recommend([_e('cerca', 1.62, 0.5), _e('lejos', 1.60, 40)], _plan)!;
      expect(r.best.entry.station.id, 'cerca');
      expect(r.cheapest.entry.station.id, 'lejos');
      expect(r.bestIsNearest, isTrue);
      // La barata saldría 8,86 € más cara: 89,984 € frente a 81,12636 €.
      expect(r.extraOfCheapest, closeTo(8.85764, 1e-9));
    });

    test('con pocos litros pesa más el viaje: cambia la recomendación', () {
      final stations = [_e('cerca', 1.70, 1), _e('barata', 1.60, 5)];
      expect(recommend(stations, _plan)!.best.entry.station.id, 'barata');
      const few = TripPlan(liters: 5, consumption: 6);
      expect(recommend(stations, few)!.best.entry.station.id, 'cerca');
    });

    test('la clasificación va de menor a mayor coste y se limita a las mejores', () {
      final stations = [for (var i = 0; i < 20; i++) _e('s$i', 1.5 + i / 100, 1.0 + (i * 7 % 20))];
      final r = recommend(stations, _plan, top: 5)!;
      expect(r.ranking, hasLength(5));
      expect(r.ranking.first, same(r.best));
      for (var i = 1; i < r.ranking.length; i++) {
        expect(r.ranking[i].total, greaterThanOrEqualTo(r.ranking[i - 1].total));
      }
      // Ninguna de las que quedan fuera es mejor que la última de la clasificación.
      final all = stations.map((e) => effectiveCost(e, _plan)).toList()..sort();
      expect(r.ranking.last.total, closeTo(all[4], 1e-9));
    });

    test('sin ubicación no hay recomendación', () {
      final unknown = [StationEntry(_st('a', 1.6, 0, 0), 1.6, null), StationEntry(_st('b', 1.7, 0, 0), 1.7, null)];
      expect(recommend(unknown, _plan), isNull);
      expect(recommend(const <StationEntry>[], _plan), isNull);
    });
  });

  test('orden "Rentables": la barata y lejana baja si el viaje la encarece', () {
    final stations = [
      _st('cerca', 1.62, 38.6447, 0.0445), // a ~0 km
      _st('lejos', 1.60, 38.9500, 0.0445), // a ~34 km
    ];
    const here = (lat: 38.6447, lng: 0.0445);
    final byPrice = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.price, position: here);
    expect(byPrice.first.station.id, 'lejos');

    final byValue = buildEntries(
      stations,
      fuel: FuelType.gasolina95,
      sort: SortMode.value,
      position: here,
      plan: _plan,
    );
    expect(byValue.first.station.id, 'cerca');

    // Sin plan de repostaje, "Rentables" ordena por precio.
    final noCar = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.value, position: here);
    expect(noCar.first.station.id, 'lejos');
  });

  group('diario de repostajes', () {
    RefuelEntry r(DateTime d, double l, double total, {double? km, double? avg}) => RefuelEntry(
      id: '$d',
      date: d,
      fuel: FuelType.gasolina95,
      liters: l,
      totalEuros: total,
      odometerKm: km,
      zoneAverage: avg,
    );

    test('gasto del mes, ahorro, precio medio y consumo real', () {
      final now = DateTime(2026, 10, 20);
      final s = computeStats([
        r(DateTime(2026, 9, 28), 40, 64, km: 10000), // mes anterior
        r(DateTime(2026, 10, 5), 30, 48, km: 10500, avg: 1.70),
        r(DateTime(2026, 10, 15), 35, 56, km: 11000),
      ], now: now);

      expect(s.spentThisMonth, closeTo(104, 1e-9));
      expect(s.litersThisMonth, closeTo(65, 1e-9));
      // (1,70 - 1,60) · 30 L.
      expect(s.totalSaving, closeTo(3.0, 1e-9));
      expect(s.averagePrice, closeTo(168 / 105, 1e-9));
      // 65 L en 1.000 km.
      expect(s.consumption, closeTo(6.5, 1e-9));
    });

    test('incluye litros sin kilómetros solo dentro del intervalo medido', () {
      final s = computeStats([
        r(DateTime(2026, 10, 20), 25, 40), // fuera del intervalo
        r(DateTime(2026, 10, 15), 30, 48, km: 11000),
        r(DateTime(2026, 10, 10), 20, 32),
        r(DateTime(2026, 10, 5), 40, 64, km: 10000),
        r(DateTime(2026, 10, 1), 15, 24), // fuera del intervalo
      ], now: DateTime(2026, 10, 25));
      expect(s.consumption, closeTo(5, 1e-9));
    });

    test('no calcula consumo con cuentakilómetros decreciente', () {
      final s = computeStats([
        r(DateTime(2026, 10, 5), 40, 64, km: 11000),
        r(DateTime(2026, 10, 15), 30, 48, km: 10000),
      ], now: DateTime(2026, 10, 20));
      expect(s.consumption, isNull);
    });

    test('sin kilómetros suficientes no hay consumo', () {
      final s = computeStats([r(DateTime(2026, 10, 1), 30, 48, km: 1000)], now: DateTime(2026, 10, 2));
      expect(s.consumption, isNull);
      expect(computeStats([], now: DateTime(2026, 10, 2)).averagePrice, isNull);
    });

    test('se guarda y se recupera igual (JSON)', () {
      final e = r(DateTime(2026, 10, 5, 9, 30), 30, 48, km: 10500, avg: 1.7);
      final back = RefuelEntry.fromJson(e.toJson())!;
      expect(back.date, e.date);
      expect(back.liters, e.liters);
      expect(back.odometerKm, 10500);
      expect(back.saving, closeTo(e.saving, 1e-9));

      final car = CarProfile.fromJson(_car.toJson())!;
      expect(car.fuel, FuelType.gasolina95);
      expect(car.tankLiters, 50);
      expect(CarProfile.fromJson({'fuel': 'nope'}), isNull);
    });
  });
}
