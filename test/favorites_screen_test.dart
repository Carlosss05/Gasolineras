import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/fuel_price_repository.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/car.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/favorites_controller.dart';
import 'package:gasolineras/state/stations_controller.dart';
import 'package:gasolineras/ui/favorites_screen.dart';
import 'package:gasolineras/ui/widgets/station_tile.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends MineturRepository {
  _Repository(this.items);
  final List<Station> items;

  @override
  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false}) async =>
      PriceSnapshot(stations: items, publishedAt: null);
}

class _LocatedController extends StationsController {
  _LocatedController(FuelPriceRepository repo, LocationService location) : super(repo, location);

  @override
  Position get position => Position(
    latitude: 38.6447,
    longitude: 0.0445,
    timestamp: DateTime(2026, 10, 5),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}

Station _station(String id, double price, double lat) => Station(
  id: id,
  brand: id,
  address: '',
  municipality: 'Calpe',
  province: 'Alicante',
  provinceId: '03',
  communityId: '10',
  postalCode: '03710',
  schedule: '',
  latitude: lat,
  longitude: 0.0445,
  prices: {FuelType.gasolina95: price},
);

void main() {
  testWidgets('favoritas ordena Rentables incluyendo el coste del viaje', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final items = [_station('lejos', 1.60, 38.9500), _station('cerca', 1.62, 38.6447)];
    final repo = _Repository(items);
    final favorites = FavoritesController();
    final controller = _LocatedController(repo, LocationService())
      ..setCar(const CarProfile(fuel: FuelType.gasolina95, tankLiters: 50, consumption: 6))
      ..setSort(SortMode.value);
    addTearDown(favorites.dispose);
    addTearDown(controller.dispose);
    for (final s in items) {
      await favorites.toggle(s);
    }
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<FuelPriceRepository>.value(value: repo),
        ChangeNotifierProvider<FavoritesController>.value(value: favorites),
        ChangeNotifierProvider<StationsController>.value(value: controller),
      ],
      child: const MaterialApp(home: FavoritesScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.widgetList<StationTile>(find.byType(StationTile)).first.station.id, 'cerca');
    controller.setSort(SortMode.price);
    await tester.pumpAndSettle();
    expect(tester.widgetList<StationTile>(find.byType(StationTile)).first.station.id, 'lejos');
  });
}
