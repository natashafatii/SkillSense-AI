// A pathname beginning with // becomes a host reference when Flutter's hash
// router passes it to history.replaceState. Repair it before any SDK or Flutter
// bootstrap reads the URL. Keep the origin, query, fragment and history state.
(() => {
  const current = new URL(window.location.href);
  const path = current.pathname.replace(/^\/{2,}/, '/');
  if (path === current.pathname) return;
  current.pathname = path;
  window.history.replaceState(window.history.state, '', current.href);
})();
