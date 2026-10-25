// Post-processing for omascii art: works on a grid of cells
// ({ ch, fg, bg }, colours as "rrggbb" or null) whatever made it (FIGlet,
// TheDraw or an image). Fill swaps the ink characters, flip mirrors, shadow
// drops a shaded copy behind, border frames it, and the colour mode paints
// a gradient or the theme's rainbow over every cell without its own colour.

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const FLIPS = ["none", "horizontal", "vertical", "both"];
export const BORDERS = ["none", "single", "rounded", "double", "heavy", "ascii", "block", "shade",
  "dashed", "heavydash", "dotted", "doubleside", "bevel", "brackets", "corners", "stars", "wave", "hash", "braille"];
export const SHADOWS = ["none", "light", "medium", "dark", "solid", "outline", "glow", "long", "left", "under"];
export const COLOR_MODES = ["solid", "gradient", "rainbow", "palette", "stripes", "split"];
export const GRADIENTS = ["horizontal", "vertical", "diagonal", "radial", "diamond", "wave", "angle"];
// What sits behind each ink cell, as TheDraw colour fonts do: nothing, a
// darker shade of the ink's own colour, or the second colour.
export const INK_BGS = ["none", "shade", "color2"];

// Ready-made colour runs for the "palette" colour mode, painted along the
// gradient direction. Hex without "#", first stop first.
export const PALETTES = {
  sunset:     ["f8b195", "f67280", "c06c84", "6c5b7b", "355c7d"],
  synthwave:  ["fdf500", "ff2a6d", "d300c5", "05d9e8", "005678"],
  vaporwave:  ["ff71ce", "b967ff", "01cdfe", "05ffa1", "fffb96"],
  aurora:     ["00ff87", "60efff", "0061ff", "b16cea"],
  ocean:      ["a8edea", "4fc3f7", "0288d1", "01579b"],
  ice:        ["ffffff", "d6f3ff", "9ad9ff", "5ab8f5", "2e86de"],
  fire:       ["fff200", "ff9a00", "ff4d00", "e00000", "8b0000"],
  lava:       ["ffd36e", "ff6b35", "c81d25", "3d0c11"],
  forest:     ["d4fc79", "96e6a1", "43a047", "1b5e20"],
  matrix:     ["d1ffd1", "5aff5a", "00c800", "006400"],
  neon:       ["39ff14", "00f0ff", "ff00e6", "fffb00"],
  candy:      ["ff9a9e", "fecfef", "a18cd1", "fbc2eb"],
  pastel:     ["ffadad", "ffd6a5", "fdffb6", "caffbf", "9bf6ff", "a0c4ff", "bdb2ff", "ffc6ff"],
  gold:       ["fff6c9", "ffd700", "daa520", "8b6508"],
  chrome:     ["ffffff", "c0c0c0", "6d6d6d", "d8d8d8", "8a8a8a"],
  mono:       ["ffffff", "9e9e9e", "4a4a4a"],
  dracula:    ["ff79c6", "bd93f9", "8be9fd", "50fa7b", "f1fa8c"],
  nord:       ["8fbcbb", "88c0d0", "81a1c1", "5e81ac"],
  catppuccin: ["f5c2e7", "cba6f7", "89b4fa", "94e2d5", "a6e3a1", "f9e2af"],
  tokyonight: ["7aa2f7", "bb9af7", "7dcfff", "9ece6a", "e0af68", "f7768e"],
  // The DOS 16-colour runs ANSI art groups drew their logos in
  acid:       ["ffffff", "55ffff", "00aaaa", "aa00aa", "ff55ff"],
  bbs:        ["ffffff", "55ffff", "5555ff", "0000aa"],
  ansiheat:   ["ffff55", "ff5555", "aa0000", "550000"],
  vga:        ["55ff55", "55ffff", "5555ff", "ff55ff", "ff5555", "ffff55"],
  c64:        ["ffffff", "a5a5ff", "7c70da", "3e31a2"],
  amber:      ["ffe9a8", "ffb000", "cc7a00", "663d00"],
};

// One-click looks in the TheDraw ANSI style: a colour run, shading behind
// the ink, a shadow and a frame, plus a TheDraw font that suits them.
// `swatch` is what a picker shows; `options` are the config keys they set.
const LOOK = { fill: "", flip: "none", border: "none", padding: 0, shadow: "none", inkBg: "shade", fontColors: false, gradient: "vertical" };
export const PRESETS = [
  { id: "acid-trip", name: "ACiD Trip", font: "TDF acidx", swatch: PALETTES.acid,
    options: { ...LOOK, colorMode: "palette", colorPalette: "acid", shadow: "dark" } },
  { id: "ice-cold", name: "iCE Cold", font: "TDF fb-icefx", swatch: PALETTES.ice,
    options: { ...LOOK, colorMode: "palette", colorPalette: "ice", shadow: "glow" } },
  { id: "bbs-blue", name: "BBS Blue", font: "TDF lastbbs", swatch: PALETTES.bbs,
    options: { ...LOOK, colorMode: "palette", colorPalette: "bbs", shadow: "solid", border: "double", padding: 1 } },
  { id: "ansi-heat", name: "ANSi Heat", font: "TDF fire", swatch: PALETTES.ansiheat,
    options: { ...LOOK, colorMode: "palette", colorPalette: "ansiheat", shadow: "long" } },
  { id: "vga-16", name: "VGA 16", font: "TDF dope", swatch: PALETTES.vga,
    options: { ...LOOK, colorMode: "palette", colorPalette: "vga", gradient: "horizontal", shadow: "medium" } },
  { id: "commodore", name: "Commodore", font: "TDF commx", swatch: ["a5a5ff", "7c70da", "352879"],
    options: { ...LOOK, colorMode: "palette", colorPalette: "c64", inkBg: "color2", color2: "#352879", border: "block", padding: 1 } },
  { id: "amber-term", name: "Amber Term", font: "TDF metal", swatch: PALETTES.amber,
    options: { ...LOOK, colorMode: "palette", colorPalette: "amber", shadow: "under" } },
  { id: "phosphor", name: "Phosphor", font: "TDF matrixx", swatch: PALETTES.matrix,
    options: { ...LOOK, colorMode: "palette", colorPalette: "matrix", shadow: "light" } },
  { id: "neon-sign", name: "Neon Sign", font: "TDF neon", swatch: PALETTES.neon,
    options: { ...LOOK, colorMode: "palette", colorPalette: "neon", gradient: "horizontal", shadow: "glow", inkBg: "none" } },
  { id: "chrome", name: "Chrome Logo", font: "TDF metalix", swatch: ["ffffff", "c0c0c0", "6d6d6d"],
    options: { ...LOOK, colorMode: "split", color: "#ffffff", color2: "#7a7a8c", shadow: "long" } },
  { id: "synthwave", name: "Synthwave", font: "TDF synthicx", swatch: PALETTES.synthwave,
    options: { ...LOOK, colorMode: "palette", colorPalette: "synthwave", shadow: "long", border: "bevel", padding: 1 } },
  { id: "lava-flow", name: "Lava Flow", font: "TDF udmfire", swatch: PALETTES.lava,
    options: { ...LOOK, colorMode: "palette", colorPalette: "lava", gradient: "wave", shadow: "medium" } },
  { id: "tokyo-night", name: "Tokyo Night", font: "TDF midnight", swatch: PALETTES.tokyonight,
    options: { ...LOOK, colorMode: "palette", colorPalette: "tokyonight", gradient: "diagonal", shadow: "dark" } },
  // Follows whichever Omarchy theme is on, through the rainbow mode.
  { id: "omarchy", name: "Omarchy Theme", font: "TDF future2x", swatch: "theme",
    options: { ...LOOK, colorMode: "rainbow", gradient: "diagonal", shadow: "dark", border: "rounded", padding: 1 } },
];

const COLORS_TOML = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"),
  "omarchy", "current", "theme", "colors.toml");
// Stock Omarchy boot colours, as in build.py
const STOCK = { background: "2d353b", accent: "7fbbb3", foreground: "d3c6aa" };

let palette = null;

// The current Omarchy theme's colours by name ("accent", "blue", ...)
export function loadPalette() {
  if (palette) return palette;
  palette = { ...STOCK };
  try {
    const toml = readFileSync(COLORS_TOML, "utf8");
    for (const m of toml.matchAll(/^\s*([A-Za-z0-9_]+)\s*=\s*"#?([0-9a-fA-F]{6})"/gm)) palette[m[1]] = m[2].toLowerCase();
  } catch {}
  palette.accent ??= palette.foreground;
  return palette;
}

export function resolveColor(name) {
  const s = String(name || "").trim();
  if (/^#?[0-9a-fA-F]{6}$/.test(s)) return s.replace("#", "").toLowerCase();
  const pal = loadPalette();
  return pal[s] || pal.accent;
}

const blankCell = () => ({ ch: " ", fg: null, bg: null });
const isBlank = (c) => !c || (c.ch === " " && !c.bg);

export function textToCells(text) {
  const lines = String(text).split("\n");
  const width = Math.max(0, ...lines.map((l) => [...l].length));
  return lines.map((l) => {
    const chars = [...l];
    return Array.from({ length: width }, (_, i) => ({ ch: chars[i] ?? " ", fg: null, bg: null }));
  });
}

// Drop empty edge rows and columns, so the art centres on its ink
export function trimCells(rows) {
  rows = rows.filter(Boolean).slice();
  while (rows.length && rows[0].every(isBlank)) rows.shift();
  while (rows.length && rows[rows.length - 1].every(isBlank)) rows.pop();
  if (!rows.length) return [];
  const width = Math.max(...rows.map((r) => r.length));
  const filled = rows.map((r) => r.concat(Array.from({ length: width - r.length }, blankCell)));
  let left = 0;
  while (left < width && filled.every((r) => isBlank(r[left]))) left++;
  let right = width;
  while (right > left && filled.every((r) => isBlank(r[right - 1]))) right--;
  return filled.map((r) => r.slice(left, right));
}

const H_MIRROR = pairs("/\\ () [] {} <> ▌▐ ▖▗ ▘▝ ▙▟ ▛▜ ▚▞ ┌┐ └┘ ├┤ ┏┓ ┗┛ ┣┫ ╔╗ ╚╝ ╠╣ ╭╮ ╰╯ ╱╲ ▏▕ ⌐¬ ‹› «» bd pq");
const V_MIRROR = pairs("/\\ ▀▄ ▖▘ ▗▝ ▙▛ ▟▜ ▚▞ ┌└ ┐┘ ┬┴ ┏┗ ┓┛ ┳┻ ╔╚ ╗╝ ╦╩ ╭╰ ╮╯ ╱╲ ▁▔ _‾ ^v bp dq '. `,");

function pairs(spec) {
  const map = {};
  for (const p of spec.split(" ")) {
    const [a, b] = [...p];
    map[a] = b;
    map[b] = a;
  }
  return map;
}

function flip(rows, mode) {
  if (mode === "horizontal" || mode === "both")
    rows = rows.map((r) => r.slice().reverse().map((c) => ({ ...c, ch: H_MIRROR[c.ch] || c.ch })));
  if (mode === "vertical" || mode === "both")
    rows = rows.slice().reverse().map((r) => r.map((c) => ({ ...c, ch: V_MIRROR[c.ch] || c.ch })));
  return rows;
}

// Every ink character becomes the fill string's characters in turn, e.g.
// "█" for solid letters or "01" for binary
function fill(rows, chars) {
  const list = [...chars];
  if (!list.length) return rows;
  let n = 0;
  return rows.map((r) => r.map((c) => (c.ch === " " ? c : { ...c, ch: list[n++ % list.length] })));
}

const SHADOW_CHARS = { light: "░", medium: "▒", dark: "▓", solid: "█" };
// Cells of room the shadows may need around the ink (long reaches three)
const SHADOW_MARGIN = 3;

// What a shadow mode draws on an empty cell, given ink(dr, dc): whether the
// ink has a character dr rows up and dc columns left of it. Drop shadows
// copy the ink down and right, outline and glow ring it, long trails off
// diagonally, left drops down and left, under sits right beneath it.
function shadowChar(mode, ink) {
  const ring = (d) => {
    for (let dr = -d; dr <= d; dr++)
      for (let dc = -d; dc <= d; dc++)
        if (Math.max(Math.abs(dr), Math.abs(dc)) === d && ink(dr, dc)) return true;
    return false;
  };
  switch (mode) {
    case "outline": return ring(1) ? "·" : null;
    case "glow": return ring(1) ? "▒" : (ring(2) ? "░" : null);
    case "long":
      for (let k = 1; k <= 3; k++) if (ink(k, k)) return ["▓", "▒", "░"][k - 1];
      return null;
    case "left": return ink(1, -1) ? "░" : null;
    case "under": return ink(1, 0) ? "▀" : null;
    default: return ink(1, 1) ? SHADOW_CHARS[mode] || "░" : null;
  }
}

// A shaded copy or ring of the ink, drawn only on empty cells around it
function shadow(rows, mode) {
  if (mode === "none" || !rows.length) return rows;
  const m = SHADOW_MARGIN;
  const h = rows.length;
  const w = rows[0].length;
  const out = Array.from({ length: h + 2 * m }, (_, r) => Array.from({ length: w + 2 * m }, (_, c) => {
    const src = rows[r - m]?.[c - m];
    return src ? { ...src } : blankCell();
  }));
  for (let r = 0; r < h + 2 * m; r++) {
    for (let c = 0; c < w + 2 * m; c++) {
      if (!isBlank(out[r][c])) continue;
      const ink = (dr, dc) => {
        const cell = rows[r - dr - m]?.[c - dc - m];
        return !!cell && !isBlank(cell);
      };
      const ch = shadowChar(mode, ink);
      if (ch) out[r][c] = { ch, fg: null, bg: null, shade: true };
    }
  }
  return out;
}

// Seven characters (corner, top, corner, sides, corner, bottom, corner), or
// eight when the left and right sides differ (… left, right, …).
const FRAMES = {
  single:     "┌─┐│└─┘",
  rounded:    "╭─╮│╰─╯",
  double:     "╔═╗║╚═╝",
  heavy:      "┏━┓┃┗━┛",
  ascii:      "+-+|+-+",
  block:      "█▀██▀▀▀",
  shade:      "▒▒▒▒▒▒▒",
  dashed:     "┌╌┐╎└╌┘",
  heavydash:  "┏╍┓╏┗╍┛",
  dotted:     "╭┈╮┊╰┈╯",
  doubleside: "╓─╖║╙─╜",
  bevel:      "◢▀◣▌▐◥▄◤",
  brackets:   "⎡ ⎤⎢⎥⎣ ⎦",
  corners:    "┌ ┐ └ ┘",
  stars:      "✦─✦│✦─✦",
  wave:       "╭~╮│╰~╯",
  hash:       "#=#|#=#",
  braille:    "⡏⠉⢹⡇⢸⣇⣀⣸",
};

function border(rows, mode, padding) {
  const frame = FRAMES[mode];
  if (!frame) return pad(rows, padding);
  const chars = [...frame];
  const [tl, t, tr] = chars;
  const [l, r] = chars.length === 8 ? [chars[3], chars[4]] : [chars[3], chars[3]];
  const [bl, b, br] = chars.slice(-3);
  const inner = pad(rows, padding);
  const w = inner[0]?.length || 0;
  const edge = (ch) => ({ ch, fg: null, bg: null, frame: true });
  // The block frame's bottom edge is the lower half block
  const bottom = mode === "block" ? ["▀", "▀", "▀"] : [bl, b, br];
  return [
    [edge(tl), ...Array.from({ length: w }, () => edge(t)), edge(tr)],
    ...inner.map((row) => [edge(l), ...row, edge(r)]),
    [edge(bottom[0]), ...Array.from({ length: w }, () => edge(bottom[1])), edge(bottom[2])],
  ];
}

// Padding is cells: twice as many columns as rows, so it looks even
function pad(rows, padding) {
  const p = Math.max(0, Math.floor(padding) || 0);
  if (!p) return rows;
  const w = (rows[0]?.length || 0) + 4 * p;
  const empty = () => Array.from({ length: w }, blankCell);
  const side = () => Array.from({ length: 2 * p }, blankCell);
  return [...Array.from({ length: p }, empty), ...rows.map((r) => [...side(), ...r, ...side()]),
    ...Array.from({ length: p }, empty)];
}

function mix(a, b, t) {
  const n = (h, i) => parseInt(h.slice(i, i + 2), 16);
  return [0, 2, 4].map((i) => Math.round(n(a, i) + (n(b, i) - n(a, i)) * t).toString(16).padStart(2, "0")).join("");
}

function stopsAt(stops, t) {
  if (stops.length === 1) return stops[0];
  const x = Math.min(1, Math.max(0, t)) * (stops.length - 1);
  const i = Math.min(stops.length - 2, Math.floor(x));
  return mix(stops[i], stops[i + 1], x - i);
}

// Paint the colour mode over cells without their own colour. Shadow cells
// are dimmed toward the background.
function colorize(rows, config) {
  const mode = config.colorMode || "solid";
  const pal = loadPalette();
  const base = resolveColor(config.color);
  const second = resolveColor(config.color2);
  let stops = null;
  if (mode === "gradient") stops = [base, second];
  else if (mode === "palette") stops = PALETTES[config.colorPalette] || PALETTES.sunset;
  else if (mode === "rainbow")
    stops = ["red", "orange", "yellow", "green", "cyan", "blue", "magenta"].map((n) => pal[n]).filter(Boolean);
  if (stops && stops.length < 2) stops = ["ff5555", "ffff55", "55ff55", "55ffff", "5555ff", "ff55ff"];
  const h = rows.length;
  const w = rows[0]?.length || 0;
  const dir = config.gradient || "horizontal";
  const at = (r, c) => {
    const x = w > 1 ? c / (w - 1) : 0;
    const y = h > 1 ? r / (h - 1) : 0;
    // Cells are twice as tall as wide, so rows count double for round shapes
    const dy = (y - 0.5) * (h / Math.max(1, w)) * 2;
    if (dir === "vertical") return y;
    if (dir === "diagonal") return (x + y) / 2;
    if (dir === "radial") return Math.min(1, Math.hypot(x - 0.5, dy) * 2);
    if (dir === "diamond") return Math.min(1, Math.abs(x - 0.5) + Math.abs(dy));
    if (dir === "wave") return 0.5 + 0.5 * Math.sin(x * Math.PI * 4 + y * Math.PI);
    if (dir === "angle") return (Math.atan2(dy, x - 0.5) / (2 * Math.PI) + 1) % 1;
    return x;
  };
  // Stripes alternate the two colours a row at a time; split paints the top
  // half one and the bottom half the other, like chrome lettering.
  const banded = (r) => (mode === "stripes" ? (r % 2 ? second : base) : (r < h / 2 ? base : second));
  const inkBg = config.inkBg || "none";
  return rows.map((r, ri) => r.map((c, ci) => {
    if (c.ch === " " || c.fg) return c;
    // Without stops, plain ink keeps the art colour (fg null)
    let fg = mode === "stripes" || mode === "split" ? banded(ri) : (stops ? stopsAt(stops, at(ri, ci)) : null);
    if (c.shade) fg = mix(fg || base, pal.background || "000000", 0.55);
    // Half blocks and shading show the background through, which is where
    // TheDraw art gets its depth.
    let bg = c.bg;
    if (!bg && !c.shade && !c.frame && inkBg !== "none")
      bg = inkBg === "color2" ? second : mix(fg || base, "000000", 0.72);
    return fg || bg ? { ...c, fg: fg || base, bg: bg || null } : c;
  }));
}

// The whole pipeline, in the order the settings read top to bottom
export function applyStyle(rows, config) {
  let out = trimCells(rows);
  if (!out.length) return out;
  if (config.fill) out = fill(out, config.fill);
  if (config.flip && config.flip !== "none") out = flip(out, config.flip);
  if (config.shadow && config.shadow !== "none") out = trimCells(shadow(out, config.shadow));
  if ((config.border && config.border !== "none") || config.padding > 0) out = border(out, config.border, config.padding);
  out = colorize(out, config);
  return out.map((r) => r.map(({ ch, fg, bg }) => ({ ch, fg: fg || null, bg: bg || null })));
}

export function hasColor(rows) {
  return rows.some((r) => r.some((c) => c.fg || c.bg));
}

export function stripColor(rows) {
  return rows.map((r) => r.map((c) => ({ ch: c.ch, fg: null, bg: null })));
}
