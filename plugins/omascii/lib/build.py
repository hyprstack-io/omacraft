#!/usr/bin/env python3
"""Build a Plymouth theme that shows FIGlet ASCII art, for omascii.

Adapted from the HyprStack theme builder (~/Projects/hyprboot/build.py).
Animated style renders ttfx (terminal text effects) intros of the art into
PNG frames; static style draws the art once. ttfx draws each frame as a full
block of rows and then emits ESC 8 ESC 7 ESC [nA to jump back to the top, so
frames are split on that.

Each terminal cell becomes a CELL_W x CELL_H pixel tile. Block elements,
box drawing and braille are drawn as crisp shapes; everything else with a
monospace font (falling back through fontconfig for symbols it lacks).

Colours come from the current Omarchy theme's colors.toml, so the splash
matches the desktop. Re-run after changing theme to pick up the new palette.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import effects as native

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
COLORS_TOML = Path.home() / ".local/state/omarchy/current/theme/colors.toml"
FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"

# Base cell at scale 1, matching the HyprStack theme
BASE_W, BASE_H, BASE_FONT = 8, 16, 13
MARGIN_X, MARGIN_Y = 4, 3          # canvas cells around the text

# Stock Omarchy boot colours, used without a theme colors.toml
STOCK = {"background": "2d353b", "lighter_background": "292e42", "accent": "7fbbb3",
         "foreground": "d3c6aa"}

EFFECT_NAMES = ["decrypt", "beams", "burn", "slide", "rain", "laseretch",
                "waves", "middleout", "vhstape", "sweep", "unstable"]
# More ttfx intros, with ttfx's own colours for the effect itself
EXTRA_EFFECTS = ["expand", "pour", "print", "scattered", "slice", "spotlights", "wipe",
                 "errorcorrect", "randomsequence", "swarm", "fireworks", "blackhole", "rings",
                 "bubbles", "crumble", "binarypath", "overflow", "spray", "orbittingvolley",
                 "smoke", "bouncyballs"]
# The rest of what Omarchy's screensaver picks from at random (it runs every
# ttfx effect); matrix and thunderstorm are timed in seconds, so they run
# against a real 50 fps clock
SCREENSAVER_EFFECTS = ["matrix", "synthgrid", "thunderstorm", "colorshift", "highlight"]
REALTIME = {"matrix", "thunderstorm"}
# Effects that end on their own text gradient instead of --final-gradient-stops
OWN_FINAL = {"synthgrid"}
# Effects that only recolour the art. With "always", ttfx pins every cell to
# the art's own colours (TheDraw colour fonts, images, gradients), leaving
# them nothing to animate; "dynamic" lets the effect colour each frame and
# still settles on the art's colours.
COLOR_ONLY = {"spotlights", "colorshift", "highlight"}
# Screensaver-style variants of ttfx effects: name -> the ttfx effect they run
PRESET_BASES = {"matrix-theme": "matrix", "matrix-binary": "matrix", "synthgrid-neon": "synthgrid",
                "thunderstorm-violet": "thunderstorm", "colorshift-rainbow": "colorshift",
                "fireworks-neon": "fireworks", "burn-inferno": "burn", "beams-aurora": "beams",
                "rain-storm": "rain", "decrypt-green": "decrypt"}
PRESET_EFFECTS = list(PRESET_BASES)
NATIVE_EFFECTS = native.NATIVE_EFFECTS
HOLD_EFFECT = "highlight"

FRAME_SPLIT = re.compile(r"\x1b8?\x1b7\x1b\[\d+A")
TOKEN = re.compile(r"\x1b\[([0-9;]*)m|\x1b\[\?[0-9]+[hl]|\x1b[78]|\x1b\[\d*[A-D]|(.)", re.S)


def load_palette():
    try:
        data = tomllib.loads(COLORS_TOML.read_text())
    except (OSError, tomllib.TOMLDecodeError):
        return dict(STOCK), None
    pal = {k: v.lstrip("#") for k, v in data.items()
           if isinstance(v, str) and re.fullmatch(r"#?[0-9a-fA-F]{6}", v)}
    if "background" not in pal:
        return dict(STOCK), None
    pal.setdefault("accent", pal.get("foreground", STOCK["accent"]))
    return pal, COLORS_TOML


def rgb(hexcol):
    return tuple(int(hexcol[i:i + 2], 16) for i in (0, 2, 4))


def screen_size():
    """Largest connected monitor in physical pixels (Plymouth runs at native mode)."""
    try:
        mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True,
                                         check=True, timeout=5).stdout)
        sizes = [(m["width"], m["height"]) for m in mons if m.get("width")]
        if sizes:
            return max(sizes, key=lambda s: s[0] * s[1])
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        pass
    return 1920, 1080


def pick_scale(cols, rows, screen, wanted):
    """Cell scale that fits the canvas in ~85% of the width and ~55% of the
    height (the password box and progress bar sit below it)."""
    if wanted != "auto":
        return float(wanted)
    w, h = screen
    for s in (2, 1.5, 1.25, 1, 0.75, 0.625, 0.5, 0.375, 0.25):
        if cols * BASE_W * s <= w * 0.85 and rows * BASE_H * s <= h * 0.55:
            return s
    return 0.25


# ------------------------------------------------------------------ ttfx frames

def run_ttfx(logo, effect, args, cols, rows, seed, bg, fg, keep_colors=False):
    # keep_colors: the input carries ANSI colours (TheDraw colour fonts) that
    # the effects should settle on instead of the final gradient
    base = PRESET_BASES.get(effect, effect)
    rate = "50" if base in REALTIME else "0"
    cmd = ["ttfx", "-i", logo, "--frame-rate", rate,
           "--canvas-width", str(cols), "--canvas-height", str(rows),
           "--anchor-canvas", "c", "--anchor-text", "c",
           "--ignore-terminal-dimensions", "--no-restore-cursor",
           "--terminal-background-color", bg, "--seed", str(seed),
           *(["--existing-color-handling", "dynamic" if base in COLOR_ONLY else "always"] if keep_colors else []),
           base, *args, *([] if base in OWN_FINAL else ["--final-gradient-stops", fg])]
    out = subprocess.run(cmd, capture_output=True, check=True).stdout
    return out.decode("utf-8", "replace")


def parse_frames(stream, cols, rows):
    frames = []
    for chunk in FRAME_SPLIT.split(stream):
        grid = [[(" ", None, None) for _ in range(cols)] for _ in range(rows)]
        r = c = 0
        fg = bg = None
        for m in TOKEN.finditer(chunk):
            sgr, ch = m.group(1), m.group(2)
            if sgr is not None:
                parts = [int(p) for p in sgr.split(";") if p] or [0]
                i = 0
                while i < len(parts):
                    p = parts[i]
                    if p == 0:
                        fg = bg = None
                    elif p in (38, 48) and i + 4 < len(parts) and parts[i + 1] == 2:
                        col = tuple(parts[i + 2:i + 5])
                        if p == 38:
                            fg = col
                        else:
                            bg = col
                        i += 4
                    elif p == 39:
                        fg = None
                    elif p == 49:
                        bg = None
                    i += 1
            elif ch is not None:
                if ch == "\n":
                    r, c = r + 1, 0
                elif ch == "\r":
                    c = 0
                elif r < rows and c < cols:
                    grid[r][c] = (ch, fg, bg)
                    c += 1
        if any(cell[0] != " " or cell[2] for row in grid for cell in row):
            frames.append(grid)
    return frames


def text_grid(lines, cols, rows, cells=None):
    """The art centred on the canvas, like ttfx's final frame: in the art
    colour, or in its own colours when cells ([ch, fg, bg] rows) are given."""
    grid = [[(" ", None, None) for _ in range(cols)] for _ in range(rows)]
    width = max(len(l) for l in lines)
    top = (rows - len(lines)) // 2
    left = (cols - width) // 2
    for r, line in enumerate(lines):
        for c, ch in enumerate(line):
            fg = bg = None
            if cells:
                _, fg, bg = cells[r][c]
                fg = rgb(fg) if fg else None
                bg = rgb(bg) if bg else None
            grid[top + r][left + c] = (ch, fg, bg)
    return grid


def ansi_art(cells):
    """[ch, fg, bg] rows as 24-bit ANSI text, for ttfx to keep the colours."""
    out = []
    for row in cells:
        line, last = "", None
        for ch, fg, bg in row:
            if (fg, bg) != last:
                line += "\x1b[0m"
                if fg:
                    line += "\x1b[38;2;%d;%d;%dm" % rgb(fg)
                if bg:
                    line += "\x1b[48;2;%d;%d;%dm" % rgb(bg)
                last = (fg, bg)
            line += ch
        out.append(line + "\x1b[0m")
    return "\n".join(out) + "\n"


# ------------------------------------------------------------------ cell drawing

# Block elements as (x0, y0, x1, y1, alpha) in fractions of a cell
BLOCKS = {
    "█": [(0, 0, 1, 1, 1)], "▀": [(0, 0, 1, .5, 1)], "▄": [(0, .5, 1, 1, 1)],
    "▌": [(0, 0, .5, 1, 1)], "▐": [(.5, 0, 1, 1, 1)],
    "░": [(0, 0, 1, 1, .25)], "▒": [(0, 0, 1, 1, .5)], "▓": [(0, 0, 1, 1, .75)],
    "▖": [(0, .5, .5, 1, 1)], "▗": [(.5, .5, 1, 1, 1)],
    "▘": [(0, 0, .5, .5, 1)], "▝": [(.5, 0, 1, .5, 1)],
    "▙": [(0, 0, .5, 1, 1), (.5, .5, 1, 1, 1)], "▟": [(.5, 0, 1, 1, 1), (0, .5, .5, 1, 1)],
    "▛": [(0, 0, 1, .5, 1), (0, .5, .5, 1, 1)], "▜": [(0, 0, 1, .5, 1), (.5, .5, 1, 1, 1)],
    "▚": [(0, 0, .5, .5, 1), (.5, .5, 1, 1, 1)], "▞": [(.5, 0, 1, .5, 1), (0, .5, .5, 1, 1)],
    "▁": [(0, .875, 1, 1, 1)], "▂": [(0, .75, 1, 1, 1)], "▃": [(0, .625, 1, 1, 1)],
    "▅": [(0, .375, 1, 1, 1)], "▆": [(0, .25, 1, 1, 1)], "▇": [(0, .125, 1, 1, 1)],
    "▔": [(0, 0, 1, .125, 1)], "▕": [(.875, 0, 1, 1, 1)], "▏": [(0, 0, .125, 1, 1)],
    "■": [(.125, .3125, .875, .6875, 1)], "▪": [(.25, .375, .75, .625, 1)],
}

# Box drawing: arms (up, right, down, left) with weight 1 light, 2 heavy, 3 double
L, H, D = 1, 2, 3
BOX = {
    "─": (0, L, 0, L), "│": (L, 0, L, 0), "┌": (0, L, L, 0), "┐": (0, 0, L, L),
    "└": (L, L, 0, 0), "┘": (L, 0, 0, L), "├": (L, L, L, 0), "┤": (L, 0, L, L),
    "┬": (0, L, L, L), "┴": (L, L, 0, L), "┼": (L, L, L, L),
    "╴": (0, 0, 0, L), "╵": (L, 0, 0, 0), "╶": (0, L, 0, 0), "╷": (0, 0, L, 0),
    "━": (0, H, 0, H), "┃": (H, 0, H, 0), "┏": (0, H, H, 0), "┓": (0, 0, H, H),
    "┗": (H, H, 0, 0), "┛": (H, 0, 0, H), "┣": (H, H, H, 0), "┫": (H, 0, H, H),
    "┳": (0, H, H, H), "┻": (H, H, 0, H), "╋": (H, H, H, H),
    "╸": (0, 0, 0, H), "╹": (H, 0, 0, 0), "╺": (0, H, 0, 0), "╻": (0, 0, H, 0),
    "═": (0, D, 0, D), "║": (D, 0, D, 0), "╔": (0, D, D, 0), "╗": (0, 0, D, D),
    "╚": (D, D, 0, 0), "╝": (D, 0, 0, D), "╠": (D, D, D, 0), "╣": (D, 0, D, D),
    "╦": (0, D, D, D), "╩": (D, D, 0, D), "╬": (D, D, D, D),
}
ROUNDED = {"╭": (1, 1), "╮": (-1, 1), "╰": (1, -1), "╯": (-1, -1)}  # (dx, dy) of the arms

# Braille dot bits -> (column, row) in the 2x4 dot grid
BRAILLE_DOTS = [(0x01, 0, 0), (0x02, 0, 1), (0x04, 0, 2), (0x08, 1, 0),
                (0x10, 1, 1), (0x20, 1, 2), (0x40, 0, 3), (0x80, 1, 3)]


class Renderer:
    def __init__(self, scale, default_fg):
        self.cw = max(2, round(BASE_W * scale))
        self.ch = self.cw * 2
        self.size = max(4, round(BASE_FONT * scale))
        self.default_fg = default_fg
        self.font = ImageFont.truetype(FONT, self.size)
        self.fallbacks = {}
        self.thin = max(1, round(self.cw / 8))

    def glyph_font(self, ch):
        """JetBrains Mono, or whichever installed font fontconfig finds for ch."""
        if ch in self.fallbacks:
            return self.fallbacks[ch]
        font = self.font
        try:
            # A missing glyph draws the font's .notdef box, not nothing
            if not hasattr(self, "_notdef"):
                self._notdef = bytes(self.font.getmask("\U0010fffd"))
            if bytes(self.font.getmask(ch)) == self._notdef and ch.strip():
                path = subprocess.run(["fc-match", "-f", "%{file}", f":charset={ord(ch):x}"],
                                      capture_output=True, text=True, timeout=5).stdout.strip()
                if path:
                    font = ImageFont.truetype(path, self.size)
        except (OSError, subprocess.SubprocessError):
            pass
        self.fallbacks[ch] = font
        return font

    def box(self, draw, x, y, arms, color):
        cw, chh, t = self.cw, self.ch, self.thin
        cx, cy = x + cw // 2, y + chh // 2
        g = max(1, cw // 4)                      # half gap between double lines
        up, right, down, left = arms

        def hline(x0, x1, yy, w):
            draw.rectangle([min(x0, x1), yy - w // 2, max(x0, x1), yy - w // 2 + w - 1], fill=color)

        def vline(y0, y1, xx, w):
            draw.rectangle([xx - w // 2, min(y0, y1), xx - w // 2 + w - 1, max(y0, y1)], fill=color)

        # Single and heavy arms run from the centre to the edge
        for weight, horizontal, sign in ((up, False, -1), (down, False, 1),
                                         (left, True, -1), (right, True, 1)):
            if weight in (L, H):
                w = t if weight == L else t * 2
                if horizontal:
                    hline(cx, x + cw - 1 if sign > 0 else x, cy, w)
                else:
                    vline(cy, y + chh - 1 if sign > 0 else y, cx, w)
        # Double arms are two lines. Each starts g short of the centre on the
        # side where a perpendicular arm joins (leaving the gap), and g past
        # it otherwise, so ═ ║ run through and ╔ ╠ ╬ get proper corners.
        for weight, sign in ((up, -1), (down, 1)):
            if weight == D:
                for side, joined in ((-1, left), (1, right)):
                    start = cy + sign * (g if joined else -g)
                    vline(start, y if sign < 0 else y + chh - 1, cx + side * g, t)
        for weight, sign in ((left, -1), (right, 1)):
            if weight == D:
                for side, joined in ((-1, up), (1, down)):
                    start = cx + sign * (g if joined else -g)
                    hline(start, x if sign < 0 else x + cw - 1, cy + side * g, t)

    def rounded(self, draw, x, y, dirs, color):
        cw, chh, t = self.cw, self.ch, self.thin
        cx, cy = x + cw // 2, y + chh // 2
        dx, dy = dirs
        r = cw // 2
        # Straight arm to the edge beyond the arc, then the quarter arc
        ex = cx + dx * r
        ey = cy + dy * r
        draw.rectangle([min(ex, x + cw - 1 if dx > 0 else x), cy - t // 2,
                        max(ex, x + cw - 1 if dx > 0 else x), cy - t // 2 + t - 1], fill=color)
        draw.rectangle([cx - t // 2, min(ey, y + chh - 1 if dy > 0 else y),
                        cx - t // 2 + t - 1, max(ey, y + chh - 1 if dy > 0 else y)], fill=color)
        bbox = [cx + (0 if dx > 0 else -2 * r), cy + (0 if dy > 0 else -2 * r),
                cx + (2 * r if dx > 0 else 0), cy + (2 * r if dy > 0 else 0)]
        start = {(1, 1): 180, (-1, 1): 270, (1, -1): 90, (-1, -1): 0}[dirs]
        draw.arc(bbox, start, start + 90, fill=color, width=t)

    def braille(self, draw, x, y, ch, color):
        bits = ord(ch) - 0x2800
        dot = max(1, self.cw // 4)
        for bit, col, row in BRAILLE_DOTS:
            if bits & bit:
                px = x + round((col + 0.5) * self.cw / 2) - dot // 2
                py = y + round((row + 0.5) * self.ch / 4) - dot // 2
                draw.rectangle([px, py, px + dot - 1, py + dot - 1], fill=color)

    def render(self, grid, cols, rows):
        cw, chh = self.cw, self.ch
        img = Image.new("RGBA", (cols * cw, rows * chh), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        for r, row in enumerate(grid):
            for c, (ch, fg, bg) in enumerate(row):
                x, y = c * cw, r * chh
                if bg:
                    draw.rectangle([x, y, x + cw - 1, y + chh - 1], fill=bg + (255,))
                if ch in (" ", " "):
                    continue
                color = (fg or self.default_fg) + (255,)
                if ch in BLOCKS:
                    for x0, y0, x1, y1, a in BLOCKS[ch]:
                        # Snap to whole pixels, keeping at least 1px so thin
                        # eighths (▏ ▕ ▁ ▔) survive small cell sizes
                        px0, py0 = round(x0 * cw), round(y0 * chh)
                        px1 = max(px0 + 1, round(x1 * cw))
                        py1 = max(py0 + 1, round(y1 * chh))
                        draw.rectangle([x + px0, y + py0, x + px1 - 1, y + py1 - 1],
                                       fill=color[:3] + (int(255 * a),))
                elif ch in BOX:
                    self.box(draw, x, y, BOX[ch], color)
                elif ch in ROUNDED:
                    self.rounded(draw, x, y, ROUNDED[ch], color)
                elif ch in ("╱", "╲", "╳"):
                    if ch in ("╱", "╳"):
                        draw.line([x, y + chh - 1, x + cw - 1, y], fill=color, width=self.thin)
                    if ch in ("╲", "╳"):
                        draw.line([x, y, x + cw - 1, y + chh - 1], fill=color, width=self.thin)
                elif 0x2800 <= ord(ch) <= 0x28ff:
                    self.braille(draw, x, y, ch, color)
                else:
                    draw.text((x + cw / 2, y + chh / 2), ch, font=self.glyph_font(ch),
                              fill=color, anchor="mm")
        return img


def save(img, path):
    # Palette PNGs keep the initramfs small
    img.quantize(colors=64, method=Image.Quantize.FASTOCTREE).save(path, optimize=True)


def recolor(src, colour, dest):
    alpha = Image.open(src).convert("RGBA").getchannel("A")
    img = Image.new("RGBA", alpha.size, rgb(colour) + (255,))
    img.putalpha(alpha)
    img.save(dest, optimize=True)


def grid_html(grid, default_fg):
    """One frame as Qt rich text: a span per colour run, &nbsp; for spaces."""
    lines = []
    for row in grid:
        html, run, key = "", "", None
        for ch, fg, bg in row:
            k = (short(fg or default_fg), short(bg) if bg else None) if ch.strip() or bg else (None, None)
            if k != key and run:
                html += span(run, key)
                run = ""
            key = k
            run += HTML_ESCAPES.get(ch, ch)
        if run:
            html += span(run, key)
        lines.append(html)
    return "<br>".join(lines)


HTML_ESCAPES = {"&": "&amp;", "<": "&lt;", ">": "&gt;", " ": "&nbsp;", "\u00a0": "&nbsp;"}


def short(col):
    """#rgb: 4 bits a channel is plenty for a preview and merges more runs."""
    return "#" + "".join("%x" % min(15, round(v / 17)) for v in col)


def span(text, key):
    fg, bg = key
    if not fg and not bg:
        return text
    style = (f"color:{fg};" if fg else "") + (f"background-color:{bg};" if bg else "")
    return f'<span style="{style}">{text}</span>'


def effect_frames(name, args, logo, lines, cells, cols, rows, seed, bg, fg):
    """One intro's frames: omascii's own effects are drawn here, the rest by ttfx."""
    if name in NATIVE_EFFECTS:
        pal = {k: rgb(v) for k, v in load_palette()[0].items()}
        return native.frames(name, text_grid(lines, cols, rows, cells), rgb(fg), rgb(bg), pal, seed)
    return parse_frames(run_ttfx(logo, name, args, cols, rows, seed, bg, fg, keep_colors=bool(cells)), cols, rows)


def preview_json(effect, effects, logo, lines, cells, cols, rows, opts, bg, fg):
    """Frames of one intro as rich text, thinned to at most --max-frames,
    then the hold highlight, for the shell to play at 50 fps."""
    default = rgb(fg)
    if effect == "static":
        frames, hold = [text_grid(lines, cols, rows, cells)], 0
    else:
        if effect not in effects:
            sys.exit(f"build.py: unknown effect {effect}")
        args, step = effects[effect]
        raw = effect_frames(effect, args, logo, lines, cells, cols, rows, opts.seed, bg, fg)
        if not raw:
            sys.exit(f"build.py: ttfx {effect} produced no frames")
        frames = raw[::step]
        if frames[-1] is not raw[-1]:
            frames.append(raw[-1])
        limit = opts.max_frames
        if limit and len(frames) > limit:
            idx = [round(i * (len(frames) - 1) / (limit - 1)) for i in range(limit)]
            frames = [frames[i] for i in idx]
        hold = len(frames)
        held = parse_frames(run_ttfx(logo, HOLD_EFFECT, ["--highlight-width", "10"], cols, rows,
                                     opts.seed, bg, fg, keep_colors=bool(cells)), cols, rows)[::2]
        frames += held[::max(1, len(held) // 60)]
    json.dump({"effect": effect, "cols": cols, "rows": rows, "background": bg, "foreground": fg,
               "fps": 50, "hold": hold, "frames": [grid_html(g, default) for g in frames]},
              sys.stdout, separators=(",", ":"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--logo", required=True, help="text file with the ASCII art")
    ap.add_argument("--out", required=True, help="theme directory to write")
    ap.add_argument("--name", default="omascii")
    ap.add_argument("--install-dir", default=None, help="where the theme will be installed")
    ap.add_argument("--style", choices=["animated", "static"], default="animated")
    ap.add_argument("--effects", default=",".join(EFFECT_NAMES))
    ap.add_argument("--color", default="accent", help="palette name or #rrggbb for the art")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--max-frames", type=int, default=200,
                    help="cap per intro effect (plymouth runs at 50 fps)")
    ap.add_argument("--scale", default="auto", help="cell scale (1 = 8x16 px cells) or auto")
    ap.add_argument("--screen", default=None, help="WxH to fit, default: largest monitor")
    ap.add_argument("--cells", default=None,
                    help="JSON [ch, fg, bg] rows: the art with its own colours (TheDraw colour fonts)")
    ap.add_argument("--preview-json", default=None, metavar="EFFECT",
                    help="print one effect's frames as rich text JSON (for the shell's live preview) "
                         "instead of building the theme; 'static' for the still")
    opts = ap.parse_args()

    pal, source = load_palette()
    bg = pal["background"]
    if re.fullmatch(r"#?[0-9a-fA-F]{6}", opts.color):
        fg = opts.color.lstrip("#").lower()
    else:
        fg = pal.get(opts.color) or pal["accent"]

    def c(*names):
        """Palette colours by name, falling back to the art colour."""
        return [pal.get(n, fg) for n in names]

    # effect name -> (extra ttfx args, keep every Nth frame)
    effects = {
        "decrypt":   (["--typing-speed", "8",
                       "--ciphertext-colors", *c("primary_container", "cyan", "bright_cyan")], 2),
        "beams":     (["--beam-gradient-stops", *c("bright_foreground", "bright_cyan", "primary_container")], 2),
        "burn":      (["--starting-color", *c("muted"),
                       "--burn-colors", *c("bright_foreground", "bright_yellow", "orange", "red", "brown")], 2),
        "slide":     (["--merge"], 1),
        "rain":      (["--rain-colors", *c("selection", "primary_container", "cyan", "accent",
                                           "bright_cyan", "primary", "light_foreground", "bright_foreground")], 2),
        "laseretch": (["--laser-gradient-stops", *c("bright_foreground", "blue"),
                       "--cool-gradient-stops", *c("bright_yellow", "accent"),
                       "--spark-gradient-stops", *c("bright_foreground", "bright_yellow", "orange", "darker_background")], 2),
        "waves":     (["--wave-gradient-stops", *c("bright_cyan", "accent", "blue", "accent", "bright_cyan")], 2),
        "middleout": (["--starting-color", *c("bright_foreground")], 1),
        "vhstape":   (["--glitch-line-colors", *c("bright_foreground", "red", "green", "blue", "bright_foreground"),
                       "--glitch-wave-colors", *c("bright_foreground", "red", "green", "blue", "bright_foreground"),
                       "--noise-colors", *c("lighter_background", "surface_bright", "muted",
                                            "dark_foreground", "light_foreground", "bright_foreground")], 2),
        "sweep":     ([], 1),
        "unstable":  (["--unstable-color", *c("orange")], 2),
        # The screensaver's own, and screensaver-style variants
        "matrix":    (["--rain-time", "3"], 2),
        "synthgrid": (["--grid-gradient-stops", *c("selection", "accent"),
                       "--text-gradient-stops", fg], 2),
        "thunderstorm": (["--storm-time", "3"], 2),
        "colorshift": (["--no-loop", "--cycles", "1"], 1),
        "highlight": (["--highlight-width", "10"], 1),
        "matrix-theme": (["--rain-time", "3", "--highlight-color", *c("bright_foreground"),
                          "--rain-color-gradient", *c("accent", "primary_container", "selection")], 2),
        "matrix-binary": (["--rain-time", "3", "--rain-symbols", "0", "1"], 2),
        "synthgrid-neon": (["--grid-gradient-stops", "ff2a6d", "d300c5", "05d9e8",
                            "--text-gradient-stops", "fdf500", fg], 2),
        "thunderstorm-violet": (["--storm-time", "3", "--lightning-color", "c9a0ff",
                                 "--glowing-text-color", "e0c3ff", "--spark-glow-color", "b16cea"], 2),
        "colorshift-rainbow": (["--no-loop", "--cycles", "2", "--gradient-stops",
                                *c("red", "yellow", "green", "cyan", "blue", "magenta")], 1),
        "fireworks-neon": (["--firework-colors", "39ff14", "00f0ff", "ff00e6", "fffb00", "ff6b35"], 2),
        "burn-inferno": (["--starting-color", "3d0c11",
                          "--burn-colors", "ffffff", "fff200", "ff9a00", "ff4d00", "c81d25", "3d0c11"], 2),
        "beams-aurora": (["--beam-gradient-stops", "ffffff", "00ff87", "60efff", "0061ff", "b16cea"], 2),
        "rain-storm": (["--rain-symbols", "│", "╎", "┆", ":", "'", "--movement-speed", "0.4-0.9",
                        "--rain-colors", *c("blue", "cyan", "bright_blue", "bright_cyan", "light_foreground")], 2),
        "decrypt-green": (["--typing-speed", "8", "--ciphertext-colors", "008000", "00cb00", "00ff00"], 2),
    }
    for name in EXTRA_EFFECTS + NATIVE_EFFECTS:
        effects.setdefault(name, ([], 1 if name in NATIVE_EFFECTS else 2))

    cells = json.loads(Path(opts.cells).read_text()) if opts.cells else None
    if cells:
        # Rows already trimmed to the ink; keep their full width so the
        # coloured backgrounds line up
        lines = ["".join(c[0] for c in row) for row in cells]
    else:
        lines = [l.rstrip() for l in Path(opts.logo).read_text().replace("\u00a0", " ").rstrip().split("\n")]
        while lines and not lines[0]:
            lines.pop(0)
    if not lines:
        sys.exit("build.py: the art is empty")
    # Trailing spaces would widen the text block and push the logo off-centre
    logo = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
    logo.write(ansi_art(cells) if cells else "\n".join(lines) + "\n")
    logo.close()

    text_cols = max(len(l) for l in lines)
    cols, rows = text_cols + 2 * MARGIN_X, len(lines) + 2 * MARGIN_Y
    screen = tuple(int(v) for v in opts.screen.lower().split("x")) if opts.screen else screen_size()
    scale = pick_scale(cols, rows, screen, opts.scale)
    renderer = Renderer(scale, rgb(fg))

    if opts.preview_json:
        preview_json(opts.preview_json, effects, logo.name, lines, cells, cols, rows, opts, bg, fg)
        Path(logo.name).unlink()
        return

    out = Path(opts.out)
    if out.exists():
        shutil.rmtree(out)
    (out / "frames").mkdir(parents=True)
    install_dir = opts.install_dir or f"/usr/share/plymouth/themes/{opts.name}"

    print(f"palette: bg #{bg} art " + ("in per-cell colours" if cells else f"#{fg}")
          + (f" from {source}" if source else " (stock Omarchy)"), file=sys.stderr)
    print(f"art {text_cols}x{len(lines)} chars, canvas {cols}x{rows} cells at "
          f"{renderer.cw}x{renderer.ch} px -> {cols * renderer.cw}x{rows * renderer.ch} px "
          f"(screen {screen[0]}x{screen[1]})", file=sys.stderr)

    def build_effect(name, args, step, outdir, limit):
        frames = effect_frames(name, args, logo.name, lines, cells, cols, rows, opts.seed, bg, fg)
        if not frames:
            raise SystemExit(f"build.py: {name} produced no frames")
        picked = frames[::step]
        if picked[-1] is not frames[-1]:
            picked.append(frames[-1])
        if limit and len(picked) > limit:
            # Too long: thin out evenly but always keep the final frame
            idx = [round(i * (len(picked) - 1) / (limit - 1)) for i in range(limit)]
            picked = [picked[i] for i in idx]
        outdir.mkdir(parents=True, exist_ok=True)
        for i, grid in enumerate(picked):
            save(renderer.render(grid, cols, rows), outdir / f"{i}.png")
        print(f"  {name:10s} {len(frames):4d} raw -> {len(picked):4d} frames", file=sys.stderr)
        return len(picked)

    names, counts, hold = [], [], 0
    if opts.style == "animated":
        names = [e.strip() for e in opts.effects.split(",") if e.strip()]
        for name in names:
            if name not in effects:
                sys.exit(f"build.py: unknown effect {name}")
        for i, name in enumerate(names):
            args, step = effects[name]
            counts.append(build_effect(name, args, step, out / "frames" / str(i), opts.max_frames))
        hold = build_effect(HOLD_EFFECT, ["--highlight-width", "10"], 2, out / "frames" / "hold", 0)

    # Static logo: the art in its final colour, used for the static style
    save(renderer.render(text_grid(lines, cols, rows, cells), cols, rows), out / "logo.png")

    # Frame table the Plymouth script reads (it has no directory listing
    # and no includes, so it is spliced into the script)
    table = "\n".join(f"global.effect_frames[{i}] = {n};  # {name}"
                      for i, (name, n) in enumerate(zip(names, counts)))
    frames = (f"global.effect_count = {len(names)};\n" + (table + "\n" if table else "")
              + f"global.hold_frames = {hold};")
    script = (ASSETS / "omascii.script.in").read_text()
    bg_rgb = ", ".join(f"{v / 255:.3f}" for v in rgb(bg))
    script = (script.replace("#@FRAMES@", frames)
              .replace("#@MARGIN@", str(MARGIN_Y * renderer.ch))
              .replace("#@BG@", bg_rgb))
    (out / f"{opts.name}.script").write_text(script)

    # The dialogue assets are single-colour silhouettes: repaint them in the palette
    for asset, colour in (("entry.png", "foreground"), ("lock.png", "foreground"),
                          ("bullet.png", "foreground"), ("progress_box.png", "lighter_background"),
                          ("progress_bar.png", "accent")):
        recolor(ASSETS / asset, pal.get(colour, fg), out / asset)

    (out / f"{opts.name}.plymouth").write_text(f"""[Plymouth Theme]
Name=omascii
Description=FIGlet ASCII art boot splash made with omascii.
ModuleName=script

[script]
ImageDir={install_dir}
ScriptFile={install_dir}/{opts.name}.script
ConsoleLogBackgroundColor=0x{bg}
MonospaceFont=Cantarell 11
Font=Cantarell 11
""")
    Path(logo.name).unlink()
    size = sum(f.stat().st_size for f in out.rglob("*") if f.is_file())
    print(f"theme written to {out} ({size / 1e6:.1f} MB)", file=sys.stderr)
    if size > 40e6:
        print("warning: that is a lot of initramfs; consider fewer --effects or a lower "
              "--max-frames", file=sys.stderr)


if __name__ == "__main__":
    main()
