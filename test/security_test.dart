// Pruebas de seguridad.
//
// La app no tiene servidor ni cuentas de usuario, así que su superficie de
// ataque es: (1) los datos que llegan de internet (API de precios,
// OpenStreetMap), (2) lo guardado en el dispositivo, que cualquiera puede
// manipular, (3) lo que escribe el usuario, y (4) el propio repositorio
// (claves, conexiones sin cifrar, permisos de los workflows).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/fuel_price_repository.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/car.dart';
import 'package:gasolineras/models/fuel_type.dart';
import 'package:gasolineras/models/region.dart';
import 'package:gasolineras/models/station.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/state/favorites_controller.dart';
import 'package:gasolineras/ui/format.dart';
import 'package:gasolineras/ui/widgets/station_tile.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _station(Map<String, Object?> overrides) => {
  'IDEESS': '1',
  'Rótulo': 'REPSOL',
  'Dirección': 'CALLE MAYOR, 1',
  'Municipio': 'Calpe/Calp',
  'IDMunicipio': '187',
  'IDProvincia': '03',
  'Latitud': '38,6447',
  'Longitud (WGS84)': '0,0445',
  'Precio Gasolina 95 E5': '1,619',
  ...overrides,
};

Uint8List _bytes(Object json) => Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  group('Datos de la API (no fiables)', () {
    test('precios imposibles se descartan: infinito, NaN, negativos, absurdos', () {
      for (final bad in ['Infinity', 'NaN', '-1,5', '0', '9999', '1e400', '1,6abc', '${'9' * 50},0']) {
        final s = Station.fromApi(_station({'Precio Gasolina 95 E5': bad}));
        expect(s?.prices[FuelType.gasolina95], isNull, reason: 'precio "$bad"');
      }
    });

    test('coordenadas fuera del planeta o no numéricas: la estación se descarta', () {
      for (final (lat, lng) in [('91', '0'), ('0', '181'), ('NaN', '0'), ('Infinity', '1'), ('abc', '1')]) {
        expect(
          Station.fromApi(_station({'Latitud': lat, 'Longitud (WGS84)': lng})),
          isNull,
          reason: '$lat,$lng',
        );
      }
    });

    test('tipos inesperados (números, listas, mapas, null) no rompen la app', () {
      final s = Station.fromApi(
        _station({
          'Rótulo': 12345,
          'Dirección': ['a', 'b'],
          'Municipio': {'x': 1},
          'C.P.': null,
          'Precio Gasoleo A': 1.5, // número en vez de texto: se ignora
        }),
      );
      expect(s, isNotNull);
      expect(s!.brand, '12345');
      expect(s.address, '');
      expect(s.prices.containsKey(FuelType.diesel), isFalse);
      expect(Station.fromApi(_station({'IDEESS': null})), isNull);
    });

    test('textos enormes se recortan (evita abusar de memoria o de la pantalla)', () {
      final s = Station.fromApi(_station({'Rótulo': 'A' * 100000}))!;
      expect(s.brand.length, Station.maxTextLength);
    });

    test('HTML o scripts en los textos se tratan como texto plano', () {
      final s = Station.fromApi(_station({'Rótulo': '<script>alert(1)</script>'}))!;
      // Flutter pinta texto, no interpreta HTML; solo cambia mayúsculas.
      expect(s.brand.toLowerCase(), '<script>alert(1)</script>');
    });

    test('el enlace "Cómo llegar" solo contiene coordenadas, nunca textos de la API', () {
      final s = Station.fromApi(_station({'Rótulo': 'x&destination=evil.example#', 'Dirección': '"><img>'}))!;
      final uri = directionsUri(s);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters.keys, unorderedEquals(['api', 'destination']));
      expect(uri.queryParameters['destination'], '38.6447,0.0445');
    });

    test('respuesta que no es JSON: mensaje claro, no un error interno', () async {
      final repo = MineturRepository(
        client: MockClient((_) async => http.Response('<html>Error</html>', 200)),
      );
      expect(
        repo.stations(const SearchScope.province('03', 'Alicante')),
        throwsA(isA<FuelApiException>().having((e) => e.message, 'message', contains('no válidos'))),
      );
    });

    test('JSON con forma inesperada: mensaje claro', () async {
      final repo = MineturRepository(
        client: MockClient((_) async => http.Response.bytes(_bytes({'ListaEESSPrecio': 'nope'}), 200)),
      );
      expect(repo.stations(const SearchScope.spain()), throwsA(isA<FuelApiException>()));
    });

    test('error HTTP del servidor: mensaje claro', () async {
      final repo = MineturRepository(client: MockClient((_) async => http.Response('', 503)));
      expect(repo.stations(const SearchScope.spain()), throwsA(isA<FuelApiException>()));
    });

    test('elementos sueltos inválidos no tiran toda la lista', () {
      final snap = parseSnapshot(
        _bytes({
          'ListaEESSPrecio': [
            _station({}),
            _station({'IDEESS': '2', 'Latitud': 'basura'}),
            _station({'IDEESS': '3'}),
          ],
        }),
      );
      expect(snap.stations.map((s) => s.id), ['1', '3']);
    });

    test('OpenStreetMap: fuera de España o código postal falso no da provincia', () {
      expect(placeFromAddress({'postcode': '03710', 'country_code': 'fr'}), isNull);
      expect(provinceFromPostalCode('99999'), isNull);
      expect(provinceFromPostalCode('03710; DROP'), isNull);
    });
  });

  group('Datos guardados en el dispositivo (manipulables)', () {
    test('coche con valores fuera de rango o tipos falsos: se ignora', () {
      for (final bad in [
        {'fuel': 'gasolina95', 'tank': -5, 'consumption': 6},
        {'fuel': 'gasolina95', 'tank': 50, 'consumption': 1e9},
        {'fuel': 'gasolina95', 'tank': double.nan, 'consumption': 6},
        {'fuel': 'nuclear', 'tank': 50, 'consumption': 6},
        {'fuel': 'gasolina95', 'tank': '50', 'consumption': 6},
      ]) {
        expect(CarProfile.fromJson(bad), isNull, reason: '$bad');
      }
    });

    test('repostaje con cifras imposibles: se ignora', () {
      Map<String, Object?> entry(Map<String, Object?> o) => {
        'id': '1',
        'date': '2026-10-05T10:00:00.000',
        'fuel': 'gasolina95',
        'liters': 40,
        'total': 64,
        ...o,
      };
      expect(RefuelEntry.fromJson(entry({})), isNotNull);
      for (final bad in [
        {'liters': -1},
        {'liters': 1e12},
        {'total': 0},
        {'total': double.infinity},
        {'km': -10},
        {'date': 'ayer'},
      ]) {
        expect(RefuelEntry.fromJson(entry(bad)), isNull, reason: '$bad');
      }
    });

    test('una media de zona manipulada no infla el ahorro', () {
      final e = RefuelEntry.fromJson({
        'id': '1',
        'date': '2026-10-05T10:00:00.000',
        'fuel': 'gasolina95',
        'liters': 40,
        'total': 64,
        'avg': 999999,
      })!;
      expect(e.saving, 0);
    });

    test('zona guardada manipulada (inyección en la URL, tipo falso): se ignora', () {
      expect(SearchScope.fromJson({'kind': 'province', 'id': '03/../../x', 'name': 'A'}), isNull);
      expect(SearchScope.fromJson({'kind': 'province', 'id': '03?a=1', 'name': 'A'}), isNull);
      expect(SearchScope.fromJson({'kind': 'admin', 'id': '03', 'name': 'A'}), isNull);
      expect(SearchScope.fromJson({'kind': 'province', 'id': '03', 'name': ''}), isNull);
      expect(
        SearchScope.fromJson({'kind': 'myTown', 'id': '03', 'name': 'Calpe', 'townId': '1; x'})?.kind,
        ScopeKind.myProvince,
      );

      final ok = SearchScope.fromJson(const SearchScope.myTown('03', '187', 'Calpe').toJson())!;
      expect((ok.kind, ok.id, ok.townId), (ScopeKind.myTown, '03', '187'));
    });

    test('favoritas con JSON corrupto: la app arranca sin favoritas', () async {
      SharedPreferences.setMockInitialValues({'favorites.v1': '{esto no es json'});
      final favs = FavoritesController();
      await favs.load();
      expect(favs.isEmpty, isTrue);
    });
  });

  group('Lo que escribe el usuario', () {
    test('números enormes, vacíos o con letras no se aceptan', () {
      expect(parseDecimal('9' * 400), isNull);
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('1,2,3'), isNull);
      expect(parseDecimal('NaN'), isNull);
      expect(parseDecimal('12,5'), 12.5);
      expect(RefuelEntry.isValid(liters: 40, totalEuros: 64), isTrue);
      expect(RefuelEntry.isValid(liters: 40, totalEuros: 64, odometerKm: -1), isFalse);
      expect(CarProfile.isValid(tankLiters: 5000, consumption: 6), isFalse);
    });
  });

  group('Repositorio y configuración', () {
    final root = Directory.current;

    test('todas las conexiones del código son cifradas (HTTPS)', () {
      final offenders = <String>[];
      for (final f in Directory('${root.path}/lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('http://')) offenders.add('${f.path}:${i + 1}');
        }
      }
      expect(offenders, isEmpty);
    });

    test('Android no permite tráfico sin cifrar ni hace la app depurable', () {
      final manifest = File('${root.path}/android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
      expect(manifest, isNot(contains('android:debuggable="true"')));
    });

    test('la clave de firma y los secretos están excluidos de git', () {
      final gitignore = File('${root.path}/.gitignore').readAsStringSync();
      final androidIgnore = File('${root.path}/android/.gitignore').readAsStringSync();
      expect(gitignore, contains('/.secrets/'));
      expect(androidIgnore, contains('key.properties'));
      expect(androidIgnore, contains('**/*.jks'));
    });

    test('ningún archivo con claves está subido al repositorio', () async {
      final r = await Process.run('git', ['ls-files'], workingDirectory: root.path);
      if (r.exitCode != 0) return; // sin git (p. ej. código descargado en zip)
      final tracked = (r.stdout as String).split('\n');
      final secrets = tracked.where(
        (f) => RegExp(r'(\.jks|\.keystore|key\.properties|\.secrets/|\.p12|\.pem)$|\.secrets/').hasMatch(f),
      );
      expect(secrets, isEmpty);
    });

    test('los workflows de GitHub tienen los permisos mínimos', () {
      final pages = File('${root.path}/.github/workflows/pages.yml').readAsStringSync();
      final android = File('${root.path}/.github/workflows/android.yml').readAsStringSync();
      for (final wf in [pages, android]) {
        // pull_request_target ejecuta código de terceros con secretos: prohibido.
        expect(wf, isNot(contains('pull_request_target')));
        expect(wf, contains('permissions:'));
        expect(wf, isNot(contains('write-all')));
      }
      expect(pages, contains('contents: read'));
      // Los secretos de firma solo se usan al publicar una versión etiquetada.
      expect(android, contains("tags: ['v*']"));
      expect(android, isNot(contains('pull_request')));
    });
  });
}
