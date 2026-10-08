import 'package:flutter/material.dart';

import '../../utils/text.dart';

/// Insignia de la marca de la gasolinera: siglas sobre los colores
/// corporativos de las marcas más comunes en España. No reproduce logotipos
/// (tienen derechos de marca); el resto de marcas usan su inicial con un
/// color estable derivado del nombre.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.brand, this.size = 40});

  final String brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = brandStyle(brand);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: style.border == null ? null : Border.all(color: style.border!, width: size * 0.06),
      ),
      child: style.label == null
          ? Icon(Icons.local_gas_station, color: style.foreground, size: size * 0.55)
          : FittedBox(
              child: Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: Text(
                  style.label!,
                  style: TextStyle(
                    color: style.foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.42,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
              ),
            ),
    );
  }
}

class BrandStyle {
  const BrandStyle(this.label, this.background, this.foreground, [this.border]);

  final String? label;
  final Color background;
  final Color foreground;
  final Color? border;
}

/// Marcas conocidas: clave normalizada (contenida en el rótulo) -> estilo.
/// El orden importa: se usa la primera clave que aparece en el rótulo.
const _brands = <String, BrandStyle>{
  'repsol': BrandStyle('R', Color(0xFFFF7A00), Colors.white, Color(0xFFE30613)),
  'moeve': BrandStyle('M', Color(0xFF00857C), Colors.white),
  'cepsa': BrandStyle('C', Color(0xFFE2231A), Colors.white),
  'galp': BrandStyle('G', Color(0xFFF26522), Colors.white),
  'ballenoil': BrandStyle('B', Color(0xFF0072BC), Colors.white),
  'plenergy': BrandStyle('P', Color(0xFF7AB929), Colors.white),
  'plenoil': BrandStyle('P', Color(0xFF7AB929), Colors.white),
  'shell': BrandStyle('S', Color(0xFFFFD500), Color(0xFFDD1D21)),
  'petroprix': BrandStyle('PX', Color(0xFFE30613), Colors.white),
  'petronor': BrandStyle('PN', Color(0xFF00843D), Colors.white, Color(0xFFE30613)),
  'bp': BrandStyle('bp', Color(0xFF009B3A), Color(0xFFFFE600)),
  'carrefour': BrandStyle('C', Color(0xFF004E9F), Colors.white, Color(0xFFE2001A)),
  'avia': BrandStyle('A', Color(0xFFE30613), Colors.white),
  'q8': BrandStyle('Q8', Color(0xFF00529F), Color(0xFFF7A600)),
  'esclatoil': BrandStyle('E', Color(0xFF1D3F8F), Colors.white),
  'bonarea': BrandStyle('bA', Color(0xFFD7001E), Colors.white),
  'campsa': BrandStyle('CA', Color(0xFFE30613), Color(0xFFFFD100)),
  'valcarce': BrandStyle('V', Color(0xFF003A70), Colors.white),
  'agla': BrandStyle('AG', Color(0xFF2E7D32), Colors.white),
  'alcampo': BrandStyle('A', Color(0xFFE2001A), Colors.white, Color(0xFF00953A)),
  'eni': BrandStyle('eni', Color(0xFFFFD100), Colors.black),
  'eroski': BrandStyle('E', Color(0xFFE30613), Colors.white),
  'gasexpress': BrandStyle('GX', Color(0xFF00A0DF), Colors.white),
  'beroil': BrandStyle('BE', Color(0xFF00447C), Colors.white),
  'meroil': BrandStyle('ME', Color(0xFF00447C), Color(0xFFFFC20E)),
  'tamoil': BrandStyle('T', Color(0xFFF58220), Colors.white),
  'disa': BrandStyle('D', Color(0xFF00539B), Colors.white, Color(0xFFE30613)),
};

/// Colores para marcas desconocidas, elegidos de forma estable por nombre.
const _fallbackColors = [
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFF8D6E63),
  Color(0xFF7E57C2),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFEC407A),
  Color(0xFF78909C),
];

BrandStyle brandStyle(String brand) {
  final words = normalize(brand).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const BrandStyle(null, Color(0xFF90A4AE), Colors.white);

  final joined = words.join();
  for (final entry in _brands.entries) {
    // "bp" o "eni" solo como palabra completa; el resto, en cualquier parte.
    final match = entry.key.length <= 3 ? words.contains(entry.key) : joined.contains(entry.key);
    if (match) return entry.value;
  }

  final hash = joined.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return BrandStyle(
    words.first[0].toUpperCase(),
    _fallbackColors[hash % _fallbackColors.length],
    Colors.white,
  );
}
