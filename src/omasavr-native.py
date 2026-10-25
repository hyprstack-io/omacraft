"""One of omascii's own effects (ripple, starfield, ...) played full screen in
the terminal, for Screensaver's screensaver. omascii draws the frames (its
lib/effects.py); this sizes the art to the terminal, then prints them.

Usage: omasavr-native.py EFFECT ART_FILE OMASCII_LIB_DIR
"""

import os
import random
import re
import sys
import time
import tomllib
from pathlib import Path

COLORS = Path.home() / ".local/state/omarchy/current/theme/colors.toml"
FPS = 50


def palette():
    try:
        data = tomllib.loads(COLORS.read_text())
    except (OSError, tomllib.TOMLDecodeError):
        return {}
    return {k: tuple(int(v.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
            for k, v in data.items() if isinstance(v, str) and re.fullmatch(r"#?[0-9a-fA-F]{6}", v)}


def canvas(lines, cols, rows):
    """The art centred on the screen, in the art colour (None)."""
    grid = [[(" ", None, None) for _ in range(cols)] for _ in range(rows)]
    lines = [line[:cols] for line in lines[:rows]]
    width = max(len(line) for line in lines)
    top, left = (rows - len(lines)) // 2, (cols - width) // 2
    for r, line in enumerate(lines):
        for c, ch in enumerate(line):
            grid[top + r][left + c] = (ch, None, None)
    return grid


def ansi(grid):
    out = []
    for row in grid:
        line, last = [], None
        for ch, fg, bg in row:
            if (fg, bg) != last:
                line.append("\x1b[0m"
                            + (f"\x1b[38;2;{fg[0]};{fg[1]};{fg[2]}m" if fg else "")
                            + (f"\x1b[48;2;{bg[0]};{bg[1]};{bg[2]}m" if bg else ""))
                last = (fg, bg)
            line.append(ch)
        out.append("".join(line))
    return "\x1b[0m" + "\r\n".join(out) + "\x1b[0m"


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__.strip().splitlines()[-1])
    effect, art, lib = sys.argv[1:]
    sys.path.insert(0, lib)
    import effects as native  # omascii's

    if effect not in native.NATIVE_EFFECTS:
        sys.exit(f"omasavr-native: unknown effect {effect}")
    lines = [line.rstrip() for line in Path(art).read_text().replace(" ", " ").rstrip().split("\n")]
    while lines and not lines[0].strip():
        lines.pop(0)
    if not lines:
        sys.exit("omasavr-native: the art is empty")

    cols, rows = os.get_terminal_size()
    pal = palette()
    fg = pal.get("foreground", (255, 255, 255))
    frames = native.frames(effect, canvas(lines, cols, rows), fg, (0, 0, 0), pal, random.randrange(1 << 30))

    out = sys.stdout
    out.write("\x1b[?25l\x1b[2J")
    for grid in frames:
        start = time.monotonic()
        out.write("\x1b[H" + ansi(grid))
        out.flush()
        time.sleep(max(0.0, 1 / FPS - (time.monotonic() - start)))


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
