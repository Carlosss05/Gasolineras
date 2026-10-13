import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Píxeles tapados abajo por la barra de Safari o el indicador de inicio.
final ValueNotifier<double> webBottomInset = ValueNotifier(_read());

double _read() {
  final value = globalContext['__gasBottomInset'];
  if (value == null || !value.isA<JSNumber>()) return 0;
  final px = (value as JSNumber).toDartDouble;
  return px.isFinite && px > 0 && px < 600 ? px : 0;
}

/// Escucha los cambios que avisa web/ios-viewport.js (evento "gas-insets").
void initWebInsets() {
  webBottomInset.value = _read();
  globalContext.callMethod<JSAny?>(
    'addEventListener'.toJS,
    'gas-insets'.toJS,
    ((JSAny? _) => webBottomInset.value = _read()).toJS,
  );
}
