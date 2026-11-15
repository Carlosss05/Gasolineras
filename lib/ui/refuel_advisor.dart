import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/savings.dart';
import '../models/station.dart';
import '../state/stations_controller.dart';
import 'format.dart';
import 'garage_forms.dart';
import 'theme.dart';
import 'widgets/brand_badge.dart';
import 'widgets/price_change.dart';
import 'widgets/station_tile.dart';

/// Tarjeta destacada de la pantalla principal: la gasolinera a la que más
/// compensa ir contando el viaje (precio, distancia y consumo del coche) o,
/// sin ubicación, la más barata de la lista.
class BestOptionCard extends StatelessWidget {
  const BestOptionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final summary = c.summary;
    if (summary == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final rec = c.recommendation;
    final entry = rec?.best.entry ?? summary.cheapest;
    final Station s = entry.station;
    // Ámbar legible sobre blanco en modo claro.
    final priceColor = dark ? AppColors.amber : const Color(0xFFB86E00);
    final badgeColor = rec != null ? scheme.primary : (dark ? const Color(0xFFF5B841) : const Color(0xFFA35F00));
    final distance = entry.distanceKm;
    final change = c.priceChange(s.id, entry.price);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => showStationDetails(context, s, entry.distanceKm, fuel: c.fuel),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BrandBadge(brand: s.brand, size: 48),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              rec != null ? Icons.verified_rounded : Icons.emoji_events_rounded,
                              size: 14,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                rec != null ? 'TU MEJOR OPCIÓN' : 'LA MÁS BARATA',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // La distancia es corta y va a su tamaño; el rótulo
                            // se queda con todo el hueco restante.
                            if (distance != null)
                              Text(
                                ' · ${formatDistance(distance)}',
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.brand.isEmpty ? 'Sin marca' : s.brand,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${s.address} · ${s.municipality.split('/').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                          color: priceColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text('€/L', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      if (change != null) PriceChange(change: change),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      rec != null ? Icons.route_rounded : Icons.trending_down_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      rec != null ? _tripSummary(rec, scheme) : _averageSummary(summary, c.plan, scheme),
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.calculate_outlined, size: 20),
                      label: Text(
                        rec == null
                            ? '¿Me compensa ir?'
                            : c.planIsTypical
                            ? 'Ajustar a mi coche'
                            : 'Ver el cálculo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => showRefuelAdvisor(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 20),
                    label: const Text('Llévame'),
                    onPressed: () => openDirections(s),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Repostar 40 L aquí te sale por 66,85 € con el viaje: 2,10 € menos que
  /// en la más cercana."
  TextSpan _tripSummary(Recommendation rec, ColorScheme scheme) {
    const bold = TextStyle(fontWeight: FontWeight.w800);
    final saving = rec.savingVsNearest;
    return TextSpan(
      children: [
        TextSpan(text: 'Repostar ${formatLitersShort(rec.plan.liters)} aquí te sale por '),
        TextSpan(text: formatEuros(rec.best.total), style: bold),
        const TextSpan(text: ' con el viaje'),
        if (!rec.bestIsNearest && saving >= 0.05) ...[
          const TextSpan(text: ': '),
          TextSpan(
            text: '${formatEuros(saving)} menos',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: ' que en la más cercana.'),
        ] else if (rec.bestIsNearest && rec.bestIsCheapest)
          const TextSpan(text: '. Es la más barata y la más cercana.')
        else if (rec.bestIsNearest)
          const TextSpan(text: '. Además es la más cercana.')
        else
          const TextSpan(text: '.'),
      ],
    );
  }

  /// Sin ubicación: lo que se ahorra frente al precio medio de la zona.
  TextSpan _averageSummary(EntriesSummary summary, TripPlan plan, ColorScheme scheme) {
    final saving = (summary.average - summary.min) * plan.liters;
    if (saving < 0.5) return const TextSpan(text: 'Los precios de la zona son muy parecidos.');
    return TextSpan(
      children: [
        const TextSpan(text: 'Ahorras '),
        TextSpan(
          text: formatEuros(saving),
          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
        ),
        TextSpan(
          text:
              ' repostando ${formatLitersShort(plan.liters)} frente a la media '
              '(${formatPrice(summary.average)}/L)',
        ),
      ],
    );
  }
}

/// Hoja "¿Dónde reposto?": se ajustan los litros, el consumo y el tipo de
/// viaje, y se ve a qué gasolineras sale más barato ir, con las cuentas.
Future<void> showRefuelAdvisor(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _AdvisorSheet(),
  );
}

class _AdvisorSheet extends StatelessWidget {
  const _AdvisorSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = context.watch<StationsController>();
    final rec = c.recommendation;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Dónde reposto?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'La que mejor te sale contando el precio, lo lejos que está y lo que gasta tu coche en ir.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (rec == null)
              const _NeedLocation()
            else ...[
              const _PlanControls(),
              const SizedBox(height: 20),
              Text(
                'Las que mejor te salen · ${c.fuel.label}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ..._rows(rec),
              const SizedBox(height: 8),
              Text(
                'El viaje se estima con la distancia en línea recta × '
                '${roadFactor.toStringAsFixed(1).replaceAll('.', ',')} (lo que se rodea por carretera) y '
                'se paga al precio de cada gasolinera.',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Las mejores por coste total y, si no están entre ellas, la más cercana
  /// y la más barata, para poder compararlas.
  List<Widget> _rows(Recommendation rec) {
    final shown = {for (final cost in rec.ranking) cost.entry.station.id};
    final rows = [
      ...rec.ranking,
      if (shown.add(rec.nearest.entry.station.id)) rec.nearest,
      if (shown.add(rec.cheapest.entry.station.id)) rec.cheapest,
    ];
    return [
      for (final (i, cost) in rows.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CostRow(
            cost: cost,
            position: i < rec.ranking.length ? i + 1 : null,
            best: i == 0,
            nearest: cost.entry.station.id == rec.nearest.entry.station.id,
            cheapest: cost.entry.station.id == rec.cheapest.entry.station.id,
            extra: cost.total - rec.best.total,
          ),
        ),
    ];
  }
}

/// Litros a repostar, consumo del coche y si el viaje es de ida y vuelta.
class _PlanControls extends StatelessWidget {
  const _PlanControls();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = context.watch<StationsController>();
    final plan = c.plan;
    // Rangos cómodos de arrastrar que siempre incluyen el coche configurado.
    final maxLiters = (c.car?.tankLiters ?? 0) > 80 ? TripPlan.maxLiters : 80.0;
    final maxConsumption = plan.consumption > 15 ? TripPlan.maxConsumption : 15.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledSlider(
            label: 'Litros que vas a repostar',
            valueText: formatLitersShort(plan.liters),
            value: plan.liters.clamp(TripPlan.minLiters, maxLiters).toDouble(),
            min: TripPlan.minLiters,
            max: maxLiters,
            divisions: (maxLiters - TripPlan.minLiters).round(),
            onChanged: (v) => c.setPlan(liters: v),
          ),
          const SizedBox(height: 4),
          _LabeledSlider(
            label: 'Consumo de tu coche',
            valueText: formatConsumption(plan.consumption),
            value: plan.consumption.clamp(TripPlan.minConsumption, maxConsumption).toDouble(),
            min: TripPlan.minConsumption,
            max: maxConsumption,
            divisions: ((maxConsumption - TripPlan.minConsumption) * 10).round(),
            onChanged: (v) => c.setPlan(consumption: (v * 10).round() / 10),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.sync_alt_rounded), label: Text('Ida y vuelta')),
              ButtonSegment(value: false, icon: Icon(Icons.east_rounded), label: Text('Solo ida')),
            ],
            selected: {plan.roundTrip},
            onSelectionChanged: (s) => c.setPlan(roundTrip: s.first),
          ),
          if (c.planIsTypical) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Valores de un coche típico. Mueve los controles o guarda el tuyo.',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton(onPressed: () => showCarForm(context), child: const Text('Mi coche')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              valueText,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            // Sin margen lateral propio: alineado con los textos.
            padding: const EdgeInsets.symmetric(vertical: 10),
            showValueIndicator: ShowValueIndicator.never,
            tickMarkShape: SliderTickMarkShape.noTickMark,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            semanticFormatterCallback: (_) => valueText,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Una gasolinera de la comparación: lo que cuesta en total y su desglose.
class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.cost,
    required this.position,
    required this.best,
    required this.nearest,
    required this.cheapest,
    required this.extra,
  });

  final StationCost cost;

  /// Puesto por coste total; `null` si se añade solo para comparar.
  final int? position;
  final bool best;
  final bool nearest;
  final bool cheapest;

  /// Lo que cuesta de más que la mejor opción.
  final double extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = context.read<StationsController>();
    final entry = cost.entry;
    final Station s = entry.station;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return Material(
      color: best ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: best ? scheme.primary.withValues(alpha: 0.6) : scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showStationDetails(context, s, entry.distanceKm, fuel: c.fuel),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrandBadge(brand: s.brand, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${position == null ? '' : '$position. '}${s.brand.isEmpty ? 'Sin marca' : s.brand}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        // Distancia y precio primero: si no cabe, se corta el pueblo.
                        Text(
                          'a ${formatDistance(entry.distanceKm ?? 0)} · ${formatPriceNumber(entry.price)} €/L · '
                          '${s.municipality.split('/').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatEuros(cost.total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        best ? 'en total' : '+${formatEuros(extra)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: best ? scheme.onSurfaceVariant : PriceChange.colorFor(context, extra),
                          fontWeight: best ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Las cuentas, a todo el ancho para que se lean de un vistazo.
              Text(
                '${formatEuros(cost.fuelCost)} de combustible + ${formatEuros(cost.tripCost)} de viaje '
                '(${formatDistance(cost.tripKm)})',
                style: muted,
              ),
              if (best || nearest || cheapest) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (best) InfoPill(icon: Icons.verified_rounded, text: 'Mejor opción', color: scheme.primary),
                    if (cheapest) const InfoPill(icon: Icons.sell_outlined, text: 'Más barata'),
                    if (nearest) const InfoPill(icon: Icons.near_me, text: 'Más cercana'),
                  ],
                ),
              ],
              if (best) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: const Text('Llévame'),
                  onPressed: () => openDirections(s),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sin ubicación no se puede calcular el viaje: se explica y se ofrece activarla.
class _NeedLocation extends StatelessWidget {
  const _NeedLocation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = context.watch<StationsController>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.my_location_rounded, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            c.locating ? 'Buscando dónde estás…' : 'Necesito saber dónde estás',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Con tu ubicación calculo lo que cuesta ir a cada gasolinera y te digo cuál compensa. '
            'Solo se usa para medir distancias y saber en qué pueblo estás.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: c.locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
            label: const Text('Usar mi ubicación'),
            onPressed: c.locating ? null : c.retryLocation,
          ),
        ],
      ),
    );
  }
}
