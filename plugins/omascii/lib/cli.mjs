// omascii command line. Keeps the chosen text/font/layout in
// ~/.config/omascii/config.json, renders it with figlet.js, a TheDraw font, a
// system font or from an image (image.py), styles it (style.mjs), and hands
// the art to build.py (Plymouth theme) and install.sh (privileged install).

import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { EXTRA_DIR, LAYOUTS, extraFonts, isExtraFont, layoutName, listFonts, parseTaag, render, resolveFont } from "./figlet.mjs";
import { BORDERS, COLOR_MODES, FLIPS, GRADIENTS, INK_BGS, PALETTES, PRESETS, SHADOWS, applyStyle, hasColor, loadPalette, resolveColor, stripColor, textToCells } from "./style.mjs";
import { TDF_DIR, cellsToAnsi, cellsToCodes, cellsToHtml, cellsToRows, cellsToText, isTdf, listTdfFonts, renderTdf, resolveTdf, tdfStats } from "./tdf.mjs";
import { TTF_DIR, isTtf, listTtfFonts, resolveTtf, ttfStats } from "./ttf.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const HOME = homedir();
const CONFIG_DIR = process.env.OMASCII_CONFIG_DIR
  || join(process.env.XDG_CONFIG_HOME || join(HOME, ".config"), "omascii");
const STATE_DIR = process.env.OMASCII_STATE_DIR
  || join(process.env.XDG_STATE_HOME || join(HOME, ".local", "state"), "omascii");
const CONFIG = join(CONFIG_DIR, "config.json");
// Boot screens the user saved by name, and the ones applied to boot
const SAVED = join(CONFIG_DIR, "saved.json");
const SAVED_LIMIT = 60;
const THEME_NAME = "omascii";
const THEME_BUILD = join(STATE_DIR, "theme", THEME_NAME);
const INSTALL_DIR = `/usr/share/plymouth/themes/${THEME_NAME}`;

// The first eleven are themed for Omarchy and the default set; the rest use
// ttfx's own effect colours (keep build.py's EFFECT_NAMES/EXTRA_EFFECTS in step)
const CORE_EFFECTS = ["decrypt", "beams", "burn", "slide", "rain", "laseretch",
  "waves", "middleout", "vhstape", "sweep", "unstable"];
const MORE_EFFECTS = ["expand", "pour", "print", "scattered", "slice", "spotlights",
  "wipe", "errorcorrect", "randomsequence", "swarm", "fireworks", "blackhole", "rings", "bubbles",
  "crumble", "binarypath", "overflow", "spray", "orbittingvolley", "smoke", "bouncyballs"];
// The rest of the ttfx effects Omarchy's screensaver plays, and variants of
// them tuned like screensaver scenes (build.py's SCREENSAVER_EFFECTS, PRESET_BASES)
const SCREENSAVER_EFFECTS = ["matrix", "synthgrid", "thunderstorm", "colorshift", "highlight"];
const PRESET_EFFECTS = ["matrix-theme", "matrix-binary", "synthgrid-neon", "thunderstorm-violet",
  "colorshift-rainbow", "fireworks-neon", "burn-inferno", "beams-aurora", "rain-storm", "decrypt-green"];
// omascii's own, drawn by lib/effects.py rather than ttfx
const NATIVE_EFFECTS = ["ripple", "starfield", "neon", "tetris", "spiral", "crt", "plasma", "tunein", "helix"];
export const EFFECTS = [...CORE_EFFECTS, ...MORE_EFFECTS, ...SCREENSAVER_EFFECTS, ...PRESET_EFFECTS, ...NATIVE_EFFECTS];
// For the designers, which list each effect is shown under
const EFFECT_GROUPS = [
  { id: "core", name: "Core", effects: CORE_EFFECTS },
  { id: "more", name: "More ttfx", effects: MORE_EFFECTS },
  { id: "screensaver", name: "Screensaver", effects: SCREENSAVER_EFFECTS },
  { id: "presets", name: "Screensaver presets", effects: PRESET_EFFECTS },
  { id: "omascii", name: "omascii originals", effects: NATIVE_EFFECTS },
];
const STYLES = ["animated", "static"];
const SOURCES = ["text", "image"];
// Pixel charsets for images and system fonts (image.py)
const CHARSETS = ["ascii", "detailed", "blocks", "braille", "quadrant", "halfblock", "custom"];

// Defaults mirror the TAAG link this plugin was made from:
// #p=testall&f=Graffiti&t=HyprStack&x=none&v=4&h=4&w=80&we=false
const DEFAULTS = {
  text: "HyprStack",
  font: "Graffiti",
  hlayout: "universal smushing",
  vlayout: "universal smushing",
  width: 80,
  whitespaceBreak: false,
  style: "animated",
  effects: CORE_EFFECTS,
  color: "accent",
  fontColors: true,   // TheDraw colour fonts keep their own colours
  maxFrames: 200,
  // System fonts (TTF ...) are drawn as pixels this many rows tall
  ttfRows: 8,
  ttfCharset: "quadrant",
  // Image source
  source: "text",
  image: "",
  imageWidth: 80,
  charset: "ascii",
  chars: "",          // custom ramp, darkest first
  imageColors: true,
  invert: false,
  dither: false,
  threshold: 50,
  contrast: 1,
  brightness: 1,
  normalize: true,
  // Styling, applied to any source
  fill: "",
  flip: "none",
  shadow: "none",
  border: "none",
  padding: 0,
  colorMode: "solid",
  color2: "blue",
  colorPalette: "sunset",
  gradient: "horizontal",
  inkBg: "none",
};

// The collection tdfiglet ships ("all known TDF fonts")
const TDF_SOURCE = "https://github.com/tat3r/tdfiglet";
// The largest FIGlet/toilet collection; those identical to TAAG's are skipped
const FLF_SOURCE = "https://github.com/xero/figlet-fonts";

function loadConfig() {
  try {
    return { ...DEFAULTS, ...JSON.parse(readFileSync(CONFIG, "utf8")) };
  } catch {
    return { ...DEFAULTS };
  }
}

function saveConfig(config) {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(CONFIG, JSON.stringify(config, null, 2) + "\n");
}

function clamp(v, lo, hi, fallback) {
  const n = Math.floor(Number(v));
  return Number.isFinite(n) ? Math.max(lo, Math.min(hi, n)) : fallback;
}

function validate(config) {
  const c = { ...config };
  c.text = String(c.text ?? "");
  if (!SOURCES.includes(c.source)) throw new Error(`source must be one of: ${SOURCES.join(", ")}`);
  if (c.source === "text" && !c.text.trim()) throw new Error("text is empty");
  c.font = isTdf(c.font) ? resolveTdf(c.font).id : isTtf(c.font) ? resolveTtf(c.font).id : resolveFont(c.font);
  c.image = String(c.image || "").replace(/^~(?=\/|$)/, HOME);
  if (c.source === "image" && !c.image) throw new Error("no image chosen (--image PATH)");
  c.imageWidth = clamp(c.imageWidth, 8, 400, DEFAULTS.imageWidth);
  c.ttfRows = clamp(c.ttfRows, 2, 60, DEFAULTS.ttfRows);
  c.threshold = clamp(c.threshold, 0, 100, DEFAULTS.threshold);
  c.padding = clamp(c.padding, 0, 20, 0);
  for (const k of ["contrast", "brightness"]) c[k] = Math.max(0, Math.min(5, Number(c[k]) || 0)) || 1;
  c.chars = String(c.chars || "");
  c.fill = [...String(c.fill || "")].slice(0, 16).join("");
  for (const k of ["imageColors", "invert", "dither", "normalize"]) c[k] = c[k] === true || c[k] === "true";
  const oneOf = (key, list) => {
    if (!list.includes(c[key])) throw new Error(`${key} must be one of: ${list.join(", ")}`);
  };
  oneOf("charset", CHARSETS);
  oneOf("ttfCharset", CHARSETS);
  oneOf("flip", FLIPS);
  oneOf("shadow", SHADOWS);
  oneOf("border", BORDERS);
  oneOf("colorMode", COLOR_MODES);
  oneOf("gradient", GRADIENTS);
  oneOf("inkBg", INK_BGS);
  if (!PALETTES[c.colorPalette]) c.colorPalette = DEFAULTS.colorPalette;
  if (c.source === "image" && c.charset === "custom" && !c.chars) throw new Error("custom charset needs --chars");
  if (!/^(#?[0-9a-fA-F]{6}|[a-z_]+)$/.test(String(c.color2))) throw new Error(`bad color2 "${c.color2}"`);
  c.fontColors = c.fontColors !== false;
  c.hlayout = layoutName(c.hlayout);
  c.vlayout = layoutName(c.vlayout);
  c.width = Math.max(0, Math.floor(Number(c.width) || 0));
  c.whitespaceBreak = !!c.whitespaceBreak;
  if (!STYLES.includes(c.style)) throw new Error(`style must be one of: ${STYLES.join(", ")}`);
  c.effects = (Array.isArray(c.effects) ? c.effects : String(c.effects).split(","))
    .map((e) => String(e).trim()).filter(Boolean);
  for (const e of c.effects) if (!EFFECTS.includes(e)) throw new Error(`unknown effect "${e}" (${EFFECTS.join(", ")})`);
  if (c.style === "animated" && c.effects.length === 0) throw new Error("animated style needs at least one effect");
  if (!/^(#?[0-9a-fA-F]{6}|[a-z_]+)$/.test(String(c.color))) throw new Error(`bad color "${c.color}" (palette name like accent, or #rrggbb)`);
  c.maxFrames = Math.max(10, Math.floor(Number(c.maxFrames) || DEFAULTS.maxFrames));
  return c;
}

const VALUE_FLAGS = {
  "--text": "text", "-t": "text", "--font": "font", "-f": "font",
  "--hlayout": "hlayout", "--vlayout": "vlayout", "--width": "width", "-w": "width",
  "--style": "style", "--effects": "effects", "--color": "color", "--max-frames": "maxFrames",
  "--source": "source", "--image": "image", "-i": "image", "--image-width": "imageWidth",
  "--charset": "charset", "--chars": "chars", "--threshold": "threshold",
  "--contrast": "contrast", "--brightness": "brightness",
  "--ttf-rows": "ttfRows", "--ttf-charset": "ttfCharset",
  "--fill": "fill", "--flip": "flip", "--shadow": "shadow", "--border": "border", "--padding": "padding",
  "--color-mode": "colorMode", "--color2": "color2", "--gradient": "gradient", "--palette": "colorPalette",
  "--ink-bg": "inkBg",
  "--taag": "taag", "--set": "set", "--offset": "offset", "--limit": "limit", "--filter": "filter",
  "--config-json": "configJson", "--name": "name",
};
// Flags that pick what a command does rather than boot art settings
const NOT_SETTINGS = ["taag", "set", "offset", "limit", "filter", "configJson", "name"];
// --flag / --no-flag pairs
const BOOL_FLAGS = {
  "whitespace-break": "whitespaceBreak", "font-colors": "fontColors", "image-colors": "imageColors",
  "invert": "invert", "dither": "dither", "normalize": "normalize",
};

function parseArgs(argv) {
  const opts = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const eq = a.startsWith("--") ? a.indexOf("=") : -1;
    const flag = eq > 0 ? a.slice(0, eq) : a;
    if (VALUE_FLAGS[flag]) {
      if (eq > 0) opts[VALUE_FLAGS[flag]] = a.slice(eq + 1);
      else if (i + 1 < argv.length) opts[VALUE_FLAGS[flag]] = argv[++i];
      else throw new Error(`${flag} needs a value`);
    } else if (a.startsWith("--") && BOOL_FLAGS[a.slice(2)]) opts[BOOL_FLAGS[a.slice(2)]] = true;
    else if (a.startsWith("--no-") && BOOL_FLAGS[a.slice(5)]) opts[BOOL_FLAGS[a.slice(5)]] = false;
    else if (a === "--json") opts.json = true;
    else if (a === "--tdf") opts.tdf = true;
    else if (a === "--ttf") opts.ttf = true;
    else if (a === "--yes" || a === "-y") opts.yes = true;
    else if (a.startsWith("-") && a !== "-") throw new Error(`unknown option ${a}`);
    else opts._.push(a);
  }
  return opts;
}

// Config overridden by command-line options (a TAAG link first, then flags)
function withOverrides(config, opts) {
  const next = { ...config };
  // The shell sends its whole draft as JSON; only known settings are taken
  if (opts.configJson) {
    const draft = JSON.parse(opts.configJson);
    for (const key of Object.keys(DEFAULTS)) if (draft[key] !== undefined) next[key] = draft[key];
  }
  if (opts.taag) Object.assign(next, parseTaag(opts.taag), { source: "text" });
  for (const key of Object.values(VALUE_FLAGS)) {
    if (!NOT_SETTINGS.includes(key) && opts[key] !== undefined) next[key] = opts[key];
  }
  for (const key of Object.values(BOOL_FLAGS)) if (opts[key] !== undefined) next[key] = opts[key];
  // --image alone switches to the image source, --font alone back to text
  if (opts.source === undefined) {
    if (opts.image !== undefined) next.source = "image";
    else if (opts.font !== undefined || opts.text !== undefined) next.source = "text";
  }
  // Typed "\n" starts a new line, as in TAAG
  next.text = String(next.text).replace(/\\n/g, "\n");
  return validate(next);
}

function run(cmd, args, options = {}) {
  const r = spawnSync(cmd, args, { stdio: "inherit", ...options });
  if (r.error) throw new Error(`${cmd}: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`${cmd} exited with status ${r.status}`);
}

// image.py: an image or system-font text as [ch, fg, bg] rows
function pixelCells(args) {
  const r = spawnSync("python3", [join(ROOT, "lib", "image.py"), ...args],
    { encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (r.error) throw new Error(`python3: ${r.error.message}`);
  if (r.status !== 0) throw new Error((r.stderr || "image.py failed").trim().replace(/^.*?: error: /s, ""));
  return JSON.parse(r.stdout).map((row) => row.map(([ch, fg, bg]) => ({ ch, fg, bg })));
}

function pixelArgs(config, charset) {
  const args = ["--charset", charset, "--threshold", String(config.threshold)];
  if (charset === "custom") args.push("--chars", config.chars);
  if (config.dither) args.push("--dither");
  return args;
}

// Cells straight from the source, and whether their colours are their own
function sourceCells(config) {
  if (config.source === "image") {
    const args = ["image", config.image, "--width", String(config.imageWidth), ...pixelArgs(config, config.charset),
      "--contrast", String(config.contrast), "--brightness", String(config.brightness)];
    if (config.invert) args.push("--invert");
    if (config.normalize) args.push("--normalize");
    if (config.imageColors) args.push("--colors");
    return { cells: pixelCells(args), own: config.imageColors };
  }
  if (isTdf(config.font)) {
    const own = resolveTdf(config.font).type === "color" && config.fontColors;
    return { cells: renderTdf(config.font, config.text), own };
  }
  if (isTtf(config.font)) {
    const f = resolveTtf(config.font);
    return {
      cells: pixelCells(["text", "--text", config.text, "--font-file", f.file, "--font-index", String(f.index),
        "--rows", String(config.ttfRows), ...pixelArgs(config, config.ttfCharset)]),
      own: false,
    };
  }
  return { cells: textToCells(render(config)), own: false };
}

// The art for a config: plain text, plus coloured cells when anything
// carries a colour (TheDraw colour fonts, image colours, gradients, shadows)
function art(config) {
  const src = sourceCells(config);
  const cells = applyStyle(src.own ? src.cells : stripColor(src.cells), config);
  if (!cells.length) throw new Error("nothing to draw — try other text, font or settings");
  return { text: cellsToText(cells), cells: hasColor(cells) ? cells : null };
}

// For the terminal: colours when there are any and stdout is a terminal
function printable(config) {
  const a = art(config);
  return a.cells && process.stdout.isTTY ? cellsToAnsi(a.cells) : a.text;
}

// One page of the TheDraw gallery: { total, offset, items }. There are
// thousands of these fonts, so the UI asks for pages as it scrolls.
function tdfGallery(config, { offset = 0, limit = 0, filter = "" } = {}) {
  const q = String(filter).toLowerCase();
  const fonts = listTdfFonts().filter((f) => !q || f.id.toLowerCase().includes(q) || f.name.toLowerCase().includes(q));
  const start = Math.max(0, Number(offset) || 0);
  const page = fonts.slice(start, Number(limit) > 0 ? start + Number(limit) : undefined);
  const items = page.map((f) => {
    try {
      const cells = renderTdf(f.id, config.text);
      // Full-width rows plus run-length colours; the UI turns them into rich
      // text only for the rows on screen (HTML for all fonts is ~70 MB)
      return {
        font: f.id, name: f.name, type: f.type, art: cellsToRows(cells),
        codes: f.type === "color" ? cellsToCodes(cells) : "", cols: cells[0]?.length || 0, rows: cells.length,
      };
    } catch (e) {
      return { font: f.id, name: f.name, type: f.type, art: "", codes: "", error: e.message };
    }
  });
  return { total: fonts.length, offset: start, items, names: start === 0 ? fonts.map((f) => f.id) : undefined };
}

// One page of system fonts drawn as pixels: same shape as tdfGallery
function ttfGallery(config, { offset = 0, limit = 0, filter = "" } = {}) {
  const q = String(filter).toLowerCase();
  const fonts = listTtfFonts().filter((f) => !q || f.id.toLowerCase().includes(q));
  const start = Math.max(0, Number(offset) || 0);
  const page = fonts.slice(start, Number(limit) > 0 ? start + Number(limit) : undefined);
  if (!page.length) return { total: fonts.length, offset: start, items: [], names: start === 0 ? fonts.map((f) => f.id) : undefined };
  const r = spawnSync("python3", [join(ROOT, "lib", "image.py"), "gallery", "--text", config.text,
    "--rows", String(config.ttfRows), ...pixelArgs(config, config.ttfCharset)],
  { input: JSON.stringify(page.map((f) => ({ id: f.id, file: f.file, index: f.index }))),
    encoding: "utf8", maxBuffer: 256 * 1024 * 1024 });
  if (r.status !== 0) throw new Error((r.stderr || "image.py failed").trim());
  const items = JSON.parse(r.stdout).map((g, i) => ({
    ...g, name: page[i].source === "user" ? "added" : "", type: page[i].style,
  }));
  return { total: fonts.length, offset: start, items, names: start === 0 ? fonts.map((f) => f.id) : undefined };
}

// Image files to offer in the shell: newest first from the usual places
function listImages(limit = 400) {
  const dirs = [join(HOME, "Pictures"), join(HOME, "Downloads"), join(HOME, "Desktop"),
    join(HOME, ".config", "omarchy", "backgrounds"),
    join(HOME, ".local", "state", "omarchy", "current", "theme", "backgrounds"),
    join(HOME, ".config", "omarchy", "current", "theme", "backgrounds")];
  const found = new Map();
  const visit = (dir, depth) => {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      if (e.name.startsWith(".")) continue;
      const path = join(dir, e.name);
      if (e.isDirectory() && depth < 3) visit(path, depth + 1);
      else if (/\.(png|jpe?g|gif|webp|bmp|tiff?|ico)$/i.test(e.name)) {
        try {
          const st = statSync(path);
          if (st.isFile()) found.set(path, st.mtimeMs);
        } catch {}
      }
    }
  };
  for (const d of dirs) visit(d, 0);
  return [...found].sort((a, b) => b[1] - a[1]).slice(0, limit)
    .map(([path, mtime]) => ({ path, name: basename(path), dir: dirname(path).replace(HOME, "~"), mtime }));
}

const sha1 = (data) => createHash("sha1").update(data.toString("latin1").replace(/\r\n/g, "\n")).digest("hex");

// .flf/.tlf into EXTRA_DIR, skipping ones TAAG's set (or EXTRA_DIR) already
// has; .ttf/.otf into TTF_DIR; .tdf and zips to the TheDraw handler
function copyFontFiles(paths) {
  mkdirSync(EXTRA_DIR, { recursive: true });
  const known = new Set();
  const bundledDir = join(ROOT, "vendor", "figlet", "fonts");
  const bundledNames = new Set();
  for (const f of readdirSync(bundledDir)) {
    known.add(sha1(readFileSync(join(bundledDir, f))));
    bundledNames.add(f.replace(/\.flf$/i, "").toLowerCase());
  }
  for (const p of extraFonts().values()) known.add(sha1(readFileSync(p)));
  const counts = { figlet: 0, ttf: 0, tdf: 0, same: 0 };
  const visit = (path) => {
    const st = statSync(path);
    if (st.isDirectory()) {
      for (const f of readdirSync(path)) if (!f.startsWith(".")) visit(join(path, f));
    } else if (/\.(flf|tlf)$/i.test(path)) {
      const data = readFileSync(path);
      const hash = sha1(data);
      // A bundled font of the same name would hide it anyway
      if (known.has(hash) || bundledNames.has(basename(path).replace(/\.(flf|tlf)$/i, "").toLowerCase())) counts.same++;
      else {
        known.add(hash);
        writeFileSync(join(EXTRA_DIR, basename(path)), data);
        counts.figlet++;
      }
    } else if (/\.(ttf|otf|ttc|otc)$/i.test(path)) {
      mkdirSync(TTF_DIR, { recursive: true });
      copyFileSync(path, join(TTF_DIR, basename(path)));
      counts.ttf++;
    } else if (/\.(tdf|zip)$/i.test(path)) {
      copyTdfFiles([path]);
      counts.tdf++;
    }
  };
  for (const p of paths) visit(p);
  return counts;
}

function fontsCommand(sub, args, opts) {
  switch (sub) {
    case "fetch": {
      const tmp = mkdtempSync(join(tmpdir(), "omascii-flf-"));
      let counts;
      try {
        run("git", ["clone", "--depth", "1", "--quiet", args[0] || FLF_SOURCE, tmp]);
        rmSync(join(tmp, ".git"), { recursive: true, force: true });
        counts = copyFontFiles([tmp]);
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
      console.log(`${counts.figlet} new FIGlet/toilet fonts in ${EXTRA_DIR} (${counts.same} already in the TAAG set)`);
      break;
    }
    case "add": {
      if (!args.length) throw new Error("usage: omascii fonts add <font files, folders or zips> ...");
      const c = copyFontFiles(args);
      console.log(`added ${c.figlet} FIGlet, ${c.ttf} TrueType/OpenType and ${c.tdf} TheDraw files`
        + (c.same ? ` (${c.same} FIGlet fonts were already there)` : ""));
      break;
    }
    case "dir":
      console.log(`figlet ${EXTRA_DIR}\nttf    ${TTF_DIR}\ntdf    ${TDF_DIR}`);
      break;
    default:
      if (opts.tdf) {
        const fonts = listTdfFonts().map((f) => ({ name: f.id, type: f.type, title: f.name }));
        console.log(opts.json ? JSON.stringify(fonts) : fonts.map((f) => f.name).join("\n"));
      } else if (opts.ttf) {
        const fonts = listTtfFonts().map((f) => ({ name: f.id, file: f.file, source: f.source }));
        console.log(opts.json ? JSON.stringify(fonts) : fonts.map((f) => f.name).join("\n"));
      } else {
        run(process.execPath, [join(ROOT, "lib", "figlet.mjs"), "fonts", ...(opts.json ? ["--json"] : [])]);
      }
  }
}

function copyTdfFiles(paths) {
  mkdirSync(TDF_DIR, { recursive: true });
  let added = 0;
  const visit = (path) => {
    const st = statSync(path);
    if (st.isDirectory()) {
      for (const f of readdirSync(path)) visit(join(path, f));
    } else if (/\.tdf$/i.test(path)) {
      copyFileSync(path, join(TDF_DIR, basename(path)));
      added++;
    } else if (/\.zip$/i.test(path)) {
      run("unzip", ["-q", "-j", "-o", "-C", path, "*.tdf", "-d", TDF_DIR], { stdio: ["ignore", "inherit", "ignore"] });
      added = -1;
    }
  };
  for (const p of paths) visit(p);
  return added;
}

function tdfCommand(sub, args) {
  switch (sub) {
    case "fetch": {
      // Shallow clone of tdfiglet, keeping only its fonts/ folder
      const tmp = mkdtempSync(join(tmpdir(), "omascii-tdf-"));
      try {
        run("git", ["clone", "--depth", "1", "--quiet", args[0] || TDF_SOURCE, tmp]);
        const fonts = join(tmp, "fonts");
        if (!existsSync(fonts)) throw new Error(`no fonts/ folder in ${args[0] || TDF_SOURCE}`);
        copyTdfFiles([fonts]);
      } finally {
        rmSync(tmp, { recursive: true, force: true });
      }
      const s = tdfStats();
      console.log(`${s.files} TheDraw font files in ${s.dir}: ${s.color} colour and ${s.block} block fonts usable`);
      break;
    }
    case "add": {
      if (!args.length) throw new Error("usage: omascii tdf add <file.tdf|folder|fonts.zip> ...");
      copyTdfFiles(args);
      const s = tdfStats();
      console.log(`${s.files} TheDraw font files in ${s.dir}: ${s.color} colour and ${s.block} block fonts usable`);
      break;
    }
    case "list":
      for (const f of listTdfFonts()) console.log(`${f.id.padEnd(28)} ${f.type.padEnd(6)} ${f.name}`);
      break;
    case "dir":
      console.log(TDF_DIR);
      break;
    default:
      throw new Error("usage: omascii tdf fetch [git-url] | add <paths> | list | dir");
  }
}

function currentPlymouthTheme() {
  try {
    const conf = readFileSync("/etc/plymouth/plymouthd.conf", "utf8");
    return (conf.match(/^\s*Theme\s*=\s*(\S+)/m) || [])[1] || "";
  } catch {
    return "";
  }
}

// Write the art for build.py into dir; returns its common arguments
function buildInput(config, dir, stem) {
  mkdirSync(dir, { recursive: true });
  const logo = join(dir, `${stem}.txt`);
  const cellsFile = join(dir, `${stem}.cells.json`);
  const a = art(config);
  writeFileSync(logo, a.text + "\n");
  const args = [join(ROOT, "lib", "build.py"), "--logo", logo, "--color", String(config.color),
    "--max-frames", String(config.maxFrames)];
  if (a.cells) {
    writeFileSync(cellsFile, JSON.stringify(a.cells.map((r) => r.map((c) => [c.ch, c.fg, c.bg]))));
    args.push("--cells", cellsFile);
  } else {
    rmSync(cellsFile, { force: true });
  }
  return args;
}

function build(config) {
  const args = [...buildInput(config, STATE_DIR, "logo"), "--out", THEME_BUILD,
    "--name", THEME_NAME, "--install-dir", INSTALL_DIR, "--style", config.style];
  if (config.style === "animated") args.push("--effects", config.effects.join(","));
  run("python3", args);
  writeFileSync(join(STATE_DIR, "built.json"), JSON.stringify(config, null, 2) + "\n");
}

// One intro's frames as rich text JSON, for the shell's live preview
function frames(config, effect) {
  const dir = mkdtempSync(join(tmpdir(), "omascii-frames-"));
  try {
    const args = [...buildInput({ ...config, maxFrames: Math.min(config.maxFrames, 120) }, dir, "logo"),
      "--out", join(dir, "unused"), "--preview-json", effect];
    const r = spawnSync("python3", args, { stdio: ["ignore", "pipe", "pipe"], maxBuffer: 512 * 1024 * 1024 });
    if (r.error) throw new Error(`python3: ${r.error.message}`);
    if (r.status !== 0) throw new Error(String(r.stderr).trim().split("\n").pop() || "build.py failed");
    process.stdout.write(r.stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function status() {
  const config = loadConfig();
  let text = "";
  let error = "";
  try {
    text = art(validate(config)).text;
  } catch (e) {
    error = e.message;
  }
  return {
    config,
    art: text,
    error,
    layouts: LAYOUTS,
    styles: STYLES,
    effects: EFFECTS,
    coreEffects: CORE_EFFECTS,
    effectGroups: EFFECT_GROUPS,
    palettes: Object.keys(PALETTES),
    paletteStops: PALETTES,
    charsets: CHARSETS,
    flips: FLIPS,
    shadows: SHADOWS,
    borders: BORDERS,
    colorModes: COLOR_MODES,
    gradients: GRADIENTS,
    inkBgs: INK_BGS,
    presets: PRESETS,
    fontCount: listFonts().length,
    extraFontCount: extraFonts().size,
    tdf: tdfStats(),
    ttf: ttfStats(),
    plymouthTheme: currentPlymouthTheme(),
    installed: existsSync(INSTALL_DIR),
    applied: readJson(join(STATE_DIR, "applied.json")),
    configPath: CONFIG,
    savedCount: loadSaved().length,
    palette: loadPalette(),
  };
}

// ---------------------------------------------------------------- saved

function sameConfig(a, b) {
  const keys = Object.keys(DEFAULTS);
  return keys.every((k) => JSON.stringify(a[k]) === JSON.stringify(b[k]));
}

function settingsOnly(config) {
  const out = {};
  for (const key of Object.keys(DEFAULTS)) if (config[key] !== undefined) out[key] = config[key];
  return out;
}

function describe(config) {
  return config.source === "image" ? basename(String(config.image || "image")) : `${config.font} · ${String(config.text).split("\n")[0]}`;
}

// The library starts with the last built theme, if there is one, so earlier
// work is not lost
function loadSaved() {
  const list = readJson(SAVED);
  if (Array.isArray(list)) return list;
  const built = readJson(join(STATE_DIR, "built.json"));
  if (!built) return [];
  const at = (() => { try { return statSync(join(STATE_DIR, "built.json")).mtime.toISOString(); } catch { return new Date().toISOString(); } })();
  return [{ id: "built", name: "Last built: " + describe(built), kind: "applied", at, config: settingsOnly(built) }];
}

function writeSaved(list) {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(SAVED, JSON.stringify(list.slice(0, SAVED_LIMIT), null, 2) + "\n");
}

// kind "saved" (named by the user) or "applied" (recorded on apply). A same
// named save, or an identical applied one, is replaced and moves to the top.
function addSaved(config, { name = "", kind = "saved" } = {}) {
  const list = loadSaved();
  const entry = {
    id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
    name: String(name).trim() || describe(config),
    kind,
    at: new Date().toISOString(),
    config: settingsOnly(config),
  };
  const rest = list.filter((e) => kind === "saved"
    ? !(e.kind === "saved" && e.name === entry.name)
    : !(e.kind === "applied" && sameConfig(e.config, config)));
  // An applied entry keeps the name of a matching saved one
  if (kind === "applied") {
    const named = rest.find((e) => e.kind === "saved" && sameConfig(e.config, config));
    if (named) entry.name = named.name;
  }
  writeSaved([entry, ...rest]);
  return entry;
}

function findSaved(id) {
  const entry = loadSaved().find((e) => e.id === id || e.name === id);
  if (!entry) throw new Error(`no saved boot screen "${id}" — see: omascii saved`);
  return entry;
}

function savedCommand(sub, args, opts) {
  switch (sub || "list") {
    case "list": {
      const list = loadSaved();
      if (!opts.json) {
        for (const e of list) console.log(`${e.id.padEnd(12)} ${e.kind.padEnd(8)} ${e.at.slice(0, 16).replace("T", " ")}  ${e.name}`);
        break;
      }
      // With the art, for the shell's library view
      console.log(JSON.stringify(list.map((e) => {
        const config = { ...DEFAULTS, ...e.config };
        try {
          const a = art(validate(config));
          const lines = a.text.split("\n");
          return { ...e, text: a.text, html: a.cells ? cellsToHtml(a.cells) : "",
                   cols: a.cells ? a.cells[0].length : Math.max(1, ...lines.map((l) => [...l].length)), rows: lines.length,
                   foreground: "#" + resolveColor(config.color), error: "" };
        } catch (err) {
          return { ...e, text: "", html: "", cols: 1, rows: 1, foreground: "", error: err.message };
        }
      })));
      break;
    }
    case "add": {
      const config = withOverrides(loadConfig(), opts);
      saveConfig(config);
      const entry = addSaved(config, { name: opts.name || args.join(" ") });
      console.log(`Saved "${entry.name}"`);
      break;
    }
    case "use": {
      const entry = findSaved(args[0]);
      saveConfig(validate({ ...DEFAULTS, ...entry.config }));
      console.log(`Loaded "${entry.name}"`);
      break;
    }
    case "rename": {
      const list = loadSaved();
      const entry = list.find((e) => e.id === args[0]);
      if (!entry) throw new Error(`no saved boot screen "${args[0]}"`);
      entry.name = String(opts.name || args.slice(1).join(" ")).trim() || entry.name;
      entry.kind = "saved";
      writeSaved(list);
      break;
    }
    case "rm": case "remove": case "delete": {
      const list = loadSaved();
      const next = list.filter((e) => e.id !== args[0]);
      if (next.length === list.length) throw new Error(`no saved boot screen "${args[0]}"`);
      writeSaved(next);
      break;
    }
    default:
      throw new Error(`unknown saved command "${sub}" — use list, add, use, rename or rm`);
  }
}

const HELP = `omascii — ASCII art (every TAAG font, TheDraw, system fonts or an
image) for the Plymouth boot screen

Usage: omascii <command> [options]

Commands:
  open                      Open the font browser in the Omarchy shell
  fonts [--tdf|--ttf] [--json]  List the FIGlet fonts (${listFonts().length}), TheDraw or system fonts
  fonts fetch [git-url]     Download more FIGlet/toilet fonts (${FLF_SOURCE.replace("https://", "")}),
                            keeping those not already in the TAAG set
  fonts add <paths>         Add .flf/.tlf, .ttf/.otf or .tdf files, folders or zips
  fonts dir                 Where added fonts live
  render [options] [--json] Print the art for the saved settings (+ options);
                            --json gives {text, html, cols, rows} for the UI
  set [options]             Save options as the boot art settings and print it
  show                      Print the saved settings and their art
  status --json             Settings, art and install state (for the shell UI)
  gallery [--set S]         Render the text in every font (JSON, for the UI). S is
                            figlet, tdf or ttf; tdf/ttf pages take --offset/--limit/--filter
  images [--json]           Images found in ~/Pictures, ~/Downloads and backgrounds
  frames [effect] --json    One intro's frames as rich text (the shell's live preview)
  tdf fetch [git-url]       Download the TheDraw font collection (${TDF_SOURCE.replace("https://", "")})
  tdf add <paths>           Add .tdf files, folders of them, or a .zip
  tdf list                  List installed TheDraw fonts ("TDF <name>")
  build                     Build the Plymouth theme into ${THEME_BUILD.replace(HOME, "~")}
  preview [effect|hold]     Build, then render GIF previews of the boot animation
  apply [--yes]             Build, install and select the theme (uses sudo,
                            rebuilds the initramfs)
  restore                   Switch back to the boot theme used before omascii
  saved [--json]            Saved and previously applied boot screens
  saved add --name NAME     Save the settings (+ options) as a named boot screen
  saved use ID              Load a saved boot screen into the settings
  saved rename ID NAME      Rename one (and keep it as saved)
  saved rm ID               Delete one

Text:
  -t, --text TEXT           Text to render ("\\n" for a new line)
  -f, --font NAME           FIGlet font (case-insensitive), e.g. "ANSI Shadow",
                            a TheDraw font, "TDF <name>", or a system font,
                            "TTF <family> <style>", drawn as pixels
      --hlayout L           Horizontal layout: ${LAYOUTS.map((l, i) => `${i}=${l}`).join(", ")}
      --vlayout L           Vertical layout (same values)
  -w, --width N             Wrap width in columns, 0 for none (TAAG default 80)
      --[no-]whitespace-break  Break on spaces when wrapping
      --taag URL            Take font, text, layouts and width from a TAAG link
      --ttf-rows N          Height of system-font text in rows (default 8)
      --ttf-charset C       How system fonts are drawn (default quadrant)

Image (switches the source to the image):
  -i, --image PATH          Image to convert (png, jpg, gif, webp, ...)
      --source S            text or image
      --image-width N       Columns (default 80)
      --charset C           ${CHARSETS.join(", ")}
      --chars STR           Custom ramp, darkest first (with --charset custom)
      --[no-]image-colors   Keep the image's colours (default on)
      --[no-]invert         Dense characters for dark pixels
      --[no-]dither         Floyd-Steinberg dithering (braille, quadrant, halfblock)
      --threshold N         0-100 brightness cut for dot charsets (default 50)
      --contrast X, --brightness X   Adjust before converting (1 = unchanged)
      --[no-]normalize      Stretch the levels first (default on)

Style (any source):
      --fill STR            Replace the ink with these characters, e.g. "█" or "01"
      --flip F              ${FLIPS.join(", ")}
      --shadow S            ${SHADOWS.join(", ")}
      --border B            ${BORDERS.join(", ")}
      --padding N           Space inside the border (rows; columns are doubled)
      --color C             Art colour: palette name (accent, blue, ...) or #rrggbb
      --color-mode M        ${COLOR_MODES.join(", ")} (rainbow: theme colours;
                            stripes/split: --color and --color2 by row/half)
      --color2 C            Gradient end colour
      --palette P           For --color-mode palette: ${Object.keys(PALETTES).join(", ")}
      --gradient D          ${GRADIENTS.join(", ")}
      --ink-bg B            ${INK_BGS.join(", ")} (shade: a dark copy of the ink colour
                            behind each cell, as TheDraw fonts do)
      --[no-]font-colors    Keep a TheDraw colour font's own colours (default on)

Boot:
      --style S             animated (ttfx effects) or static
      --effects a,b,...     Intro effects (default: ${CORE_EFFECTS.join(", ")}):
${EFFECT_GROUPS.map((g) => `                            ${g.name}: ${g.effects.join(", ")}`).join("\n")}
      --max-frames N        Frame cap per intro effect (50 per second)
`;

function main() {
  const [cmd = "help", ...rest] = process.argv.slice(2);
  const opts = parseArgs(rest);
  switch (cmd) {
    case "help": case "--help": case "-h":
      process.stdout.write(HELP);
      break;
    case "fonts":
      fontsCommand(opts._[0], opts._.slice(1), opts);
      break;
    case "tdf":
      tdfCommand(opts._[0], opts._.slice(1));
      break;
    case "render": {
      const config = withOverrides(loadConfig(), opts);
      if (!opts.json) {
        console.log(printable(config));
        break;
      }
      const a = art(config);
      const lines = a.text.split("\n");
      console.log(JSON.stringify({
        text: a.text,
        html: a.cells ? cellsToHtml(a.cells) : "",
        cols: a.cells ? a.cells[0].length : Math.max(1, ...lines.map((l) => [...l].length)),
        rows: lines.length,
        font: config.font,
        source: config.source,
        // The boot screen's colours, so the preview matches it
        foreground: "#" + resolveColor(config.color),
        background: "#" + loadPalette().background,
      }));
      break;
    }
    case "set": {
      const config = withOverrides(loadConfig(), opts);
      saveConfig(config);
      console.log(printable(config));
      break;
    }
    case "show": {
      const config = validate(loadConfig());
      for (const [k, v] of Object.entries(config)) console.log(`${k.padEnd(16)} ${Array.isArray(v) ? v.join(",") : JSON.stringify(v)}`);
      console.log("\n" + printable(config));
      break;
    }
    case "status":
      console.log(JSON.stringify(status(), null, opts.json ? 0 : 2));
      break;
    case "gallery": {
      // The gallery only needs the text settings: don't fail on the rest
      // (e.g. an image source with no image yet)
      const config = { ...loadConfig(), source: "text" };
      const next = withOverrides(config, { ...opts, source: "text", text: opts.text ?? (config.text || "omascii") });
      if (opts.set === "tdf") {
        console.log(JSON.stringify(tdfGallery(next, opts)));
        break;
      }
      if (opts.set === "ttf") {
        console.log(JSON.stringify(ttfGallery(next, opts)));
        break;
      }
      const args = [join(ROOT, "lib", "figlet.mjs"), "gallery", "--text", next.text,
        "--hlayout", next.hlayout, "--vlayout", next.vlayout, "--width", String(next.width)];
      if (next.whitespaceBreak) args.push("--whitespace-break");
      run(process.execPath, args);
      break;
    }
    case "images": {
      const list = listImages();
      console.log(opts.json ? JSON.stringify(list) : list.map((i) => i.path).join("\n"));
      break;
    }
    case "frames":
      frames(withOverrides(loadConfig(), opts), opts._[0] || "static");
      break;
    case "build":
      build(withOverrides(loadConfig(), opts));
      break;
    case "preview": {
      build(withOverrides(loadConfig(), opts));
      const out = join(STATE_DIR, "preview");
      run("bash", [join(ROOT, "lib", "preview.sh"), THEME_BUILD, out, ...opts._]);
      break;
    }
    case "apply": {
      const config = withOverrides(loadConfig(), opts);
      saveConfig(config);
      console.log(printable(config) + "\n");
      build(config);
      const previous = currentPlymouthTheme();
      if (previous && previous !== THEME_NAME) writeFileSync(join(STATE_DIR, "previous-theme"), previous + "\n");
      run("bash", [join(ROOT, "lib", "install.sh"), "install", THEME_BUILD, THEME_NAME, ...(opts.yes ? ["--yes"] : [])]);
      writeFileSync(join(STATE_DIR, "applied.json"), JSON.stringify({ ...config, at: new Date().toISOString() }, null, 2) + "\n");
      addSaved(config, { kind: "applied", name: opts.name });
      break;
    }
    case "restore": {
      let previous = "";
      try {
        previous = readFileSync(join(STATE_DIR, "previous-theme"), "utf8").trim();
      } catch {}
      if (!previous) throw new Error("no earlier boot theme recorded — use: omarchy plymouth reset");
      run("bash", [join(ROOT, "lib", "install.sh"), "select", previous, ...(opts.yes ? ["--yes"] : [])]);
      break;
    }
    case "saved":
      savedCommand(opts._[0], opts._.slice(1), opts);
      break;
    case "open":
      run("omarchy-shell", ["shell", "toggle", "omacraft.omascii", "{}"]);
      break;
    default:
      throw new Error(`unknown command "${cmd}" — see: omascii help`);
  }
}

try {
  main();
} catch (e) {
  console.error(`omascii: ${e.message}`);
  process.exit(1);
}
