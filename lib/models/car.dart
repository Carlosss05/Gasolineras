import 'fuel_type.dart';

/// Datos del coche del usuario para personalizar precios y ahorro.
class CarProfile {
  const CarProfile({required this.fuel, required this.tankLiters, required this.consumption});

  final FuelType fuel;

  /// Capacidad del depósito, en litros.
  final double tankLiters;

  /// Consumo medio, en litros cada 100 km.
  final double consumption;

  /// Rangos admitidos (los mismos que en el formulario).
  static const minTank = 10.0, maxTank = 200.0;
  static const minConsumption = 2.0, maxConsumption = 30.0;

  static bool isValid({required double tankLiters, required double consumption}) =>
      tankLiters >= minTank &&
      tankLiters <= maxTank &&
      consumption >= minConsumption &&
      consumption <= maxConsumption;

  Map<String, Object> toJson() => {'fuel': fuel.name, 'tank': tankLiters, 'consumption': consumption};

  /// Lee lo guardado en el dispositivo. Como cualquiera puede manipularlo,
  /// devuelve `null` ante tipos o valores fuera de rango.
  static CarProfile? fromJson(Map<String, dynamic> j) {
    try {
      final tank = (j['tank'] as num).toDouble();
      final consumption = (j['consumption'] as num).toDouble();
      if (!isValid(tankLiters: tank, consumption: consumption)) return null;
      return CarProfile(
        fuel: FuelType.values.byName(j['fuel'] as String),
        tankLiters: tank,
        consumption: consumption,
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

  /// Límites de un repostaje creíble (un camión cabe de sobra).
  static const maxLiters = 1000.0, maxTotal = 10000.0, maxKm = 5000000.0;

  static bool isValid({required double liters, required double totalEuros, double? odometerKm}) =>
      liters > 0 &&
      liters <= maxLiters &&
      totalEuros > 0 &&
      totalEuros <= maxTotal &&
      (odometerKm == null || (odometerKm >= 0 && odometerKm <= maxKm));

  /// Lee lo guardado en el dispositivo. Como cualquiera puede manipularlo,
  /// devuelve `null` ante tipos o valores fuera de rango.
  static RefuelEntry? fromJson(Map<String, dynamic> j) {
    try {
      final liters = (j['liters'] as num).toDouble();
      final total = (j['total'] as num).toDouble();
      final km = (j['km'] as num?)?.toDouble();
      final avg = (j['avg'] as num?)?.toDouble();
      if (!isValid(liters: liters, totalEuros: total, odometerKm: km)) return null;
      final name = j['stationName'] as String?;
      return RefuelEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        fuel: FuelType.values.byName(j['fuel'] as String),
        liters: liters,
        totalEuros: total,
        stationId: j['stationId'] as String?,
        stationName: name != null && name.length > 200 ? name.substring(0, 200) : name,
        odometerKm: km,
        // Una media imposible no debe inflar el "ahorrado con la app".
        zoneAverage: avg != null && avg > 0 && avg < 10 ? avg : null,
      );
    } catch (_) {
      return null;
    }
  }
}
