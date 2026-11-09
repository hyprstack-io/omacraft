#!/usr/bin/env python3
"""Builds HyprVYZR's theme for the Kasm Workspaces dashboard.

  build.py [--palette omarchy|duckbones] [--colors colors.toml] [kasm-index.css]
                                 writes dist/duckbones.css and dist/wordmark.svg

The palette is the current Omarchy theme's (OmaCraft's own colours, from
~/.local/state/omarchy/current/theme/colors.toml) unless --palette duckbones
asks for the original scheme. The dashboard stays dark either way: a light
Omarchy theme lends its hues, and its ink becomes the background.

Kasm's stylesheet (CoreUI, Bootstrap 4, Tailwind with the tw- prefix and
Kasm's own variables) is read once, and every rule that sets a colour is
written out again with only its colour declarations, each colour moved onto
the Duckbones palette. The rules keep their selectors, order and media
queries, so Kasm's own cascade (light/dark, hover, active) still decides
which one wins; only the colours change. theme.css, the hand-written layer
with the Kasm variables and the HyprStack look, goes after it.

Stdlib only. The input is Kasm 1.19's index.css, saved in vendor/.
"""

import argparse
import colorsys
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "dist/duckbones.css"

# Duckbones (zenbones.nvim, mcchrish), dark: the roles theme.css is written
# in. An Omarchy palette replaces every one of them (omarchy_roles below).
DUCKBONES = {
    "bg": "#0E101A", "bg-deep": "#090A11", "bg-raise": "#151826", "surface": "#1B1E2E",
    "line": "#2B2F46", "line-2": "#3A3F5C", "sel": "#37382D", "fg": "#EBEFC0", "fg-dim": "#B3B692",
    "muted": "#8B8E7A", "impact": "#F4F7D9", "pale": "#D6DAAE",
    "leaf": "#5DCD97", "leaf-hi": "#58DB9E", "water": "#00A3CB", "water-hi": "#00B4E0",
    "wood": "#E39500", "wood-hi": "#F6A100", "rose": "#E03600", "rose-hi": "#FF4821",
    "blossom": "#795CCC", "blossom-hi": "#B3A1E6", "blossom-pale": "#C9BCF0",
}
BG = "#0E101A"
FG = "#EBEFC0"
# Neutrals from black to white: Duckbones' blue-black up to its cream.
NEUTRALS = ["#07080D", "#0E101A", "#151826", "#1B1E2E", "#2B2F46", "#3A3F5C",
            "#5A5E78", "#8B8E7A", "#B3B692", "#D6DAAE", "#EBEFC0", "#F4F7D9"]
# Hue families: (low, high) on the colour wheel, then the base and bright tone.
FAMILIES = [
    ((0, 18), "#E03600", "#FF4821"),      # rose (red)
    ((18, 52), "#E39500", "#F6A100"),     # wood (orange, amber, yellow)
    ((52, 175), "#5DCD97", "#58DB9E"),    # leaf (lime, green, emerald, teal)
    ((175, 235), "#00A3CB", "#00B4E0"),   # water (cyan, sky, blue)
    ((235, 300), "#795CCC", "#B3A1E6"),   # blossom (indigo, violet, purple)
    ((300, 345), "#B3A1E6", "#C9BCF0"),   # blossom, light (fuchsia, pink)
    ((345, 361), "#E03600", "#FF4821"),   # rose
]

COLOR = re.compile(
    r"#[0-9a-fA-F]{8}\b|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3,4}\b"
    r"|rgba?\(\s*[\d.]+[\s,]+[\d.]+[\s,]+[\d.]+\s*(?:[,/]\s*(?:var\([^)]*\)|[\d.]+%?))?\s*\)"
    r"|\b(?:white|black)\b")
COLOR_PROPS = re.compile(
    r"^(?:color|background|background-color|background-image|border(?:-(?:top|right|bottom|left))?(?:-color)?"
    r"|outline(?:-color)?|box-shadow|text-shadow|fill|stroke|caret-color|text-decoration-color|column-rule-color"
    r"|--[\w-]+)$")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def to_hex(c):
    return "#%02x%02x%02x" % tuple(round(max(0, min(1, v)) * 255) for v in c)


def lum(c):
    def ch(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ramp(stops, t):
    t = max(0.0, min(1.0, t)) * (len(stops) - 1)
    i = min(int(t), len(stops) - 2)
    return mix(hex_rgb(stops[i]), hex_rgb(stops[i + 1]), t - i)


def duckbones(rgb):
    """The Duckbones colour that plays the same part as rgb."""
    h, l, s = colorsys.rgb_to_hls(*rgb)
    # Chroma, not HLS saturation: that calls near-whites and blue-greys
    # (#f0f3f5, #536c79) colourful.
    # Kasm's navies and blue-greys (#181f47, #678898) are its neutrals, so
    # dark and pale colours need more chroma to count as a hue.
    chroma = max(rgb) - min(rgb)
    if chroma < (0.36 if l < 0.32 else 0.30 if l > 0.85 else 0.22):
        return ramp(NEUTRALS, l)
    deg = h * 360
    base, bright = next((hex_rgb(b), hex_rgb(br)) for (lo, hi), b, br in FAMILIES if lo <= deg < hi)
    # Keep how light or dark the original was: light tints lean to the
    # cream, deep shades to the blue-black.
    if l > 0.62:
        return mix(bright, hex_rgb(FG), min(1, (l - 0.62) / 0.33) * 0.75)
    if l > 0.45:
        return mix(base, bright, (l - 0.45) / 0.17)
    return mix(base, hex_rgb(BG), min(1, (0.45 - l) / 0.39) * 0.8)


def recolor(match):
    text = match.group(0)
    low = text.lower()
    if low in ("white", "black"):
        return to_hex(duckbones((1, 1, 1) if low == "white" else (0, 0, 0)))
    alpha = ""
    if text.startswith("#"):
        h = text[1:]
        if len(h) in (3, 4):
            h = "".join(c * 2 for c in h)
        rgb = hex_rgb(h[:6])
        if len(h) == 8:
            alpha = h[6:]
        return to_hex(duckbones(rgb)) + alpha
    nums = re.findall(r"var\([^)]*\)|[\d.]+%?", text[text.index("(") + 1:-1])
    rgb = tuple(float(n) / 255 for n in nums[:3])
    out = duckbones(rgb)
    r, g, b = (round(v * 255) for v in out)
    if len(nums) > 3:
        sep = "/" if "/" in text else ","
        if sep == "/":
            return f"rgb({r} {g} {b}/{nums[3]})"
        return f"rgba({r},{g},{b},{nums[3]})"
    return f"rgb({r} {g} {b})" if " " in text and "," not in text else f"rgb({r},{g},{b})"


def split_decls(body):
    out, depth, cur, quote = [], 0, "", ""
    for ch in body:
        if quote:
            cur += ch
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == ";" and depth == 0:
            out.append(cur)
            cur = ""
            continue
        cur += ch
    if cur.strip():
        out.append(cur)
    return out


def color_decls(body):
    keep = []
    for decl in split_decls(body):
        if ":" not in decl:
            continue
        prop, value = decl.split(":", 1)
        prop = prop.strip()
        if not COLOR_PROPS.match(prop) or "url(" in value or not COLOR.search(value):
            continue
        keep.append(f"{prop}:{COLOR.sub(recolor, value.strip())}")
    return ";".join(keep)


def blocks(css):
    """Yields (prelude, body, is_group) at this nesting level."""
    i, n = 0, len(css)
    while i < n:
        j = css.find("{", i)
        if j < 0:
            return
        prelude = css[i:j].strip()
        depth, k, quote = 1, j + 1, ""
        while k < n and depth:
            ch = css[k]
            if quote:
                if ch == quote:
                    quote = ""
            elif ch in "\"'":
                quote = ch
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            k += 1
        body = css[j + 1:k - 1]
        # A statement at-rule (@charset, @import) before the selector.
        while prelude.startswith("@") and ";" in prelude:
            prelude = prelude.split(";", 1)[1].strip()
        yield prelude, body, prelude.startswith(("@media", "@supports", "@layer", "@container"))
        i = k


def walk(css):
    out = []
    for prelude, body, group in blocks(css):
        if group:
            inner = walk(body)
            if inner:
                out.append(f"{prelude}{{{inner}}}")
        elif prelude.startswith(("@font-face", "@keyframes", "@-webkit-keyframes", "@page", "@property")):
            continue
        else:
            decls = color_decls(body)
            if decls:
                out.append(f"{prelude}{{{decls}}}")
    return "\n".join(out)


def wordmark_svg(text):
    """The FIGlet wordmark as rectangles, so it needs no font: a full block
    fills its cell, box-drawing characters become doubled strokes."""
    W, H, T, G = 10, 20, 1.6, 2.4  # cell size, stroke, half the gap of a double line
    arms = {"═": "lr", "║": "ud", "╗": "ld", "╔": "rd", "╝": "lu", "╚": "ru",
            "─": "lr", "│": "ud", "┐": "ld", "┌": "rd", "┘": "lu", "└": "ru"}
    lines = text.rstrip("\n").split("\n")
    rects = []
    for row, line in enumerate(lines):
        for col, ch in enumerate(line):
            x, y = col * W, row * H
            if ch == "█":
                rects.append((x, y, W + .3, H + .3))
                continue
            dirs = arms.get(ch, "")
            if not dirs:
                continue
            cx, cy = x + W / 2, y + H / 2
            offsets = (-G, G) if ch in "═║╗╔╝╚" else (0,)
            if dirs == "lr":
                rects += [(x, cy + o - T / 2, W, T) for o in offsets]
                continue
            if dirs == "ud":
                rects += [(cx + o - T / 2, y, T, H) for o in offsets]
                continue
            # A corner: one horizontal arm (h) and one vertical arm (v). Of a
            # double line, the outer stroke runs past the centre, the inner
            # one stops short, so the two strokes nest.
            h, v = dirs[0], dirs[1]
            sh = 1 if h == "l" else -1      # the horizontal arm runs from its edge towards +sh
            sv = 1 if v == "u" else -1      # the vertical arm runs from its edge towards +sv
            for o in offsets:
                outer = o == 0 or (o < 0) == (v == "d")
                reach = cx + sh * ((G if outer else -G) if o else T / 2)
                x0, x1 = sorted((x if h == "l" else x + W, reach))
                rects.append((x0, cy + o - T / 2, x1 - x0, T))
            for o in offsets:
                outer = o == 0 or (o > 0) == (h == "l")
                reach = cy + sv * ((G if outer else -G) if o else T / 2)
                y0, y1 = sorted((y if v == "u" else y + H, reach))
                rects.append((cx + o - T / 2, y0, T, y1 - y0))
    width = max(len(l) for l in lines) * W
    body = "".join(f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}"/>' for x, y, w, h in rects)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {len(lines) * H}" '
            f'shape-rendering="crispEdges"><title>HyprVYZR</title><g fill="#fff">{body}</g></svg>\n')


# ------------------------------------------------------------------ Omarchy

def read_colors(path):
    """colors.toml's key = "#rrggbb" lines (it is flat), as {key: hex}."""
    out = {}
    for line in Path(path).read_text().splitlines():
        m = re.match(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6})"', line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def readable(color, bg, ratio=4.5):
    """color, lightened until it reads on bg (WCAG AA for text)."""
    c = color
    for _ in range(40):
        if contrast(c, bg) >= ratio:
            break
        c = mix(c, (1, 1, 1), 0.06)
    return c


def rotate(rgb, degrees):
    h, l, s = colorsys.rgb_to_hls(*rgb)
    return colorsys.hls_to_rgb((h + degrees / 360) % 1, l, s)


def omarchy_roles(colors):
    """Duckbones' roles from an Omarchy theme. accent-2 is the suite's rule:
    the accent turned 50 degrees round the hue wheel."""
    get = lambda k, d: hex_rgb(colors.get(k, d))
    back, fore = get("background", "#1a1b26"), get("foreground", "#c0caf5")
    # Always a dark dashboard: the darker of the two is the ground.
    dark, light = (back, fore) if lum(back) <= lum(fore) else (mix(fore, (0, 0, 0), 0.35), back)
    if lum(dark) > 0.04:
        dark = mix(dark, (0, 0, 0), 0.5)
    accent = get("accent", colors.get("blue", "#7aa2f7"))
    r = {
        "bg": dark, "bg-deep": mix(dark, (0, 0, 0), 0.35), "bg-raise": mix(dark, light, 0.05),
        "surface": mix(dark, light, 0.09), "line": mix(dark, light, 0.19), "line-2": mix(dark, light, 0.28),
        "fg": light, "impact": mix(light, (1, 1, 1), 0.35),
    }
    r["sel"] = mix(dark, get("selection", colors.get("accent", "#7aa2f7")), 0.55) if "selection" in colors \
        else mix(dark, accent, 0.3)
    r["fg-dim"] = readable(mix(light, dark, 0.22), dark, 7)
    r["muted"] = readable(mix(light, dark, 0.42), dark, 4.5)
    r["pale"] = mix(light, r["fg-dim"], 0.5)
    hues = {"leaf": accent, "water": get("blue", "#7aa2f7"), "wood": get("yellow", "#e0af68"),
            "rose": get("red", "#f7768e"), "blossom": rotate(accent, 50)}
    for name, c in hues.items():
        base = readable(c, dark, 4.5)
        r[name] = base
        r[name + "-hi"] = readable(mix(base, (1, 1, 1), 0.18), dark, 5)
    r["blossom-pale"] = mix(r["blossom-hi"], light, 0.35)
    return {k: to_hex(v) for k, v in r.items()}


def use_palette(roles):
    """Points the recolouring and theme.css at roles (a full DUCKBONES-shaped map)."""
    global BG, FG, NEUTRALS, FAMILIES
    BG, FG = roles["bg"], roles["fg"]
    NEUTRALS = [roles[k] for k in ("bg-deep", "bg", "bg-raise", "surface", "line", "line-2")] + \
        [to_hex(mix(hex_rgb(roles["line-2"]), hex_rgb(roles["muted"]), 0.5)), roles["muted"], roles["fg-dim"],
         roles["pale"], roles["fg"], roles["impact"]]
    FAMILIES = [
        ((0, 18), roles["rose"], roles["rose-hi"]),
        ((18, 52), roles["wood"], roles["wood-hi"]),
        ((52, 175), roles["leaf"], roles["leaf-hi"]),
        ((175, 235), roles["water"], roles["water-hi"]),
        ((235, 300), roles["blossom"], roles["blossom-hi"]),
        ((300, 345), roles["blossom-hi"], roles["blossom-pale"]),
        ((345, 361), roles["rose"], roles["rose-hi"]),
    ]


def repaint(css, roles):
    """theme.css is written in Duckbones; each of its colours (hex, or the
    "r, g, b" triples inside rgba() and Kasm's -rgb variables) becomes the
    same role's."""
    swap = {DUCKBONES[k].lower(): roles[k] for k in DUCKBONES}

    def hex_sub(m):
        return swap.get(m.group(0).lower(), m.group(0))

    css = re.sub(r"#[0-9A-Fa-f]{6}(?![0-9A-Fa-f])", hex_sub, css)
    triples = {}
    for k in DUCKBONES:
        r, g, b = (round(v * 255) for v in hex_rgb(DUCKBONES[k]))
        nr, ng, nb = (round(v * 255) for v in hex_rgb(roles[k]))
        triples[(r, g, b)] = f"{nr}, {ng}, {nb}"

    def tri_sub(m):
        key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        return triples.get(key, m.group(0))

    return re.sub(r"\b(\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\b", tri_sub, css)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--palette", choices=["omarchy", "duckbones"], default="omarchy")
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    ap.add_argument("--colors", default=str(state / "omarchy/current/theme/colors.toml"))
    ap.add_argument("source", nargs="?", default=str(HERE / "vendor/kasm-1.19.0-index.css"))
    args = ap.parse_args()
    SRC = Path(args.source)
    roles = dict(DUCKBONES)
    if args.palette == "omarchy":
        try:
            roles = omarchy_roles(read_colors(args.colors))
        except OSError:
            print(f"build.py: no Omarchy theme at {args.colors}; using Duckbones", file=sys.stderr)
    use_palette(roles)
    (HERE / "dist").mkdir(exist_ok=True)
    (HERE / "dist/wordmark.svg").write_text(wordmark_svg((HERE / "wordmark.txt").read_text()))
    css = re.sub(r"/\*.*?\*/", "", SRC.read_text(), flags=re.S)
    remap = walk(css)
    theme = repaint((HERE / "theme.css").read_text(), roles)
    # @import only counts at the top of a stylesheet.
    imports = re.findall(r"^@import[^;]*;\n", theme, flags=re.M)
    for line in imports:
        theme = theme.replace(line, "")
    # Plain ASCII out, so no @charset is needed: other characters become CSS escapes.
    theme = "".join(c if ord(c) < 128 else "\\%x " % ord(c) for c in theme)
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(
        f"/* HyprVYZR for Kasm Workspaces 1.19, in the {args.palette} palette. Built by build.py, don't edit.\n"
        "   Part 1 is Kasm's own colours moved onto the palette; part 2 is theme.css. */\n"
        + "".join(imports) + remap + "\n\n" + theme)
    print(f"{OUT}: {len(remap.splitlines())} recoloured rules, {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
