import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fuel_price_repository.dart';
import '../data/snapshot_store.dart';
import '../logic/price_trend.dart';
import '../logic/savings.dart';
import '../models/car.dart';
import '../models/fuel_type.dart';
import '../models/price_history.dart';
import '../models/region.dart';
import '../models/station.dart';
import '../services/location_service.dart';
import '../utils/text.dart';

/// [value]: coste real de repostar (combustible + viaje); necesita el plan de
/// repostaje (litros y consumo) y la ubicación.
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
  TripPlan? plan,
}) {
  final q = normalize(query.trim());
  final list = <StationEntry>[];
  for (final s in stations) {
    final price = s.prices[fuel];
    if (price == null) continue;
    if (municipalityId != null && s.municipalityId != municipalityId) continue;
    if (q.isNotEmpty && !s.searchText.contains(q)) continue;
    final d = position == null ? null : LocationService.distanceKm(position.lat, position.lng, s.latitude, s.longitude);
    list.add(StationEntry(s, price, d));
  }

  int byPrice(StationEntry a, StationEntry b) => a.price.compareTo(b.price);
  int byDistance(StationEntry a, StationEntry b) =>
      (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity);

  final (first, second) = switch (sort) {
    SortMode.distance when position != null => (byDistance, byPrice),
    SortMode.value when position != null && plan != null => (
      (StationEntry a, StationEntry b) => effectiveCost(a, plan).compareTo(effectiveCost(b, plan)),
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

/// Nombres normalizados de cada municipio, calculados una sola vez: en cada
/// tecla del buscador se consultan los 8.100 de España.
final _municipalityNames = Expando<List<String>>();

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
    return [PlaceSuggestion('Código postal $q', province.name, SearchScope.province(province.id, province.name))];
  }
  if (q.length < 3 || RegExp(r'^\d+$').hasMatch(q)) return const [];

  final startsWith = <Municipality>[];
  final contains = <Municipality>[];
  for (final m in municipalities) {
    if (!outside(m.provinceId, m.communityId, m.id)) continue;
    // Nombres bilingües: "Calpe/Calp" debe encontrarse por cualquiera de los dos.
    final names = _municipalityNames[m] ??= [for (final n in normalize(m.name).split('/')) n.trim()];
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

/// Mínimo, máximo, media y gasolinera más barata de la lista. Se calcula una
/// vez por cambio de lista, no en cada repintado.
typedef EntriesSummary = ({double min, double max, double average, StationEntry cheapest});

class StationsController extends ChangeNotifier {
  StationsController(this._repo, this._location, {SnapshotStore? store}) : _store = store ?? SnapshotStore();

  static const _autoRefreshEvery = Duration(minutes: 10);

  /// Distancia que hay que recorrer antes de volver a comprobar pueblo y provincia.
  static const _provinceRecheckMeters = 1500.0;

  /// Lo que se escribe en el buscador se usa tal cual para filtrar miles de
  /// textos: se acota para que un pegado enorme no cueste nada.
  static const maxQueryLength = 60;

  final FuelPriceRepository _repo;
  final LocationService _location;
  final SnapshotStore _store;

  SearchScope? _scope;
  FuelType _fuel = FuelType.gasolina95;
  SortMode _sort = SortMode.price;
  String _query = '';
  CarProfile? _car;

  // Plan de repostaje: lo que se ajusta en "¿Dónde reposto?". Mientras no se
  // toque, sale del coche configurado o de valores típicos.
  double? _planLiters;
  double? _planConsumption;
  bool _roundTrip = true;
  EntriesSummary? _summary;
  Recommendation? _recommendation;
  bool _recommendationReady = false;

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

  /// Los precios en pantalla son los guardados de otra sesión y aún no ha
  /// llegado la actualización.
  bool _showingStored = false;

  List<Province> provinces = const [];
  List<Community> communities = const [];

  List<StationEntry>? _entries;
  List<Municipality> _municipalities = const [];
  bool _municipalitiesRequested = false;
  List<PlaceSuggestion>? _places;
  StreamSubscription<Position>? _positionSub;
  Timer? _refreshTimer;
  bool _disposed = false;

  // Evolución de precios: los de la zona y el combustible actuales hace un
  // día y hace una semana.
  TrendPeriod _trendPeriod = TrendPeriod.day;
  String? _trendKey;
  bool trendLoading = false;
  final _history = <TrendPeriod, PriceHistory>{};
  final _zoneTrends = <TrendPeriod, ZoneTrend?>{};

  SearchScope? get scope => _scope;
  FuelType get fuel => _fuel;
  SortMode get sort => _sort;
  String get query => _query;
  Position? get position => _position;
  PriceSnapshot? get snapshot => _snapshot;

  /// No se han podido actualizar los precios y se enseñan los últimos que
  /// había (guardados o de esta sesión).
  bool get offline => error != null && _snapshot != null;

  List<StationEntry> get entries => _entries ??= _snapshot == null
      ? const []
      : buildEntries(
          _snapshot!.stations,
          fuel: _fuel,
          sort: _sort,
          position: _position == null ? null : (lat: _position!.latitude, lng: _position!.longitude),
          query: _query,
          municipalityId: _scope?.kind == ScopeKind.myTown ? _scope!.townId : null,
          plan: _car == null ? null : plan,
        );

  /// Resumen de precios de [entries]; `null` con la lista vacía.
  EntriesSummary? get summary {
    final list = entries;
    if (list.isEmpty) return null;
    return _summary ??= () {
      var min = double.infinity, max = 0.0, sum = 0.0;
      var cheapest = list.first;
      for (final e in list) {
        sum += e.price;
        if (e.price > max) max = e.price;
        if (e.price < min) {
          min = e.price;
          cheapest = e;
        }
      }
      return (min: min, max: max, average: sum / list.length, cheapest: cheapest);
    }();
  }

  /// Litros, consumo y tipo de viaje con los que se calcula a qué gasolinera
  /// conviene ir.
  TripPlan get plan => TripPlan(
    liters: _planLiters ?? _car?.tankLiters ?? TripPlan.defaultLiters,
    consumption: _planConsumption ?? _car?.consumption ?? TripPlan.defaultConsumption,
    roundTrip: _roundTrip,
  );

  /// Si el plan usa valores típicos (ni coche configurado ni ajustes a mano).
  bool get planIsTypical => _car == null && _planLiters == null && _planConsumption == null;

  /// Ajusta el plan de repostaje; los valores se acotan a rangos razonables.
  void setPlan({double? liters, double? consumption, bool? roundTrip}) {
    if (liters != null && liters.isFinite) {
      _planLiters = liters.clamp(TripPlan.minLiters, TripPlan.maxLiters).toDouble();
    }
    if (consumption != null && consumption.isFinite) {
      _planConsumption = consumption.clamp(TripPlan.minConsumption, TripPlan.maxConsumption).toDouble();
    }
    if (roundTrip != null) _roundTrip = roundTrip;
    _recommendationReady = false;
    // La lista solo depende del plan cuando se ordena por coste real.
    if (_sort == SortMode.value) {
      _invalidate();
    } else {
      _notify();
    }
  }

  /// A qué gasolinera de la lista conviene ir contando el viaje. `null` sin
  /// ubicación o sin gasolineras.
  Recommendation? get recommendation {
    if (!_recommendationReady) {
      _recommendation = recommend(entries, plan);
      _recommendationReady = true;
    }
    return _recommendation;
  }

  /// Lo que cuesta repostar en [e] con el plan actual, viaje incluido.
  StationCost costOf(StationEntry e) => stationCost(e, plan);

  /// Gasolineras de la zona actual (sin filtrar por combustible ni búsqueda),
  /// de la más cercana a la más lejana si hay ubicación. Para elegir dónde se
  /// ha repostado.
  List<StationEntry> nearbyStations() {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    final townId = _scope?.kind == ScopeKind.myTown ? _scope!.townId : null;
    final pos = _position;
    final list = <StationEntry>[
      for (final s in snapshot.stations)
        if (townId == null || s.municipalityId == townId)
          StationEntry(
            s,
            s.prices.values.isEmpty ? 0 : s.prices.values.first,
            pos == null ? null : LocationService.distanceKm(pos.latitude, pos.longitude, s.latitude, s.longitude),
          ),
    ];
    if (pos != null) list.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    return list;
  }

  /// Precio medio de [fuel] en la zona actual, para calcular el ahorro de un
  /// repostaje. `null` si no hay datos.
  double? zoneAverageFor(FuelType fuel) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    final townId = _scope?.kind == ScopeKind.myTown ? _scope!.townId : null;
    final prices = <double>[
      for (final s in snapshot.stations)
        if ((townId == null || s.municipalityId == townId) && s.prices[fuel] != null) s.prices[fuel]!,
    ];
    if (prices.isEmpty) return null;
    return prices.fold<double>(0, (sum, p) => sum + p) / prices.length;
  }

  /// Con qué día se compara el precio de cada gasolinera de la lista.
  TrendPeriod get trendPeriod => _trendPeriod;

  void setTrendPeriod(TrendPeriod period) {
    if (period == _trendPeriod) return;
    _trendPeriod = period;
    _notify();
  }

  /// Si hay (o se está cargando) evolución de precios para la zona actual. No
  /// la hay para toda España ni si el histórico no responde.
  bool get hasTrend => trendLoading || _history.isNotEmpty;

  /// Cuánto ha cambiado (en €/L) el precio de [stationId] desde el día de
  /// [period] (por defecto, el elegido). `null` si no hay dato de ese día.
  double? priceChange(String stationId, double price, [TrendPeriod? period]) {
    final before = _history[period ?? _trendPeriod]?.prices[stationId];
    return before == null ? null : price - before;
  }

  /// Precio de [stationId] el día de [period], si se conoce.
  ({DateTime day, double price})? pastPrice(String stationId, TrendPeriod period) {
    final history = _history[period];
    final price = history?.prices[stationId];
    return history == null || price == null ? null : (day: history.day, price: price);
  }

  /// Cambio del precio medio de la lista actual desde el día de [period].
  ZoneTrend? zoneTrendFor(TrendPeriod period) {
    if (_zoneTrends.containsKey(period)) return _zoneTrends[period];
    final history = _history[period];
    return _zoneTrends[period] = history == null ? null : zoneTrend(entries, history);
  }

  /// Día de los precios actuales (sin hora): con el que se cuentan "ayer" y
  /// "hace una semana".
  DateTime get pricesDay {
    final d = _snapshot?.publishedAt ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  /// Zona, combustible y día de la evolución que toca mostrar; `null` si no
  /// se puede (sin datos todavía, o toda España).
  String? get _wantedTrendKey {
    final s = _scope;
    // Con precios guardados de otro día se espera a los de hoy para comparar.
    if (s == null || _snapshot == null || _showingStored || s.kind == ScopeKind.spain) return null;
    return '${s.kind.name}|${s.id}|${s.townId}|${_fuel.name}|$pricesDay';
  }

  /// Descarga en segundo plano los precios de hace un día y una semana. Se
  /// lanza después de mostrar la lista para no retrasarla.
  Future<void> _loadTrend() async {
    final key = _wantedTrendKey;
    if (key == _trendKey) return;
    _trendKey = key;
    _history.clear();
    _zoneTrends.clear();
    final scope = _scope;
    if (key == null || scope == null) {
      trendLoading = false;
      return;
    }
    trendLoading = true;
    final fuel = _fuel;
    final today = pricesDay;
    final results = await Future.wait([
      for (final period in TrendPeriod.values) _historyAround(scope, fuel, today, period.days),
    ]);
    if (key != _trendKey || _disposed) return;
    for (final (i, period) in TrendPeriod.values.indexed) {
      final history = results[i];
      if (history != null) _history[period] = history;
    }
    trendLoading = false;
    _zoneTrends.clear();
    _notify();
  }

  /// Precios de hace [days] días; si ese día aún no se ha publicado (o falla),
  /// los del día anterior.
  Future<PriceHistory?> _historyAround(SearchScope scope, FuelType fuel, DateTime today, int days) async {
    for (final back in [days, days + 1]) {
      try {
        final history = await _repo.history(scope, fuel, DateTime(today.year, today.month, today.day - back));
        if (history.prices.isNotEmpty) return history;
      } catch (_) {
        // Se prueba con el día anterior; si tampoco, no se muestra la evolución.
      }
    }
    return null;
  }

  Future<void> init() async {
    _refreshTimer = Timer.periodic(_autoRefreshEvery, (_) => refresh(silent: true));
    unawaited(_loadRegions());

    // La última zona usada se muestra al instante, sin esperar al GPS; si
    // era "mi provincia", la ubicación la corrige después si has cambiado.
    final saved = await _restoreScope();
    if (saved != null && _scope == null) {
      // Los últimos precios guardados de esa zona se enseñan ya, sin esperar
      // a la red; los nuevos se piden por detrás y los sustituyen.
      final stored = await _store.load(saved.cacheKey);
      if (_scope == null) {
        if (stored == null) {
          unawaited(setScope(saved));
        } else {
          _scope = saved;
          _snapshot = stored;
          _showingStored = true;
          _invalidate();
          unawaited(_load(force: true));
        }
      }
    }

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
      return SearchScope.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveScope(SearchScope s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scopeKey, jsonEncode(s.toJson()));
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
    _planLiters = null;
    _planConsumption = null;
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
    if (query.length > maxQueryLength) query = query.substring(0, maxQueryLength);
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
    // Si esta zona ya se descargó antes en esta sesión se enseña al instante,
    // aunque ya no sea reciente, mientras se actualiza.
    _snapshot = _repo.peek(scope);
    _showingStored = false;
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
    // La respuesta vale mientras se siga en una zona con los mismos datos
    // (p. ej. al pasar de la provincia a un pueblo suyo durante la descarga).
    bool current() => _scope?.cacheKey == requested.cacheKey;
    if (!silent) {
      loading = true;
      error = null;
      _notify();
    }
    try {
      final snapshot = await _repo.stations(requested, forceRefresh: force);
      if (!current()) return;
      _snapshot = snapshot;
      _showingStored = false;
      error = null;
      unawaited(_store.save(requested.cacheKey, snapshot));
    } catch (e) {
      if (current() && !silent) error = e;
    } finally {
      if (current()) {
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
        Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude) > _provinceRecheckMeters;
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
          s == null || s.kind == ScopeKind.myTown || (s.kind == ScopeKind.myProvince && !_provinceChosenByUser);
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
    return _places ??= findPlaces(_query, current: _scope, municipalities: _municipalities, provinces: provinces);
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
    _summary = null;
    _recommendationReady = false;
    _zoneTrends.clear();
    if (_wantedTrendKey != _trendKey) unawaited(_loadTrend());
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
