import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/data/minetur_repository.dart';
import 'package:gasolineras/models/region.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final body = jsonEncode({
    'Fecha': '05/10/2026 15:19:22',
    'ListaEESSPrecio': [
      {'IDEESS': '1', 'Latitud': '38,9', 'Longitud (WGS84)': '-1,8', 'Precio Gasolina 95 E5': '1,619'},
    ],
  });

  test('la descarga termina y las peticiones repetidas usan la caché', () async {
    var calls = 0;
    final repo = MineturRepository(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
    );
    const albacete = SearchScope.province('02', 'Albacete');

    final first = await repo.stations(albacete).timeout(const Duration(seconds: 5));
    expect(first.stations, hasLength(1));

    final again = await repo.stations(albacete).timeout(const Duration(seconds: 5));
    expect(identical(first, again), isTrue);
    expect(calls, 1);

    await repo.stations(albacete, forceRefresh: true).timeout(const Duration(seconds: 5));
    expect(calls, 2);
  });

  test('dos peticiones simultáneas comparten una sola descarga', () async {
    var calls = 0;
    final repo = MineturRepository(
      client: MockClient((_) async {
        calls++;
        return http.Response.bytes(utf8.encode(body), 200);
      }),
    );
    const albacete = SearchScope.province('02', 'Albacete');

    await Future.wait([repo.stations(albacete), repo.stations(albacete)]).timeout(const Duration(seconds: 5));
    expect(calls, 1);
  });
}
