// A pathname beginning with // becomes a host reference when Flutter's hash
// router passes it to history.replaceState. Repair it before any SDK or Flutter
// bootstrap reads the URL. Keep the origin, query, fragment and history state.
(() => {
  const current = new URL(window.location.href);
  const path = current.pathname.replace(/^\/{2,}/, '/');
  const repaired = path !== current.pathname;
  current.pathname = path;
  // Staff links can be shared as clean paths. Enter Flutter's existing hash
  // routing format before startup so subsequent console navigation and reloads
  // use one route, including an optional returnTo query.
  const adminLink = !current.hash && /^\/admin\/[a-z-]+$/.test(path);
  if (adminLink) {
    current.hash = path + current.search;
    current.search = '';
    current.pathname = new URL(document.baseURI).pathname;
  }
  if (!repaired && !adminLink) return;
  window.history.replaceState(window.history.state, '', current.href);
})();
