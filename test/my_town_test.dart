import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/stations_controller.dart';

Station _st(String id, String municipality, String municipalityId, double lat, double lng) => Station(
  id: id,
  brand: 'Repsol',
  address: 'Calle 1',
  municipality: municipality,
  municipalityId: municipalityId,
  province: 'Alicante',
  provinceId: '03',
  communityId: '10',
  postalCode: '03000',
  schedule: '',
  latitude: lat,
  longitude: lng,
  prices: {FuelType.gasolina95: 1.7},
);

void main() {
  final stations = [
    _st('1', 'Calpe/Calp', '187', 38.6447, 0.0445),
    _st('2', 'Calpe/Calp', '187', 38.6500, 0.0500),
    _st('3', 'Elche/Elx', '203', 38.2669, -0.6984),
    _st('4', 'Elche/Elx', '203', 38.2700, -0.7000),
    _st('5', "Alfàs del Pi (l')", '9', 38.5800, -0.1000),
    _st('6', 'Benissa', '41', 38.7150, 0.0480),
  ];

  group('resolveTown', () {
    test('Calpe por su nombre en valenciano (OpenStreetMap da "Calp")', () {
      final t = resolveTown(stations, ['Calp'], lat: 38.6447, lng: 0.0445);
      expect(t, (id: '187', name: 'Calpe'));
    });

    test('Elche aunque el nombre venga al revés ("Elx / Elche")', () {
      final t = resolveTown(stations, ['Elx / Elche'], lat: 38.2669, lng: -0.6984);
      expect(t?.id, '203');
      expect(t?.name, 'Elche');
    });

    test("artículos: \"l'Alfàs del Pi\" = \"Alfàs del Pi (l')\"", () {
      expect(resolveTown(stations, ["l'Alfàs del Pi"], lat: 38.58, lng: -0.1)?.id, '9');
    });

    test('sin coincidencia de nombre, la gasolinera más cercana si está cerca', () {
      // Urbanización a las afueras de Calpe con un nombre que no es municipio.
      final t = resolveTown(stations, ['Urbanización La Canuta'], lat: 38.6460, lng: 0.0460);
      expect(t?.id, '187');
    });

    test('sin coincidencia y lejos de todo, no inventa un pueblo', () {
      expect(resolveTown(stations, ['Pueblo sin gasolinera'], lat: 39.5, lng: -1.5), isNull);
    });
  });

  test('en "mi pueblo" solo salen las gasolineras de ese municipio', () {
    final e = buildEntries(stations, fuel: FuelType.gasolina95, sort: SortMode.price, municipalityId: '203');
    expect(e.map((x) => x.station.id), unorderedEquals(['3', '4']));
  });

  test('desde "mi pueblo" se sugiere otro pueblo de la misma provincia', () {
    const calpe = SearchScope.myTown('03', '187', 'Calpe');
    final r = findPlaces(
      'benissa',
      current: calpe,
      municipalities: const [
        Municipality(
          id: '41',
          name: 'Benissa',
          provinceId: '03',
          provinceName: 'Alicante',
          communityId: '10',
        ),
        Municipality(
          id: '187',
          name: 'Calpe/Calp',
          provinceId: '03',
          provinceName: 'Alicante',
          communityId: '10',
        ),
      ],
      provinces: const [],
    );
    expect(r.single.title, 'Benissa');
    expect(findPlaces('calpe', current: calpe, municipalities: const [], provinces: const []), isEmpty);
  });

  test('OpenStreetMap: provincia y nombres del pueblo', () {
    final p = placeFromAddress({'town': 'Calp', 'postcode': '03710', 'country_code': 'es'});
    expect(p?.provinceId, '03');
    expect(p?.townNames, ['Calp']);
  });
}
