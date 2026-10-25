#!/usr/bin/env python3
"""Turn an image, or text in a TrueType/OpenType font, into ASCII art cells for omascii.

  image.py image <path> [--width N] [options]
  image.py text --text T --font-file F [--font-index N] [--rows N] [options]
  image.py gallery --text T [--rows N] [options] < [{id, file, index}]

Prints JSON: rows of [ch, fg, bg] cells (colours "rrggbb" or null), or for
gallery [{font, art}].

Charsets:
  ascii      10-step ramp " .:-=+*#%@"
  detailed   70-step ramp (more tones, busier)
  blocks     shade blocks " ░▒▓█"
  braille    2x4 dots per cell, the finest detail
  quadrant   2x2 block quadrants per cell
  halfblock  two pixels per cell (▀ over its background): full colour
  custom     your own ramp, darkest first (--chars)

Terminal cells are twice as tall as wide, so the image is sampled at half
height. Transparent pixels stay empty. Bright pixels get dense characters
(they show on the dark boot screen) unless --invert.
"""

import argparse
import json
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps

RAMPS = {
    "ascii": " .:-=+*#%@",
    "detailed": " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$",
    "blocks": " ░▒▓█",
}
# Sub-cell pixel grid per charset (columns, rows)
GRID = {"braille": (2, 4), "quadrant": (2, 2), "halfblock": (1, 2)}
# Braille dot bits by (column, row)
BRAILLE = {(0, 0): 0x01, (0, 1): 0x02, (0, 2): 0x04, (1, 0): 0x08,
           (1, 1): 0x10, (1, 2): 0x20, (0, 3): 0x40, (1, 3): 0x80}
# Quadrant bits: 1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right
QUADRANTS = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"


def hexcol(rgb):
    return "%02x%02x%02x" % tuple(int(v) for v in rgb[:3])


def load(path, opts):
    img = Image.open(path)
    img = ImageOps.exif_transpose(img).convert("RGBA")
    if opts.crop:
        bbox = img.getchannel("A").getbbox()
        if bbox:
            img = img.crop(bbox)
    return img


def sized(img, cols, sub):
    """Resample to cols cells wide; cells are 1:2, so rows follow from that."""
    sx, sy = sub
    w, h = img.size
    rows = max(1, round(cols * h / w / 2))
    return img.resize((cols * sx, rows * sy), Image.Resampling.LANCZOS), rows


def luminance(px):
    r, g, b = px[:3]
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255


def ramp_cells(img, cols, ramp, opts):
    small, rows = sized(img, cols, (1, 1))
    px = small.load()
    out = []
    for y in range(rows):
        row = []
        for x in range(cols):
            p = px[x, y]
            if p[3] < 40:
                row.append([" ", None, None])
                continue
            v = luminance(p) ** opts.gamma
            if opts.invert:
                v = 1 - v
            ch = ramp[min(len(ramp) - 1, int(v * len(ramp)))]
            row.append([ch, hexcol(p) if opts.colors and ch != " " else None, None])
        out.append(row)
    return out


def bitmap(small, opts):
    """1 bit per pixel: on where bright (or dark with --invert), off where
    transparent. Floyd-Steinberg dithered with --dither."""
    gray = small.convert("L")
    if opts.gamma != 1:
        gray = gray.point(lambda v: 255 * (v / 255) ** opts.gamma)
    if opts.invert:
        gray = ImageOps.invert(gray)
    if opts.dither:
        bits = gray.convert("1", dither=Image.Dither.FLOYDSTEINBERG)
    else:
        cut = opts.threshold * 255 / 100
        bits = gray.point(lambda v: 255 if v >= cut else 0).convert("1", dither=Image.Dither.NONE)
    bp = bits.load()
    ap = small.getchannel("A").load()
    return lambda x, y: bool(bp[x, y]) and ap[x, y] >= 40


def average(px, points):
    pts = [px[p] for p in points if px[p][3] >= 40]
    if not pts:
        return None
    return hexcol([sum(p[i] for p in pts) / len(pts) for i in range(3)])


def dot_cells(img, cols, kind, opts):
    sx, sy = GRID[kind]
    small, rows = sized(img, cols, (sx, sy))
    on = bitmap(small, opts)
    px = small.load()
    out = []
    for y in range(rows):
        row = []
        for x in range(cols):
            lit = [(x * sx + dx, y * sy + dy) for dy in range(sy) for dx in range(sx)
                   if on(x * sx + dx, y * sy + dy)]
            if kind == "braille":
                bits = sum(BRAILLE[(px_ - x * sx, py - y * sy)] for px_, py in lit)
                ch = chr(0x2800 + bits) if bits else " "
            else:
                bits = sum(1 << ((py - y * sy) * 2 + (px_ - x * sx)) for px_, py in lit)
                ch = QUADRANTS[bits]
            fg = average(px, lit) if opts.colors and lit else None
            row.append([ch, fg, None])
        out.append(row)
    return out


def half_cells(img, cols, opts):
    if not opts.colors:
        return dot_cells_half(img, cols, opts)
    small, rows = sized(img, cols, (1, 2))
    px = small.load()
    out = []
    for y in range(rows):
        row = []
        for x in range(cols):
            top, bottom = px[x, y * 2], px[x, y * 2 + 1]
            t = hexcol(top) if top[3] >= 40 else None
            b = hexcol(bottom) if bottom[3] >= 40 else None
            if t and b:
                row.append(["▀", t, b] if t != b else ["█", t, None])
            elif t:
                row.append(["▀", t, None])
            elif b:
                row.append(["▄", b, None])
            else:
                row.append([" ", None, None])
        out.append(row)
    return out


def dot_cells_half(img, cols, opts):
    small, rows = sized(img, cols, (1, 2))
    on = bitmap(small, opts)
    chars = {(False, False): " ", (True, False): "▀", (False, True): "▄", (True, True): "█"}
    return [[[chars[(on(x, y * 2), on(x, y * 2 + 1))], None, None] for x in range(cols)]
            for y in range(rows)]


def adjust(img, opts):
    rgb = img.convert("RGB")
    if opts.normalize:
        rgb = ImageOps.autocontrast(rgb, cutoff=1)
    if opts.brightness != 1:
        rgb = ImageEnhance.Brightness(rgb).enhance(opts.brightness)
    if opts.contrast != 1:
        rgb = ImageEnhance.Contrast(rgb).enhance(opts.contrast)
    if opts.saturation != 1:
        rgb = ImageEnhance.Color(rgb).enhance(opts.saturation)
    rgb.putalpha(img.getchannel("A"))
    return rgb


def convert(img, cols, opts):
    cols = max(4, min(400, cols))
    if opts.charset in GRID:
        if opts.charset == "halfblock":
            return half_cells(img, cols, opts)
        return dot_cells(img, cols, opts.charset, opts)
    ramp = opts.chars if opts.charset == "custom" else RAMPS[opts.charset]
    if not ramp:
        sys.exit("custom charset needs --chars")
    if not ramp.startswith(" "):
        ramp = " " + ramp
    return ramp_cells(img, cols, ramp, opts)


def text_image(text, font_file, index=0):
    """White text on black, rendered large and cropped to the ink."""
    font = ImageFont.truetype(font_file, 160, index=index)
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    box = probe.multiline_textbbox((0, 0), text, font=font, spacing=24)
    w, h = box[2] - box[0] + 40, box[3] - box[1] + 40
    if w * h > 40_000_000:
        raise ValueError("text too long")
    mask = Image.new("L", (max(1, w), max(1, h)), 0)
    ImageDraw.Draw(mask).multiline_text((20 - box[0], 20 - box[1]), text, font=font, fill=255, spacing=24)
    bbox = mask.getbbox()
    if not bbox:
        raise ValueError("the font has no glyphs for this text")
    mask = mask.crop(bbox)
    img = Image.merge("RGBA", (mask, mask, mask, Image.new("L", mask.size, 255)))
    return img


def text_cells(text, font_file, index, rows, opts):
    """Text in a TrueType/OpenType font, `rows` cells tall."""
    img = text_image(text, font_file, index)
    sy = GRID.get(opts.charset, (1, 1))[1]
    # Keep the ink's aspect: cells are 1:2, so cols = 2 * rows * w / h
    cols = max(1, round(2 * rows * img.size[0] / img.size[1]))
    # A clean bitmap: coverage is the brightness, no colours or levels
    opts.colors = False
    opts.invert = False
    cells = convert(img, cols, opts)
    # Rounding can leave an empty row; keep exactly what has ink
    while cells and all(c[0] == " " for c in cells[-1]):
        cells.pop()
    return cells


def common(ap):
    ap.add_argument("--charset", default="ascii", choices=[*RAMPS, *GRID, "custom"])
    ap.add_argument("--chars", default="", help="custom ramp, darkest first")
    ap.add_argument("--invert", action="store_true")
    ap.add_argument("--colors", action="store_true", help="keep the image's colours")
    ap.add_argument("--dither", action="store_true")
    ap.add_argument("--threshold", type=float, default=50, help="0-100, for dot charsets")
    ap.add_argument("--contrast", type=float, default=1)
    ap.add_argument("--brightness", type=float, default=1)
    ap.add_argument("--saturation", type=float, default=1)
    ap.add_argument("--gamma", type=float, default=1)
    ap.add_argument("--normalize", action="store_true", help="stretch the levels to full range first")
    ap.add_argument("--crop", action="store_true", help="crop transparent edges")


def dump(data):
    json.dump(data, sys.stdout, ensure_ascii=False, separators=(",", ":"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("image", help="an image file -> cells")
    p.add_argument("path")
    p.add_argument("--width", type=int, default=80, help="columns")
    common(p)
    p = sub.add_parser("text", help="text in a font file -> cells")
    p.add_argument("--text", required=True)
    p.add_argument("--font-file", required=True)
    p.add_argument("--font-index", type=int, default=0)
    p.add_argument("--rows", type=int, default=8)
    common(p)
    p = sub.add_parser("gallery", help="text in many fonts (JSON [{id, file, index}] on stdin)")
    p.add_argument("--text", required=True)
    p.add_argument("--rows", type=int, default=8)
    common(p)
    opts = ap.parse_args()

    if opts.cmd == "image":
        try:
            img = adjust(load(opts.path, opts), opts)
        except (OSError, ValueError) as e:
            sys.exit(f"cannot read image {opts.path}: {e}")
        dump(convert(img, opts.width, opts))
    elif opts.cmd == "text":
        try:
            dump(text_cells(opts.text, opts.font_file, opts.font_index, max(2, opts.rows), opts))
        except (OSError, ValueError) as e:
            sys.exit(f"cannot render with {opts.font_file}: {e}")
    else:
        out = []
        for f in json.load(sys.stdin):
            try:
                cells = text_cells(opts.text, f["file"], f.get("index", 0), max(2, opts.rows), opts)
                out.append({"font": f["id"], "art": "\n".join("".join(c[0] for c in r).rstrip() for r in cells)})
            except Exception as e:  # one broken font must not sink the page
                out.append({"font": f["id"], "art": "", "error": str(e)})
        dump(out)


if __name__ == "__main__":
    main()
