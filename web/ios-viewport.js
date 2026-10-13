// Ajustes de pantalla para iPhone (Safari y app instalada en la pantalla de
// inicio). En el resto de dispositivos solo deja la franja inferior a 0.
//
// 1) Contenido detrás de la barra de cristal. iOS 26 no dibuja los elementos
//    fijos (position: fixed) por debajo de su barra flotante ni en la zona del
//    indicador de inicio, y allí quedaba una franja sólida. En iPhone la app
//    va dentro de la página con la altura completa (clase "ios", ver
//    index.html) y se ve a través de la barra. Aquí se calcula cuánto queda
//    tapado abajo (window.__gasBottomInset + evento "gas-insets") para que la
//    app deje ese margen al final de las listas y suba los botones.
//    https://developer.apple.com/forums/thread/800798
//
// 2) Teclado en la app instalada. La primera vez que se abre, iOS encoge la
//    ventana unos 50-60 px y no la recupera al cerrarlo. Al cerrar el teclado
//    se fuerza a iOS a volver a medirla ocultando y mostrando un instante un
//    elemento a pantalla completa.
//    https://dev.to/cederhook/fixing-the-ios-standalone-pwa-keyboard-bug-that-shrinks-your-viewport-for-good-63d
//
// También guarda un registro de tamaños para el panel de diagnóstico (diag.js).
(function () {
  var log = (window.__vpLog = []);
  function note(what) {
    var vv = window.visualViewport;
    log.push(Math.round(performance.now()) + ' ms  ' + what + '  innerH=' + window.innerHeight +
      ' vvH=' + (vv ? Math.round(vv.height) : -1) + ' scrollY=' + Math.round(window.scrollY));
    if (log.length > 60) log.shift();
  }
  note('inicio');
  window.addEventListener('resize', function () { note('resize'); });
  window.__gasBottomInset = 0;

  var ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (!ios) return;
  document.documentElement.classList.add('ios');

  var standalone = navigator.standalone === true ||
    (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
  var app = document.getElementById('app');

  function typing() {
    var a = document.activeElement;
    return !!a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA');
  }
  function later(fn, ms) {
    return function () { setTimeout(fn, ms); };
  }

  // ---- 1) Zona tapada abajo -------------------------------------------------
  var safeProbe = document.createElement('div');
  safeProbe.setAttribute('aria-hidden', 'true');
  safeProbe.style.cssText =
    'position:absolute;top:0;left:0;width:1px;visibility:hidden;pointer-events:none;height:env(safe-area-inset-bottom,0px)';
  document.body.appendChild(safeProbe);

  function updateInsets() {
    // Lo que sobresale de la app por debajo de la ventana visible (barra de
    // Safari, o hueco del fallo del teclado), y como mínimo la zona del
    // indicador de inicio.
    var hidden = Math.max(0, Math.round(app.getBoundingClientRect().bottom - window.innerHeight));
    var inset = Math.max(hidden, Math.round(safeProbe.getBoundingClientRect().height));
    if (inset !== window.__gasBottomInset) {
      window.__gasBottomInset = inset;
      note('zona tapada abajo = ' + inset);
      window.dispatchEvent(new Event('gas-insets'));
    }
  }

  // iOS puede desplazar la página al escribir; la app debe quedarse arriba.
  function resetScroll() {
    if (!typing() && (window.scrollY || document.documentElement.scrollTop)) {
      note('volver arriba');
      window.scrollTo(0, 0);
    }
  }

  function refresh() {
    resetScroll();
    updateInsets();
  }

  updateInsets();
  window.addEventListener('load', refresh);
  window.addEventListener('resize', later(refresh, 50));
  if (window.visualViewport) window.visualViewport.addEventListener('resize', later(refresh, 200));
  window.addEventListener('orientationchange', later(refresh, 600));
  document.addEventListener('focusout', later(refresh, 300), true);

  // ---- 2) Teclado en la app instalada --------------------------------------
  if (!standalone) return;

  // Mayor altura vista sin teclado, por orientación: es la altura buena.
  var peaks = (window.__vpPeaks = {});
  function orientation() {
    return window.innerWidth > window.innerHeight ? 'horizontal' : 'vertical';
  }
  function updatePeak() {
    if (typing()) return;
    var o = orientation();
    peaks[o] = Math.max(peaks[o] || 0, window.innerHeight);
  }
  updatePeak();
  window.addEventListener('resize', updatePeak);
  function shrunk() {
    return (peaks[orientation()] || window.innerHeight) - window.innerHeight > 4;
  }

  // Elemento invisible a pantalla completa para forzar que iOS vuelva a medir.
  var probe = document.createElement('div');
  probe.setAttribute('aria-hidden', 'true');
  probe.style.cssText = 'position:fixed;top:0;left:0;width:1px;height:100vh;visibility:hidden;pointer-events:none;';
  document.body.appendChild(probe);

  function flip(el) {
    el.style.display = 'none';
    void el.offsetHeight; // fuerza a recalcular el diseño en este momento
    el.style.display = '';
  }

  function repair(reason) {
    if (typing() || !shrunk()) return;
    note('reparar (' + reason + ')');
    flip(probe);
    setTimeout(function () {
      if (!typing() && shrunk()) {
        flip(app);
        note('reparar contenedor');
      }
      updatePeak();
      refresh();
    }, 120);
  }

  document.addEventListener('focusout', function (e) {
    var t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA')) setTimeout(function () { repair('teclado'); }, 140);
  }, true);
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', function () {
      setTimeout(function () { repair('ventana'); }, 200);
    });
  }
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) setTimeout(function () { repair('volver a la app'); }, 300);
  });
  window.addEventListener('orientationchange', function () {
    setTimeout(function () { repair('girar'); }, 600);
  });
})();
