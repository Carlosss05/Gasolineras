import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fuel_price_repository.dart';
import '../logic/savings.dart';
import '../models/car.dart';
import '../models/fuel_type.dart';
import '../models/region.dart';
import '../models/station.dart';
import '../services/location_service.dart';
import '../utils/text.dart';

/// [value]: coste real de llenar el depósito (combustible + viaje de ida y
/// vuelta); necesita el coche y la ubicación.
enum SortMode { price, distance, value }

class StationEntry {
  const StationEntry(this.station, this.price, this.distanceKm);

  final Station station;
  final double price;
  final double? distanceKm;
}

/// Filtra las estaciones que venden [fuel], calcula la distancia a
/// [position] y ordena según [sort]. En caso de empate usa el otro criterio.
List<StationEntry> buildEntries(
  Iterable<Station> stations, {
  required FuelType fuel,
  required SortMode sort,
  ({double lat, double lng})? position,
  String query = '',
  String? municipalityId,
  CarProfile? car,
}) {
  final q = normalize(query.trim());
  final list = <StationEntry>[];
  for (final s in stations) {
    final price = s.prices[fuel];
    if (price == null) continue;
    if (municipalityId != null && s.municipalityId != municipalityId) continue;
    if (q.isNotEmpty && !s.searchText.contains(q)) continue;
    final d = position == null
        ? null
        : LocationService.distanceKm(position.lat, position.lng, s.latitude, s.longitude);
    list.add(StationEntry(s, price, d));
  }

  int byPrice(StationEntry a, StationEntry b) => a.price.compareTo(b.price);
  int byDistance(StationEntry a, StationEntry b) =>
      (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);

  final (first, second) = switch (sort) {
    SortMode.distance when position != null => (byDistance, byPrice),
    SortMode.value when position != null && car != null => (
      (StationEntry a, StationEntry b) => effectiveCost(a, car).compareTo(effectiveCost(b, car)),
      byPrice,
    ),
    _ => (byPrice, byDistance),
  };
  list.sort((a, b) {
    final c = first(a, b);
    return c != 0 ? c : second(a, b);
  });
  return list;
}

final _parenthesis = RegExp(r'\(.*?\)');
final _leadingArticle = RegExp(r"^(l'|(el|la|los|las|els|les|es|sa|o|a)\s+)");

/// Formas comparables de un nombre de municipio: "Elche/Elx" -> {elche, elx};
/// "Alfàs del Pi (l')" y "l'Alfàs del Pi" -> {alfas del pi}.
Set<String> _townForms(String name) => {
  for (final part in normalize(name).replaceAll(_parenthesis, '').split('/'))
    if (part.trim().replaceFirst(_leadingArticle, '').trim() case final f when f.isNotEmpty) f,
};

/// Municipio (código y nombre) de [stations] que corresponde a [townNames].
///
/// Si ningún nombre coincide (pedanía, urbanización…), se usa el de la
/// gasolinera más cercana siempre que esté a menos de [maxFallbackKm].
({String id, String name})? resolveTown(
  List<Station> stations,
  List<String> townNames, {
  required double lat,
  required double lng,
  double maxFallbackKm = 5,
}) {
  final wanted = townNames.expand(_townForms).toSet();
  Station? nearest;
  var nearestKm = double.infinity;
  for (final s in stations) {
    if (s.municipalityId.isEmpty) continue;
    if (_townForms(s.municipality).any(wanted.contains)) {
      return (id: s.municipalityId, name: s.municipality.split('/').first.trim());
    }
    final d = LocationService.distanceKm(lat, lng, s.latitude, s.longitude);
    if (d < nearestKm) {
      nearestKm = d;
      nearest = s;
    }
  }
  if (nearest == null || nearestKm > maxFallbackKm) return null;
  return (id: nearest.municipalityId, name: nearest.municipality.split('/').first.trim());
}

/// Lugar fuera de la zona actual que coincide con lo que se busca.
class PlaceSuggestion {
  const PlaceSuggestion(this.title, this.subtitle, this.scope);

  final String title;
  final String subtitle;
  final SearchScope scope;
}

/// Pueblos o códigos postales que coinciden con [query] pero quedan fuera de
/// [current], para ofrecer cambiar de zona. Los que están dentro ya aparecen
/// en la lista normal.
List<PlaceSuggestion> findPlaces(
  String query, {
  required SearchScope? current,
  required List<Municipality> municipalities,
  required List<Province> provinces,
  int limit = 6,
}) {
  final q = normalize(query.trim());
  bool outside(String provinceId, String communityId, [String? townId]) => switch (current?.kind) {
    null => true,
    ScopeKind.spain => false,
    ScopeKind.community => current!.id != communityId,
    ScopeKind.province || ScopeKind.myProvince => current!.id != provinceId,
    // En "mi pueblo" cualquier otro municipio (o un CP) está fuera.
    ScopeKind.myTown => townId == null || current!.townId != townId,
  };

  if (RegExp(r'^\d{5}$').hasMatch(q)) {
    final id = provinceFromPostalCode(q);
    final province = provinces.where((p) => p.id == id).firstOrNull;
    if (province == null || !outside(province.id, province.communityId)) return const [];
    return [
      PlaceSuggestion('Código postal $q', province.name, SearchScope.province(province.id, province.name)),
    ];
  }
  if (q.length < 3 || RegExp(r'^\d+$').hasMatch(q)) return const [];

  final startsWith = <Municipality>[];
  final contains = <Municipality>[];
  for (final m in municipalities) {
    if (!outside(m.provinceId, m.communityId, m.id)) continue;
    // Nombres bilingües: "Calpe/Calp" debe encontrarse por cualquiera de los dos.
    final names = normalize(m.name).split('/').map((n) => n.trim());
    if (names.any((n) => n.startsWith(q))) {
      startsWith.add(m);
    } else if (names.any((n) => n.contains(q))) {
      contains.add(m);
    }
  }
  // "madrid" -> Madrid antes que Madridejos.
  startsWith.sort((a, b) => a.name.length.compareTo(b.name.length));
  return [
    for (final m in [...startsWith, ...contains].take(limit))
      PlaceSuggestion(m.name, m.provinceName, SearchScope.province(m.provinceId, m.provinceName)),
  ];
}

class StationsController extends ChangeNotifier {
  StationsController(this._repo, this._location);

  static const _autoRefreshEvery = Duration(minutes: 10);

  /// Distancia que hay que recorrer antes de volver a comprobar pueblo y provincia.
  static const _provinceRecheckMeters = 1500.0;

  final FuelPriceRepository _repo;
  final LocationService _location;

  SearchScope? _scope;
  FuelType _fuel = FuelType.gasolina95;
  SortMode _sort = SortMode.price;
  String _query = '';
  CarProfile? _car;

  Position? _position;
  Position? _lastProvinceCheck;
  bool _checkingProvince = false;
  bool locating = false;
  bool locationEnabled = false;
  String? myProvinceId;
  String? myProvinceName;
  String? myTownId;
  String? myTownName;
  bool _provinceChosenByUser = false;

  PriceSnapshot? _snapshot;
  bool loading = false;
  Object? error;

  List<Province> provinces = const [];
  List<Community> communities = const [];

  List<StationEntry>? _entries;
  List<Municipality> _municipalities = const [];
  bool _municipalitiesRequested = false;
  List<PlaceSuggestion>? _places;
  StreamSubscription<Position>? _positionSub;
  Timer? _refreshTimer;
  bool _disposed = false;

  SearchScope? get scope => _scope;
  FuelType get fuel => _fuel;
  SortMode get sort => _sort;
  String get query => _query;
  Position? get position => _position;
  PriceSnapshot? get snapshot => _snapshot;

  List<StationEntry> get entries => _entries ??= _snapshot == null
      ? const []
      : buildEntries(
          _snapshot!.stations,
          fuel: _fuel,
          sort: _sort,
          position: _position == null ? null : (lat: _position!.latitude, lng: _position!.longitude),
          query: _query,
          municipalityId: _scope?.kind == ScopeKind.myTown ? _scope!.townId : null,
          car: _car,
        );

  Future<void> init() async {
    _refreshTimer = Timer.periodic(_autoRefreshEvery, (_) => refresh(silent: true));
    unawaited(_loadRegions());

    // La última zona usada se muestra al instante, sin esperar al GPS; si
    // era "mi provincia", la ubicación la corrige después si has cambiado.
    final saved = await _restoreScope();
    if (saved != null && _scope == null) unawaited(setScope(saved));

    await _startLocation();
  }

  Future<void> retryLocation() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _lastProvinceCheck = null;
    await _startLocation();
  }

  Future<void> _startLocation() async {
    locating = true;
    _notify();
    try {
      locationEnabled = await _location.ensurePermission();
      if (locationEnabled) {
        _positionSub = _location.watch().listen(_onPosition, onError: (_) {});
        final first = await _location.current();
        if (first != null) await _onPosition(first);
      }
    } finally {
      locating = false;
      _notify();
    }
  }

  static const _scopeKey = 'scope.v1';

  Future<SearchScope?> _restoreScope() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopeKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final id = j['id'] as String, name = j['name'] as String;
      return switch (ScopeKind.values.byName(j['kind'] as String)) {
        ScopeKind.myTown when j['townId'] is String => SearchScope.myTown(id, j['townId'] as String, name),
        // Formato antiguo sin municipio: se queda en la provincia.
        ScopeKind.myTown => SearchScope.myProvince(id, name),
        ScopeKind.myProvince => SearchScope.myProvince(id, name),
        ScopeKind.province => SearchScope.province(id, name),
        ScopeKind.community => SearchScope.community(id, name),
        ScopeKind.spain => const SearchScope.spain(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveScope(SearchScope s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _scopeKey,
        jsonEncode({'kind': s.kind.name, 'id': s.id, 'name': s.name, 'townId': ?s.townId}),
      );
    } catch (_) {
      // No es grave: la próxima vez se pedirá la zona otra vez.
    }
  }

  void setFuel(FuelType fuel) {
    if (fuel == _fuel) return;
    _fuel = fuel;
    _invalidate();
  }

  CarProfile? get car => _car;

  /// Coche del usuario: fija su combustible y permite ordenar por coste real.
  void setCar(CarProfile? car, {bool applyFuel = true}) {
    _car = car;
    if (car != null && applyFuel) _fuel = car.fuel;
    if (car == null && _sort == SortMode.value) _sort = SortMode.price;
    _invalidate();
  }

  void setSort(SortMode sort) {
    if (sort == _sort) return;
    _sort = sort;
    _invalidate();
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    _invalidate();
  }

  Future<void> setScope(SearchScope scope) async {
    final sameData = _scope?.cacheKey == scope.cacheKey && _snapshot != null;
    _scope = scope;
    unawaited(_saveScope(scope));
    if (sameData) {
      // Mismos datos (misma provincia, quizá otro municipio): no hace falta
      // volver a descargar ni vaciar la lista, solo volver a filtrar.
      _invalidate();
      return;
    }
    _snapshot = null;
    _invalidate();
    await _load();
  }

  Future<void> useMyProvince() async {
    if (myProvinceId == null) return;
    await setScope(SearchScope.myProvince(myProvinceId!, myProvinceName ?? myProvinceId!));
  }

  /// Zona elegida a mano en el selector. Solo entonces "Mi provincia" se
  /// respeta al moverse; la guardada de otras sesiones pasa a "Mi pueblo".
  Future<void> chooseScope(SearchScope scope) {
    _provinceChosenByUser = scope.kind == ScopeKind.myProvince;
    return setScope(scope);
  }

  Future<void> useMyTown() async {
    if (myProvinceId == null || myTownId == null) return;
    await setScope(SearchScope.myTown(myProvinceId!, myTownId!, myTownName ?? myTownId!));
  }

  Future<void> refresh({bool silent = false}) => _load(force: true, silent: silent);

  Future<void> _load({bool force = false, bool silent = false}) async {
    final requested = _scope;
    if (requested == null) return;
    if (!silent) {
      loading = true;
      error = null;
      _notify();
    }
    try {
      final snapshot = await _repo.stations(requested, forceRefresh: force);
      if (!identical(requested, _scope)) return;
      _snapshot = snapshot;
      error = null;
    } catch (e) {
      if (identical(requested, _scope) && !silent) error = e;
    } finally {
      if (identical(requested, _scope)) {
        loading = false;
        _invalidate();
      }
    }
  }

  Future<void> _onPosition(Position p) async {
    _position = p;
    _invalidate();

    final last = _lastProvinceCheck;
    final moved =
        last == null ||
        Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude) >
            _provinceRecheckMeters;
    if (!moved || _checkingProvince) return;

    _checkingProvince = true;
    try {
      final place = await _location.placeAt(p.latitude, p.longitude);
      _lastProvinceCheck = p;
      if (place == null) return;
      if (place.provinceId != myProvinceId) {
        myProvinceId = place.provinceId;
        myProvinceName = await _provinceName(place.provinceId);
      }
      await _resolveMyTown(place, p);

      // Si seguimos la ubicación, se pasa al pueblo (o provincia) actual.
      final s = _scope;
      final followTown =
          s == null ||
          s.kind == ScopeKind.myTown ||
          (s.kind == ScopeKind.myProvince && !_provinceChosenByUser);
      if (followTown) {
        if (myTownId != null) {
          await useMyTown();
        } else {
          await useMyProvince();
        }
      } else if (s.kind == ScopeKind.myProvince && s.id != myProvinceId) {
        await useMyProvince();
      }
      _notify();
    } finally {
      _checkingProvince = false;
    }
  }

  /// Averigua el municipio con las gasolineras de la provincia (que se
  /// reutilizan después para mostrarlas, así que no hay descarga extra).
  Future<void> _resolveMyTown(DetectedPlace place, Position p) async {
    try {
      final snapshot = await _repo.stations(SearchScope.province(place.provinceId, ''));
      final town = resolveTown(snapshot.stations, place.townNames, lat: p.latitude, lng: p.longitude);
      myTownId = town?.id;
      myTownName = town?.name;
    } catch (_) {
      myTownId = null;
      myTownName = null;
    }
  }

  Future<String> _provinceName(String id) async {
    if (provinces.isEmpty) await _loadRegions();
    for (final p in provinces) {
      if (p.id == id) return p.name;
    }
    return id;
  }

  Future<void> _loadRegions() async {
    try {
      final results = await Future.wait([_repo.provinces(), _repo.communities()]);
      provinces = results[0] as List<Province>;
      communities = results[1] as List<Community>;
      _notify();
    } catch (_) {
      // Se reintentará al abrir el selector de zona.
    }
  }

  Future<void> ensureRegions() async {
    if (provinces.isEmpty || communities.isEmpty) await _loadRegions();
  }

  /// Pueblos o códigos postales de otras zonas que coinciden con la búsqueda.
  List<PlaceSuggestion> get placeSuggestions {
    if (_query.trim().length < 3) return const [];
    if (_municipalities.isEmpty) unawaited(_loadMunicipalities());
    return _places ??= findPlaces(
      _query,
      current: _scope,
      municipalities: _municipalities,
      provinces: provinces,
    );
  }

  /// Cambia a la zona de una sugerencia manteniendo la búsqueda, así se ven
  /// directamente las gasolineras de ese pueblo o código postal.
  Future<void> goToPlace(PlaceSuggestion place) => setScope(place.scope);

  Future<void> _loadMunicipalities() async {
    if (_municipalitiesRequested) return;
    _municipalitiesRequested = true;
    try {
      final list = await _repo.municipalities();
      if (provinces.isEmpty) await _loadRegions();
      _municipalities = list;
      _invalidate();
    } catch (_) {
      // Se reintentará en la próxima búsqueda.
      _municipalitiesRequested = false;
    }
  }

  void _invalidate() {
    _entries = null;
    _places = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
