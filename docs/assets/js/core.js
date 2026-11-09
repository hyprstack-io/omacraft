// Shared pieces (from the hyprstack.io OmaCraft site): the saved state, a tiny event bus, colour maths and helpers.
(function () {
  "use strict";

  const KEY = "omacraft-gh-v1";
  const defaults = {
    ws: 1,
    theme: { wallpaper: "monolith", wallColours: false, scheme: "material", contrast: 50, accent: null, preset: matchMedia("(prefers-color-scheme: light)").matches ? "latte" : "omacraft",
      follow: { bar: true, border: true, ascii: true, burn: true } },
    anim: { preset: "omarchy", speed: 1, enabled: true, windowStyle: "preset", workspaceStyle: "preset" },
    border: { id: "wallpaper", loop: true, speed: 6, size: 2, rounding: 0, gaps: 10, opacity: 88 },
    burn: { enabled: true, close: ["fire", "doom", "broken-glass", "tv", "snap", "glitch", "matrix", "portal"],
      open: ["glide", "focus", "energize-a", "pixelate", "border-trace"], speed: 1, intensity: 1, color: "effect", custom: "#ff7a1a", pick: "fire" },
    bar: { look: "omarchy", scheme: "theme", position: "top", float: false, opacity: 10, height: 32, gap: 6, launch: "drop",
      lanes: { left: ["logo", "workspaces", "title"], center: ["clock"], right: ["preset", "burn", "wallpaper", "theme", "fps", "net", "github"] },
      shelf: [] },
    barMine: [],
    banner: { font: "balistcx", ink: "theme" },
    ascii: { text: "Omarchy", font: "synergy", color: "font", shadow: "none", border: "none", effect: "decode", zoom: 10,
      source: "tdf", imgW: 96, ramp: "half" },
    walls: [],
    site: { showWall: true, switch: "burn", font: "tdf:balistcx", effect: null, auto: true, edit: "close",
      splash: { text: "Omarchy", font: "flf:ANSI Shadow", effect: "decrypt", ink: "theme", shadow: "none", border: "none" } },
  };

  const clone = (o) => JSON.parse(JSON.stringify(o));
  function merge(base, over) {
    if (!over || typeof over !== "object" || Array.isArray(over)) return over === undefined ? base : over;
    const out = Array.isArray(base) ? base.slice() : Object.assign({}, base);
    for (const k of Object.keys(over)) out[k] = base && typeof base[k] === "object" && !Array.isArray(base[k]) ? merge(base[k], over[k]) : over[k];
    return out;
  }

  let saved = null;
  try { saved = JSON.parse(localStorage.getItem(KEY) || "null"); } catch (e) { saved = null; }
  const state = merge(clone(defaults), saved || {});

  let saveTimer = 0;
  function save() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      try { localStorage.setItem(KEY, JSON.stringify(state)); }
      catch (e) {
        // Usually an uploaded wallpaper too big for storage: keep the rest.
        try { localStorage.setItem(KEY, JSON.stringify(Object.assign({}, state, { walls: [] }))); } catch (e2) { /* private mode */ }
      }
    }, 250);
  }

  const handlers = {};
  const on = (name, fn) => { (handlers[name] = handlers[name] || []).push(fn); };
  const emit = (name, data) => { (handlers[name] || []).forEach((fn) => fn(data)); };

  // ── colour ───────────────────────────────────────────
  function hex2rgb(hex) {
    hex = String(hex).replace("#", "");
    if (hex.length === 3) hex = hex.split("").map((c) => c + c).join("");
    const n = parseInt(hex.slice(0, 6), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  const rgb2hex = (r, g, b) => "#" + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("");
  function rgb2hsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    let h = 0, s = 0;
    const l = (max + min) / 2;
    if (max !== min) {
      const d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h *= 60;
    }
    return [h, s, l];
  }
  function hsl2rgb(h, s, l) {
    h = ((h % 360) + 360) % 360 / 360;
    if (s === 0) return [l * 255, l * 255, l * 255];
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    const f = (t) => {
      if (t < 0) t += 1; if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };
    return [f(h + 1 / 3) * 255, f(h) * 255, f(h - 1 / 3) * 255];
  }
  const hsl = (h, s, l) => rgb2hex(...hsl2rgb(h, Math.max(0, Math.min(1, s)), Math.max(0, Math.min(1, l))));
  const hexHsl = (hex) => rgb2hsl(...hex2rgb(hex));
  function mix(a, b, t) {
    const x = hex2rgb(a), y = hex2rgb(b);
    return rgb2hex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t);
  }
  function luminance(hex) {
    const c = hex2rgb(hex).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }
  const contrast = (a, b) => { const x = luminance(a), y = luminance(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const rgba = (hex, a) => { const c = hex2rgb(hex); return `rgba(${c[0]},${c[1]},${c[2]},${a})`; };

  // ── helpers ──────────────────────────────────────────
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => Array.from(root.querySelectorAll(s));
  function el(tag, attrs, ...kids) {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (k === "class") n.className = v;
      else if (k === "style") n.style.cssText = v;
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), v);
      else if (k === "html") n.innerHTML = v;
      else if (v !== false && v != null) n.setAttribute(k, v === true ? "" : v);
    }
    for (const kid of kids.flat()) if (kid != null) n.append(kid.nodeType ? kid : document.createTextNode(kid));
    return n;
  }

  let toastTimer = 0;
  function toast(msg) {
    const t = $("#toast");
    t.textContent = msg;
    t.classList.add("on");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove("on"), 2200);
  }

  async function copy(text, what = "Copied") {
    try { await navigator.clipboard.writeText(text); toast(what + " to the clipboard"); }
    catch (e) {
      const ta = el("textarea", { style: "position:fixed;opacity:0" }); ta.value = text; document.body.append(ta); ta.select();
      try { document.execCommand("copy"); toast(what + " to the clipboard"); } catch (e2) { toast("Couldn't reach the clipboard"); }
      ta.remove();
    }
  }

  function download(name, data, type = "text/plain") {
    const blob = data instanceof Blob ? data : new Blob([data], { type });
    const a = el("a", { href: URL.createObjectURL(blob), download: name });
    document.body.append(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }

  // Deterministic noise for effects: the same cell gets the same number.
  function hash(a, b = 0, c = 0) {
    let h = (a * 374761393 + b * 668265263 + c * 2147483647) | 0;
    h = (h ^ (h >>> 13)) * 1274126177;
    return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
  }
  const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
  const smooth = (a, b, v) => { const t = clamp((v - a) / (b - a)); return t * t * (3 - 2 * t); };
  const typing = (e) => { const t = e.target; return t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName)) && t.type !== "range" && t.type !== "checkbox"; };

  window.Oma = {
    state, defaults, save, on, emit, clone,
    color: { hex2rgb, rgb2hex, rgb2hsl, hsl2rgb, hsl, hexHsl, mix, luminance, contrast, rgba },
    $, $$, el, toast, copy, download, hash, clamp, smooth, typing,
    reduced: window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  };
})();
