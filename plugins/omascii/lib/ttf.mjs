// System and user TrueType/OpenType fonts for omascii, drawn as pixel art
// by image.py (text -> bitmap -> block, braille or ramp characters).
// Fonts come from fontconfig (those that cover English) plus any .ttf/.otf
// in TTF_DIR (omascii fonts add). Ids are "TTF <family> <style>".

import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const TTF_PREFIX = "TTF ";
export const TTF_DIR = process.env.OMASCII_TTF_DIR
  || join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "omascii", "ttf");

// Icon and emoji fonts draw nothing useful for text
const SKIP = /emoji|awesome|symbol|icons?\b|dingbat|wingding|cursor|music/i;

let catalog = null;

// fc-list for installed fonts, fc-scan for files in TTF_DIR
function fontconfig(tool, args) {
  const r = spawnSync(tool, [...args, "--format", "%{family[0]}\t%{style[0]}\t%{file}\t%{index}\n"],
    { encoding: "utf8" });
  if (r.status !== 0 || !r.stdout) return [];
  return r.stdout.split("\n").filter(Boolean).map((l) => {
    const [family, style, file, index] = l.split("\t");
    return { family, style: style || "Regular", file, index: Number(index) || 0 };
  });
}

export function listTtfFonts() {
  if (catalog) return catalog;
  const seen = new Set();
  catalog = [];
  const add = (f, source) => {
    if (!/\.(ttf|otf|ttc|otc)$/i.test(f.file) || SKIP.test(f.family)) return;
    const id = `${TTF_PREFIX}${f.family} ${f.style}`.replace(/\s+/g, " ").trim();
    if (seen.has(id.toLowerCase())) return;
    seen.add(id.toLowerCase());
    catalog.push({ id, family: f.family, style: f.style, file: f.file, index: f.index, source });
  };
  // User fonts first, so they win a name clash
  if (existsSync(TTF_DIR) && readdirSync(TTF_DIR).length) for (const f of fontconfig("fc-scan", [TTF_DIR])) add(f, "user");
  for (const f of fontconfig("fc-list", [":lang=en"])) add(f, "system");
  catalog.sort((a, b) => a.id.localeCompare(b.id, "en", { sensitivity: "base" }));
  return catalog;
}

export function isTtf(id) {
  return String(id).toLowerCase().startsWith(TTF_PREFIX.toLowerCase());
}

export function resolveTtf(id) {
  const folded = String(id).toLowerCase().replace(/\s+/g, " ").trim();
  const fonts = listTtfFonts();
  const match = fonts.find((f) => f.id.toLowerCase() === folded)
    // "TTF Family" alone means its Regular face (or the first one)
    || fonts.find((f) => f.id.toLowerCase() === `${folded} regular`)
    || fonts.find((f) => `${TTF_PREFIX}${f.family}`.toLowerCase() === folded);
  if (match) return match;
  throw new Error(`unknown system font "${id}" (see: omascii fonts --ttf)`);
}

export function ttfStats() {
  const fonts = listTtfFonts();
  return { dir: TTF_DIR, count: fonts.length, user: fonts.filter((f) => f.source === "user").length };
}
