// Busca vulnerabilidades conocidas en las dependencias (pubspec.lock) en la
// base de datos pública OSV (https://osv.dev), la misma que usan GitHub y
// Google. Termina con código 1 si encuentra alguna.
//
//   dart run tool/osv_audit.dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // En Windows git puede dejar saltos de línea \r\n.
  final lock = File('pubspec.lock').readAsStringSync().replaceAll('\r\n', '\n');

  // Paquetes de pub.dev con su versión exacta (los del SDK de Flutter no).
  final entry = RegExp(r'^  (\S+):\n((?:    .*\n)+)', multiLine: true);
  final packages = <String, String>{};
  for (final m in entry.allMatches(lock)) {
    final body = m[2]!;
    if (!body.contains('source: hosted')) continue;
    final version = RegExp(r'version: "([^"]+)"').firstMatch(body)?[1];
    if (version != null) packages[m[1]!] = version;
  }
  stdout.writeln('Dependencias analizadas: ${packages.length}');

  final names = packages.keys.toList();
  final client = HttpClient();
  final req = await client.postUrl(Uri.parse('https://api.osv.dev/v1/querybatch'));
  req.headers.contentType = ContentType.json;
  req.write(
    jsonEncode({
      'queries': [
        for (final n in names)
          {
            'package': {'name': n, 'ecosystem': 'Pub'},
            'version': packages[n],
          },
      ],
    }),
  );
  final res = await req.close();
  final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
  client.close();

  final results = (body['results'] as List).cast<Map<String, dynamic>>();
  var found = 0;
  for (var i = 0; i < results.length; i++) {
    final vulns = (results[i]['vulns'] as List?) ?? const [];
    for (final v in vulns.cast<Map<String, dynamic>>()) {
      found++;
      stdout.writeln('✗ ${names[i]} ${packages[names[i]]}: ${v['id']}');
    }
  }
  if (found == 0) {
    stdout.writeln('✓ Ninguna vulnerabilidad conocida.');
  } else {
    stdout.writeln('$found vulnerabilidades encontradas. Actualiza esos paquetes.');
    exitCode = 1;
  }
}
