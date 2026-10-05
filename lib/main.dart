import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/fuel_price_repository.dart';
import 'data/minetur_repository.dart';
import 'services/location_service.dart';
import 'state/favorites_controller.dart';
import 'state/stations_controller.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final FuelPriceRepository repository = MineturRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider<FuelPriceRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => FavoritesController()..load()),
        ChangeNotifierProvider(create: (_) => StationsController(repository, LocationService())..init()),
      ],
      child: const GasolinerasApp(),
    ),
  );
}

class GasolinerasApp extends StatelessWidget {
  const GasolinerasApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B8A3A);
    return MaterialApp(
      title: 'Gasolineras baratas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
