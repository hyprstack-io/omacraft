.pragma library

// Every setting of the lock and login screens: its default and what it may be.
// The lock plugin, the login theme and OmaCraft's page all read settings through
// clean(), so a hand-edited or damaged file can only ever produce a usable
// screen. Nothing here may be able to hide the password field or stop it taking
// keys: a lock screen that can't be unlocked is the one failure that matters.
//
// Each rule is one of:
//   [default, min, max]    a number
//   [default, ["a", "b"]]  one of these words
//   [true]                 on or off
//   ["", "color"]          #rrggbb, or "" for the theme's colour
//   ["", 120]              text up to this long
var rules = {
    // Where the block of clock, greeting and field sits, in % of the screen.
    blockX: [50, 0, 100], blockY: [50, 0, 100],
    align: ["center", ["left", "center", "right"]],
    gap: [18, 0, 80],
    // What's behind the block.
    panel: ["none", ["none", "card", "left", "right", "bottom"]],
    panelSize: [34, 15, 70],
    panelRadius: [14, 0, 48],
    panelOpacity: [0.72, 0, 1],

    // The password field.
    fieldStyle: ["box", ["box", "pill", "line"]],
    fieldWidth: [381, 180, 900], fieldHeight: [67, 36, 120],
    fieldRadius: [0, 0, 60], borderWidth: [3, 0, 10],
    borderGradient: [true],
    fieldOpacity: [0.8, 0, 1],
    dotGlyph: ["●", ["●", "•", "*", "■", "✦", "█"]],
    placeholder: ["", 60],

    // What else is on the screen.
    showClock: [false], clock24h: [true], clockSeconds: [false],
    clockSize: [88, 24, 260], clockWeight: ["light", ["light", "normal", "bold"]], clockOpacity: [1, 0.1, 1],
    showDate: [false], dateFormat: ["dddd d MMMM", 40], dateSize: [20, 10, 64],
    showGreeting: [false], greeting: ["{user}", 80], greetingSize: [22, 10, 64],
    showAvatar: [false], avatar: ["", 1024], avatarSize: [96, 32, 240],
    avatarShape: ["circle", ["circle", "square", "squircle"]],
    showNote: [false], note: ["", 160], noteSize: [13, 9, 32],
    fontFamily: ["", 80],

    // Colours; empty follows the Omarchy theme.
    colorSurface: ["", "color"], colorBorder: ["", "color"], colorBorder2: ["", "color"],
    colorText: ["", "color"], colorClock: ["", "color"], colorError: ["", "color"],
    colorDim: ["", "color"], colorPanel: ["", "color"],

    // The picture behind it all.
    bgMode: ["wallpaper", ["wallpaper", "image", "folder", "solid", "gradient"]],
    bgImage: ["", 1024], bgFolder: ["", 1024],
    bgColor: ["", "color"], bgColor2: ["", "color"], bgAngle: [135, 0, 359],
    bgFit: ["crop", ["crop", "fit", "stretch", "center", "tile"]],
    blur: [1, 0, 1], dim: [0, 0, 1],
    brightness: [0, -1, 1], contrast: [-0.08, -1, 1], saturation: [0, -1, 1],

    // Motion. Never holds up typing: the field takes keys from the first frame.
    lockIn: ["none", ["none", "fade", "rise", "zoom", "focus", "curtain"]],
    lockInMs: [420, 100, 1500],
    unlockOut: ["none", ["none", "fade", "rise", "zoom", "focus", "curtain"]],
    // Capped: this is time between a correct password and the desktop.
    unlockMs: [380, 100, 800],
    shake: [true], drift: [false], pulse: [false],

    // Lock only: seconds before the locked screen turns the display off.
    blankSeconds: [5, 2, 3600],

    // Login only.
    showSession: [true], showPower: [true]
};

var hexColor = /^#[0-9a-fA-F]{6}$/;

function ruleKind(rule) {
    if (rule.length === 1) return "bool";
    if (rule.length === 3) return "number";
    if (Array.isArray(rule[1])) return "word";
    return rule[1] === "color" ? "color" : "text";
}

// One value made safe. Strings are accepted for everything, since the login
// theme's settings arrive as text from an ini file.
function cleanValue(rule, raw) {
    var fallback = rule[0];
    if (raw === undefined || raw === null) return fallback;
    switch (ruleKind(rule)) {
    case "bool":
        if (raw === true || raw === "true") return true;
        if (raw === false || raw === "false") return false;
        return fallback;
    case "number":
        var n = Number(raw);
        if (raw === "" || !isFinite(n)) return fallback;
        return Math.min(rule[2], Math.max(rule[1], n));
    case "word":
        return rule[1].indexOf(String(raw)) !== -1 ? String(raw) : fallback;
    case "color":
        return hexColor.test(String(raw)) ? String(raw) : fallback;
    default:
        return String(raw).replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, rule[1]);
    }
}

function clean(raw) {
    var source = raw && typeof raw === "object" ? raw : {};
    var out = {};
    for (var key in rules) out[key] = cleanValue(rules[key], source[key]);
    return out;
}

// Ready-made looks: each is only what it changes from the defaults.
var presets = [
    { id: "omarchy", name: "Omarchy", note: "The stock lock: blurred wallpaper, one field", values: {} },
    { id: "console", name: "Console", note: "Dark screen, left-aligned, a line to type on", values: {
        bgMode: "solid", blockX: 14, blockY: 74, align: "left", fieldStyle: "line", fieldWidth: 460, fieldHeight: 54,
        borderGradient: false, fieldOpacity: 0, dotGlyph: "*", showClock: true, clockSize: 132, clockWeight: "bold",
        showDate: true, showGreeting: true, greeting: "{user}@{host}", greetingSize: 18, lockIn: "fade", unlockOut: "fade", unlockMs: 240
    } },
    { id: "sidebar", name: "Sidebar", note: "A full-height panel; the wallpaper stays sharp", values: {
        panel: "left", panelSize: 30, panelOpacity: 0.82, blockX: 15, blockY: 50, fieldWidth: 400, blur: 0, contrast: 0,
        fieldStyle: "box", showClock: true, clockSize: 92, showDate: true, showAvatar: true, showGreeting: true,
        lockIn: "curtain", unlockOut: "curtain", lockInMs: 520, unlockMs: 460
    } },
    { id: "glass", name: "Glass", note: "A soft card with an avatar over a dimmed picture", values: {
        panel: "card", panelSize: 28, panelRadius: 28, panelOpacity: 0.42, fieldStyle: "pill", fieldRadius: 34, fieldHeight: 58,
        fieldWidth: 340, showAvatar: true, showGreeting: true, blur: 0.5, dim: 0.25, contrast: 0, lockIn: "zoom", unlockOut: "zoom"
    } },
    { id: "poster", name: "Poster", note: "A huge clock, the field tucked low", values: {
        blockX: 50, blockY: 76, showClock: true, clockSize: 220, clockWeight: "bold", clockOpacity: 0.92, showDate: true, dateSize: 24,
        fieldWidth: 320, fieldHeight: 50, fieldStyle: "line", fieldOpacity: 0, blur: 0, dim: 0.3, contrast: 0, drift: true,
        lockIn: "rise", unlockOut: "rise"
    } },
    { id: "strip", name: "Strip", note: "One bar along the foot of the screen", values: {
        panel: "bottom", panelSize: 18, panelOpacity: 0.8, blockX: 50, blockY: 89, showClock: false, fieldWidth: 520, fieldHeight: 54,
        showGreeting: true, gap: 10, blur: 0.15, contrast: 0, lockIn: "rise", unlockOut: "focus"
    } }
];

function preset(id) {
    for (var i = 0; i < presets.length; i++)
        if (presets[i].id === id) return presets[i];
    return presets[0];
}

// The theme-resolved colours a scene draws with.
function colours(s, theme) {
    return {
        background: s.colorDim || theme.background,
        surface: s.colorSurface || theme.background,
        panel: s.colorPanel || theme.background,
        border: s.colorBorder || theme.accent,
        border2: s.colorBorder2 || theme.accent2 || theme.accent,
        text: s.colorText || theme.foreground,
        clock: s.colorClock || s.colorText || theme.foreground,
        error: s.colorError || theme.urgent
    };
}

// Where a pictured file comes from, or "" when there's nothing to load.
function backgroundFile(s, wallpaper, folderPick) {
    if (s.bgMode === "image") return s.bgImage || wallpaper;
    if (s.bgMode === "folder") return folderPick || wallpaper;
    if (s.bgMode === "wallpaper") return wallpaper;
    return "";
}

function fileUrl(path) {
    if (!path) return "";
    if (path.indexOf("file:") === 0 || path.indexOf("qrc:") === 0) return path;
    return "file://" + path.split("/").map(encodeURIComponent).join("/");
}
