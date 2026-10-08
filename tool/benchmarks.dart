// Medidas de rendimiento con datos del tamaño real de toda España.
//
// Se usan desde test/performance_test.dart (en la máquina virtual de Dart) y
// desde tool/bench_web.dart (compiladas a JavaScript, como en la web del
// móvil), para comparar ambos entornos con las mismas operaciones.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/state/stations_controller.dart';

const spainStations = 12000;
const spainMunicipalities = 8112;

/// Una medida: nombre, mediana en ms y presupuesto máximo en ms.
class Bench {
  const Bench(this.name, this.ms, this.budgetMs);

  final String name;
  final double ms;
  final double budgetMs;

  bool get ok => ms <= budgetMs;

  @override
  String toString() =>
      '${ok ? '✓' : '✗'} ${name.padRight(40)} ${ms.toStringAsFixed(1).padLeft(7)} ms  (límite ${budgetMs.toStringAsFixed(0)} ms)';
}

const _brands = [
  'REPSOL',
  'CEPSA',
  'MOEVE',
  'GALP',
  'BALLENOIL',
  'PLENERGY',
  'SHELL',
  'BP',
  'PETROPRIX',
  'AVIA',
];
const _streets = [
  'CARRETERA NACIONAL 332 KM. 12',
  'AVENIDA DE LA CONSTITUCIÓN, 45',
  'CALLE MAYOR, 1',
  'POLÍGONO INDUSTRIAL LAS ATALAYAS',
];
const _towns = [
  'Calpe/Calp',
  'Elche/Elx',
  'Alicante/Alacant',
  'Benissa',
  'Jávea/Xàbia',
  'Villajoyosa/Vila Joiosa (la)',
];

String _price(Random r) => (1.4 + r.nextDouble() * 0.6).toStringAsFixed(3).replaceAll('.', ',');

/// JSON con la misma forma (campos y vacíos) que la respuesta de la API.
Uint8List fakeApiResponse(int n) {
  final r = Random(42);
  final list = [
    for (var i = 0; i < n; i++)
      {
        'C.P.': '0${3000 + i % 900}',
        'Dirección': _streets[i % _streets.length],
        'Horario': i.isEven ? 'L-D: 24H' : 'L-V: 06:00-22:00; S-D: 08:00-21:00',
        'Latitud': (36 + r.nextDouble() * 7.5).toStringAsFixed(6).replaceAll('.', ','),
        'Localidad': 'LOCALIDAD $i',
        'Longitud (WGS84)': (-9 + r.nextDouble() * 12).toStringAsFixed(6).replaceAll('.', ','),
        'Margen': 'D',
        'Municipio': _towns[i % _towns.length],
        'Precio Adblue': '',
        'Precio Amoniaco': '',
        'Precio Biodiesel': '',
        'Precio Bioetanol': '',
        'Precio Diésel Renovable': '',
        'Precio Gas Natural Comprimido': '',
        'Precio Gas Natural Licuado': '',
        'Precio Gases licuados del petróleo': i % 7 == 0 ? _price(r) : '',
        'Precio Gasoleo A': _price(r),
        'Precio Gasoleo B': '',
        'Precio Gasoleo Premium': i % 3 == 0 ? _price(r) : '',
        'Precio Gasolina 95 E10': '',
        'Precio Gasolina 95 E25': '',
        'Precio Gasolina 95 E5': _price(r),
        'Precio Gasolina 95 E5 Premium': '',
        'Precio Gasolina 95 E85': '',
        'Precio Gasolina 98 E10': '',
        'Precio Gasolina 98 E5': i % 2 == 0 ? _price(r) : '',
        'Precio Gasolina Renovable': '',
        'Precio Hidrogeno': '',
        'Precio Metanol': '',
        'Provincia': 'ALICANTE',
        'Remisión': 'dm',
        'Rótulo': _brands[i % _brands.length],
        'Tipo Venta': 'P',
        '% BioEtanol': '0,0',
        '% Éster metílico': '0,0',
        'IDEESS': '$i',
        'IDMunicipio': '${i % 8000}',
        'IDProvincia': '03',
        'IDCCAA': '10',
      },
  ];
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({'Fecha': '07/10/2026 10:00:00', 'ListaEESSPrecio': list, 'ResultadoConsulta': 'OK'}),
    ),
  );
}

List<Municipality> fakeMunicipalities() => [
  for (var i = 0; i < spainMunicipalities; i++)
    Municipality(
      id: '$i',
      name: i == 187 ? 'Calpe/Calp' : 'Municipio número $i',
      provinceId: (i % 52 + 1).toString().padLeft(2, '0'),
      provinceName: 'Provincia ${i % 52}',
      communityId: '${i % 19 + 1}',
    ),
];

/// Mediana en ms de varias ejecuciones (la primera calienta y no cuenta).
double medianMs(void Function() run, {int times = 5}) {
  run();
  final samples = <double>[];
  for (var i = 0; i < times; i++) {
    final sw = Stopwatch()..start();
    run();
    samples.add(sw.elapsedMicroseconds / 1000);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

/// Ejecuta todas las medidas. Los presupuestos son para un ordenador normal;
/// un móvil puede ser 2-4 veces más lento.
List<Bench> runBenchmarks({void Function(String)? log}) {
  final results = <Bench>[];
  void add(Bench b) {
    results.add(b);
    log?.call('$b');
  }

  final spainJson = fakeApiResponse(spainStations);
  log?.call('JSON de toda España generado: ${(spainJson.length / 1e6).toStringAsFixed(1)} MB');
  add(Bench('Procesar toda España (12.000)', medianMs(() => parseSnapshot(spainJson), times: 3), 1500));

  final provinceJson = fakeApiResponse(500);
  add(Bench('Procesar una provincia (500)', medianMs(() => parseSnapshot(provinceJson)), 100));

  final spain = parseSnapshot(spainJson).stations;
  const here = (lat: 38.6447, lng: 0.0445);
  add(
    Bench(
      'Ordenar España por precio',
      medianMs(() => buildEntries(spain, fuel: FuelType.gasolina95, sort: SortMode.price, position: here)),
      100,
    ),
  );
  add(
    Bench(
      'Ordenar España por distancia',
      medianMs(() => buildEntries(spain, fuel: FuelType.gasolina95, sort: SortMode.distance, position: here)),
      100,
    ),
  );
  add(
    Bench(
      'Buscar texto en España (por tecla)',
      medianMs(() => buildEntries(spain, fuel: FuelType.gasolina95, sort: SortMode.price, query: 'calpe')),
      50,
    ),
  );

  final municipalities = fakeMunicipalities();
  const murcia = SearchScope.province('30', 'Murcia');
  add(
    Bench(
      'Sugerir pueblos, 8.112 (por tecla)',
      medianMs(
        () => findPlaces('calp', current: murcia, municipalities: municipalities, provinces: const []),
      ),
      30,
    ),
  );

  final province = spain.take(500).toList();
  add(
    Bench(
      'Detectar municipio (peor caso)',
      medianMs(() => resolveTown(province, ['Pueblo inexistente'], lat: 38.6, lng: 0.04)),
      20,
    ),
  );
  return results;
}
