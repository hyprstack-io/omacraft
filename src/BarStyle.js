.pragma library

// The bar's colour maths, as omabar16 does it, so every preview in OMAcraft
// matches the real bar; and the split of a style into its look (shape,
// spacing, fill) and its colours, so the two can be mixed from different
// themes, the way waybar themes keep a colour scheme apart from the layout.

function isList(v) {
    return v !== null && v !== undefined && typeof v === "object" && typeof v.length === "number";
}
function isHex(v) {
    return typeof v === "string" && /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(v);
}
function clone(o) {
    return o === undefined ? undefined : JSON.parse(JSON.stringify(o));
}

// --- colour maths ---

function parseHex(hex) {
    const h = String(hex).replace("#", "");
    return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)];
}
function toHex(rgb) {
    const c = v => ("0" + Math.max(0, Math.min(255, Math.round(v))).toString(16)).slice(-2);
    return "#" + c(rgb[0]) + c(rgb[1]) + c(rgb[2]);
}
function mix(a, b, t) {
    const x = parseHex(a), y = parseHex(b);
    return toHex([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t]);
}
function darker(hex, f) {
    const x = parseHex(hex);
    return toHex([x[0] / f, x[1] / f, x[2] / f]);
}
function lighter(hex, f) {
    const x = parseHex(hex);
    return toHex([x[0] * f, x[1] * f, x[2] * f]);
}
function distance(a, b) {
    const x = parseHex(a), y = parseHex(b);
    return Math.sqrt(Math.pow((x[0] - y[0]) / 255, 2) + Math.pow((x[1] - y[1]) / 255, 2) + Math.pow((x[2] - y[2]) / 255, 2));
}
// WCAG relative luminance and contrast.
function luminance(hex) {
    const ch = v => { v /= 255; return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    const x = parseHex(hex);
    return 0.2126 * ch(x[0]) + 0.7152 * ch(x[1]) + 0.0722 * ch(x[2]);
}
function contrast(a, b) {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// --- palette, as Bar.qml builds it ---

const DEFAULT_PALETTE = ["accent", "blue", "magenta", "green", "yellow", "cyan"];

function themeHue(t, name) {
    const n = String(name);
    const alias = {
        accent: ["accent"], red: ["red", "color1"], green: ["green", "color2"], yellow: ["yellow", "color3"],
        blue: ["blue", "color4", "color12"], magenta: ["magenta", "color5", "color13"],
        cyan: ["cyan", "color6", "color14"], orange: ["orange", "color9"], foreground: ["foreground"],
        background: ["background"]
    };
    const keys = alias[n] || [n];
    for (let i = 0; i < keys.length; i++) if (t[keys[i]]) return t[keys[i]];
    return isHex(n) ? n : null;
}

function buildPalette(themeColors, names, background) {
    const list = isList(names) && names.length > 0 ? names : DEFAULT_PALETTE;
    const out = [];
    for (let i = 0; i < list.length; i++) {
        const literal = isHex(String(list[i]));
        const hex = themeHue(themeColors, list[i]);
        if (!hex) continue;
        if (literal) { out.push(hex); continue; }
        if (distance(hex, background) < 0.14) continue;
        let dup = false;
        for (let j = 0; j < out.length; j++) if (distance(hex, out[j]) < 0.09) dup = true;
        if (!dup) out.push(hex);
    }
    if (out.length === 0) out.push(themeColors.accent || "#888888");
    const base = out[0];
    const ramp = [darker(base, 1.4), lighter(base, 1.3), darker(base, 1.8)];
    for (let k = 0; out.length < 3; k++) out.push(ramp[k % ramp.length]);
    return out;
}

// Every colour a style would use, against the Omarchy theme's colours.
function resolve(style, themeColors) {
    const s = style || {};
    const t = themeColors || {};
    const background = t.background || "#101315", foreground = t.foreground || "#cacccc";
    const bg = isHex(s.bg) ? s.bg : background;
    const fg = isHex(s.fg) ? s.fg : null;
    const solid = s.solid !== false;
    return {
        bg: bg,
        fg: fg,
        accent: isHex(s.accent) ? s.accent : (t.accent || foreground),
        solid: solid,
        tint: s.tint === undefined ? 0.3 : s.tint,
        // Ink on a filled segment, or text on the bar itself.
        text: solid ? (fg || bg) : (fg || foreground),
        barText: fg || foreground,
        palette: buildPalette(t, s.palette, bg),
        style: s
    };
}

function segmentBase(res, region, idx, count, id) {
    const s = res.style;
    if (s.modules && isHex(s.modules[id])) return s.modules[id];
    if (s.regions && isHex(s.regions[region])) return s.regions[region];
    const p = res.palette;
    const i = idx < 0 ? 0 : idx;
    if (s.colors === "mono") return i % 2 === 0 ? p[0] : mix(p[0], res.bg, 0.28);
    const k = region === "right" ? (count - 1 - i) : (region === "center" ? i + 1 : i);
    return p[((k % p.length) + p.length) % p.length];
}

function segmentFill(res, base, lit) {
    if (res.solid) return lit ? lighter(base, 1.14) : base;
    return mix(res.bg, base, Math.min(1, res.tint + (lit ? 0.16 : 0)));
}

// --- looks and colours ---

const COLOUR_KEYS = ["palette", "bg", "fg", "accent", "colors", "outlineColor", "hoverColor", "regions", "modules"];

function lookOf(style) {
    const out = {};
    const s = style || {};
    for (const k in s) if (COLOUR_KEYS.indexOf(k) < 0) out[k] = clone(s[k]);
    return out;
}

function coloursOf(style) {
    const out = {};
    const s = style || {};
    for (const k in s) if (COLOUR_KEYS.indexOf(k) >= 0) out[k] = clone(s[k]);
    return out;
}

function signature(o, skip) {
    const keys = Object.keys(o || {}).filter(k => !skip || skip.indexOf(k) < 0).sort();
    return keys.map(k => k + "=" + JSON.stringify(o[k])).join(";");
}
function lookSignature(style) { return signature(lookOf(style)); }
// fg is left out: it follows the fill, not the scheme.
function colourSignature(style) { return signature(coloursOf(style), ["fg", "regions", "modules"]); }

// Text that reads on a scheme's own background, near its first colour.
function textOn(bg, hue) {
    const light = luminance(bg) < 0.4;
    let text = mix(light ? "#ffffff" : "#111111", hue || (light ? "#ffffff" : "#111111"), 0.12);
    if (contrast(text, bg) < 4.5) text = light ? "#f5f5f5" : "#111111";
    return text;
}

// Does this look fill its segments with colour?
function fills(look) {
    const shape = look.shape || "none";
    return shape !== "none" && shape !== "underline" && look.solid !== false;
}

// A look from one style and the colours of another, made into one style
// whose text reads: dark ink on filled segments, light text on the bar.
function compose(look, colours) {
    const out = lookOf(look);
    const c = coloursOf(colours);
    for (const k in c) if (k !== "fg") out[k] = c[k];
    if (isHex(c.bg)) {
        const hue = (isList(c.palette) && isHex(c.palette[0])) ? c.palette[0] : (isHex(c.accent) ? c.accent : null);
        if (fills(out) && hue) out.fg = contrast(c.bg, hue) >= 3 ? c.bg : (luminance(hue) > 0.35 ? "#111111" : "#f5f5f5");
        else if (isHex(c.fg) && contrast(c.fg, c.bg) >= 3) out.fg = c.fg;
        else out.fg = textOn(c.bg, hue);
    }
    return out;
}

// The swatches a colour scheme shows: background first, then its palette.
function swatches(colours, themeColors) {
    const res = resolve(colours, themeColors);
    return [res.bg].concat(res.palette.slice(0, 6));
}

// --- shapes ---

const SHAPES = [
    { id: "arrow", name: "Chevron", family: "Powerline" },
    { id: "slant", name: "Slant", family: "Slants" },
    { id: "backslant", name: "Back slant", family: "Slants" },
    { id: "trapezoid", name: "Trapezoid", family: "Slants" },
    { id: "hex", name: "Hexagon", family: "Hexagons" },
    { id: "round", name: "Pill", family: "Pills" },
    { id: "block", name: "Block", family: "Blocks" },
    { id: "leaf", name: "Leaf", family: "Leaves & tabs" },
    { id: "tab", name: "Tab", family: "Leaves & tabs" },
    { id: "underline", name: "Underline", family: "Underlines" },
    { id: "none", name: "Plain", family: "Plain" }
];

function shapeFamily(shape) {
    for (let i = 0; i < SHAPES.length; i++) if (SHAPES[i].id === (shape || "none")) return SHAPES[i].family;
    return "Plain";
}

// --- layouts ---

function lane(cfg, name) {
    return cfg && cfg.layout && isList(cfg.layout[name]) ? cfg.layout[name] : [];
}

// A config cut down to a few widgets a lane, for small previews.
function sample(cfg, perLane) {
    const out = clone(cfg) || {};
    out.layout = out.layout || {};
    ["left", "center", "right"].forEach(l => { out.layout[l] = lane(cfg, l).slice(0, perLane); });
    return out;
}

// Which widgets in a lane draw with text beside their glyph in previews.
const LABELLED = ["omarchy.clock", "omarchy.active-window", "omarchy.media", "omarchy.weather"];

const CLOCK_FORMATS = [
    { label: "Day + 24h", format: "dddd HH:mm" },
    { label: "24h", format: "HH:mm" },
    { label: "12h", format: "h:mm AP" },
    { label: "Date + time", format: "ddd d MMM  HH:mm" },
    { label: "Seconds", format: "HH:mm:ss" },
    { label: "ISO", format: "yyyy-MM-dd HH:mm" }
];

// Widgets that draw text, several icons or images, where one glyph would
// replace what they show.
const NOT_ICONABLE = ["omarchy.clock", "omarchy.workspaces", "omarchy.tray", "omarchy.active-window",
    "omarchy.media", "omarchy.spacer", "omarchy.keyboard-layout", "omarchy.weather", "omarchy.indicators",
    "omarchy.elsewhen", "omacraft.folders"];

function iconable(id) {
    return NOT_ICONABLE.indexOf(id) < 0;
}

// A sample of what a clock format shows.
function clockSample(format) {
    const pad = n => ("0" + n).slice(-2);
    const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    const d = new Date();
    return String(format || "").replace(/dddd|ddd|dd|d|MMMM|MMM|MM|yyyy|HH|H|hh|h|mm|ss|AP|ap/g, function(t) {
        switch (t) {
        case "dddd": return days[d.getDay()];
        case "ddd": return days[d.getDay()].slice(0, 3);
        case "dd": return pad(d.getDate());
        case "d": return String(d.getDate());
        case "MMMM": return months[d.getMonth()];
        case "MMM": return months[d.getMonth()].slice(0, 3);
        case "MM": return pad(d.getMonth() + 1);
        case "yyyy": return String(d.getFullYear());
        case "HH": return pad(d.getHours());
        case "H": return String(d.getHours());
        case "hh": return pad(d.getHours() % 12 || 12);
        case "h": return String(d.getHours() % 12 || 12);
        case "mm": return pad(d.getMinutes());
        case "ss": return pad(d.getSeconds());
        case "AP": return d.getHours() < 12 ? "AM" : "PM";
        case "ap": return d.getHours() < 12 ? "am" : "pm";
        }
        return t;
    }).replace(/'([^']*)'/g, "$1");
}
