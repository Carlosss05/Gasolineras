import 'package:flutter/material.dart';

/// Siluetas de la lista mientras llegan los primeros precios: se ve la forma
/// de lo que va a aparecer en vez de una pantalla vacía con un círculo.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.items = 6});

  final int items;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quien pide menos movimiento en su móvil ve las siluetas quietas.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = scheme.onSurface.withValues(alpha: 0.08);

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(height / 2)),
    );

    return Semantics(
      label: 'Cargando precios',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.45).animate(_pulse),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                // Tarjeta destacada.
                Container(
                  height: 168,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(13)),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [bar(96, 10), const SizedBox(height: 8), bar(150, 14)],
                            ),
                          ),
                          bar(70, 26),
                        ],
                      ),
                      const Spacer(),
                      bar(double.infinity, 10),
                      const SizedBox(height: 8),
                      bar(180, 10),
                      const Spacer(),
                      bar(double.infinity, 40),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < widget.items; i++)
                  Container(
                    height: 84,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(13)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [bar(120, 13), const SizedBox(height: 9), bar(190, 10)],
                          ),
                        ),
                        bar(58, 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
