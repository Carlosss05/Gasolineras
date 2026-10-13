// Panel de diagnóstico de pantalla de la versión web (web/diag.js). En
// Android/iOS nativo no hace nada.
export 'web_diagnostics_stub.dart' if (dart.library.js_interop) 'web_diagnostics_web.dart';
