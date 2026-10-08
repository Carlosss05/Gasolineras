import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/region.dart';
import '../state/stations_controller.dart';
import '../utils/text.dart';

/// Hoja para elegir dónde buscar, al estilo de Material 3: arriba las zonas
/// que siguen tu ubicación (mi pueblo, mi provincia) y debajo el resto
/// (otra provincia, una comunidad autónoma o toda España).
Future<void> showScopePicker(BuildContext context) async {
  final controller = context.read<StationsController>();
  unawaited(controller.ensureRegions());

  final scope = await showModalBottomSheet<SearchScope>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ScopeSheet(),
  );

  if (scope != null) await controller.chooseScope(scope);
}

class _ScopeSheet extends StatelessWidget {
  const _ScopeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = context.watch<StationsController>();
    final current = c.scope;
    final hasTown = c.myTownId != null && c.myProvinceId != null;
    final hasProvince = c.myProvinceId != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Dónde buscas?',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Elige de qué zona quieres ver los precios.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            const _SectionLabel('Cerca de ti'),
            const SizedBox(height: 10),
            if (hasProvince)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _NearbyCard(
                        icon: Icons.home_rounded,
                        title: 'Mi pueblo',
                        subtitle: hasTown ? c.myTownName ?? '' : 'No detectado',
                        selected: current?.kind == ScopeKind.myTown,
                        onTap: hasTown
                            ? () => Navigator.pop(
                                context,
                                SearchScope.myTown(c.myProvinceId!, c.myTownId!, c.myTownName ?? c.myTownId!),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NearbyCard(
                        icon: Icons.my_location_rounded,
                        title: 'Mi provincia',
                        subtitle: c.myProvinceName ?? '',
                        selected: current?.kind == ScopeKind.myProvince,
                        onTap: () => Navigator.pop(
                          context,
                          SearchScope.myProvince(c.myProvinceId!, c.myProvinceName ?? c.myProvinceId!),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _LocationOffCard(locating: c.locating, onEnable: c.retryLocation),
            if (hasProvince) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.sync_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cambian solas cuando te mueves.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            const _SectionLabel('Otras zonas'),
            const SizedBox(height: 10),
            _Group(
              children: [
                _ZoneTile(
                  icon: Icons.map_rounded,
                  title: 'Otra provincia',
                  subtitle: current?.kind == ScopeKind.province ? current!.name : 'Las 52 provincias',
                  selected: current?.kind == ScopeKind.province,
                  onTap: () async {
                    await c.ensureRegions();
                    if (!context.mounted) return;
                    final p = await _pick(
                      context,
                      title: 'Provincia',
                      items: c.provinces,
                      nameOf: (p) => p.name,
                      isSelected: (p) => current?.kind == ScopeKind.province && current!.id == p.id,
                    );
                    if (p != null && context.mounted) {
                      Navigator.pop(context, SearchScope.province(p.id, p.name));
                    }
                  },
                ),
                _ZoneTile(
                  icon: Icons.layers_rounded,
                  title: 'Comunidad autónoma',
                  subtitle: current?.kind == ScopeKind.community
                      ? current!.name
                      : 'Las 17 comunidades, Ceuta y Melilla',
                  selected: current?.kind == ScopeKind.community,
                  onTap: () async {
                    await c.ensureRegions();
                    if (!context.mounted) return;
                    final cc = await _pick(
                      context,
                      title: 'Comunidad autónoma',
                      items: c.communities,
                      nameOf: (c) => c.name,
                      isSelected: (cc) => current?.kind == ScopeKind.community && current!.id == cc.id,
                    );
                    if (cc != null && context.mounted) {
                      Navigator.pop(context, SearchScope.community(cc.id, cc.name));
                    }
                  },
                ),
                _ZoneTile(
                  icon: Icons.public_rounded,
                  title: 'Toda España',
                  subtitle: 'Unas 12.000 gasolineras · tarda algo más',
                  selected: current?.kind == ScopeKind.spain,
                  showChevron: false,
                  onTap: () => Navigator.pop(context, const SearchScope.spain()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Tarjeta seleccionable de "Mi pueblo" / "Mi provincia".
class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected ? scheme.primary : scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: selected ? scheme.onPrimary : scheme.primary),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sin ubicación: explica para qué sirve y ofrece activarla.
class _LocationOffCard extends StatelessWidget {
  const _LocationOffCard({required this.locating, required this.onEnable});

  final bool locating;
  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: locating
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
                  )
                : Icon(Icons.location_off_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locating ? 'Buscando tu ubicación…' : 'Ubicación desactivada',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Actívala para ver las gasolineras de tu pueblo y ordenar por cercanía.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (!locating) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Activar ubicación'),
                    onPressed: onEnable,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de filas con esquinas redondeadas, como en los Ajustes de Android.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: selected ? scheme.onPrimary : scheme.primary),
      ),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : null,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : showChevron
          ? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant)
          : null,
    );
  }
}

Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) nameOf,
  required bool Function(T) isSelected,
}) {
  if (items.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se ha podido cargar el listado. Revisa tu conexión.')));
    return Future.value();
  }
  return Navigator.push<T>(
    context,
    MaterialPageRoute<T>(
      builder: (_) => _RegionListPage<T>(title: title, items: items, nameOf: nameOf, isSelected: isSelected),
    ),
  );
}

/// Lista de provincias o comunidades: buscador en píldora y agrupada por
/// letra, con la zona actual marcada.
class _RegionListPage<T> extends StatefulWidget {
  const _RegionListPage({
    required this.title,
    required this.items,
    required this.nameOf,
    required this.isSelected,
  });

  final String title;
  final List<T> items;
  final String Function(T) nameOf;
  final bool Function(T) isSelected;

  @override
  State<_RegionListPage<T>> createState() => _RegionListPageState<T>();
}

class _RegionListPageState<T> extends State<_RegionListPage<T>> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = normalize(_filter.trim());
    final visible = widget.items.where((i) => normalize(widget.nameOf(i)).contains(f)).toList()
      ..sort((a, b) => normalize(widget.nameOf(a)).compareTo(normalize(widget.nameOf(b))));

    // Filas: cabecera de letra + elementos.
    final rows = <Object>[];
    String? letter;
    for (final item in visible) {
      final l = normalize(widget.nameOf(item)).characters.first.toUpperCase();
      if (l != letter) {
        rows.add(l);
        letter = l;
      }
      rows.add(item as Object);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              autoFocus: true,
              hintText: 'Buscar ${widget.title.toLowerCase()}',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(scheme.surface),
              side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
        ),
      ),
      body: rows.isEmpty
          ? Center(
              child: Text(
                'Ningún resultado para "$_filter"',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is String) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Text(
                      row,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                final item = row as T;
                final name = widget.nameOf(item);
                final selected = widget.isSelected(item);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: selected ? scheme.primary : scheme.primaryContainer,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: selected ? FontWeight.w700 : null),
                  ),
                  trailing: selected ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
    );
  }
}
