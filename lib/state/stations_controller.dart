import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fuel_price_repository.dart';
import '../models/fuel_type.dart';
import '../models/region.dart';
import '../models/station.dart';
import '../services/location_service.dart';
import '../utils/text.dart';

enum SortMode { price, distance }

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
}) {
  final q = normalize(query.trim());
  final list = <StationEntry>[];
  for (final s in stations) {
    final price = s.prices[fuel];
    if (price == null) continue;
    if (q.isNotEmpty && !s.searchText.contains(q)) continue;
    final d = position == null
        ? null
        : LocationService.distanceKm(position.lat, position.lng, s.latitude, s.longitude);
    list.add(StationEntry(s, price, d));
  }

  int byPrice(StationEntry a, StationEntry b) => a.price.compareTo(b.price);
  int byDistance(StationEntry a, StationEntry b) =>
      (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);

  final (first, second) = sort == SortMode.distance && position != null
      ? (byDistance, byPrice)
      : (byPrice, byDistance);
  list.sort((a, b) {
    final c = first(a, b);
    return c != 0 ? c : second(a, b);
  });
  return list;
}

class StationsController extends ChangeNotifier {
  StationsController(this._repo, this._location);

  static const _autoRefreshEvery = Duration(minutes: 10);

  /// Distancia que hay que recorrer antes de volver a comprobar la provincia.
  static const _provinceRecheckMeters = 3000.0;

  final FuelPriceRepository _repo;
  final LocationService _location;

  SearchScope? _scope;
  FuelType _fuel = FuelType.gasolina95;
  SortMode _sort = SortMode.price;
  String _query = '';

  Position? _position;
  Position? _lastProvinceCheck;
  bool _checkingProvince = false;
  bool locating = false;
  bool locationEnabled = false;
  String? myProvinceId;
  String? myProvinceName;

  PriceSnapshot? _snapshot;
  bool loading = false;
  Object? error;

  List<Province> provinces = const [];
  List<Community> communities = const [];

  List<StationEntry>? _entries;
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
      await prefs.setString(_scopeKey, jsonEncode({'kind': s.kind.name, 'id': s.id, 'name': s.name}));
    } catch (_) {
      // No es grave: la próxima vez se pedirá la zona otra vez.
    }
  }

  void setFuel(FuelType fuel) {
    if (fuel == _fuel) return;
    _fuel = fuel;
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
      // Misma zona (p. ej. el GPS confirma la provincia guardada): no hace
      // falta volver a descargar ni vaciar la lista.
      _notify();
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
      final id = await _location.provinceIdAt(p.latitude, p.longitude);
      _lastProvinceCheck = p;
      if (id == null || id == myProvinceId) return;
      myProvinceId = id;
      myProvinceName = await _provinceName(id);
      // Al cambiar de provincia se recargan los precios si seguimos "mi provincia".
      if (_scope == null || _scope!.followsLocation) await useMyProvince();
      _notify();
    } finally {
      _checkingProvince = false;
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

  void _invalidate() {
    _entries = null;
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
