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

void main() {
  test('coste del viaje de ida y vuelta', () {
    // 10 km ida + 10 vuelta = 20 km · 6 L/100 km = 1,2 L · 1,60 €/L = 1,92 €.
    expect(roundTripCost(distanceKm: 10, consumption: 6, price: 1.6), closeTo(1.92, 1e-9));
  });

  group('¿Merece la pena ir?', () {
    test('sí, si el ahorro en combustible supera el viaje extra', () {
      final r = compareCheapestWithNearest([_e('cerca', 1.70, 1), _e('barata', 1.60, 5)], _car)!;
      expect(r.cheapest.station.id, 'barata');
      expect(r.nearest.station.id, 'cerca');
      expect(r.fuelSaving, closeTo(5.0, 1e-9)); // 0,10 €/L · 50 L
      // Viaje: 2·5·0,06·1,60 = 0,96 € frente a 2·1·0,06·1,70 = 0,204 €.
      expect(r.extraTripCost, closeTo(0.756, 1e-9));
      expect(r.worthIt, isTrue);
    });

    test('no, si la barata está tan lejos que el viaje se come el ahorro', () {
      final r = compareCheapestWithNearest([_e('cerca', 1.62, 0.5), _e('lejos', 1.60, 40)], _car)!;
      expect(r.netSaving, lessThan(0));
      expect(r.worthIt, isFalse);
    });

    test('sin comparación si la más barata ya es la más cercana o no hay ubicación', () {
      expect(compareCheapestWithNearest([_e('a', 1.6, 1), _e('b', 1.7, 3)], _car), isNull);
      expect(
        compareCheapestWithNearest([
          StationEntry(_st('a', 1.6, 0, 0), 1.6, null),
          StationEntry(_st('b', 1.7, 0, 0), 1.7, null),
        ], _car),
        isNull,
      );
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
      car: _car,
    );
    expect(byValue.first.station.id, 'cerca');

    // Sin coche, "Rentables" ordena por precio.
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
