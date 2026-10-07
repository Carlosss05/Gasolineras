import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/fuel_type.dart';
import '../models/station.dart';
import '../state/garage_controller.dart';
import '../state/stations_controller.dart';
import '../utils/text.dart';
import 'format.dart';
import 'widgets/brand_badge.dart';

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Formulario del coche: combustible, depósito y consumo.
Future<void> showCarForm(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CarForm(),
  );
}

class _CarForm extends StatefulWidget {
  const _CarForm();

  @override
  State<_CarForm> createState() => _CarFormState();
}

class _CarFormState extends State<_CarForm> {
  late FuelType _fuel;
  late final TextEditingController _tank;
  late final TextEditingController _consumption;

  @override
  void initState() {
    super.initState();
    final car = context.read<GarageController>().car;
    _fuel = car?.fuel ?? FuelType.gasolina95;
    _tank = TextEditingController(text: _fmt(car?.tankLiters ?? 50));
    _consumption = TextEditingController(text: _fmt(car?.consumption ?? 6.5));
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'.replaceAll('.', ',');

  @override
  void dispose() {
    _tank.dispose();
    _consumption.dispose();
    super.dispose();
  }

  double? get _tankValue => parseDecimal(_tank.text);
  double? get _consumptionValue => parseDecimal(_consumption.text);
  bool get _valid =>
      (_tankValue ?? 0) >= 10 &&
      (_tankValue ?? 0) <= 200 &&
      (_consumptionValue ?? 0) >= 2 &&
      (_consumptionValue ?? 0) <= 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mi coche', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Con estos datos la app calcula cuánto te cuesta llenar el depósito y si '
              'compensa ir a una gasolinera más lejana.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Text('Combustible', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in FuelType.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _fuel == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _fuel = f),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tank,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimal],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Depósito',
                      suffixText: 'L',
                      helperText: 'Entre 10 y 200',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _consumption,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimal],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Consumo',
                      suffixText: 'L/100 km',
                      helperText: 'Entre 2 y 30',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid
                  ? () {
                      context.read<GarageController>().setCar(
                        CarProfile(fuel: _fuel, tankLiters: _tankValue!, consumption: _consumptionValue!),
                      );
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario para anotar (o editar, con [existing]) un repostaje.
///
/// La gasolinera se elige de una lista de la zona actual; al elegir el
/// combustible se pone su precio, y con el precio el importe y los litros se
/// calculan uno a partir del otro.
Future<void> showRefuelForm(BuildContext context, {Station? station, FuelType? fuel, RefuelEntry? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RefuelForm(station: station, fuel: fuel, existing: existing),
  );
}

class _RefuelForm extends StatefulWidget {
  const _RefuelForm({this.station, this.fuel, this.existing});

  final Station? station;
  final FuelType? fuel;
  final RefuelEntry? existing;

  @override
  State<_RefuelForm> createState() => _RefuelFormState();
}

class _RefuelFormState extends State<_RefuelForm> {
  final _price = TextEditingController();
  final _liters = TextEditingController();
  final _total = TextEditingController();
  final _km = TextEditingController();
  final _name = TextEditingController();

  Station? _station;
  late FuelType _fuel;
  late DateTime _date;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final stations = context.read<StationsController>();
    _station = widget.station ?? _findStation(stations, e?.stationId);
    _fuel = widget.fuel ?? e?.fuel ?? context.read<GarageController>().car?.fuel ?? FuelType.gasolina95;
    _date = e?.date ?? DateTime.now();
    _name.text = e?.stationName ?? (_station == null ? '' : _stationLabel(_station!));

    if (e != null) {
      _price.text = _fmt(e.pricePerLiter, 3);
      _liters.text = _fmt(e.liters, 2);
      _total.text = _fmt(e.totalEuros, 2);
      if (e.odometerKm != null) _km.text = e.odometerKm!.round().toString();
    } else {
      _applyStationPrice();
    }
  }

  static Station? _findStation(StationsController c, String? id) {
    if (id == null) return null;
    for (final s in c.snapshot?.stations ?? const <Station>[]) {
      if (s.id == id) return s;
    }
    return null;
  }

  static String _stationLabel(Station s) => '${s.brand} · ${s.municipality.split('/').first}';

  static String _fmt(double v, int decimals) => v.toStringAsFixed(decimals).replaceAll('.', ',');

  @override
  void dispose() {
    for (final c in [_price, _liters, _total, _km, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pone el precio de la gasolinera elegida para el combustible elegido y
  /// recalcula importe/litros.
  void _applyStationPrice() {
    final p = _station?.prices[_fuel];
    if (p == null) return;
    _price.text = _fmt(p, 3);
    _recalcFromPrice();
  }

  double? get _priceValue => parseDecimal(_price.text);

  // Con el precio conocido, litros e importe se calculan uno a partir del otro.
  void _litersChanged(String v) {
    final l = parseDecimal(v), p = _priceValue;
    if (l != null && p != null && p > 0) _total.text = _fmt(l * p, 2);
    setState(() {});
  }

  void _totalChanged(String v) {
    final t = parseDecimal(v), p = _priceValue;
    if (t != null && p != null && p > 0) _liters.text = _fmt(t / p, 2);
    setState(() {});
  }

  /// Al cambiar el precio se mantiene el importe (lo que se suele saber del
  /// ticket) y se recalculan los litros; si aún no hay importe, al revés.
  void _recalcFromPrice() {
    final p = _priceValue;
    if (p == null || p <= 0) return;
    final t = parseDecimal(_total.text), l = parseDecimal(_liters.text);
    if (t != null && t > 0) {
      _liters.text = _fmt(t / p, 2);
    } else if (l != null && l > 0) {
      _total.text = _fmt(l * p, 2);
    }
  }

  bool get _valid => (parseDecimal(_liters.text) ?? 0) > 0 && (parseDecimal(_total.text) ?? 0) > 0;

  Future<void> _pickStation() async {
    final picked = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StationPicker(),
    );
    if (picked == null) return;
    setState(() {
      _station = picked;
      _name.text = _stationLabel(picked);
      // Si la gasolinera no vende el combustible elegido, se usa el primero que tenga.
      if (!picked.prices.containsKey(_fuel) && picked.prices.isNotEmpty) {
        _fuel = picked.prices.keys.first;
      }
      _applyStationPrice();
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    final garage = context.read<GarageController>();
    final stations = context.read<StationsController>();
    final previous = widget.existing;
    // La media de la zona solo se conoce al anotar; al editar se conserva,
    // salvo que cambie el combustible.
    final zoneAverage = previous != null && previous.fuel == _fuel
        ? previous.zoneAverage
        : stations.zoneAverageFor(_fuel);

    final entry = RefuelEntry(
      id: previous?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: _date,
      fuel: _fuel,
      liters: parseDecimal(_liters.text)!,
      totalEuros: parseDecimal(_total.text)!,
      stationId: _station?.id ?? previous?.stationId,
      stationName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      odometerKm: parseDecimal(_km.text),
      zoneAverage: zoneAverage,
    );
    if (previous == null) {
      garage.addRefuel(entry);
    } else {
      garage.updateRefuel(entry);
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text(previous == null ? 'Repostaje anotado en tu diario' : 'Repostaje actualizado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    InputDecoration deco(String label, {String? suffix, String? helper}) => InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: helper,
      border: const OutlineInputBorder(),
    );
    // Combustibles a elegir: los que vende la gasolinera (o todos si no hay).
    final fuels = _station == null || _station!.prices.isEmpty
        ? FuelType.values
        : FuelType.values.where(_station!.prices.containsKey).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing ? 'Editar repostaje' : 'Anotar repostaje',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // Gasolinera: se elige de la lista; el nombre se puede retocar.
            Material(
              color: scheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: _station == null
                    ? CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(Icons.local_gas_station_rounded, color: scheme.primary),
                      )
                    : BrandBadge(brand: _station!.brand, size: 40),
                title: Text(
                  _name.text.isEmpty ? 'Elegir gasolinera' : _name.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(_station == null ? 'De la lista de tu zona' : _station!.address, maxLines: 1),
                trailing: const Icon(Icons.expand_more_rounded),
                onTap: _pickStation,
              ),
            ),
            if (_station == null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: deco('O escribe el nombre (opcional)'),
              ),
            ],
            const SizedBox(height: 16),

            Text('Combustible', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in fuels)
                  ChoiceChip(
                    label: Text(
                      _station?.prices[f] == null
                          ? f.label
                          : '${f.label} · ${formatPriceNumber(_station!.prices[f]!)}',
                    ),
                    selected: _fuel == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _fuel = f;
                      _applyStationPrice();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimal],
              onChanged: (_) => setState(_recalcFromPrice),
              decoration: deco(
                'Precio',
                suffix: '€/L',
                helper: _station?.prices[_fuel] != null ? 'Precio de la gasolinera; puedes cambiarlo' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _total,
                    autofocus: !_editing,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimal],
                    onChanged: _totalChanged,
                    decoration: deco('Importe', suffix: '€'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _liters,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimal],
                    onChanged: _litersChanged,
                    decoration: deco('Litros', suffix: 'L'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _km,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: deco(
                'Kilómetros del coche (opcional)',
                suffix: 'km',
                helper: 'Llenando el depósito, la app calcula tu consumo real',
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(formatDay(_date)),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _valid ? _save : null,
              child: Text(_editing ? 'Guardar cambios' : 'Guardar repostaje'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de las gasolineras de la zona actual, con buscador, para elegir
/// dónde se ha repostado.
class _StationPicker extends StatefulWidget {
  const _StationPicker();

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.read<StationsController>();
    final q = normalize(_query.trim());
    final all = controller.nearbyStations();
    final visible = q.isEmpty ? all : all.where((e) => e.station.searchText.contains(q)).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '¿Dónde has repostado?',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Marca, calle o pueblo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Elige primero una zona en la pantalla principal para ver sus gasolineras.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final e = visible[i];
                      final s = e.station;
                      return ListTile(
                        leading: BrandBadge(brand: s.brand, size: 40),
                        title: Text(
                          s.brand.isEmpty ? 'Sin marca' : s.brand,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            '${s.address} · ${s.municipality.split('/').first}',
                            if (e.distanceKm != null) formatDistance(e.distanceKm!),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
