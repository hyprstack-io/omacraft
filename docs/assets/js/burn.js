// Burn My Windows for the web: the omacraft.burn effects, played on any
// element on the page. Each effect is a pure function of its progress p
// (0 = the window whole, 1 = gone), so closing plays it forwards and opening
// plays the same thing backwards. An effect can:
//   css(p)            transform / filter / opacity on the element itself
//   field(x, y, p)    how much of the element shows at (x, y), 0…1, as a mask
//   draw(g, p)        particles and light on a canvas over it
//   pieces            split it into clipped copies that move on their own
(function () {
  "use strict";
  const { state, hash, clamp, smooth, color: C } = Oma;

  const noise1 = (x, seed = 0) => { const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f); return hash(i, seed) * (1 - u) + hash(i + 1, seed) * u; };
  function noise2(x, y, seed = 0) {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const a = hash(xi, yi, seed), b = hash(xi + 1, yi, seed), c = hash(xi, yi + 1, seed), d = hash(xi + 1, yi + 1, seed);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  }
  const ease = (t) => 1 - Math.pow(1 - clamp(t), 3);
  const lerp = (a, b, t) => a + (b - a) * t;
  const glyphs = "アイウエオカキクケコサシスセソタチツテトナニヌネノ01234567890ABCDEF<>/*+=";

  // ── the effects ───────────────────────────────────────
  const FX = {
    apparition: {
      css: (p) => ({ transform: `rotate(${p * 28}deg) scale(${1 - p * 0.55}) skewX(${p * 12}deg)`, filter: `blur(${p * 9}px) brightness(${1 + p * 0.6})`, opacity: 1 - Math.pow(p, 1.4) }),
      draw(g, p, S) { const a = Math.sin(p * Math.PI) * 0.55 * S.k; glow(g, S.W / 2, S.H / 2, Math.max(S.w, S.h) * (0.4 + p * 0.3), S.c1, a); },
    },
    "aura-glow": {
      field(x, y, p, S) { const d = Math.min(x, 1 - x, y, 1 - y) * 2 + noise2(x * 6, y * 6, S.seed) * 0.18; return d > p * 1.25 ? 1 : 0; },
      draw(g, p, S) {
        const inset = p * Math.min(S.w, S.h) * 0.62;
        g.save(); g.shadowColor = S.c1; g.shadowBlur = 24 * S.k; g.lineWidth = 3 + 6 * Math.sin(p * Math.PI);
        g.strokeStyle = C.rgba(S.c2, Math.sin(p * Math.PI)); g.strokeRect(S.x0 + inset, S.y0 + inset, Math.max(0, S.w - inset * 2), Math.max(0, S.h - inset * 2)); g.restore();
      },
    },
    "broken-glass": {
      pieces: (S) => shards(S, 5, 4),
      move(i, p, S, sh) {
        const t = clamp((p - 0.12) / 0.88);
        const dx = sh.cx - S.ix, dy = sh.cy - S.iy, len = Math.hypot(dx, dy) || 1;
        const v = (0.25 + hash(i, 7) * 0.6) * S.w;
        return { x: (dx / len) * v * t, y: (dy / len) * v * t * 0.6 + t * t * S.h * 1.2, r: (hash(i, 3) - 0.5) * 220 * t, o: 1 - Math.pow(t, 2.5) };
      },
      draw(g, p, S) {
        if (p > 0.35) return;
        g.save(); g.strokeStyle = C.rgba(S.c1, 0.85 * (1 - p / 0.35)); g.lineWidth = 1.2;
        const ix = S.x0 + S.ix, iy = S.y0 + S.iy;
        for (let i = 0; i < 14; i++) {
          const a = hash(i, 11) * Math.PI * 2, l = clamp(p / 0.12) * (0.25 + hash(i, 12) * 0.6) * Math.max(S.w, S.h);
          g.beginPath(); g.moveTo(ix, iy); g.lineTo(ix + Math.cos(a) * l * 0.5 + (hash(i, 13) - 0.5) * 20, iy + Math.sin(a) * l * 0.5); g.lineTo(ix + Math.cos(a) * l, iy + Math.sin(a) * l); g.stroke();
        }
        g.restore();
      },
    },
    doom: {
      pieces: (S) => columns(S, Math.max(10, Math.min(28, Math.round(S.w / 26)))),
      move(i, p) { const d = hash(i, 5) * 0.35; return { x: 0, y: Math.pow(clamp((p - d) / (1 - d)), 1.7) * 1.15, rel: true, o: 1 }; },
    },
    "energize-a": {
      css: (p) => ({ opacity: 1 - smooth(0.35, 0.9, p), filter: `brightness(${1 + Math.sin(p * Math.PI) * 1.2}) saturate(${1 - p * 0.6})` }),
      draw(g, p, S) {
        const n = Math.round(160 * S.k), a = Math.sin(p * Math.PI);
        for (let i = 0; i < n; i++) {
          const tw = 0.5 + 0.5 * Math.sin(p * 40 + i * 1.7);
          const x = S.x0 + hash(i, 1) * S.w, y = S.y0 + hash(i, 2) * S.h - p * 20 * hash(i, 4);
          spark(g, x, y, 1 + tw * 2.5, i % 3 ? S.c1 : S.c2, a * tw);
        }
      },
    },
    "energize-b": {
      css: (p) => ({ opacity: 1 - smooth(0.25, 0.85, p), filter: `sepia(${p * 0.8}) brightness(${1 + p})` }),
      draw(g, p, S) {
        const n = Math.round(70 * S.k), a = Math.sin(p * Math.PI);
        g.save(); g.globalCompositeOperation = "lighter";
        for (let i = 0; i < n; i++) {
          const x = S.x0 + hash(i, 1) * S.w, len = 20 + hash(i, 2) * 60, y = S.y0 + S.h - ((hash(i, 3) + p * 1.6) % 1.2) * S.h;
          const gr = g.createLinearGradient(x, y, x, y + len); gr.addColorStop(0, C.rgba(S.c1, a)); gr.addColorStop(1, C.rgba(S.c2, 0));
          g.fillStyle = gr; g.fillRect(x, y, 2, len);
        }
        g.restore();
      },
    },
    fire: {
      field(x, y, p, S) { const front = 1.08 - p * 1.25 + (noise1(x * 7 + p * 3, S.seed) - 0.5) * 0.14; return y < front ? clamp((front - y) * 18) : 0; },
      draw(g, p, S) {
        const n = Math.round(260 * S.k);
        g.save(); g.globalCompositeOperation = "lighter";
        for (let i = 0; i < n; i++) {
          const born = hash(i, 1) * 1.05 - 0.05, life = 0.12 + hash(i, 2) * 0.16, age = (p - born) / life;
          if (age < 0 || age > 1) continue;
          const xn = hash(i, 3), front = 1.08 - born * 1.25 + (noise1(xn * 7 + born * 3, S.seed) - 0.5) * 0.14;
          const x = S.x0 + xn * S.w + Math.sin(age * 6 + i) * 6, y = S.y0 + front * S.h - age * (30 + hash(i, 4) * 70);
          const r = (1 - age) * (6 + hash(i, 5) * 10) * S.k;
          glow(g, x, y, r * 2, age < 0.4 ? S.c2 : S.c1, (1 - age) * 0.8);
        }
        g.restore();
      },
    },
    focus: { css: (p) => ({ filter: `blur(${p * 18}px)`, transform: `scale(${1 + p * 0.06})`, opacity: 1 - p }) },
    glide: { css: (p) => ({ transform: `perspective(900px) rotateX(${p * 38}deg) scale(${1 - p * 0.25}) translateY(${-p * 6}%)`, opacity: 1 - p }) },
    glitch: {
      css: (p, S) => { const j = p > 0.02 && p < 0.97 ? (hash(Math.floor(p * 40), 9) - 0.5) * 30 * S.k : 0; return { transform: `translate(${j}px, ${j * 0.2}px)`, filter: `hue-rotate(${Math.floor(p * 12) * 30}deg)` }; },
      field(x, y, p, S) { const bx = Math.floor(x * 14), by = Math.floor(y * 10); return hash(bx, by, S.seed) * 0.9 + 0.05 > p ? 1 : 0; },
      draw(g, p, S) {
        const n = Math.round(14 * S.k), a = Math.sin(p * Math.PI);
        for (let i = 0; i < n; i++) {
          const f = Math.floor(p * 30) + i, y = S.y0 + hash(f, 1) * S.h, h = 2 + hash(f, 2) * 14, x = S.x0 + (hash(f, 3) - 0.2) * S.w;
          g.fillStyle = C.rgba(i % 2 ? S.c1 : S.c2, a * 0.7); g.fillRect(x, y, hash(f, 4) * S.w * 0.5, h);
        }
      },
    },
    hexagon: {
      field(x, y, p, S) {
        const h = hex(x * S.w, y * S.h, S.hs);
        const local = clamp((p - h.thr * 0.6) / 0.4);
        return h.d < 1 - local - 0.06 ? 1 : 0;
      },
      draw(g, p, S) {
        const a = Math.sin(p * Math.PI) * S.k;
        g.save(); g.strokeStyle = C.rgba(S.c1, a); g.shadowColor = S.c1; g.shadowBlur = 10; g.lineWidth = 1.5;
        hexGrid(g, S); g.restore();
      },
    },
    incinerate: {
      field(x, y, p, S) { const d = Math.hypot((x - S.sx) * S.w, (y - S.sy) * S.h) / S.diag + noise2(x * 5, y * 5, S.seed) * 0.12; return d > p * 1.3 ? clamp((d - p * 1.3) * 40) : 0; },
      draw(g, p, S) {
        const r = p * 1.3 * S.diag, cx = S.x0 + S.sx * S.w, cy = S.y0 + S.sy * S.h;
        g.save(); g.globalCompositeOperation = "lighter";
        const n = Math.round(120 * S.k);
        for (let i = 0; i < n; i++) {
          const a = hash(i, 1) * Math.PI * 2, rr = r - 0.12 * S.diag + noise2(Math.cos(a) * 3, Math.sin(a) * 3, S.seed) * 0.12 * S.diag;
          glow(g, cx + Math.cos(a) * rr, cy + Math.sin(a) * rr, 6 + hash(i, 2) * 8, i % 2 ? S.c1 : S.c2, 0.7 * (1 - p * 0.7));
        }
        g.restore();
      },
    },
    "magic-lamp": {
      css: (p) => { const t = ease(p); return { transformOrigin: "50% 100%", transform: `translateY(${t * 40}%) scale(${1 - t * 0.9}, ${1 - t})`, clipPath: `polygon(0 0, 100% 0, ${100 - t * 44}% 100%, ${t * 44}% 100%)`, opacity: 1 - smooth(0.7, 1, p) }; },
    },
    matrix: {
      field(x, y, p, S) { const c = Math.floor(x * S.cols); const head = p * 1.5 - hash(c, 4, S.seed) * 0.5; return y > head ? 1 : 0; },
      draw(g, p, S) {
        const cw = S.w / S.cols;
        g.save(); g.font = `${Math.max(8, cw)}px ${getComputedStyle(document.body).fontFamily}`; g.textAlign = "center";
        for (let c = 0; c < S.cols; c++) {
          const head = (p * 1.5 - hash(c, 4, S.seed) * 0.5) * S.h;
          for (let k = 0; k < 14; k++) {
            const y = head - k * cw * 1.1;
            if (y < 0 || y > S.h + cw) continue;
            const ch = glyphs[Math.floor(hash(c, k, Math.floor(p * 20)) * glyphs.length)];
            g.fillStyle = k === 0 ? C.rgba(S.c2, 1) : C.rgba(S.c1, (1 - k / 14) * (1 - smooth(0.85, 1, p)));
            g.fillText(ch, S.x0 + c * cw + cw / 2, S.y0 + y);
          }
        }
        g.restore();
      },
    },
    mushroom: {
      css: (p) => { const steps = [1, 0.82, 1, 0.64, 0.82, 0.46, 0.64, 0.28, 0.12, 0]; const s = steps[Math.min(steps.length - 1, Math.floor(p * steps.length))]; return { transform: `scale(${s})`, opacity: p > 0.92 ? 0 : 1, imageRendering: "pixelated" }; },
      draw(g, p, S) {
        const a = Math.sin(p * Math.PI), cx = S.W / 2, cy = S.H / 2, rays = 12;
        g.save(); g.translate(cx, cy); g.rotate(p * 3);
        for (let i = 0; i < rays; i++) { g.rotate((Math.PI * 2) / rays); g.fillStyle = C.rgba(i % 2 ? S.c1 : S.c2, a * 0.85); g.fillRect(0, -3, Math.max(S.w, S.h) * 0.6 * p, 6); }
        g.restore();
      },
    },
    "paint-brush": {
      field(x, y, p, S) {
        const rows = 6, r = Math.min(rows - 1, Math.floor(y * rows)), start = (r / rows) * 0.7, local = clamp((p - start) / 0.3);
        const edge = (noise1(y * 40, S.seed) - 0.5) * 0.06;
        const front = r % 2 ? 1 - local : local;
        return (r % 2 ? x < front + edge : x > front + edge) ? 1 : 0;
      },
      draw(g, p, S) {
        const rows = 6;
        for (let r = 0; r < rows; r++) {
          const start = (r / rows) * 0.7, local = clamp((p - start) / 0.3);
          if (local <= 0 || local >= 1) continue;
          const x = S.x0 + (r % 2 ? 1 - local : local) * S.w, y = S.y0 + (r + 0.5) / rows * S.h;
          g.fillStyle = C.rgba(S.c1, 0.9); g.beginPath(); g.ellipse(x, y, 14, S.h / rows * 0.6, 0, 0, Math.PI * 2); g.fill();
        }
      },
    },
    pixelate: {
      css: (p) => ({ filter: `blur(${p * 2}px) contrast(${1 + p})` }),
      field(x, y, p, S) { const b = 4 + Math.floor(p * 10); const bx = Math.floor((x * S.mw) / b), by = Math.floor((y * S.mh) / b); return hash(bx, by, b + S.seed) > p * 1.1 - 0.05 ? 1 : 0; },
    },
    "pixel-wheel": {
      css: (p) => ({ transform: `rotate(${ease(p) * 120}deg) scale(${1 - p * 0.45})` }),
      field(x, y, p, S) { const dx = x - 0.5, dy = (y - 0.5) * S.h / S.w; const a = (Math.atan2(dy, dx) / (Math.PI * 2) + 0.5), ring = Math.floor(Math.hypot(dx, dy) * 10); const seg = Math.floor(a * 18); return ((seg / 18 + ring * 0.07 + hash(seg, ring, S.seed) * 0.2) % 1) * 0.9 + 0.05 > p ? 1 : 0; },
    },
    "pixel-wipe": {
      field(x, y, p, S) { const b = 8, bx = Math.floor(x * S.mw / b), by = Math.floor(y * S.mh / b); const d = Math.hypot((bx * b / S.mw - S.px) * S.w, (by * b / S.mh - S.py) * S.h) / S.diag; return d * 0.85 + hash(bx, by, S.seed) * 0.15 > p * 1.05 ? 1 : 0; },
      draw(g, p, S) { const r = p * 1.05 * S.diag / 0.85; g.save(); g.strokeStyle = C.rgba(S.c1, Math.sin(p * Math.PI)); g.lineWidth = 3; g.shadowColor = S.c1; g.shadowBlur = 12; g.beginPath(); g.arc(S.x0 + S.px * S.w, S.y0 + S.py * S.h, Math.max(0, r), 0, Math.PI * 2); g.stroke(); g.restore(); },
    },
    portal: {
      css: (p) => ({ transform: `scale(${1 - smooth(0.15, 0.85, p)}) rotate(${smooth(0.15, 0.85, p) * 300}deg)`, opacity: 1 - smooth(0.6, 0.85, p), filter: `hue-rotate(${p * 90}deg)` }),
      draw(g, p, S) {
        const open = Math.sin(clamp(p) * Math.PI), R = Math.min(S.w, S.h) * 0.55 * open, cx = S.W / 2, cy = S.H / 2;
        if (R < 1) return;
        g.save(); g.translate(cx, cy);
        const gr = g.createRadialGradient(0, 0, 0, 0, 0, R); gr.addColorStop(0, C.rgba(S.c2, 0.9)); gr.addColorStop(0.6, C.rgba(S.c1, 0.6)); gr.addColorStop(1, C.rgba(S.c1, 0));
        g.fillStyle = gr; g.beginPath(); g.arc(0, 0, R, 0, Math.PI * 2); g.fill();
        g.strokeStyle = C.rgba(S.c2, 0.8); g.lineWidth = 2;
        for (let arm = 0; arm < 4; arm++) { g.beginPath(); for (let t = 0; t < 1; t += 0.02) { const a = arm * Math.PI / 2 + t * 6 + p * 12, r = t * R; g.lineTo(Math.cos(a) * r, Math.sin(a) * r); } g.stroke(); }
        g.restore();
      },
    },
    "rgb-warp": {
      css: (p, S) => { const x = Math.sin(p * 22) * p * 14 * S.k; return { filter: `drop-shadow(${-x}px 0 0 rgba(255,0,60,.8)) drop-shadow(${x}px 0 0 rgba(0,220,255,.8))`, transform: `skewX(${Math.sin(p * 30) * p * 10}deg) scaleY(${1 + Math.sin(p * 18) * p * 0.06})`, opacity: 1 - Math.pow(p, 2) }; },
    },
    snap: {
      field(x, y, p, S) { const t = x * 0.55 + noise2(x * 18, y * 18, S.seed) * 0.45; return t > p * 1.12 - 0.04 ? 1 : 0; },
      draw(g, p, S) {
        const n = Math.round(900 * S.k);
        for (let i = 0; i < n; i++) {
          const x = hash(i, 1), y = hash(i, 2), t = x * 0.55 + noise2(x * 18, y * 18, S.seed) * 0.45, born = (t + 0.04) / 1.12, age = (p - born) / 0.45;
          if (age < 0 || age > 1) continue;
          const px = S.x0 + x * S.w + age * (40 + hash(i, 3) * 120), py = S.y0 + y * S.h - age * (30 + hash(i, 4) * 60) + Math.sin(age * 8 + i) * 4;
          g.fillStyle = C.rgba(hash(i, 5) < 0.5 ? S.c1 : C.mix(S.c1, S.bg, 0.4), 1 - age); g.fillRect(px, py, 2, 2);
        }
      },
    },
    "team-rocket": {
      css: (p) => { const t = ease(p); return { transform: `translate(${t * 70}%, ${-t * 110}%) rotate(${t * 620}deg) scale(${1 - t * 0.97})`, opacity: p > 0.88 ? 0 : 1 }; },
      draw(g, p, S) {
        if (p < 0.82) return;
        const a = Math.sin(clamp((p - 0.82) / 0.18) * Math.PI), x = S.x0 + S.w / 2 + S.w * 0.7, y = S.y0 + S.h / 2 - S.h * 1.1;
        star(g, Math.min(S.W - 20, Math.max(20, x)), Math.max(20, y), 16 * a + 2, S.c1, a);
      },
    },
    trex: {
      pieces: (S) => strips(S, 4),
      move(i, p) { const t = clamp((p - 0.3) / 0.7); return { x: (i - 1.5) * 12 * t, y: t * t * 1.3, rel: true, r: (i % 2 ? 1 : -1) * 18 * t, o: 1 - smooth(0.75, 1, p) }; },
      draw(g, p, S) {
        const t = clamp(p / 0.3), fade = 1 - smooth(0.3, 0.6, p);
        g.save(); g.strokeStyle = C.rgba(S.c1, fade); g.lineWidth = 7; g.lineCap = "round"; g.shadowColor = S.c1; g.shadowBlur = 12;
        for (let k = 1; k < 4; k++) { const x0 = S.x0 + S.w * (k / 4 - 0.12), y0 = S.y0 - 10; g.beginPath(); g.moveTo(x0, y0); g.lineTo(x0 + S.w * 0.24 * t, y0 + (S.h + 20) * t); g.stroke(); }
        g.restore();
      },
    },
    tv: {
      css: (p) => (p < 0.5 ? { transform: `scale(1, ${Math.max(0.006, 1 - ease(p / 0.5))})`, filter: `brightness(${1 + p * 6})` } : { transform: `scale(${Math.max(0, 1 - ease((p - 0.5) / 0.5))}, 0.006)`, filter: "brightness(8)", opacity: p > 0.97 ? 0 : 1 }),
      draw(g, p, S) { if (p < 0.35) return; const a = Math.sin(clamp((p - 0.35) / 0.65) * Math.PI); glow(g, S.W / 2, S.H / 2, S.w * 0.4 * (1.2 - p), "#ffffff", a * 0.7); },
    },
    "tv-glitch": {
      css: (p, S) => { const base = FX.tv.css(p); const j = (hash(Math.floor(p * 50), 2) - 0.5) * 24 * S.k * (1 - p); base.transform = `translateX(${j}px) ` + base.transform; base.filter += ` hue-rotate(${Math.floor(p * 20) * 40}deg) drop-shadow(${j / 2}px 0 0 rgba(255,0,80,.7))`; return base; },
      draw(g, p, S) { FX.tv.draw(g, p, S); FX.glitch.draw(g, p * 0.6, S); },
    },
    wisps: {
      css: (p) => ({ opacity: 1 - smooth(0.1, 0.8, p) }),
      draw(g, p, S) {
        const n = Math.round(46 * S.k);
        g.save(); g.globalCompositeOperation = "lighter";
        for (let i = 0; i < n; i++) {
          const born = hash(i, 1) * 0.6, age = (p - born) / 0.4;
          if (age < 0 || age > 1) continue;
          const x = S.x0 + hash(i, 2) * S.w + Math.sin(age * 5 + i) * 26, y = S.y0 + hash(i, 3) * S.h - age * S.h * 0.5;
          glow(g, x, y, 10 + 14 * Math.sin(age * Math.PI), i % 2 ? S.c1 : S.c2, Math.sin(age * Math.PI) * 0.8);
        }
        g.restore();
      },
    },
    ascii: {
      field(x, y, p, S) { const cx = Math.floor(x * S.w / 9), cy = Math.floor(y * S.h / 15); return p * 1.4 < hash(cx, cy, S.seed) ? 1 : 0; },
      draw(g, p, S) {
        g.save(); g.font = `13px ${getComputedStyle(document.body).fontFamily}`; g.textBaseline = "top";
        const cols = Math.ceil(S.w / 9), rows = Math.ceil(S.h / 15), chars = "@#%*+=-:.";
        for (let cy = 0; cy < rows; cy++) for (let cx = 0; cx < cols; cx++) {
          const thr = hash(cx, cy, S.seed), on = p * 1.4 >= thr, off = p * 1.4 - 0.4 >= thr * 0.85 + 0.15;
          if (!on || off || hash(cx, cy, Math.floor(p * 30)) < 0.15) continue;
          g.fillStyle = C.rgba(hash(cx, cy, 3) < 0.5 ? S.c1 : S.c2, 0.85);
          g.fillText(chars[Math.floor(hash(cx, cy, Math.floor(p * 12)) * chars.length)], S.x0 + cx * 9, S.y0 + cy * 15);
        }
        g.restore();
      },
    },
    "warp-speed": {
      css: (p) => ({ transform: `translateX(${ease(p) * 60}%) scale(${1 + ease(p) * 2.2}, ${1 - ease(p) * 0.92})`, filter: `blur(${p * 6}px) brightness(${1 + p * 2})`, opacity: 1 - smooth(0.4, 0.95, p) }),
      draw(g, p, S) {
        const n = Math.round(60 * S.k), a = Math.sin(p * Math.PI);
        for (let i = 0; i < n; i++) {
          const y = S.y0 + hash(i, 1) * S.h, len = (40 + hash(i, 2) * 200) * p * 2, x = S.x0 + hash(i, 3) * S.w + p * S.w;
          const gr = g.createLinearGradient(x - len, y, x, y); gr.addColorStop(0, C.rgba(S.c1, 0)); gr.addColorStop(1, C.rgba(S.c2, a));
          g.fillStyle = gr; g.fillRect(x - len, y, len, 1.5);
        }
      },
    },
    dwindle: {
      field(x, y, p, S) {
        const gap = 0.012 + smooth(0, 0.15, p) * 0.012;
        for (let i = 0; i < S.tiles.length; i++) {
          const t = S.tiles[i];
          if (x < t.x || x > t.x + t.w || y < t.y || y > t.y + t.h) continue;
          if (x < t.x + gap || x > t.x + t.w - gap || y < t.y + gap * S.w / S.h || y > t.y + t.h - gap * S.w / S.h) return p < 0.04 ? 1 : 0;
          const local = clamp((p - (i / S.tiles.length) * 0.7) / 0.3), s = 1 - ease(local);
          const cx = t.x + t.w / 2, cy = t.y + t.h / 2;
          return Math.abs(x - cx) < (t.w / 2) * s && Math.abs(y - cy) < (t.h / 2) * s ? 1 : 0;
        }
        return 0;
      },
      draw(g, p, S) {
        g.save(); g.lineWidth = 2;
        S.tiles.forEach((t, i) => {
          const local = clamp((p - (i / S.tiles.length) * 0.7) / 0.3), s = 1 - ease(local);
          if (s <= 0.01 || p < 0.04) return;
          const w = t.w * S.w * s, h = t.h * S.h * s, x = S.x0 + (t.x + t.w / 2) * S.w - w / 2, y = S.y0 + (t.y + t.h / 2) * S.h - h / 2;
          const gr = g.createLinearGradient(x, y, x + w, y + h); gr.addColorStop(0, S.c1); gr.addColorStop(1, S.c2);
          g.strokeStyle = gr; g.globalAlpha = s; g.strokeRect(x + 3, y + 3, Math.max(0, w - 6), Math.max(0, h - 6));
        });
        g.restore();
      },
    },
    "boot-log": {
      field(x, y, p, S) { const line = Math.floor(y * S.lines); return line / S.lines >= p * 1.1 ? 1 : 0; },
      draw(g, p, S) {
        const lh = S.h / S.lines;
        g.save(); g.font = `${Math.min(13, lh * 0.8)}px ${getComputedStyle(document.body).fontFamily}`; g.textBaseline = "middle";
        const fade = 1 - smooth(0.85, 1, p);
        for (let i = 0; i < S.lines; i++) {
          if (i / S.lines >= p * 1.1) break;
          const y = S.y0 + (i + 0.5) * lh;
          g.fillStyle = C.rgba(S.bg, 0.9 * fade); g.fillRect(S.x0, y - lh / 2, S.w, lh);
          g.fillStyle = C.rgba(S.c1, fade); g.fillText("[  OK  ]", S.x0 + 8, y);
          g.fillStyle = C.rgba(S.c2, fade); g.fillText(BOOT[i % BOOT.length], S.x0 + 82, y);
        }
        g.restore();
      },
    },
    "theme-swap": {
      css: (p) => ({ filter: `hue-rotate(${smooth(0, 0.45, p) * 160}deg) saturate(${1 + p})` }),
      field(x, y, p, S) { const s = Math.floor(x * 12); return p < 0.45 + hash(s, 1, S.seed) * 0.5 ? 1 : 0; },
      draw(g, p, S) {
        if (p > 0.55) return;
        const bx = S.x0 + (p / 0.45) * (S.w + 120) - 60;
        const gr = g.createLinearGradient(bx - 60, 0, bx + 60, 0); gr.addColorStop(0, C.rgba(S.c1, 0)); gr.addColorStop(0.5, C.rgba(S.c2, 0.6)); gr.addColorStop(1, C.rgba(S.c1, 0));
        g.fillStyle = gr; g.fillRect(bx - 60, S.y0, 120, S.h);
      },
    },
    plymouth: {
      css: (p) => { const t = ease(clamp(p / 0.4)); return { transform: `scale(${1 - t * 0.55}, ${1 - t * 0.96})`, opacity: p < 0.4 ? 1 : 0, filter: `brightness(${1 + t})` }; },
      draw(g, p, S) {
        if (p < 0.35) return;
        const a = 1 - smooth(0.9, 1, p), bw = S.w * 0.45, bh = Math.max(6, S.h * 0.04), x = S.W / 2 - bw / 2, y = S.H / 2 - bh / 2;
        g.strokeStyle = C.rgba(S.c2, a); g.lineWidth = 1.5; g.strokeRect(x, y, bw, bh);
        g.fillStyle = C.rgba(S.c1, a); g.fillRect(x + 2, y + 2, (bw - 4) * ease(clamp((p - 0.4) / 0.45)), bh - 4);
      },
    },
    "border-trace": {
      css: (p) => ({ opacity: 1 - smooth(0.2, 0.9, p), transform: `scale(${1 - p * 0.04})` }),
      draw(g, p, S) {
        const per = 2 * (S.w + S.h), at = (d) => { d = ((d % per) + per) % per; if (d < S.w) return [S.x0 + d, S.y0]; d -= S.w; if (d < S.h) return [S.x0 + S.w, S.y0 + d]; d -= S.h; if (d < S.w) return [S.x0 + S.w - d, S.y0 + S.h]; return [S.x0, S.y0 + S.h - (d - S.w)]; };
        const a = Math.sin(p * Math.PI);
        for (let c = 0; c < 2; c++) for (let k = 0; k < 26; k++) {
          const [x, y] = at(p * per * 1.5 + c * per / 2 - k * 7);
          glow(g, x, y, 9 - k * 0.3, C.mix(S.c1, S.c2, k / 26), a * (1 - k / 26));
        }
      },
    },
    summit: {
      field(x, y, p, S) {
        const rows = 7, cols = 10, r = Math.floor(y * rows), fx = x * cols - (r % 2) * 0.5, c = Math.floor(fx * 2);
        const peak = y > 0.25 + Math.abs(x - 0.5) * 1.3;
        const thr = peak ? 0.8 + hash(c, r, 2) * 0.2 : hash(c, r, S.seed) * 0.75;
        return thr > p ? 1 : 0;
      },
    },
  };

  const BOOT = ["Started Hyprland compositor.", "Reached target Graphical Interface.", "Started OmaCraft plugin suite.", "Mounted /home.", "Started Network Manager.",
    "Started omarchy-shell.service.", "Reached target Sound Card.", "Started Burn My Windows.", "Loaded animation preset.", "Started swaync notifications."];

  // ── drawing helpers ──────────────────────────────────
  function glow(g, x, y, r, col, a) {
    if (a <= 0 || r <= 0) return;
    const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, C.rgba(col, a)); gr.addColorStop(1, C.rgba(col, 0));
    g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  function spark(g, x, y, r, col, a) { g.fillStyle = C.rgba(col, a); g.fillRect(x - r / 2, y - 0.5, r, 1); g.fillRect(x - 0.5, y - r / 2, 1, r); glow(g, x, y, r * 1.6, col, a * 0.5); }
  function star(g, x, y, r, col, a) { g.save(); g.translate(x, y); g.fillStyle = C.rgba(col, a); g.beginPath(); for (let i = 0; i < 8; i++) { const rr = i % 2 ? r * 0.25 : r; const an = (i / 8) * Math.PI * 2; g.lineTo(Math.cos(an) * rr, Math.sin(an) * rr); } g.fill(); g.restore(); glow(g, x, y, r * 2, col, a * 0.6); }

  function hex(x, y, s) {
    const q = ((Math.sqrt(3) / 3) * x - y / 3) / s, r = ((2 / 3) * y) / s;
    let rx = Math.round(q), ry = Math.round(-q - r), rz = Math.round(r);
    const dx = Math.abs(rx - q), dy = Math.abs(ry + q + r), dz = Math.abs(rz - r);
    if (dx > dy && dx > dz) rx = -ry - rz; else if (dy <= dz) rz = -rx - ry;
    const cx = s * Math.sqrt(3) * (rx + rz / 2), cy = s * 1.5 * rz;
    return { d: Math.hypot(x - cx, y - cy) / s, thr: hash(rx, rz, 77) };
  }
  function hexGrid(g, S) {
    const s = S.hs;
    for (let rz = -1; rz * s * 1.5 < S.h + s; rz++) for (let rx = -Math.ceil(rz / 2) - 1; s * Math.sqrt(3) * (rx + rz / 2) < S.w + s; rx++) {
      const cx = S.x0 + s * Math.sqrt(3) * (rx + rz / 2), cy = S.y0 + s * 1.5 * rz;
      g.beginPath(); for (let i = 0; i < 6; i++) { const a = Math.PI / 6 + (i * Math.PI) / 3; g.lineTo(cx + Math.cos(a) * s, cy + Math.sin(a) * s); } g.closePath(); g.stroke();
    }
  }

  // Pieces: polygons in element pixels.
  function columns(S, n) { const w = S.w / n; return Array.from({ length: n }, (_, i) => [[i * w, 0], [(i + 1) * w + 0.6, 0], [(i + 1) * w + 0.6, S.h], [i * w, S.h]]); }
  function strips(S, n) {
    const out = [];
    for (let i = 0; i < n; i++) { const a = (i / n) * S.w - S.w * 0.12, b = ((i + 1) / n) * S.w - S.w * 0.12, sk = S.w * 0.24; out.push([[a, 0], [b + 0.6, 0], [b + sk + 0.6, S.h], [a + sk, S.h]]); }
    out[0][0][0] = out[0][3][0] = -S.w; out[n - 1][1][0] = out[n - 1][2][0] = S.w * 2;
    return out;
  }
  function shards(S, nx, ny) {
    const pts = [];
    for (let j = 0; j <= ny; j++) for (let i = 0; i <= nx; i++) {
      const edgeX = i === 0 || i === nx, edgeY = j === 0 || j === ny;
      pts.push([(i / nx) * S.w + (edgeX ? 0 : (hash(i, j, 1) - 0.5) * S.w / nx * 0.7), (j / ny) * S.h + (edgeY ? 0 : (hash(i, j, 2) - 0.5) * S.h / ny * 0.7)]);
    }
    const P = (i, j) => pts[j * (nx + 1) + i], out = [];
    for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
      if ((i + j) % 2) { out.push([P(i, j), P(i + 1, j), P(i + 1, j + 1)]); out.push([P(i, j), P(i + 1, j + 1), P(i, j + 1)]); }
      else { out.push([P(i, j), P(i + 1, j), P(i, j + 1)]); out.push([P(i + 1, j), P(i + 1, j + 1), P(i, j + 1)]); }
    }
    return out;
  }

  function dwindleTiles(n) {
    const tiles = []; let x = 0, y = 0, w = 1, h = 1;
    for (let i = 0; i < n - 1; i++) {
      if (i % 2 === 0) { tiles.push({ x, y, w: w / 2, h }); x += w / 2; w /= 2; } else { tiles.push({ x, y, w, h: h / 2 }); y += h / 2; h /= 2; }
    }
    tiles.push({ x, y, w, h });
    return tiles;
  }

  function copyCanvases(from, to) {
    const a = from.querySelectorAll("canvas"), b = to.querySelectorAll("canvas");
    a.forEach((c, i) => { if (!b[i] || !c.width) return; b[i].width = c.width; b[i].height = c.height; try { b[i].getContext("2d").drawImage(c, 0, 0); } catch (e) { /* tainted */ } });
  }

  // ── playing one ─────────────────────────────────────
  let pointer = { x: innerWidth / 2, y: innerHeight / 2 };
  addEventListener("pointermove", (e) => { pointer = { x: e.clientX, y: e.clientY }; }, { passive: true });
  addEventListener("pointerdown", (e) => { pointer = { x: e.clientX, y: e.clientY }; }, { passive: true });

  const effectMeta = (id) => window.OMA_DATA.effects.find((e) => e.id === id);
  const available = () => window.OMA_DATA.effects.filter((e) => FX[e.id]);

  function colours(meta) {
    const t = window.Theme ? Theme.current : null;
    const mode = state.theme.follow.burn ? "theme" : state.burn.color;
    if (mode === "theme" && t) return [t.accent, t.accent_2];
    if (mode === "custom") return [state.burn.custom, C.mix(state.burn.custom, "#ffffff", 0.55)];
    return [meta.color, meta.color2];
  }

  const running = new WeakMap();

  // play(el, "close" | "open", { effect, delay, loop }) → Promise
  function play(el, mode = "close", opts = {}) {
    const list = (state.burn[mode] || []).filter((id) => FX[id]);
    const id = opts.effect || (list.length ? list[Math.floor(Math.random() * list.length)] : state.burn.pick);
    const fx = FX[id] || FX.fire, meta = effectMeta(id) || { duration: 1000, color: "#ffffff", color2: "#ffffff", pad: 0 };
    const prev = running.get(el); if (prev) prev.stop();

    const rect = el.getBoundingClientRect();
    const pad = Math.round(Math.max(rect.width, rect.height) * Math.max(0.15, meta.pad || 0) + 30);
    const [c1, c2] = colours(meta);
    const S = {
      w: rect.width, h: rect.height, x0: pad, y0: pad, W: rect.width + pad * 2, H: rect.height + pad * 2,
      diag: Math.hypot(rect.width, rect.height), c1, c2, bg: (window.Theme && Theme.current.background) || "#101010",
      k: state.burn.intensity, seed: Math.floor(Math.random() * 1000),
      ix: clamp(pointer.x - rect.left, 0, rect.width) || rect.width / 2, iy: clamp(pointer.y - rect.top, 0, rect.height) || rect.height / 2,
      px: clamp((pointer.x - rect.left) / rect.width), py: clamp((pointer.y - rect.top) / rect.height),
      sx: 0.2 + Math.random() * 0.6, sy: 0.25 + Math.random() * 0.5,
      cols: Math.max(12, Math.round(rect.width / 14)), lines: Math.max(8, Math.round(rect.height / 18)),
      hs: Math.max(14, rect.width / 14), tiles: dwindleTiles(6),
    };
    if (!(pointer.x >= rect.left && pointer.x <= rect.right && pointer.y >= rect.top && pointer.y <= rect.bottom)) { S.px = 0.5; S.py = 0.5; S.ix = rect.width / 2; S.iy = rect.height / 2; }
    const ms = (meta.duration || 1000) / state.burn.speed;

    // overlay canvas
    let cv = null, g = null;
    if (fx.draw) {
      cv = document.createElement("canvas"); cv.className = "burn-canvas";
      const dpr = Math.min(2, devicePixelRatio || 1);
      cv.width = Math.round(S.W * dpr); cv.height = Math.round(S.H * dpr);
      Object.assign(cv.style, { left: rect.left - pad + "px", top: rect.top - pad + "px", width: S.W + "px", height: S.H + "px" });
      g = cv.getContext("2d"); g.scale(dpr, dpr);
      document.body.append(cv);
    }
    // mask canvas
    let mc = null, mg = null, img = null;
    if (fx.field) {
      S.mw = Math.max(24, Math.min(160, Math.round(rect.width / 6))); S.mh = Math.max(16, Math.round(S.mw * rect.height / rect.width));
      mc = document.createElement("canvas"); mc.width = S.mw; mc.height = S.mh; mg = mc.getContext("2d"); img = mg.createImageData(S.mw, S.mh);
    }
    // pieces
    let pieces = null;
    if (fx.pieces) {
      pieces = fx.pieces(S).map((poly) => {
        const holder = document.createElement("div"); holder.className = "burn-piece";
        Object.assign(holder.style, { left: rect.left + "px", top: rect.top + "px", width: rect.width + "px", height: rect.height + "px", clipPath: `polygon(${poly.map(([x, y]) => `${x}px ${y}px`).join(",")})` });
        const copy = el.cloneNode(true);
        copy.removeAttribute("id"); copy.querySelectorAll("[id]").forEach((n) => n.removeAttribute("id"));
        Object.assign(copy.style, { position: "absolute", left: "0", top: "0", width: rect.width + "px", height: rect.height + "px", margin: "0", transform: "none", opacity: "1", visibility: "visible" });
        copyCanvases(el, copy);
        holder.append(copy); document.body.append(holder);
        const cx = poly.reduce((a, q) => a + q[0], 0) / poly.length, cy = poly.reduce((a, q) => a + q[1], 0) / poly.length;
        holder.style.transformOrigin = `${cx}px ${cy}px`;
        return { holder, cx, cy };
      });
    }

    const keys = ["transform", "filter", "opacity", "clipPath", "transformOrigin", "imageRendering"];
    const saved = {}; keys.forEach((k) => { saved[k] = el.style[k]; });

    function frame(p) {
      if (fx.css) { const s = fx.css(p, S); keys.forEach((k) => { el.style[k] = s[k] != null ? s[k] : saved[k]; }); }
      if (fx.field) {
        const d = img.data;
        for (let y = 0; y < S.mh; y++) for (let x = 0; x < S.mw; x++) {
          const a = fx.field((x + 0.5) / S.mw, (y + 0.5) / S.mh, p, S);
          const i = (y * S.mw + x) * 4; d[i] = d[i + 1] = d[i + 2] = 255; d[i + 3] = a * 255;
        }
        mg.putImageData(img, 0, 0);
        const url = `url(${mc.toDataURL()})`;
        el.style.maskImage = el.style.webkitMaskImage = url;
        el.style.maskSize = el.style.webkitMaskSize = "100% 100%";
      }
      if (pieces) {
        el.style.opacity = "0";
        pieces.forEach((pc, i) => {
          const m = fx.move(i, p, S, pc);
          const x = m.rel ? m.x * S.w : m.x, y = m.rel ? m.y * S.h : m.y;
          pc.holder.style.transform = `translate(${x}px, ${y}px) rotate(${m.r || 0}deg)`;
          pc.holder.style.opacity = m.o;
        });
      }
      if (g) { g.clearRect(0, 0, S.W, S.H); fx.draw(g, p, S); }
    }

    function cleanup(gone) {
      keys.forEach((k) => { el.style[k] = saved[k]; });
      el.style.maskImage = el.style.webkitMaskImage = ""; el.style.maskSize = el.style.webkitMaskSize = "";
      if (gone) el.style.opacity = "0";
      if (cv) cv.remove();
      if (pieces) pieces.forEach((pc) => pc.holder.remove());
      running.delete(el);
    }

    return new Promise((resolve) => {
      let start = 0, raf = 0, stopped = false;
      const delay = opts.delay || 0;
      // keep: hold the last frame until the next play on this element (a
      // close followed by an open, for previews) takes over from it.
      const done = () => {
        if (opts.keep) { resolve(); return; }
        cleanup(mode === "close");
        if (mode === "close") requestAnimationFrame(() => { el.style.opacity = saved.opacity; });
        resolve();
      };
      running.set(el, { stop() { stopped = true; cancelAnimationFrame(raf); cleanup(false); resolve(); } });
      frame(mode === "close" ? 0 : 1);
      const tick = (now) => {
        if (stopped) return;
        if (!start) start = now + delay;
        const t = clamp((now - start) / ms);
        frame(mode === "close" ? t : 1 - t);
        if (t < 1) raf = requestAnimationFrame(tick); else done();
      };
      raf = requestAnimationFrame(tick);
    });
  }

  window.Burn = { play, FX, available, effectMeta, stop: (el) => { const r = running.get(el); if (r) r.stop(); } };
})();
