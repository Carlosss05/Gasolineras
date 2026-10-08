import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/car.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/garage_controller.dart';
import 'package:gasolineras/state/stations_controller.dart';
import 'package:gasolineras/ui/garage_forms.dart';
import 'package:provider/provider.dart';

class _PendingGarage extends GarageController {
  final result = Completer<void>();
  int calls = 0;

  @override
  Future<void> addRefuel(RefuelEntry entry) {
    calls++;
    return result.future;
  }
}

void main() {
  for (final fails in [false, true]) {
    testWidgets('guardar espera al almacenamiento; fallo: $fails', (tester) async {
      final garage = _PendingGarage();
      final stations = StationsController(MineturRepository(), LocationService());
      addTearDown(garage.dispose);
      addTearDown(stations.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<GarageController>.value(value: garage),
          ChangeNotifierProvider<StationsController>.value(value: stations),
        ],
        child: MaterialApp(home: Scaffold(body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRefuelForm(context),
            child: const Text('Abrir'),
          ),
        ))),
      ));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Importe'), '48');
      await tester.enterText(find.widgetWithText(TextField, 'Litros'), '30');
      final save = find.widgetWithText(FilledButton, 'Guardar repostaje');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(garage.calls, 1);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text('Repostaje anotado en tu diario'), findsNothing);
      if (fails) {
        garage.result.completeError(StateError('Almacenamiento no disponible'));
      } else {
        garage.result.complete();
      }
      await tester.pumpAndSettle();
      if (fails) {
        expect(find.text('No se ha podido guardar el repostaje. Inténtalo de nuevo.'), findsOneWidget);
        expect(find.text('Guardar repostaje'), findsOneWidget);
      } else {
        expect(find.text('Repostaje anotado en tu diario'), findsOneWidget);
        expect(find.text('Guardar repostaje'), findsNothing);
      }
    });
  }
}
