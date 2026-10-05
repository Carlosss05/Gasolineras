import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _price = NumberFormat('0.000', 'es');
final _km = NumberFormat('0.0', 'es');
final _time = DateFormat('HH:mm');
final _date = DateFormat('dd/MM HH:mm');

String formatPrice(double p) => '${_price.format(p)} €';

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
      ? Color.lerp(const Color(0xFF1B8A3A), const Color(0xFFC98A00), t * 2)!
      : Color.lerp(const Color(0xFFC98A00), const Color(0xFFC62828), (t - 0.5) * 2)!;
}
