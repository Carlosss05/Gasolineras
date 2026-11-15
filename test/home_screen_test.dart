import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/fuel_price_repository.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/car.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/price_history.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/favorites_controller.dart';
import 'package:gasolineras/state/garage_controller.dart';
import 'package:gasolineras/state/stations_controller.dart';
import 'package:gasolineras/ui/home_screen.dart';
import 'package:gasolineras/ui/widgets/skeleton.dart';
import 'package:gasolineras/ui/widgets/station_tile.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends MineturRepository {
  _Repository(this.items);
  final List<Station> items;

  /// Para retrasar la respuesta o hacerla fallar.
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false}) async {
    await gate?.future;
    if (fail) throw FuelApiException('Sin red');
    return PriceSnapshot(stations: items, publishedAt: null);
  }

  /// Ayer: '0' estaba 2 cts más cara y '1', 1 ct más barata. Hace una semana: '0', 10 cts más cara.
  @override
  Future<PriceHistory> history(SearchScope scope, FuelType fuel, DateTime day) async {
    final weekAgo = DateTime.now().difference(day).inDays >= 3;
    return PriceHistory(day: day, prices: weekAgo ? {'0': 1.70} : {'0': 1.62, '1': 1.60});
  }
}

const _lat = 38.34, _lng = -0.48;

/// Ubicación fija en el centro de Alicante, sin GPS ni red.
class _FixedLocation extends LocationService {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Position?> current() async => Position(
    latitude: _lat,
    longitude: _lng,
    timestamp: DateTime(2026, 11, 15),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  @override
  Stream<Position> watch({int distanceFilterMeters = 100}) => const Stream.empty();

  @override
  Future<DetectedPlace?> placeAt(double latitude, double longitude) async => null;
}

Station _station(String id, double price, {double lat = _lat}) => Station(
  id: id,
  brand: 'Marca $id',
  address: 'Calle Mayor, 1',
  municipality: 'Alicante',
  province: 'Alicante',
  provinceId: '03',
  communityId: '10',
  postalCode: '03001',
  schedule: '',
  latitude: lat,
  longitude: _lng,
  prices: {FuelType.gasolina95: price},
);

/// Una cara a la puerta, una intermedia a ~3 km y la más barata a ~67 km.
List<Station> _spread() => [
  _station('cerca', 1.70),
  _station('media', 1.62, lat: _lat + 0.03),
  _station('lejos', 1.55, lat: _lat + 0.6),
];

Future<(StationsController, _Repository)> _pumpHome(
  WidgetTester tester, {
  SearchScope? scope,
  List<Station>? items,
  bool located = false,
  bool settle = true,
  Completer<void>? gate,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repo = _Repository(items ?? [for (var i = 0; i < 30; i++) _station('$i', 1.6 + i / 100)])..gate = gate;
  final stations = StationsController(repo, located ? _FixedLocation() : LocationService());
  final favorites = FavoritesController();
  final garage = GarageController();
  addTearDown(stations.dispose);
  addTearDown(favorites.dispose);
  addTearDown(garage.dispose);
  await garage.load();
  if (located) await stations.retryLocation();
  if (scope != null) {
    final loading = stations.chooseScope(scope);
    if (gate == null) await loading;
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<FuelPriceRepository>.value(value: repo),
        ChangeNotifierProvider<FavoritesController>.value(value: favorites),
        ChangeNotifierProvider<StationsController>.value(value: stations),
        ChangeNotifierProvider<GarageController>.value(value: garage),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return (stations, repo);
}

const _alicante = SearchScope.province('03', 'Alicante');

/// Opacidad de la barra mínima (siempre construida, oculta arriba).
double _barOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: find.text('Gasolina 95 · Más baratas'), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

void main() {
  testWidgets('cabecera compacta: zona en el buscador y barra mínima al bajar', (tester) async {
    await _pumpHome(tester, scope: _alicante);

    expect(find.text('Gasolineras'), findsOneWidget);
    expect(find.text('Pueblo, marca o CP'), findsOneWidget);
    // Sin ubicación se destaca la más barata y se ofrece calcular el viaje.
    expect(find.text('LA MÁS BARATA'), findsOneWidget);
    expect(find.text('¿Me compensa ir?'), findsOneWidget);
    expect(find.text('30 gasolineras'), findsOneWidget);
    expect(_barOpacity(tester), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(_barOpacity(tester), 1);
    expect(find.byType(StationTile), findsWidgets);

    // Tocar el logo de la barra mínima vuelve arriba.
    await tester.tap(find.byTooltip('Volver arriba'));
    await tester.pumpAndSettle();
    expect(_barOpacity(tester), 0);

    // El orden se cambia junto al número de resultados.
    await tester.tap(find.text('Cerca'));
    await tester.pumpAndSettle();
    expect(find.text('Gasolina 95 · Más cercanas'), findsOneWidget);
  });

  testWidgets('el mapa va bajo la cabecera y los combustibles flotan encima', (tester) async {
    await _pumpHome(tester, scope: _alicante);

    await tester.tap(find.byTooltip('Ver mapa').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Ver lista'), findsOneWidget);
    expect(find.text('Gasolina 95'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Ver lista'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('30 gasolineras'), findsOneWidget);
  });

  testWidgets('muestra cuánto ha cambiado la media y cada gasolinera', (tester) async {
    await _pumpHome(tester, scope: _alicante);

    expect(find.text('Media desde ayer'), findsOneWidget);
    expect(find.text('Media en 7 días'), findsOneWidget);
    // Media de '0' (−2 cts) y '1' (+1 ct).
    expect(find.text('0,5 cts'), findsOneWidget);
    expect(
      find.text('De 2 gasolineras, 1 han bajado y 1 han subido. Cada una muestra su cambio bajo el precio.'),
      findsOne,
    );
    // '0' es la más barata: su bajada sale en la tarjeta destacada y en su fila.
    expect(find.text('2,0 cts'), findsNWidgets(2));
    expect(find.text('1,0 cts'), findsOneWidget);

    await tester.tap(find.text('Media en 7 días'));
    await tester.pumpAndSettle();
    expect(find.text('10,0 cts'), findsNWidgets(3));
    expect(find.text('1,0 cts'), findsNothing);
  });

  testWidgets('sin zona, el aviso va dentro de la lista bajo la cabecera', (tester) async {
    await _pumpHome(tester);

    expect(find.text('No sabemos dónde estás'), findsOneWidget);
    expect(find.text('Elegir zona'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('¿Dónde reposto?', () {
    testWidgets('con ubicación recomienda la de menor coste total, no la más barata', (tester) async {
      final (c, _) = await _pumpHome(tester, scope: _alicante, items: _spread(), located: true);

      // La intermedia gana: la barata está a 67 km y la cercana es cara.
      expect(c.recommendation!.best.entry.station.id, 'media');
      expect(find.text('TU MEJOR OPCIÓN'), findsOneWidget);
      expect(find.text('LA MÁS BARATA'), findsNothing);
      expect(find.textContaining('Repostar 40 L aquí te sale por'), findsOneWidget);
      expect(find.textContaining('menos que en la más cercana.'), findsOneWidget);

      // Sin coche configurado se calcula con valores típicos y se ofrece ajustarlos.
      await tester.tap(find.text('Ajustar a mi coche'));
      await tester.pumpAndSettle();
      expect(find.text('¿Dónde reposto?'), findsOneWidget);
      expect(find.text('Litros que vas a repostar'), findsOneWidget);
      expect(find.text('40 L'), findsOneWidget);
      expect(find.text('6,5 L/100 km'), findsOneWidget);
      expect(find.text('Mejor opción'), findsOneWidget);
      expect(find.text('Más cercana'), findsOneWidget);
      expect(find.text('Más barata'), findsOneWidget);
      expect(find.text('1. Marca media'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Con pocos litros el viaje pesa más: pasa a compensar la de la puerta.
      c.setPlan(liters: 5);
      await tester.pumpAndSettle();
      expect(c.recommendation!.best.entry.station.id, 'cerca');
      expect(find.text('5 L'), findsOneWidget);
      expect(find.text('1. Marca cerca'), findsOneWidget);
      expect(find.textContaining('Además es la más cercana.'), findsOneWidget);

      // Solo ida: la mitad de viaje.
      final roundTrip = c.recommendation!.ranking.last.tripCost;
      await tester.tap(find.text('Solo ida'));
      await tester.pumpAndSettle();
      expect(c.plan.roundTrip, isFalse);
      expect(c.recommendation!.ranking.last.tripCost, closeTo(roundTrip / 2, 1e-9));
    });

    testWidgets('sin ubicación la hoja explica que hace falta y ofrece activarla', (tester) async {
      await _pumpHome(tester, scope: _alicante);

      await tester.tap(find.text('¿Me compensa ir?'));
      await tester.pumpAndSettle();
      expect(find.text('¿Dónde reposto?'), findsOneWidget);
      expect(find.text('Necesito saber dónde estás'), findsOneWidget);
      expect(find.text('Usar mi ubicación'), findsOneWidget);
      expect(find.text('Litros que vas a repostar'), findsNothing);
    });

    testWidgets('ordenando por "Rentables" cada gasolinera enseña su coste con el viaje', (tester) async {
      final (c, _) = await _pumpHome(tester, scope: _alicante, items: _spread(), located: true);
      expect(find.textContaining('con viaje'), findsNothing);

      c
        ..setCar(const CarProfile(fuel: FuelType.gasolina95, tankLiters: 50, consumption: 6))
        ..setSort(SortMode.value);
      await tester.pumpAndSettle();

      expect(tester.widgetList<StationTile>(find.byType(StationTile)).first.station.id, 'media');
      // 50 L a 1,70 €/L en la de la puerta, sin viaje.
      expect(find.text('85,00 € con viaje'), findsOneWidget);
      // Con el coche configurado el cálculo ya no es "típico".
      expect(find.text('Ver el cálculo'), findsOneWidget);
    });
  });

  testWidgets('la primera descarga enseña siluetas de la lista, no una pantalla vacía', (tester) async {
    final gate = Completer<void>();
    await _pumpHome(tester, scope: _alicante, gate: gate, settle: false);
    await tester.pump();

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.text('Buscando los mejores precios…'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonList), findsNothing);
    expect(find.text('30 gasolineras'), findsOneWidget);
  });

  testWidgets('si no se pueden actualizar los precios, se avisa y se puede reintentar', (tester) async {
    final (c, repo) = await _pumpHome(tester, scope: _alicante);
    expect(find.textContaining('Sin conexión'), findsNothing);

    repo.fail = true;
    await c.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión: estos son los últimos precios guardados.'), findsOneWidget);
    expect(find.text('30 gasolineras'), findsOneWidget); // la lista sigue ahí

    repo.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin conexión'), findsNothing);
  });
}
