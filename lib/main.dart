import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/fuel_price_repository.dart';
import 'data/minetur_repository.dart';
import 'models/car.dart';
import 'services/location_service.dart';
import 'state/favorites_controller.dart';
import 'state/garage_controller.dart';
import 'state/stations_controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nombres de meses en español para el diario de repostajes.
  await initializeDateFormatting('es');
  final FuelPriceRepository repository = MineturRepository();
  final stations = StationsController(repository, LocationService());
  final garage = GarageController();

  // Cuando se guarda o cambia el coche, la lista pasa a su combustible.
  CarProfile? lastCar;
  garage.addListener(() {
    if (!identical(garage.car, lastCar)) {
      lastCar = garage.car;
      stations.setCar(garage.car);
    }
  });
  garage.load();
  stations.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<FuelPriceRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => FavoritesController()..load()),
        ChangeNotifierProvider.value(value: stations),
        ChangeNotifierProvider.value(value: garage),
      ],
      child: const GasolinerasApp(),
    ),
  );
}

class GasolinerasApp extends StatelessWidget {
  const GasolinerasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gasolineras baratas',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
