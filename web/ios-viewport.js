// Fallo de iOS (WebKit) en apps instaladas en la pantalla de inicio: la
// primera vez que se abre el teclado, la ventana se encoge unos 50-60 px y
// NO recupera su tamaño al cerrarlo; abajo queda una franja vacía hasta que
// se cierra la app del todo. No pasa en Safari normal ni en Android.
//
// iOS solo vuelve a medir la ventana cuando un elemento a pantalla completa
// cambia de "display", así que al cerrar el teclado (o al volver a la app)
// se oculta y muestra uno durante un instante si la altura se ha quedado corta.
// Referencia: https://dev.to/cederhook/fixing-the-ios-standalone-pwa-keyboard-bug-that-shrinks-your-viewport-for-good-63d
//
// También guarda un registro de tamaños para el panel de diagnóstico (diag.js).
(function () {
  var log = (window.__vpLog = []);
  function vvHeight() {
    return window.visualViewport ? Math.round(window.visualViewport.height) : -1;
  }
  function note(what) {
    log.push(Math.round(performance.now()) + ' ms  ' + what + '  innerH=' + window.innerHeight + ' vvH=' + vvHeight());
    if (log.length > 60) log.shift();
  }
  note('inicio');
  window.addEventListener('resize', function () { note('resize'); });

  var standalone = navigator.standalone === true ||
    (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
  if (!standalone) return;

  function typing() {
    var a = document.activeElement;
    return !!a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA');
  }

  // Mayor altura vista sin teclado, por orientación: es la altura buena.
  var peaks = (window.__vpPeaks = {});
  function orientation() {
    return window.innerWidth > window.innerHeight ? 'horizontal' : 'vertical';
  }
  function peak() {
    return peaks[orientation()] || window.innerHeight;
  }
  function updatePeak() {
    if (typing()) return;
    var o = orientation();
    peaks[o] = Math.max(peaks[o] || 0, window.innerHeight);
  }
  updatePeak();
  window.addEventListener('resize', updatePeak);

  // Elemento invisible a pantalla completa que se usa para forzar la medida.
  var probe = document.createElement('div');
  probe.setAttribute('aria-hidden', 'true');
  probe.style.cssText = 'position:fixed;top:0;left:0;width:1px;height:100vh;visibility:hidden;pointer-events:none;';
  document.body.appendChild(probe);

  function flip(el) {
    el.style.display = 'none';
    void el.offsetHeight; // fuerza a recalcular el diseño en este momento
    el.style.display = '';
  }

  function shrunk() {
    return peak() - window.innerHeight > 4;
  }

  function repair(reason) {
    if (typing() || !shrunk()) return;
    note('reparar (' + reason + ')');
    flip(probe);
    // Si iOS aún no ha recuperado la altura, se repite con el contenedor de
    // la app (Flutter se vuelve a ajustar solo a su nuevo tamaño).
    setTimeout(function () {
      if (!typing() && shrunk()) {
        var app = document.getElementById('app');
        if (app) flip(app);
        note('reparar contenedor');
      }
      updatePeak();
    }, 120);
  }

  function later(reason, ms) {
    return function () { setTimeout(function () { repair(reason); }, ms); };
  }

  // Al cerrar el teclado: Flutter usa un <input>/<textarea> oculto para escribir.
  document.addEventListener('focusout', function (e) {
    var t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA')) later('teclado', 140)();
  }, true);
  if (window.visualViewport) window.visualViewport.addEventListener('resize', later('ventana', 200));
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) later('volver a la app', 300)();
  });
  window.addEventListener('orientationchange', later('girar', 600));
})();
