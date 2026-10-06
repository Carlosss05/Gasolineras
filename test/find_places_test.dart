import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/state/stations_controller.dart';

const _municipalities = [
  Municipality(id: '187', name: 'Calpe/Calp', provinceId: '03', provinceName: 'Alicante', communityId: '10'),
  Municipality(id: '1', name: 'Madridejos', provinceId: '45', provinceName: 'Toledo', communityId: '07'),
  Municipality(id: '2', name: 'Madrid', provinceId: '28', provinceName: 'Madrid', communityId: '13'),
  Municipality(id: '3', name: 'Murcia', provinceId: '30', provinceName: 'Murcia', communityId: '14'),
];

const _provinces = [
  Province(id: '03', name: 'Alicante', communityId: '10'),
  Province(id: '30', name: 'Murcia', communityId: '14'),
];

List<PlaceSuggestion> _find(String q, SearchScope? current) =>
    findPlaces(q, current: current, municipalities: _municipalities, provinces: _provinces);

void main() {
  const murcia = SearchScope.myProvince('30', 'Murcia');

  test('encuentra Calpe estando en otra provincia, por cualquiera de sus nombres', () {
    for (final q in ['calpe', 'CALP', 'Calpe']) {
      final r = _find(q, murcia);
      expect(r.single.title, 'Calpe/Calp');
      expect(r.single.scope.id, '03');
    }
  });

  test('un código postal lleva a su provincia', () {
    final r = _find('03710', murcia);
    expect(r.single.title, 'Código postal 03710');
    expect(r.single.scope.id, '03');
  });

  test('no sugiere lugares que ya están en la zona actual', () {
    expect(_find('calpe', const SearchScope.province('03', 'Alicante')), isEmpty);
    expect(_find('calpe', const SearchScope.community('10', 'Comunidad Valenciana')), isEmpty);
    expect(_find('03710', const SearchScope.province('03', 'Alicante')), isEmpty);
    expect(_find('calpe', const SearchScope.spain()), isEmpty);
  });

  test('sin zona elegida también sugiere', () {
    expect(_find('calpe', null), hasLength(1));
  });

  test('la coincidencia exacta va primero', () {
    expect(_find('madrid', murcia).map((p) => p.title), ['Madrid', 'Madridejos']);
  });

  test('búsquedas demasiado cortas o números incompletos no sugieren nada', () {
    expect(_find('ca', murcia), isEmpty);
    expect(_find('0371', murcia), isEmpty);
  });
}
