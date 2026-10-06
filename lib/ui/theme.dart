import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad visual: verde esmeralda (ahorro, confianza) con acento ámbar
/// para "la mejor oferta". Todo el color de la app sale de aquí.
abstract final class AppColors {
  static const emerald = Color(0xFF0B8F5A);
  static const emeraldDark = Color(0xFF06603D);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFFF5A524);
  static const ink = Color(0xFF13221C);

  static const cheap = Color(0xFF0B8F5A);
  static const mid = Color(0xFFD98E04);
  static const expensive = Color(0xFFD64545);

  /// Degradado de la cabecera.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B8F5A), Color(0xFF0F766E)],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.emerald, brightness: brightness).copyWith(
    primary: dark ? const Color(0xFF3DD68C) : AppColors.emerald,
    secondary: AppColors.amber,
    surface: dark ? const Color(0xFF16201B) : Colors.white,
    surfaceContainerLowest: dark ? const Color(0xFF0E1512) : const Color(0xFFF2F6F3),
    onSurface: dark ? const Color(0xFFE6EEE9) : AppColors.ink,
    onSurfaceVariant: dark ? const Color(0xFF9BB0A5) : const Color(0xFF5B6B63),
    outlineVariant: dark ? const Color(0xFF26332C) : const Color(0xFFE1E8E4),
  );

  final text = GoogleFonts.plusJakartaSansTextTheme(
    (dark ? ThemeData.dark() : ThemeData.light()).textTheme,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      secondaryLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimary),
      checkmarkColor: scheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primaryContainer : scheme.surface,
        ),
        textStyle: WidgetStatePropertyAll(text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
