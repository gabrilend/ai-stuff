// The sidebar filter: typing narrows the list to matching page names,
// opening every section that still has a match.
function filterNav(q) {
  q = q.toLowerCase();
  document.querySelectorAll('nav details').forEach(function (d) {
    var any = false;
    d.querySelectorAll('a').forEach(function (a) {
      var hit = !q || a.textContent.toLowerCase().indexOf(q) >= 0;
      a.style.display = hit ? '' : 'none';
      any = any || hit;
    });
    d.style.display = any ? '' : 'none';
    if (q && any) d.open = true;
  });
}
// Keep the sidebar scrolled to the page you are on.
window.addEventListener('load', function () {
  var here = document.querySelector('nav a.here');
  if (here) here.scrollIntoView({ block: 'center' });
});
