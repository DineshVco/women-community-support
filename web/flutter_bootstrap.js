{{flutter_js}}
{{flutter_build_config}}

// Looma starts without a service worker. Flutter's default one made the
// first start wait up to 4 seconds for it and downloaded the app a second
// time on the first visit. Normal browser caching (see firebase.json)
// keeps repeat starts quick. Any service worker left by an older version
// is removed.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker
    .getRegistrations()
    .then(function (registrations) {
      registrations.forEach(function (r) { r.unregister(); });
    })
    .catch(function () {});
  // And the copies of the app it kept.
  if (window.caches) {
    caches
      .keys()
      .then(function (keys) {
        keys
          .filter(function (k) { return k.indexOf('flutter-') === 0; })
          .forEach(function (k) { caches.delete(k); });
      })
      .catch(function () {});
  }
}

_flutter.loader.load();
