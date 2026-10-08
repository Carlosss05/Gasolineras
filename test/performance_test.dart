// Pruebas de rendimiento con datos del tamaño real de toda España.
//
// Fallan si alguna operación supera su presupuesto (ver tool/benchmarks.dart).
// Para ver los tiempos:
//
//   flutter test test/performance_test.dart --reporter expanded
//
// Las mismas medidas compiladas a JavaScript (como en la web del móvil):
//
//   flutter build web -t tool/bench_web.dart -o build/bench
@Tags(['performance'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../tool/benchmarks.dart';

void main() {
  test('todas las operaciones pesadas están dentro de su presupuesto', () {
    // ignore: avoid_print
    final results = runBenchmarks(log: print);
    for (final r in results) {
      expect(r.ms, lessThanOrEqualTo(r.budgetMs), reason: r.name);
    }
  });
}
