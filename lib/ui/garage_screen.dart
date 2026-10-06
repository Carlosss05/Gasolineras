import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../state/garage_controller.dart';
import 'format.dart';
import 'garage_forms.dart';
import 'theme.dart';

/// "Mi coche": datos del coche, resumen de gastos y diario de repostajes.
class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final garage = context.watch<GarageController>();
    final car = garage.car;
    final stats = garage.stats;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi coche')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRefuelForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Anotar repostaje'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          _CarCard(car: car),
          const SizedBox(height: 16),
          Text(
            'Este mes · ${formatMonth(DateTime.now())}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _StatTile(
                icon: Icons.payments_outlined,
                label: 'Gastado',
                value: formatEuros(stats.spentThisMonth),
                detail: stats.litersThisMonth > 0 ? formatLiters(stats.litersThisMonth) : 'Sin repostajes',
              ),
              _StatTile(
                icon: Icons.savings_outlined,
                label: 'Ahorrado con la app',
                value: formatEuros(stats.totalSaving),
                detail: 'Frente a la media de la zona',
                highlight: stats.totalSaving > 0,
              ),
              _StatTile(
                icon: Icons.speed_rounded,
                label: 'Consumo real',
                value: stats.consumption == null
                    ? '—'
                    : '${stats.consumption!.toStringAsFixed(1).replaceAll('.', ',')} L',
                detail: stats.consumption == null ? 'Anota 2 repostajes con km' : 'cada 100 km',
              ),
              _StatTile(
                icon: Icons.local_gas_station_outlined,
                label: 'Precio medio pagado',
                value: stats.averagePrice == null ? '—' : formatPrice(stats.averagePrice!),
                detail: 'por litro',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Repostajes', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (garage.refuels.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: theme.colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(
                      'Tu diario está vacío',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Al repostar, abre la gasolinera en la app y pulsa «Anotar repostaje». '
                      'Así verás cuánto gastas y cuánto ahorras.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final e in garage.refuels) _RefuelTile(entry: e),
        ],
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({required this.car});

  final CarProfile? car;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = car;
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCarForm(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.directions_car_rounded, color: AppColors.ink, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c == null ? 'Configura tu coche' : c.fuel.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c == null
                          ? 'Combustible, depósito y consumo para calcular tu ahorro real'
                          : 'Depósito de ${formatLiters(c.tankLiters)} · '
                                '${c.consumption.toStringAsFixed(1).replaceAll('.', ',')} L/100 km',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(c == null ? Icons.chevron_right_rounded : Icons.edit_outlined, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: highlight ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefuelTile extends StatelessWidget {
  const _RefuelTile({required this.entry});

  final RefuelEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final garage = context.read<GarageController>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.expensive, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        onDismissed: (_) {
          garage.removeRefuel(entry.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Repostaje borrado'),
              action: SnackBarAction(label: 'Deshacer', onPressed: () => garage.addRefuel(entry)),
            ),
          );
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${entry.date.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        formatDay(entry.date).split(' ').last,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.stationName ?? 'Repostaje',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${formatLiters(entry.liters)} · ${formatPrice(entry.pricePerLiter)}/L'
                        '${entry.odometerKm != null ? ' · ${entry.odometerKm!.round()} km' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatEuros(entry.totalEuros),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (entry.saving.abs() >= 0.01)
                      Text(
                        entry.saving > 0
                            ? 'ahorro ${formatEuros(entry.saving)}'
                            : '${formatEuros(-entry.saving)} más',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: entry.saving > 0 ? AppColors.cheap : AppColors.expensive,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
