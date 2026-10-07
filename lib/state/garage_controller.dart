import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/savings.dart';
import '../models/car.dart';

/// Coche del usuario y diario de repostajes, guardados en el dispositivo.
class GarageController extends ChangeNotifier {
  static const _carKey = 'car.v1';
  static const _logKey = 'refuels.v1';

  CarProfile? _car;
  List<RefuelEntry> _refuels = const [];
  bool loaded = false;

  CarProfile? get car => _car;

  /// Repostajes, del más reciente al más antiguo.
  List<RefuelEntry> get refuels => _refuels;

  RefuelStats get stats => computeStats(_refuels, now: DateTime.now());

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carRaw = prefs.getString(_carKey);
      if (carRaw != null) _car = CarProfile.fromJson(jsonDecode(carRaw) as Map<String, dynamic>);
      final logRaw = prefs.getString(_logKey);
      if (logRaw != null) {
        _refuels =
            (jsonDecode(logRaw) as List)
                .map((j) => RefuelEntry.fromJson(j as Map<String, dynamic>))
                .whereType<RefuelEntry>()
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (_) {
      // Datos corruptos: se empieza de cero.
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> setCar(CarProfile car) async {
    _car = car;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_carKey, jsonEncode(car.toJson()));
  }

  Future<void> addRefuel(RefuelEntry entry) async {
    _refuels = [entry, ..._refuels]..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveLog();
  }

  /// Sustituye un repostaje ya anotado (mismo `id`) por su versión editada.
  Future<void> updateRefuel(RefuelEntry entry) async {
    _refuels = [for (final e in _refuels) e.id == entry.id ? entry : e]
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveLog();
  }

  Future<void> removeRefuel(String id) async {
    _refuels = _refuels.where((e) => e.id != id).toList();
    notifyListeners();
    await _saveLog();
  }

  Future<void> _saveLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logKey, jsonEncode([for (final e in _refuels) e.toJson()]));
  }
}
