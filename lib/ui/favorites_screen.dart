import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/fuel_price_repository.dart';
import '../models/region.dart';
import '../models/station.dart';
import '../state/favorites_controller.dart';
import '../state/stations_controller.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'widgets/station_tile.dart';

/// Gasolineras guardadas, con su precio actual aunque estén en otra provincia.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Station>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Station>> _load({bool force = false}) async {
    final repo = context.read<FuelPriceRepository>();
    final favorites = context.read<FavoritesController>().provinceById;
    final provinceIds = favorites.values.toSet();
    final snapshots = await Future.wait(
      provinceIds.map((id) => repo.stations(SearchScope.province(id, id), forceRefresh: force)),
    );
    return [
      for (final s in snapshots)
        for (final station in s.stations)
          if (favorites.containsKey(station.id)) station,
    ];
  }

  Future<void> _reload() {
    final future = _load(force: true);
    setState(() => _future = future);
    return future;
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final c = context.watch<StationsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritas')),
      body: Column(
        children: [
          const FiltersBar(),
          Expanded(
            child: favorites.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(color: Color(0x33F5A524), shape: BoxShape.circle),
                            child: const Icon(Icons.star_rounded, size: 48, color: AppColors.amber),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Aún no tienes favoritas',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pulsa la estrella de tus gasolineras habituales y aquí verás '
                            'sus precios de hoy de un vistazo.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : FutureBuilder<List<Station>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${snap.error}'),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _reload, child: const Text('Reintentar')),
                            ],
                          ),
                        );
                      }
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                      final stations = snap.data!.where((s) => favorites.isFavorite(s.id)).toList();
                      final pos = c.position;
                      final withFuel = buildEntries(
                        stations,
                        fuel: c.fuel,
                        sort: c.sort,
                        car: c.car,
                        position: pos == null ? null : (lat: pos.latitude, lng: pos.longitude),
                      );
                      final withoutFuel = stations.where((s) => !s.prices.containsKey(c.fuel)).toList();
                      final prices = withFuel.map((e) => e.price);
                      final minPrice = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
                      final maxPrice = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);

                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          children: [
                            for (final e in withFuel)
                              StationTile(
                                station: e.station,
                                fuel: c.fuel,
                                price: e.price,
                                distanceKm: e.distanceKm,
                                minPrice: minPrice,
                                maxPrice: maxPrice,
                              ),
                            for (final s in withoutFuel)
                              StationTile(
                                station: s,
                                fuel: c.fuel,
                                price: null,
                                distanceKm: null,
                                minPrice: minPrice,
                                maxPrice: maxPrice,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
