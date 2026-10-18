{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's (deprecated) worker unregisters any
// worker on the page and reloads it, which would fight offline.js.
_flutter.loader.load();
