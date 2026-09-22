/* Keep bookmarked page URLs useful after their content moves to the homepage. */
(() => {
  'use strict';
  const routes = JSON.parse(document.getElementById('redirect-map').textContent);
  let hash = '';
  try { hash = decodeURIComponent(location.hash.slice(1)); } catch { /* Use the section entry. */ }
  const destination = 'index.html' + location.search + '#' + (routes[hash] || routes['']);
  document.querySelector('[data-redirect-target]').href = destination;
  location.replace(destination);
})();
