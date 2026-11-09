// TheDraw (.tdf) fonts in the browser: a port of omascii's lib/tdf.mjs.
//
// File layout (offsets as in tdfiglet): "\x13TheDraw FONTS file\x1a" (20
// bytes), then font records:
//   +0  55 AA 00 FF marker        +4  name length    +5  name (12 bytes)
//   +17 reserved (4)              +21 type: 0 outline, 1 block, 2 colour
//   +22 letter spacing            +23 data size (u16 LE)
//   +25 94 u16 LE glyph offsets for '!'..'~' (0xFFFF = missing)
//   +213 glyph data
// A glyph is width, height, then cells until NUL: CR (or LF) ends a row,
// other bytes are CP437 characters, each followed by a DOS attribute byte
// in colour fonts (low nibble foreground, bits 4-6 background).
(function () {
  "use strict";

  const MAGIC = "\x13TheDraw FONTS file\x1a";
  const TYPES = ["outline", "block", "color"];
  const CP437_HIGH = "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ";
  const DOS = ["#000000", "#0000aa", "#00aa00", "#00aaaa", "#aa0000", "#aa00aa", "#aa5500", "#aaaaaa",
    "#555555", "#5555ff", "#55ff55", "#55ffff", "#ff5555", "#ff55ff", "#ffff55", "#ffffff"];

  const cp437 = (b) => (b < 0x20 ? " " : b < 0x80 ? String.fromCharCode(b) : CP437_HIGH[b - 0x80]);
  const u16 = (buf, p) => buf[p] | (buf[p + 1] << 8);

  function parse(bytes) {
    let head = "";
    for (let i = 0; i < 20; i++) head += String.fromCharCode(bytes[i]);
    if (head !== MAGIC) return [];
    const fonts = [];
    let pos = 20;
    while (pos + 213 <= bytes.length && bytes[pos] === 0x55 && bytes[pos + 1] === 0xaa
           && bytes[pos + 2] === 0x00 && bytes[pos + 3] === 0xff) {
      const nameLen = Math.min(bytes[pos + 4], 12);
      let name = "";
      for (let i = 0; i < nameLen; i++) name += String.fromCharCode(bytes[pos + 5 + i]);
      const size = u16(bytes, pos + 23);
      const offsets = [];
      for (let i = 0; i < 94; i++) offsets.push(u16(bytes, pos + 25 + i * 2));
      fonts.push({
        name: name.replace(/\0.*$/, "").trim(),
        type: TYPES[bytes[pos + 21]] || "unknown",
        spacing: bytes[pos + 22],
        offsets,
        data: bytes.subarray(pos + 213, Math.min(bytes.length, pos + 213 + size)),
        glyphs: new Map(),
      });
      pos += 213 + size;
    }
    return fonts;
  }

  function glyph(font, code) {
    if (font.glyphs.has(code)) return font.glyphs.get(code);
    const index = code - 33;
    let g = null;
    if (index >= 0 && index < 94 && font.offsets[index] !== 0xffff) {
      const data = font.data;
      let p = font.offsets[index];
      if (p + 2 <= data.length) {
        const width = data[p], height = data[p + 1];
        p += 2;
        const cells = Array.from({ length: height }, () =>
          Array.from({ length: width }, () => ({ ch: " ", fg: null, bg: null })));
        let row = 0, col = 0;
        const colored = font.type === "color";
        while (p < data.length && data[p] !== 0) {
          const ch = data[p++];
          if (ch === 0x0d || ch === 0x0a) { row++; col = 0; continue; }
          let attr = null;
          if (colored && p < data.length) attr = data[p++];
          if (row < height && col < width) {
            const cell = cells[row][col];
            cell.ch = cp437(ch);
            if (attr !== null) {
              const bg = (attr >> 4) & 0x07;
              cell.fg = DOS[attr & 0x0f];
              cell.bg = bg ? DOS[bg] : null; // black background = transparent
            }
          }
          col++;
        }
        g = { width, height, cells };
      }
    }
    font.glyphs.set(code, g);
    return g;
  }

  const blank = (c) => c.ch === " " && !c.bg;

  function trim(rows) {
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

  // Fonts are named as omascii names them: "stem" for a file's first font,
  // "stem #n" for the others. The inline ones (OMA_TDF) draw at once; the
  // rest wait for load(), which adds assets/fonts/pack/<stem>.js.
  const INDEX = window.OMA_TDF_INDEX || {};
  const files = {}, pending = {};
  const split = (id) => { const m = /^(.*?)(?: #(\d+))?$/.exec(String(id).toLowerCase()); return [m[1], Number(m[2] || 0)]; };

  function add(stem, b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    files[stem] = parse(bytes);
    if (pending[stem]) { pending[stem].resolve(); delete pending[stem]; }
  }

  function font(id) {
    const [stem, n] = split(id);
    if (!files[stem] && (window.OMA_TDF || {})[stem]) add(stem, window.OMA_TDF[stem]);
    return files[stem] ? files[stem][n] || null : null;
  }
  const ready = (id) => !!font(id);

  // Resolves once the font can draw, or with false if it can't be had.
  function load(id) {
    const [stem] = split(id);
    if (ready(id)) return Promise.resolve(true);
    if (!INDEX[stem] || !INDEX[stem][0]) return Promise.resolve(false);
    if (!pending[stem]) {
      let resolve;
      const p = new Promise((r) => { resolve = r; });
      pending[stem] = { p, resolve };
      const s = document.createElement("script");
      s.src = "assets/fonts/pack/" + encodeURIComponent(stem) + ".js";
      s.onerror = () => { delete pending[stem]; resolve(); s.remove(); };
      s.onload = () => s.remove();
      document.head.append(s);
    }
    return pending[stem].p.then(() => ready(id));
  }

  // Lay text out like tdfiglet: glyphs side by side with the font's letter
  // spacing, lowercase falling back to uppercase, lines stacked with a blank
  // row. Returns rows of {ch, fg, bg} cells.
  function render(id, text, opts = {}) {
    const f = font(id);
    if (!f) return [];
    const widths = [];
    for (let c = 33; c < 127; c++) { const g = glyph(f, c); if (g) widths.push(g.width); }
    const spaceWidth = Math.max(2, Math.round(widths.reduce((a, b) => a + b, 0) / Math.max(1, widths.length) / 2));
    const gap = opts.spacing != null ? opts.spacing : Math.min(f.spacing, 8);
    const out = [];
    String(text).split("\n").forEach((line, li) => {
      const parts = [];
      for (const ch of line) {
        if (ch === " ") { parts.push({ width: spaceWidth, height: 0, cells: [] }); continue; }
        let g = glyph(f, ch.codePointAt(0));
        if (!g && ch !== ch.toUpperCase()) g = glyph(f, ch.toUpperCase().codePointAt(0));
        if (!g && ch !== ch.toLowerCase()) g = glyph(f, ch.toLowerCase().codePointAt(0));
        if (g) parts.push(g);
      }
      const height = Math.max(0, ...parts.map((p) => p.height));
      if (li > 0 && out.length) out.push([]);
      for (let r = 0; r < height; r++) {
        const row = [];
        parts.forEach((p, i) => {
          for (let c = 0; c < p.width; c++) row.push(Object.assign({}, p.cells[r] && p.cells[r][c] || { ch: " ", fg: null, bg: null }));
          if (i < parts.length - 1) for (let s = 0; s < gap; s++) row.push({ ch: " ", fg: null, bg: null });
        });
        out.push(row);
      }
    });
    return trim(out);
  }

  // From the index, without loading the font.
  function info(id) {
    const [stem, n] = split(id);
    const entry = INDEX[stem] && INDEX[stem][1].find((r) => r[2] === n);
    if (entry) return { id: n ? `${stem} #${n}` : stem, name: entry[0] || stem, type: entry[1], inline: !INDEX[stem][0] };
    const f = font(id);
    return f ? { id, name: f.name || id, type: f.type, inline: true } : null;
  }

  const all = Object.keys(INDEX).length
    ? Object.keys(INDEX).flatMap((stem) => INDEX[stem][1].map((r) => (r[2] ? `${stem} #${r[2]}` : stem)))
    : Object.keys(window.OMA_TDF || {});

  const toText = (rows) => rows.map((r) => r.map((c) => c.ch).join("").replace(/\s+$/, "")).join("\n");

  function toAnsi(rows) {
    const sgr = (hex, base) => `${base};2;${parseInt(hex.slice(1, 3), 16)};${parseInt(hex.slice(3, 5), 16)};${parseInt(hex.slice(5, 7), 16)}`;
    return rows.map((r) => {
      let s = "", last = "";
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

  window.TDF = { add, load, ready, render, info, toText, toAnsi, DOS,
    fonts: () => all.slice(), inline: () => all.filter((id) => (info(id) || {}).inline) };
})();
