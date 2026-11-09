{{flutter_js}}
{{flutter_build_config}}

// Called only by FIREBASE_EMULATORS builds. Public JS SDK APIs connect Auth
// before FlutterFire waits for persisted sessions. Keep the fallback aligned
// with firebase_core_web 3.10.0 (pubspec.lock); explicit SDK overrides also apply.
window.prepareDemoAuthEmulator = async (host, port, options) => {
  if (options.projectId !== 'demo-men-hair-booking') {
    throw new Error('Auth bootstrap requires the isolated demo project.');
  }
  const version = window.flutterfire_web_sdk_version || '12.17.0';
  const core = await import(`https://www.gstatic.com/firebasejs/${version}/firebase-app.js`);
  const auth = await import(`https://www.gstatic.com/firebasejs/${version}/firebase-auth.js`);
  const app = core.initializeApp(options);
  const instance = auth.initializeAuth(app, {
    errorMap: auth.debugErrorMap,
    persistence: [auth.indexedDBLocalPersistence, auth.browserLocalPersistence,
      auth.browserSessionPersistence],
    popupRedirectResolver: auth.browserPopupRedirectResolver,
  });
  auth.connectAuthEmulator(instance, `http://${host}:${port}`);
};

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
  if (document.getElementById('app-startup')) startupFailed(event.error ?? event.message);
});
window.addEventListener('unhandledrejection', (event) => {
  if (document.getElementById('app-startup')) startupFailed(event.reason);
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
