{{flutter_js}}
{{flutter_build_config}}

// This atlas loads historical boundary GeoJSON on demand. Flutter's default
// PWA service worker precaches every declared asset, which can make first load
// expensive because the map has many boundary files. Prefer network-on-demand
// loading over offline precache for this app.
const serviceWorkerCleanup = 'serviceWorker' in navigator
  ? navigator.serviceWorker
      .getRegistrations()
      .then((registrations) => Promise.all(
        registrations.map((registration) => registration.unregister()),
      ))
      .catch(() => {
        // Loading the app should not depend on service worker cleanup.
      })
  : Promise.resolve();

serviceWorkerCleanup.finally(() => {
  _flutter.loader.load();
});
