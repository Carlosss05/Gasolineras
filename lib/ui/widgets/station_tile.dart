import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/fuel_type.dart';
import '../../models/station.dart';
import '../../state/favorites_controller.dart';
import '../format.dart';

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
    final isFavorite = context.select<FavoritesController, bool>((f) => f.isFavorite(station.id));
    final p = price;

    return ListTile(
      onTap: () => showStationDetails(context, station, distanceKm),
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(
        station.brand.isEmpty ? 'Sin marca' : station.brand,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          '${station.address}, ${station.municipality}',
          if (distanceKm != null) formatDistance(distanceKm!),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p == null ? '—' : formatPrice(p),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: p == null ? theme.disabledColor : priceColor(p, minPrice, maxPrice),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            tooltip: isFavorite ? 'Quitar de favoritas' : 'Añadir a favoritas',
            icon: Icon(isFavorite ? Icons.star : Icons.star_border),
            color: isFavorite ? Colors.amber.shade700 : null,
            onPressed: () => context.read<FavoritesController>().toggle(station),
          ),
        ],
      ),
    );
  }
}

Future<void> showStationDetails(BuildContext context, Station station, double? distanceKm) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final isFavorite = context.select<FavoritesController, bool>((f) => f.isFavorite(station.id));
      final prices = station.prices.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index));

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(station.brand.isEmpty ? 'Sin marca' : station.brand, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${station.address}\n${station.postalCode} ${station.municipality} (${station.province})'),
              if (station.schedule.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Horario: ${station.schedule}', style: theme.textTheme.bodySmall),
              ],
              if (distanceKm != null)
                Text('A ${formatDistance(distanceKm)} de ti', style: theme.textTheme.bodySmall),
              const Divider(height: 24),
              for (final e in prices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key.label)),
                      Text(formatPrice(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (prices.isEmpty) const Text('Sin precios publicados.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                      label: Text(isFavorite ? 'Favorita' : 'Guardar'),
                      onPressed: () => context.read<FavoritesController>().toggle(station),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Cómo llegar'),
                      onPressed: () => launchUrl(
                        Uri.parse('https://www.google.com/maps/dir/?api=1'
                            '&destination=${station.latitude},${station.longitude}'),
                        mode: LaunchMode.externalApplication,
                      ),
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
