// Ejecuta las medidas de rendimiento compiladas a JavaScript, como corre la
// app en la web del móvil. Muestra los resultados en pantalla y en la consola.
//
//   flutter build web -t tool/bench_web.dart -o build/bench
import 'dart:async';

import 'package:flutter/material.dart';

import 'benchmarks.dart';

void main() => runApp(const MaterialApp(home: _BenchPage()));

class _BenchPage extends StatefulWidget {
  const _BenchPage();

  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage> {
  final _lines = <String>['Midiendo…'];

  @override
  void initState() {
    super.initState();
    // Deja pintar el primer frame antes de bloquear con las medidas.
    Timer(const Duration(milliseconds: 300), () {
      final lines = <String>[];
      final results = runBenchmarks(
        log: (l) {
          lines.add(l);
          debugPrint('[bench] $l');
        },
      );
      debugPrint('[bench] FIN ${results.every((r) => r.ok) ? 'OK' : 'FALLOS'}');
      setState(
        () => _lines
          ..clear()
          ..addAll(lines),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final l in _lines) Text(l, style: const TextStyle(fontFamily: 'monospace'))],
    ),
  );
}
