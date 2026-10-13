// Panel de diagnóstico de pantalla (oculto). Se abre manteniendo pulsado el
// logotipo de la app. Muestra las medidas reales que da el navegador, para
// investigar problemas de tamaño en dispositivos concretos (p. ej. iPhone).
(function () {
  function px(value) {
    var probe = document.createElement('div');
    probe.style.cssText = 'position:fixed;top:0;left:0;width:0;visibility:hidden;pointer-events:none;height:' + value;
    document.body.appendChild(probe);
    var h = Math.round(probe.getBoundingClientRect().height);
    probe.remove();
    return h;
  }
  function rect(sel) {
    var el = document.querySelector(sel);
    if (!el) return '—';
    var r = el.getBoundingClientRect();
    return 'top ' + Math.round(r.top) + ' · alto ' + Math.round(r.height) + ' · fin ' + Math.round(r.bottom);
  }
  function at(y) {
    var el = document.elementFromPoint(Math.round(window.innerWidth / 2), y);
    return el ? el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') : 'nada';
  }

  function report() {
    var vv = window.visualViewport;
    var mq = function (q) { return window.matchMedia && window.matchMedia(q).matches; };
    var canvases = Array.prototype.map.call(document.querySelectorAll('#app canvas'), function (c) {
      var r = c.getBoundingClientRect();
      return Math.round(r.width) + 'x' + Math.round(r.height) + ' (' + c.width + 'x' + c.height + ')';
    });
    var fv = document.querySelector('flutter-view');
    return [
      'Agente: ' + navigator.userAgent,
      'Instalada: standalone=' + navigator.standalone + ' · display-mode=' + (mq('(display-mode: standalone)') ? 'standalone' : 'browser'),
      'Tema oscuro: ' + mq('(prefers-color-scheme: dark)'),
      'Pantalla: ' + screen.width + 'x' + screen.height + ' · dpr ' + window.devicePixelRatio,
      'Ventana: inner ' + window.innerWidth + 'x' + window.innerHeight + ' · outer ' + window.outerHeight +
        ' · clientH ' + document.documentElement.clientHeight,
      'visualViewport: ' + (vv ? Math.round(vv.width) + 'x' + Math.round(vv.height) + ' · offsetTop ' + Math.round(vv.offsetTop) : '—'),
      'Unidades: 100vh=' + px('100vh') + ' · 100dvh=' + px('100dvh') + ' · 100svh=' + px('100svh') + ' · 100lvh=' + px('100lvh') + ' · 100%=' + px('100%'),
      'Zona segura: arriba ' + px('env(safe-area-inset-top,0px)') + ' · abajo ' + px('env(safe-area-inset-bottom,0px)') +
        ' · izq ' + px('env(safe-area-inset-left,0px)') + ' · der ' + px('env(safe-area-inset-right,0px)'),
      'html: ' + rect('html'),
      'body: ' + rect('body'),
      '#app: ' + rect('#app'),
      'flutter-view: ' + (fv ? (fv.getAttribute('style') || '').replace(/\s+/g, ' ').slice(0, 120) : '—'),
      'canvas: ' + (canvases.join(' | ') || '—'),
      'Elemento abajo (y=' + (window.innerHeight - 5) + '): ' + at(window.innerHeight - 5),
      'Altura buena guardada: ' + JSON.stringify(window.__vpPeaks || {}),
      'Scroll: ' + window.scrollY + ' · ' + document.documentElement.scrollTop,
      '— Registro de tamaños —',
    ].concat(window.__vpLog || []).join('\n');
  }

  window.gasDiag = function () {
    var old = document.getElementById('gas-diag');
    if (old) old.remove();
    var text = report();
    var box = document.createElement('div');
    box.id = 'gas-diag';
    box.style.cssText =
      'position:fixed;left:8px;right:8px;top:calc(8px + env(safe-area-inset-top,0px));bottom:8px;z-index:99999;' +
      'background:rgba(10,20,16,.94);color:#e6eee9;border-radius:14px;padding:12px;display:flex;flex-direction:column;gap:8px;' +
      'font:11px/1.45 ui-monospace,Menlo,monospace;box-shadow:0 10px 30px rgba(0,0,0,.4)';
    var pre = document.createElement('pre');
    pre.style.cssText = 'margin:0;flex:1;overflow:auto;white-space:pre-wrap;word-break:break-word;-webkit-user-select:text;user-select:text';
    pre.textContent = text;
    var row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px';
    function button(label, onClick) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      b.style.cssText = 'flex:1;padding:10px;border:0;border-radius:10px;background:#0B8F5A;color:#fff;font:600 14px -apple-system,sans-serif';
      b.addEventListener('click', onClick);
      row.appendChild(b);
    }
    button('Copiar', function () {
      if (navigator.clipboard) navigator.clipboard.writeText(text).catch(function () {});
    });
    button('Actualizar', function () { window.gasDiag(); });
    button('Cerrar', function () { box.remove(); });
    box.appendChild(pre);
    box.appendChild(row);
    document.body.appendChild(box);
  };
})();
