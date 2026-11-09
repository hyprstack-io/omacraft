// Wallpapers and the theme built from them, after OmaCraft's Wallpapers page
// (hyprskin): pick a wallpaper and every colour on the site follows it, by
// one of four schemes, or pick an Omarchy theme instead.
(function () {
  "use strict";
  const { state, save, emit, color: C } = Oma;

  // ── wallpapers, painted here so the site carries no image files ─────
  const W = 1600, H = 900;
  function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
  function stars(g, r, n, max = 1.4) {
    for (let i = 0; i < n; i++) { g.globalAlpha = r() * 0.8 + 0.2; g.fillStyle = "#fff"; g.fillRect(r() * W, r() * H, r() * max, r() * max); }
    g.globalAlpha = 1;
  }
  function blob(g, x, y, rad, col, a = 1) {
    const gr = g.createRadialGradient(x, y, 0, x, y, rad);
    gr.addColorStop(0, C.rgba(col, a)); gr.addColorStop(1, C.rgba(col, 0));
    g.fillStyle = gr; g.fillRect(0, 0, W, H);
  }
  function ridge(g, r, base, amp, col, rough = 0.5) {
    g.fillStyle = col; g.beginPath(); g.moveTo(0, H);
    let y = base;
    for (let x = 0; x <= W; x += 8) { y += (r() - 0.5) * amp * rough; y = y * 0.96 + base * 0.04; g.lineTo(x, y + Math.sin(x / 140) * amp * 0.4); }
    g.lineTo(W, H); g.fill();
  }

  const PAINTERS = {
    nebula: { name: "Nebula", paint(g, r) {
      g.fillStyle = "#07071a"; g.fillRect(0, 0, W, H);
      blob(g, 420, 380, 620, "#5b3cc4", .55); blob(g, 1150, 520, 560, "#c43c8f", .42); blob(g, 900, 250, 380, "#3c8fc4", .4); blob(g, 300, 760, 420, "#1d2b8a", .5);
      stars(g, r, 900);
    } },
    synthwave: { name: "Synthwave", paint(g) {
      const sky = g.createLinearGradient(0, 0, 0, H * .62); sky.addColorStop(0, "#0d0221"); sky.addColorStop(.6, "#3a0b5c"); sky.addColorStop(1, "#ff2a6d");
      g.fillStyle = sky; g.fillRect(0, 0, W, H * .62);
      const sun = g.createLinearGradient(0, 180, 0, 560); sun.addColorStop(0, "#ffd319"); sun.addColorStop(1, "#ff2975");
      g.save(); g.beginPath(); g.arc(W / 2, 470, 230, 0, Math.PI * 2); g.clip(); g.fillStyle = sun; g.fillRect(0, 0, W, H);
      g.fillStyle = "#3a0b5c"; for (let i = 0; i < 9; i++) g.fillRect(0, 400 + i * 22, W, 3 + i * 1.6); g.restore();
      g.fillStyle = "#0d0221"; g.fillRect(0, H * .62, W, H);
      g.strokeStyle = "#d300c5"; g.lineWidth = 2; g.globalAlpha = .8;
      for (let i = -20; i <= 20; i++) { g.beginPath(); g.moveTo(W / 2 + i * 18, H * .62); g.lineTo(W / 2 + i * 160, H); g.stroke(); }
      for (let i = 0; i < 14; i++) { const y = H * .62 + Math.pow(i / 14, 2) * H * .38; g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
      g.globalAlpha = 1;
    } },
    aurora: { name: "Aurora", paint(g, r) {
      const sky = g.createLinearGradient(0, 0, 0, H); sky.addColorStop(0, "#020b14"); sky.addColorStop(1, "#0a2a33"); g.fillStyle = sky; g.fillRect(0, 0, W, H);
      stars(g, r, 500, 1.2);
      g.globalCompositeOperation = "lighter";
      for (let band = 0; band < 3; band++) {
        const col = ["#00ff87", "#60efff", "#b16cea"][band];
        for (let x = 0; x < W; x += 3) {
          const top = 140 + band * 60 + Math.sin(x / 210 + band) * 70 + Math.sin(x / 63) * 14;
          const len = 220 + Math.sin(x / 120 + band * 2) * 90;
          const gr = g.createLinearGradient(0, top, 0, top + len);
          gr.addColorStop(0, C.rgba(col, 0)); gr.addColorStop(.7, C.rgba(col, .09)); gr.addColorStop(1, C.rgba(col, 0));
          g.fillStyle = gr; g.fillRect(x, top, 3, len);
        }
      }
      g.globalCompositeOperation = "source-over";
      ridge(g, r, 690, 60, "#041217"); ridge(g, r, 770, 40, "#02080b");
    } },
    forest: { name: "Everpine", paint(g, r) {
      const sky = g.createLinearGradient(0, 0, 0, H); sky.addColorStop(0, "#2b3339"); sky.addColorStop(1, "#a7c080"); g.fillStyle = sky; g.fillRect(0, 0, W, H);
      blob(g, 1150, 260, 300, "#dbbc7f", .5);
      ["#56635f", "#475258", "#3a454a", "#2d353b", "#232a2e"].forEach((c, i) => ridge(g, r, 380 + i * 105, 120 - i * 14, c, .9));
    } },
    ember: { name: "Ember Dunes", paint(g, r) {
      const sky = g.createLinearGradient(0, 0, 0, H); sky.addColorStop(0, "#1a0b08"); sky.addColorStop(.55, "#5c1d0c"); sky.addColorStop(1, "#ff7a1a"); g.fillStyle = sky; g.fillRect(0, 0, W, H);
      blob(g, 400, 520, 260, "#ffb347", .55);
      ["#8a2c0d", "#6a1f08", "#4a1505", "#2b0b03"].forEach((c, i) => {
        g.fillStyle = c; g.beginPath(); g.moveTo(0, H);
        for (let x = 0; x <= W; x += 10) g.lineTo(x, 520 + i * 95 + Math.sin(x / (260 - i * 30) + i * 1.7) * (50 - i * 6));
        g.lineTo(W, H); g.fill();
      });
      stars(g, r, 120, 1);
    } },
    abyss: { name: "Abyss", paint(g, r) {
      const sea = g.createLinearGradient(0, 0, 0, H); sea.addColorStop(0, "#0b3a5c"); sea.addColorStop(1, "#020812"); g.fillStyle = sea; g.fillRect(0, 0, W, H);
      g.globalCompositeOperation = "lighter";
      for (let i = 0; i < 14; i++) { const x = r() * W; const gr = g.createLinearGradient(x, 0, x + 200, H); gr.addColorStop(0, "rgba(120,200,255,.10)"); gr.addColorStop(1, "rgba(120,200,255,0)"); g.fillStyle = gr; g.beginPath(); g.moveTo(x, 0); g.lineTo(x + 60, 0); g.lineTo(x + 340, H); g.lineTo(x + 180, H); g.fill(); }
      g.globalCompositeOperation = "source-over";
      for (let i = 0; i < 160; i++) { g.fillStyle = `rgba(160,230,255,${r() * .5})`; g.beginPath(); g.arc(r() * W, r() * H, r() * 3, 0, 7); g.fill(); }
      blob(g, 1200, 700, 260, "#2ee6c5", .28);
    } },
    sakura: { name: "Rosé Dusk", paint(g, r) {
      const sky = g.createLinearGradient(0, 0, W, H); sky.addColorStop(0, "#191724"); sky.addColorStop(1, "#403d52"); g.fillStyle = sky; g.fillRect(0, 0, W, H);
      for (let i = 0; i < 60; i++) blob(g, r() * W, r() * H, 30 + r() * 120, ["#ebbcba", "#eb6f92", "#c4a7e7", "#f6c177"][i % 4], .12 + r() * .18);
    } },
    monolith: { name: "Monolith", paint(g, r) {
      g.fillStyle = "#0c0c0c"; g.fillRect(0, 0, W, H);
      for (let i = 0; i < 4000; i++) { g.fillStyle = `rgba(255,255,255,${r() * .03})`; g.fillRect(r() * W, r() * H, 2, 2); }
      g.fillStyle = "#151515"; g.fillRect(W * .58, 0, 260, H);
      const line = g.createLinearGradient(0, 0, 0, H); line.addColorStop(0, "rgba(234,175,90,0)"); line.addColorStop(.5, "#eaaf5a"); line.addColorStop(1, "rgba(234,175,90,0)");
      g.fillStyle = line; g.fillRect(W * .58 - 2, 0, 2, H);
      blob(g, W * .58, H * .5, 300, "#eaaf5a", .12);
    } },
    circuit: { name: "Circuit", paint(g, r) {
      g.fillStyle = "#06101a"; g.fillRect(0, 0, W, H);
      g.lineWidth = 2;
      for (let i = 0; i < 90; i++) {
        let x = Math.round(r() * W / 40) * 40, y = Math.round(r() * H / 40) * 40;
        const col = r() < .7 ? "#05d9e8" : "#ff2a6d";
        g.strokeStyle = C.rgba(col, .25 + r() * .5); g.beginPath(); g.moveTo(x, y);
        for (let s = 0; s < 6; s++) { if (r() < .5) x += (r() < .5 ? -1 : 1) * 40 * (1 + Math.floor(r() * 4)); else y += (r() < .5 ? -1 : 1) * 40 * (1 + Math.floor(r() * 3)); g.lineTo(x, y); }
        g.stroke(); g.fillStyle = col; g.fillRect(x - 3, y - 3, 6, 6);
      }
      blob(g, W / 2, H / 2, 600, "#05d9e8", .1);
    } },
  };

  const painted = {};
  function wallUrl(id) {
    if (painted[id]) return painted[id];
    const up = state.walls.find((w) => w.id === id);
    if (up) return up.url;
    const p = PAINTERS[id];
    if (!p) return null;
    const cv = document.createElement("canvas"); cv.width = W; cv.height = H;
    p.paint(cv.getContext("2d"), rng(id.length * 9973 + id.charCodeAt(0) * 31));
    painted[id] = cv.toDataURL("image/jpeg", 0.88);
    return painted[id];
  }
  function wallList() {
    return Object.entries(PAINTERS).map(([id, p]) => ({ id, name: p.name, own: false }))
      .concat(state.walls.map((w) => ({ id: w.id, name: w.name, own: true })));
  }

  // ── reading a wallpaper's colours ─────────────────────
  function loadImage(url) {
    return new Promise((res, rej) => { const im = new Image(); im.onload = () => res(im); im.onerror = rej; im.src = url; });
  }
  // k-means over a 96×54 copy of the picture, in RGB.
  async function extract(url, k = 8) {
    const im = await loadImage(url);
    const cv = document.createElement("canvas"); cv.width = 96; cv.height = 54;
    const g = cv.getContext("2d"); g.drawImage(im, 0, 0, 96, 54);
    const d = g.getImageData(0, 0, 96, 54).data;
    const px = [];
    for (let i = 0; i < d.length; i += 4) px.push([d[i], d[i + 1], d[i + 2]]);
    const sorted = px.slice().sort((a, b) => (a[0] + a[1] + a[2]) - (b[0] + b[1] + b[2]));
    let cents = Array.from({ length: k }, (_, i) => sorted[Math.floor((i + 0.5) / k * sorted.length)].slice());
    let assign = new Array(px.length).fill(0);
    for (let it = 0; it < 10; it++) {
      const sum = cents.map(() => [0, 0, 0, 0]);
      px.forEach((p, i) => {
        let best = 0, bd = 1e9;
        cents.forEach((c, j) => { const dd = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2; if (dd < bd) { bd = dd; best = j; } });
        assign[i] = best; const s = sum[best]; s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; s[3]++;
      });
      cents = cents.map((c, j) => (sum[j][3] ? [sum[j][0] / sum[j][3], sum[j][1] / sum[j][3], sum[j][2] / sum[j][3]] : c));
    }
    const counts = cents.map(() => 0); assign.forEach((a) => counts[a]++);
    return cents.map((c, i) => {
      const hex = C.rgb2hex(...c); const [h, s, l] = C.rgb2hsl(...c);
      return { hex, h, s, l, w: counts[i] / px.length };
    }).filter((c) => c.w > 0.004).sort((a, b) => b.w - a.w);
  }

  // ── schemes: wallpaper colours → an Omarchy colors.toml ──
  const ANSI_HUES = { red: 355, orange: 25, yellow: 42, green: 100, cyan: 185, blue: 220, magenta: 290 };
  const hueDist = (a, b) => { const d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d; };

  function derive(t, contrast) {
    // the shared tail: shades of background and foreground, selection, ink
    const k = contrast / 100;
    const [bh, bs] = C.hexHsl(t.background);
    t.background = C.hsl(bh, Math.min(bs, .35), .115 - k * .065);
    t.dark_background = C.mix(t.background, "#000000", .25);
    t.darker_background = C.mix(t.background, "#000000", .45);
    t.lighter_background = C.mix(t.background, t.foreground, .09);
    const [fh, fs] = C.hexHsl(t.foreground);
    t.foreground = C.hsl(fh, Math.min(fs, .4), .80 + k * .14);
    t.dark_foreground = C.mix(t.foreground, t.background, .22);
    t.light_foreground = C.mix(t.foreground, "#ffffff", .2);
    t.bright_foreground = C.mix(t.foreground, "#ffffff", .4);
    t.muted = C.mix(t.background, t.foreground, .38);
    t.selection = t.lighter_background;
    t.selection_foreground = t.foreground;
    // keep the accent readable on the background
    let [ah, as, al] = C.hexHsl(t.accent);
    while (C.contrast(C.hsl(ah, as, al), t.background) < 4.2 && al < .92) al += .03;
    t.accent = C.hsl(ah, as, al);
    t.accent_2 = t.accent_2 || C.hsl(ah + 50, as, al);
    for (const name of Object.keys(ANSI_HUES)) {
      t["bright_" + name] = C.mix(t[name], "#ffffff", .22);
    }
    t.brown = C.mix(t.orange, t.background, .45);
    t.accent_ink = C.contrast(t.accent, "#000000") > C.contrast(t.accent, "#ffffff") ? C.mix(t.darker_background, "#000000", .3) : "#ffffff";
    return t;
  }

  function ansi(baseHue, sat, light, pull) {
    const out = {};
    for (const [name, h] of Object.entries(ANSI_HUES)) {
      let d = ((baseHue - h + 540) % 360) - 180;
      out[name] = C.hsl(h + d * pull, sat, light);
    }
    return out;
  }

  const vivid = (cs) => cs.filter((c) => c.l > .14 && c.l < .9).sort((a, b) => (b.s * Math.pow(b.w, .3) * (1 - Math.abs(b.l - .5))) - (a.s * Math.pow(a.w, .3) * (1 - Math.abs(a.l - .5))))[0] || cs[0];

  const SCHEMES = {
    material: { name: "Material", note: "One source colour, tonal shades of it", build(cs, ct, pick) {
      const src = pick || vivid(cs);
      const h = src.h;
      return finish(Object.assign({
        background: C.hsl(h, .22, .08), foreground: C.hsl(h, .2, .9),
        accent: C.hsl(h, Math.max(.55, src.s), .7), accent_2: C.hsl(h + 60, .5, .74),
      }, ansi(h, .62, .7, .12)), ct);
    } },
    wallbash: { name: "Wallbash", note: "The dominant colour as the base, the most distinct as the accent", build(cs, ct, pick) {
      const dom = cs[0];
      const acc = pick || cs.slice(1).sort((a, b) => (hueDist(b.h, dom.h) * b.s + b.s * 80) - (hueDist(a.h, dom.h) * a.s + a.s * 80))[0] || dom;
      const rest = cs.filter((c) => c !== dom && c !== acc && c.s > .15);
      const a = ansi(acc.h, .58, .68, .25);
      // nudge each ANSI slot toward the nearest wallpaper hue
      for (const name of Object.keys(ANSI_HUES)) {
        const near = rest.slice().sort((x, y) => hueDist(x.h, ANSI_HUES[name]) - hueDist(y.h, ANSI_HUES[name]))[0];
        if (near && hueDist(near.h, ANSI_HUES[name]) < 45) a[name] = C.hsl(near.h, Math.max(.45, near.s), .68);
      }
      return finish(Object.assign({ background: C.hsl(dom.h, dom.s * .6, .08), foreground: C.hsl(dom.h, .18, .88), accent: C.hsl(acc.h, Math.max(.5, acc.s), .68), accent_2: C.hsl(dom.h, Math.max(.4, dom.s), .7) }, a), ct);
    } },
    pywal: { name: "pywal", note: "Darkest to lightest, the wallpaper's own colours in order", build(cs, ct, pick) {
      const byL = cs.slice().sort((a, b) => a.l - b.l);
      const dark = byL[0], light = byL[byL.length - 1];
      const mids = cs.filter((c) => c !== dark && c !== light).sort((a, b) => a.h - b.h);
      while (mids.length < 6) mids.push(mids[mids.length % Math.max(1, mids.length)] || dark);
      const names = ["red", "green", "yellow", "blue", "magenta", "cyan"];
      const t = { background: dark.hex, foreground: C.mix(light.hex, "#ffffff", .5) };
      names.forEach((n, i) => { const c = mids[i]; t[n] = C.hsl(c.h, Math.min(.75, c.s + .1), Math.max(.55, Math.min(.75, c.l + .25))); });
      t.orange = C.mix(t.red, t.yellow, .5);
      const best = pick || vivid(mids);
      t.accent = C.hsl(best.h, Math.max(.5, best.s), Math.max(.6, best.l));
      t.accent_2 = t.magenta;
      return finish(t, ct);
    } },
    base16: { name: "Base16", note: "flavours-style: eight hues spread evenly, at one tone", build(cs, ct, pick) {
      const src = pick || vivid(cs);
      const t = { background: C.hsl(cs[0].h, .2, .09), foreground: C.hsl(src.h, .12, .86), accent: C.hsl(src.h, .6, .7), accent_2: C.hsl(src.h + 180, .5, .72) };
      Object.assign(t, ansi(src.h, .5, .7, .0));
      return finish(t, ct);
    } },
  };

  // ── Omarchy themes ──────────────────────────────────
  const PRESETS = {
    omacraft: { name: "OmaCraft", wall: "monolith", c: ["#121212", "#e8e6e3", "#f2c40f", "#7fd4c1", "#f0605a", "#f59e0b", "#f2c40f", "#9ece6a", "#7fd4c1", "#7aa2f7", "#c49cf2"] },
    latte: { name: "Catppuccin Latte", light: true, wall: "sakura", c: ["#eff1f5", "#4c4f69", "#8839ef", "#1e66f5", "#d20f39", "#fe640b", "#df8e1d", "#40a02b", "#179299", "#1e66f5", "#ea76cb"] },
    "tokyo-night": { name: "Tokyo Night", wall: "nebula", c: ["#1a1b26", "#c0caf5", "#7aa2f7", "#bb9af7", "#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#7dcfff", "#7aa2f7", "#bb9af7"] },
    catppuccin: { name: "Catppuccin", wall: "sakura", c: ["#1e1e2e", "#cdd6f4", "#cba6f7", "#89b4fa", "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89b4fa", "#f5c2e7"] },
    gruvbox: { name: "Gruvbox", wall: "ember", c: ["#282828", "#ebdbb2", "#d79921", "#fe8019", "#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#d3869b"] },
    everforest: { name: "Everforest", wall: "forest", c: ["#2d353b", "#d3c6aa", "#a7c080", "#83c092", "#e67e80", "#e69875", "#dbbc7f", "#a7c080", "#83c092", "#7fbbb3", "#d699b6"] },
    nord: { name: "Nord", wall: "aurora", c: ["#2e3440", "#eceff4", "#88c0d0", "#81a1c1", "#bf616a", "#d08770", "#ebcb8b", "#a3be8c", "#8fbcbb", "#81a1c1", "#b48ead"] },
    "rose-pine": { name: "Rosé Pine", wall: "sakura", c: ["#191724", "#e0def4", "#ebbcba", "#c4a7e7", "#eb6f92", "#f6c177", "#f6c177", "#31748f", "#9ccfd8", "#31748f", "#c4a7e7"] },
    kanagawa: { name: "Kanagawa", wall: "abyss", c: ["#1f1f28", "#dcd7ba", "#7e9cd8", "#957fb8", "#c34043", "#ffa066", "#c0a36e", "#76946a", "#6a9589", "#7e9cd8", "#957fb8"] },
    "matte-black": { name: "Matte Black", wall: "monolith", c: ["#121212", "#bebebe", "#eaaf5a", "#d35f5f", "#d35f5f", "#f59e0b", "#ffc107", "#9ece6a", "#8a8a8d", "#e68e0d", "#ab4642"] },
    "osaka-jade": { name: "Osaka Jade", wall: "abyss", c: ["#111c18", "#c1c497", "#509475", "#2dd5b7", "#ff5345", "#e5c736", "#e5c736", "#549e6a", "#2dd5b7", "#509475", "#d2689c"] },
    ristretto: { name: "Ristretto", wall: "ember", c: ["#2c2525", "#e6d9db", "#f38d70", "#f9cc6c", "#fd6883", "#f38d70", "#f9cc6c", "#adda78", "#85dacc", "#f38d70", "#a8a9eb"] },
    synthwave: { name: "Synthwave", wall: "synthwave", c: ["#16091f", "#f8f4ff", "#ff2a6d", "#05d9e8", "#fe4450", "#f97e72", "#fede5d", "#72f1b8", "#05d9e8", "#36f9f6", "#ff7edb"] },
  };
  function presetTheme(id) {
    const p = PRESETS[id] || PRESETS["tokyo-night"];
    const [bg, fg, accent, accent2, red, orange, yellow, green, cyan, blue, magenta] = p.c;
    const t = { background: bg, foreground: fg, accent, accent_2: accent2, red, orange, yellow, green, cyan, blue, magenta };
    return finish(t, 50, true);
  }
  // Presets keep their exact colours: only the derived shades are filled in.
  function finish(t, contrast, exact) {
    if (!exact) return derive(t, contrast);
    const keep = { background: t.background, foreground: t.foreground, accent: t.accent };
    const out = derive(t, contrast);
    Object.assign(out, keep);
    out.dark_background = C.mix(keep.background, "#000000", .25);
    out.darker_background = C.mix(keep.background, "#000000", .45);
    out.lighter_background = C.mix(keep.background, keep.foreground, .09);
    out.dark_foreground = C.mix(keep.foreground, keep.background, .22);
    out.muted = C.mix(keep.background, keep.foreground, .38);
    out.selection = out.lighter_background;
    out.accent_ink = C.contrast(keep.accent, "#000000") > C.contrast(keep.accent, "#ffffff") ? out.darker_background : "#ffffff";
    return out;
  }

  // ── applying ─────────────────────────────────────────
  let current = presetTheme("tokyo-night");
  let clusters = [];
  let layer = 0;

  function setWallpaper(url) {
    const layers = Oma.$$("#wallpaper .wp-layer");
    const next = layers[(layer + 1) % 2];
    next.style.backgroundImage = `url("${url}")`;
    next.classList.add("on"); layers[layer].classList.remove("on");
    layer = (layer + 1) % 2;
  }

  function applyVars(t) {
    const root = document.documentElement.style;
    const map = {
      "--background": t.background, "--dark-background": t.dark_background, "--lighter-background": t.lighter_background,
      "--foreground": t.foreground, "--dark-foreground": t.dark_foreground, "--muted": t.muted,
      "--accent": t.accent, "--accent-2": t.accent_2, "--accent-ink": t.accent_ink,
      "--red": t.red, "--green": t.green, "--yellow": t.yellow, "--blue": t.blue, "--magenta": t.magenta, "--cyan": t.cyan, "--orange": t.orange,
    };
    for (const [k, v] of Object.entries(map)) root.setProperty(k, v);
    const meta = document.querySelector('meta[name="theme-color"]'); if (meta) meta.content = t.dark_background;
  }

  let themingTimer = 0;
  async function rebuild(opts = {}) {
    const th = state.theme;
    const url = wallUrl(th.wallpaper) || wallUrl("nebula");
    if (opts.wall !== false) setWallpaper(url);
    try { clusters = await extract(url); } catch (e) { clusters = []; }
    if (th.wallColours && clusters.length) {
      const pick = th.accent ? clusters.find((c) => c.hex === th.accent) || null : null;
      current = SCHEMES[th.scheme] ? SCHEMES[th.scheme].build(clusters, th.contrast, pick) : SCHEMES.material.build(clusters, th.contrast);
    } else {
      current = presetTheme(th.preset);
    }
    current.wallpaper = th.wallpaper;
    if (opts.animate !== false) {
      document.body.classList.add("theming");
      clearTimeout(themingTimer);
      themingTimer = setTimeout(() => document.body.classList.remove("theming"), 700);
    }
    applyVars(current);
    emit("theme", current);
  }

  function colorsToml(t) {
    const keys = ["accent", "selection", "selection_foreground", "muted", "", "background", "dark_background", "darker_background", "lighter_background", "",
      "foreground", "dark_foreground", "light_foreground", "bright_foreground", "", "red", "yellow", "orange", "green", "cyan", "blue", "magenta", "brown", "",
      "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta"];
    const name = state.theme.wallColours ? `${SCHEMES[state.theme.scheme].name} from ${(wallList().find((w) => w.id === t.wallpaper) || {}).name || "the wallpaper"}` : PRESETS[state.theme.preset].name;
    return `# Generated by OmaCraft (hyprskin): ${name}\nmode = "dark"\n\n` + keys.map((k) => (k ? `${k} = "${t[k]}"` : "")).join("\n") + "\n";
  }

  // Ask the wallpaper colours for a border gradient, like OmaCraft's `wallpaper` run.
  function borderRun(t = current) {
    const hues = clusters.filter((c) => c.s > .2).slice(0, 3).map((c) => C.hsl(c.h, Math.max(.55, c.s), .66));
    return [t.accent].concat(hues.length ? hues : [t.accent_2]).concat([t.accent_2]).slice(0, 4);
  }

  async function addUpload(file) {
    const url = await new Promise((res) => { const fr = new FileReader(); fr.onload = () => res(fr.result); fr.readAsDataURL(file); });
    const im = await loadImage(url);
    // Keep stored copies small: 1600px wide JPEG.
    const scale = Math.min(1, 1600 / im.width);
    const cv = document.createElement("canvas"); cv.width = Math.round(im.width * scale); cv.height = Math.round(im.height * scale);
    cv.getContext("2d").drawImage(im, 0, 0, cv.width, cv.height);
    const small = cv.toDataURL("image/jpeg", 0.85);
    const id = "up-" + Date.now().toString(36) + Math.floor(Math.random() * 1e4);
    state.walls.push({ id, name: file.name.replace(/\.[^.]+$/, "").slice(0, 24) || "Mine", url: small });
    save();
    return id;
  }

  window.Theme = {
    SCHEMES, PRESETS, PAINTERS, wallUrl, wallList, rebuild, colorsToml, borderRun, addUpload, loadImage,
    get current() { return current; }, get clusters() { return clusters; },
  };
})();
