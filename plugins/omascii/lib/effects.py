"""omascii's own intro effects, drawn in Python rather than by ttfx.

Each effect returns a list of frames in the same shape parse_frames() gives
build.py: rows of (char, fg, bg) cells, colours as (r, g, b) tuples or None.
The last frame is always the art at rest, so the hold highlight that follows
starts from the same picture every ttfx intro ends on.

They are seeded, so a boot plays the same frames as the preview did.
"""

import math
import random

NATIVE_EFFECTS = ["ripple", "starfield", "neon", "tetris", "spiral", "crt", "plasma", "tunein", "helix"]

NOISE = "░▒▓▚▞▖▗▘▝"
STARS = "·.+*✦"


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


class Canvas:
    """The art at rest, and what every effect needs to know about it."""

    def __init__(self, final, fg, bg, pal):
        self.final = final                       # text_grid(): the art centred, colours or None
        self.rows = len(final)
        self.cols = len(final[0]) if final else 0
        self.fg = fg                             # default art colour (r, g, b)
        self.bg = bg
        self.pal = pal                           # theme colours by name, as (r, g, b)
        self.ink = [(r, c) for r in range(self.rows) for c in range(self.cols)
                    if final[r][c][0] != " " or final[r][c][2]]
        rs = [r for r, _ in self.ink] or [0]
        cs = [c for _, c in self.ink] or [0]
        self.top, self.bottom, self.left, self.right = min(rs), max(rs), min(cs), max(cs)
        self.cy = (self.top + self.bottom) / 2
        self.cx = (self.left + self.right) / 2

    def blank(self):
        return [[(" ", None, None) for _ in range(self.cols)] for _ in range(self.rows)]

    def colour(self, r, c):
        """The colour a cell settles on."""
        return self.final[r][c][1] or self.fg

    def put(self, grid, r, c, ch=None, fg=None, bg=None):
        """Draw the art's own cell (or ch) at r, c in fg."""
        if 0 <= r < self.rows and 0 <= c < self.cols:
            own, _, own_bg = self.final[r][c]
            grid[r][c] = (ch if ch is not None else own, fg, bg if bg is not None else own_bg)

    def settle(self, grid, r, c, t, start):
        """The cell easing from start to its own colour, t 0..1."""
        self.put(grid, r, c, fg=mix(start, self.colour(r, c), smooth(t)))

    def distance(self, r, c):
        """From the centre of the art, with rows counted double (cells are tall)."""
        return math.hypot(c - self.cx, (r - self.cy) * 2)

    def bright(self, *names):
        return [self.pal[n] for n in names if n in self.pal] or [mix(self.fg, (255, 255, 255), 0.5)]

    def rest(self):
        grid = self.blank()
        for r, c in self.ink:
            self.put(grid, r, c, fg=self.colour(r, c))
        return grid


def ripple(cv, rnd):
    """Rings spread from the centre; each one leaves the art a little more lit."""
    far = max([cv.distance(r, c) for r, c in cv.ink] or [1]) + 6
    white = cv.bright("bright_foreground")[0]
    ring = cv.pal.get("accent", cv.fg)
    frames, n = [], 90
    for f in range(n):
        radius = far * smooth(f / (n * 0.75))
        grid = cv.blank()
        for r in range(cv.rows):
            for c in range(cv.cols):
                d = cv.distance(r, c)
                behind = radius - d
                if (r, c) in cv.inkset:
                    if behind >= 0:
                        cv.settle(grid, r, c, behind / 10, white)
                elif abs(behind) < 0.7 and f < n - 8:
                    grid[r][c] = ("·", mix(ring, cv.bg, 0.3), None)
                elif abs(behind - 5) < 0.5 and f < n - 12:
                    grid[r][c] = ("·", mix(ring, cv.bg, 0.7), None)
        frames.append(grid)
    return frames


def starfield(cv, rnd):
    """Warp speed out of the centre; the art fades in as the stars thin out."""
    n = 100
    stars = []
    for _ in range(160):
        a = rnd.uniform(0, 2 * math.pi)
        stars.append((a, rnd.uniform(0.6, 1.6), rnd.uniform(0, n * 0.7)))
    appear = {p: rnd.uniform(n * 0.3, n * 0.75) for p in cv.ink}
    reach = math.hypot(cv.cols, cv.rows * 2) / 2
    frames = []
    for f in range(n):
        grid = cv.blank()
        for a, speed, born in stars:
            age = f - born
            if age < 0 or f > n - 10:
                continue
            dist = (age * speed * 0.18) ** 1.6
            if dist > reach:
                continue
            r = round(cv.rows / 2 + math.sin(a) * dist / 2)
            c = round(cv.cols / 2 + math.cos(a) * dist)
            if 0 <= r < cv.rows and 0 <= c < cv.cols:
                t = dist / reach
                grid[r][c] = (STARS[min(len(STARS) - 1, int(t * len(STARS)))], mix(cv.bg, (255, 255, 255), 0.35 + 0.65 * t), None)
        for p in cv.ink:
            t = (f - appear[p]) / 18
            if t > 0:
                cv.settle(grid, p[0], p[1], t, mix(cv.bg, cv.colour(*p), 0.15))
        frames.append(grid)
    return frames


def neon(cv, rnd):
    """A neon sign warming up: letters stutter on, then glow and settle."""
    n = 96
    groups = {}
    for r, c in cv.ink:
        groups.setdefault(c // 5, []).append((r, c))
    schedule = {}
    for key in groups:
        lit_from = rnd.uniform(10, 55)
        schedule[key] = [f >= lit_from or rnd.random() < (f / 60) ** 3 for f in range(n)]
    frames = []
    for f in range(n):
        grid = cv.blank()
        glow = 1 - smooth((f - 62) / 30)
        for key, cells in groups.items():
            on = schedule[key][f] or f >= 60
            for r, c in cells:
                own = cv.colour(r, c)
                if on:
                    cv.put(grid, r, c, fg=mix(own, (255, 255, 255), 0.45 * glow))
                else:
                    cv.put(grid, r, c, fg=mix(own, cv.bg, 0.82))
        frames.append(grid)
    return frames


def tetris(cv, rnd):
    """Blocks drop in, bottom row first, and lock into the letters."""
    palette = cv.bright("red", "yellow", "green", "cyan", "blue", "magenta")
    order = sorted(cv.ink, key=lambda p: (-p[0], p[1]))
    landed_rows = sorted({r for r, _ in cv.ink}, reverse=True)
    row_rank = {r: i for i, r in enumerate(landed_rows)}
    drops = {}
    for r, c in order:
        start = row_rank[r] * 6 + rnd.uniform(0, 8)
        drops[(r, c)] = (start, palette[(c // 4) % len(palette)])
    gravity = 0.24
    last = max(s + math.sqrt(2 * (r + 1) / gravity) for (r, _), (s, _) in drops.items()) if drops else 0
    n = int(last) + 14
    frames = []
    for f in range(n):
        grid = cv.blank()
        for (r, c), (start, block) in drops.items():
            dt = f - start
            if dt < 0:
                continue
            fall = 0.5 * gravity * dt * dt
            if fall < r + 1:
                y = int(fall) - 1
                if 0 <= y < r:
                    grid[y][c] = ("█", block, None)
                continue
            since = dt - math.sqrt(2 * (r + 1) / gravity)
            if since < 4:
                grid[r][c] = ("█", block, None)
            else:
                cv.settle(grid, r, c, (since - 4) / 6, block)
        frames.append(grid)
    return frames


def spiral(cv, rnd):
    """The art is drawn in along a spiral, from the outside in."""
    far = max([cv.distance(r, c) for r, c in cv.ink] or [1]) or 1

    def key(p):
        r, c = p
        turn = (math.atan2((r - cv.cy) * 2, c - cv.cx) / (2 * math.pi)) % 1
        return (1 - cv.distance(r, c) / far) * 3 + turn

    order = sorted(cv.ink, key=key)
    n = 90
    head = cv.bright("bright_foreground", "accent")[0]
    reveal = {p: i / max(1, len(order) - 1) * (n - 20) for i, p in enumerate(order)}
    frames = []
    for f in range(n):
        grid = cv.blank()
        for p, at in reveal.items():
            if f >= at:
                cv.settle(grid, p[0], p[1], (f - at) / 10, head)
        frames.append(grid)
    return frames


def crt(cv, rnd):
    """An old monitor powering on: a line, then the picture, then the scanlines fade."""
    n = 76
    white = (255, 255, 255)
    mid = cv.rows / 2
    frames = []
    for f in range(n):
        grid = cv.blank()
        if f < 12:
            half = cv.cols / 2 * smooth(f / 11)
            for c in range(cv.cols):
                if abs(c - cv.cols / 2) <= half:
                    grid[int(mid)][c] = ("━", mix(white, cv.bg, abs(c - cv.cols / 2) / max(1, half) * 0.6), None)
        else:
            opened = mid * smooth((f - 12) / 16)
            settle = smooth((f - 34) / 36)
            noise = max(0.0, 0.18 * (1 - smooth((f - 20) / 30)))
            for r in range(cv.rows):
                if abs(r - mid) > opened + 0.5:
                    continue
                scan = 0.35 * (1 - settle) if r % 2 else 0
                for c in range(cv.cols):
                    if (r, c) in cv.inkset:
                        own = cv.colour(r, c)
                        lit = mix(mix(white, own, 0.35 + 0.65 * settle), cv.bg, scan)
                        cv.put(grid, r, c, fg=lit)
                    elif rnd.random() < noise:
                        grid[r][c] = (rnd.choice(NOISE), mix(cv.bg, white, rnd.uniform(0.1, 0.35)), None)
        frames.append(grid)
    return frames


def plasma(cv, rnd):
    """A plasma field washes through the letters, then drains to their colours."""
    n = 110
    stops = cv.bright("magenta", "blue", "cyan", "green", "yellow", "red")
    phase = rnd.uniform(0, 6)

    def field(r, c, t):
        v = (math.sin(c * 0.21 + t) + math.sin(r * 0.43 + t * 1.3)
             + math.sin((c + r * 2) * 0.13 + t * 0.7) + math.sin(math.hypot(c - cv.cx, r * 2 - cv.cy * 2) * 0.18 - t))
        x = (v + 4) / 8 * (len(stops) - 1)
        i = min(len(stops) - 2, int(x))
        return mix(stops[i], stops[i + 1], x - i)

    frames = []
    for f in range(n):
        grid = cv.blank()
        t = phase + f * 0.12
        fade_in = smooth(f / 14)
        drain = smooth((f - 60) / 46)
        for r, c in cv.ink:
            col = mix(cv.bg, field(r, c, t), fade_in)
            cv.put(grid, r, c, fg=mix(col, cv.colour(r, c), drain))
        frames.append(grid)
    return frames


def tunein(cv, rnd):
    """Television static that tunes in to the art."""
    n = 84
    tune = {p: rnd.uniform(14, 62) for p in cv.ink}
    frames = []
    for f in range(n):
        grid = cv.blank()
        density = 0.55 * (1 - smooth((f - 8) / 50))
        for r in range(max(0, cv.top - 2), min(cv.rows, cv.bottom + 3)):
            for c in range(max(0, cv.left - 4), min(cv.cols, cv.right + 5)):
                p = (r, c)
                if p in tune and f >= tune[p]:
                    cv.settle(grid, r, c, (f - tune[p]) / 8, (255, 255, 255))
                elif rnd.random() < (0.85 if p in tune else density):
                    grid[r][c] = (rnd.choice(NOISE), mix(cv.bg, (255, 255, 255), rnd.uniform(0.15, 0.55)), None)
        frames.append(grid)
    return frames


def helix(cv, rnd):
    """A double helix sweeps across and leaves the art behind it."""
    n = 100
    a, b = cv.bright("accent", "cyan")[0], cv.bright("magenta", "blue")[-1]
    span = cv.right - cv.left + 24
    amp = max(1.0, (cv.bottom - cv.top) / 2 + 1)
    frames = []
    for f in range(n):
        grid = cv.blank()
        front = cv.left - 12 + span * smooth(f / (n - 18))
        fade = 1 - smooth((f - (n - 16)) / 14)
        for r, c in cv.ink:
            if c < front - 3:
                cv.settle(grid, r, c, (front - 3 - c) / 10, (255, 255, 255))
        for c in range(int(front - 10), int(front) + 1):
            if not 0 <= c < cv.cols or fade <= 0:
                continue
            angle = c * 0.45 - f * 0.25
            for strand, colour, sign in ((0, a, 1), (1, b, -1)):
                r = round(cv.cy + sign * math.sin(angle) * amp)
                depth = math.cos(angle) * sign
                ch = "●" if depth > 0.3 else ("•" if depth > -0.3 else "·")
                if 0 <= r < cv.rows:
                    grid[r][c] = (ch, mix(cv.bg, colour, fade * (0.55 + 0.45 * (depth + 1) / 2)), None)
            if c % 3 == 0:
                lo, hi = sorted((round(cv.cy + math.sin(angle) * amp), round(cv.cy - math.sin(angle) * amp)))
                for r in range(lo + 1, hi):
                    if 0 <= r < cv.rows and grid[r][c][0] == " ":
                        grid[r][c] = ("│", mix(cv.bg, a, 0.4 * fade), None)
        frames.append(grid)
    return frames


EFFECTS = {"ripple": ripple, "starfield": starfield, "neon": neon, "tetris": tetris, "spiral": spiral,
           "crt": crt, "plasma": plasma, "tunein": tunein, "helix": helix}


def frames(name, final, fg, bg, pal, seed):
    """Frames of one of omascii's own effects, ending on the art at rest."""
    cv = Canvas(final, fg, bg, pal)
    cv.inkset = set(cv.ink)
    out = EFFECTS[name](cv, random.Random(seed))
    out.append(cv.rest())
    return out
