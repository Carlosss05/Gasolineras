import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../state/stations_controller.dart';
import 'format.dart';
import 'widgets/brand_badge.dart';
import 'widgets/station_tile.dart';

/// Mapa con las gasolineras de [entries], ya filtradas y ordenadas.
///
/// Para que vaya fluido incluso con toda España (~12.000 estaciones) solo se
/// pintan las [maxMarkers] primeras que caen dentro de la zona visible; como
/// [entries] viene ordenada, son las más baratas (o las más cercanas).
class StationsMap extends StatefulWidget {
  const StationsMap({super.key, required this.entries, required this.userLocation, required this.sort});

  final List<StationEntry> entries;
  final LatLng? userLocation;
  final SortMode sort;

  static const maxMarkers = 150;

  /// Cuántas etiquetas caben sin amontonarse según el zoom: pocas con la
  /// provincia entera a la vista, todas al acercarse a un pueblo.
  static int markersForZoom(double zoom) => zoom < 9
      ? 25
      : zoom < 10.5
      ? 40
      : zoom < 12
      ? 70
      : zoom < 13.5
      ? 110
      : maxMarkers;

  @override
  State<StationsMap> createState() => _StationsMapState();
}

class _StationsMapState extends State<StationsMap> {
  final _controller = MapController();
  LatLngBounds? _visible;
  double _zoom = 6;
  Timer? _debounce;

  static LatLng _point(StationEntry e) => LatLng(e.station.latitude, e.station.longitude);

  CameraFit get _fitAll {
    final points = widget.entries.map(_point).toList();
    if (points.length == 1) return CameraFit.coordinates(coordinates: points, maxZoom: 15);
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
      maxZoom: 15,
    );
  }

  void _onCameraChanged(MapCamera camera, bool hasGesture) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _visible = camera.visibleBounds;
          _zoom = camera.zoom;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = _visible;

    final limit = StationsMap.markersForZoom(_zoom);
    final inView = <StationEntry>[];
    var truncated = false;
    for (final e in widget.entries) {
      if (bounds != null && !bounds.contains(_point(e))) continue;
      if (inView.length == limit) {
        truncated = true;
        break;
      }
      inView.add(e);
    }

    final prices = inView.map((e) => e.price);
    final minPrice = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);
    final user = widget.userLocation;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: widget.entries.isEmpty ? null : _fitAll,
            initialCenter: user ?? const LatLng(40.2, -3.7),
            initialZoom: 6,
            minZoom: 4,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: _onCameraChanged,
            onMapReady: () => setState(() {
              _visible = _controller.camera.visibleBounds;
              _zoom = _controller.camera.zoom;
            }),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'es.carlosss05.gasolineras',
            ),
            MarkerLayer(
              markers: [
                // Las más caras primero para que las baratas queden encima.
                for (final e in inView.reversed)
                  Marker(
                    point: _point(e),
                    width: 92,
                    height: 34,
                    alignment: Alignment.topCenter,
                    child: _PriceMarker(
                      brand: e.station.brand,
                      price: e.price,
                      color: priceColor(e.price, minPrice, maxPrice),
                      isBest: identical(e, inView.first) && widget.sort == SortMode.price,
                      onTap: () => showStationDetails(context, e.station, e.distanceKm),
                    ),
                  ),
                if (user != null) Marker(point: user, width: 22, height: 22, child: const _UserDot()),
              ],
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                ),
                TextSourceAttribution(
                  'CARTO',
                  onTap: () => launchUrl(Uri.parse('https://carto.com/attributions')),
                ),
              ],
            ),
          ],
        ),
        if (truncated)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                elevation: 3,
                shadowColor: Colors.black26,
                shape: const StadiumBorder(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.sort == SortMode.price
                              ? 'Las $limit más baratas · acerca para ver más'
                              : 'Las $limit más cercanas · acerca para ver más',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 24,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'fit',
                tooltip: 'Ver todas',
                onPressed: widget.entries.isEmpty ? null : () => _controller.fitCamera(_fitAll),
                child: const Icon(Icons.zoom_out_map),
              ),
              if (user != null) ...[
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'me',
                  tooltip: 'Mi ubicación',
                  onPressed: () => _controller.move(user, 14),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Etiqueta con el precio y un piquito que apunta a la gasolinera.
class _PriceMarker extends StatelessWidget {
  const _PriceMarker({
    required this.brand,
    required this.price,
    required this.color,
    required this.isBest,
    required this.onTap,
  });

  final String brand;

  final double price;
  final Color color;
  final bool isBest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(3, 3, 6, 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: isBest ? 2.5 : 1.5),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandBadge(brand: brand, size: 18),
                const SizedBox(width: 4),
                if (isBest) const Icon(Icons.emoji_events, size: 12, color: Colors.white),
                Text(
                  formatPrice(price).replaceAll(' €', ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(size: const Size(10, 6), painter: _ArrowPainter(color)),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
    );
  }
}
