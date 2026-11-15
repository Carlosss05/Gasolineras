import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';

/// Últimos precios descargados, guardados en el dispositivo. Al abrir la app
/// se enseñan al instante (también sin conexión) mientras se piden los
/// nuevos, en vez de esperar a la red con la pantalla vacía.
///
/// Solo se guarda una zona (la última) y solo si es razonablemente pequeña:
/// una provincia son 100-300 KB; toda España no cabría.
class SnapshotStore {
  static const _key = 'snapshot.v1';

  /// Zonas más grandes no se guardan (comunidades grandes y toda España).
  static const maxStations = 2500;

  /// Tamaño máximo de lo guardado; por encima se ignora al leer.
  static const maxChars = 3 * 1024 * 1024;

  /// Precios más viejos que esto ya no se enseñan.
  static const maxAge = Duration(days: 14);

  String? _savedMark;

  /// Precios guardados de la zona [cacheKey], o `null` si no hay, son de otra
  /// zona, están caducados o dañados.
  Future<PriceSnapshot?> load(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return raw == null ? null : decodeSnapshot(raw, cacheKey, now: DateTime.now());
    } catch (_) {
      return null;
    }
  }

  /// Guarda [snapshot] como últimos precios de [cacheKey]. No hace nada si la
  /// zona es demasiado grande o si esos mismos precios ya están guardados.
  Future<void> save(String cacheKey, PriceSnapshot snapshot) async {
    if (snapshot.stations.isEmpty || snapshot.stations.length > maxStations) return;
    final mark = '$cacheKey|${snapshot.publishedAt}|${snapshot.stations.length}';
    if (mark == _savedMark) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (await prefs.setString(_key, encodeSnapshot(cacheKey, snapshot))) _savedMark = mark;
    } catch (_) {
      // Sin espacio o sin almacenamiento: la próxima vez se esperará a la red.
    }
  }
}

String encodeSnapshot(String cacheKey, PriceSnapshot snapshot) => jsonEncode({
  'key': cacheKey,
  'published': snapshot.publishedAt?.toIso8601String(),
  'fetched': snapshot.fetchedAt.toIso8601String(),
  'stations': [for (final s in snapshot.stations) s.toCache()],
});

/// Lee lo guardado con [encodeSnapshot]. Como cualquier dato del dispositivo
/// puede estar manipulado o dañado: tamaño acotado, tipos comprobados y cada
/// gasolinera validada; ante cualquier duda, `null` (se espera a la red).
PriceSnapshot? decodeSnapshot(String raw, String cacheKey, {required DateTime now}) {
  if (raw.length > SnapshotStore.maxChars) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic> || json['key'] != cacheKey) return null;
    final fetched = DateTime.tryParse(json['fetched'] is String ? json['fetched'] as String : '');
    final list = json['stations'];
    if (fetched == null || list is! List || list.length > SnapshotStore.maxStations) return null;
    // Ni caducados ni "del futuro" (reloj cambiado o dato manipulado).
    final age = now.difference(fetched);
    if (age > SnapshotStore.maxAge || age < const Duration(minutes: -5)) return null;

    final stations = list.map(Station.fromCache).whereType<Station>().toList(growable: false);
    if (stations.isEmpty) return null;
    final published = json['published'];
    return PriceSnapshot(
      stations: stations,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      fetchedAt: fetched,
    );
  } catch (_) {
    return null;
  }
}
