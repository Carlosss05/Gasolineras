import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/fuel_price_repository.dart';
import 'package:gasolineras/data/snapshot_store.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/price_history.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/stations_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Station _station(String id, double price, {String townId = '14'}) => Station(
  id: id,
  brand: 'Marca $id',
  address: 'Calle Mayor, 1',
  municipality: 'Alicante/Alacant',
  municipalityId: townId,
  locality: 'Alicante',
  province: 'Alicante',
  provinceId: '03',
  communityId: '10',
  postalCode: '03001',
  schedule: 'L-D: 24H',
  latitude: 38.34,
  longitude: -0.48,
  prices: {FuelType.gasolina95: price, FuelType.diesel: price - 0.1},
);

PriceSnapshot _snapshot(double price, {DateTime? fetchedAt}) => PriceSnapshot(
  stations: [_station('1', price), _station('2', price + 0.05)],
  publishedAt: DateTime(2026, 11, 14, 18, 30),
  fetchedAt: fetchedAt,
);

/// Repositorio falso completo (sin red): la respuesta se puede retrasar o
/// hacer fallar para probar el arranque.
class _Repo implements FuelPriceRepository {
  _Repo(this.fresh);

  PriceSnapshot fresh;
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  final _cache = <String, PriceSnapshot>{};

  @override
  Future<List<Province>> provinces() async => const [];

  @override
  Future<List<Community>> communities() async => const [];

  @override
  Future<List<Municipality>> municipalities() async => const [];

  @override
  PriceSnapshot? peek(SearchScope scope) => _cache[scope.cacheKey];

  @override
  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false}) async {
    calls++;
    await gate?.future;
    if (fail) throw FuelApiException('Sin red');
    return _cache[scope.cacheKey] = fresh;
  }

  @override
  Future<PriceHistory> history(SearchScope scope, FuelType fuel, DateTime day) async =>
      throw FuelApiException('Sin histórico');
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

const _alicante = SearchScope.province('03', 'Alicante');

/// Deja guardadas la zona y, si se pasa, sus últimos precios.
void _store({SearchScope scope = _alicante, PriceSnapshot? snapshot, String? snapshotKey}) {
  SharedPreferences.setMockInitialValues({
    'scope.v1': jsonEncode(scope.toJson()),
    if (snapshot != null) 'snapshot.v1': encodeSnapshot(snapshotKey ?? scope.cacheKey, snapshot),
  });
}

double _firstPrice(StationsController c) => c.snapshot!.stations.first.prices[FuelType.gasolina95]!;

void main() {
  final now = DateTime(2026, 11, 15, 10);

  group('precios guardados', () {
    test('se guardan y se recuperan iguales', () {
      final saved = _snapshot(1.619, fetchedAt: now.subtract(const Duration(hours: 3)));
      final back = decodeSnapshot(encodeSnapshot('P03', saved), 'P03', now: now)!;

      expect(back.publishedAt, saved.publishedAt);
      expect(back.fetchedAt, saved.fetchedAt);
      expect(back.stations, hasLength(2));
      final s = back.stations.first;
      expect(s.id, '1');
      expect(s.brand, 'Marca 1');
      expect(s.municipalityId, '14');
      expect(s.latitude, 38.34);
      expect(s.prices, {FuelType.gasolina95: 1.619, FuelType.diesel: closeTo(1.519, 1e-9)});
      // El texto de búsqueda se calcula al pedirlo.
      expect(s.searchText, contains('marca 1'));
    });

    test('de otra zona, caducados o con fecha futura no se usan', () {
      final raw = encodeSnapshot('P03', _snapshot(1.6, fetchedAt: now.subtract(const Duration(hours: 1))));
      expect(decodeSnapshot(raw, 'P46', now: now), isNull);
      expect(decodeSnapshot(raw, 'P03', now: now.add(const Duration(days: 15))), isNull);
      expect(decodeSnapshot(raw, 'P03', now: now.subtract(const Duration(days: 2))), isNull);
      expect(decodeSnapshot(raw, 'P03', now: now), isNotNull);
    });

    test('dañados o manipulados: se ignoran en vez de romper la app', () {
      expect(decodeSnapshot('no es json', 'P03', now: now), isNull);
      expect(decodeSnapshot('[1,2,3]', 'P03', now: now), isNull);
      expect(decodeSnapshot('{"key":"P03","fetched":"ayer","stations":[]}', 'P03', now: now), isNull);
      expect(decodeSnapshot('{"key":"P03","fetched":"2026-11-15T09:00:00","stations":"x"}', 'P03', now: now), isNull);
      expect(decodeSnapshot('x' * (SnapshotStore.maxChars + 1), 'P03', now: now), isNull);

      // Demasiadas gasolineras para ser una provincia.
      final huge = jsonEncode({
        'key': 'P03',
        'fetched': '2026-11-15T09:00:00',
        'stations': List.filled(SnapshotStore.maxStations + 1, _station('1', 1.6).toCache()),
      });
      expect(decodeSnapshot(huge, 'P03', now: now), isNull);
    });

    test('cada gasolinera guardada pasa los mismos filtros que la API', () {
      final good = _station('1', 1.6).toCache();
      List<Object?> withValue(int index, Object? value) => [...good]..[index] = value;

      expect(Station.fromCache(good), isNotNull);
      expect(Station.fromCache('texto'), isNull);
      expect(Station.fromCache(good.sublist(0, 5)), isNull);
      expect(Station.fromCache(withValue(0, '')), isNull); // sin identificador
      expect(Station.fromCache(withValue(1, 42)), isNull); // tipo falso
      expect(Station.fromCache(withValue(11, 999)), isNull); // latitud imposible
      expect(Station.fromCache(withValue(12, double.nan)), isNull);
      expect(Station.fromCache(withValue(13, 'precios')), isNull);

      // Precios imposibles o de combustibles inventados se descartan.
      final tampered = Station.fromCache(
        withValue(13, {'gasolina95': 0.01, 'diesel': 999, 'plutonio': 1.0, 'glp': '1'}),
      )!;
      expect(tampered.prices, {FuelType.gasolina95: 0.01});
      // Textos enormes se recortan.
      expect(Station.fromCache(withValue(2, 'A' * 5000))!.address.length, Station.maxTextLength);

      // En una lista, las inválidas se saltan y las válidas se conservan.
      final mixed = jsonEncode({
        'key': 'P03',
        'fetched': '2026-11-15T09:00:00',
        'stations': [good, 'basura', withValue(11, 999)],
      });
      expect(decodeSnapshot(mixed, 'P03', now: now)!.stations, hasLength(1));
    });

    test('no se guardan zonas enormes ni se reescribe lo que ya está guardado', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SnapshotStore();
      final prefs = await SharedPreferences.getInstance();

      final spain = PriceSnapshot(
        stations: List.filled(SnapshotStore.maxStations + 1, _station('1', 1.6)),
        publishedAt: null,
      );
      await store.save('ES', spain);
      expect(prefs.getString('snapshot.v1'), isNull);

      final province = _snapshot(1.6);
      await store.save('P03', province);
      final first = prefs.getString('snapshot.v1');
      expect(first, isNotNull);
      expect((await store.load('P03'))!.stations, hasLength(2));
      expect(await store.load('P46'), isNull);

      // Los mismos precios (misma publicación) no se vuelven a escribir.
      await prefs.remove('snapshot.v1');
      await store.save('P03', province);
      expect(prefs.getString('snapshot.v1'), isNull);
    });
  });

  group('arranque', () {
    test('se enseñan al instante los precios guardados y luego llegan los nuevos', () async {
      _store(snapshot: _snapshot(1.50));
      final repo = _Repo(_snapshot(1.60))..gate = Completer<void>();
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      unawaited(c.init());
      await _settle();
      // La red aún no ha contestado y ya hay lista.
      expect(_firstPrice(c), 1.50);
      expect(c.entries, hasLength(2));
      expect(c.loading, isTrue);
      expect(c.hasTrend, isFalse); // con precios guardados no se compara todavía

      repo.gate!.complete();
      await _settle();
      expect(_firstPrice(c), 1.60);
      expect(c.loading, isFalse);
      expect(c.offline, isFalse);

      // Los nuevos quedan guardados para la próxima vez.
      final prefs = await SharedPreferences.getInstance();
      final stored = decodeSnapshot(prefs.getString('snapshot.v1')!, 'P03', now: DateTime.now())!;
      expect(stored.stations.first.prices[FuelType.gasolina95], 1.60);
    });

    test('sin conexión se quedan los guardados y se avisa', () async {
      _store(snapshot: _snapshot(1.50));
      final repo = _Repo(_snapshot(1.60))..fail = true;
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      unawaited(c.init());
      await _settle();
      expect(_firstPrice(c), 1.50);
      expect(c.offline, isTrue);
      expect(c.loading, isFalse);

      // Al volver la conexión, reintentar trae los nuevos y quita el aviso.
      repo.fail = false;
      await c.refresh();
      expect(_firstPrice(c), 1.60);
      expect(c.offline, isFalse);
    });

    test('precios guardados de otra zona no se enseñan', () async {
      _store(snapshot: _snapshot(1.50), snapshotKey: 'P46');
      final repo = _Repo(_snapshot(1.60))..gate = Completer<void>();
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      unawaited(c.init());
      await _settle();
      expect(c.snapshot, isNull);
      expect(c.loading, isTrue);

      repo.gate!.complete();
      await _settle();
      expect(_firstPrice(c), 1.60);
    });

    test('cambiar a un pueblo de la misma provincia durante la descarga no pierde la respuesta', () async {
      _store(snapshot: _snapshot(1.50));
      final repo = _Repo(_snapshot(1.60))..gate = Completer<void>();
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      unawaited(c.init());
      await _settle();
      await c.setScope(const SearchScope.myTown('03', '14', 'Alicante'));
      expect(_firstPrice(c), 1.50);

      repo.gate!.complete();
      await _settle();
      expect(_firstPrice(c), 1.60);
      expect(c.loading, isFalse);
    });

    test('volver a una zona ya vista en la sesión es inmediato', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = _Repo(_snapshot(1.60));
      final c = StationsController(repo, LocationService());
      addTearDown(c.dispose);

      await c.chooseScope(_alicante);
      await c.chooseScope(const SearchScope.province('46', 'Valencia'));
      repo
        ..fresh = _snapshot(1.70)
        ..gate = Completer<void>();

      unawaited(c.chooseScope(_alicante));
      // Sin esperar a la red: se ve lo que había mientras se actualiza.
      expect(c.snapshot, isNotNull);
      expect(_firstPrice(c), 1.60);

      repo.gate!.complete();
      await _settle();
      expect(_firstPrice(c), 1.70);
    });
  });
}
