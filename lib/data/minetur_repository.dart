import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/region.dart';
import '../models/station.dart';
import '../utils/text.dart';
import 'fuel_price_repository.dart';

/// Precios oficiales del Ministerio para la Transición Ecológica (Geoportal
/// de gasolineras). Pública, gratuita y sin clave; se actualiza cada ~30 min.
class MineturRepository implements FuelPriceRepository {
  MineturRepository({http.Client? client, this.cacheTtl = const Duration(minutes: 5)})
    : _client = client ?? http.Client();

  static const _base = 'https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes';

  final http.Client _client;
  final Duration cacheTtl;

  final _cache = <String, PriceSnapshot>{};
  final _inFlight = <String, Future<PriceSnapshot>>{};
  Future<List<Province>>? _provinces;
  Future<List<Community>>? _communities;
  Future<List<Municipality>>? _municipalities;

  @override
  Future<List<Municipality>> municipalities() => _municipalities ??=
      // ~1 MB de JSON: se descarga solo la primera vez que se busca algo.
      _get('$_base/Listados/Municipios/').then((bytes) => compute(parseMunicipalities, bytes)).catchError((
        Object e,
      ) {
        _municipalities = null;
        throw e;
      });

  @override
  Future<List<Province>> provinces() => _provinces ??= _getJson('$_base/Listados/Provincias/')
      .then((json) {
        final list =
            (json as List)
                .cast<Map<String, dynamic>>()
                .map(
                  (p) => Province(
                    // Sí, la API lo escribe "IDPovincia".
                    id: '${p['IDPovincia']}',
                    name: prettyName('${p['Provincia']}'),
                    communityId: '${p['IDCCAA']}',
                  ),
                )
                .toList()
              ..sort((a, b) => normalize(a.name).compareTo(normalize(b.name)));
        return list;
      })
      .catchError((Object e) {
        _provinces = null;
        throw e;
      });

  @override
  Future<List<Community>> communities() => _communities ??= _getJson('$_base/Listados/ComunidadesAutonomas/')
      .then((json) {
        return (json as List)
            .cast<Map<String, dynamic>>()
            .map((c) => Community(id: '${c['IDCCAA']}', name: '${c['CCAA']}'))
            .toList();
      })
      .catchError((Object e) {
        _communities = null;
        throw e;
      });

  @override
  Future<PriceSnapshot> stations(SearchScope scope, {bool forceRefresh = false}) {
    final key = scope.cacheKey;
    final cached = _cache[key];
    if (!forceRefresh && cached != null && DateTime.now().difference(cached.fetchedAt) < cacheTtl) {
      return Future.value(cached);
    }
    return _inFlight[key] ??= _fetchStations(scope)
        .then((snapshot) {
          _cache[key] = snapshot;
          return snapshot;
        })
        .whenComplete(() {
          // Con llaves a propósito: si el callback devolviera el Future eliminado,
          // whenComplete esperaría a ese mismo Future y nunca terminaría.
          _inFlight.remove(key);
        });
  }

  Future<PriceSnapshot> _fetchStations(SearchScope scope) async {
    final filter = switch (scope.kind) {
      ScopeKind.spain => '',
      ScopeKind.community => 'FiltroCCAA/${scope.id}',
      ScopeKind.myTown || ScopeKind.myProvince || ScopeKind.province => 'FiltroProvincia/${scope.id}',
    };
    final bytes = await _get('$_base/EstacionesTerrestres/$filter');
    // Toda España son ~12 MB de JSON: se procesa fuera del hilo de la UI.
    return compute(parseSnapshot, bytes);
  }

  Future<Object?> _getJson(String url) async => jsonDecode(utf8.decode(await _get(url)));

  Future<Uint8List> _get(String url) async {
    final http.Response res;
    try {
      res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 90));
    } catch (_) {
      throw FuelApiException('No se ha podido conectar con el servicio de precios.');
    }
    if (res.statusCode != 200) {
      throw FuelApiException('El servicio de precios respondió con error ${res.statusCode}.');
    }
    return res.bodyBytes;
  }
}

/// Convierte la respuesta de `EstacionesTerrestres` en un [PriceSnapshot].
PriceSnapshot parseSnapshot(Uint8List bytes) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final raw = (json['ListaEESSPrecio'] as List? ?? const []).cast<Map<String, dynamic>>();
  return PriceSnapshot(
    stations: raw.map(Station.fromApi).whereType<Station>().toList(growable: false),
    publishedAt: _parseDate(json['Fecha'] as String?),
  );
}

List<Municipality> parseMunicipalities(Uint8List bytes) {
  final raw = (jsonDecode(utf8.decode(bytes)) as List).cast<Map<String, dynamic>>();
  return [
    for (final m in raw)
      Municipality(
        id: '${m['IDMunicipio']}',
        name: '${m['Municipio']}',
        provinceId: '${m['IDProvincia']}',
        provinceName: prettyName('${m['Provincia']}'),
        communityId: '${m['IDCCAA']}',
      ),
  ];
}

/// "05/10/2026 15:19:22" -> DateTime (hora peninsular).
DateTime? _parseDate(String? s) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2}):(\d{2})$').firstMatch(s ?? '');
  if (m == null) return null;
  int g(int i) => int.parse(m[i]!);
  return DateTime(g(3), g(2), g(1), g(4), g(5), g(6));
}
