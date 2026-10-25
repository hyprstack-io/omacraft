// TheDraw (.tdf) fonts for omascii: the colour/block ANSI fonts from the DOS
// art program TheDraw, as shown by TAAG and tdfiglet.
//
// File layout (offsets as in tdfiglet): "\x13TheDraw FONTS file\x1a" (20
// bytes), then one or more font records:
//   +0  55 AA 00 FF marker        +4  name length    +5  name (12 bytes)
//   +17 reserved (4)              +21 type: 0 outline, 1 block, 2 colour
//   +22 letter spacing            +23 data size (u16 LE)
//   +25 94 u16 LE glyph offsets for '!'..'~' (0xFFFF = missing)
//   +213 glyph data
// A glyph is width, height, then cells until NUL: CR (or LF) ends a row,
// other bytes are CP437 characters, each followed by a DOS attribute byte
// in colour fonts (low nibble foreground, bits 4-6 background, bit 7 blink).
// Outline fonts are left out: their A-Q codes need TheDraw's outline styles.

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";

const MAGIC = "\x13TheDraw FONTS file\x1a";
const TYPES = ["outline", "block", "color"];

export const TDF_PREFIX = "TDF ";
export const TDF_DIR = process.env.OMASCII_TDF_DIR
  || join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "omascii", "tdf");

// CP437 0x80-0xFF; bytes below 0x20 are drawn as spaces, as tdfiglet does
const CP437_HIGH = "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ";

function cp437(byte) {
  if (byte < 0x20) return " ";
  if (byte < 0x80) return String.fromCharCode(byte);
  return CP437_HIGH[byte - 0x80];
}

// DOS/VGA text palette, attribute order
export const DOS_COLORS = ["000000", "0000aa", "00aa00", "00aaaa", "aa0000", "aa00aa", "aa5500", "aaaaaa",
  "555555", "5555ff", "55ff55", "55ffff", "ff5555", "ff55ff", "ffff55", "ffffff"];

function parseFile(path) {
  const buf = readFileSync(path);
  if (buf.length < 20 || buf.toString("latin1", 0, 20) !== MAGIC) return [];
  const fonts = [];
  let pos = 20;
  while (pos + 213 <= buf.length && buf[pos] === 0x55 && buf[pos + 1] === 0xaa
         && buf[pos + 2] === 0x00 && buf[pos + 3] === 0xff) {
    const nameLen = Math.min(buf[pos + 4], 12);
    const size = buf.readUInt16LE(pos + 23);
    const offsets = [];
    for (let i = 0; i < 94; i++) offsets.push(buf.readUInt16LE(pos + 25 + i * 2));
    fonts.push({
      name: buf.toString("latin1", pos + 5, pos + 5 + nameLen).replace(/\0.*$/, "").trim(),
      type: TYPES[buf[pos + 21]] || "unknown",
      spacing: buf[pos + 22],
      offsets,
      data: buf.subarray(pos + 213, Math.min(buf.length, pos + 213 + size)),
    });
    pos += 213 + size;
  }
  return fonts;
}

function decodeGlyph(font, code) {
  const index = code - 33;
  if (index < 0 || index >= 94 || font.offsets[index] === 0xffff) return null;
  const data = font.data;
  let p = font.offsets[index];
  if (p + 2 > data.length) return null;
  const width = data[p];
  const height = data[p + 1];
  p += 2;
  const cells = Array.from({ length: height }, () =>
    Array.from({ length: width }, () => ({ ch: " ", fg: null, bg: null })));
  let row = 0;
  let col = 0;
  const colored = font.type === "color";
  while (p < data.length && data[p] !== 0) {
    const ch = data[p++];
    if (ch === 0x0d || ch === 0x0a) {
      row++;
      col = 0;
      continue;
    }
    let attr = null;
    if (colored && p < data.length) attr = data[p++];
    if (row < height && col < width) {
      const cell = cells[row][col];
      cell.ch = cp437(ch);
      if (attr !== null) {
        const bg = (attr >> 4) & 0x07;  // bit 7 is blink
        cell.fi = attr & 0x0f;
        cell.bi = bg;
        cell.fg = DOS_COLORS[cell.fi];
        cell.bg = bg ? DOS_COLORS[bg] : null;  // black background = transparent
      }
    }
    col++;
  }
  return { width, height, cells };
}

let catalog = null;

// Every usable font under TDF_DIR. One file can hold several fonts; those
// after the first get " #n" in their id.
export function listTdfFonts() {
  if (catalog) return catalog;
  catalog = [];
  if (!existsSync(TDF_DIR)) return catalog;
  const files = readdirSync(TDF_DIR).filter((f) => /\.tdf$/i.test(f))
    .sort((a, b) => a.localeCompare(b, "en", { sensitivity: "base" }));
  for (const file of files) {
    let fonts;
    try {
      fonts = parseFile(join(TDF_DIR, file));
    } catch {
      continue;
    }
    const stem = basename(file).replace(/\.tdf$/i, "");
    fonts.forEach((font, index) => {
      if (font.type !== "color" && font.type !== "block") return;
      catalog.push({
        id: TDF_PREFIX + stem + (index ? ` #${index}` : ""),
        name: font.name,
        file,
        index,
        type: font.type,
        spacing: font.spacing,
        font,
      });
    });
  }
  return catalog;
}

export function isTdf(id) {
  return String(id).toLowerCase().startsWith(TDF_PREFIX.toLowerCase());
}

export function resolveTdf(id) {
  const fonts = listTdfFonts();
  const folded = String(id).toLowerCase();
  const match = fonts.find((f) => f.id.toLowerCase() === folded);
  if (match) return match;
  if (!fonts.length) throw new Error(`no TheDraw fonts installed in ${TDF_DIR} (run: omascii tdf fetch)`);
  throw new Error(`unknown TheDraw font "${id}" (see: omascii fonts --tdf)`);
}

// Lay text out like tdfiglet: glyphs side by side with the font's letter
// spacing, lowercase falling back to uppercase, lines stacked with a blank row.
export function renderTdf(id, text) {
  const entry = resolveTdf(id);
  const font = entry.font;
  const glyphCache = new Map();
  const glyph = (code) => {
    if (!glyphCache.has(code)) glyphCache.set(code, decodeGlyph(font, code));
    return glyphCache.get(code);
  };
  const widths = [];
  for (let c = 33; c < 127; c++) {
    const g = glyph(c);
    if (g) widths.push(g.width);
  }
  const spaceWidth = Math.max(2, Math.round((widths.reduce((a, b) => a + b, 0) / Math.max(1, widths.length)) / 2));
  const gap = Math.min(font.spacing, 8);

  const out = [];
  const lines = String(text).split("\n");
  lines.forEach((line, li) => {
    const parts = [];
    for (const ch of line) {
      if (ch === " ") {
        parts.push({ width: spaceWidth, height: 0, cells: [] });
        continue;
      }
      const code = ch.codePointAt(0);
      let g = glyph(code);
      if (!g && ch !== ch.toUpperCase()) g = glyph(ch.toUpperCase().codePointAt(0));
      if (!g && ch !== ch.toLowerCase()) g = glyph(ch.toLowerCase().codePointAt(0));
      if (g) parts.push(g);
    }
    const height = Math.max(0, ...parts.map((p) => p.height));
    if (li > 0 && out.length) out.push([]);
    for (let r = 0; r < height; r++) {
      const row = [];
      parts.forEach((p, i) => {
        for (let c = 0; c < p.width; c++) row.push(p.cells[r]?.[c] || { ch: " ", fg: null, bg: null });
        if (i < parts.length - 1) for (let s = 0; s < gap; s++) row.push({ ch: " ", fg: null, bg: null });
      });
      out.push(row);
    }
  });
  return trimCells(out);
}

function blank(cell) {
  return cell.ch === " " && !cell.bg;
}

// Drop empty edge rows and columns, so the art centres on its ink
function trimCells(rows) {
  rows = rows.slice();
  while (rows.length && rows[0].every(blank)) rows.shift();
  while (rows.length && rows[rows.length - 1].every(blank)) rows.pop();
  if (!rows.length) return [];
  const width = Math.max(...rows.map((r) => r.length));
  const filled = rows.map((r) => r.concat(Array.from({ length: width - r.length }, () => ({ ch: " ", fg: null, bg: null }))));
  let left = 0;
  while (left < width && filled.every((r) => blank(r[left]))) left++;
  let right = width;
  while (right > left && filled.every((r) => blank(r[right - 1]))) right--;
  return filled.map((r) => r.slice(left, right));
}

export function cellsToText(rows) {
  return rows.map((r) => r.map((c) => c.ch).join("").trimEnd()).join("\n");
}

export function cellsToAnsi(rows) {
  const sgr = (hex, base) => `${base};2;${parseInt(hex.slice(0, 2), 16)};${parseInt(hex.slice(2, 4), 16)};${parseInt(hex.slice(4, 6), 16)}`;
  return rows.map((r) => {
    let s = "";
    let last = "";
    for (const c of r) {
      const key = `${c.fg}|${c.bg}`;
      if (key !== last) {
        s += "\x1b[0m" + (c.fg ? `\x1b[${sgr(c.fg, 38)}m` : "") + (c.bg ? `\x1b[${sgr(c.bg, 48)}m` : "");
        last = key;
      }
      s += c.ch;
    }
    return s + "\x1b[0m";
  }).join("\n");
}

// Compact colours for the shell gallery: per row, space-separated runs of
// <fg hex digit or "."><bg 0-7><length>, e.g. "c03 .02 b17". The rows line up
// with cellsToRows(), whose rows keep their full width.
export function cellsToCodes(rows) {
  return rows.map((r) => {
    const runs = [];
    let key = null;
    let n = 0;
    for (const c of r) {
      const k = (c.fi === undefined ? "." : c.fi.toString(16)) + (c.bi || 0);
      if (k !== key) {
        if (key !== null) runs.push(key + n);
        key = k;
        n = 0;
      }
      n++;
    }
    if (key !== null) runs.push(key + n);
    return runs.join(" ");
  }).join("\n");
}

export function cellsToRows(rows) {
  return rows.map((r) => r.map((c) => c.ch).join("")).join("\n");
}

const HTML_ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", " ": "&nbsp;" };

// Rich text for the shell's preview: one span per colour run
export function cellsToHtml(rows, fallback = "") {
  return rows.map((r) => {
    let s = "";
    let run = "";
    let key = null;
    const flush = () => {
      if (!run) return;
      const [fg, bg] = key.split("|");
      const style = (fg !== "null" ? `color:#${fg};` : (fallback ? `color:${fallback};` : ""))
        + (bg !== "null" ? `background-color:#${bg};` : "");
      s += style ? `<span style="${style}">${run}</span>` : run;
      run = "";
    };
    for (const c of r) {
      const k = `${c.fg}|${c.bg}`;
      if (k !== key) {
        flush();
        key = k;
      }
      run += HTML_ESCAPES[c.ch] || c.ch;
    }
    flush();
    return s;
  }).join("<br>");
}

export function tdfStats() {
  const fonts = listTdfFonts();
  return {
    dir: TDF_DIR,
    count: fonts.length,
    color: fonts.filter((f) => f.type === "color").length,
    block: fonts.filter((f) => f.type === "block").length,
    files: existsSync(TDF_DIR) ? readdirSync(TDF_DIR).filter((f) => /\.tdf$/i.test(f)).length : 0,
    updated: existsSync(TDF_DIR) ? statSync(TDF_DIR).mtimeMs : 0,
  };
}
