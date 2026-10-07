import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

final _price = NumberFormat('0.000', 'es');
final _euros = NumberFormat('0.00', 'es');
final _km = NumberFormat('0.0', 'es');
final _time = DateFormat('HH:mm');
final _date = DateFormat('dd/MM HH:mm');

String formatPrice(double p) => '${_price.format(p)} €';

/// Solo la cifra, para mostrar "1,619" grande y "€/L" aparte.
String formatPriceNumber(double p) => _price.format(p);

String formatEuros(double e) => '${_euros.format(e)} €';

String formatLiters(double l) => '${_km.format(l)} L';

final _day = DateFormat('d MMM', 'es');
final _monthYear = DateFormat('MMMM yyyy', 'es');

String formatDay(DateTime d) => _day.format(d);

String formatMonth(DateTime d) => _monthYear.format(d);

/// Número escrito por el usuario, con coma o punto decimal.
double? parseDecimal(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

String formatDistance(double km) => km < 1 ? '${(km * 1000).round()} m' : '${_km.format(km)} km';

String formatPublished(DateTime d) {
  final now = DateTime.now();
  final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
  return sameDay ? 'hoy a las ${_time.format(d)}' : _date.format(d);
}

/// Verde para lo más barato de la lista, rojo para lo más caro.
Color priceColor(double price, double min, double max) {
  final t = max - min < 0.0005 ? 0.0 : ((price - min) / (max - min)).clamp(0.0, 1.0);
  return t < 0.5
      ? Color.lerp(AppColors.cheap, AppColors.mid, t * 2)!
      : Color.lerp(AppColors.mid, AppColors.expensive, (t - 0.5) * 2)!;
}

/// Si el horario indica apertura las 24 horas ("L-D: 24H").
bool isOpen24h(String schedule) => schedule.toUpperCase().contains('24H');
