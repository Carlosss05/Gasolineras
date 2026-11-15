import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/fuel_price_repository.dart';
import 'data/minetur_repository.dart';
import 'models/car.dart';
import 'platform/web_insets.dart';
import 'services/location_service.dart';
import 'state/favorites_controller.dart';
import 'state/garage_controller.dart';
import 'state/stations_controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Si falla el pintado de una parte de la pantalla, se sustituye solo esa
  // parte por un aviso discreto en vez de dejar un bloque gris.
  ErrorWidget.builder = (details) => kDebugMode ? ErrorWidget(details.exception) : const _BrokenPart();

  // Lo primero, los datos: la zona guardada, sus últimos precios, la
  // ubicación y la petición a la red arrancan ya, mientras se preparan las
  // tipografías, en vez de esperar a que estas terminen.
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

  // Nombres de meses en español para el diario de repostajes.
  await initializeDateFormatting('es');
  // La tipografía va incluida en assets/google_fonts: nunca se descarga de
  // Google (arranque más rápido, sin parpadeo de letra y sin conexión).
  GoogleFonts.config.allowRuntimeFetching = false;
  // Se cargan los pesos que usa la app antes de pintar, para que el texto no
  // cambie de letra al aparecer. Como mucho 1,5 s: con red lenta no se espera.
  for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800]) {
    GoogleFonts.plusJakartaSans(fontWeight: w);
  }
  await GoogleFonts.pendingFonts().timeout(const Duration(milliseconds: 1500), onTimeout: () => const []);
  // Web en iPhone: zona tapada abajo por la barra de Safari (ver web/ios-viewport.js).
  initWebInsets();

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

/// Sustituto de una parte de la pantalla que no se ha podido pintar. No
/// depende del tema ni del idioma de la app, que podrían ser lo que falla.
class _BrokenPart extends StatelessWidget {
  const _BrokenPart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'No se ha podido mostrar esta parte.',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8A9A92), fontSize: 13),
        ),
      ),
    );
  }
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
      // En la web de iPhone la app se dibuja también detrás de la barra de
      // cristal de Safari; esa zona se añade como margen inferior (igual que
      // el indicador de inicio en una app nativa) para que nada quede tapado.
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: webBottomInset,
        builder: (context, inset, _) {
          final mq = MediaQuery.of(context);
          if (inset <= mq.padding.bottom) return child!;
          return MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: inset),
              viewPadding: mq.viewPadding.copyWith(bottom: inset),
            ),
            child: child!,
          );
        },
      ),
      home: const HomeScreen(),
    );
  }
}
