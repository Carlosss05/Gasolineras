import 'fuel_type.dart';

/// Datos del coche del usuario para personalizar precios y ahorro.
class CarProfile {
  const CarProfile({required this.fuel, required this.tankLiters, required this.consumption});

  final FuelType fuel;

  /// Capacidad del depósito, en litros.
  final double tankLiters;

  /// Consumo medio, en litros cada 100 km.
  final double consumption;

  Map<String, Object> toJson() => {'fuel': fuel.name, 'tank': tankLiters, 'consumption': consumption};

  static CarProfile? fromJson(Map<String, dynamic> j) {
    try {
      return CarProfile(
        fuel: FuelType.values.byName(j['fuel'] as String),
        tankLiters: (j['tank'] as num).toDouble(),
        consumption: (j['consumption'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Un repostaje anotado en el diario.
class RefuelEntry {
  const RefuelEntry({
    required this.id,
    required this.date,
    required this.fuel,
    required this.liters,
    required this.totalEuros,
    this.stationId,
    this.stationName,
    this.odometerKm,
    this.zoneAverage,
  });

  final String id;
  final DateTime date;
  final FuelType fuel;
  final double liters;
  final double totalEuros;
  final String? stationId;
  final String? stationName;

  /// Kilómetros del cuentakilómetros al repostar (para calcular el consumo).
  final double? odometerKm;

  /// Precio medio de la zona cuando se repostó, para calcular el ahorro.
  /// Solo se conoce si el repostaje se anota desde una gasolinera de la app.
  final double? zoneAverage;

  double get pricePerLiter => liters > 0 ? totalEuros / liters : 0;

  /// Lo que se ahorró frente a la media de la zona (0 si no se conoce).
  double get saving => zoneAverage == null ? 0 : (zoneAverage! - pricePerLiter) * liters;

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'fuel': fuel.name,
    'liters': liters,
    'total': totalEuros,
    'stationId': stationId,
    'stationName': stationName,
    'km': odometerKm,
    'avg': zoneAverage,
  };

  static RefuelEntry? fromJson(Map<String, dynamic> j) {
    try {
      return RefuelEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        fuel: FuelType.values.byName(j['fuel'] as String),
        liters: (j['liters'] as num).toDouble(),
        totalEuros: (j['total'] as num).toDouble(),
        stationId: j['stationId'] as String?,
        stationName: j['stationName'] as String?,
        odometerKm: (j['km'] as num?)?.toDouble(),
        zoneAverage: (j['avg'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
