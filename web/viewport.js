// Ajusta la altura de la app en iPhone cuando se abre desde la pantalla de
// inicio. Con la barra de estado transparente (black-translucent), iOS
// calcula la altura de la ventana restando la barra de estado, así que un
// elemento fijado abajo (bottom: 0) se queda corto y abajo aparecía una
// franja vacía. Aquí se usa la altura real de la pantalla.
(function () {
  if (navigator.standalone !== true) return;

  var app = document.getElementById('app');
  // Elemento invisible para leer en píxeles la zona segura superior (notch).
  var probe = document.createElement('div');
  probe.style.cssText =
    'position:fixed;top:0;left:0;width:0;height:env(safe-area-inset-top,0px);visibility:hidden;pointer-events:none';
  document.body.appendChild(probe);

  function fit() {
    var landscape = window.innerWidth > window.innerHeight;
    var screenHeight = landscape
      ? Math.min(screen.width, screen.height)
      : Math.max(screen.width, screen.height);
    var top = probe.getBoundingClientRect().height;
    app.style.bottom = 'auto';
    app.style.height = screenHeight - top + 'px';
  }

  fit();
  window.addEventListener('resize', fit);
  window.addEventListener('orientationchange', function () {
    setTimeout(fit, 300);
  });
})();
