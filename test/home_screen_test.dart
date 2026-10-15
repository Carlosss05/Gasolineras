import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/fuel_price_repository.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/price_history.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/favorites_controller.dart';
import 'package:gasolineras/state/garage_controller.dart';
import 'package:gasolineras/state/stations_controller.dart';
import 'package:gasolineras/ui/home_screen.dart';
import 'package:gasolineras/ui/widgets/station_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends MineturRepository {
  _Repository(this.items);
  final List<Station> items;

  @override
  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false}) async =>
      PriceSnapshot(stations: items, publishedAt: null);

  /// Ayer: '0' estaba 2 cts más cara y '1', 1 ct más barata. Hace una semana: '0', 10 cts más cara.
  @override
  Future<PriceHistory> history(SearchScope scope, FuelType fuel, DateTime day) async {
    final weekAgo = DateTime.now().difference(day).inDays >= 3;
    return PriceHistory(day: day, prices: weekAgo ? {'0': 1.70} : {'0': 1.62, '1': 1.60});
  }
}

Station _station(String id, double price) => Station(
  id: id,
  brand: 'Marca $id',
  address: 'Calle Mayor, 1',
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

Future<StationsController> _pumpHome(WidgetTester tester, {SearchScope? scope}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(402, 874));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repo = _Repository([for (var i = 0; i < 30; i++) _station('$i', 1.6 + i / 100)]);
  final stations = StationsController(repo, LocationService());
  final favorites = FavoritesController();
  final garage = GarageController();
  addTearDown(stations.dispose);
  addTearDown(favorites.dispose);
  addTearDown(garage.dispose);
  await garage.load();
  if (scope != null) await stations.chooseScope(scope);

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
  await tester.pumpAndSettle();
  return stations;
}

/// Opacidad de la barra mínima (siempre construida, oculta arriba).
double _barOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: find.text('Gasolina 95 · Más baratas'), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

void main() {
  testWidgets('cabecera compacta: zona en el buscador y barra mínima al bajar', (tester) async {
    await _pumpHome(tester, scope: const SearchScope.province('03', 'Alicante'));

    expect(find.text('Gasolineras'), findsOneWidget);
    expect(find.text('Pueblo, marca o CP'), findsOneWidget);
    expect(find.text('LA MÁS BARATA'), findsOneWidget);
    expect(find.text('30 gasolineras'), findsOneWidget);
    expect(find.text('Configura tu coche y te decimos si compensa el viaje'), findsOneWidget);
    expect(_barOpacity(tester), 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(_barOpacity(tester), 1);
    expect(find.byType(StationTile), findsWidgets);

    // El orden se cambia junto al número de resultados.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(_barOpacity(tester), 0);
    await tester.tap(find.text('Cerca'));
    await tester.pumpAndSettle();
    expect(find.text('Gasolina 95 · Más cercanas'), findsOneWidget);
  });

  testWidgets('el mapa va bajo la cabecera y los combustibles flotan encima', (tester) async {
    await _pumpHome(tester, scope: const SearchScope.province('03', 'Alicante'));

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
    await _pumpHome(tester, scope: const SearchScope.province('03', 'Alicante'));

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
}
