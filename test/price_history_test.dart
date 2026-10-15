import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/logic/price_trend.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/price_history.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/stations_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Station _station(String id, double price) => Station(
  id: id,
  brand: 'Marca $id',
  address: '',
  municipality: 'Alicante',
  province: 'Alicante',
  provinceId: '03',
  communityId: '10',
  postalCode: '03001',
  schedule: '',
  latitude: 38.34,
  longitude: -0.48,
  prices: {FuelType.gasolina95: price},
);

Uint8List _historyBody(Map<String, String> prices) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'Fecha': '14/10/2026 0:00:00',
      'ListaEESSPrecio': [
        for (final e in prices.entries) {'IDEESS': e.key, 'PrecioProducto': e.value},
      ],
    }),
  ),
);

/// Repositorio falso: lista fija y un histórico por número de días atrás.
class _Repository extends MineturRepository {
  _Repository(this.items, this.byDaysAgo);

  final List<Station> items;
  final Map<int, Map<String, double>> byDaysAgo;
  final requested = <DateTime>[];

  @override
  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false}) async =>
      PriceSnapshot(stations: items, publishedAt: DateTime(2026, 10, 15, 9));

  @override
  Future<PriceHistory> history(SearchScope scope, FuelType fuel, DateTime day) async {
    requested.add(day);
    final prices = byDaysAgo[DateTime(2026, 10, 15).difference(day).inDays];
    if (prices == null) throw Exception('Sin publicar');
    return PriceHistory(day: day, prices: prices);
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('historyUrl', () {
    final day = DateTime(2026, 10, 4);

    test('usa el filtro más pequeño que cubre la zona', () {
      expect(
        historyUrl(const SearchScope.province('03', 'Alicante'), FuelType.gasolina95, day),
        endsWith('/EstacionesTerrestresHist/FiltroProvinciaProducto/04-10-2026/03/1'),
      );
      expect(
        historyUrl(const SearchScope.myTown('03', '140', 'Agost'), FuelType.diesel, day),
        endsWith('/EstacionesTerrestresHist/FiltroMunicipioProducto/04-10-2026/140/4'),
      );
      expect(
        historyUrl(const SearchScope.community('10', 'Comunitat Valenciana'), FuelType.gasolina95E10, day),
        endsWith('/EstacionesTerrestresHist/FiltroCCAAProducto/04-10-2026/10/23'),
      );
    });

    test('no pide toda España (4 MB por día)', () {
      expect(historyUrl(const SearchScope.spain(), FuelType.gasolina95, day), isNull);
    });
  });

  test('parseHistory descarta ids y precios no válidos', () {
    final prices = parseHistory(
      _historyBody({'1': '1,619', '2': '', '3': 'abc', '4': '99,0', ' 5 ': '1,7', '': '1,5'}),
    );
    expect(prices, {'1': 1.619, '5': 1.7});
  });

  test('cada día se descarga una vez y los fallos no se guardan', () async {
    var calls = 0;
    var fail = true;
    final repo = MineturRepository(
      client: MockClient((_) async {
        calls++;
        if (fail) return http.Response('', 400);
        return http.Response.bytes(_historyBody({'1': '1,6'}), 200);
      }),
    );
    const scope = SearchScope.province('03', 'Alicante');
    final day = DateTime(2026, 10, 14);

    await expectLater(repo.history(scope, FuelType.gasolina95, day), throwsA(anything));
    fail = false;
    final first = await repo.history(scope, FuelType.gasolina95, day);
    final again = await repo.history(scope, FuelType.gasolina95, day);
    expect(first.prices, {'1': 1.6});
    expect(identical(first, again), isTrue);
    expect(calls, 2);
  });

  test('zoneTrend solo compara gasolineras con precio los dos días', () {
    final entries = [
      StationEntry(_station('a', 1.60), 1.60, null),
      StationEntry(_station('b', 1.70), 1.70, null),
      StationEntry(_station('c', 1.80), 1.80, null),
    ];
    final trend = zoneTrend(entries, PriceHistory(day: DateTime(2026, 10, 14), prices: {'a': 1.62, 'b': 1.69}))!;
    expect(trend.compared, 2);
    expect(trend.change, closeTo(-0.005, 1e-9));
    expect(trend.down, 1);
    expect(trend.up, 1);
  });

  group('controlador', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('compara con ayer y con hace una semana', () async {
      final repo = _Repository(
        [_station('a', 1.60), _station('b', 1.70)],
        {
          1: {'a': 1.62, 'b': 1.70},
          7: {'a': 1.65, 'b': 1.66},
        },
      );
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      await c.chooseScope(const SearchScope.province('03', 'Alicante'));
      await _settle();

      expect(c.hasTrend, isTrue);
      expect(c.priceChange('a', 1.60), closeTo(-0.02, 1e-9));
      expect(c.priceChange('b', 1.70), closeTo(0, 1e-9));
      expect(c.zoneTrendFor(TrendPeriod.day)!.change, closeTo(-0.01, 1e-9));
      expect(c.zoneTrendFor(TrendPeriod.week)!.since, DateTime(2026, 10, 8));

      c.setTrendPeriod(TrendPeriod.week);
      expect(c.priceChange('b', 1.70), closeTo(0.04, 1e-9));
    });

    test('si ayer aún no está publicado, usa anteayer', () async {
      final repo = _Repository(
        [_station('a', 1.60)],
        {
          2: {'a': 1.61},
        },
      );
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      await c.chooseScope(const SearchScope.province('03', 'Alicante'));
      await _settle();

      expect(c.zoneTrendFor(TrendPeriod.day)!.since, DateTime(2026, 10, 13));
      expect(c.zoneTrendFor(TrendPeriod.week), isNull);
      expect(repo.requested, containsAll([DateTime(2026, 10, 14), DateTime(2026, 10, 13)]));
    });

    test('en toda España no se descarga el histórico', () async {
      final repo = _Repository(
        [_station('a', 1.60)],
        {
          1: {'a': 1.61},
        },
      );
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      await c.chooseScope(const SearchScope.spain());
      await _settle();

      expect(c.hasTrend, isFalse);
      expect(repo.requested, isEmpty);
    });
  });
}
