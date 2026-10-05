import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/state/stations_controller.dart';

Map<String, dynamic> _station(String id, String g95, String diesel, String lat, String lng) => {
      'IDEESS': id,
      'Rótulo': 'REPSOL',
      'Dirección': 'CALLE MAYOR, 1',
      'Municipio': 'Alicante/Alacant',
      'Provincia': 'ALICANTE',
      'IDProvincia': '03',
      'IDCCAA': '10',
      'C.P.': '03001',
      'Horario': 'L-D: 24H',
      'Latitud': lat,
      'Longitud (WGS84)': lng,
      'Precio Gasolina 95 E5': g95,
      'Precio Gasoleo A': diesel,
    };

Uint8List _response(List<Map<String, dynamic>> stations) => Uint8List.fromList(utf8.encode(jsonEncode({
      'Fecha': '05/10/2026 15:19:22',
      'ListaEESSPrecio': stations,
      'ResultadoConsulta': 'OK',
    })));

void main() {
  test('parsea precios con coma decimal y descarta campos vacíos', () {
    final snap = parseSnapshot(_response([_station('1', '1,889', '', '38,434417', '-0,637250')]));

    expect(snap.publishedAt, DateTime(2026, 10, 5, 15, 19, 22));
    final s = snap.stations.single;
    expect(s.prices[FuelType.gasolina95], 1.889);
    expect(s.prices.containsKey(FuelType.diesel), isFalse);
    expect(s.latitude, closeTo(38.434417, 1e-9));
    expect(s.brand, 'Repsol');
    expect(s.address, 'Calle Mayor, 1');
  });

  test('descarta estaciones sin coordenadas', () {
    final snap = parseSnapshot(_response([_station('1', '1,8', '', '', '')]));
    expect(snap.stations, isEmpty);
  });

  group('buildEntries', () {
    final stations = parseSnapshot(_response([
      _station('cara-cerca', '1,950', '1,800', '38,3450', '-0,4810'),
      _station('barata-lejos', '1,700', '', '38,9000', '-0,1000'),
      _station('media', '1,800', '1,700', '38,5000', '-0,4000'),
    ])).stations;
    const here = (lat: 38.3452, lng: -0.4815);

    test('ordena de más barata a más cara', () {
      final e = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.price, position: here);
      expect(e.map((x) => x.station.id), ['barata-lejos', 'media', 'cara-cerca']);
    });

    test('ordena por cercanía', () {
      final e = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.distance, position: here);
      expect(e.map((x) => x.station.id), ['cara-cerca', 'media', 'barata-lejos']);
      expect(e.first.distanceKm, lessThan(0.1));
    });

    test('sin ubicación, la cercanía cae a orden por precio', () {
      final e = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.distance);
      expect(e.first.station.id, 'barata-lejos');
      expect(e.first.distanceKm, isNull);
    });

    test('solo incluye estaciones que venden el combustible', () {
      final e = buildEntries(stations, fuel: FuelType.diesel, sort: SortMode.price);
      expect(e.map((x) => x.station.id), ['media', 'cara-cerca']);
    });

    test('el buscador ignora mayúsculas y tildes', () {
      final e = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.price, query: 'ALICÁNTE');
      expect(e, hasLength(3));
      expect(buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.price, query: 'cepsa'), isEmpty);
    });
  });
}
