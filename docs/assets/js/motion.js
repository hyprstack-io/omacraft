// Hyprland's animation tree in the browser, driven by the omacraft.animations
// presets: each leaf's speed (deciseconds), curve (bezier or spring) and style
// become Web Animations, so windows here open, move, close and switch
// workspaces the way the preset makes Hyprland do it.
(function () {
  "use strict";
  const { state } = Oma;
  const DATA = window.OMA_DATA;

  // Curves Omarchy (or Hyprland itself) already defines.
  const BUILTIN = {
    default: [0, 0.75, 0.15, 1], easeOutQuint: [0.23, 1, 0.32, 1], easeInOutCubic: [0.65, 0.05, 0.36, 1],
    linear: [0, 0, 1, 1], almostLinear: [0.5, 0.5, 0.75, 1], quick: [0.15, 0, 0.1, 1],
  };
  const WINDOW_STYLES = ["preset", "popin 90%", "popin 60%", "popin 30%", "popin 10%", "gnomed",
    "slide", "slide top", "slide bottom", "slide left", "slide right"];
  const WORKSPACE_STYLES = ["preset", "slide", "slidevert", "fade", "slidefade 20%", "slidefade 50%",
    "slidefadevert 20%", "slidefadevert 50%"];
  // Which leaf a missing one inherits from, as in Hyprland's tree.
  const PARENT = {
    windowsIn: "windows", windowsOut: "windows", windowsMove: "windows", windows: "global",
    fadeIn: "fade", fadeOut: "fade", fadeSwitch: "fade", fade: "global", border: "global", borderangle: "border",
    layersIn: "layers", layersOut: "layers", layers: "global", workspaces: "global", specialWorkspace: "workspaces",
  };

  const presetById = (id) => DATA.presets.find((p) => p.id === id) || DATA.presets[0];
  const curveDef = (name) => (BUILTIN[name] ? { type: "bezier", points: [[BUILTIN[name][0], BUILTIN[name][1]], [BUILTIN[name][2], BUILTIN[name][3]]] } : DATA.curves[name]);

  // A damped spring from 0 to 1: its samples and how long it takes to settle.
  const springCache = {};
  function spring(c) {
    const key = `${c.mass}|${c.stiffness}|${c.dampening}`;
    if (springCache[key]) return springCache[key];
    let x = 0, v = 0, t = 0;
    const dt = 1 / 600, pts = [];
    let settled = 0;
    while (t < 4) {
      const a = (-c.stiffness * (x - 1) - c.dampening * v) / c.mass;
      v += a * dt; x += v * dt; t += dt;
      pts.push([t, x]);
      if (Math.abs(x - 1) < 0.0015 && Math.abs(v) < 0.01) { if (!settled) settled = t; if (t > settled + 0.05) break; }
      else settled = 0;
    }
    const total = pts[pts.length - 1][0];
    const out = { seconds: total, samples: [] };
    const n = 56;
    for (let i = 0; i <= n; i++) {
      const target = (i / n) * total;
      const p = pts.find((q) => q[0] >= target) || pts[pts.length - 1];
      out.samples.push([i / n, i === n ? 1 : p[1]]);
    }
    springCache[key] = out;
    return out;
  }

  function easing(name) {
    const c = curveDef(name);
    if (!c) return "ease-out";
    if (c.type === "spring") return "linear(" + spring(c).samples.map(([t, y]) => `${y.toFixed(4)} ${(t * 100).toFixed(1)}%`).join(", ") + ")";
    const [[x0, y0], [x1, y1]] = c.points;
    return `cubic-bezier(${x0}, ${y0}, ${x1}, ${y1})`;
  }

  // Points along a curve for drawing it: [x, y] with x the time, 0…1.
  function curvePoints(name, n = 40) {
    const c = curveDef(name);
    if (!c) return [[0, 0], [1, 1]];
    if (c.type === "spring") return spring(c).samples;
    const [[x0, y0], [x1, y1]] = c.points;
    const pts = [];
    for (let i = 0; i <= n; i++) {
      const t = i / n, u = 1 - t;
      pts.push([3 * u * u * t * x0 + 3 * u * t * t * x1 + t * t * t, 3 * u * u * t * y0 + 3 * u * t * t * y1 + t * t * t]);
    }
    return pts;
  }

  function curveSvg(name) {
    const pts = curvePoints(name);
    const ys = pts.map((p) => p[1]);
    const lo = Math.min(0, ...ys), hi = Math.max(1, ...ys);
    const W = 100, H = 30;
    const y = (v) => H - ((v - lo) / (hi - lo)) * H;
    const d = pts.map((p, i) => `${i ? "L" : "M"}${(p[0] * W).toFixed(1)},${y(p[1]).toFixed(1)}`).join(" ");
    return `<svg viewBox="-2 -2 ${W + 4} ${H + 4}" preserveAspectRatio="none"><line class="grid" x1="0" x2="${W}" y1="${y(1)}" y2="${y(1)}" stroke-dasharray="2 3"/><line class="grid" x1="0" x2="${W}" y1="${y(0)}" y2="${y(0)}"/><path class="curve" d="${d}" vector-effect="non-scaling-stroke"/></svg>`;
  }

  // The leaf as the preset sets it (inherited if missing), with the speed
  // multiplier and the window / workspace shape overrides.
  function leaf(name, preset = presetById(state.anim.preset), speed = state.anim.speed, look = state.anim) {
    if (!state.anim.enabled || preset.enabled === false) return null;
    const anims = preset.animations || {};
    let n = name, spec;
    while (n) {
      if (n in anims) { spec = anims[n]; break; }
      n = PARENT[n];
    }
    if (spec === false) return null;
    if (!spec) spec = [8, "default"];
    let style = spec[2] || "";
    if (/^windows/.test(name) && look.windowStyle && look.windowStyle !== "preset") style = look.windowStyle;
    if (name === "workspaces" && look.workspaceStyle && look.workspaceStyle !== "preset") style = look.workspaceStyle;
    const c = curveDef(spec[1]);
    let ms = Math.min(10000, Math.max(10, (spec[0] * 100) / speed));
    // Springs run for as long as they take to settle, scaled by the speed.
    if (c && c.type === "spring") ms = Math.max(ms, (spring(c).seconds * 1000) / speed);
    return { ms, curve: spec[1], easing: easing(spec[1]), style };
  }

  const pct = (style, fallback) => { const m = /(\d+)%/.exec(style || ""); return m ? Number(m[1]) / 100 : fallback; };

  // Where a window slides in from: its nearest edge, unless the style says.
  function slideFrom(style, rect, box) {
    let side = (style.split(" ")[1] || "").trim();
    if (!side) {
      const cx = rect.left + rect.width / 2 - box.left, cy = rect.top + rect.height / 2 - box.top;
      const d = { left: cx, right: box.width - cx, top: cy, bottom: box.height - cy };
      side = Object.keys(d).sort((a, b) => d[a] - d[b])[0];
    }
    const off = { left: [-(rect.right - box.left + 20), 0], right: [box.right - rect.left + 20, 0], top: [0, -(rect.bottom - box.top + 20)], bottom: [0, box.bottom - rect.top + 20] };
    return off[side] || off.bottom;
  }

  function windowFrames(style, el, box) {
    style = style || "popin 87%";
    if (style.startsWith("slide")) {
      const [x, y] = slideFrom(style, el.getBoundingClientRect(), box);
      return [{ transform: `translate(${x}px, ${y}px)` }, { transform: "none" }];
    }
    if (style.startsWith("gnomed")) return [{ transform: "scale(1, 0.02)" }, { transform: "none" }];
    const s = pct(style, 0.87);
    return [{ transform: `scale(${s})` }, { transform: "none" }];
  }

  const finished = (anims) => Promise.all(anims.map((a) => a.finished.catch(() => {})));

  // A window appearing: its shape on windowsIn, its opacity on fadeIn.
  function open(el, box = el.offsetParent ? el.offsetParent.getBoundingClientRect() : document.body.getBoundingClientRect(), opts = {}) {
    const w = leaf("windowsIn", opts.preset, opts.speed, opts.look), f = leaf("fadeIn", opts.preset, opts.speed);
    const anims = [];
    if (w) anims.push(el.animate(windowFrames(w.style, el, box), { duration: w.ms, easing: w.easing, delay: opts.delay || 0, fill: "backwards" }));
    if (f) anims.push(el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: f.ms, easing: f.easing, delay: opts.delay || 0, fill: "backwards" }));
    return finished(anims);
  }

  // A window going away, on windowsOut and fadeOut; it stays gone (fill forwards).
  function close(el, box = el.offsetParent ? el.offsetParent.getBoundingClientRect() : document.body.getBoundingClientRect(), opts = {}) {
    const w = leaf("windowsOut", opts.preset, opts.speed, opts.look), f = leaf("fadeOut", opts.preset, opts.speed);
    const anims = [];
    if (w) anims.push(el.animate(windowFrames(w.style, el, box).reverse(), { duration: w.ms, easing: w.easing, fill: "forwards" }));
    if (f) anims.push(el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: f.ms, easing: f.easing, fill: "forwards" }));
    if (!anims.length) anims.push(el.animate([{ opacity: 0 }, { opacity: 0 }], { duration: 1, fill: "forwards" }));
    return finished(anims);
  }

  // FLIP: from where it was to where it is now, on windowsMove.
  function move(el, from, opts = {}) {
    const m = leaf("windowsMove", opts.preset, opts.speed);
    const to = el.getBoundingClientRect();
    if (!m || !from || !to.width) return Promise.resolve();
    const dx = from.left - to.left, dy = from.top - to.top, sx = from.width / to.width, sy = from.height / to.height;
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1 && Math.abs(sx - 1) < 0.01 && Math.abs(sy - 1) < 0.01) return Promise.resolve();
    return el.animate([{ transformOrigin: "0 0", transform: `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})` }, { transformOrigin: "0 0", transform: "none" }],
      { duration: m.ms, easing: m.easing }).finished.catch(() => {});
  }

  // Two workspaces trading places; dir is +1 for a higher number.
  function workspace(from, to, dir, opts = {}) {
    const w = leaf("workspaces", opts.preset, opts.speed, opts.look);
    if (!w || !from) return Promise.resolve();
    const style = w.style || "slide";
    const vert = style.includes("vert");
    const axis = vert ? "Y" : "X";
    const anims = [];
    const t = { duration: w.ms, easing: w.easing };
    if (style === "fade") {
      anims.push(from.animate([{ opacity: 1 }, { opacity: 0 }], t), to.animate([{ opacity: 0 }, { opacity: 1 }], t));
    } else if (style.startsWith("slidefade")) {
      const d = pct(style, 0.2) * 100;
      anims.push(from.animate([{ opacity: 1, transform: "none" }, { opacity: 0, transform: `translate${axis}(${-dir * d}%)` }], t));
      anims.push(to.animate([{ opacity: 0, transform: `translate${axis}(${dir * d}%)` }, { opacity: 1, transform: "none" }], t));
    } else {
      anims.push(from.animate([{ transform: "none" }, { transform: `translate${axis}(calc(${-dir * 100}% - ${dir * 20}px))` }], t));
      anims.push(to.animate([{ transform: `translate${axis}(calc(${dir * 100}% + ${dir * 20}px))` }, { transform: "none" }], t));
    }
    return finished(anims);
  }

  // ── the Lua omarchy-animations writes ──────────────────
  const luaNum = (v) => { const s = Number(v).toFixed(4).replace(/0+$/, "").replace(/\.$/, ""); return s || "0"; };
  const luaStr = (v) => JSON.stringify(String(v));
  function lua(preset = presetById(state.anim.preset), speed = state.anim.speed, look = state.anim, border = null) {
    const lines = [
      "-- Generated by the omacraft.animations Omarchy plugin. Don't edit by hand:",
      "-- pick a preset from the bar, or run `omarchy-animations`. Add your own",
      "-- presets in ~/.config/omarchy/animation-presets.json.",
      `-- preset: ${preset.id}  speed: ${luaNum(speed)}x`, "",
    ];
    const enabled = preset.enabled !== false && state.anim.enabled;
    lines.push(`hl.config({ animations = { enabled = ${enabled ? "true" : "false"} } })`);
    if (!enabled) return lines.join("\n") + "\n";
    const animations = Object.assign({}, preset.animations || {});
    for (const [leaves, key] of [[["windows", "windowsIn", "windowsOut"], "windowStyle"], [["workspaces"], "workspaceStyle"]]) {
      const style = look[key] || "preset";
      if (style !== "preset") for (const l of leaves) if (animations[l]) animations[l] = [animations[l][0], animations[l][1], style];
    }
    const used = [];
    for (const spec of Object.values(animations)) if (spec && !BUILTIN[spec[1]] && !used.includes(spec[1])) used.push(spec[1]);
    if (used.length) lines.push("");
    for (const name of used) {
      const c = DATA.curves[name];
      if (!c) continue;
      if (c.type === "spring") lines.push(`hl.curve(${luaStr(name)}, { type = "spring", mass = ${luaNum(c.mass)}, stiffness = ${luaNum(c.stiffness)}, dampening = ${luaNum(c.dampening)} })`);
      else { const [[x0, y0], [x1, y1]] = c.points; lines.push(`hl.curve(${luaStr(name)}, { type = "bezier", points = { { ${luaNum(x0)}, ${luaNum(y0)} }, { ${luaNum(x1)}, ${luaNum(y1)} } } })`); }
    }
    if (Object.keys(animations).length) lines.push("");
    for (const [name, spec] of Object.entries(animations)) {
      if (!spec) { lines.push(`hl.animation({ leaf = ${luaStr(name)}, enabled = false })`); continue; }
      const duration = Math.min(100, Math.max(0.1, Math.round((spec[0] / speed) * 100) / 100));
      const kind = (DATA.curves[spec[1]] || {}).type === "spring" ? "spring" : "bezier";
      const parts = [`leaf = ${luaStr(name)}`, "enabled = true", `speed = ${luaNum(duration)}`, `${kind} = ${luaStr(spec[1])}`];
      if (spec[2]) parts.push(`style = ${luaStr(spec[2])}`);
      lines.push(`hl.animation({ ${parts.join(", ")} })`);
    }
    if (border && border.colors && border.colors.length) {
      const colors = `{ colors = { ${border.colors.map((c) => luaStr(`rgba(${c.replace("#", "")}ee)`)).join(", ")} }, angle = ${border.angle || 45} }`;
      lines.push("", `-- border: ${border.id}`, `hl.config({ general = { col = { active_border = ${colors} } }, group = { col = { border_active = ${colors} } } })`);
      if (border.loop) lines.push(`hl.animation({ leaf = "borderangle", enabled = true, speed = ${border.speed * 10}, bezier = "linear", style = "loop" })`);
    }
    return lines.join("\n") + "\n";
  }

  window.Motion = { leaf, easing, curveSvg, curvePoints, open, close, move, workspace, lua, presetById, WINDOW_STYLES, WORKSPACE_STYLES, BUILTIN };
})();
