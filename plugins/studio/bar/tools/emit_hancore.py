import json, re, sys, subprocess
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
installed = set(subprocess.run(["fc-list", "--format", "%{family}\n"], capture_output=True, text=True).stdout.replace(",", "\n").split("\n"))

def tidy(text, limit=64):
    t = re.sub(r"\*+|`|_", "", text).strip()
    t = re.sub(r"\s+", " ", t)
    t = t[0].upper() + t[1:] if t else t
    if len(t) > limit:
        t = t[:limit].rsplit(" ", 1)[0].rstrip(",;:-") + "…"
    return t

def short(desc):
    return tidy(desc.replace("HANCORE · ", ""))

layouts, themes = [], []
for l in d["layouts"]:
    item = {"id": l["id"], "label": l["label"].replace("HANCORE ", "HANCORE "), "desc": "HANCORE · " + short(l["desc"]),
            "anchor": l["anchor"], "layout": {k: [{"id": w} for w in v] for k, v in l["layout"].items()}}
    if l.get("position"): item["position"] = l["position"]
    layouts.append(item)
notes = {l["id"]: l["desc"] for l in d["layouts"]}
for t in d["themes"]:
    style = dict(t["style"])
    if style.get("fontFamily") and style["fontFamily"] not in installed:
        style.pop("fontFamily")
    note = short(notes.get(t["id"], "")) if t["id"] in notes else ""
    kind = t["desc"].replace("HANCORE · ", "")
    themes.append({"id": t["id"], "label": t["label"], "desc": "HANCORE · " + kind + (" · " + note if note and note != "Waybar layout" else ""), "style": style})

header = """.pragma library

// Bar looks and arrangements converted from HANCORE-linux/waybar-themes
// (https://github.com/HANCORE-linux/waybar-themes, MIT, (c) 2025 drdeltree).
// Generated: each waybar module is mapped to its nearest Omarchy widget
// (cpu/memory/temperature and separators have none and are dropped), and each
// style.css is reduced to omabar16 style keys. Colours the original takes from
// the Omarchy theme are left unset, so those looks keep following the theme
// and the wallpaper. Variants that convert to the same result appear once.
"""
with open(out, "w") as f:
    f.write(header + "\n")
    f.write("var THEMES = " + json.dumps(themes, ensure_ascii=False, indent=1) + "\n\n")
    f.write("var LAYOUTS = " + json.dumps(layouts, ensure_ascii=False, indent=1) + "\n")
print(len(themes), "themes", len(layouts), "layouts ->", out)
