import '../models/price_history.dart';
import '../state/stations_controller.dart';

/// Con qué día se comparan los precios de hoy.
enum TrendPeriod {
  day(1),
  week(7);

  const TrendPeriod(this.days);

  final int days;
}

/// Diferencias de menos de medio céntimo por litro cuentan como "igual".
const priceChangeEpsilon = 0.0005;

/// Cómo ha cambiado el precio medio de una zona desde un día pasado.
class ZoneTrend {
  const ZoneTrend({
    required this.since,
    required this.change,
    required this.compared,
    required this.up,
    required this.down,
  });

  /// Día con el que se compara.
  final DateTime since;

  /// Cambio del precio medio en €/L (positivo: ha subido).
  final double change;

  /// Gasolineras con precio los dos días (la media solo usa esas).
  final int compared;

  final int up;
  final int down;
}

/// Compara los precios de [entries] con los de [past]. Solo cuentan las
/// gasolineras con precio los dos días, para que las medias sean comparables.
/// `null` si no hay ninguna en común.
ZoneTrend? zoneTrend(Iterable<StationEntry> entries, PriceHistory past) {
  var now = 0.0;
  var then = 0.0;
  var compared = 0;
  var up = 0;
  var down = 0;
  for (final e in entries) {
    final before = past.prices[e.station.id];
    if (before == null) continue;
    now += e.price;
    then += before;
    compared++;
    final change = e.price - before;
    if (change > priceChangeEpsilon) {
      up++;
    } else if (change < -priceChangeEpsilon) {
      down++;
    }
  }
  if (compared == 0) return null;
  return ZoneTrend(since: past.day, change: (now - then) / compared, compared: compared, up: up, down: down);
}
