import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/fuel_type.dart';
import '../../models/station.dart';
import '../../state/favorites_controller.dart';
import '../format.dart';
import '../theme.dart';
import 'brand_badge.dart';

/// Tarjeta de una gasolinera en la lista: marca, dirección, distancia y el
/// precio grande con su color (verde barato, rojo caro).
class StationTile extends StatelessWidget {
  const StationTile({
    super.key,
    required this.station,
    required this.fuel,
    required this.price,
    required this.distanceKm,
    required this.minPrice,
    required this.maxPrice,
  });

  final Station station;
  final FuelType fuel;
  final double? price;
  final double? distanceKm;
  final double minPrice;
  final double maxPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isFavorite = context.select<FavoritesController, bool>((f) => f.isFavorite(station.id));
    final p = price;
    final color = p == null ? scheme.onSurfaceVariant : priceColor(p, minPrice, maxPrice);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showStationDetails(context, station, distanceKm, fuel: fuel),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              children: [
                BrandBadge(brand: station.brand, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.brand.isEmpty ? 'Sin marca' : station.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${station.address} · ${station.municipality.split('/').first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (distanceKm != null || isOpen24h(station.schedule)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (distanceKm != null)
                              InfoPill(icon: Icons.near_me, text: formatDistance(distanceKm!)),
                            if (isOpen24h(station.schedule))
                              const InfoPill(icon: Icons.schedule, text: '24 h'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p == null ? '—' : formatPriceNumber(p),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text('€/L', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                IconButton(
                  tooltip: isFavorite ? 'Quitar de favoritas' : 'Añadir a favoritas',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded),
                  color: isFavorite ? AppColors.amber : scheme.onSurfaceVariant,
                  onPressed: () => context.read<FavoritesController>().toggle(station),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña con icono ("1,2 km", "24 h").
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

Future<void> openDirections(Station station) => launchUrl(
  Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}'),
  mode: LaunchMode.externalApplication,
);

/// Ficha de la gasolinera: todos sus precios (el combustible elegido,
/// destacado), horario, distancia y acciones.
Future<void> showStationDetails(BuildContext context, Station station, double? distanceKm, {FuelType? fuel}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final isFavorite = context.select<FavoritesController, bool>((f) => f.isFavorite(station.id));
      final prices = station.prices.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index));

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BrandBadge(brand: station.brand, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.brand.isEmpty ? 'Sin marca' : station.brand,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${station.address}\n${station.postalCode} ${station.municipality} '
                          '(${station.province})',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (distanceKm != null)
                    InfoPill(icon: Icons.near_me, text: 'A ${formatDistance(distanceKm)}'),
                  if (station.schedule.isNotEmpty)
                    InfoPill(
                      icon: Icons.schedule,
                      text: isOpen24h(station.schedule) ? 'Abierta 24 h' : station.schedule,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Precios', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (prices.isEmpty)
                Text('Esta gasolinera no ha publicado precios.', style: theme.textTheme.bodyMedium)
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    for (final e in prices)
                      _PriceCell(fuel: e.key, price: e.value, highlighted: e.key == fuel),
                  ],
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFavorite ? AppColors.amber : null,
                      ),
                      label: Text(isFavorite ? 'Favorita' : 'Guardar'),
                      onPressed: () => context.read<FavoritesController>().toggle(station),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Cómo llegar'),
                      onPressed: () => openDirections(station),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({required this.fuel, required this.price, required this.highlighted});

  final FuelType fuel;
  final double price;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlighted ? scheme.primary : scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fuel.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            formatPrice(price),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
