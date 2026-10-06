import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/region.dart';
import '../state/stations_controller.dart';
import '../utils/text.dart';

/// Hoja para elegir dónde buscar: mi provincia, otra provincia, una comunidad
/// autónoma o toda España.
Future<void> showScopePicker(BuildContext context) async {
  final controller = context.read<StationsController>();
  unawaited(controller.ensureRegions());

  final scope = await showModalBottomSheet<SearchScope>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final c = context.watch<StationsController>();
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Mi provincia'),
              subtitle: Text(
                c.myProvinceName != null
                    ? '${c.myProvinceName} · se actualiza al moverte'
                    : 'Activa la ubicación para detectarla',
              ),
              enabled: c.myProvinceId != null,
              onTap: () => Navigator.pop(
                context,
                SearchScope.myProvince(c.myProvinceId!, c.myProvinceName ?? c.myProvinceId!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Otra provincia'),
              onTap: () async {
                await c.ensureRegions();
                if (!context.mounted) return;
                final p = await _pick(context, 'Provincia', c.provinces, (p) => p.name);
                if (p != null && context.mounted) Navigator.pop(context, SearchScope.province(p.id, p.name));
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Comunidad autónoma'),
              onTap: () async {
                await c.ensureRegions();
                if (!context.mounted) return;
                final cc = await _pick(context, 'Comunidad autónoma', c.communities, (c) => c.name);
                if (cc != null && context.mounted) {
                  Navigator.pop(context, SearchScope.community(cc.id, cc.name));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Toda España'),
              subtitle: const Text('Unas 12.000 gasolineras; la descarga tarda algo más'),
              onTap: () => Navigator.pop(context, const SearchScope.spain()),
            ),
          ],
        ),
      );
    },
  );

  if (scope != null) await controller.setScope(scope);
}

Future<T?> _pick<T>(BuildContext context, String title, List<T> items, String Function(T) nameOf) {
  if (items.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se ha podido cargar el listado. Revisa tu conexión.')));
    return Future.value();
  }
  return Navigator.push<T>(
    context,
    MaterialPageRoute(
      builder: (_) => _RegionListPage<T>(title: title, items: items, nameOf: nameOf),
    ),
  );
}

class _RegionListPage<T> extends StatefulWidget {
  const _RegionListPage({required this.title, required this.items, required this.nameOf});

  final String title;
  final List<T> items;
  final String Function(T) nameOf;

  @override
  State<_RegionListPage<T>> createState() => _RegionListPageState<T>();
}

class _RegionListPageState<T> extends State<_RegionListPage<T>> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final f = normalize(_filter);
    final visible = widget.items.where((i) => normalize(widget.nameOf(i)).contains(f)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(widget.nameOf(visible[i])),
                onTap: () => Navigator.pop(context, visible[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
