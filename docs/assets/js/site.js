// OmaCraft's page: the repository layout (files, README, sidebar) and the
// pages people can try (Wallpapers, Window Transitions, Burn My Windows,
// Boot Splash), switched like workspaces, with OmaCraft's own keys.
(function () {
  "use strict";
  const { state, save, on, $, $$, el, toast, copy, download, color: C } = Oma;
  const REPO = window.OMA_REPO || { owner: "hyprstack-io", name: "omacraft", url: "https://github.com/hyprstack-io/omacraft", files: [], languages: [], readme: "", commit: {}, version: "" };
  const DATA = window.OMA_DATA;
  const PAGES = ["code", "wallpapers", "transitions", "burn", "splash", "install"];
  const PAGE_NAMES = { code: "Code", wallpapers: "Wallpapers", transitions: "Window Transitions", burn: "Burn My Windows", splash: "Boot Splash", install: "Install" };
  const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const compact = (n) => (n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k" : String(n));
  const SVG = (d, extra = "") => `<svg viewBox="0 0 16 16" aria-hidden="true"${extra}>${d}</svg>`;

  function rel(iso) {
    if (!iso) return "";
    const s = (Date.now() - new Date(iso).getTime()) / 1000;
    const units = [[60, "second"], [60, "minute"], [24, "hour"], [7, "day"], [4.35, "week"], [12, "month"], [Infinity, "year"]];
    let v = s, i = 0;
    for (; i < units.length - 1 && Math.abs(v) >= units[i][0]; i++) v /= units[i][0];
    const n = Math.max(1, Math.round(v));
    if (i === 0) return "just now";
    return `${n} ${units[i][1]}${n === 1 ? "" : "s"} ago`;
  }
  const date = (iso) => (iso ? new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "");

  // ── links to the real repository ─────────────────────────────
  function links() {
    const u = REPO.url, tag = REPO.release ? REPO.release.tag : "v" + REPO.version;
    const to = { owner: `https://github.com/${REPO.owner}`, repo: u, watch: u + "/subscription", fork: u + "/fork", star: u,
      releases: u + "/releases", release: `${u}/releases/tag/${tag}`, zip: u + "/archive/refs/heads/main.zip", commits: u + "/commits/main",
      license: u + "/blob/main/LICENSE", notices: u + "/blob/main/THIRD-PARTY-NOTICES.md" };
    $$("[data-repo-link]").forEach((a) => { a.href = to[a.dataset.repoLink] || u; if (a.dataset.repoLink !== "owner") a.target = "_blank"; });
    $("#clone-url").textContent = `git clone ${u}.git`;
    $("#run-cmd").textContent = `sh omacraft-${REPO.version}-x86_64.run`;
    $("#src-cmd").textContent = `sudo pacman -S --needed base-devel git\ngit clone --branch ${tag} ${u}.git\ncd omacraft && bin/install`;
  }

  // ── tabs, like workspaces ─────────────────────────────────────
  let current = null, switching = false, queued = null;
  const pageEl = (id) => $(`#page-${id}`);
  function markTabs(id) {
    $$("#tabs a").forEach((a) => a.setAttribute("aria-selected", a.dataset.tab === id ? "true" : "false"));
    placeInk();
  }
  function placeInk() {
    const a = $(`#tabs a[aria-selected="true"]`), ink = $(".tab-ink");
    if (!a) return;
    ink.style.width = a.offsetWidth - 12 + "px";
    ink.style.transform = `translateX(${a.offsetLeft + 6}px)`;
  }
  function clampToView(elm) {
    const r = elm.getBoundingClientRect();
    elm.style.maxHeight = Math.max(240, innerHeight - Math.max(0, r.top) + 40) + "px";
    elm.style.overflow = "hidden";
  }
  const unclamp = (elm) => { elm.style.maxHeight = ""; elm.style.overflow = ""; };
  const tabsTop = () => $("#tabs").getBoundingClientRect().top + scrollY - $(".top").offsetHeight;

  async function go(id, opts = {}) {
    if (!PAGES.includes(id)) id = "code";
    if (id === current) return;
    if (switching) { queued = id; return; }
    const from = current ? pageEl(current) : null, to = pageEl(id);
    const dir = PAGES.indexOf(id) > PAGES.indexOf(current) ? 1 : -1;
    const was = current;
    current = id;
    markTabs(id);
    if (!opts.fromHash && location.hash !== "#" + id) history.pushState(null, "", "#" + id);
    document.title = id === "code" ? "OmaCraft · Omarchy UI/UX Tweakz Suite" : `${PAGE_NAMES[id]} · OmaCraft`;
    Oma.emit("page", { id, was });
    const style = !from || Oma.reduced ? "instant" : state.site.switch;
    // Keep the tabs in view under the header, as GitHub does.
    const top = tabsTop();
    if (from && scrollY > top) scrollTo({ top: Math.max(0, top), behavior: "instant" });
    switching = true;
    try {
      if (style === "burn") {
        const speed = state.burn.speed;
        state.burn.speed = speed * 1.7;
        clampToView(from);
        await Burn.play(from, "close");
        from.hidden = true; unclamp(from);
        to.hidden = false; clampToView(to);
        await Burn.play(to, "open");
        unclamp(to);
        state.burn.speed = speed;
      } else if (style === "workspace") {
        const cs = getComputedStyle(main);
        to.hidden = false;
        Object.assign(from.style, { position: "absolute", top: cs.paddingTop, left: cs.paddingLeft, right: cs.paddingRight });
        main.style.overflow = "clip";
        if (Motion.leaf("workspaces")) await Motion.workspace(from, to, dir);
        else {
          const t = { duration: 420, easing: "cubic-bezier(0.16, 1, 0.3, 1)" };
          await Promise.all([from.animate([{ transform: "none", opacity: 1 }, { transform: `translateX(${-dir * 8}%)`, opacity: 0 }], t).finished,
            to.animate([{ transform: `translateX(${dir * 8}%)`, opacity: 0 }, { transform: "none", opacity: 1 }], t).finished]);
        }
        from.hidden = true; from.style.position = from.style.top = from.style.left = from.style.right = ""; main.style.overflow = "";
      } else {
        if (from) from.hidden = true;
        to.hidden = false;
        if (from && !Oma.reduced) windowsIn(to);
      }
    } catch (e) { if (from) from.hidden = true; to.hidden = false; }
    finally {
      switching = false;
      Oma.emit("shown", id);
      if (queued) { const q = queued; queued = null; go(q); }
    }
  }
  // Panels arrive like Hyprland windows, on the preset's windowsIn.
  function windowsIn(scope) {
    const items = $$(".panel, .box, .page-head", scope).slice(0, 6);
    const box = scope.getBoundingClientRect();
    items.forEach((item, i) => Motion.open(item, box, { delay: i * 45 }));
  }

  // ── Code: files, commit, sidebar ─────────────────────────────
  const ICON_DIR = SVG('<path d="M1.5 3.5a1 1 0 0 1 1-1h3.3l1.5 1.6h6.2a1 1 0 0 1 1 1v7.4a1 1 0 0 1-1 1H2.5a1 1 0 0 1-1-1z"/>');
  const ICON_FILE = SVG('<path d="M3.5 1.5h6l3 3v10h-9zM9.5 1.5v3h3"/>');
  function files() {
    $("#file-rows").replaceChildren(...REPO.files.map((f) => el("div", { class: "file " + f.type },
      el("span", { html: f.type === "dir" ? ICON_DIR : ICON_FILE }),
      el("a", { class: "name", href: `${REPO.url}/${f.type === "dir" ? "tree" : "blob"}/main/${f.name}`, target: "_blank", rel: "noopener" }, f.name),
      el("a", { class: "msg", href: `${REPO.url}/commit/${f.hash}`, target: "_blank", rel: "noopener", title: f.subject }, f.subject),
      el("span", { class: "when", title: date(f.date) }, rel(f.date)))));
    // Folded like GitHub on a phone, so the README's title is in view.
    const rows = $$("#file-rows .file"), keep = 6;
    if (rows.length > keep + 2) {
      rows.slice(keep).forEach((r) => r.classList.add("extra"));
      $("#files").classList.add("folded");
      const more = el("button", { type: "button", class: "file more", "aria-expanded": "false" }, `Show ${rows.length - keep} more files`);
      more.addEventListener("click", () => {
        const folded = $("#files").classList.toggle("folded");
        more.textContent = folded ? `Show ${rows.length - keep} more files` : "Show fewer files";
        more.setAttribute("aria-expanded", folded ? "false" : "true");
      });
      $("#file-rows").append(more);
    }
    const c = REPO.commit;
    $("#commit-author").textContent = c.author || "skll";
    const msg = $("#commit-msg"); msg.textContent = c.subject || ""; msg.href = `${REPO.url}/commit/${c.hash}`; msg.target = "_blank";
    const h = $("#commit-hash"); h.textContent = c.hash || ""; h.href = msg.href; h.target = "_blank";
    $("#commit-date").textContent = rel(c.date);
    $("#commit-count").textContent = `${c.count || 0} Commits`;
    if (REPO.release) { $("#rel-tag").textContent = REPO.release.tag; $("#rel-date").textContent = date(REPO.release.date); }
    $("#lang-bar").replaceChildren(...REPO.languages.map((l) => el("i", { style: `background:${l.color}`, title: `${l.name} ${l.pct.toFixed(1)}%`, "data-w": l.pct })));
    $("#langs").replaceChildren(...REPO.languages.map((l) => el("li", {}, el("i", { style: `background:${l.color}` }), el("b", {}, l.name), el("span", {}, l.pct.toFixed(1) + "%"))));
    requestAnimationFrame(() => setTimeout(() => $$("#lang-bar i").forEach((i) => { i.style.width = i.dataset.w + "%"; }), 120));
  }

  // ── the README, rendered as GitHub would ────────────────────────
  function markdown(src) {
    const blobUrl = (u) => (/^(https?:|mailto:|#)/.test(u) ? u : `${REPO.url}/blob/main/${u.replace(/^\.\//, "")}`);
    function inline(s) {
      const codes = [];
      s = s.replace(/`([^`]+)`/g, (_, c) => { codes.push(`<code>${esc(c)}</code>`); return `\u0000${codes.length - 1}\u0000`; });
      s = esc(s);
      s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, t, u) => `<a href="${esc(blobUrl(u.replace(/&amp;/g, "&")))}" target="_blank" rel="noopener">${t}</a>`);
      s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>").replace(/(^|[^*\w])\*([^*\s][^*]*?)\*(?!\w)/g, "$1<em>$2</em>").replace(/(^|[\s(])_([^_]+)_(?=[\s.,;:)]|$)/g, "$1<em>$2</em>");
      return s.replace(/\u0000(\d+)\u0000/g, (_, i) => codes[Number(i)]);
    }
    const lines = src.replace(/<!--[\s\S]*?-->/g, "").split("\n");
    const out = [], slugs = {};
    let i = 0;
    const blockStart = (l) => /^(#{1,6} |```|\| |- |\* )/.test(l) || !l.trim();
    while (i < lines.length) {
      const l = lines[i];
      if (!l.trim()) { i++; continue; }
      let m;
      if ((m = /^```(\w*)/.exec(l))) {
        const body = []; i++;
        while (i < lines.length && !/^```/.test(lines[i])) body.push(lines[i++]);
        i++;
        out.push(`<pre><code>${esc(body.join("\n"))}</code></pre>`);
      } else if ((m = /^(#{1,6}) (.*)$/.exec(l))) {
        const level = Math.min(3, m[1].length), text = m[2];
        let slug = "md-" + text.toLowerCase().replace(/[^\w\s-]/g, "").trim().replace(/\s+/g, "-");
        if (slugs[slug]) slug += "-" + slugs[slug]++; else slugs[slug] = 1;
        out.push(`<h${level} id="${slug}"><a class="anchor" href="#${slug}" aria-hidden="true">#</a>${inline(text)}</h${level}>`);
        i++;
      } else if (/^\|/.test(l) && i + 1 < lines.length && /^\|\s*:?-{3,}/.test(lines[i + 1])) {
        const cells = (row) => {
          // split on pipes outside inline code, as people mean them
          const parts = [""]; let tick = false;
          for (let k = 0; k < row.length; k++) {
            const ch = row[k];
            if (ch === "`") tick = !tick;
            if (ch === "\\" && row[k + 1] === "|") { parts[parts.length - 1] += "|"; k++; continue; }
            if (ch === "|" && !tick) { parts.push(""); continue; }
            parts[parts.length - 1] += ch;
          }
          if (!parts[0].trim()) parts.shift();
          if (parts.length && !parts[parts.length - 1].trim()) parts.pop();
          return parts.map((c) => inline(c.trim()));
        };
        const head = cells(l); i += 2;
        const body = [];
        while (i < lines.length && /^\|/.test(lines[i])) body.push(cells(lines[i++]));
        out.push(`<table><thead><tr>${head.map((h) => `<th>${h}</th>`).join("")}</tr></thead><tbody>${body.map((r) => `<tr>${r.map((c) => `<td>${c}</td>`).join("")}</tr>`).join("")}</tbody></table>`);
      } else if (/^[-*] /.test(l)) {
        const items = [];
        while (i < lines.length && (/^[-*] /.test(lines[i]) || (/^ {2,}\S/.test(lines[i]) && items.length))) {
          if (/^[-*] /.test(lines[i])) items.push(lines[i].slice(2)); else items[items.length - 1] += " " + lines[i].trim();
          i++;
        }
        out.push(`<ul>${items.map((t) => `<li>${inline(t)}</li>`).join("")}</ul>`);
      } else {
        const para = [];
        while (i < lines.length && !(para.length && blockStart(lines[i])) && lines[i].trim()) para.push(lines[i++]);
        out.push(`<p>${inline(para.join(" "))}</p>`);
      }
    }
    return out.join("\n");
  }

  // ── modules, as on OmaCraft's landing page ──────────────────────
  const MI = {
    wall: '<rect x="1.5" y="2.5" width="13" height="11" rx="1.5"/><path d="m1.5 11 3.8-3.8 3.2 3.2 2-2 4 4"/><circle cx="11" cy="5.8" r="1.2"/>',
    anim: '<path d="M1.5 13C5 13 6 3 9.5 3S14.5 8 14.5 8"/><circle cx="9.5" cy="3" r="1.3"/>',
    burn: '<path d="M8 14.5c2.8 0 4.5-1.8 4.5-4.3 0-3-2.6-4.3-3.1-7.7-1.9 1.2-2.9 3-2.6 5-1-.4-1.6-1.3-1.7-2.3-1.2 1.2-1.6 2.8-1.6 5 0 2.5 1.7 4.3 4.5 4.3Z"/>',
    splash: '<rect x="1.5" y="2.5" width="13" height="11" rx="1.5"/><path d="m4 6 2 2-2 2M7.5 10.5h4"/>',
    saver: '<rect x="1.5" y="2.5" width="13" height="9" rx="1.5"/><path d="M5.5 14h5M8 11.5V14M5 6.5l1.5 1.5L5 9.5M8.5 9.5h2"/>',
    bar: '<rect x="1.5" y="3" width="13" height="3.5" rx="1"/><path d="M3.5 4.75h2M7 4.75h2M10.5 4.75h2M1.5 9h13M1.5 12.5h13"/>',
    dock: '<rect x="2" y="9.5" width="12" height="4" rx="1.5"/><path d="M4.5 11.5h.01M8 11.5h.01M11.5 11.5h.01M5 2.5h6v4.5H5z"/>',
    launch: '<rect x="2" y="2" width="5" height="5" rx="1"/><rect x="9" y="2" width="5" height="5" rx="1"/><rect x="2" y="9" width="5" height="5" rx="1"/><rect x="9" y="9" width="5" height="5" rx="1"/>',
    rofi: '<rect x="2" y="2" width="12" height="12" rx="2"/><path d="M5 5.5h6M5 8h6M5 10.5h3.5"/>',
    lock: '<rect x="3" y="7" width="10" height="7" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2M8 10v1.5"/>',
    cursor: '<path d="m3 2 9.5 6-4.3 1.2L6.5 13.5z"/><path d="m8.2 9.2 3 4"/>',
    dot: '<rect x="1.5" y="2.5" width="13" height="11" rx="1.5"/><path d="M4.5 6.5h3M4.5 9h7M4.5 11.5h5M10.5 6.5h1"/>',
    iso: '<circle cx="8" cy="8" r="6.5"/><circle cx="8" cy="8" r="2"/>',
    keys: '<rect x="1.5" y="4" width="13" height="8.5" rx="1.6"/><path d="M4 7h.01M6.5 7h.01M9 7h.01M11.5 7h.01M5 9.8h6"/>',
    market: '<path d="M2.5 6h11l-1 7.5h-9zM5 6a3 3 0 0 1 6 0"/>',
  };
  const MODULES = [
    { n: "Wallpapers", i: "wall", d: "Wallhaven, your library and folders; the Omarchy theme rebuilt from the wallpaper by four schemes.", go: "wallpapers" },
    { n: "Window Transitions", i: "anim", d: "Hyprland animation presets with their curves, gradient borders, speed, and the Lua they write.", go: "transitions" },
    { n: "Burn My Windows", i: "burn", d: "Open and close effects after the GNOME extension: fire, broken glass, the Doom melt, the Matrix, an old TV.", go: "burn" },
    { n: "Boot Splash", i: "splash", d: "omascii: FIGlet, TheDraw, system fonts or an image, revealed by ttfx intros, built into Plymouth.", go: "splash" },
    { n: "Screensaver", i: "saver", d: "The Omarchy screensaver's word or art, with the same effects as the boot intros.", go: "splash", fx: "matrix" },
    { n: "Main Bar", i: "bar", d: "omabar16 edited in place: themes, looks, colour schemes, widgets dragged between lanes, folder trays." },
    { n: "Side Dock", i: "dock", d: "A magnifying dock on the screen edge that opens into a panel with a tab per AI agent." },
    { n: "Launcher", i: "launch", d: "The launcher's layouts, colour schemes and 14 opening transitions, each playing." },
    { n: "ROFIoma", i: "rofi", d: "rofi popups and swaync notifications: power menus, emoji and glyph pickers, a control-centre builder." },
    { n: "Lock & Logon", i: "lock", d: "Lock, idle and SDDM login screens designed on a live stage that types, fails and unlocks." },
    { n: "Cursors & Icons", i: "cursor", d: "Import and choose icon and cursor themes, tinted from the wallpaper, like nwg-look." },
    { n: "Dotfile Generator", i: "dot", d: "The HyprCraft configurator, for Omarchy's Lua config or plain Hyprland." },
    { n: "OmaBuilds", i: "iso", d: "hyprbuildz's ISO builder as a stage: profile, packages, files, options, ISO, USB." },
    { n: "Alienflare", i: "keys", d: "Per-key lighting for the Alienware x15: designs, 29 animations, colours from the wallpaper." },
    { n: "Marketplaces", i: "market", d: "Every community plugin and theme on omarchy.org, installed with Omarchy's own tools." },
  ];
  function modules() {
    const grid = $("#module-grid");
    grid.replaceChildren(...MODULES.map((m) => {
      const card = el(m.go ? "a" : "div", m.go ? { class: "module try", href: "#" + m.go, onclick: (e) => { e.preventDefault(); if (m.fx) { state.site.splash.effect = m.fx; save(); } go(m.go); } } : { class: "module" },
        el("div", { class: "module-top" }, el("span", { class: "module-ic", html: SVG(MI[m.i]) }), el("b", {}, m.n)),
        el("p", {}, m.d),
        el("span", { class: "go" }, m.go ? "Try it ›" : "In the app"));
      return card;
    }));
    const cards = $$(".module", grid);
    const io = new IntersectionObserver((entries) => entries.forEach((e) => {
      if (!e.isIntersecting) return;
      const i = cards.indexOf(e.target);
      setTimeout(() => e.target.classList.add("in"), (i % 3) * 70 + Math.floor(i / 3) * 40);
      io.unobserve(e.target);
    }), { rootMargin: "0px 0px -40px 0px" });
    cards.forEach((c) => io.observe(c));
  }

  // ── the title: OMACRAFT, revealed by ttfx ──────────────────────
  const hero = { stage: null, order: [], idx: 0, timer: 0, visible: true, token: 0 };
  function heroOrder() {
    // Start where OmaCraft's title does, then every intro once, shuffled.
    const rest = TTFX.ALL.filter((n) => n !== "beams");
    for (let i = rest.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [rest[i], rest[j]] = [rest[j], rest[i]]; }
    return ["beams"].concat(rest);
  }
  async function heroRows() {
    let raw = await Fonts.render(state.site.font, "OMACRAFT");
    if (!raw.length) { state.site.font = "tdf:balistcx"; raw = await Fonts.render(state.site.font, "OMACRAFT"); }
    const kind = (Fonts.byId.get(state.site.font) || {}).kind;
    return Ascii.ink(raw, kind === "TheDraw" ? "theme" : "gradient-h");
  }
  async function heroCompose(play) {
    const f = Fonts.byId.get(state.site.font);
    $("#font-pill-label").textContent = f ? f.name : "balistcx";
    const token = ++hero.token;
    const rows = await heroRows();
    if (token !== hero.token) return;
    hero.stage.set(rows);
    const first = !hero.ready;
    hero.ready = true;
    if (play || (first && current === "code")) heroPlay(hero.order[hero.idx]);
  }
  function heroLabel(name) {
    const n = hero.order.indexOf(name) + 1;
    $("#fx-name").innerHTML = `<b>${esc(name)}</b> ${n}/${hero.order.length}`;
    $("#fx-pill-label").textContent = name;
  }
  function heroPlay(name) {
    clearTimeout(hero.timer);
    hero.idx = Math.max(0, hero.order.indexOf(name));
    heroLabel(name);
    hero.stage.sweep(false);
    hero.stage.play(name, () => {
      hero.stage.sweep(hero.visible);
      if (state.site.auto && hero.visible) hero.timer = setTimeout(() => heroPlay(hero.order[(hero.idx + 1) % hero.order.length]), 4200);
    });
  }
  function heroAuto(onOff) {
    state.site.auto = onOff; save();
    const b = $("#auto-pill");
    b.setAttribute("aria-pressed", onOff ? "true" : "false");
    b.querySelector("span").textContent = onOff ? "Autoplay on" : "Autoplay off";
    clearTimeout(hero.timer);
    if (onOff && !hero.stage.playing) hero.timer = setTimeout(() => heroPlay(hero.order[(hero.idx + 1) % hero.order.length]), 1200);
  }
  function fxMenu(button, pickName, onPick) {
    const menu = $("#fx-menu");
    if (!menu.hidden) { closeMenu(); return; }
    menu.replaceChildren(...TTFX.GROUPS.flatMap((g) => [el("div", { class: "menu-group" }, g.name)].concat(g.effects.map((n) =>
      el("button", { type: "button", role: "menuitem", class: "menu-item" + (n === pickName() ? " on" : ""), onclick: () => { closeMenu(); onPick(n); } }, n,
        el("small", {}, TTFX.isOriginal(n) ? "omascii" : "ttfx"))))));
    menu.hidden = false;
    const r = button.getBoundingClientRect();
    const h = Math.min(innerHeight * 0.7, 520), below = innerHeight - r.bottom - 12;
    menu.style.left = Math.max(12, Math.min(innerWidth - 292, r.left + r.width / 2 - 140)) + "px";
    if (below > 260) { menu.style.top = r.bottom + 8 + "px"; menu.style.bottom = ""; menu.style.maxHeight = Math.min(h, below) + "px"; }
    else { menu.style.top = ""; menu.style.bottom = innerHeight - r.top + 8 + "px"; menu.style.maxHeight = Math.min(h, r.top - 12) + "px"; }
    requestAnimationFrame(() => menu.classList.add("on"));
    const cur = menu.querySelector(".menu-item.on"); if (cur) cur.scrollIntoView({ block: "center" });
    const first = cur || menu.querySelector(".menu-item"); if (first) first.focus({ preventScroll: true });
    menu.onkeydown = (e) => {
      const items = $$(".menu-item", menu), i = items.indexOf(document.activeElement);
      if (e.key === "ArrowDown" || e.key === "ArrowUp") { e.preventDefault(); const n = items[(i + (e.key === "ArrowDown" ? 1 : -1) + items.length) % items.length]; n.focus(); }
      else if (e.key === "Escape") { e.preventDefault(); e.stopPropagation(); closeMenu(); button.focus(); }
    };
    setTimeout(() => addEventListener("pointerdown", outsideMenu, true), 0);
  }
  function outsideMenu(e) { if (!$("#fx-menu").contains(e.target)) closeMenu(); }
  function closeMenu() { const m = $("#fx-menu"); m.classList.remove("on"); m.hidden = true; removeEventListener("pointerdown", outsideMenu, true); }

  function heroInit() {
    hero.stage = TTFX.stage($("#title-canvas"), { maxCell: 13, fill: 0.94 });
    hero.order = heroOrder();
    if (state.site.effect && hero.order.includes(state.site.effect)) hero.idx = hero.order.indexOf(state.site.effect);
    $("#auto-pill").addEventListener("click", () => heroAuto(!state.site.auto));
    heroAuto(state.site.auto);
    clearTimeout(hero.timer);
    $("#replay").addEventListener("click", () => heroPlay(hero.order[hero.idx]));
    $("#title-stage").addEventListener("click", () => heroPlay(hero.order[hero.idx]));
    $("#fx-pill").addEventListener("click", (e) => fxMenu(e.currentTarget, () => hero.order[hero.idx], (n) => { state.site.effect = n; save(); heroPlay(n); }));
    $("#font-pill").addEventListener("click", (e) => Fonts.picker(e.currentTarget, {
      get: () => state.site.font, fallback: "tdf:balistcx",
      set: (id) => { state.site.font = id; save(); heroCompose(true); },
    }));
    new IntersectionObserver(([e]) => {
      hero.visible = e.isIntersecting && current === "code";
      if (!hero.stage.playing) hero.stage.sweep(hero.visible);
    }).observe($("#title-stage"));
    typeTagline();
    heroCompose(false);
  }
  function typeTagline() {
    const text = "Omarchy UI/UX Tweakz Suite", t = $("#tagline-text");
    if (Oma.reduced) { t.textContent = text; return; }
    let i = 0;
    const step = () => { t.textContent = text.slice(0, ++i); if (i < text.length) setTimeout(step, 38 + Math.random() * 40); };
    setTimeout(step, 500);
  }
  function stats() {
    const items = [[11, "shell plugins"], [DATA.presets.length, "transition presets"], [Burn.available().length, "burn effects"], [Fonts.count, "fonts"], [TTFX.ALL.length, "intro effects"]];
    $("#stats").replaceChildren(...items.map(([n, l]) => el("span", {}, el("b", { "data-n": n }, "0"), l)));
    if (Oma.reduced) { $$("#stats b").forEach((b) => { b.textContent = Number(b.dataset.n).toLocaleString(); }); return; }
    const t0 = performance.now();
    const tick = (now) => {
      const k = Math.min(1, (now - t0) / 1400), e = 1 - Math.pow(1 - k, 4);
      $$("#stats b").forEach((b) => { b.textContent = Math.round(Number(b.dataset.n) * e).toLocaleString(); });
      if (k < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    $$("[data-count]").forEach((c) => {
      const n = { walls: Theme.wallList().length, presets: DATA.presets.length, effects: Burn.available().length, fonts: Fonts.count }[c.dataset.count];
      c.textContent = compact(n);
    });
  }

  // ── Wallpapers ─────────────────────────────────────────────────
  function bindSeg(seg, value, onPick) {
    const set = (v) => $$("button", seg).forEach((b) => b.setAttribute("aria-checked", b.dataset.v === v ? "true" : "false"));
    $$("button", seg).forEach((b) => b.addEventListener("click", () => { set(b.dataset.v); onPick(b.dataset.v); }));
    seg.addEventListener("keydown", (e) => {
      if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
      const bs = $$("button", seg), i = bs.findIndex((b) => b.getAttribute("aria-checked") === "true");
      const n = bs[(i + (e.key === "ArrowRight" ? 1 : -1) + bs.length) % bs.length]; n.focus(); n.click(); e.preventDefault();
    });
    set(value);
    return set;
  }
  const fillRange = (r) => r.style.setProperty("--fill", ((r.value - r.min) / (r.max - r.min)) * 100 + "%");
  function range(input, out, value, fmt, onChange) {
    input.value = value; if (out) out.textContent = fmt(value); fillRange(input);
    input.addEventListener("input", () => { const v = Number(input.value); if (out) out.textContent = fmt(v); fillRange(input); onChange(v); });
  }

  let rebuildTimer = 0;
  const rebuild = (opts) => { clearTimeout(rebuildTimer); rebuildTimer = setTimeout(() => Theme.rebuild(opts), 60); };
  function walls() {
    const grid = $("#wall-grid"), list = Theme.wallList();
    $("#wall-count").textContent = list.length;
    grid.replaceChildren(...list.map((w) => {
      const b = el("button", { type: "button", class: "wall", "aria-pressed": state.theme.wallpaper === w.id ? "true" : "false", "aria-label": w.name, "data-id": w.id,
        onclick: () => useWall(w.id) }, el("span", {}, w.name));
      if (w.own) b.append(el("i", { class: "x", role: "button", "aria-label": `Remove ${w.name}`, onclick: (e) => { e.stopPropagation(); removeWall(w.id); } }, "×"));
      return b;
    }));
    // Painting a wallpaper takes a moment: one per frame keeps the page moving.
    const tiles = $$(".wall", grid);
    let i = 0;
    const next = () => { if (i >= tiles.length) return; const t = tiles[i++]; t.style.backgroundImage = `url("${Theme.wallUrl(t.dataset.id)}")`; requestAnimationFrame(next); };
    requestAnimationFrame(next);
  }
  function useWall(id) {
    state.theme.wallpaper = id;
    if (!state.theme.wallColours) state.theme.wallColours = true;
    state.theme.accent = null;
    save(); syncWallControls(); walls(); Theme.rebuild();
  }
  function removeWall(id) {
    state.walls = state.walls.filter((w) => w.id !== id);
    if (state.theme.wallpaper === id) state.theme.wallpaper = "nebula";
    save(); walls(); Theme.rebuild();
  }
  function nextWall() {
    const list = Theme.wallList(), i = list.findIndex((w) => w.id === state.theme.wallpaper);
    useWall(list[(i + 1) % list.length].id);
    toast(list[(i + 1) % list.length].name);
  }
  function syncWallControls() {
    $("#wall-colours").checked = state.theme.wallColours;
    $$("[data-when='wall']").forEach((f) => { f.hidden = !state.theme.wallColours; });
    $$(".wall").forEach((b) => b.setAttribute("aria-pressed", b.dataset.id === state.theme.wallpaper ? "true" : "false"));
    $$(".tchip").forEach((b) => b.setAttribute("aria-pressed", !state.theme.wallColours && b.dataset.id === state.theme.preset ? "true" : "false"));
  }
  function wallpapersInit() {
    walls();
    $("#wall-upload").addEventListener("change", async (e) => {
      const f = e.target.files[0]; e.target.value = "";
      if (!f) return;
      try { const id = await Theme.addUpload(f); walls(); useWall(id); toast("Colours read from your picture"); }
      catch (err) { toast("That picture couldn't be read"); }
    });
    $("#wall-colours").addEventListener("change", (e) => { state.theme.wallColours = e.target.checked; save(); syncWallControls(); Theme.rebuild({ wall: false }); });
    const seg = $("#scheme-seg");
    seg.replaceChildren(...Object.entries(Theme.SCHEMES).map(([id, s]) => el("button", { type: "button", role: "radio", "data-v": id, title: s.note }, s.name)));
    const note = () => { $("#scheme-note").textContent = (Theme.SCHEMES[state.theme.scheme] || {}).note || ""; };
    bindSeg(seg, state.theme.scheme, (v) => { state.theme.scheme = v; state.theme.accent = null; save(); note(); Theme.rebuild({ wall: false }); });
    note();
    range($("#contrast"), $("#contrast-out"), state.theme.contrast, String, (v) => { state.theme.contrast = v; save(); rebuild({ wall: false, animate: false }); });
    $("#preset-chips").replaceChildren(...Object.entries(Theme.PRESETS).map(([id, p]) => el("button", { type: "button", class: "tchip", "data-id": id,
      onclick: () => usePreset(id) }, el("span", { class: "dots" }, [p.c[0], p.c[2], p.c[3], p.c[1]].map((c) => el("i", { style: `background:${c}` }))), p.name)));
    $("#show-wall").checked = state.site.showWall;
    $("#show-wall").addEventListener("change", (e) => { state.site.showWall = e.target.checked; save(); document.body.classList.toggle("no-wall", !state.site.showWall); });
    $("#toml-copy").addEventListener("click", () => copy(Theme.colorsToml(Theme.current), "colors.toml copied"));
    $("#toml-dl").addEventListener("click", () => download("colors.toml", Theme.colorsToml(Theme.current)));
    syncWallControls();
  }
  function usePreset(id) {
    const p = Theme.PRESETS[id];
    state.theme.preset = id; state.theme.wallColours = false;
    if (p.wall) state.theme.wallpaper = p.wall;
    save(); syncWallControls(); Theme.rebuild();
  }
  function nextTheme() {
    const ids = Object.keys(Theme.PRESETS), i = state.theme.wallColours ? -1 : ids.indexOf(state.theme.preset);
    const id = ids[(i + 1) % ids.length];
    usePreset(id); toast(Theme.PRESETS[id].name);
  }
  function onTheme(t) {
    document.documentElement.dataset.mode = C.luminance(t.background) > 0.45 ? "light" : "dark";
    document.body.classList.toggle("no-wall", !state.site.showWall);
    const url = Theme.wallUrl(state.theme.wallpaper);
    $$(".desk, .burn-stage").forEach((d) => { d.style.backgroundImage = url ? `url("${url}")` : ""; });
    $("#clusters").replaceChildren(...Theme.clusters.slice(0, 8).map((c) => el("button", { type: "button", class: "swatch", style: `background:${c.hex}`, title: c.hex,
      "aria-label": `Accent ${c.hex}`, "aria-pressed": state.theme.accent === c.hex ? "true" : "false",
      onclick: () => { state.theme.accent = state.theme.accent === c.hex ? null : c.hex; save(); Theme.rebuild({ wall: false }); } })));
    const keys = ["background", "foreground", "accent", "accent_2", "muted", "red", "orange", "yellow", "green", "cyan", "blue", "magenta"];
    $("#palette-row").replaceChildren(...keys.map((k) => el("button", { type: "button", class: "pal", title: "Copy " + t[k], onclick: () => copy(t[k], t[k]) }, el("i", { style: `background:${t[k]}` }), k.replace("_", " "), el("span", {}, t[k]))));
    $("#toml").innerHTML = esc(Theme.colorsToml(t)).replace(/^(#.*)$/gm, '<span class="c">$1</span>').replace(/^(\w+)( = )(&quot;.*&quot;)$/gm, '<span class="k">$1</span>$2<span class="s">$3</span>');
    syncWallControls();
    term();
  }

  // ── Window Transitions ─────────────────────────────────────────
  const T = { demo: 0, hoverTimer: 0, extra: 0 };
  const winEl = () => el("div", { class: "win", style: `--angle:${100 + Math.random() * 120}deg` }, el("div", { class: "win-in" }, el("i"), el("i"), el("i"), el("i")));
  function deskReset() {
    const a = $("#ws-a"), b = $("#ws-b");
    a.replaceChildren(winEl(), winEl(), winEl()); a.dataset.n = 3;
    b.replaceChildren(winEl(), winEl()); b.dataset.n = 2;
    a.hidden = false; b.hidden = true; a.style.visibility = b.style.visibility = "";
    $$("#ws-dots i").forEach((d, i) => d.classList.toggle("on", i === 0));
  }
  const deskBox = () => $("#desk").getBoundingClientRect();
  const rects = (ws) => $$(".win", ws).map((w) => [w, w.getBoundingClientRect()]);
  async function openWin(preset) {
    const ws = $("#ws-a").hidden ? $("#ws-b") : $("#ws-a");
    if ($$(".win", ws).length >= 4) return closeWin(preset);
    const before = rects(ws), w = winEl();
    ws.append(w); ws.dataset.n = $$(".win", ws).length;
    before.forEach(([e, r]) => Motion.move(e, r, { preset }));
    await Motion.open(w, deskBox(), { preset });
  }
  async function closeWin(preset) {
    const ws = $("#ws-a").hidden ? $("#ws-b") : $("#ws-a");
    const wins = $$(".win", ws);
    if (wins.length <= 1) return openWin(preset);
    const w = wins[wins.length - 1];
    await Motion.close(w, deskBox(), { preset });
    const before = rects(ws).filter(([e]) => e !== w);
    w.remove(); ws.dataset.n = $$(".win", ws).length;
    before.forEach(([e, r]) => Motion.move(e, r, { preset }));
  }
  async function switchWs(preset) {
    const a = $("#ws-a"), b = $("#ws-b"), from = a.hidden ? b : a, to = a.hidden ? a : b, dir = to === b ? 1 : -1;
    to.hidden = false;
    await Motion.workspace(from, to, dir, { preset });
    from.hidden = true;
    $$("#ws-dots i").forEach((d, i) => d.classList.toggle("on", i === (to === a ? 0 : 1)));
  }
  async function demo(presetId) {
    const id = ++T.demo, preset = Motion.presetById(presetId || state.anim.preset);
    $("#stage-preset").textContent = "· " + preset.name;
    deskReset();
    const alive = () => id === T.demo && current === "transitions";
    await wait(200); if (!alive()) return;
    await openWin(preset); await wait(380); if (!alive()) return;
    await switchWs(preset); await wait(420); if (!alive()) return;
    await openWin(preset); await wait(300); if (!alive()) return;
    await switchWs(preset); await wait(380); if (!alive()) return;
    await closeWin(preset);
  }
  function lua() {
    const code = Motion.lua(Motion.presetById(state.anim.preset), state.anim.speed, state.anim, null);
    $("#lua").innerHTML = esc(code).replace(/^(--.*)$/gm, '<span class="c">$1</span>').replace(/(&quot;[^&]*&quot;)/g, '<span class="s">$1</span>').replace(/\b(hl\.\w+)/g, '<span class="k">$1</span>').replace(/\b(\d+(\.\d+)?)\b/g, '<span class="n">$1</span>');
  }
  function usePresetAnim(id) {
    state.anim.preset = id; save();
    $$(".preset").forEach((p) => p.setAttribute("aria-pressed", p.dataset.id === id ? "true" : "false"));
    lua(); demo(id);
    toast(`${Motion.presetById(id).name}: this page's windows and tabs use it too`);
  }
  function transitionsInit() {
    $("#preset-count").textContent = DATA.presets.length;
    $("#preset-grid").replaceChildren(...DATA.presets.map((p) => {
      const a = p.animations || {}, spec = a.windowsIn || a.windows || a.global || [1, "default"];
      return el("button", { type: "button", class: "preset", "data-id": p.id, "aria-pressed": state.anim.preset === p.id ? "true" : "false",
        onclick: () => usePresetAnim(p.id),
        onpointerenter: () => { clearTimeout(T.hoverTimer); T.hoverTimer = setTimeout(() => demo(p.id), 260); },
        onpointerleave: () => clearTimeout(T.hoverTimer) },
        el("b", {}, p.name), el("small", {}, p.description || ""),
        el("div", { html: p.enabled === false ? '<svg viewBox="0 0 100 30"><line class="grid" x1="0" x2="100" y1="15" y2="15"/></svg>' : Motion.curveSvg(spec[1]) }), el("i", { class: "ball" }));
    }));
    $("#anim-on").checked = state.anim.enabled;
    $("#anim-on").addEventListener("change", (e) => { state.anim.enabled = e.target.checked; save(); lua(); });
    range($("#speed"), $("#speed-out"), state.anim.speed, (v) => v + "×", (v) => { state.anim.speed = v; save(); lua(); });
    const fill = (sel, list, val, key) => {
      sel.replaceChildren(...list.map((s) => el("option", { value: s }, s === "preset" ? "As the preset says" : s)));
      sel.value = val;
      sel.addEventListener("change", () => { state.anim[key] = sel.value; save(); lua(); demo(); });
    };
    fill($("#win-style"), Motion.WINDOW_STYLES, state.anim.windowStyle, "windowStyle");
    fill($("#ws-style"), Motion.WORKSPACE_STYLES, state.anim.workspaceStyle, "workspaceStyle");
    $("#t-play").addEventListener("click", () => demo());
    $("#t-open").addEventListener("click", () => { T.demo++; openWin(Motion.presetById(state.anim.preset)); });
    $("#t-close").addEventListener("click", () => { T.demo++; closeWin(Motion.presetById(state.anim.preset)); });
    $("#t-ws").addEventListener("click", () => { T.demo++; switchWs(Motion.presetById(state.anim.preset)); });
    $("#lua-copy").addEventListener("click", () => copy(Motion.lua(Motion.presetById(state.anim.preset), state.anim.speed, state.anim, null), "Lua copied"));
    deskReset(); lua();
    const tick = () => { const d = new Date(); $("#desk-clock").textContent = d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }); };
    tick(); setInterval(tick, 15000);
  }
  function movePreset(step) {
    const ids = DATA.presets.map((p) => p.id), i = ids.indexOf(state.anim.preset);
    usePresetAnim(ids[(i + step + ids.length) % ids.length]);
    const b = $(`.preset[data-id="${state.anim.preset}"]`); if (b) b.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }

  // ── Burn My Windows ────────────────────────────────────────────
  const B = { busy: false };
  function term() {
    const t = Theme.current || {};
    $("#term-body").innerHTML = [
      `<span class="a">        ▄▀▀▀▄</span>   <span class="b">skll</span>@<span class="b">omarchy</span>`,
      `<span class="a">       █ ▄▄ █</span>   <span class="m">─────────────</span>`,
      `<span class="a">  ▄▀▀▀▀ ▀▀ ▀▀▀▄</span>  <span class="a">OS</span> Omarchy 4 x86_64`,
      `<span class="a">  █  OMACRAFT  █</span> <span class="a">WM</span> Hyprland (Lua)`,
      `<span class="a">  ▀▄▄▄▄▄▄▄▄▄▄▄▀</span>  <span class="a">Shell</span> omarchy-shell`,
      `                 <span class="a">Theme</span> ${esc(state.theme.wallColours ? (Theme.SCHEMES[state.theme.scheme] || {}).name + " from the wallpaper" : (Theme.PRESETS[state.theme.preset] || {}).name || "")}`,
      `                 <span class="a">Accent</span> ${esc(t.accent || "")}`,
      ``,
      `<span class="m">~</span> <span class="a">❯</span> omarchy-burn preview ${esc(state.burn.pick)}<span class="a">▌</span>`,
    ].join("\n");
  }
  function burnCounts() { $("#n-close").textContent = state.burn.close.length; $("#n-open").textContent = state.burn.open.length; }
  function burnGrid() {
    const edit = state.site.edit;
    $$(".fx").forEach((f) => f.classList.toggle("in", state.burn[edit].includes(f.dataset.id)));
    burnCounts();
  }
  async function burnPlay(id) {
    id = id || state.burn.pick;
    state.burn.pick = id; save();
    const meta = Burn.effectMeta(id) || { name: id };
    $("#burn-picked").textContent = "· " + meta.name;
    $$(".fx").forEach((f) => f.classList.toggle("playing", f.dataset.id === id));
    term();
    const win = $("#burn-win");
    Burn.stop(win);
    if (B.busy) { B.busy = false; }
    B.busy = true;
    await Burn.play(win, "close", { effect: id });
    await wait(260);
    await Burn.play(win, "open", { effect: id });
    B.busy = false;
    $$(".fx").forEach((f) => f.classList.remove("playing"));
  }
  function burnInit() {
    const tickSvg = SVG('<path d="M3 8.5 6.5 12 13 4.5"/>');
    $("#burn-grid").replaceChildren(...Burn.available().map((m) => {
      const tick = el("span", { class: "tick", role: "checkbox", tabindex: "0", "aria-label": `${m.name} in the list`, html: tickSvg });
      const toggle = (e) => {
        e.stopPropagation();
        const list = state.burn[state.site.edit], i = list.indexOf(m.id);
        if (i >= 0) { if (list.length > 1) list.splice(i, 1); else { toast("Keep at least one effect in the list"); return; } } else list.push(m.id);
        save(); burnGrid();
      };
      tick.addEventListener("click", toggle);
      tick.addEventListener("keydown", (e) => { if (e.key === " " || e.key === "Enter") { e.preventDefault(); toggle(e); } });
      return el("button", { type: "button", class: "fx", "data-id": m.id, style: `--c1:${m.color};--c2:${m.color2}`, title: m.description, onclick: () => burnPlay(m.id) },
        tick, el("b", {}, m.name), el("small", {}, m.description));
    }));
    bindSeg($("#burn-edit"), state.site.edit, (v) => { state.site.edit = v; save(); burnGrid(); });
    $("#burn-random").addEventListener("click", burnRandom);
    $("#burn-play").addEventListener("click", () => burnPlay());
    $("#burn-page").addEventListener("click", burnPage);
    range($("#bspeed"), $("#bspeed-out"), state.burn.speed, (v) => v.toFixed(2) + "×", (v) => { state.burn.speed = v; save(); });
    range($("#bint"), $("#bint-out"), state.burn.intensity, (v) => v.toFixed(2), (v) => { state.burn.intensity = v; save(); });
    const colourMode = state.theme.follow.burn ? "theme" : state.burn.color;
    bindSeg($("#bcolor"), colourMode, (v) => { state.burn.color = v; state.theme.follow.burn = v === "theme"; save(); $("#bcustom").hidden = v !== "custom"; });
    $("#bcustom").value = state.burn.custom; $("#bcustom").hidden = colourMode !== "custom";
    $("#bcustom").addEventListener("input", (e) => { state.burn.custom = e.target.value; save(); });
    bindSeg($("#switch-style"), state.site.switch, (v) => { state.site.switch = v; save(); toast(v === "burn" ? "Tabs burn: the closing and opening lists above" : v === "workspace" ? "Tabs slide like workspaces, on the transition preset" : "Tabs switch at once"); });
    burnGrid(); term();
    $("#burn-picked").textContent = "· " + ((Burn.effectMeta(state.burn.pick) || {}).name || "");
  }
  function burnRandom() { const all = Burn.available(); burnPlay(all[Math.floor(Math.random() * all.length)].id); }
  async function burnPage() {
    const page = pageEl(current), id = state.burn.pick;
    const top = tabsTop();
    if (scrollY > top) scrollTo({ top, behavior: "instant" });
    clampToView(page);
    await Burn.play(page, "close", { effect: id });
    await wait(300);
    await Burn.play(page, "open", { effect: id });
    unclamp(page);
  }

  // ── Boot Splash ────────────────────────────────────────────────
  const S = { stage: null, rows: [], token: 0 };
  const INKS = [["theme", "Theme"], ["font", "Font's own"], ["gradient-h", "Gradient →"], ["gradient-v", "Gradient ↓"], ["rainbow", "Rainbow"], ["mono", "Mono"]];
  async function splashCompose(play) {
    const s = state.site.splash, token = ++S.token;
    const f = Fonts.byId.get(s.font);
    $("#s-font-label").textContent = f ? `${f.name}` : s.font;
    let raw = await Fonts.render(s.font, s.text.trim() || " ");
    if (token !== S.token) return;
    if (!raw.length) raw = [[...(s.text || " ")].map((ch) => ({ ch, fg: null, bg: null }))];
    S.rows = Ascii.border(Ascii.shadow(Ascii.ink(raw, s.ink), s.shadow), s.border);
    S.stage.set(S.rows);
    command();
    if (play) { $("#splash-fx").textContent = s.effect; S.stage.play(s.effect, () => S.stage.sweep(current === "splash")); }
  }
  function command() {
    const s = state.site.splash;
    const q = (v) => `"${String(v).replace(/(["\\$`])/g, "\\$1")}"`;
    const color = { font: "--font-colors", theme: "--no-font-colors --color-mode solid --color accent", "gradient-h": "--no-font-colors --color-mode gradient --gradient horizontal --color accent --color2 foreground",
      "gradient-v": "--no-font-colors --color-mode gradient --gradient vertical --color accent --color2 foreground", rainbow: "--no-font-colors --color-mode rainbow", mono: "--no-font-colors --color-mode solid --color foreground" }[s.ink];
    const fx = TTFX.isOriginal(s.effect) && s.effect !== "matrix" ? s.effect : s.effect;
    $("#s-cmd").innerHTML = esc(`omascii set -t ${q(s.text)} -f ${q(Fonts.flag(s.font))} \\\n  --style animated --effects ${fx} \\\n  --shadow ${s.shadow} --border ${s.border} ${color}\nomascii apply      # build it into the Plymouth boot screen`)
      .replace(/^(omascii \w+)/gm, '<span class="k">$1</span>').replace(/(# .*)$/gm, '<span class="c">$1</span>').replace(/(&quot;[^&]*&quot;)/g, '<span class="s">$1</span>');
  }
  function splashInit() {
    const s = state.site.splash;
    S.stage = TTFX.stage($("#splash-canvas"), { maxCell: 16, fill: 0.9 });
    const text = $("#s-text"); text.value = s.text;
    let t = 0;
    text.addEventListener("input", () => { s.text = text.value; save(); clearTimeout(t); t = setTimeout(() => splashCompose(false), 120); });
    text.addEventListener("keydown", (e) => { if (e.key === "Enter") splashCompose(true); });
    $("#s-font").addEventListener("click", (e) => Fonts.picker(e.currentTarget, { get: () => s.font, fallback: "flf:ANSI Shadow", set: (id) => { s.font = id; save(); splashCompose(true); } }));
    const sel = $("#s-effect");
    sel.replaceChildren(...TTFX.GROUPS.map((g) => el("optgroup", { label: g.name }, g.effects.map((n) => el("option", { value: n }, n)))));
    sel.value = s.effect;
    sel.addEventListener("change", () => { s.effect = sel.value; save(); splashCompose(true); });
    $("#s-play").addEventListener("click", () => splashCompose(true));
    $("#splash-stage").addEventListener("click", () => splashCompose(true));
    const ink = $("#s-ink"); ink.replaceChildren(...INKS.map(([v, n]) => el("button", { type: "button", role: "radio", "data-v": v }, n)));
    bindSeg(ink, s.ink, (v) => { s.ink = v; save(); splashCompose(false); });
    for (const k of ["shadow", "border"]) { const e = $("#s-" + k); e.value = s[k]; e.addEventListener("change", () => { s[k] = e.value; save(); splashCompose(false); }); }
    $("#s-copy-cmd").addEventListener("click", () => copy($("#s-cmd").textContent, "Command copied"));
    $("#s-copy-text").addEventListener("click", () => copy(Ascii.toText(S.rows), "Art copied"));
    $("#s-copy-ansi").addEventListener("click", () => copy(Ascii.toAnsi(S.rows), "ANSI art copied"));
    $("#s-png").addEventListener("click", () => {
      const cv = document.createElement("canvas");
      Ascii.draw(cv, S.rows, 12, null, 1);
      const out = document.createElement("canvas"), pad = 48;
      out.width = cv.width + pad * 2; out.height = cv.height + pad * 2;
      const g = out.getContext("2d"); g.fillStyle = "#050505"; g.fillRect(0, 0, out.width, out.height); g.drawImage(cv, pad, pad);
      out.toBlob((b) => download("omascii.png", b));
    });
    splashCompose(false);
  }

  // ── search palette ──────────────────────────────────────────────
  let palItems = [], palPick = 0;
  function palIndex() {
    const items = [];
    PAGES.forEach((p, i) => items.push({ name: PAGE_NAMES[p], kind: `page · ${i + 1}`, run: () => go(p) }));
    DATA.presets.forEach((p) => items.push({ name: p.name, kind: "transition", run: () => { go("transitions"); usePresetAnim(p.id); } }));
    Burn.available().forEach((m) => items.push({ name: m.name, kind: "burn effect", run: () => { go("burn"); setTimeout(() => burnPlay(m.id), 500); } }));
    Object.entries(Theme.PRESETS).forEach(([id, p]) => items.push({ name: p.name, kind: "theme", run: () => usePreset(id) }));
    Theme.wallList().forEach((w) => items.push({ name: w.name, kind: "wallpaper", run: () => useWall(w.id) }));
    TTFX.ALL.forEach((n) => items.push({ name: n, kind: "intro effect", run: () => { go("code"); heroPlay(n); } }));
    REPO.files.forEach((f) => items.push({ name: f.name, kind: f.type === "dir" ? "folder" : "file", run: () => open(`${REPO.url}/${f.type === "dir" ? "tree" : "blob"}/main/${f.name}`, "_blank", "noopener") }));
    Fonts.ALL.forEach((f) => items.push({ name: f.name, kind: f.kind === "TheDraw" ? "TheDraw font" : "FIGlet font", run: () => { state.site.font = f.id; save(); go("code"); heroCompose(true); } }));
    return items;
  }
  let PAL = null;
  function palette(show = true) {
    const ov = $("#palette");
    if (!show) { ov.hidden = true; return; }
    PAL = PAL || palIndex();
    ov.hidden = false;
    const input = $("#pal-input"); input.value = ""; palFilter(""); input.focus();
  }
  function palFilter(q) {
    q = q.trim().toLowerCase();
    const scored = [];
    for (const it of PAL) {
      const n = it.name.toLowerCase();
      if (!q) { if (/page|transition|theme/.test(it.kind) && scored.length < 30) scored.push([0, it]); continue; }
      const i = n.indexOf(q);
      if (i < 0) continue;
      scored.push([(i === 0 ? 0 : 1) + (i === 0 && it.kind.startsWith("page") ? -1 : 0) + (/font/.test(it.kind) ? 0.5 : 0) + n.length / 200, it]);
    }
    scored.sort((a, b) => a[0] - b[0]);
    palItems = scored.slice(0, 60).map((s) => s[1]); palPick = 0;
    const mark = (n) => { if (!q) return esc(n); const i = n.toLowerCase().indexOf(q); return esc(n.slice(0, i)) + "<mark>" + esc(n.slice(i, i + q.length)) + "</mark>" + esc(n.slice(i + q.length)); };
    const list = $("#pal-list");
    list.replaceChildren(...(palItems.length ? palItems.map((it, i) => el("button", { type: "button", role: "option", class: "pal-item" + (i === 0 ? " pick" : ""), onclick: () => { palette(false); it.run(); }, onmouseenter: () => { palPick = i; palMark(); } },
      el("span", { html: mark(it.name) }), el("span", { class: "kind" }, it.kind))) : [el("div", { class: "pal-empty" }, "Nothing by that name")]));
  }
  function palMark() { $$(".pal-item").forEach((b, i) => b.classList.toggle("pick", i === palPick)); const p = $(".pal-item.pick"); if (p) p.scrollIntoView({ block: "nearest" }); }

  // ── shortcuts ──────────────────────────────────────────────────
  const KEYS = [
    ["Everywhere", [["1 … 6", "Switch tabs"], ["Ctrl PgUp / PgDn", "Previous / next tab"], ["/", "Search everything"], ["T", "Next Omarchy theme"], ["?", "These shortcuts"], ["Esc", "Close, or leave a field"]]],
    ["Code", [["Space", "Play the title again"], ["A", "Autoplay on or off"], ["E", "Pick the intro effect"], ["F", "Pick the font"]]],
    ["Wallpapers", [["N", "Next wallpaper"], ["U", "Use your own picture"], ["C", "Colours from the wallpaper on or off"]]],
    ["Window Transitions", [["P", "Play the stage"], ["← →", "Previous / next preset"], ["+ - 0", "Faster, slower, preset speed"], ["O / X / W", "Open, close, switch workspace"]]],
    ["Burn My Windows", [["P", "Play the picked effect"], ["R", "A random effect"], ["C / O", "Edit the closing / opening list"], ["B", "Burn this page"]]],
    ["Boot Splash", [["Ctrl P", "Play the intro"], ["F", "Pick the font"]]],
  ];
  function help(show = true) {
    const ov = $("#help");
    if (!show) { ov.hidden = true; return; }
    $("#keys").replaceChildren(...KEYS.flatMap(([h, rows]) => [el("h3", {}, h)].concat(rows.map(([k, d]) => el("div", { class: "key" }, el("span", {}, d), el("span", {}, k.split(" / ").map((x) => el("kbd", {}, x))))))));
    ov.hidden = false; $("[data-close]", ov).focus();
  }

  document.addEventListener("keydown", (e) => {
    const pal = !$("#palette").hidden, hlp = !$("#help").hidden;
    if (pal) {
      if (e.key === "Escape") { palette(false); e.preventDefault(); }
      else if (e.key === "ArrowDown" || e.key === "ArrowUp") { palPick = Math.max(0, Math.min(palItems.length - 1, palPick + (e.key === "ArrowDown" ? 1 : -1))); palMark(); e.preventDefault(); }
      else if (e.key === "Enter" && palItems[palPick]) { const it = palItems[palPick]; palette(false); it.run(); e.preventDefault(); }
      return;
    }
    if (hlp) { if (e.key === "Escape" || e.key === "?") { help(false); e.preventDefault(); } return; }
    if (document.querySelector(".fp-pop") || !$("#fx-menu").hidden) return;
    if (e.key === "Escape") { if (Oma.typing(e)) e.target.blur(); $("#code-pop").hidden = true; return; }
    if (e.ctrlKey && (e.key === "p" || e.key === "P") && current === "splash") { splashCompose(true); e.preventDefault(); return; }
    if (Oma.typing(e) || e.altKey || e.metaKey) return;
    const k = e.key, lower = k.length === 1 ? k.toLowerCase() : k;
    if (e.ctrlKey) {
      if (k === "PageDown" || k === "PageUp") { const i = PAGES.indexOf(current); go(PAGES[(i + (k === "PageDown" ? 1 : -1) + PAGES.length) % PAGES.length]); e.preventDefault(); }
      return;
    }
    if (/^[1-6]$/.test(k)) { go(PAGES[Number(k) - 1]); return; }
    if (k === "/") { palette(); e.preventDefault(); return; }
    if (k === "?") { help(); return; }
    if (lower === "t" && current !== "transitions") { nextTheme(); return; }
    switch (current) {
      case "code":
        if (k === " ") { heroPlay(hero.order[hero.idx]); e.preventDefault(); }
        else if (lower === "a") heroAuto(!state.site.auto);
        else if (lower === "e") $("#fx-pill").click();
        else if (lower === "f") $("#font-pill").click();
        break;
      case "wallpapers":
        if (lower === "n") nextWall();
        else if (lower === "u") $("#wall-upload").click();
        else if (lower === "c") $("#wall-colours").click();
        break;
      case "transitions":
        if (lower === "p") demo();
        else if (k === "ArrowRight") { movePreset(1); e.preventDefault(); }
        else if (k === "ArrowLeft") { movePreset(-1); e.preventDefault(); }
        else if (k === "+" || k === "=" || k === "-" || k === "0") {
          const r = $("#speed"); r.value = k === "0" ? 1 : Math.max(0.25, Math.min(3, Number(r.value) + (k === "-" ? -0.25 : 0.25))); r.dispatchEvent(new Event("input"));
        } else if (lower === "t") nextTheme();
        else if (lower === "o") $("#t-open").click();
        else if (lower === "x") $("#t-close").click();
        else if (lower === "w") $("#t-ws").click();
        break;
      case "burn":
        if (lower === "p") burnPlay();
        else if (lower === "r") burnRandom();
        else if (lower === "c" || lower === "o") $(`#burn-edit [data-v="${lower === "c" ? "close" : "open"}"]`).click();
        else if (lower === "b") burnPage();
        break;
      case "splash":
        if (lower === "f") $("#s-font").click();
        break;
    }
  });

  // ── wiring ────────────────────────────────────────────────────
  function wire() {
    $$("#tabs a").forEach((a) => a.addEventListener("click", (e) => { e.preventDefault(); go(a.dataset.tab); }));
    $$('a[href^="#"]').forEach((a) => {
      const id = a.getAttribute("href").slice(1);
      if (PAGES.includes(id) && !a.closest("#tabs")) a.addEventListener("click", (e) => { e.preventDefault(); go(id); });
    });
    addEventListener("popstate", () => go(location.hash.slice(1) || "code", { fromHash: true }));
    addEventListener("resize", placeInk);
    document.fonts && document.fonts.ready.then(placeInk);
    $("#search-btn").addEventListener("click", () => palette());
    $("[data-act='palette']").addEventListener("click", () => palette());
    $("#pal-input").addEventListener("input", (e) => palFilter(e.target.value));
    $("#palette").addEventListener("click", (e) => { if (e.target.id === "palette") palette(false); });
    $("#help-btn").addEventListener("click", () => help());
    $("#help").addEventListener("click", (e) => { if (e.target.id === "help" || e.target.closest("[data-close]")) help(false); });
    $("#theme-btn").addEventListener("click", nextTheme);
    $("#branch-btn").addEventListener("click", () => toast(`main is the only branch; ${REPO.release ? REPO.release.tag : "v" + REPO.version} is the latest tag`));
    const pop = $("#code-pop"), cb = $("#code-btn");
    cb.addEventListener("click", () => { pop.hidden = !pop.hidden; cb.setAttribute("aria-expanded", pop.hidden ? "false" : "true"); });
    addEventListener("pointerdown", (e) => { if (!pop.hidden && !pop.contains(e.target) && !cb.contains(e.target)) { pop.hidden = true; cb.setAttribute("aria-expanded", "false"); } });
    document.addEventListener("click", (e) => {
      const b = e.target.closest("[data-copy], [data-copy-from]");
      if (!b) return;
      e.preventDefault();
      copy(b.dataset.copy || $("#" + b.dataset.copyFrom).textContent, "Copied");
    });
    on("page", ({ id }) => {
      hero.visible = id === "code";
      if (id !== "code") { clearTimeout(hero.timer); hero.stage.sweep(false); }
      if (id !== "splash" && S.stage) S.stage.sweep(false);
    });
    on("shown", (id) => {
      if (id === "code") { hero.visible = true; if (hero.ready) heroPlay(hero.order[hero.idx]); }
      if (id === "transitions") demo();
      if (id === "splash") splashCompose(true);
    });
    on("theme", (t) => {
      onTheme(t);
      if (hero.stage) heroCompose(false);
      if (S.stage) splashCompose(false);
    });
  }

  async function start() {
    links();
    files();
    $("#readme-md").innerHTML = markdown(REPO.readme || "");
    modules();
    wire();
    await Theme.rebuild({ animate: false });
    wallpapersInit();
    transitionsInit();
    burnInit();
    splashInit();
    heroInit();
    stats();
    onTheme(Theme.current);
    const first = location.hash.slice(1);
    current = null;
    $$(".page").forEach((p) => { p.hidden = true; });
    if (PAGES.includes(first)) go(first, { fromHash: true });
    else { go("code", { fromHash: true }); if (first) { const t = document.getElementById(first); if (t) setTimeout(() => t.scrollIntoView(), 50); } }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
