// Aviso para instalar la app en iPhone (Safari no lo sugiere solo). Va en un
// archivo aparte para que la política de seguridad (CSP) no tenga que
// permitir scripts escritos dentro del HTML.
(function () {
  var ios = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var installed = navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches;
  var dismissed = false;
  try { dismissed = localStorage.getItem('install-dismissed') === '1'; } catch (e) {}
  if (!ios || installed || dismissed) return;

  var banner = document.getElementById('install');
  banner.querySelector('button').addEventListener('click', function () {
    banner.classList.remove('show');
    try { localStorage.setItem('install-dismissed', '1'); } catch (e) {}
  });
  setTimeout(function () { banner.classList.add('show'); }, 4000);
})();
