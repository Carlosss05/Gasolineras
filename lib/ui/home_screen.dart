import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../logic/savings.dart';
import '../models/car.dart';
import '../platform/web_diagnostics.dart';
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

/// A partir de cuánto desplazamiento la cabecera grande deja paso a la barra mínima.
const _collapseOffset = 120.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showMap = false;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _collapsed = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncCollapsed);
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  void _syncCollapsed() {
    _collapsed.value = _scroll.hasClients && _scroll.offset > _collapseOffset;
  }

  void _toggleMap() {
    setState(() => _showMap = !_showMap);
    // La lista puede volver a la posición en la que estaba.
    _collapsed.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncCollapsed();
    });
  }

  /// Desde la barra mínima: vuelve arriba y abre el buscador.
  Future<void> _openSearch() async {
    if (_scroll.hasClients && _scroll.offset > 0) {
      await _scroll.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
    if (mounted) _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final header = _Header(search: _search, focus: _searchFocus, showMap: _showMap, onToggleMap: _toggleMap);
    return Scaffold(
      body: _showMap
          ? _MapView(header: header)
          : Stack(
              children: [
                _StationList(controller: _scroll, header: header),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _collapsed,
                    builder: (context, collapsed, _) =>
                        _CollapsedBar(visible: collapsed, onSearch: _openSearch, onToggleMap: _toggleMap),
                  ),
                ),
              ],
            ),
    );
  }
}

void _openFavorites(BuildContext context) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()));
}

void _openGarage(BuildContext context) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const GarageScreen()));
}

/// Cabecera compacta: marca y accesos, y el buscador con la zona dentro. Va
/// dentro de la lista y se desplaza con ella; al bajar la sustituye
/// [_CollapsedBar].
class _Header extends StatelessWidget {
  const _Header({required this.search, required this.focus, required this.showMap, required this.onToggleMap});

  final TextEditingController search;
  final FocusNode focus;
  final bool showMap;
  final VoidCallback onToggleMap;

  /// Alto total: fila de 44 + buscador de 50 + márgenes, más la barra de
  /// estado y la de recarga. El mapa lo usa para saber qué parte queda tapada.
  static double heightOf(BuildContext context, {required bool refreshing}) =>
      MediaQuery.paddingOf(context).top + 128 + (refreshing ? 13 : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.watch<StationsController>();
    final refreshing = c.loading && c.snapshot != null;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    // Mantener pulsado el logo abre el panel de diagnóstico de pantalla (web).
                    GestureDetector(onLongPress: showWebDiagnostics, child: const AppLogo(size: 36)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gasolineras',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    _HeaderButton(
                      tooltip: showMap ? 'Ver lista' : 'Ver mapa',
                      icon: showMap ? Icons.view_agenda_outlined : Icons.map_outlined,
                      selected: showMap,
                      onPressed: onToggleMap,
                    ),
                    const SizedBox(width: 4),
                    _HeaderButton(
                      tooltip: 'Favoritas',
                      icon: Icons.star_outline_rounded,
                      onPressed: () => _openFavorites(context),
                    ),
                    const SizedBox(width: 4),
                    _HeaderButton(
                      tooltip: 'Mi coche',
                      icon: Icons.directions_car_outlined,
                      onPressed: () => _openGarage(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _SearchField(controller: search, focus: focus),
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

/// Buscador blanco con la zona elegida a la derecha.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  static const _muted = Color(0xFF5F6F67);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.read<StationsController>();

    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 14, right: 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.emeraldDeep, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onChanged: c.setQuery,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.emeraldDeep,
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Pueblo, marca o CP',
                hintMaxLines: 1,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(color: _muted),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Borrar',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, color: _muted),
                    onPressed: () {
                      controller.clear();
                      c.setQuery('');
                    },
                  ),
          ),
          const SizedBox(width: 4),
          const _ZoneChip(),
        ],
      ),
    );
  }
}

/// Zona en la que se busca; al tocarla se elige otra.
class _ZoneChip extends StatelessWidget {
  const _ZoneChip();

  static const _ink = Color(0xFF0A6B44);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = context.select<StationsController, SearchScope?>((c) => c.scope);

    return Tooltip(
      message: 'Cambiar zona',
      child: Material(
        color: const Color(0xFFE3F3EA),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showScopePicker(context),
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scope?.followsLocation ?? false ? Icons.my_location : Icons.place_outlined,
                    size: 15,
                    color: _ink,
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      scope?.label ?? 'Elegir zona',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(color: _ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18, color: _ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.tooltip, required this.icon, required this.onPressed, this.selected = false});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
      ),
      iconSize: 21,
      icon: Icon(icon, color: selected ? AppColors.emeraldDeep : Colors.white),
    );
  }
}

/// Barra mínima que aparece al bajar por la lista: zona, combustible y orden,
/// y accesos al buscador y al mapa.
class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({required this.visible, required this.onSearch, required this.onToggleMap});

  final bool visible;
  final VoidCallback onSearch;
  final VoidCallback onToggleMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.watch<StationsController>();
    final sort = switch (c.sort) {
      SortMode.price => 'Más baratas',
      SortMode.distance => 'Más cercanas',
      SortMode.value => 'Más rentables',
    };

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1.1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Color(0x59000000), blurRadius: 22, offset: Offset(0, 8))],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                child: Row(
                  children: [
                    const AppLogo(size: 32),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Tooltip(
                        message: 'Cambiar zona',
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => showScopePicker(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: SizedBox(
                                height: 44,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            c.scope?.label ?? 'Gasolineras',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.expand_more_rounded, size: 18, color: Colors.white),
                                      ],
                                    ),
                                    Text(
                                      '${c.fuel.label} · $sort',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _HeaderButton(tooltip: 'Buscar', icon: Icons.search_rounded, onPressed: onSearch),
                    const SizedBox(width: 4),
                    _HeaderButton(tooltip: 'Ver mapa', icon: Icons.map_outlined, onPressed: onToggleMap),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinta verde por encima de la cabecera para que, al estirar la lista hacia
/// abajo (rebote de iOS), no asome el fondo por arriba.
class _OverscrollFill extends StatelessWidget {
  const _OverscrollFill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: -600,
          height: 640,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.emeraldDeep, Color(0xFF0C7356)])),
          ),
        ),
        child,
      ],
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
                style: TextStyle(color: AppColors.ink, fontSize: size * 0.2, fontWeight: FontWeight.w800, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Combustibles en una fila desplazable. Con [floating] va sobre el mapa, con
/// sombra y aire para ella.
class FuelChipsRow extends StatelessWidget {
  const FuelChipsRow({super.key, this.floating = false});

  final bool floating;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    return SizedBox(
      height: floating ? 50 : 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: floating ? 6 : 0),
        itemCount: FuelType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final fuel = FuelType.values[i];
          return _FuelChip(
            label: fuel.label,
            selected: c.fuel == fuel,
            floating: floating,
            onTap: () => c.setFuel(fuel),
          );
        },
      ),
    );
  }
}

/// Combustible y orden. Se usa en Favoritas.
class FiltersBar extends StatelessWidget {
  const FiltersBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FuelChipsRow(),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _sortHints(context, c)),
          ),
        ],
      ),
    );
  }
}

/// Avisos bajo el selector de orden: falta la ubicación, o qué es "Rentables".
List<Widget> _sortHints(BuildContext context, StationsController c) {
  final theme = Theme.of(context);
  return [
    if (c.sort != SortMode.price && c.position == null)
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          c.sort == SortMode.distance
              ? 'Activa la ubicación para ordenar por cercanía.'
              : 'Activa la ubicación para calcular el coste del viaje.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      ),
    if (c.sort == SortMode.value && c.position != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          'Ordenadas por lo que te cuesta llenar el depósito, incluido el viaje de ida y vuelta.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
  ];
}

class _FuelChip extends StatelessWidget {
  const _FuelChip({required this.label, required this.selected, required this.onTap, this.floating = false});

  final String label;
  final bool selected;
  final bool floating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      elevation: floating ? 3 : 0,
      shadowColor: Colors.black54,
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

/// Selector compacto del orden de la lista, junto al número de resultados.
class _SortToggle extends StatelessWidget {
  const _SortToggle({this.expand = false});

  /// Ocupa todo el ancho, con las opciones repartidas.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final scheme = Theme.of(context).colorScheme;
    final options = <(SortMode, IconData, String)>[
      (SortMode.price, Icons.sell_outlined, 'Baratas'),
      (SortMode.distance, Icons.near_me_outlined, 'Cerca'),
      if (c.car != null) (SortMode.value, Icons.auto_graph_rounded, 'Rentables'),
    ];

    return Semantics(
      container: true,
      label: 'Ordenar',
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: ShapeDecoration(
          color: scheme.surface,
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (mode, icon, label) in options)
              if (expand)
                Expanded(
                  child: _SortOption(
                    icon: icon,
                    label: label,
                    selected: c.sort == mode,
                    expand: true,
                    onTap: () => c.setSort(mode),
                  ),
                )
              else
                _SortOption(icon: icon, label: label, selected: c.sort == mode, onTap: () => c.setSort(mode)),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                if (expand) Flexible(child: text) else text,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mapa hasta el borde de la pantalla, por debajo de la cabecera y de los
/// combustibles, que flotan encima.
class _MapView extends StatelessWidget {
  const _MapView({required this.header});

  final Widget header;

  /// Parte del mapa que queda bajo las esquinas redondeadas de la cabecera.
  static const _underHeader = 26.0;

  /// Alto de la fila de combustibles sobre el mapa (con aire para la sombra).
  static const _chipsHeight = 50.0;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final status = _statusView(context, c);
    final headerHeight = _Header.heightOf(context, refreshing: c.loading && c.snapshot != null);
    const covered = _underHeader + 4 + _chipsHeight;
    final pos = c.position;

    return Stack(
      children: [
        Positioned.fill(
          top: headerHeight - _underHeader,
          child: status != null
              ? SingleChildScrollView(
                  padding: EdgeInsets.only(top: covered, bottom: MediaQuery.paddingOf(context).bottom),
                  child: status,
                )
              : StationsMap(
                  // Al cambiar de zona o combustible se vuelve a encuadrar el mapa.
                  key: ValueKey('${c.scope!.cacheKey}-${c.scope!.townId}-${c.fuel.name}-${c.query}'),
                  entries: c.entries,
                  userLocation: pos == null ? null : LatLng(pos.latitude, pos.longitude),
                  sort: c.sort,
                  topInset: covered,
                ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: header),
        Positioned(top: headerHeight + 4, left: 0, right: 0, child: const FuelChipsRow(floating: true)),
      ],
    );
  }
}

/// Mensaje para los estados sin datos (sin zona, descargando, error, sin
/// resultados) o `null` si hay gasolineras que mostrar. No desplaza por sí
/// mismo: va dentro de la lista (o del hueco del mapa).
Widget? _statusView(BuildContext context, StationsController c) {
  if (c.scope == null) {
    // Sin zona todavía, pero ya se puede buscar un pueblo o CP directamente.
    final places = c.placeSuggestions;
    if (places.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: _PlaceSuggestions(places: places),
      );
    }
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
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
          ? FilledButton(onPressed: c.useMyProvince, child: Text('Ver toda la provincia de ${c.myProvinceName}'))
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

/// La lista entera se desplaza, cabecera incluida, y llega hasta el borde de
/// abajo (por detrás de la barra de Safari o del indicador de inicio).
class _StationList extends StatelessWidget {
  const _StationList({required this.controller, required this.header});

  final ScrollController controller;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StationsController>();
    final status = _statusView(context, c);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: c.refresh,
      edgeOffset: MediaQuery.paddingOf(context).top,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _OverscrollFill(child: header)),
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.only(top: 14, bottom: 2), child: FuelChipsRow()),
          ),
          if (status != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Center(child: status),
              ),
            )
          else ...[
            ..._results(context, c),
            // Margen final: que la última no quede bajo la barra de Safari o el indicador de inicio.
            SliverToBoxAdapter(child: SizedBox(height: 24 + bottom)),
          ],
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context, StationsController c) {
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

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (places.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('En otras zonas', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              _PlaceSuggestions(places: places),
            ],
            if (entries.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _BestDealCard(
                  entry: cheapest,
                  average: average,
                  fuel: c.fuel,
                  car: garage.car,
                  worthIt: garage.car == null ? null : compareCheapestWithNearest(entries, garage.car!),
                ),
              ),
            if (garage.loaded && garage.car == null)
              const Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 0), child: _CarPrompt()),
            _ListHeader(count: entries.length, publishedAt: snapshot.publishedAt),
          ],
        ),
      ),
      SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
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
    ];
  }
}

/// Número de resultados, hora de los precios y orden de la lista.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count, required this.publishedAt});

  final int count;
  final DateTime? publishedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.watch<StationsController>();
    final published = publishedAt;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count gasolineras', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (published != null)
          Text(
            'Precios de ${formatPublished(published)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Con dos opciones cabe al lado del número; con "Rentables", debajo.
              if (c.car == null && constraints.maxWidth >= 330) {
                return Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    const _SortToggle(),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [info, const SizedBox(height: 10), const _SortToggle(expand: true)],
              );
            },
          ),
          ..._sortHints(context, c),
        ],
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
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final Station s = entry.station;
    final tankLiters = car?.tankLiters ?? _defaultTankLiters;
    final saving = (average - entry.price) * tankLiters;
    final litersText = formatLiters(tankLiters).replaceAll(',0 L', ' L');
    // Ámbar legible sobre blanco en modo claro.
    final priceColor = dark ? AppColors.amber : const Color(0xFFB86E00);
    final badgeColor = dark ? const Color(0xFFF5B841) : const Color(0xFFA35F00);
    final distance = entry.distanceKm;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => showStationDetails(context, s, entry.distanceKm, fuel: fuel),
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
                            Icon(Icons.emoji_events_rounded, size: 14, color: badgeColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'LA MÁS BARATA',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (distance != null)
                              Flexible(
                                child: Text(
                                  ' · ${formatDistance(distance)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                    ],
                  ),
                ],
              ),
              if (worthIt != null) ...[const SizedBox(height: 12), _WorthItBox(result: worthIt!)],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.trending_down_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      saving >= 0.5
                          ? TextSpan(
                              children: [
                                const TextSpan(text: 'Ahorras '),
                                TextSpan(
                                  text: formatEuros(saving),
                                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: ' llenando $litersText frente a la media (${formatPrice(average)}/L)'),
                              ],
                            )
                          : const TextSpan(text: 'Los precios de la zona son muy parecidos.'),
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 12),
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
}

/// "¿Merece la pena ir?": ahorro en combustible frente a la gasolinera más
/// cercana, menos lo que cuesta de más el viaje.
class _WorthItBox extends StatelessWidget {
  const _WorthItBox({required this.result});

  final WorthIt result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final ok = result.worthIt;
    final accent = ok ? scheme.primary : (dark ? const Color(0xFFFF8A80) : const Color(0xFFC23B3B));
    final nearest = result.nearest;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.thumb_up_alt_rounded : Icons.do_not_disturb_on_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? '¿Merece la pena ir? Sí: ahorras ${formatEuros(result.netSaving)}'
                      : '¿Merece la pena ir? No, mejor la más cercana',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
    return Material(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: () => showCarForm(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
            child: Row(
              children: [
                Icon(Icons.directions_car_filled_rounded, color: scheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Configura tu coche y te decimos si compensa el viaje',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.text, this.busy = false, this.action, this.secondary});

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
    return Padding(
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
    );
  }
}
