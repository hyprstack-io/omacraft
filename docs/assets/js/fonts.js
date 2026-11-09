// Every font omascii can draw with, in one list: the FIGlet fonts it ships
// (figlet.js's collection) and the TheDraw fonts (inline ones draw at once,
// the rest load from assets/fonts/pack/ when picked). Ids are "flf:<name>"
// and "tdf:<omascii id>", and the omascii flag for each is -f "<name>" or
// -f "TDF <id>". Plus the picker: the pill and popup of OmaCraft's title.
(function () {
  "use strict";
  const { el, $, clamp } = Oma;

  let figlet = null;
  const figletReady = new Promise((resolve) => {
    if (window.OMA_FIGLET) { figlet = window.OMA_FIGLET; resolve(); return; }
    addEventListener("figlet-ready", () => { figlet = window.OMA_FIGLET; resolve(); }, { once: true });
  });

  const flf = (window.OMA_FLF || []).map((n) => ({ id: "flf:" + n, name: n, kind: "FIGlet", sub: "FIGlet" }));
  const tdf = TDF.fonts().map((id) => {
    const info = TDF.info(id) || { name: id, type: "block" };
    return { id: "tdf:" + id, name: id, kind: "TheDraw", sub: info.type === "color" ? "colour" : info.type, title: info.name };
  }).filter((f) => f.sub !== "outline");
  const ALL = flf.concat(tdf);
  const byId = new Map(ALL.map((f) => [f.id, f]));

  const flfCache = new Map();
  // → Promise of rows of {ch, fg, bg}; [] when the font can't draw the text.
  async function render(id, text) {
    const f = byId.get(id);
    if (!f) return [];
    if (f.kind === "TheDraw") {
      const tid = id.slice(4);
      if (!(await TDF.load(tid))) return [];
      return TDF.render(tid, text);
    }
    await figletReady;
    const key = f.name + "\u0000" + text;
    if (!flfCache.has(key)) {
      flfCache.set(key, figlet.text(text, { font: f.name, horizontalLayout: "default", verticalLayout: "default" }).catch(() => ""));
    }
    const out = await flfCache.get(key);
    const lines = String(out || "").replace(/\s+$/, "").split("\n");
    while (lines.length && !lines[0].trim()) lines.shift();
    const width = Math.max(0, ...lines.map((l) => [...l].length));
    return lines.map((l) => { const cs = [...l]; return Array.from({ length: width }, (_, i) => ({ ch: cs[i] || " ", fg: null, bg: null })); });
  }

  const flag = (id) => { const f = byId.get(id); return !f ? "" : f.kind === "TheDraw" ? `TDF ${f.name}` : f.name; };

  // ── the picker ──────────────────────────────────────────────
  // picker(anchorButton, { get, set, fallback }) opens a popup under (or
  // above) the button; the arrows browse and use each font as they go.
  let open = null;
  function picker(button, opts) {
    if (open) { const was = open; was.close(); if (was.button === button) return; }
    const kinds = ["All", "FIGlet", "TheDraw"];
    let kind = opts.kind || "All", query = "", list = [], shown = 0, pickIdx = -1;
    const search = el("input", { type: "search", placeholder: `Search ${ALL.length.toLocaleString()} fonts`, "aria-label": "Search fonts", spellcheck: "false" });
    const chips = el("div", { class: "fp-chips", role: "tablist" }, kinds.map((k) => el("button", { type: "button", role: "tab", class: "chip", "data-kind": k, onclick: () => { kind = k; refresh(); } }, k)));
    const dice = el("button", { type: "button", class: "icon-btn", title: "Surprise me", "aria-label": "Surprise me", html: ICON.dice, onclick: () => { if (list.length) use(list[Math.floor(Math.random() * list.length)], true); } });
    const reset = el("button", { type: "button", class: "link", onclick: () => { opts.set(opts.fallback); close(); } }, "Default");
    const ul = el("div", { class: "fp-list", role: "listbox", tabindex: "-1" });
    const count = el("span", { class: "fp-count" });
    const pop = el("div", { class: "fp-pop", role: "dialog", "aria-label": "Fonts" },
      el("div", { class: "fp-head" }, search, dice), el("div", { class: "fp-bar" }, chips, count, reset), ul);
    document.body.append(pop);

    function place() {
      const r = button.getBoundingClientRect(), h = Math.min(440, innerHeight - 24), w = Math.min(360, innerWidth - 24);
      pop.style.width = w + "px"; pop.style.maxHeight = h + "px";
      const below = innerHeight - r.bottom - 12, above = r.top - 12;
      const left = clamp(r.left + r.width / 2 - w / 2, 12, innerWidth - w - 12);
      pop.style.left = left + "px";
      if (below >= Math.min(h, 320) || below >= above) { pop.style.top = r.bottom + 8 + "px"; pop.style.bottom = ""; pop.style.maxHeight = Math.min(h, below) + "px"; pop.dataset.side = "below"; }
      else { pop.style.top = ""; pop.style.bottom = innerHeight - r.top + 8 + "px"; pop.style.maxHeight = Math.min(h, above) + "px"; pop.dataset.side = "above"; }
    }

    function row(f, i) {
      return el("div", { class: "fp-row" + (f.id === opts.get() ? " on" : "") + (i === pickIdx ? " pick" : ""), role: "option", "aria-selected": f.id === opts.get() ? "true" : "false", "data-i": i,
        onclick: () => { use(f); close(); }, onmouseenter: () => { pickIdx = i; mark(); } },
        el("span", { class: "fp-name" }, f.name), el("span", { class: "fp-tag " + (f.kind === "TheDraw" ? "tdf" : "flf") }, f.kind === "TheDraw" ? `TDF · ${f.sub}` : "FIGlet"));
    }
    function more() {
      const next = list.slice(shown, shown + 150);
      next.forEach((f, n) => ul.append(row(f, shown + n)));
      shown += next.length;
    }
    function refresh() {
      chips.querySelectorAll(".chip").forEach((c) => c.classList.toggle("on", c.dataset.kind === kind));
      const q = query.trim().toLowerCase();
      list = ALL.filter((f) => (kind === "All" || f.kind === kind) && (!q || f.name.toLowerCase().includes(q) || (f.title || "").toLowerCase().includes(q)));
      ul.textContent = ""; shown = 0;
      pickIdx = list.findIndex((f) => f.id === opts.get());
      count.textContent = `${list.length.toLocaleString()}`;
      if (!list.length) ul.append(el("div", { class: "fp-empty" }, "No font by that name"));
      more();
      while (pickIdx >= shown && shown < list.length) more();
      const cur = ul.querySelector(".fp-row.pick");
      if (cur) cur.scrollIntoView({ block: "center" });
    }
    function mark() { ul.querySelectorAll(".fp-row").forEach((r) => r.classList.toggle("pick", Number(r.dataset.i) === pickIdx)); }
    function use(f, keepOpen) {
      opts.set(f.id);
      ul.querySelectorAll(".fp-row").forEach((r) => { const on = list[Number(r.dataset.i)] && list[Number(r.dataset.i)].id === f.id; r.classList.toggle("on", on); r.setAttribute("aria-selected", on ? "true" : "false"); });
      if (keepOpen) { pickIdx = list.indexOf(f); while (pickIdx >= shown) more(); mark(); const c = ul.querySelector(".fp-row.pick"); if (c) c.scrollIntoView({ block: "nearest" }); }
    }
    function close() {
      pop.classList.add("closing");
      setTimeout(() => pop.remove(), 140);
      removeEventListener("pointerdown", outside, true); removeEventListener("resize", place);
      button.setAttribute("aria-expanded", "false");
      if (open && open.pop === pop) open = null;
      button.focus({ preventScroll: true });
    }
    const outside = (e) => { if (!pop.contains(e.target) && !button.contains(e.target)) close(); };

    search.addEventListener("input", () => { query = search.value; refresh(); });
    pop.addEventListener("keydown", (e) => {
      if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); close(); }
      else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault();
        if (!list.length) return;
        pickIdx = clamp(pickIdx + (e.key === "ArrowDown" ? 1 : -1), 0, list.length - 1);
        use(list[pickIdx], true);
      } else if (e.key === "Enter") { e.preventDefault(); if (list[pickIdx]) use(list[pickIdx]); close(); }
    });
    ul.addEventListener("scroll", () => { if (ul.scrollTop + ul.clientHeight > ul.scrollHeight - 200) more(); });
    addEventListener("pointerdown", outside, true); addEventListener("resize", place);
    button.setAttribute("aria-expanded", "true");
    place(); refresh();
    requestAnimationFrame(() => { pop.classList.add("on"); search.focus({ preventScroll: true }); });
    open = { close, pop, button };
  }

  const ICON = {
    dice: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3.5" y="3.5" width="17" height="17" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="8.5" cy="8.5" r="1.4"/><circle cx="15.5" cy="15.5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="15.5" cy="8.5" r="1.4"/><circle cx="8.5" cy="15.5" r="1.4"/></svg>',
  };

  window.Fonts = { ALL, byId, render, flag, picker, get count() { return ALL.length; }, figletReady };
})();
