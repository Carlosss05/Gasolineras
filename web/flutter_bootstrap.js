{{flutter_js}}
{{flutter_build_config}}

// Service worker propio (web/sw.js): app sin conexión y últimos precios.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch((e) => console.warn('Service worker:', e));
  });
}

// La app se dibuja dentro de #app, que respeta la zona segura del iPhone
// (barra de estado y "notch") cuando se abre desde la pantalla de inicio.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: document.querySelector('#app'),
    });
    await appRunner.runApp();
    document.getElementById('splash')?.remove();
  },
});
