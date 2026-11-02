{{flutter_js}}
{{flutter_build_config}}

const status = document.getElementById('startup-status');
const reportFailure = (error) => {
  console.error('SilentPing startup failed', error);
  if (status) status.textContent = 'SilentPing could not start. Refresh this page. If it stays here, check the preview terminal for errors.';
};
window.addEventListener('unhandledrejection', (event) => reportFailure(event.reason));
window.addEventListener('error', (event) => reportFailure(event.error || event.message));

_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  },
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const engine = await engineInitializer.initializeEngine();
      await engine.runApp();
      document.getElementById('startup')?.remove();
    } catch (error) {
      reportFailure(error);
    }
  },
}).catch(reportFailure);
