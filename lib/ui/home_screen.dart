import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../logic/savings.dart';
import '../models/car.dart';
import '../models/fuel_type.dart';
import '../models/region.dart';
import '../models/station.dart';
import '../state/garage_controller.dart';
import '../state/stations_controller.dart';
import 'favorites_screen.dart';
import 'format.dart';
import 'garage_forms.dart';
import 'garage_screen.dart';
import 'scope_picker.dart';
import 'stations_map.dart';
import 'theme.dart';
import 'widgets/brand_badge.dart';
import 'widgets/station_tile.dart';

/// Litros de referencia si el usuario no ha configurado su coche.
const _defaultTankLiters = 50.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMap = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _Header(
            search: _search,
            showMap: _showMap,
            onToggleMap: () => setState(() => _showMap = !_showMap),
          ),
          const FiltersBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showMap ? const _MapView() : const _StationList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera con degradado: marca, acciones, zona y buscador.
class _Header extends StatelessWidget {
  const _Header({required this.search, required this.showMap, required this.onToggleMap});

  final TextEditingController search;
  final bool showMap;
  final VoidCallback onToggleMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.watch<StationsController>();
    final scope = c.scope;
    final refreshing = c.loading && c.snapshot != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gasolineras',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Llena el depósito por menos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  _HeaderButton(
                    tooltip: showMap ? 'Ver lista' : 'Ver mapa',
                    icon: showMap ? Icons.view_agenda_outlined : Icons.map_outlined,
                    onPressed: onToggleMap,
                  ),
                  const SizedBox(width: 4),
                  _HeaderButton(
                    tooltip: 'Favoritas',
                    icon: Icons.star_outline_rounded,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _HeaderButton(
                    tooltip: 'Mi coche',
                    icon: Icons.directions_car_outlined,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const GarageScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => showScopePicker(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scope?.followsLocation ?? false ? Icons.my_location : Icons.place_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              scope?.label ?? 'Elegir zona',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ValueListenableBuilder(
                  valueListenable: search,
                  builder: (context, value, _) => TextField(
                    controller: search,
                    onChanged: c.setQuery,
                    textInputAction: TextInputAction.search,
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.ink),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Busca un pueblo, marca o código postal',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF7A8A82)),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.emerald),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar',
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF7A8A82)),
                              onPressed: () {
                                search.clear();
                                c.setQuery('');
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              if (refreshing) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      iconSize: 21,
      icon: Icon(icon, color: Colors.white),
    );
  }
}

/// Logotipo: gota con un surtidor sobre fondo blanco redondeado.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.local_gas_station_rounded, color: AppColors.emerald, size: size * 0.62),
          Positioned(
            right: size * 0.1,
            top: size * 0.08,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              child: Text(
                '€',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Combustible y orden. Se reutiliza en Favoritas.
class FiltersBar extends StatelessWidget {
  const FiltersBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: FuelType.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final fuel = FuelType.values[i];
                return _FuelChip(label: fuel.label, selected: c.fuel == fuel, onTap: () => c.setFuel(fuel));
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Con el coche configurado aparece "Rentables" (coste real con el
            // viaje); entonces las etiquetas se acortan para que quepan.
            child: SegmentedButton<SortMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: SortMode.price,
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(c.car == null ? 'Más baratas' : 'Baratas'),
                ),
                ButtonSegment(
                  value: SortMode.distance,
                  icon: const Icon(Icons.near_me),
                  label: Text(c.car == null ? 'Más cercanas' : 'Cercanas'),
                ),
                if (c.car != null)
                  const ButtonSegment(
                    value: SortMode.value,
                    icon: Icon(Icons.auto_graph_rounded),
                    label: Text('Rentables'),
                  ),
              ],
              selected: {c.sort},
              onSelectionChanged: (s) => c.setSort(s.first),
            ),
          ),
          if (c.sort != SortMode.price && c.position == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                c.sort == SortMode.distance
                    ? 'Activa la ubicación para ordenar por cercanía.'
                    : 'Activa la ubicación para calcular el coste del viaje.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (c.sort == SortMode.value && c.position != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Ordenadas por lo que te cuesta llenar el depósito, incluido el viaje de ida y vuelta.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _FuelChip extends StatelessWidget {
  const _FuelChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: StationsMap(
        // Al cambiar de zona o combustible se vuelve a encuadrar el mapa.
        key: ValueKey('${c.scope!.cacheKey}-${c.scope!.townId}-${c.fuel.name}-${c.query}'),
        entries: c.entries,
        userLocation: pos == null ? null : LatLng(pos.latitude, pos.longitude),
        sort: c.sort,
      ),
    );
  }
}

/// Mensaje para los estados sin datos (sin zona, descargando, error, sin
/// resultados) o `null` si hay gasolineras que mostrar.
Widget? _statusView(BuildContext context, StationsController c) {
  if (c.scope == null) {
    // Sin zona todavía, pero ya se puede buscar un pueblo o CP directamente.
    final places = c.placeSuggestions;
    if (places.isNotEmpty) return ListView(children: [_PlaceSuggestions(places: places)]);
    if (c.locating) {
      return const _Message(
        icon: Icons.my_location,
        title: 'Buscando tu ubicación…',
        text: 'Así te enseñamos las gasolineras de tu pueblo.',
        busy: true,
      );
    }
    return _Message(
      icon: Icons.location_off_outlined,
      title: 'No sabemos dónde estás',
      text: c.locationEnabled
          ? 'No hemos podido detectar tu pueblo. Elige una zona para ver precios.'
          : 'La app no tiene permiso para usar tu ubicación. Actívalo en los ajustes '
                'del navegador o del móvil, o elige una zona.',
      action: FilledButton.icon(
        icon: const Icon(Icons.place_outlined),
        onPressed: () => showScopePicker(context),
        label: const Text('Elegir zona'),
      ),
      secondary: TextButton(onPressed: c.retryLocation, child: const Text('Reintentar ubicación')),
    );
  }

  final snapshot = c.snapshot;
  if (snapshot == null) {
    if (c.error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'Sin conexión con los precios',
        text: '${c.error}',
        action: FilledButton(onPressed: c.refresh, child: const Text('Reintentar')),
      );
    }
    return const _Message(
      icon: Icons.local_gas_station_rounded,
      title: 'Buscando los mejores precios…',
      text: 'Consultando los datos oficiales del Ministerio.',
      busy: true,
    );
  }

  final entries = c.entries;
  if (entries.isEmpty) {
    final places = c.placeSuggestions;
    if (places.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'No hay resultados para "${c.query}" en ${c.scope!.label}. ¿Buscabas alguno de estos?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _PlaceSuggestions(places: places),
        ],
      );
    }
    final inTown = c.scope!.kind == ScopeKind.myTown;
    if (c.query.isNotEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        title: 'Nada por aquí',
        text: 'No encontramos gasolineras para "${c.query}". Prueba con otro pueblo, marca o código postal.',
      );
    }
    return _Message(
      icon: Icons.local_gas_station_outlined,
      title: inTown ? 'Sin ${c.fuel.label} en ${c.scope!.name}' : 'Sin ${c.fuel.label} en esta zona',
      text: 'Ninguna gasolinera de aquí vende este combustible.',
      action: inTown
          ? FilledButton(
              onPressed: c.useMyProvince,
              child: Text('Ver toda la provincia de ${c.myProvinceName}'),
            )
          : null,
    );
  }
  return null;
}

/// Pueblos o códigos postales de otras zonas; al tocarlos se cambia de zona
/// manteniendo la búsqueda.
class _PlaceSuggestions extends StatelessWidget {
  const _PlaceSuggestions({required this.places});

  final List<PlaceSuggestion> places;

  @override
  Widget build(BuildContext context) {
    final c = context.read<StationsController>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final p in places)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.travel_explore_rounded, color: scheme.primary, size: 20),
                ),
                title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Provincia de ${p.subtitle}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => c.goToPlace(p),
              ),
            ),
          ),
      ],
    );
  }
}

class _StationList extends StatelessWidget {
  const _StationList();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final status = _statusView(context, c);
    if (status != null) return status;

    final theme = Theme.of(context);
    final snapshot = c.snapshot!;
    final entries = c.entries;
    final prices = entries.map((e) => e.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final average = prices.reduce((a, b) => a + b) / prices.length;
    final cheapest = entries.reduce((a, b) => b.price < a.price ? b : a);
    final places = c.placeSuggestions;
    final garage = context.watch<GarageController>();

    final header = <Widget>[
      if (places.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            'En otras zonas',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        _PlaceSuggestions(places: places),
      ],
      if (garage.loaded && garage.car == null)
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12), child: _CarPrompt()),
      if (entries.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: _BestDealCard(
            entry: cheapest,
            average: average,
            fuel: c.fuel,
            car: garage.car,
            worthIt: garage.car == null ? null : compareCheapestWithNearest(entries, garage.car!),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(
          children: [
            Text(
              '${entries.length} gasolineras',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (snapshot.publishedAt != null)
              Text(
                'Precios de ${formatPublished(snapshot.publishedAt!)}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    ];

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: header.length + entries.length,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          final e = entries[i - header.length];
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

/// Tarjeta destacada con la gasolinera más barata y lo que se ahorra al
/// llenar el depósito frente a la media de la zona.
class _BestDealCard extends StatelessWidget {
  const _BestDealCard({
    required this.entry,
    required this.average,
    required this.fuel,
    required this.car,
    required this.worthIt,
  });

  final StationEntry entry;
  final double average;
  final FuelType fuel;
  final CarProfile? car;
  final WorthIt? worthIt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Station s = entry.station;
    final tankLiters = car?.tankLiters ?? _defaultTankLiters;
    final saving = (average - entry.price) * tankLiters;
    final litersText = formatLiters(tankLiters).replaceAll(',0 L', ' L');

    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showStationDetails(context, s, entry.distanceKm, fuel: fuel),
        child: Stack(
          children: [
            // Destello decorativo en la esquina.
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.amber.withValues(alpha: 0.35), AppColors.amber.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.ink),
                            const SizedBox(width: 4),
                            Text(
                              'LA MÁS BARATA',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (entry.distanceKm != null)
                        InfoPill(
                          icon: Icons.near_me,
                          text: formatDistance(entry.distanceKm!),
                          color: Colors.white70,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      BrandBadge(brand: s.brand, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.brand.isEmpty ? 'Sin marca' : s.brand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${s.address} · ${s.municipality.split('/').first}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPriceNumber(entry.price),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            '€/L · ${fuel.label}',
                            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.savings_rounded, color: Color(0xFF3DD68C), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            saving >= 0.5
                                ? TextSpan(
                                    children: [
                                      TextSpan(text: 'Llenando $litersText aquí ahorras '),
                                      TextSpan(
                                        text: formatEuros(saving),
                                        style: const TextStyle(
                                          color: Color(0xFF3DD68C),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(text: ' frente a la media (${formatPrice(average)}/L)'),
                                    ],
                                  )
                                : const TextSpan(text: 'Los precios de la zona son muy parecidos.'),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (worthIt != null) ...[const SizedBox(height: 8), _WorthItBox(result: worthIt!)],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Llévame'),
                      onPressed: () => openDirections(s),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "¿Merece la pena ir?": ahorro en combustible frente a la gasolinera más
/// cercana, menos lo que cuesta de más el viaje.
class _WorthItBox extends StatelessWidget {
  const _WorthItBox({required this.result});

  final WorthIt result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = result.worthIt;
    final accent = ok ? const Color(0xFF3DD68C) : const Color(0xFFFF8A80);
    final nearest = result.nearest;
    final style = theme.textTheme.bodySmall?.copyWith(color: Colors.white70);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.thumb_up_alt_rounded : Icons.do_not_disturb_on_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? '¿Merece la pena ir? Sí: ahorras ${formatEuros(result.netSaving)}'
                      : '¿Merece la pena ir? No, mejor la más cercana',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Frente a ${nearest.station.brand.isEmpty ? 'la más cercana' : nearest.station.brand} '
            '(a ${formatDistance(nearest.distanceKm!)}, ${formatPrice(nearest.price)}/L): '
            '${formatEuros(result.fuelSaving)} menos en combustible, '
            '${formatEuros(result.extraTripCost)} más de viaje (ida y vuelta).',
            style: style,
          ),
        ],
      ),
    );
  }
}

/// Invitación a configurar el coche (desaparece al hacerlo).
class _CarPrompt extends StatelessWidget {
  const _CarPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCarForm(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.directions_car_filled_rounded, color: scheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configura tu coche',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Y te diremos si compensa ir a la más barata, contando el viaje.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.text,
    this.busy = false,
    this.action,
    this.secondary,
  });

  final IconData icon;
  final String title;
  final String? text;
  final bool busy;
  final Widget? action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 42, color: scheme.primary),
                  if (busy)
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(strokeWidth: 3, color: scheme.primary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(
                text!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
            ?secondary,
          ],
        ),
      ),
    );
  }
}
