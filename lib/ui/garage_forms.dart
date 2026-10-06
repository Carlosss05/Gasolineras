import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/fuel_type.dart';
import '../models/station.dart';
import '../state/garage_controller.dart';
import 'format.dart';

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

/// Formulario para anotar un repostaje. Si viene de una gasolinera, se
/// rellenan el nombre, el combustible y el precio, y se guarda la media de la
/// zona para calcular el ahorro.
Future<void> showRefuelForm(
  BuildContext context, {
  Station? station,
  FuelType? fuel,
  double? price,
  double? zoneAverage,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RefuelForm(station: station, fuel: fuel, price: price, zoneAverage: zoneAverage),
  );
}

class _RefuelForm extends StatefulWidget {
  const _RefuelForm({this.station, this.fuel, this.price, this.zoneAverage});

  final Station? station;
  final FuelType? fuel;
  final double? price;
  final double? zoneAverage;

  @override
  State<_RefuelForm> createState() => _RefuelFormState();
}

class _RefuelFormState extends State<_RefuelForm> {
  final _liters = TextEditingController();
  final _total = TextEditingController();
  final _km = TextEditingController();
  final _name = TextEditingController();
  late FuelType _fuel;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final car = context.read<GarageController>().car;
    _fuel = widget.fuel ?? car?.fuel ?? FuelType.gasolina95;
    _name.text = widget.station == null
        ? ''
        : '${widget.station!.brand} · ${widget.station!.municipality.split('/').first}';
  }

  @override
  void dispose() {
    for (final c in [_liters, _total, _km, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  // Con el precio conocido, litros y euros se calculan uno a partir del otro.
  void _litersChanged(String v) {
    final l = parseDecimal(v);
    if (widget.price != null && l != null) _total.text = (l * widget.price!).toStringAsFixed(2);
    setState(() {});
  }

  void _totalChanged(String v) {
    final t = parseDecimal(v);
    if (widget.price != null && t != null) _liters.text = (t / widget.price!).toStringAsFixed(2);
    setState(() {});
  }

  bool get _valid => (parseDecimal(_liters.text) ?? 0) > 0 && (parseDecimal(_total.text) ?? 0) > 0;

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
    final km = parseDecimal(_km.text);
    context.read<GarageController>().addRefuel(
      RefuelEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: _date,
        fuel: _fuel,
        liters: parseDecimal(_liters.text)!,
        totalEuros: parseDecimal(_total.text)!,
        stationId: widget.station?.id,
        stationName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        odometerKm: km,
        zoneAverage: widget.zoneAverage,
      ),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Repostaje anotado en tu diario')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration deco(String label, {String? suffix, String? helper}) => InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: helper,
      border: const OutlineInputBorder(),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Anotar repostaje',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (widget.price != null)
              Text(
                '${_fuel.label} a ${formatPrice(widget.price!)}/L',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: deco('Gasolinera (opcional)')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _liters,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimal],
                    onChanged: _litersChanged,
                    decoration: deco('Litros', suffix: 'L'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimal],
                    onChanged: _totalChanged,
                    decoration: deco('Importe', suffix: '€'),
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
            FilledButton(onPressed: _valid ? _save : null, child: const Text('Guardar repostaje')),
          ],
        ),
      ),
    );
  }
}
