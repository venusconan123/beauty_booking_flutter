{{flutter_js}}
{{flutter_build_config}}

// A preview must show startup failures instead of leaving an empty page.
const startupMessage = document.getElementById('app-startup-message');
function startupFailed(error) {
  console.error('[startup] failed', error);
  if (startupMessage) {
    startupMessage.textContent = 'Không thể mở ứng dụng. Vui lòng tải lại trang.';
  }
}
window.addEventListener('flutter-first-frame', () => {
  console.info('[startup] first-frame');
  document.getElementById('app-startup')?.remove();
}, {once: true});
window.addEventListener('error', (event) => {
  if (!document.querySelector('flutter-view')) startupFailed(event.error ?? event.message);
});
console.info('[startup] loading-entrypoint');
Promise.resolve(_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      console.info('[startup] entrypoint-loaded');
      const appRunner = await engineInitializer.initializeEngine();
      console.info('[startup] engine-ready');
      await appRunner.runApp();
    } catch (error) {
      startupFailed(error);
    }
  },
})).catch(startupFailed);
