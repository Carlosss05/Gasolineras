import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Abre el panel de diagnóstico de pantalla definido en web/diag.js.
void showWebDiagnostics() {
  if (globalContext.has('gasDiag')) globalContext.callMethod<JSAny?>('gasDiag'.toJS);
}
