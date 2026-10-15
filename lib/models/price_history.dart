/// Precios de un combustible en una zona un día pasado (histórico oficial
/// del Ministerio), por gasolinera (`IDEESS`). Los de días pasados no cambian.
class PriceHistory {
  const PriceHistory({required this.day, required this.prices});

  /// Día de esos precios (sin hora).
  final DateTime day;

  final Map<String, double> prices;
}
