#!/usr/bin/env node
// The README's animated title: OMACRAFT in TheDraw balistcx (as on
// OmaCraft's landing page), drawn as an SVG that GitHub plays inside the
// README. Columns arrive in a decrypt-like sweep, a light crosses them, and
// it loops; dark and light follow the reader's colour scheme.
//
//   node docs/tools/readme-title.mjs [font] [text]  -> docs/assets/readme-title.svg
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const DOCS = join(dirname(fileURLToPath(import.meta.url)), "..");
const [font = "balistcx", text = "OMACRAFT"] = process.argv.slice(2);

// Load the page's own data and TheDraw reader.
const ctx = { window: {}, atob, document: { createElement: () => ({}), head: { append() {} } }, console };
ctx.window.window = ctx.window;
vm.createContext(ctx);
for (const f of ["data.js", "tdf.js"]) vm.runInContext(readFileSync(join(DOCS, "assets", "js", f), "utf8").replace(/\bwindow\./g, "window."), ctx);
const TDF = ctx.window.TDF;
const rows = TDF.render(font, text);
if (!rows.length) { console.error(`${font} can't draw "${text}"`); process.exit(1); }

const R = rows.length, W = rows[0].length, cw = 12, ch = 24, pad = 24;
const SOLID = "█▀▄▌▐■", SHADE = { "░": 0.34, "▒": 0.62, "▓": 0.9 };
const ink = (c) => (SOLID.includes(c) || /[─-╿]/.test(c) ? "fg" : SHADE[c] ? "a1" : "a2");

// Runs of the same shape and ink per row and column band, so the file stays small.
const BAND = 2;
const bands = new Map();
for (let r = 0; r < R; r++) {
  for (let c = 0; c < W; c++) {
    const cell = rows[r][c], s = cell.ch;
    if (s === " " && !cell.bg) continue;
    let x = c * cw, y = r * ch, w = cw, h = ch, op = 1;
    if (s === "▀") h = ch / 2;
    else if (s === "▄") { y += ch / 2; h = ch / 2; }
    else if (s === "▌") w = cw / 2;
    else if (s === "▐") { x += cw / 2; w = cw / 2; }
    else if (s === "■") { x += cw * 0.15; y += ch * 0.3; w = cw * 0.7; h = ch * 0.4; }
    else if (SHADE[s]) op = SHADE[s];
    const b = Math.floor(c / BAND), cls = ink(s) + (op < 1 ? ` o${Math.round(op * 100)}` : "");
    if (!bands.has(b)) bands.set(b, []);
    const list = bands.get(b), last = list[list.length - 1];
    // merge with the cell to the left when it lines up
    if (last && last.cls === cls && last.y === y && last.h === h && Math.abs(last.x + last.w - x) < 0.01) last.w += w;
    else list.push({ x, y, w, h, cls });
  }
}
const n = (v) => +v.toFixed(2);
const width = W * cw + pad * 2, height = R * ch + pad * 2, B = Math.ceil(W / BAND);
const groups = [...bands.entries()].sort((a, b) => a[0] - b[0]).map(([b, list]) => {
  // the order columns settle in: a soft sweep with a little scatter, as decrypt
  const delay = (b / B) * 1.1 + ((b * 37) % 7) * 0.05;
  return `<g class="b" style="animation-delay:${delay.toFixed(2)}s">${list.map((q) => `<rect class="${q.cls}" x="${n(q.x)}" y="${n(q.y)}" width="${n(q.w)}" height="${n(q.h)}"/>`).join("")}</g>`;
}).join("\n");

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="img" aria-label="${text}">
<title>${text}</title>
<style>
  :root { --bg: #0d0d0d; --grid: rgba(255,255,255,.045); --fg: #ece9e4; --a1: #f2c40f; --a2: #7fd4c1; }
  @media (prefers-color-scheme: light) { :root { --bg: #f6f6f4; --grid: rgba(0,0,0,.05); --fg: #1d1c1a; --a1: #c99a00; --a2: #138a7a; } }
  .bg { fill: var(--bg); } .grid { stroke: var(--grid); stroke-width: 1; }
  .fg { fill: var(--fg); } .a1 { fill: var(--a1); } .a2 { fill: var(--a2); }
  .o34 { opacity: .34; } .o62 { opacity: .62; } .o90 { opacity: .9; }
  .b { opacity: 0; animation: in 9s cubic-bezier(.16,1,.3,1) infinite; }
  @keyframes in {
    0% { opacity: 0; transform: translateY(-10px); }
    3% { opacity: .5; } 6%, 86% { opacity: 1; transform: none; }
    92%, 100% { opacity: 0; transform: translateY(6px); }
  }
  .shine { animation: shine 9s linear infinite; mix-blend-mode: overlay; }
  @keyframes shine { 0%, 30% { transform: translateX(-${width}px); } 52%, 100% { transform: translateX(${width}px); } }
  @media (prefers-reduced-motion: reduce) { .b, .shine { animation: none; opacity: 1; } .shine { display: none; } }
</style>
<defs>
  <pattern id="g" width="24" height="24" patternUnits="userSpaceOnUse"><path class="grid" d="M24 0H0V24" fill="none"/></pattern>
  <linearGradient id="l" x1="0" x2="1" y1="0" y2=".25"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".85"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
  <clipPath id="c"><rect width="${width}" height="${height}" rx="14"/></clipPath>
</defs>
<g clip-path="url(#c)">
<rect class="bg" width="${width}" height="${height}"/>
<rect width="${width}" height="${height}" fill="url(#g)"/>
<g transform="translate(${pad} ${pad})">
${groups}
</g>
<rect class="shine" x="0" y="0" width="${Math.round(width * 0.22)}" height="${height}" fill="url(#l)"/>
</g>
</svg>
`;
const out = join(DOCS, "assets", "readme-title.svg");
writeFileSync(out, svg);
console.log(`${out}: ${W}×${R} cells, ${(svg.length / 1024).toFixed(1)} KB`);
