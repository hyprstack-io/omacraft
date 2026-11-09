// omascii in the browser: TheDraw art drawn cell by cell on a canvas (so the
// blocks meet without a font's line gaps), styled like omascii (colours,
// shadows, borders), played through its intro effects, plus images turned
// into ASCII. Also the landing page's animated title, after AsciiTitle.qml.
(function () {
  "use strict";
  const { state, hash, clamp, smooth, color: C } = Oma;

  const SOLID = "█▀▄▌▐■";
  const SHADE = { "░": 0.34, "▒": 0.62, "▓": 0.9 };
  const NOISE = "▓▒░▀▄█";
  const theme = () => (window.Theme ? Theme.current : { foreground: "#c0caf5", accent: "#7aa2f7", accent_2: "#bb9af7", background: "#1a1b26", muted: "#565f89" });

  // ── styling a grid of {ch, fg, bg} into drawable {ch, col, bg} ─────
  const isBox = (ch) => /[─-╿]/.test(ch);
  function ink(rows, mode) {
    const t = theme(), R = rows.length, W = R ? rows[0].length : 0;
    return rows.map((row, r) => row.map((cell, c) => {
      const ch = cell.ch;
      if (ch === " " && !cell.bg) return { ch: " " };
      let col, bg = null;
      switch (mode) {
        case "font": col = cell.fg || t.foreground; bg = cell.bg; break;
        case "gradient-h": col = C.mix(t.accent, t.accent_2, W > 1 ? c / (W - 1) : 0); bg = cell.bg ? C.mix(col, t.background, 0.55) : null; break;
        case "gradient-v": col = C.mix(t.accent, t.foreground, R > 1 ? r / (R - 1) : 0); bg = cell.bg ? C.mix(col, t.background, 0.55) : null; break;
        case "rainbow": col = C.hsl((c / Math.max(1, W)) * 300 + r * 6, 0.75, 0.66); bg = cell.bg ? C.mix(col, t.background, 0.55) : null; break;
        case "mono": col = t.foreground; bg = cell.bg ? C.mix(t.foreground, t.background, 0.7) : null; break;
        default: // theme, as AsciiTitle: outlines in the text colour, shading in the accent
          col = SOLID.includes(ch) || isBox(ch) ? t.foreground : SHADE[ch] ? t.accent : t.accent_2;
          bg = cell.bg ? C.mix(t.accent, t.background, 0.62) : null;
      }
      return { ch, col, bg };
    }));
  }

  // omascii's shadows: a copy of the ink behind it, down and right.
  function shadow(rows, kind) {
    if (kind === "none" || !rows.length) return rows;
    const t = theme();
    const steps = kind === "long" ? [[1, 1], [2, 2], [3, 3]] : [[1, 2]];
    const H = rows.length + steps[steps.length - 1][0], W = rows[0].length + steps[steps.length - 1][1];
    const out = Array.from({ length: H }, (_, r) => Array.from({ length: W }, (_, c) => (rows[r] && rows[r][c]) || { ch: " " }));
    steps.slice().reverse().forEach(([dr, dc], i) => {
      const a = kind === "light" ? 0.25 : kind === "dark" ? 0.6 : 0.45 - i * 0.1;
      rows.forEach((row, r) => row.forEach((cell, c) => {
        if (cell.ch === " " && !cell.bg) return;
        const tgt = out[r + dr][c + dc];
        if (tgt.ch === " " && !tgt.bg && !(rows[r + dr] && rows[r + dr][c + dc] && rows[r + dr][c + dc].ch !== " ")) out[r + dr][c + dc] = { ch: "█", col: C.mix(t.background, t.accent, a), shadow: true };
      }));
    });
    return out;
  }

  const BORDERS = {
    single: "┌─┐│└┘", rounded: "╭─╮│╰╯", double: "╔═╗║╚╝", heavy: "┏━┓┃┗┛", block: "█▀██▄█",
  };
  function border(rows, kind) {
    const b = BORDERS[kind];
    if (!b || !rows.length) return rows;
    const t = theme(), col = t.accent, padR = 1, padC = 2, W = rows[0].length + padC * 2;
    const line = (l, m, r) => [{ ch: l, col }].concat(Array.from({ length: W }, () => ({ ch: m, col }))).concat([{ ch: r, col }]);
    const blank = () => Array.from({ length: W }, () => ({ ch: " " }));
    const side = (inner) => [{ ch: b[3], col }].concat(inner).concat([{ ch: b[3], col }]);
    const body = [];
    for (let i = 0; i < padR; i++) body.push(side(blank()));
    rows.forEach((row) => body.push(side(Array.from({ length: padC }, () => ({ ch: " " })).concat(row, Array.from({ length: padC }, () => ({ ch: " " }))))));
    for (let i = 0; i < padR; i++) body.push(side(blank()));
    return [line(b[0], b[1], b[2])].concat(body, [line(b[4], b[1], b[5])]);
  }

  // ── intro effects: omascii's own, played on any grid ─────────
  // cell(G, r, c, cell, p) → null (not drawn) or {ch, col, a, glow, dr}
  const real = (cell) => (cell.ch === " " && !cell.bg ? null : { ch: cell.ch, col: cell.col, bg: cell.bg, a: 1 });
  const EFFECTS = {
    decode: { name: "decode", ms: (G) => 90 + G.cols * 17 + 6 * 22 + 260,
      cell(G, r, c, cell, p) {
        if (cell.ch === " " && !cell.bg) return null;
        const t = p * this.ms(G), settle = 90 + c * 17 + ((r * 37 + c * 11) % 7) * 22;
        if (t < settle - 420) return null;
        if (t < settle) return { ch: NOISE[Math.floor(t / 60 + c * 7 + r * 3) % NOISE.length], col: G.t.accent, a: 0.35 };
        return real(cell);
      } },
    ripple: { name: "ripple", ms: () => 2600,
      cell(G, r, c, cell, p) {
        if (cell.ch === " " && !cell.bg) return null;
        const d = Math.hypot(c - G.cols / 2, (r - G.rows / 2) * 2), R = p * G.maxD * 1.2;
        if (d > R) return null;
        const o = real(cell);
        o.glow = Math.max(0, 1 - Math.abs(d - R) / 4) * 0.8 + Math.max(0, Math.sin(d * 0.6 - p * 24)) * 0.15 * (1 - p);
        return o;
      } },
    starfield: { name: "starfield", ms: () => 2600,
      cell(G, r, c, cell, p) { const a = smooth(0.35, 0.95, p); if (!a || (cell.ch === " " && !cell.bg)) return null; const o = real(cell); o.a = a; return o; },
      overlay(g, G, p) {
        const cx = G.px / 2, cy = G.py / 2, maxR = Math.hypot(cx, cy);
        for (let i = 0; i < 140; i++) {
          const a = hash(i, 1) * Math.PI * 2, z = (hash(i, 2) + p * (1 + hash(i, 3)) * 1.6) % 1, d = z * z * maxR, len = 4 + z * 26;
          g.strokeStyle = C.rgba(i % 4 ? G.t.foreground : G.t.accent, (1 - smooth(0.6, 1, p)) * z);
          g.lineWidth = 1 + z; g.beginPath(); g.moveTo(cx + Math.cos(a) * d, cy + Math.sin(a) * d); g.lineTo(cx + Math.cos(a) * (d + len), cy + Math.sin(a) * (d + len)); g.stroke();
        }
      } },
    neon: { name: "neon", ms: () => 2400,
      cell(G, r, c, cell, p) {
        if (cell.ch === " " && !cell.bg) return null;
        const grp = Math.floor(c / 6), on = hash(grp, 1, G.seed) * 0.55;
        if (p < on) return null;
        if (p < on + 0.18 && hash(grp, Math.floor(p * 60)) < 0.5) return null;
        const o = real(cell); o.glow = clamp(1 - (p - on - 0.18) / 0.3) * 0.6; if (p < on + 0.18) o.a = 0.6; return o;
      } },
    tetris: { name: "tetris", ms: () => 2800,
      cell(G, r, c, cell, p) {
        if (cell.ch === " " && !cell.bg) return null;
        const bx = Math.floor(c / 4), by = Math.floor(r / 2);
        const start = ((G.rows - 1 - r) / G.rows) * 0.55 + hash(bx, by, G.seed) * 0.2, l = clamp((p - start) / 0.25);
        if (l <= 0) return null;
        const o = real(cell); o.dr = -(1 - l) * (1 - l) * (r + 4); return o;
      } },
    spiral: { name: "spiral", ms: () => 2400,
      cell(G, r, c, cell, p) {
        if (cell.ch === " " && !cell.bg) return null;
        const dx = c - G.cols / 2, dy = (r - G.rows / 2) * 2;
        const th = (Math.atan2(dy, dx) / (Math.PI * 2) + 0.5), rad = Math.hypot(dx, dy) / G.maxD;
        const order = (1 - rad) * 0.65 + th * 0.3;
        if (p < order) return null;
        const o = real(cell); o.glow = clamp(1 - (p - order) / 0.08) * 0.8; return o;
      } },
    crt: { name: "crt", ms: () => 2000,
      cell(G, r, c, cell, p) {
        const mid = Math.floor(G.rows / 2);
        if (p < 0.15) return r === mid && Math.abs(c - G.cols / 2) < (p / 0.15) * G.cols / 2 ? { ch: "▀", col: "#ffffff", a: 0.9 } : null;
        if (cell.ch === " " && !cell.bg) return null;
        if (p < 0.5 && Math.abs(r - mid) > ((p - 0.15) / 0.35) * G.rows / 2 + 0.5) return null;
        const o = real(cell);
        o.glow = clamp(1 - (p - 0.15) / 0.5) * 0.7;
        if (r % 2) o.a = 1 - 0.4 * clamp(1 - (p - 0.5) / 0.5);
        if (hash(Math.floor(p * 40), 3) < 0.08 * (1 - p)) o.a *= 0.5;
        return o;
      } },
    plasma: { name: "plasma", ms: () => 3000,
      cell(G, r, c, cell, p) {
        if (cell.ch === " " && !cell.bg) return null;
        const v = Math.sin(c * 0.25 + p * 8) + Math.sin(r * 0.5 - p * 6) + Math.sin((c + r) * 0.15 + p * 4);
        const o = real(cell); o.col = C.mix(C.hsl(v * 60 + p * 360, 0.8, 0.62), cell.col || G.t.foreground, smooth(0.45, 0.95, p)); o.a = smooth(0, 0.12, p); return o;
      } },
    tunein: { name: "tunein", ms: () => 2200,
      cell(G, r, c, cell, p) {
        const q = Math.pow(p, 1.5), f = Math.floor(p * 40), ink = !(cell.ch === " " && !cell.bg);
        if (ink && hash(r, c, f) < q) return real(cell);
        if (ink) return { ch: NOISE[Math.floor(hash(c, r, f + 9) * NOISE.length)], col: G.t.muted, a: 0.55 };
        return hash(r, c, f + 3) < (1 - q) * 0.4 ? { ch: "░", col: G.t.muted, a: 0.3 } : null;
      } },
    helix: { name: "helix", ms: () => 2600,
      cell(G, r, c, cell, p) {
        const front = p * (G.cols + 26) - 13;
        if (c < front - 3) return real(cell);
        if (c > front) return null;
        const cy = (G.rows - 1) / 2, y1 = cy + Math.sin(c * 0.35 + p * 10) * G.rows * 0.45, y2 = cy - Math.sin(c * 0.35 + p * 10) * G.rows * 0.45;
        if (Math.abs(r - y1) < 0.6) return { ch: "█", col: G.t.accent, a: 1, glow: 0.3 };
        if (Math.abs(r - y2) < 0.6) return { ch: "█", col: G.t.accent_2, a: 1, glow: 0.3 };
        const o = real(cell); if (o) o.a = 0.5; return o;
      } },
    matrix: { name: "matrix", ms: () => 2600,
      cell(G, r, c, cell, p) {
        const head = (p * 1.6 - hash(c, 4, G.seed) * 0.6) * (G.rows + 6);
        const ink = !(cell.ch === " " && !cell.bg);
        if (r < head - 1 && ink) { const o = real(cell); o.col = C.mix(G.t.green || "#9ece6a", o.col || G.t.foreground, smooth(0, 6, head - r)); return o; }
        if (Math.abs(r - head) < 1) return { ch: "ｱｲｳｴｵ01ﾊﾐﾋ"[Math.floor(hash(r, c, Math.floor(p * 30)) * 10)], col: "#ffffff", a: 0.95, text: true };
        if (r < head && r > head - 6) return { ch: "ｱｲｳｴｵ01ﾊﾐﾋ"[Math.floor(hash(c, r, Math.floor(p * 18)) * 10)], col: G.t.green || G.t.accent, a: (1 - (head - r) / 6) * 0.7, text: true };
        return null;
      } },
  };

  // ── drawing ──────────────────────────────────────────
  // cw is a cell's width; a cell is twice as tall.
  function draw(canvas, rows, cw, fx, p, extra = {}) {
    const R = rows.length, W = R ? rows[0].length : 0, ch = cw * 2;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const pw = Math.max(1, Math.round(W * cw)), ph = Math.max(1, Math.round(R * ch));
    if (canvas.width !== Math.round(pw * dpr) || canvas.height !== Math.round(ph * dpr)) {
      canvas.width = Math.round(pw * dpr); canvas.height = Math.round(ph * dpr);
      canvas.style.width = pw + "px"; canvas.style.height = ph + "px";
    }
    const g = canvas.getContext("2d");
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, pw, ph);
    const t = theme();
    const G = { rows: R, cols: W, maxD: Math.hypot(W / 2, R), t, seed: extra.seed || 7, px: pw, py: ph };
    g.font = `${Math.round(cw / 0.6)}px "JetBrains Mono", monospace`; g.textBaseline = "middle"; g.textAlign = "center";
    const band = extra.band;
    for (let r = 0; r < R; r++) for (let c = 0; c < W; c++) {
      const cell = rows[r][c];
      const o = fx ? fx.cell(G, r, c, cell, p) : real(cell);
      if (!o) continue;
      let col = o.col || t.foreground, a = o.a == null ? 1 : o.a;
      let glow = o.glow || 0;
      if (band != null && !cell.shadow) { const d = Math.abs(c - r * 1.5 - band); if (d < 6) glow = Math.max(glow, (1 - d / 6) * 0.75); }
      if (glow) col = C.mix(col, "#ffffff", clamp(glow));
      const x = c * cw, y = (r + (o.dr || 0)) * ch;
      if (o.bg) { g.fillStyle = C.rgba(o.bg, a); g.fillRect(x, y, cw + 0.5, ch + 0.5); }
      const s = o.ch;
      if (s === " ") continue;
      if (SHADE[s] && !o.text) { g.fillStyle = C.rgba(col, a * SHADE[s]); g.fillRect(x, y, cw + 0.5, ch + 0.5); continue; }
      g.fillStyle = C.rgba(col, a);
      // A hair of overlap so neighbouring blocks don't show seams.
      if (s === "█" && !o.text) g.fillRect(x, y, cw + 0.5, ch + 0.5);
      else if (s === "▀") g.fillRect(x, y, cw + 0.5, ch / 2 + 0.5);
      else if (s === "▄") g.fillRect(x, y + ch / 2, cw + 0.5, ch / 2 + 0.5);
      else if (s === "▌") g.fillRect(x, y, cw / 2 + 0.5, ch + 0.5);
      else if (s === "▐") g.fillRect(x + cw / 2, y, cw / 2 + 0.5, ch + 0.5);
      else if (s === "■") g.fillRect(x + cw * 0.15, y + ch * 0.3, cw * 0.7, ch * 0.4);
      else g.fillText(s, x + cw / 2, y + ch / 2);
    }
    if (fx && fx.overlay) fx.overlay(g, G, p);
  }

  // A canvas that plays an effect on its grid, then holds it.
  function player(canvas) {
    let rows = [], cw = 10, fx = null, start = 0, raf = 0, onDone = null, sweep = false, sweepFrom = 0, seed = 1;
    const frame = (now) => {
      raf = 0;
      if (fx) {
        const ms = fx.ms({ cols: rows[0] ? rows[0].length : 1, rows: rows.length });
        const p = clamp((now - start) / ms);
        draw(canvas, rows, cw, fx, p, { seed });
        if (p >= 1) { fx = null; sweepFrom = now; const d = onDone; onDone = null; if (d) d(); }
        raf = requestAnimationFrame(frame);
        return;
      }
      if (sweep) {
        // The light: a slanted band crossing every 5.2 s, as on OmaCraft's title.
        const tt = (now - sweepFrom) % 5200;
        const W = rows[0] ? rows[0].length : 0;
        draw(canvas, rows, cw, null, 1, { band: (tt / 1400) * (W + 30) - 15 });
        raf = requestAnimationFrame(frame);
      } else draw(canvas, rows, cw, null, 1);
    };
    const kick = () => { if (!raf) raf = requestAnimationFrame(frame); };
    return {
      set(r, w) { rows = r; cw = w; kick(); },
      play(name, done) { fx = EFFECTS[name] || EFFECTS.decode; start = performance.now(); seed = Math.floor(Math.random() * 999); onDone = done || null; kick(); },
      still() { fx = null; kick(); },
      sweep(on) { sweep = on; sweepFrom = performance.now(); kick(); },
      get playing() { return !!fx; },
      get rows() { return rows; },
    };
  }

  // ── images ─────────────────────────────────────────
  async function fromImage(url, cols, ramp) {
    const im = await Theme.loadImage(url);
    const rowsN = Math.max(4, Math.round((cols * im.height) / im.width / 2));
    const sub = ramp === "half" ? 2 : 1;
    const cv = document.createElement("canvas"); cv.width = cols; cv.height = rowsN * sub;
    const g = cv.getContext("2d"); g.drawImage(im, 0, 0, cv.width, cv.height);
    const d = g.getImageData(0, 0, cv.width, cv.height).data;
    const px = (x, y) => { const i = (y * cv.width + x) * 4; return C.rgb2hex(d[i], d[i + 1], d[i + 2]); };
    const lum = (hex) => { const [r, gg, b] = C.hex2rgb(hex); return (0.299 * r + 0.587 * gg + 0.114 * b) / 255; };
    const rows = [];
    for (let r = 0; r < rowsN; r++) {
      const row = [];
      for (let c = 0; c < cols; c++) {
        if (ramp === "half") row.push({ ch: "▀", fg: px(c, r * 2), bg: px(c, r * 2 + 1) });
        else {
          const hex = px(c, r), L = lum(hex);
          const chars = ramp === "shade" ? " ░▒▓█" : " .:-=+*#%@";
          row.push({ ch: chars[Math.min(chars.length - 1, Math.floor(L * chars.length))], fg: hex, bg: null });
        }
      }
      rows.push(row);
    }
    return rows;
  }

  // ── text / ANSI out ────────────────────────────────
  const toText = (rows) => rows.map((r) => r.map((c) => c.ch || " ").join("").replace(/\s+$/, "")).join("\n");
  function toAnsi(rows) {
    const sgr = (hex, base) => { const [r, g, b] = C.hex2rgb(hex); return `\x1b[${base};2;${r};${g};${b}m`; };
    return rows.map((row) => {
      let s = "", last = "";
      for (const c of row) {
        const key = `${c.col}|${c.bg}`;
        if (key !== last) { s += "\x1b[0m" + (c.col ? sgr(c.col, 38) : "") + (c.bg ? sgr(c.bg, 48) : ""); last = key; }
        s += c.ch || " ";
      }
      return s + "\x1b[0m";
    }).join("\n");
  }

  window.Ascii = { ink, shadow, border, draw, player, fromImage, toText, toAnsi, EFFECTS };
})();
