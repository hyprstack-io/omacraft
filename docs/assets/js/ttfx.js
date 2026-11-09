// ttfx in the browser: the intro effects omascii plays through ttfx (the Rust
// port of terminaltexteffects), redrawn on a canvas so they can reveal any
// FIGlet or TheDraw art. Effects are named and grouped exactly as omascii's
// `--effects` takes them, so a pick here is a pick there. omascii's own
// originals (lib/effects.py, ported in ascii.js) play on the same stage.
//
// An effect is a pure function of progress p (0…1): for each cell of ink it
// says where that cell is (x, y in cell units, the art's top-left at 0,0),
// what it shows and how bright, or null for not yet. under()/over() paint
// beams, grids and lights around the cells.
(function () {
  "use strict";
  const { hash, clamp, smooth, color: C } = Oma;

  const SHADE = { "░": 0.34, "▒": 0.62, "▓": 0.9 };
  const NOISE = "▓▒░▀▄█";
  const GLYPHS = "!@#$%&*+=?<>/\\|~^ABCDEFGHJKLMNPQRSTUVWXYZ0123456789";
  const WAVE = "▁▂▃▄▅▆▇█▇▆▅▄▃▂";
  const lerp = (a, b, t) => a + (b - a) * t;
  const eo3 = (t) => 1 - Math.pow(1 - clamp(t), 3);
  const eio = (t) => { t = clamp(t); return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
  const eoBack = (t) => { t = clamp(t); const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
  function eoBounce(t) {
    t = clamp(t); const n = 7.5625, d = 2.75;
    if (t < 1 / d) return n * t * t;
    if (t < 2 / d) return n * (t -= 1.5 / d) * t + 0.75;
    if (t < 2.5 / d) return n * (t -= 2.25 / d) * t + 0.9375;
    return n * (t -= 2.625 / d) * t + 0.984375;
  }
  const local = (p, a, b) => clamp((p - a) / (b - a));
  const R = (i, k) => hash(i, k, 7919);
  const home = (c, extra) => Object.assign({ x: c.c, y: c.r, ch: c.ch, col: c.col, bg: c.bg, a: 1 }, extra);
  const glyph = (i, f) => GLYPHS[Math.floor(hash(i, f, 3) * GLYPHS.length)];
  const fire = (k) => (k < 0.5 ? C.mix("#fff3b0", "#ffb020", k * 2) : C.mix("#ffb020", "#ff3d1a", (k - 0.5) * 2));

  // ── the effects ─────────────────────────────────────────────
  const FX = {
    // Core
    decrypt: { ms: 2800, cell(G, c, p) {
      const shown = R(c.i, 1) * 0.22;
      if (p < shown) return null;
      const at = 0.32 + R(c.i, 2) * 0.55;
      if (p < at) {
        const f = Math.floor(p * G.ms / 70 + c.i * 3);
        const cols = [G.t.accent, G.t.accent_2, G.t.muted, G.t.foreground];
        return home(c, { ch: glyph(c.i, f), col: cols[Math.floor(hash(c.i, f, 5) * 4)], a: 0.75, text: true, bg: null });
      }
      return home(c, { glow: 1 - local(p, at, at + 0.12) });
    } },
    beams: { ms: 3000,
      prep(G) { G.rowBeam = (r) => ({ s: R(r, 3) * 0.4, dir: r % 2 ? -1 : 1 }); },
      cell(G, c, p) {
        const b = G.rowBeam(c.r), frac = b.dir > 0 ? c.c / G.cols : 1 - c.c / G.cols, at = b.s + frac * 0.32;
        if (p < at) return null;
        let glow = 1 - local(p, at, at + 0.22);
        // the closing column beams light everything once more
        const colAt = 0.72 + (c.c / G.cols) * 0.22;
        glow = Math.max(glow, 0.8 * (1 - Math.abs(p - colAt) / 0.04));
        return home(c, { glow: clamp(glow) });
      },
      over(g, G, p, X) {
        for (let r = 0; r < G.rows; r++) {
          const b = G.rowBeam(r), k = local(p, b.s, b.s + 0.32);
          if (k <= 0 || k >= 1) continue;
          const head = b.dir > 0 ? k * G.cols : (1 - k) * G.cols, len = 10 * b.dir;
          const x1 = X.x(head), x0 = X.x(head - len), y = X.y(r + 0.5);
          const gr = g.createLinearGradient(x0, 0, x1, 0);
          gr.addColorStop(0, C.rgba(G.t.accent, 0)); gr.addColorStop(1, C.rgba("#ffffff", 0.95));
          g.fillStyle = gr; g.fillRect(Math.min(x0, x1), y - X.ch * 0.2, Math.abs(x1 - x0), X.ch * 0.4);
        }
        if (p > 0.7) {
          const k = local(p, 0.72, 0.94), x = X.x(k * G.cols);
          const gr = g.createLinearGradient(0, X.y(-1), 0, X.y(G.rows + 1));
          gr.addColorStop(0, C.rgba(G.t.accent_2, 0)); gr.addColorStop(0.5, C.rgba("#ffffff", 0.5 * (1 - k))); gr.addColorStop(1, C.rgba(G.t.accent_2, 0));
          g.fillStyle = gr; g.fillRect(x - X.cw * 0.4, X.y(-1), X.cw * 0.8, X.ch * (G.rows + 2));
        }
      } },
    burn: { ms: 2800, cell(G, c, p) {
      const at = (1 - c.r / G.rows) * 0.5 + R(c.i, 4) * 0.18 + (hash(c.c >> 2, 9) - 0.5) * 0.1;
      if (p < at) return null;
      const k = local(p, at, at + 0.22);
      if (k < 1) return home(c, { ch: k < 0.6 ? "░▒▓█"[Math.floor(k / 0.6 * 4)] : c.ch, col: k < 0.6 ? fire(k / 0.6) : C.mix(fire(1), c.col || G.t.foreground, (k - 0.6) / 0.4), glow: (1 - k) * 0.5 });
      return home(c);
    },
      over(g, G, p, X) {
        for (let i = 0; i < 60; i++) {
          const life = (p * 3 + hash(i, 1)) % 1, x = hash(i, 2) * G.cols, line = G.rows * (1 - p * 1.2);
          const y = line + 2 - life * 6;
          if (y < -2 || p > 0.95) continue;
          g.fillStyle = C.rgba(fire(life), (1 - life) * 0.8);
          g.fillRect(X.x(x), X.y(y), X.cw * 0.35, X.cw * 0.35);
        }
      } },
    slide: { ms: 2200, cell(G, c, p) {
      const s = (c.r / G.rows) * 0.3, k = eo3(local(p, s, s + 0.55));
      const from = c.r % 2 ? G.R + c.c : G.L - (G.cols - c.c);
      return home(c, { x: lerp(from, c.c, k), glow: (1 - k) * 0.4 });
    } },
    rain: { ms: 3000, cell(G, c, p) {
      const s = R(c.i, 5) * 0.6, k = local(p, s, s + 0.3);
      if (k <= 0) return null;
      const startY = G.T - 1 - R(c.i, 6) * 4;
      const y = lerp(startY, c.r, k * k);
      if (k < 1) return home(c, { y, col: C.mix(G.t.cyan || G.t.accent, G.t.foreground, 0.2), ch: R(c.i, 8) < 0.5 ? c.ch : "│", text: true, a: 0.85, bg: null });
      return home(c, { glow: 1 - local(p, s + 0.3, s + 0.4) });
    } },
    laseretch: { ms: 3400,
      prep(G) { const order = G.cells.slice().sort((a, b) => (a.c + a.r * 0.6 + (a.r % 2) * 0.3) - (b.c + b.r * 0.6 + (b.r % 2) * 0.3)); order.forEach((c, n) => { c.etch = (n / order.length) * 0.85; }); G.order = order; },
      cell(G, c, p) {
        if (p < c.etch) return null;
        const k = local(p, c.etch, c.etch + 0.18);
        return home(c, { col: k < 1 ? (k < 0.4 ? C.mix("#ffffff", "#ffb020", k / 0.4) : C.mix("#ffb020", c.col || G.t.foreground, (k - 0.4) / 0.6)) : c.col, glow: (1 - k) * 0.4 });
      },
      over(g, G, p, X) {
        if (p >= 0.86) return;
        const n = Math.min(G.order.length - 1, Math.floor((p / 0.85) * G.order.length));
        const c = G.order[n]; if (!c) return;
        const ex = X.x((G.L + G.R) / 2), ey = X.y(G.T + 0.5), tx = X.x(c.c + 0.5), ty = X.y(c.r + 0.5);
        g.save(); g.strokeStyle = C.rgba(G.t.accent, 0.85); g.lineWidth = 1.5; g.shadowColor = G.t.accent; g.shadowBlur = 12;
        g.beginPath(); g.moveTo(ex, ey); g.lineTo(tx, ty); g.stroke();
        g.fillStyle = "#fff"; g.beginPath(); g.arc(tx, ty, 2.5, 0, Math.PI * 2); g.fill();
        for (let i = 0; i < 6; i++) { const a = hash(i, Math.floor(p * 200)) * Math.PI * 2, d = hash(i, 3, Math.floor(p * 200)) * X.cw * 1.6; g.fillRect(tx + Math.cos(a) * d, ty + Math.sin(a) * d, 1.5, 1.5); }
        g.restore();
      } },
    waves: { ms: 2800, cell(G, c, p) {
      const front = lerp(G.L - 2, G.R + 14, p / 0.85), d = front - c.c;
      if (d < 0) return null;
      if (d < 12) {
        const ph = Math.floor(d * 1.4 + c.r * 0.8);
        return home(c, { ch: WAVE[ph % WAVE.length], col: C.mix(G.t.accent, G.t.accent_2, (Math.sin(c.c * 0.3 + p * 10) + 1) / 2), text: true, bg: null });
      }
      return home(c);
    } },
    middleout: { ms: 2600, cell(G, c, p) {
      const mid = (G.rows - 1) / 2, cx = (G.cols - 1) / 2;
      const k1 = eo3(local(p, 0, 0.45)), k2 = eo3(local(p, 0.45, 0.9));
      return home(c, { x: lerp(cx, c.c, k1), y: lerp(mid, c.r, k2), col: C.mix(G.t.accent, c.col || G.t.foreground, k2), glow: (1 - k2) * 0.3 });
    } },
    vhstape: { ms: 2800,
      cell(G, c, p) {
        if (p < (c.r / G.rows) * 0.12) return null;
        const amp = 1 - smooth(0.55, 0.95, p), f = Math.floor(p * G.ms / 55);
        const jump = hash(c.r, f, 2) < 0.35 * amp ? (hash(c.r, f, 4) - 0.5) * 14 * amp : (hash(c.r >> 1, f >> 1) - 0.5) * 2.4 * amp;
        const o = home(c, { x: c.c + jump });
        if (hash(c.i, f, 6) < amp * 0.25) { o.ch = NOISE[Math.floor(hash(c.i, f) * NOISE.length)]; o.bg = null; }
        if (amp > 0.05 && hash(c.r, f, 8) < 0.2) o.col = hash(c.r, f, 9) < 0.5 ? "#ff3b6b" : "#3bf0ff";
        return o;
      },
      over(g, G, p, X) {
        const amp = 1 - smooth(0.55, 0.95, p);
        if (amp <= 0) return;
        for (let i = 0; i < 3; i++) {
          const y = ((p * 2.4 + i / 3) % 1) * (G.B - G.T) + G.T;
          g.fillStyle = C.rgba("#ffffff", 0.06 * amp); g.fillRect(0, X.y(y), X.W, X.ch * 1.2);
        }
      } },
    sweep: { ms: 2800, cell(G, c, p) {
      const f1 = lerp(G.L - 2, G.R + 2, local(p, 0, 0.45)), f2 = lerp(G.R + 2, G.L - 2, local(p, 0.5, 0.95));
      if (c.c > f1) return null;
      if (Math.abs(c.c - f1) < 1.5 && p < 0.45) return home(c, { ch: NOISE[c.i % NOISE.length], col: G.t.foreground, bg: null, text: true });
      if (p < 0.5 || c.c < f2) return home(c, { col: G.t.muted, bg: c.bg ? C.mix(G.t.muted, G.t.background, 0.6) : null });
      return home(c, { glow: Math.max(0, 1 - (c.c - f2) / 3) * 0.6 });
    } },
    unstable: { ms: 3200, cell(G, c, p) {
      const jx = R(c.i, 1) * G.cols, jy = R(c.i, 2) * G.rows;
      const ang = Math.atan2(jy - G.rows / 2, (jx - G.cols / 2) / 2);
      const ex = G.cols / 2 + Math.cos(ang) * (G.R - G.L) * 0.62, ey = G.rows / 2 + Math.sin(ang) * (G.B - G.T) * 0.6;
      if (p < 0.3) { const w = Math.sin(p * 60 + c.i) * 0.3 * (p / 0.3); return home(c, { x: jx + w, y: jy, col: C.mix(c.col || G.t.foreground, G.t.muted, 0.5) }); }
      if (p < 0.5) { const k = eo3(local(p, 0.3, 0.5)); return home(c, { x: lerp(jx, ex, k), y: lerp(jy, ey, k), col: G.t.red || G.t.accent, glow: 0.3 }); }
      const k = eio(local(p, 0.55, 0.95));
      return home(c, { x: lerp(ex, c.c, k), y: lerp(ey, c.r, k), col: C.mix(G.t.red || G.t.accent, c.col || G.t.foreground, k) });
    } },

    // More ttfx
    expand: { ms: 2000, cell(G, c, p) {
      const k = eoBack(local(p, R(c.i, 1) * 0.15, 0.85));
      return home(c, { x: lerp((G.cols - 1) / 2, c.c, k), y: lerp((G.rows - 1) / 2, c.r, k), a: clamp(0.2 + k), glow: (1 - clamp(k)) * 0.5 });
    } },
    pour: { ms: 2800, cell(G, c, p) {
      const rowS = ((G.rows - 1 - c.r) / G.rows) * 0.55, s = rowS + ((c.r % 2 ? G.cols - c.c : c.c) / G.cols) * 0.18;
      const k = local(p, s, s + 0.22);
      if (k <= 0) return null;
      return home(c, { y: lerp(G.T - 1, c.r, k * k), glow: k < 1 ? 0.3 : 0 });
    } },
    print: { ms: 3400, cell(G, c, p) {
      const rowS = (c.r / G.rows) * 0.9, at = rowS + (c.c / G.cols) * (0.9 / G.rows);
      return p < at ? null : home(c, { glow: 1 - local(p, at, at + 0.06) });
    },
      over(g, G, p, X) {
        if (p >= 0.9) return;
        const r = Math.min(G.rows - 1, Math.floor((p / 0.9) * G.rows)), c = ((p / 0.9) * G.rows - r) * G.cols;
        if (Math.floor(p * 40) % 2) { g.fillStyle = G.t.accent; g.fillRect(X.x(c), X.y(r), X.cw, X.ch); }
      } },
    scattered: { ms: 2400, cell(G, c, p) {
      const sx = lerp(G.L, G.R, R(c.i, 1)), sy = lerp(G.T, G.B, R(c.i, 2)), k = eio(local(p, 0.08, 0.85));
      return home(c, { x: lerp(sx, c.c, k), y: lerp(sy, c.r, k), col: C.mix(G.t.accent_2, c.col || G.t.foreground, k) });
    } },
    slice: { ms: 2200, cell(G, c, p) {
      const k = eo3(local(p, 0.05, 0.8)), top = c.c < G.cols / 2;
      return home(c, { y: lerp(top ? G.T - G.rows : G.B + 1, c.r, k) });
    } },
    spotlights: { ms: 3800,
      prep(G) {
        G.spots = (p) => {
          const conv = smooth(0.55, 0.75, p), grow = smooth(0.72, 0.95, p);
          return [0, 1, 2].map((i) => {
            const t = p * 6 + i * 2.1;
            const x = lerp(G.cols * (0.5 + 0.42 * Math.sin(t * 0.9 + i)), G.cols / 2, conv);
            const y = lerp(G.rows * (0.5 + 0.45 * Math.cos(t * 1.3 + i * 2)), G.rows / 2, conv);
            return { x, y, r: lerp(5, Math.max(G.cols, G.rows * 2), grow) };
          });
        };
      },
      cell(G, c, p) {
        let light = 0;
        for (const s of G.spots(p)) light = Math.max(light, 1 - Math.hypot(c.c - s.x, (c.r - s.y) * 2) / s.r);
        light = clamp(light * 1.6);
        return home(c, { col: C.mix(G.t.muted, c.col || G.t.foreground, light), a: 0.15 + 0.85 * light, glow: light * 0.25 * (1 - smooth(0.85, 1, p)) });
      },
      under(g, G, p, X) {
        if (p > 0.95) return;
        for (const s of G.spots(p)) {
          const gr = g.createRadialGradient(X.x(s.x), X.y(s.y), 0, X.x(s.x), X.y(s.y), s.r * X.cw);
          gr.addColorStop(0, C.rgba(G.t.accent, 0.16 * (1 - smooth(0.8, 0.95, p)))); gr.addColorStop(1, C.rgba(G.t.accent, 0));
          g.fillStyle = gr; g.fillRect(0, 0, X.W, X.H);
        }
      } },
    wipe: { ms: 1800, cell(G, c, p) {
      const at = (c.c + c.r * 2) / (G.cols + G.rows * 2) * 0.85;
      return p < at ? null : home(c, { glow: 1 - local(p, at, at + 0.08) });
    } },
    errorcorrect: { ms: 3200,
      prep(G) {
        const wrong = G.cells.filter((c) => R(c.i, 11) < 0.18), spots = wrong.map((c) => [c.c, c.r]);
        spots.push(spots.shift());
        wrong.forEach((c, n) => { c.wrong = spots[n]; c.fix = 0.2 + R(c.i, 12) * 0.6; });
      },
      cell(G, c, p) {
        if (!c.wrong) return home(c);
        if (p < c.fix) return home(c, { x: c.wrong[0], y: c.wrong[1], col: G.t.red || "#ff5555", glow: Math.floor(p * 20) % 2 ? 0.3 : 0 });
        const k = eio(local(p, c.fix, c.fix + 0.12)), d = local(p, c.fix + 0.12, c.fix + 0.3);
        return home(c, { x: lerp(c.wrong[0], c.c, k), y: lerp(c.wrong[1], c.r, k), col: k < 1 ? G.t.yellow || G.t.accent : C.mix(G.t.green || G.t.accent, c.col || G.t.foreground, d) });
      } },
    randomsequence: { ms: 2000, cell(G, c, p) {
      const at = R(c.i, 1) * 0.85;
      return p < at ? null : home(c, { a: clamp((p - at) / 0.05) });
    } },
    swarm: { ms: 3800, cell(G, c, p) {
      const grp = c.i % 6, settle = 0.42 + (grp / 6) * 0.35;
      const t = p * 7 + grp;
      const sx = G.cols / 2 + Math.sin(t * 0.8 + grp * 1.7) * (G.R - G.L) * 0.38;
      const sy = G.rows / 2 + Math.cos(t * 1.1 + grp) * (G.B - G.T) * 0.35;
      const ox = Math.cos(c.i * 2.3 + p * 9) * 3 * R(c.i, 3), oy = Math.sin(c.i * 1.7 + p * 9) * 1.5 * R(c.i, 4);
      const k = eio(local(p, settle, settle + 0.2));
      if (p < 0.06 * (grp + 1)) return null;
      return home(c, { x: lerp(sx + ox, c.c, k), y: lerp(sy + oy, c.r, k), col: C.mix(C.hsl(grp * 60, 0.7, 0.65), c.col || G.t.foreground, k) });
    } },
    fireworks: { ms: 3800, cell(G, c, p) {
      const grp = Math.floor(c.c / 10), groups = Math.ceil(G.cols / 10), s = (grp / groups) * 0.45;
      const gx = grp * 10 + 5, apexY = G.T + (G.rows + (G.B - G.T)) * 0.12;
      const k1 = local(p, s, s + 0.12), k2 = local(p, s + 0.12, s + 0.27), k3 = eio(local(p, s + 0.27, s + 0.5));
      if (k1 <= 0) return null;
      const hue = C.hsl(hash(grp, 5) * 360, 0.85, 0.65);
      if (k1 < 1) return home(c, { x: gx, y: lerp(G.B, apexY, eo3(k1)), ch: "▪", col: hue, text: true, bg: null, a: R(c.i, 1) < 0.15 ? 1 : 0 });
      const ang = R(c.i, 2) * Math.PI * 2, rad = (2 + R(c.i, 3) * 8) * eo3(k2);
      const bx = gx + Math.cos(ang) * rad * 1.6, by = apexY + Math.sin(ang) * rad * 0.8 + k2 * k2 * 3;
      if (k3 <= 0) return home(c, { x: bx, y: by, ch: "*", col: hue, text: true, bg: null, glow: 0.5 });
      return home(c, { x: lerp(bx, c.c, k3), y: lerp(by, c.r, k3), col: C.mix(hue, c.col || G.t.foreground, k3) });
    } },
    blackhole: { ms: 4000,
      cell(G, c, p) {
        const sx = lerp(G.L, G.R, R(c.i, 1)), sy = lerp(G.T, G.B, R(c.i, 2)), cx = G.cols / 2, cy = G.rows / 2;
        if (p < 0.25) return home(c, { x: sx, y: sy, ch: R(c.i, 3) < 0.5 ? "*" : "·", col: G.t.foreground, text: true, bg: null, a: 0.3 + 0.5 * Math.abs(Math.sin(p * 30 + c.i)) });
        if (p < 0.58) {
          const k = eio(local(p, 0.25, 0.55)), a0 = Math.atan2((sy - cy) * 2, sx - cx), d0 = Math.hypot(sx - cx, (sy - cy) * 2);
          const a = a0 + k * 5, d = d0 * (1 - k) + 1.2;
          return home(c, { x: cx + Math.cos(a) * d, y: cy + Math.sin(a) * d / 2, ch: "·", col: G.t.accent_2, text: true, bg: null, a: 1 - k * 0.6 });
        }
        const k = eo3(local(p, 0.6, 0.95));
        return home(c, { x: lerp(cx, c.c, k), y: lerp(cy, c.r, k), glow: (1 - k) * 0.8 });
      },
      under(g, G, p, X) {
        if (p < 0.2 || p > 0.62) return;
        const k = p < 0.55 ? local(p, 0.2, 0.4) : 1 - local(p, 0.58, 0.62);
        const x = X.x(G.cols / 2), y = X.y(G.rows / 2), r = X.cw * 3.2 * k;
        g.save(); g.fillStyle = "#000"; g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill();
        g.strokeStyle = G.t.accent; g.lineWidth = 2; g.shadowColor = G.t.accent; g.shadowBlur = 18 * k; g.stroke(); g.restore();
      } },
    rings: { ms: 3800, cell(G, c, p) {
      const ring = c.i % 3, rad = (ring + 1) * Math.min(G.cols, G.rows * 2) * 0.16 + 2;
      const ang = (c.i / G.cells.length) * Math.PI * 2 * 7 + p * (ring % 2 ? -5 : 5);
      const rx = G.cols / 2 + Math.cos(ang) * rad, ry = G.rows / 2 + Math.sin(ang) * rad / 2;
      const sx = lerp(G.L, G.R, R(c.i, 1)), sy = lerp(G.T, G.B, R(c.i, 2));
      const k1 = eio(local(p, 0, 0.25)), k2 = eio(local(p, 0.6, 0.95));
      const x = lerp(lerp(sx, rx, k1), c.c, k2), y = lerp(lerp(sy, ry, k1), c.r, k2);
      return home(c, { x, y, col: C.mix([G.t.accent, G.t.accent_2, G.t.cyan || G.t.foreground][ring], c.col || G.t.foreground, k2) });
    } },
    bubbles: { ms: 3800,
      prep(G) { G.bub = (grp) => ({ x: lerp(G.cols * 0.1, G.cols * 0.9, hash(grp, 1)), s: hash(grp, 2) * 0.35, pop: 0.45 + hash(grp, 3) * 0.3, r: 2.5 }); },
      cell(G, c, p) {
        const grp = c.i % 10, b = G.bub(grp);
        if (p < b.s) return null;
        const fall = local(p, b.s, b.pop), by = lerp(G.T - 3, G.rows * (0.2 + hash(grp, 4) * 0.6), fall), bx = b.x + Math.sin(p * 8 + grp) * 1.5;
        if (p < b.pop) { const a = (c.i / G.cells.length) * 97 + p * 3; return home(c, { x: bx + Math.cos(a) * b.r * 2, y: by + Math.sin(a) * b.r, col: G.t.cyan || G.t.accent, bg: null, ch: "o", text: true, a: 0.8 }); }
        const k = eo3(local(p, b.pop, b.pop + 0.2)), a = (c.i / G.cells.length) * 97 + b.pop * 3;
        return home(c, { x: lerp(bx + Math.cos(a) * b.r * 2, c.c, k), y: lerp(by + Math.sin(a) * b.r, c.r, k) });
      } },
    crumble: { ms: 3800, cell(G, c, p) {
      const fall = 0.08 + R(c.i, 1) * 0.3, vac = 0.48 + R(c.i, 2) * 0.12, back = 0.66 + R(c.i, 3) * 0.12;
      if (p < fall) return home(c, { col: C.mix(c.col || G.t.foreground, G.t.muted, local(p, 0, fall)) });
      if (p < vac) { const k = local(p, fall, fall + 0.12); return home(c, { y: lerp(c.r, G.B - 1, k * k), ch: k < 1 ? c.ch : "·", col: G.t.muted, text: k >= 1, bg: null }); }
      if (p < back) { const k = eio(local(p, vac, vac + 0.12)); return home(c, { y: lerp(G.B - 1, G.T, k), ch: "·", col: G.t.muted, text: true, bg: null, a: 1 - k * 0.6 }); }
      const k = eo3(local(p, back, back + 0.2));
      return home(c, { y: lerp(G.T, c.r, k), glow: (1 - k) * 0.4 });
    } },
    binarypath: { ms: 3400, cell(G, c, p) {
      const s = R(c.i, 1) * 0.5, k = local(p, s, s + 0.35);
      if (k <= 0) return null;
      if (k >= 1) return home(c, { glow: 1 - local(p, s + 0.35, s + 0.45) });
      const side = c.i % 4, sx = side === 0 ? G.L : side === 1 ? G.R : lerp(G.L, G.R, R(c.i, 2)), sy = side < 2 ? lerp(G.T, G.B, R(c.i, 3)) : side === 2 ? G.T : G.B;
      const x = k < 0.5 ? lerp(sx, c.c, k * 2) : c.c, y = k < 0.5 ? sy : lerp(sy, c.r, (k - 0.5) * 2);
      return home(c, { x: Math.round(x), y: Math.round(y), ch: hash(c.i, Math.floor(p * 60)) < 0.5 ? "0" : "1", col: G.t.green || G.t.accent, text: true, bg: null });
    } },
    overflow: { ms: 3000, cell(G, c, p) {
      if (p > 0.62) { const k = eo3(local(p, 0.62, 0.8)); return home(c, { y: lerp(c.r - 2, c.r, k) }); }
      const span = G.rows + 3, scroll = (p * G.ms) / 40;
      const y = ((c.r - scroll) % span + span) % span - 1;
      return home(c, { y, col: C.hsl(hash(c.r, Math.floor(scroll / span)) * 360, 0.5, 0.62), a: 0.85 });
    } },
    spray: { ms: 2800, cell(G, c, p) {
      const s = R(c.i, 1) * 0.6, k = eo3(local(p, s, s + 0.3));
      if (k <= 0) return null;
      const ox = G.cols / 2, oy = G.B - 0.5;
      return home(c, { x: lerp(ox, c.c, k), y: lerp(oy, c.r, k) - Math.sin(k * Math.PI) * 3, glow: (1 - k) * 0.5 });
    } },
    orbittingvolley: { ms: 3800,
      prep(G) {
        const cx = G.cols / 2, cy = G.rows / 2, maxD = Math.hypot(cx, cy * 2) || 1;
        G.cells.forEach((c) => { c.at = 0.08 + (Math.hypot(c.c - cx, (c.r - cy) * 2) / maxD) * 0.62; });
        G.launcher = (n, p) => { const a = p * 5 + n * Math.PI / 2; return { x: cx + Math.cos(a) * (G.R - G.L) * 0.48, y: cy + Math.sin(a) * (G.B - G.T) * 0.46 }; };
      },
      cell(G, c, p) {
        if (p < c.at) return null;
        const k = eo3(local(p, c.at, c.at + 0.16)), L = G.launcher(c.i % 4, c.at);
        return home(c, { x: lerp(L.x, c.c, k), y: lerp(L.y, c.r, k), glow: (1 - k) * 0.5 });
      },
      over(g, G, p, X) {
        if (p > 0.9) return;
        for (let n = 0; n < 4; n++) { const L = G.launcher(n, p); g.fillStyle = [G.t.accent, G.t.accent_2, G.t.cyan || G.t.accent, G.t.magenta || G.t.accent_2][n]; g.fillRect(X.x(L.x) - X.cw / 2, X.y(L.y) - X.ch / 2, X.cw, X.ch); }
      } },
    smoke: { ms: 3400, cell(G, c, p) {
      const n = hash(c.c >> 2, c.r >> 1, 3) * 0.3 + (c.c / G.cols) * 0.5 + (1 - c.r / G.rows) * 0.2;
      const front = p * 1.35;
      if (front < n) return home(c, { col: G.t.muted, a: 0.45, bg: null });
      if (front < n + 0.12) return home(c, { ch: "▒", col: C.mix(G.t.muted, G.t.foreground, 0.5), text: false, bg: null, a: 0.7 });
      return home(c, { glow: 1 - local(front, n + 0.12, n + 0.3) });
    } },
    bouncyballs: { ms: 3200, cell(G, c, p) {
      const s = R(c.i, 1) * 0.5, k = local(p, s, s + 0.38);
      if (k <= 0) return null;
      const y = lerp(G.T - 2, c.r, eoBounce(k));
      if (k < 1) return home(c, { y, ch: "●", col: C.hsl(R(c.i, 2) * 360, 0.75, 0.65), text: true, bg: null });
      return home(c);
    } },

    // Screensaver
    synthgrid: { ms: 3400, cell(G, c, p) {
      const at = 0.3 + R(c.i, 1) * 0.5;
      if (p < at) return null;
      const k = local(p, at, at + 0.12);
      return k < 1 ? home(c, { ch: "░▒▓"[Math.floor(k * 3)], col: G.t.accent, bg: null }) : home(c);
    },
      under(g, G, p, X) {
        const draw = local(p, 0, 0.3), fade = 1 - local(p, 0.85, 1);
        if (fade <= 0) return;
        g.strokeStyle = C.rgba(G.t.accent_2, 0.45 * fade); g.lineWidth = 1;
        for (let x = 0; x <= G.cols; x += 4) { g.beginPath(); g.moveTo(X.x(x), X.y(0)); g.lineTo(X.x(x), X.y(G.rows * draw)); g.stroke(); }
        for (let y = 0; y <= G.rows; y += 2) { g.beginPath(); g.moveTo(X.x(0), X.y(y)); g.lineTo(X.x(G.cols * draw), X.y(y)); g.stroke(); }
      } },
    thunderstorm: { ms: 3800,
      cell(G, c, p) {
        const flash = [0.28, 0.52, 0.76].reduce((m, s) => Math.max(m, 1 - Math.abs(p - s) / 0.03), 0);
        const lit = smooth(0.76, 0.86, p);
        return home(c, { col: C.mix(G.t.muted, c.col || G.t.foreground, Math.max(lit, clamp(flash))), a: 0.35 + 0.65 * Math.max(lit, clamp(flash)), glow: clamp(flash) * 0.7 });
      },
      over(g, G, p, X) {
        const rain = 1 - local(p, 0.85, 1);
        g.strokeStyle = C.rgba(G.t.foreground, 0.25 * rain); g.lineWidth = 1;
        for (let i = 0; i < 80; i++) { const x = hash(i, 1) * X.W, y = ((hash(i, 2) + p * 6) % 1) * X.H; g.beginPath(); g.moveTo(x, y); g.lineTo(x - 3, y + 12); g.stroke(); }
        [0.28, 0.52, 0.76].forEach((s, n) => {
          const k = 1 - Math.abs(p - s) / 0.03;
          if (k <= 0) return;
          g.save(); g.strokeStyle = C.rgba("#ffffff", k); g.lineWidth = 2; g.shadowColor = G.t.accent; g.shadowBlur = 16;
          let x = X.W * (0.2 + n * 0.3), y = 0; g.beginPath(); g.moveTo(x, y);
          while (y < X.H * 0.8) { x += (hash(n, y | 0) - 0.5) * 40; y += 14 + hash(y | 0, n) * 14; g.lineTo(x, y); }
          g.stroke(); g.restore();
        });
      } },
    colorshift: { ms: 3200, cell(G, c, p) {
      const hue = (c.c * 7 + c.r * 9 + p * 900) % 360;
      return home(c, { col: C.mix(C.hsl(hue, 0.75, 0.65), c.col || G.t.foreground, smooth(0.7, 1, p)) });
    } },
    highlight: { ms: 2400, cell(G, c, p) {
      const band = lerp(-12, G.cols + G.rows * 1.5 + 12, p), d = Math.abs(c.c + c.r * 1.5 - band);
      return home(c, { glow: d < 6 ? (1 - d / 6) * 0.85 : 0 });
    } },
  };

  // omascii's originals (ascii.js) on the same stage: they see the whole
  // grid, blanks included, and move cells only downwards (dr).
  const ORIGINALS = ["decode", "ripple", "starfield", "neon", "tetris", "spiral", "crt", "plasma", "tunein", "helix"];

  const GROUPS = [
    { id: "core", name: "Core", effects: ["decrypt", "beams", "burn", "slide", "rain", "laseretch", "waves", "middleout", "vhstape", "sweep", "unstable"] },
    { id: "more", name: "More ttfx", effects: ["expand", "pour", "print", "scattered", "slice", "spotlights", "wipe", "errorcorrect", "randomsequence", "swarm", "fireworks", "blackhole", "rings", "bubbles", "crumble", "binarypath", "overflow", "spray", "orbittingvolley", "smoke", "bouncyballs"] },
    { id: "screensaver", name: "Screensaver", effects: ["matrix", "synthgrid", "thunderstorm", "colorshift", "highlight"] },
    { id: "omascii", name: "omascii originals", effects: ORIGINALS },
  ];
  const ALL = GROUPS.flatMap((g) => g.effects);
  const isOriginal = (name) => ORIGINALS.includes(name) || name === "matrix";
  const msOf = (name, G) => (FX[name] ? FX[name].ms : Ascii.EFFECTS[name] ? Ascii.EFFECTS[name].ms(G) : 2400);

  // ── drawing a cell ─────────────────────────────────────────
  function cell(g, x, y, cw, ch, s, col, a, bg, text) {
    if (bg) { g.fillStyle = C.rgba(bg, a); g.fillRect(x, y, cw + 0.5, ch + 0.5); }
    if (!s || s === " ") return;
    if (SHADE[s] && !text) { g.fillStyle = C.rgba(col, a * SHADE[s]); g.fillRect(x, y, cw + 0.5, ch + 0.5); return; }
    g.fillStyle = C.rgba(col, a);
    if (text) { g.fillText(s, x + cw / 2, y + ch / 2); return; }
    if (s === "█") g.fillRect(x, y, cw + 0.5, ch + 0.5);
    else if (s === "▀") g.fillRect(x, y, cw + 0.5, ch / 2 + 0.5);
    else if (s === "▄") g.fillRect(x, y + ch / 2, cw + 0.5, ch / 2 + 0.5);
    else if (s === "▌") g.fillRect(x, y, cw / 2 + 0.5, ch + 0.5);
    else if (s === "▐") g.fillRect(x + cw / 2, y, cw / 2 + 0.5, ch + 0.5);
    else if (s === "■") g.fillRect(x + cw * 0.15, y + ch * 0.3, cw * 0.7, ch * 0.4);
    else if (WAVE.includes(s)) { const h = (WAVE.indexOf(s) % 8 + 1) / 8; g.fillRect(x, y + ch * (1 - h), cw + 0.5, ch * h + 0.5); }
    else g.fillText(s, x + cw / 2, y + ch / 2);
  }

  // A stage: a canvas filling its parent, the art centred in it.
  //   stage(canvas, { maxCell, fill }) → { set(rows), play(name, done), still(), sweep(on), ... }
  function stage(canvas, opts = {}) {
    let rows = [], name = null, start = 0, raf = 0, onDone = null, sweeping = false, sweepFrom = 0, seed = 1, G = null;
    const theme = () => (window.Theme ? Theme.current : {});

    function layout() {
      const dpr = Math.min(2, window.devicePixelRatio || 1);
      const box = canvas.parentElement.getBoundingClientRect();
      const W = Math.max(40, box.width), H = Math.max(40, box.height);
      if (canvas.width !== Math.round(W * dpr) || canvas.height !== Math.round(H * dpr)) {
        canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
        canvas.style.width = W + "px"; canvas.style.height = H + "px";
      }
      const R0 = rows.length, C0 = R0 ? rows[0].length : 1;
      const cw = Math.max(1.5, Math.min(opts.maxCell || 14, (W * (opts.fill || 0.92)) / Math.max(1, C0), (H * 0.86) / Math.max(1, R0 * 2)));
      const ch = cw * 2, ox = (W - C0 * cw) / 2, oy = (H - R0 * ch) / 2;
      return { W, H, dpr, cw, ch, ox, oy };
    }

    function scene(L) {
      const cells = [];
      rows.forEach((row, r) => row.forEach((c, cIdx) => { if (!(c.ch === " " && !c.bg)) cells.push({ r, c: cIdx, ch: c.ch, col: c.col, bg: c.bg, shadow: c.shadow, i: cells.length }); }));
      const cols = rows[0] ? rows[0].length : 0;
      const G0 = { cells, rows: rows.length, cols, t: theme(), seed,
        L: -L.ox / L.cw, R: (L.W - L.ox) / L.cw, T: -L.oy / L.ch, B: (L.H - L.oy) / L.ch,
        maxD: Math.hypot(cols / 2, rows.length), px: cols * L.cw, py: rows.length * L.ch };
      G0.ms = msOf(name, G0);
      return G0;
    }

    function draw(now) {
      const L = layout(), g = canvas.getContext("2d");
      g.setTransform(L.dpr, 0, 0, L.dpr, 0, 0);
      g.clearRect(0, 0, L.W, L.H);
      g.font = `${Math.round(L.cw / 0.6)}px "JetBrains Mono", ui-monospace, monospace`; g.textBaseline = "middle"; g.textAlign = "center";
      const X = { x: (c) => L.ox + c * L.cw, y: (r) => L.oy + r * L.ch, cw: L.cw, ch: L.ch, W: L.W, H: L.H };
      let p = 1, band = null;
      if (name) {
        if (!G) { G = scene(L); if (FX[name] && FX[name].prep) FX[name].prep(G); }
        p = clamp((now - start) / G.ms);
      } else if (sweeping) {
        const tt = (now - sweepFrom) % 5600, W = rows[0] ? rows[0].length : 0;
        band = (tt / 1500) * (W + rows.length * 1.5 + 30) - 15;
      }
      const t = theme();
      if (name && FX[name]) {
        const fx = FX[name];
        Object.assign(G, { L: -L.ox / L.cw, R: (L.W - L.ox) / L.cw, T: -L.oy / L.ch, B: (L.H - L.oy) / L.ch });
        if (fx.under) fx.under(g, G, p, X);
        for (const c of G.cells) {
          const o = fx.cell(G, c, p);
          if (!o) continue;
          let col = o.col || t.foreground;
          if (o.glow) col = C.mix(col, "#ffffff", clamp(o.glow));
          cell(g, X.x(o.x), X.y(o.y), L.cw, L.ch, o.ch, col, o.a == null ? 1 : clamp(o.a), o.bg, o.text);
        }
        if (fx.over) fx.over(g, G, p, X);
      } else {
        // omascii's originals, or the still art (with the light crossing it)
        const fx = name ? Ascii.EFFECTS[name] : null;
        const AG = fx ? G : { rows: rows.length, cols: rows[0] ? rows[0].length : 0, maxD: 1, t, seed, px: 0, py: 0 };
        for (let r = 0; r < rows.length; r++) for (let c = 0; c < rows[r].length; c++) {
          const src = rows[r][c];
          const o = fx ? fx.cell(AG, r, c, src, p) : (src.ch === " " && !src.bg ? null : { ch: src.ch, col: src.col, bg: src.bg, a: 1 });
          if (!o) continue;
          let col = o.col || t.foreground, glow = o.glow || 0;
          if (band != null && !src.shadow) { const d = Math.abs(c + r * 1.5 - band); if (d < 6) glow = Math.max(glow, (1 - d / 6) * 0.7); }
          if (glow) col = C.mix(col, "#ffffff", clamp(glow));
          cell(g, X.x(c), X.y(r + (o.dr || 0)), L.cw, L.ch, o.ch, col, o.a == null ? 1 : o.a, o.bg, o.text);
        }
        if (fx && fx.overlay) { g.save(); g.translate(L.ox, L.oy); fx.overlay(g, AG, p); g.restore(); }
      }
      return p;
    }

    const frame = (now) => {
      raf = 0;
      const p = draw(now);
      if (name && p >= 1) {
        name = null; G = null; sweepFrom = now;
        const d = onDone; onDone = null; if (d) d();
      }
      if (name || sweeping) raf = requestAnimationFrame(frame);
    };
    const kick = () => { if (!raf) raf = requestAnimationFrame(frame); };
    const ro = new ResizeObserver(() => kick());
    ro.observe(canvas.parentElement);

    return {
      set(r) { rows = r; G = null; kick(); },
      play(n, done) {
        if (Oma.reduced) { name = null; kick(); if (done) setTimeout(done, 0); return; }
        name = FX[n] || Ascii.EFFECTS[n] ? n : "decrypt"; G = null; start = performance.now(); seed = Math.floor(Math.random() * 999); onDone = done || null; kick();
      },
      stop() { name = null; G = null; onDone = null; kick(); },
      sweep(on) { sweeping = on && !Oma.reduced; sweepFrom = performance.now(); kick(); },
      get playing() { return !!name; },
      get effect() { return name; },
      canvas,
    };
  }

  window.TTFX = { stage, GROUPS, ALL, FX, isOriginal };
})();
