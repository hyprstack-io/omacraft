// FIGlet rendering for omascii, backed by the vendored figlet.js — the engine
// and font collection behind patorjk.com's Text to ASCII Art Generator (TAAG).
//
//   node figlet.mjs fonts [--json]
//   node figlet.mjs render [--text T] [--font F] [--hlayout L] [--vlayout L] [--width N] [--whitespace-break]
//   node figlet.mjs gallery [--text T] [layout options] [--fonts a,b,c]   -> JSON [{font, art}]
//   node figlet.mjs taag <url>                                             -> JSON settings
//
// Layouts are figlet.js names ("default", "full", "fitted", "controlled
// smushing", "universal smushing") or their TAAG URL indices 0-4.

import { createRequire } from "node:module";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const FONT_DIR = join(ROOT, "vendor", "figlet", "fonts");
const figlet = require(join(ROOT, "vendor", "figlet", "dist", "node-figlet.cjs"));
figlet.defaults({ fontPath: FONT_DIR });
// More FIGlet (.flf) and toilet (.tlf) fonts the user downloaded or added
// (omascii fonts fetch / add). Bundled fonts win a name clash.
export const EXTRA_DIR = process.env.OMASCII_FLF_DIR
  || join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "omascii", "flf");

export const LAYOUTS = ["default", "full", "fitted", "controlled smushing", "universal smushing"];

export function layoutName(value) {
  if (value === undefined || value === null || value === "") return "default";
  const s = String(value).trim().toLowerCase();
  if (/^\d$/.test(s) && LAYOUTS[Number(s)]) return LAYOUTS[Number(s)];
  if (LAYOUTS.includes(s)) return s;
  throw new Error(`unknown layout "${value}" (use ${LAYOUTS.map((l, i) => `${i}=${l}`).join(", ")})`);
}

let fontCache = null;
let extraCache = null;

function bundledFonts() {
  return readdirSync(FONT_DIR).filter((f) => f.endsWith(".flf")).map((f) => f.slice(0, -4));
}

// name -> path of every extra font, searched recursively (collections keep
// fonts in subfolders). Toilet fonts only differ in their "tlf2a" header.
export function extraFonts() {
  if (extraCache) return extraCache;
  extraCache = new Map();
  if (!existsSync(EXTRA_DIR)) return extraCache;
  const bundled = new Set(bundledFonts().map((f) => f.toLowerCase()));
  const visit = (dir, depth) => {
    for (const f of readdirSync(dir).sort()) {
      const path = join(dir, f);
      let st;
      try {
        st = statSync(path);
      } catch {
        continue;
      }
      if (st.isDirectory()) {
        if (depth < 4 && !f.startsWith(".")) visit(path, depth + 1);
        continue;
      }
      const m = f.match(/^(.*)\.(flf|tlf)$/i);
      if (!m || bundled.has(m[1].toLowerCase()) || extraCache.has(m[1])) continue;
      extraCache.set(m[1], path);
    }
  };
  visit(EXTRA_DIR, 0);
  return extraCache;
}

export function listFonts() {
  return (fontCache ??= [...bundledFonts(), ...extraFonts().keys()]
    .sort((a, b) => a.localeCompare(b, "en", { sensitivity: "base" })));
}

export function isExtraFont(name) {
  return extraFonts().has(name);
}

function fontPath(name) {
  return extraFonts().get(name) || join(FONT_DIR, `${name}.flf`);
}

function fontHeight(name) {
  // FIGfont header: flf2a<hardblank> <height> <baseline> ...
  const header = readFileSync(fontPath(name), "latin1").split("\n", 1)[0];
  return Number(header.split(/\s+/)[1]) || 0;
}

const loaded = new Set();

// figlet.js only reads fonts from its fontPath; extra ones are parsed here
function loadExtra(name) {
  if (loaded.has(name) || !isExtraFont(name)) return;
  const data = readFileSync(extraFonts().get(name), "utf8").replace(/^tlf2a/, "flf2a");
  figlet.parseFont(name, data);
  loaded.add(name);
}

export function resolveFont(name) {
  const fonts = listFonts();
  if (fonts.includes(name)) return name;
  const folded = String(name).toLowerCase();
  const match = fonts.find((f) => f.toLowerCase() === folded);
  if (match) return match;
  throw new Error(`unknown font "${name}" (see: omascii fonts)`);
}

export function render(opts) {
  const width = Number(opts.width) || 0;
  const font = resolveFont(opts.font || "Standard");
  loadExtra(font);
  const art = figlet.textSync(opts.text ?? "", {
    font,
    horizontalLayout: layoutName(opts.hlayout),
    verticalLayout: layoutName(opts.vlayout),
    width: width > 0 ? width : undefined,
    whitespaceBreak: !!opts.whitespaceBreak,
  });
  // Trailing spaces and blank edge rows only shift the art off-centre
  const lines = art.replace(/ /g, " ").split("\n").map((l) => l.trimEnd());
  while (lines.length && !lines[0]) lines.shift();
  while (lines.length && !lines[lines.length - 1]) lines.pop();
  return lines.join("\n");
}

// TAAG share links keep their settings in the hash:
// #p=testall&f=Graffiti&t=HyprStack&x=none&v=4&h=4&w=80&we=false
export function parseTaag(url) {
  const hash = String(url).includes("#") ? String(url).split("#").slice(1).join("#") : String(url);
  const q = new URLSearchParams(hash);
  const out = {};
  if (q.has("f")) out.font = resolveFont(q.get("f"));
  if (q.has("t")) out.text = q.get("t");
  if (q.has("h")) out.hlayout = layoutName(q.get("h"));
  if (q.has("v")) out.vlayout = layoutName(q.get("v"));
  if (q.has("w")) out.width = q.get("w") === "none" ? 0 : Number(q.get("w")) || 0;
  if (q.has("we")) out.whitespaceBreak = q.get("we") === "true";
  return out;
}

function parseArgs(argv) {
  const opts = { _: [] };
  const flags = { "--whitespace-break": "whitespaceBreak", "--json": "json" };
  const values = { "--text": "text", "--font": "font", "-f": "font", "--hlayout": "hlayout",
    "--vlayout": "vlayout", "--width": "width", "-w": "width", "--fonts": "fonts" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (flags[a]) opts[flags[a]] = true;
    else if (values[a]) {
      if (i + 1 >= argv.length) throw new Error(`${a} needs a value`);
      opts[values[a]] = argv[++i];
    } else opts._.push(a);
  }
  return opts;
}

function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  const opts = parseArgs(rest);
  switch (cmd) {
    case "fonts": {
      const fonts = listFonts();
      if (opts.json) console.log(JSON.stringify(fonts.map((name) => ({ name, height: fontHeight(name), extra: isExtraFont(name) }))));
      else console.log(fonts.join("\n"));
      break;
    }
    case "render":
      console.log(render(opts));
      break;
    case "gallery": {
      const names = opts.fonts ? opts.fonts.split(",").map(resolveFont) : listFonts();
      const out = names.map((font) => {
        try {
          return { font, art: render({ ...opts, font }) };
        } catch (e) {
          return { font, art: "", error: e.message };
        }
      });
      console.log(JSON.stringify(out));
      break;
    }
    case "taag":
      console.log(JSON.stringify(parseTaag(opts._[0] || "")));
      break;
    default:
      throw new Error(`unknown command "${cmd ?? ""}" (fonts, render, gallery, taag)`);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    main();
  } catch (e) {
    console.error(`omascii: ${e.message}`);
    process.exit(1);
  }
}
