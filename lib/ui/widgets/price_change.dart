import 'package:flutter/material.dart';

import '../../logic/price_trend.dart';
import '../format.dart';

/// Cuánto ha subido o bajado un precio: flecha y céntimos, en verde si baja
/// y en rojo si sube (la flecha lo dice también sin color).
class PriceChange extends StatelessWidget {
  const PriceChange({super.key, required this.change, this.style, this.showUnchanged = false});

  /// Diferencia en €/L (positiva: ha subido).
  final double change;

  final TextStyle? style;

  /// Si no ha cambiado, escribe "Igual" en vez de no mostrar nada.
  final bool showUnchanged;

  /// Color de una subida o bajada, legible en modo claro y oscuro.
  static Color colorFor(BuildContext context, double change) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (change.abs() < priceChangeEpsilon) return Theme.of(context).colorScheme.onSurfaceVariant;
    return change < 0
        ? (dark ? const Color(0xFF3DD68C) : const Color(0xFF0A7A4D))
        : (dark ? const Color(0xFFFF8A80) : const Color(0xFFC23B3B));
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.labelSmall;
    final color = colorFor(context, change);
    final textStyle = base?.copyWith(color: color, fontWeight: FontWeight.w800);
    if (change.abs() < priceChangeEpsilon) {
      return showUnchanged ? Text('Igual', style: textStyle) : const SizedBox.shrink();
    }
    final cents = formatCents(change);
    return Semantics(
      label: change < 0 ? 'Ha bajado $cents' : 'Ha subido $cents',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            change < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: (textStyle?.fontSize ?? 11) + 1,
            color: color,
          ),
          const SizedBox(width: 1),
          Text(cents, style: textStyle),
        ],
      ),
    );
  }
}
