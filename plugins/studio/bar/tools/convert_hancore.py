"""Convert HANCORE-linux/waybar-themes (MIT) into omabar16 layout and theme presets.

Usage: python3 -I convert_hancore.py <repo-dir> <out.json>
Reads only; prints a summary. Untrusted input: parsed as text, nothing executed.
"""
import json, re, sys
from pathlib import Path

repo, out_path = Path(sys.argv[1]), Path(sys.argv[2])

MODULE_MAP = {
    "custom/omarchy": "omarchy.menu", "custom/logo": "omarchy.menu", "custom/launcher": "omarchy.menu",
    "hyprland/workspaces": "omarchy.workspaces",
    "hyprland/window": "omarchy.active-window", "custom/windowpill": "omarchy.active-window",
    "mpris": "omarchy.media", "custom/mpris": "omarchy.media", "custom/cava": "omarchy.media",
    "clock": "omarchy.clock", "custom/clock": "omarchy.clock",
    "tray": "omarchy.tray", "group/tray-expander": "omarchy.tray", "group/tray-expander2": "omarchy.tray",
    "network": "omarchy.network", "bluetooth": "omarchy.bluetooth",
    "pulseaudio": "omarchy.audio", "wireplumber": "omarchy.audio",
    "pulseaudio#microphone": "omarchy.microphone",
    "battery": "omarchy.power", "power-profiles-daemon": "omarchy.power", "custom/power": "omarchy.power",
    "backlight": "omarchy.monitor",
    "custom/update": "omarchy.system-update", "custom/updatespacman": "omarchy.system-update",
    "custom/screenrecording-indicator": "omarchy.indicators", "custom/idle-indicator": "omarchy.indicators",
    "custom/notification-silencing-indicator": "omarchy.indicators", "idle_inhibitor": "omarchy.indicators",
    "custom/voxtype": "omarchy.indicators",
    "custom/weather": "omarchy.weather", "hyprland/language": "omarchy.keyboard-layout",
}
# Waybar modules with no Omarchy widget (system stats, separators, theme buttons).
DROPPED = ("cpu", "memory", "temperature", "disk", "custom/gpu", "custom/separator", "custom/expand",
           "custom/split", "custom/omarchy-theme", "custom/colorpicker", "custom/spacer")


def strip_jsonc(text):
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n: out.append(text[i + 1]); i += 2; continue
            if c == '"': in_str = False
            i += 1; continue
        if c == '"': in_str = True; out.append(c); i += 1; continue
        if text.startswith("//", i):
            while i < n and text[i] != "\n": i += 1
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2); i = n if j < 0 else j + 2; continue
        out.append(c); i += 1
    s = "".join(out)
    return re.sub(r",(\s*[}\]])", r"\1", s)


def load_config(path):
    try:
        # raw_decode tolerates trailing junk after the config object.
        data, _ = json.JSONDecoder().raw_decode(strip_jsonc(path.read_text(errors="replace")).lstrip())
    except Exception as e:
        return None, str(e)
    if isinstance(data, list): data = data[0] if data else {}
    return data, None


def expand(cfg, names, seen=None):
    seen = seen or set()
    out = []
    for name in names or []:
        if not isinstance(name, str): continue
        if name.startswith("group/") and name not in MODULE_MAP:
            if name in seen: continue
            mods = (cfg.get(name) or {}).get("modules") or []
            out += expand(cfg, mods, seen | {name})
        else:
            out.append(name)
    return out


def map_lane(names, used, dropped):
    lane = []
    for name in names:
        base = name.split("#")[0] if name not in MODULE_MAP else name
        wid = MODULE_MAP.get(name) or MODULE_MAP.get(base)
        if not wid:
            if not any(name.startswith(d) for d in DROPPED): dropped.add(name)
            continue
        if wid in used: continue
        used.add(wid); lane.append(wid)
    return lane


# ---------------------------------------------------------------- CSS
HEX = re.compile(r"#([0-9a-fA-F]{3,8})\b")

def parse_css(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    defs = {m.group(1): m.group(2).strip() for m in re.finditer(r"@define-color\s+([\w-]+)\s+([^;]+);", text)}
    rules = []
    for m in re.finditer(r"([^{}@]+)\{([^{}]*)\}", text):
        sels = [s.strip() for s in m.group(1).split(",") if s.strip()]
        props = {}
        for decl in m.group(2).split(";"):
            if ":" in decl:
                k, v = decl.split(":", 1); props[k.strip().lower()] = v.strip()
        rules.append((sels, props))
    return defs, rules


THEME_VARS = {"background", "foreground", "base", "text", "bg", "fg", "accent", "color0", "color15"}

def resolve(value, defs, depth=0):
    """'#hex', 'theme:<name>' for Omarchy theme colours, 'transparent', or None."""
    if not value: return None
    v = value.strip().lower().replace("!important", "").strip()
    if v in ("transparent", "none", "rgba(0,0,0,0)", "rgba(0, 0, 0, 0)"): return "transparent"
    m = re.match(r"alpha\(\s*(@?[\w#-]+)\s*,\s*([\d.]+)\s*\)", v)
    if m:
        if float(m.group(2)) < 0.2: return "transparent"
        return resolve(m.group(1), defs, depth + 1)
    m = re.match(r"linear-gradient\([^,]*,\s*(@?[#\w-]+)", v)
    if m: return resolve(m.group(1), defs, depth + 1)
    if v.startswith("@"):
        name = v[1:].split()[0]
        if name in defs and depth < 6: return resolve(defs[name], defs, depth + 1)
        return "theme:" + name
    m = re.match(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)", v)
    if m:
        if m.group(4) is not None and float(m.group(4)) < 0.2: return "transparent"
        return "#%02x%02x%02x" % tuple(int(m.group(i)) for i in (1, 2, 3))
    m = HEX.search(v)
    if m:
        h = m.group(1)
        if len(h) == 3: h = "".join(c * 2 for c in h)
        if len(h) == 8 and int(h[6:8], 16) < 50: return "transparent"
        return "#" + h[:6].lower()
    return None


def lum(h):
    def ch(v):
        v = v / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def contrast(a, b):
    la, lb = lum(a) + 0.05, lum(b) + 0.05
    return max(la, lb) / min(la, lb)


def px(value, index=None):
    if not value: return None
    nums = [float(x) for x in re.findall(r"(-?[\d.]+)px", value)]
    if not nums:
        nums = [float(x) for x in re.findall(r"(-?[\d.]+)", value)]
    if not nums: return None
    if index is None: return nums[0]
    # CSS shorthand: [v h] or [t r b l]
    if len(nums) == 1: return nums[0]
    if len(nums) in (2, 3): return nums[1] if index == "h" else nums[0]
    return nums[1] if index == "h" else nums[0]


MODULE_SEL = re.compile(r"^#(clock|workspaces|tray|network|pulseaudio|bluetooth|battery|backlight|mpris|window|"
                        r"custom-[\w-]+|idle_inhibitor|power-profiles-daemon|group-[\w-]+|cpu|memory|wireplumber)$"
                        r"|^\.modules-(left|center|right)$")


def bar_style(css_text, cfg):
    defs, rules = parse_css(css_text)
    def props_for(pred):
        out = []
        for sels, props in rules:
            if any(pred(s) for s in sels): out.append(props)
        return out

    star = {}
    for p in props_for(lambda s: s == "*"): star.update(p)
    window = {}
    for p in props_for(lambda s: s in ("window#waybar", "window#waybar.top", "#waybar")): window.update(p)

    bar_bg = resolve(window.get("background-color") or window.get("background"), defs)
    bar_fg = resolve(window.get("color") or star.get("color"), defs)

    chip_bgs, chip_fgs, radii, gaps, insets, lanes_bg = [], [], [], [], [], False
    borders, border_colors = [], []
    for sels, props in rules:
        mods = [s for s in sels if MODULE_SEL.match(s)]
        if not mods or any(":" in s or " " in s for s in sels if s in mods): continue
        bg = resolve(props.get("background-color") or props.get("background"), defs)
        if bg and bg != "transparent":
            chip_bgs.extend([bg] * len(mods))
            if any(s.startswith(".modules-") for s in mods): lanes_bg = True
        fg = resolve(props.get("color"), defs)
        if fg and fg != "transparent": chip_fgs.extend([fg] * len(mods))
        b = props.get("border")
        if b and "none" not in b:
            bw = px(b)
            if bw: borders.append(bw)
            bc = resolve(b, defs) if ("#" in b or "@" in b or "rgb" in b) else None
            m2 = re.search(r"(@[\w-]+|#[0-9a-fA-F]{3,8}|rgba?\([^)]*\))", b)
            if m2: bc = resolve(m2.group(1), defs)
            if bc and bc != "transparent": border_colors.append(bc)
        r = px(props.get("border-radius"))
        if r is not None: radii.append(r)
        mh, mv = px(props.get("margin"), "h"), px(props.get("margin"), "v")
        if mh is not None: gaps.append(mh)
        if mv is not None: insets.append(mv)

    active = None
    for sels, props in rules:
        if any(re.match(r"^#workspaces button\.(active|focused)$", s) for s in sels):
            a = resolve(props.get("background-color") or props.get("background"), defs)
            if a and a != "transparent": active = a
            elif not active:
                c = resolve(props.get("color"), defs)
                if c and c != "transparent": active = c

    def most(lst):
        return max(set(lst), key=lst.count) if lst else None

    chip = most(chip_bgs)
    text = most(chip_fgs) or bar_fg
    # On a solid chip of its own colour, the readable text is the candidate
    # that contrasts most with it, not merely the most common one.
    if chip and chip.startswith("#"):
        cands = [c for c in set(chip_fgs + [bar_fg]) if c and c.startswith("#")]
        if cands:
            text = max(cands, key=lambda c: contrast(c, chip))
        if not text or not text.startswith("#") or contrast(text, chip) < 3:
            text = max(("#000000", "#ffffff"), key=lambda c: contrast(c, chip))
    radius = most([r for r in radii if r is not None]) if radii else px(star.get("border-radius"))
    radius = radius if radius is not None else 0
    gap = most([g for g in gaps if 0 <= g <= 12])
    inset = most([v for v in insets if 0 <= v <= 8])
    height = cfg.get("height")
    margin = max([px(str(cfg.get(k))) or 0 for k in ("margin-top", "margin-bottom")] + [0])
    edge = px(str(cfg.get("margin-left"))) or 0

    style = {}
    transparent_bar = bar_bg in (None, "transparent")
    if chip is None:
        style["shape"] = "none"
    else:
        style["shape"] = "round" if radius >= 8 else "block"
        if style["shape"] == "block": style["radius"] = int(min(20, radius))
        literal_chip = chip.startswith("#")
        if literal_chip:
            style.update({"solid": True, "colors": "mono", "palette": [chip]})
        else:
            # Chips in the Omarchy theme's background: a light tint of the theme
            # foreground over it, so they keep following the theme.
            style.update({"solid": False, "colors": "mono", "palette": ["foreground"], "tint": 0.12})
        if gap is not None: style["gap"] = int(gap)
        if inset is not None: style["inset"] = int(inset)
        if transparent_bar: style["float"] = int(max(1, min(16, margin or 2)))
        elif margin: style["float"] = int(min(16, margin))
        if lanes_bg: style["gap"] = 0
    if chip is not None and borders:
        style["outline"] = int(max(1, min(4, most(borders))))
        oc = most(border_colors)
        if oc and oc.startswith("#"): style["outlineColor"] = oc
    if isinstance(height, (int, float)) and 16 <= height <= 96: style["size"] = int(height)
    if edge and 0 < edge <= 24: style["edge"] = int(edge)
    for key, val in (("bg", bar_bg), ("fg", text), ("accent", active)):
        if val and val.startswith("#"): style[key] = val
    if "solid" in style and style["solid"] and "fg" not in style:
        style["solid"] = False; style.update({"palette": ["foreground"], "tint": 0.12})
    fam = star.get("font-family", "").split(",")[0].strip().strip("'\"")
    if fam: style["fontFamily"] = fam
    return style


def readme_notes(text):
    notes, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^##\s+(V[\w.\-]+)\s*$", line.strip())
        if m: cur = m.group(1); notes[cur] = []; continue
        if cur and line.strip().startswith("-"):
            t = re.sub(r"<[^>]+>", "", line.strip()[1:]).strip()
            if t: notes[cur].append(t)
    return notes


notes = readme_notes((repo / "README.md").read_text(errors="replace"))
layouts, themes, problems, dropped_all = [], [], [], {}
seen_layout, seen_style = {}, {}
for d in sorted((repo / "config").iterdir(), key=lambda p: [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", p.name)]):
    if not d.is_dir() or d.name == "test": continue
    cfg, err = load_config(d / "config.jsonc")
    if cfg is None:
        problems.append(f"{d.name}: {err}"); continue
    used, dropped = set(), set()
    lanes = {lane: map_lane(expand(cfg, cfg.get(f"modules-{lane}")), used, dropped) for lane in ("left", "center", "right")}
    dropped_all[d.name] = sorted(dropped)
    position = cfg.get("position", "top")
    position = position if position in ("top", "bottom", "left", "right") else "top"
    note = (notes.get(d.name) or [""])[0]
    note = re.sub(r"\s+", " ", note)[:70]
    slug = "hc-" + d.name.lower().replace(".", "-")
    label = "HANCORE " + d.name
    sig = json.dumps([lanes, position])
    if sig in seen_layout:
        seen_layout[sig].append(d.name)
    else:
        seen_layout[sig] = [d.name]
        anchor = "omarchy.clock" if "omarchy.clock" in lanes["center"] else ""
        layouts.append({"id": slug, "label": label, "desc": "HANCORE · " + (note or "waybar layout"),
                        "anchor": anchor, "position": position if position != "top" else None, "layout": lanes, "_dir": d.name})
    css = (d / "style.css").read_text(errors="replace") if (d / "style.css").exists() else ""
    for extra in d.glob("*.css"):
        if extra.name != "style.css": css = extra.read_text(errors="replace") + "\n" + css
    style = bar_style(css, cfg)
    ssig = json.dumps(style, sort_keys=True)
    if ssig in seen_style:
        seen_style[ssig].append(d.name)
    else:
        seen_style[ssig] = [d.name]
        own = any(k in style for k in ("bg", "fg")) or style.get("palette") not in (None, ["foreground"])
        kind = "own colours" if own else ("theme colours, own accent" if "accent" in style else "follows your Omarchy theme")
        themes.append({"id": slug, "label": label, "desc": "HANCORE · " + kind,
                       "style": style, "_dir": d.name})

json.dump({"layouts": layouts, "themes": themes, "problems": problems,
           "dropped": {k: v for k, v in dropped_all.items() if v},
           "dupLayouts": [v for v in seen_layout.values() if len(v) > 1],
           "dupStyles": [v for v in seen_style.values() if len(v) > 1]}, open(out_path, "w"), indent=1, ensure_ascii=False)
print(f"{len(layouts)} distinct layouts, {len(themes)} distinct styles, {len(problems)} unreadable configs")
