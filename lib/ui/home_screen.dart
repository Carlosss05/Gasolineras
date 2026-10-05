import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/fuel_type.dart';
import '../models/region.dart';
import '../state/stations_controller.dart';
import 'favorites_screen.dart';
import 'format.dart';
import 'scope_picker.dart';
import 'stations_map.dart';
import 'widgets/station_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final loading = context.select<StationsController, bool>((c) => c.loading && c.snapshot != null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gasolineras baratas'),
        actions: [
          IconButton(
            tooltip: _showMap ? 'Ver lista' : 'Ver mapa',
            icon: Icon(_showMap ? Icons.view_list : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            tooltip: 'Favoritas',
            icon: const Icon(Icons.star_outline),
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
        ],
        bottom: loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          const FiltersBar(showSearch: true),
          Expanded(child: _showMap ? const _MapView() : const _StationList()),
        ],
      ),
    );
  }
}

/// Zona, buscador, combustible y orden. Se reutiliza en Favoritas.
class FiltersBar extends StatelessWidget {
  const FiltersBar({super.key, this.showSearch = false});

  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final scope = c.scope;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ActionChip(
                    avatar: Icon(
                      scope?.kind == ScopeKind.myProvince ? Icons.my_location : Icons.place_outlined,
                      size: 18,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(scope?.label ?? 'Elegir zona', overflow: TextOverflow.ellipsis),
                    ),
                    onPressed: () => showScopePicker(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Pueblo, marca, CP…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: c.setQuery,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: FuelType.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final fuel = FuelType.values[i];
                return ChoiceChip(
                  label: Text(fuel.label),
                  selected: c.fuel == fuel,
                  onSelected: (_) => c.setFuel(fuel),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<SortMode>(
              segments: const [
                ButtonSegment(value: SortMode.price, icon: Icon(Icons.euro), label: Text('Más baratas')),
                ButtonSegment(
                  value: SortMode.distance,
                  icon: Icon(Icons.near_me),
                  label: Text('Más cercanas'),
                ),
              ],
              selected: {c.sort},
              onSelectionChanged: (s) => c.setSort(s.first),
            ),
          ),
          if (c.sort == SortMode.distance && c.position == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Activa la ubicación para ordenar por cercanía.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final status = _statusView(context, c);
    if (status != null) return status;

    final pos = c.position;
    return StationsMap(
      // Al cambiar de zona o combustible se vuelve a encuadrar el mapa.
      key: ValueKey('${c.scope!.cacheKey}-${c.fuel.name}-${c.query}'),
      entries: c.entries,
      userLocation: pos == null ? null : LatLng(pos.latitude, pos.longitude),
      sort: c.sort,
    );
  }
}

/// Mensaje para los estados sin datos (sin zona, descargando, error, sin
/// resultados) o `null` si hay gasolineras que mostrar.
Widget? _statusView(BuildContext context, StationsController c) {
  if (c.scope == null) {
    if (c.locating) {
      return const _Message(icon: Icons.my_location, text: 'Buscando tu ubicación…', busy: true);
    }
    return _Message(
      icon: Icons.location_off_outlined,
      text: 'No hemos podido detectar tu provincia.\nElige una zona para ver precios.',
      action: FilledButton(onPressed: () => showScopePicker(context), child: const Text('Elegir zona')),
      secondary: TextButton(onPressed: c.retryLocation, child: const Text('Reintentar ubicación')),
    );
  }

  final snapshot = c.snapshot;
  if (snapshot == null) {
    if (c.error != null) {
      return _Message(
        icon: Icons.cloud_off,
        text: '${c.error}',
        action: FilledButton(onPressed: c.refresh, child: const Text('Reintentar')),
      );
    }
    return const _Message(icon: Icons.local_gas_station, text: 'Descargando precios…', busy: true);
  }

  final entries = c.entries;
  if (entries.isEmpty) {
    return _Message(
      icon: Icons.search_off,
      text: c.query.isEmpty
          ? 'Ninguna gasolinera de esta zona vende ${c.fuel.label}.'
          : 'Sin resultados para "${c.query}".',
    );
  }
  return null;
}

class _StationList extends StatelessWidget {
  const _StationList();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final status = _statusView(context, c);
    if (status != null) return status;

    final snapshot = c.snapshot!;
    final entries = c.entries;
    final prices = entries.map((e) => e.price);
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.separated(
        itemCount: entries.length + 1,
        separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 16),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                '${entries.length} gasolineras · desde ${formatPrice(minPrice)}'
                '${snapshot.publishedAt != null ? ' · precios de ${formatPublished(snapshot.publishedAt!)}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          final e = entries[i - 1];
          return StationTile(
            station: e.station,
            fuel: c.fuel,
            price: e.price,
            distanceKm: e.distanceKm,
            minPrice: minPrice,
            maxPrice: maxPrice,
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.busy = false, this.action, this.secondary});

  final IconData icon;
  final String text;
  final bool busy;
  final Widget? action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const CircularProgressIndicator()
                : Icon(icon, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
            ?secondary,
          ],
        ),
      ),
    );
  }
}
