// HyprVYZR: Duckbones is a dark scheme, so Kasm's dashboard always starts in
// its own dark mode (Kasm reads "themecolor" when its bundle starts, which is
// after this script). Marks the page so the theme's rules apply.
(function () {
  try {
    localStorage.setItem("themecolor", "Dark");
    localStorage.setItem("theme", "Dark");
  } catch (e) { /* storage blocked: Kasm falls back to the system setting */ }
  document.documentElement.classList.add("hyprvyze");
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", "#0E101A");
})();
