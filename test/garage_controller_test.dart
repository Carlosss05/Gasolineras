import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/models/car.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/state/garage_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entry = RefuelEntry(
    id: 'test',
    date: DateTime(2026, 10, 5),
    fuel: FuelType.gasolina95,
    liters: 30,
    totalEuros: 48,
  );

  test('recupera el diario aunque el JSON del coche esté corrupto', () async {
    SharedPreferences.setMockInitialValues({
      'car.v1': '{invalido',
      'refuels.v1': jsonEncode([entry.toJson()]),
    });
    final garage = GarageController();
    addTearDown(garage.dispose);
    await garage.load();
    expect(garage.loaded, isTrue);
    expect(garage.car, isNull);
    expect(garage.refuels.single.id, entry.id);
  });

  test('una entrada malformada no impide recuperar las válidas', () async {
    SharedPreferences.setMockInitialValues({
      'refuels.v1': jsonEncode([null, entry.toJson(), 'invalido']),
    });
    final garage = GarageController();
    addTearDown(garage.dispose);
    await garage.load();
    expect(garage.refuels.single.id, entry.id);
  });

  test('el diario se conserva tras guardar, editar y volver a cargar', () async {
    SharedPreferences.setMockInitialValues({});
    final garage = GarageController();
    addTearDown(garage.dispose);
    await garage.addRefuel(entry);
    final edited = RefuelEntry(
      id: entry.id,
      date: entry.date,
      fuel: entry.fuel,
      liters: 40,
      totalEuros: 64,
    );
    await garage.updateRefuel(edited);
    final restored = GarageController();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.refuels.single.liters, 40);
    await garage.removeRefuel(entry.id);
    await restored.load();
    expect(restored.refuels, isEmpty);
  });
}
