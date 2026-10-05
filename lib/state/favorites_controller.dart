import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';

/// Gasolineras favoritas, guardadas en el dispositivo.
///
/// Para cada favorita se guarda también su provincia, así se pueden
/// descargar sus precios actuales aunque esté fuera de la zona elegida.
class FavoritesController extends ChangeNotifier {
  static const _key = 'favorites.v1';

  final Map<String, String> _provinceById = {};

  Map<String, String> get provinceById => Map.unmodifiable(_provinceById);

  bool get isEmpty => _provinceById.isEmpty;

  bool isFavorite(String stationId) => _provinceById.containsKey(stationId);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((id, province) {
        _provinceById[id] = '$province';
      });
    } catch (_) {
      // Datos corruptos: se empieza de cero.
    }
    notifyListeners();
  }

  Future<void> toggle(Station station) async {
    if (_provinceById.remove(station.id) == null) {
      _provinceById[station.id] = station.provinceId;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_provinceById));
  }
}
